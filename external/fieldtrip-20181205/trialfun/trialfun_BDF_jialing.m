function [trl, event] = trialfun_BDF(cfg)
% trialfun_BDF - 用于在BDF数据中定义trials,专门处理trigger21和trigger22配对
% 输入:
%   cfg.headerfile - BDF文件的路径
%   cfg.trialdef.prestim - prestim time (未使用，保持兼容性)
%   cfg.trialdef.poststim - poststim time (未使用，保持兼容性)
% 输出:
%   trl - [开始采样点, 结束采样点, offset, trigger值]
%   event - 包含每个trial事件信息的单元格数组

% 读取头文件
hdr = ft_read_header(cfg.headerfile);
fs = hdr.Fs;

% 清理空事件
event_values = cell(1, length(hdr.event));
for i = 1:length(hdr.event)
    if isfield(hdr.event{i}, 'eventvalue')
        event_values{i} = hdr.event{i}.eventvalue;
    else
        event_values{i} = [];
    end
end
valid_events = ~cellfun(@isempty, event_values);
hdr.event = hdr.event(valid_events);
event_values = event_values(valid_events);

% 找出所有trigger21和trigger22的位置
trigger_positions = zeros(length(hdr.event), 2); % [类型, 位置]
trigger_count = 0;

for i = 1:length(hdr.event)
    if isnumeric(hdr.event{i}.eventvalue) && ...
       (hdr.event{i}.eventvalue == 21 || hdr.event{i}.eventvalue == 22)
        trigger_count = trigger_count + 1;
        trigger_positions(trigger_count, 1) = hdr.event{i}.eventvalue;
        trigger_positions(trigger_count, 2) = round(hdr.event{i}.offset_in_sec * fs);
    end
end
trigger_positions = trigger_positions(1:trigger_count, :);

% 初始化输出
num_segments = 0;
trl = [];
event = {};

% 查找trigger21和trigger22的配对
for i = 1:size(trigger_positions, 1)-1
    % 如果当前是trigger21，且下一个是trigger22
    if trigger_positions(i, 1) == 21 && trigger_positions(i+1, 1) == 22
        num_segments = num_segments + 1;
        
        % 计算采样点
        start_sample = trigger_positions(i, 2);
        end_sample = trigger_positions(i+1, 2);
        
        % 检查数据范围
        if end_sample > hdr.nSamples
            warning('段 %d 超出数据范围，跳过此段', num_segments);
            continue;
        end
        
        % 添加到trial矩阵 [start, end, offset, triggervalue]
        trl(num_segments, :) = [start_sample, end_sample, 0, 21];
        
        % 添加事件信息（保持与trialfun_BDF格式一致）
        event{num_segments}.type = 'segment';
        event{num_segments}.value = num_segments;
        event{num_segments}.sample = start_sample;
        event{num_segments}.timestamp = start_sample / fs;
        event{num_segments}.offset = 0;
        event{num_segments}.duration = end_sample - start_sample;
        
        % 调试信息
        fprintf('找到段 %d: 开始=%.2fs, 结束=%.2fs, 持续时间=%.2fs\n', ...
            num_segments, start_sample/fs, end_sample/fs, ...
            (end_sample - start_sample)/fs);
    end
end

% 检查是否找到有效配对
if isempty(trl)
    warning('未找到有效的trigger21-22配对');
else
    fprintf('总共找到 %d 个有效数据段\n', num_segments);
end

% 如果需要显示所有触发器类型和出现次数
if strcmp(cfg.trialdef.eventtype, '?')
    unique_triggers = unique([trigger_positions(:,1)]);
    for i = 1:length(unique_triggers)
        count = sum(trigger_positions(:,1) == unique_triggers(i));
        fprintf('触发器 %d: 出现 %d 次\n', unique_triggers(i), count);
    end
end

end