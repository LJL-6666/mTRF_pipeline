function dat = read_biosemi_bdf1(filename, hdr, begsample, endsample, chanindx)
% Implemented based on read_biosemi_bdf.m file in FieldTrip toolbox
% To replace the file with the same name in FieldTrip
%
% this function can be used alone for reading BDF+ data file, as well as integrated with FieldTrip
% usage:
% hdr = read_bdf(file_name);
% dat = read_bdf(file_name,hdr,begsample,endsample, [chanindx]);
% To read all data, set begsample = 1 and endsample = hdr.nSamples;
%
% For extracting the EEG events in FieldTrip, trialfun_bdf.m is also needed
% usage (an example for listing all the events):
% cfg = [];
% cfg.dataset = file_name;
% cfg.trialdef.eventtype  = '?';
% cfg.trialfun = 'trialfun_BDF';
% cfg_trl = ft_definetrial(cfg);
%
% 2015-12-15, Dan Zhang, added support for BDF+ format, dzhang@tsinghua.edu.cn
%
% 2015-12-18, Bug fixed: error when reading data segment without triggers, Dan Zhang
%
% 2016-01-07, Updated to be compatible with files with abnormal data duration information, Dan Zhang
%
% 2017-01-01, Bug fixed: compatiblility for files without events

if nargin==1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % read the header, this code is from EEGLAB's openbdf
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    FILENAME = filename;
    
    % defines Seperator for Subdirectories
    SLASH='/';
    BSLASH=char(92);
    
    cname=computer;
    if cname(1:2)=='PC' SLASH=BSLASH; end;
    
    fid=fopen(FILENAME,'r','ieee-le');
    if fid<0
        fprintf(2,['Error LOADEDF: File ' FILENAME ' not found\n']);
        return;
    end;
    
    EDF.FILE.FID=fid;
    EDF.FILE.OPEN = 1;
    EDF.FileName = FILENAME;
    
    PPos=min([max(find(FILENAME=='.')) length(FILENAME)+1]);
    SPos=max([0 find((FILENAME=='/') | (FILENAME==BSLASH))]);
    EDF.FILE.Ext = FILENAME(PPos+1:length(FILENAME));
    EDF.FILE.Name = FILENAME(SPos+1:PPos-1);
    if SPos==0
        EDF.FILE.Path = pwd;
    else
        EDF.FILE.Path = FILENAME(1:SPos-1);
    end;
    EDF.FileName = [EDF.FILE.Path SLASH EDF.FILE.Name '.' EDF.FILE.Ext];
    
    H1=char(fread(EDF.FILE.FID,256,'char')');     %
    EDF.VERSION=H1(1:8);                          % 8 Byte  Versionsnummer
    %if 0 fprintf(2,'LOADEDF: WARNING  Version EDF Format %i',ver); end;
    EDF.PID = deblank(H1(9:88));                  % 80 Byte local patient identification
    EDF.RID = deblank(H1(89:168));                % 80 Byte local recording identification
    %EDF.H.StartDate = H1(169:176);               % 8 Byte
    %EDF.H.StartTime = H1(177:184);               % 8 Byte
    EDF.T0=[str2num(H1(168+[7 8])) str2num(H1(168+[4 5])) str2num(H1(168+[1 2])) str2num(H1(168+[9 10])) str2num(H1(168+[12 13])) str2num(H1(168+[15 16])) ];
    
    % Y2K compatibility until year 2090
    if EDF.VERSION(1)=='0'
        if EDF.T0(1) < 91
            EDF.T0(1)=2000+EDF.T0(1);
        else
            EDF.T0(1)=1900+EDF.T0(1);
        end;
    else ;
        % in a future version, this is hopefully not needed
    end;
    
    EDF.HeadLen = str2num(H1(185:192));  % 8 Byte  Length of Header
    % reserved = H1(193:236);            % 44 Byte
    EDF.NRec = str2num(H1(237:244));     % 8 Byte  # of data records
    EDF.Dur = str2num(H1(245:252));      % 8 Byte  # duration of data record in sec
    EDF.NS = str2num(H1(253:256));       % 8 Byte  # of signals
    
    EDF.Label = char(fread(EDF.FILE.FID,[16,EDF.NS],'char')');
    EDF.Transducer = char(fread(EDF.FILE.FID,[80,EDF.NS],'char')');
    EDF.PhysDim = char(fread(EDF.FILE.FID,[8,EDF.NS],'char')');
    
    EDF.PhysMin= str2num(char(fread(EDF.FILE.FID,[8,EDF.NS],'char')'));
    EDF.PhysMax= str2num(char(fread(EDF.FILE.FID,[8,EDF.NS],'char')'));
    EDF.DigMin = str2num(char(fread(EDF.FILE.FID,[8,EDF.NS],'char')'));
    EDF.DigMax = str2num(char(fread(EDF.FILE.FID,[8,EDF.NS],'char')'));
    
    % check validity of DigMin and DigMax
    if (length(EDF.DigMin) ~= EDF.NS)
        fprintf(2,'Warning OPENEDF: Failing Digital Minimum\n');
        EDF.DigMin = -(2^15)*ones(EDF.NS,1);
    end
    if (length(EDF.DigMax) ~= EDF.NS)
        fprintf(2,'Warning OPENEDF: Failing Digital Maximum\n');
        EDF.DigMax = (2^15-1)*ones(EDF.NS,1);
    end
    if (any(EDF.DigMin >= EDF.DigMax))
        fprintf(2,'Warning OPENEDF: Digital Minimum larger than Maximum\n');
    end
    % check validity of PhysMin and PhysMax
    if (length(EDF.PhysMin) ~= EDF.NS)
        fprintf(2,'Warning OPENEDF: Failing Physical Minimum\n');
        EDF.PhysMin = EDF.DigMin;
    end
    if (length(EDF.PhysMax) ~= EDF.NS)
        fprintf(2,'Warning OPENEDF: Failing Physical Maximum\n');
        EDF.PhysMax = EDF.DigMax;
    end
    if (any(EDF.PhysMin >= EDF.PhysMax))
        fprintf(2,'Warning OPENEDF: Physical Minimum larger than Maximum\n');
        EDF.PhysMin = EDF.DigMin;
        EDF.PhysMax = EDF.DigMax;
    end
    EDF.PreFilt= char(fread(EDF.FILE.FID,[80,EDF.NS],'char')');   %
    tmp = fread(EDF.FILE.FID,[8,EDF.NS],'char')'; %   samples per data record
    EDF.SPR = str2num(char(tmp));               % samples per data record
    
    fseek(EDF.FILE.FID,32*EDF.NS,0);
    
    EDF.Cal = (EDF.PhysMax-EDF.PhysMin)./(EDF.DigMax-EDF.DigMin);
    EDF.Off = EDF.PhysMin - EDF.Cal .* EDF.DigMin;
    tmp = find(EDF.Cal < 0);
    EDF.Cal(tmp) = ones(size(tmp));
    EDF.Off(tmp) = zeros(size(tmp));
    
    EDF.Calib=[EDF.Off';(diag(EDF.Cal))];
    %EDF.Calib=sparse(diag([1; EDF.Cal]));
    %EDF.Calib(1,2:EDF.NS+1)=EDF.Off';
    
    EDF.SampleRate = EDF.SPR / EDF.Dur;
    
    EDF.FILE.POS = ftell(EDF.FILE.FID);
    if EDF.NRec == -1                            % unknown record size, determine correct NRec
        fseek(EDF.FILE.FID, 0, 'eof');
        endpos = ftell(EDF.FILE.FID);
        EDF.NRec = floor((endpos - EDF.FILE.POS) / (sum(EDF.SPR) * 2));
        fseek(EDF.FILE.FID, EDF.FILE.POS, 'bof');
        H1(237:244)=sprintf('%-8i',EDF.NRec);      % write number of records
    end;
    
    EDF.Chan_Select=(EDF.SPR==max(EDF.SPR));
    for k=1:EDF.NS
        if EDF.Chan_Select(k)
            EDF.ChanTyp(k)='N';
        else
            EDF.ChanTyp(k)=' ';
        end;
        if findstr(upper(EDF.Label(k,:)),'ECG')
            EDF.ChanTyp(k)='C';
        elseif findstr(upper(EDF.Label(k,:)),'EKG')
            EDF.ChanTyp(k)='C';
        elseif findstr(upper(EDF.Label(k,:)),'EEG')
            EDF.ChanTyp(k)='E';
        elseif findstr(upper(EDF.Label(k,:)),'EOG')
            EDF.ChanTyp(k)='O';
        elseif findstr(upper(EDF.Label(k,:)),'EMG')
            EDF.ChanTyp(k)='M';
        end;
    end;
    
    EDF.AS.spb = sum(EDF.SPR);    % Samples per Block
    
    hdr.Annotation = 0;
    hdr.AnnotationChn = -1;
    EDF.SampleRateOrg = EDF.SampleRate;
    if any(EDF.SampleRate~=EDF.SampleRate(1))
        chn_indx = find(EDF.SampleRate~=EDF.SampleRate(1));
        if(length(chn_indx) == 1 && strcmp(EDF.Label(chn_indx,:),'BDF Annotations '))
            disp('BDF+ file format detected, the BDF Annotation channel will be skipped when reading data');
            hdr.Annotation = 1;
            hdr.AnnotationChn = chn_indx;
            EDF.SampleRate(chn_indx) = EDF.SampleRate(1);%force it to be the same as others, in order to pass the FieldTrip test
            EDF.Label(chn_indx,:) = [];%delete the info about the Annotation channel
            EDF.NS = EDF.NS -1;
        else
            error('Channels with different sampling rate but not BDF Annotation found');
        end
    end
    
    %check and fix the file duration if necessary
    fid_check = fopen(FILENAME,'r','ieee-le');
    fseek(fid_check,0,'eof');
    fsize = ftell(fid_check);
    Dur_actual = (fsize - EDF.HeadLen)/(EDF.Dur * sum(EDF.SampleRateOrg) * 3);
    if(EDF.NRec ~= Dur_actual)
        disp('!!! Warning: abnormal file duration found, press any key to continue reading with file duration fixed');
        pause;
        EDF.NRec = Dur_actual;
    end
    
    %read all the events as well
    if(hdr.Annotation)
        epoch_total = EDF.Dur * sum(EDF.SampleRateOrg);
        n_annotation = EDF.Dur*EDF.SampleRateOrg(hdr.AnnotationChn);
        % allocate memory to hold the data
        dat_event = zeros(EDF.NRec,n_annotation*3);
        % read and concatenate all required data epochs
        for i=1:EDF.NRec
            offset = EDF.HeadLen + (i-1)*epoch_total*3 + EDF.Dur*sum(EDF.SampleRateOrg(1:hdr.AnnotationChn-1))*3;
            %extract the bits for events
            buf = readEvents(filename, offset, n_annotation); % see below in subfunction
            %           buf = readLowLevel(filename, offset, n_annotation);
            dat_event(i,:) = buf;
        end
        
        %decoding the events
        event_cnt = 1;
        event = [];
        for i = 1:EDF.NRec
            char20_index = find(dat_event(i,:)==20);
            
            TAL_start = char20_index(2) + 1;%the first event right after the second char 20
            char20_index = char20_index(3:end);%remove the first two 20 (belonging to the TAL time index)
            num_event = length(char20_index)/2;%two char 20 per event
            if(num_event == 0)
                continue;
            end
            for j = 1:num_event
                %structure of a single event: [offset in sec] [char21][Duration in sec] [char20][Trigger Code] [char20][char0]
                %the field [char21][Duration in sec] can be skipped
                %multiple events can be stored within one Annotation block, the last ends with [char0][char0]
                singleTAL = dat_event(i,TAL_start:char20_index(2*j)-1);
                char21_one = find(singleTAL == 21);
                char20_one = find(singleTAL == 20);
                event{event_cnt}.eventtype = 'trigger';%fixed info
                event{event_cnt}.eventvalue = str2num(char(singleTAL(char20_one+1:end)));%trigger code
                if(~isempty(char21_one))%if Duration field exist
                    event{event_cnt}.offset_in_sec = str2num(char(singleTAL(1:char21_one-1)));%in sec
                    event{event_cnt}.duration = str2num(char(singleTAL(char21_one+1:char20_one-1)));%in sec;
                else%if no Duration field
                    event{event_cnt}.offset_in_sec = str2num(char(singleTAL(1:char20_one-1)));%in sec
                    event{event_cnt}.duration = 0;
                end
                event{event_cnt}.offset = round(event{event_cnt}.offset_in_sec*EDF.SampleRateOrg(1));%in sampling points
                event_cnt = event_cnt + 1;
                TAL_start = char20_index(2*j) + 1;
                if(dat_event(i,char20_index(2*j)+1) ~= 0)%check if the TAL is complete
                    error('BDF+ event error');
                end
            end
            %check if all TALs are read
            if ~(dat_event(i,char20_index(2*num_event)+1) == 0 && dat_event(i,char20_index(2*num_event)+2) == 0)
                error('BDF+ final event error');
            end
        end
        hdr.event = event;
    end
    % close the file
    fclose(EDF.FILE.FID);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % convert the header to Fieldtrip-style
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    hdr.Fs          = EDF.SampleRate(1);
    hdr.nChans      = EDF.NS;
    hdr.label       = cellstr(EDF.Label);
    % it is continuous data, therefore append all records in one trial
    hdr.nTrials     = 1;
    hdr.nSamples    = EDF.NRec * EDF.Dur * EDF.SampleRate(1);
    hdr.nSamplesPre = 0;
    hdr.orig        = EDF;
    
    % return the header
    dat = hdr;
    
else
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % read the data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % retrieve the original header
    EDF = hdr.orig;
    
    % determine the trial containing the begin and end sample
    epochlength = EDF.Dur * EDF.SampleRate(1);
    begepoch    = floor((begsample-1)/epochlength) + 1;
    endepoch    = floor((endsample-1)/epochlength) + 1;
    nepochs     = endepoch - begepoch + 1;
    nchans      = EDF.NS;
    epoch_total = EDF.Dur * sum(EDF.SampleRateOrg);
    
    if nargin<5
        chanindx = 1:nchans;
    end
    if(hdr.Annotation)
        for tmp_indx = 1:length(chanindx)
            %make this revision as the Annotation channel is invisible to the
            %users, hereby channel index (by user) larger than the Annotation
            %channel should increase their index by 1
            if(chanindx(tmp_indx) >= hdr.AnnotationChn)
                chanindx(tmp_indx) = chanindx(tmp_indx) + 1;
            end
        end
    end
    
    % allocate memory to hold the data
    dat = zeros(length(chanindx),nepochs*epochlength);
    
    % read and concatenate all required data epochs
    for i=begepoch:endepoch
        offset = EDF.HeadLen + (i-1)*epoch_total*3;
        % read the data from all channels and then select the desired channels
        buf = readLowLevel(filename, offset, epoch_total); % see below in subfunction
        if(~hdr.Annotation)% BDF file format
            buf = reshape(buf, epochlength, nchans);
        else % BDF+ file format: remove the Annotation channel
            n_annotation = EDF.Dur*EDF.SampleRateOrg(hdr.AnnotationChn);
            if(hdr.AnnotationChn == nchans+1)%if the Annotation channel is the last channel
                buf = buf(1:epoch_total-n_annotation);
            else
                tmp_offset = EDF.Dur*sum(EDF.SampleRateOrg(1:hdr.AnnotationChn-1));
                buf = buf([1:tmp_offset tmp_offset+n_annotation+1:end]);
            end
            buf = reshape(buf, epochlength, nchans);
        end
        dat(:,((i-begepoch)*epochlength+1):((i-begepoch+1)*epochlength)) = buf(:,chanindx)';
    end
    
    % select the desired samples
    begsample = begsample - (begepoch-1)*epochlength;  % correct for the number of bytes that were skipped
    endsample = endsample - (begepoch-1)*epochlength;  % correct for the number of bytes that were skipped
    dat = dat(:, begsample:endsample);
    
    % Calibrate the data
    calib = diag(EDF.Cal(chanindx));
    if length(chanindx)>1
        % using a sparse matrix speeds up the multiplication
        dat = sparse(calib) * dat;
    else
        % in case of one channel the sparse multiplication would result in a sparse array
        dat = calib * dat;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION for reading the 24 bit values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function buf = readLowLevel(filename, offset, numwords)
% if offset < 2*1024^3
%   % use the external mex file, only works for <2GB
%   buf = read_24bit(filename, offset, numwords);
%   % this would be the only difference between the bdf and edf implementation
%   % buf = read_16bit(filename, offset, numwords);
% else
%   use plain matlab, thanks to Philip van der Broek
fp = fopen(filename,'r','ieee-le');
status = fseek(fp, offset, 'bof');
if status
    error(['failed seeking ' filename]);
end
[buf,num] = fread(fp,numwords,'bit24=>double');
fclose(fp);
if (num<numwords)
    error(['failed opening ' filename]);
    return
    %   end
end

function buf = readEvents(filename, offset, numwords)

% use plain matlab, thanks to Philip van der Broek
fp = fopen(filename,'r','ieee-le');
status = fseek(fp, offset, 'bof');
if status
    error(['failed seeking ' filename]);
end
[buf,num] = fread(fp,numwords*3,'uint8=>char');
fclose(fp);
if (num<numwords)
    error(['failed opening ' filename]);
    return
end

