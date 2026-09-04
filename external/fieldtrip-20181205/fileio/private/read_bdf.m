function dat = read_bdf(file_name, hdr, begsample, endsample, chanindx)
% Implemented based on read_biosemi_bdf.m file in FieldTrip toolbox
% To replace the file with the same name in FieldTrip
%
% Compatible with the Neuracle Recordings, both old and new version
% old version: data and event in the same file
% new version: data in data.bdf and event in evt.bdf, both in the same directory
%
% this function can be used alone for reading BDF+ data file, as well as integrated with FieldTrip
% usage:
% hdr = read_bdf(file_name);
% dat = read_bdf(file_name,hdr,begsample,endsample, chanindx);
% To read all data, set begsample = 1, endsample = hdr.nSamples, and chanindx = 1:length(hdr.label);
%
% FieldTrip usage: 
% 1. replace the [FieldTripRoot]/fileio/private/read_biosemi_bdf.m with the read_bdf.m file, rename it to 'read_biosemi_bdf.m'
% 2. place read_biosemi_bdf1.m and read_biosemi_bdf2.m to [FieldTripRoot]/fileio/private]
% 3. place trialfun_BDF.m in [FieldTripRoot]/trialfun
%
% For extracting the EEG events in FieldTrip, trialfun_BDF.m is also needed
% usage (an example for listing all the events):
% cfg = [];
% cfg.dataset = file_name;
% cfg.trialdef.eventtype  = '?';
% cfg.trialfun = 'trialfun_BDF';
% cfg_trl = ft_definetrial(cfg);
%
% 2017-01-01, Dan Zhang, dzhang@tsinghua.edu.cn

% 2018-03-25, V23, trialfun_BDF.m updated, for empty event from 8-channel
% Neuracle

% 2023-06-10, V26, read_biosemi_bdf2.m updated, for duration fixation

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
%if the evt.bdf file does not exist, then switch back to the older version
%(data and events in the same file)
if(~exist(EVTFILENAME))
    bdf_ver = 1;
else
    bdf_ver = 2;
end

if nargin==1
    if(bdf_ver == 1)
        dat = read_biosemi_bdf1(file_name);
        disp('old Neuracle file format detected.');
    elseif(bdf_ver == 2)
        dat = read_biosemi_bdf2(file_name);
        disp('new Neuracle file format detected.');
    end
else
    if(bdf_ver == 1)
        dat = read_biosemi_bdf1(file_name,hdr,begsample,endsample, chanindx);
    elseif(bdf_ver == 2)
        dat = read_biosemi_bdf2(file_name,hdr,begsample,endsample, chanindx);
    end
end
