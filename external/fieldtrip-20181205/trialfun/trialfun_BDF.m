function [trl, event] = trialfun_BDF(cfg)
%requiring fields:
% for trial definition:
% cfg.trialdef.prestim - prestim time before the trigger
% cfg.trialdef.poststim - poststim time after the trigger
% trialfun for Neusen W32 amplifier, bDF+ format

% Dan Zhang, dzhang@tsinghua.edu.cn, 2015-12-16

% 2015-12-28, updated for occasions when trigger timestampes exceed the EEG
% recordings, Dan Zhang

% Jingjing Chen, chen-jj15@mails.tsinghua.edu.cn 2017-10-31
% updated for compatible with the new version of EEGRecorder
% recordings, Jingjing Chen

% Xin Hu, hu-x18@mails.tsinghua.edu.cn 2018-10-09
% updated for occasions when empty triggers appear abnormally

% Dan Zhang, dzhang@tsinghua.edu.cn 2023-04-10
% updated for trl with the 4th column for event values

prestim = cfg.trialdef.prestim;
poststim = cfg.trialdef.poststim;
% read the header, contains the sampling frequency
hdr = ft_read_header(cfg.headerfile);

fs = hdr.Fs;
num_event = length(hdr.event);
trl = zeros(num_event,3);
event = cell(1,num_event);
tri_values = zeros(1,num_event);
for i = 1:num_event
    trl(i,1) = round(hdr.event{i}.offset_in_sec*fs)-prestim*fs;
    trl(i,2) = round(hdr.event{i}.offset_in_sec*fs)+poststim*fs-1;
    trl(i,3) = -prestim*fs;
    if(isempty(hdr.event{i}.eventvalue) || ~isnumeric(hdr.event{i}.eventvalue))
        trl(i,4) = NaN;
    else
        trl(i,4) = hdr.event{i}.eventvalue;
    end
    event{i}.eventtype = hdr.event{i}.eventtype;
    event{i}.eventvalue = hdr.event{i}.eventvalue;
    if isempty(hdr.event{i}.eventvalue)~=1
    tri_values(i) = hdr.event{i}.eventvalue;
    else
        disp('!!! Warning: abnormal empty trigger found, press any key to continue reading without empty triggers');
        pause;
    end
end
%return only the events with the required eventvalue
if(~strcmp(cfg.trialdef.eventtype,'?'))
    event_sel_list = unique(cfg.trialdef.eventvalue);
    num_event = length(event_sel_list);
    trial_sel = [];
    for i = 1:num_event
        trial_sel=[trial_sel find(tri_values==event_sel_list(i))];
    end
    trl=trl(trial_sel,:);
    event=event(trial_sel);
    %check if the trigger timestampes exceed the EEG recording
    trial_sel2 = [];
    for i = 1:length(event)
       if(max(trl(i,:)) > hdr.nSamples)
           disp(['Discarding event ' num2str(event{i}.eventvalue) ... 
               ' with offset ' num2str(trl(i,1) - trl(i,3)) ' (exceeding the EEG recording with ' num2str(hdr.nSamples) ' samples']);
           trial_sel2 = [trial_sel2 i];
       end
    end
    trl(trial_sel2,:) = [];
    event(trial_sel2) = [];
else
    %display all possible events and their number of appearances
    tri_list = unique(tri_values);
    for i = 1:length(tri_list)
       disp(['trigger ' num2str(tri_list(i)) ': ' num2str(length(find(tri_values == tri_list(i)))) ' times']); 
    end
end
