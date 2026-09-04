function dat = read_biosemi_bdf2(file_name, hdr, begsample, endsample, chanindx)
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
% 2017-01-01, Revised to read the upgraded BDF+ file package
%             input the directory name, read both data.bdf and evt.bdf
%             This new version is also compatible with the older version
%
% 2017-06-07, Updated to be compatible with the newly released Neuracle
%             Recording Software, see line 71-78

DATAFILENAME = file_name;
%assume there is an evt.bdf file in the same directory
% defines Seperator for Subdirectories
SLASH='/';
BSLASH=char(92);
cname = computer;
if cname(1:2)=='PC' SLASH=BSLASH; end;
PPos=min([max(find(DATAFILENAME=='.')) length(DATAFILENAME)+1]);
SPos=max([0 find((DATAFILENAME=='/') | (DATAFILENAME==BSLASH))]);
FILE.Ext = DATAFILENAME(PPos+1:length(DATAFILENAME));
FILE.Name = DATAFILENAME(SPos+1:PPos-1);
if SPos==0
    FILE.Path = pwd;
else
    FILE.Path = DATAFILENAME(1:SPos-1);
end;
EVTFILENAME = [FILE.Path SLASH 'evt.' FILE.Ext];

if nargin==1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % read the header, this code is from EEGLAB's openbdf
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    EDF = readHeader(DATAFILENAME,1);
    EVT = readHeader(EVTFILENAME,0);
    
    %check and fix the file duration if necessary
    fid_check = fopen(DATAFILENAME,'r','ieee-le');
    fseek(fid_check,0,'eof');
    fsize = ftell(fid_check);
    Dur_actual = (fsize - EDF.HeadLen)/(EDF.Dur * sum(EDF.SampleRate) * 3);
    if(EDF.NRec ~= Dur_actual)
        disp('!!! Warning: abnormal file duration found, reading with file duration fixed');
%         pause;
        if(EDF.NRec > Dur_actual)
           EDF.NRec = floor(Dur_actual);
           %if the calculated duration is less than the recorded size,
           %change the recorded size; otherwise, keep the original size
        end
    end
    fclose(fid_check);
    
    % ****** now read events ******
    hdr.Annotation = 1;
    hdr.AnnotationChn = [];
    %find the first and possibly ONLY channel with label of 'BDF Annotations'
    for i = 1:size(EVT.Label,1)
        if(strcmp(EVT.Label(i,:),'BDF Annotations '))
            hdr.AnnotationChn = i;
            break;
        end
    end
    %read all the events as well
    if(hdr.Annotation)
        epoch_total = EVT.Dur * sum(EVT.SampleRate);
        n_annotation = EVT.Dur*EVT.SampleRate(hdr.AnnotationChn);
        % allocate memory to hold the data
        dat_event = zeros(EVT.NRec,n_annotation*3);
        % read and concatenate all required data epochs
        for i=1:EVT.NRec
            offset = EVT.HeadLen + (i-1)*epoch_total*3 + EVT.Dur*sum(EVT.SampleRate(1:hdr.AnnotationChn-1))*3;
            %extract the bits for events
            buf = readEvents(EVTFILENAME, offset, n_annotation); % see below in subfunction
            %           buf = readLowLevel(filename, offset, n_annotation);
            dat_event(i,:) = buf;
        end
        
        %decoding the events
        event_cnt = 1;
        event = [];
        for i = 1:EVT.NRec
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
                event{event_cnt}.offset = round(event{event_cnt}.offset_in_sec*EVT.SampleRate(1));%in sampling points
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
    epoch_total = EDF.Dur * sum(EDF.SampleRate);
    
    if nargin<5
        chanindx = 1:nchans;
    end
    %the following codes not necessary in the 2.0 version
    %     if(hdr.Annotation)
    %         for tmp_indx = 1:length(chanindx)
    %             %make this revision as the Annotation channel is invisible to the
    %             %users, hereby channel index (by user) larger than the Annotation
    %             %channel should increase their index by 1
    %             if(chanindx(tmp_indx) >= hdr.AnnotationChn)
    %                 chanindx(tmp_indx) = chanindx(tmp_indx) + 1;
    %             end
    %         end
    %     end
    
    % allocate memory to hold the data
    dat = zeros(length(chanindx),nepochs*epochlength);
    
    % read and concatenate all required data epochs
    for i=begepoch:endepoch
        offset = EDF.HeadLen + (i-1)*epoch_total*3;
        % read the data from all channels and then select the desired channels
        buf = readLowLevel(DATAFILENAME, offset, epoch_total); % see below in subfunction
        %         if(~hdr.Annotation)% BDF file format
        buf = reshape(buf, epochlength, nchans);
        %         else % BDF+ file format: remove the Annotation channel
        %             n_annotation = EDF.Dur*EDF.SampleRate(hdr.AnnotationChn);
        %             if(hdr.AnnotationChn == nchans+1)%if the Annotation channel is the last channel
        %                 buf = buf(1:epoch_total-n_annotation);
        %             else
        %                 tmp_offset = EDF.Dur*sum(EDF.SampleRate(1:hdr.AnnotationChn-1));
        %                 buf = buf([1:tmp_offset tmp_offset+n_annotation+1:end]);
        %             end
        %             buf = reshape(buf, epochlength, nchans);
        %         end
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

function HDR = readHeader(FILENAME,if_data)
% defines Seperator for Subdirectories
SLASH='/';
BSLASH=char(92);

cname = computer;
if cname(1:2)=='PC' SLASH=BSLASH; end;

fid = fopen(FILENAME,'r','ieee-le');
if fid<0
    fprintf(2,['Error LOADEDF: File ' FILENAME ' not found\n']);
    return;
end;

HDR.FILE.FID = fid;
HDR.FILE.OPEN = 1;
HDR.FileName = FILENAME;

PPos=min([max(find(FILENAME=='.')) length(FILENAME)+1]);
SPos=max([0 find((FILENAME=='/') | (FILENAME==BSLASH))]);
HDR.FILE.Ext = FILENAME(PPos+1:length(FILENAME));
HDR.FILE.Name = FILENAME(SPos+1:PPos-1);
if SPos==0
    HDR.FILE.Path = pwd;
else
    HDR.FILE.Path = FILENAME(1:SPos-1);
end;
HDR.FileName = [HDR.FILE.Path SLASH HDR.FILE.Name '.' HDR.FILE.Ext];

H1=char(fread(HDR.FILE.FID,256,'char')');     %
HDR.VERSION=H1(1:8);                          % 8 Byte  Versionsnummer
%if 0 fprintf(2,'LOADEDF: WARNING  Version HDR Format %i',ver); end;
HDR.PID = deblank(H1(9:88));                  % 80 Byte local patient identification
HDR.RID = deblank(H1(89:168));                % 80 Byte local recording identification
%HDR.H.StartDate = H1(169:176);               % 8 Byte
%HDR.H.StartTime = H1(177:184);               % 8 Byte
HDR.T0=[str2num(H1(168+[7 8])) str2num(H1(168+[4 5])) str2num(H1(168+[1 2])) str2num(H1(168+[9 10])) str2num(H1(168+[12 13])) str2num(H1(168+[15 16])) ];

% Y2K compatibility until year 2090
if HDR.VERSION(1)=='0'
    if HDR.T0(1) < 91
        HDR.T0(1)=2000+HDR.T0(1);
    else
        HDR.T0(1)=1900+HDR.T0(1);
    end;
else ;
    % in a future version, this is hopefully not needed
end;

HDR.HeadLen = str2num(H1(185:192));  % 8 Byte  Length of Header
% reserved = H1(193:236);            % 44 Byte
HDR.NRec = str2num(H1(237:244));     % 8 Byte  # of data records
HDR.Dur = str2num(H1(245:252));      % 8 Byte  # duration of data record in sec
HDR.NS = str2num(H1(253:256));       % 8 Byte  # of signals

HDR.Label = char(fread(HDR.FILE.FID,[16,HDR.NS],'char')');
HDR.Transducer = char(fread(HDR.FILE.FID,[80,HDR.NS],'char')');
HDR.PhysDim = char(fread(HDR.FILE.FID,[8,HDR.NS],'char')');

HDR.PhysMin= str2num(char(fread(HDR.FILE.FID,[8,HDR.NS],'char')'));
HDR.PhysMax= str2num(char(fread(HDR.FILE.FID,[8,HDR.NS],'char')'));
HDR.DigMin = str2num(char(fread(HDR.FILE.FID,[8,HDR.NS],'char')'));
HDR.DigMax = str2num(char(fread(HDR.FILE.FID,[8,HDR.NS],'char')'));

% check validity of DigMin and DigMax
if (length(HDR.DigMin) ~= HDR.NS)
    fprintf(2,'Warning OPENEDF: Failing Digital Minimum\n');
    HDR.DigMin = -(2^15)*ones(HDR.NS,1);
end
if (length(HDR.DigMax) ~= HDR.NS)
    fprintf(2,'Warning OPENEDF: Failing Digital Maximum\n');
    HDR.DigMax = (2^15-1)*ones(HDR.NS,1);
end
if (any(HDR.DigMin >= HDR.DigMax))
    fprintf(2,'Warning OPENEDF: Digital Minimum larger than Maximum\n');
end
% check validity of PhysMin and PhysMax
if (length(HDR.PhysMin) ~= HDR.NS)
    fprintf(2,'Warning OPENEDF: Failing Physical Minimum\n');
    HDR.PhysMin = HDR.DigMin;
end
if (length(HDR.PhysMax) ~= HDR.NS)
    fprintf(2,'Warning OPENEDF: Failing Physical Maximum\n');
    HDR.PhysMax = HDR.DigMax;
end
if (any(HDR.PhysMin >= HDR.PhysMax))
    fprintf(2,'Warning OPENEDF: Physical Minimum larger than Maximum\n');
    HDR.PhysMin = HDR.DigMin;
    HDR.PhysMax = HDR.DigMax;
end
HDR.PreFilt= char(fread(HDR.FILE.FID,[80,HDR.NS],'char')');   %
tmp = fread(HDR.FILE.FID,[8,HDR.NS],'char')'; %   samples per data record
HDR.SPR = str2num(char(tmp));               % samples per data record

fseek(HDR.FILE.FID,32*HDR.NS,0);

HDR.Cal = (HDR.PhysMax-HDR.PhysMin)./(HDR.DigMax-HDR.DigMin);
HDR.Off = HDR.PhysMin - HDR.Cal .* HDR.DigMin;
tmp = find(HDR.Cal < 0);
HDR.Cal(tmp) = ones(size(tmp));
HDR.Off(tmp) = zeros(size(tmp));

HDR.Calib=[HDR.Off';(diag(HDR.Cal))];
%HDR.Calib=sparse(diag([1; HDR.Cal]));
%HDR.Calib(1,2:HDR.NS+1)=HDR.Off';

HDR.SampleRate = HDR.SPR / HDR.Dur;

HDR.FILE.POS = ftell(HDR.FILE.FID);
if HDR.NRec == -1                            % unknown record size, determine correct NRec
    fseek(HDR.FILE.FID, 0, 'eof');
    endpos = ftell(HDR.FILE.FID);
    HDR.NRec = floor((endpos - HDR.FILE.POS) / (sum(HDR.SPR) * 2));
    fseek(HDR.FILE.FID, HDR.FILE.POS, 'bof');
    H1(237:244)=sprintf('%-8i',HDR.NRec);      % write number of records
end;

HDR.Chan_Select=(HDR.SPR==max(HDR.SPR));
for k=1:HDR.NS
    if HDR.Chan_Select(k)
        HDR.ChanTyp(k)='N';
    else
        HDR.ChanTyp(k)=' ';
    end;
    if findstr(upper(HDR.Label(k,:)),'ECG')
        HDR.ChanTyp(k)='C';
    elseif findstr(upper(HDR.Label(k,:)),'EKG')
        HDR.ChanTyp(k)='C';
    elseif findstr(upper(HDR.Label(k,:)),'EEG')
        HDR.ChanTyp(k)='E';
    elseif findstr(upper(HDR.Label(k,:)),'EOG')
        HDR.ChanTyp(k)='O';
    elseif findstr(upper(HDR.Label(k,:)),'EMG')
        HDR.ChanTyp(k)='M';
    end;
end;

HDR.AS.spb = sum(HDR.SPR);    % Samples per Block

if(if_data)%check this for ONLY data file, NOT event file
    if any(HDR.SampleRate~=HDR.SampleRate(1))
        error('Channels with different sampling rate found');
    end
end

fclose(fid);
