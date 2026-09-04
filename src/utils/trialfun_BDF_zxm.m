function [trl, event] = trialfun_BDF_zxm(cfg)
% TRIALFUN_BDF_ZXM  Neuracle BDF 数据的自定义分段函数
%
% 替代原代码中引用的 ft_trialfun_BDF_zxm（原文件已佚失）。
% 行为与原流水线一致：按 cfg.trialdef.eventvalue 筛选触发事件，
% 以每个触发点为 0 时刻截取 [-prestim, +poststim) 的数据段。
% 第 4 列保留触发值；时间戳超出记录长度的事件被丢弃。
%
% 基于通用的 BDF 触发分段实现改写（按触发值筛选事件、-prestim~+poststim
% 截取、丢弃超界事件），依赖 vendored FieldTrip 的 ft_read_header
%（返回带 offset_in_sec 字段的事件，Neuracle 数据适用）。

prestim  = cfg.trialdef.prestim;
poststim = cfg.trialdef.poststim;

hdr = ft_read_header(cfg.headerfile);
fs  = hdr.Fs;

num_event = numel(hdr.event);
trl   = zeros(num_event, 4);
event = cell(1, num_event);
tri_values = nan(1, num_event);

for i = 1:num_event
    trl(i,1) = round(hdr.event{i}.offset_in_sec*fs) - prestim*fs;
    trl(i,2) = round(hdr.event{i}.offset_in_sec*fs) + poststim*fs - 1;
    trl(i,3) = -prestim*fs;
    if isempty(hdr.event{i}.eventvalue) || ~isnumeric(hdr.event{i}.eventvalue)
        trl(i,4) = NaN;
    else
        trl(i,4) = hdr.event{i}.eventvalue;
        tri_values(i) = hdr.event{i}.eventvalue;
    end
    event{i}.eventtype  = hdr.event{i}.eventtype;
    event{i}.eventvalue = hdr.event{i}.eventvalue;
end

if ~strcmp(cfg.trialdef.eventtype, '?')
    % 只保留指定触发值的事件
    sel = find(ismember(tri_values, unique(cfg.trialdef.eventvalue)));
    trl   = trl(sel, :);
    event = event(sel);
    % 丢弃时间戳超出记录长度的事件
    bad = false(1, numel(event));
    for i = 1:numel(event)
        if trl(i,2) > hdr.nSamples
            fprintf('丢弃事件 %d（超出记录长度 %d 采样点）\n', ...
                    event{i}.eventvalue, hdr.nSamples);
            bad(i) = true;
        end
    end
    trl(bad, :) = [];
    event(bad) = [];
else
    % 仅显示全部触发值及出现次数（探查模式）
    tri_list = unique(tri_values(~isnan(tri_values)));
    for i = 1:numel(tri_list)
        fprintf('trigger %d: %d 次\n', tri_list(i), sum(tri_values == tri_list(i)));
    end
end
end
