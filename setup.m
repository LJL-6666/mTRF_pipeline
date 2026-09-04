function setup()
% SETUP  配置 mTRF 流水线运行环境（main.m 会自动调用，一般无需手动运行）
%
% 功能：
%   1. 将 external/ 下的 FieldTrip 与 mTRF 工具箱加入 MATLAB 路径
%   2. 将 src/ 与 src/utils/ 加入路径
%   3. 检查关键函数是否可用，不可用则报错并提示原因

root = fileparts(mfilename('fullpath'));

%% FieldTrip（ vendored 副本：external/fieldtrip-20181205 ）
ftDir = fullfile(root, 'external', 'fieldtrip-20181205');
if ~exist(ftDir, 'dir')
    error('未找到 FieldTrip：%s\n请确认 external/fieldtrip-20181205 完整存在。', ftDir);
end
addpath(ftDir);
ft_defaults;   % 由 FieldTrip 自己补全其子目录路径

%% mTRF 工具箱（ external/mtrf ，仅核心函数）
mtrfDir = fullfile(root, 'external', 'mtrf');
if ~exist(mtrfDir, 'dir')
    error('未找到 mTRF 工具箱：%s', mtrfDir);
end
addpath(mtrfDir);

%% 本项目源码与资源
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'src', 'utils'));
% 注意：resources/ 不 addpath（新版 MATLAB 中 'resources' 为保留目录名），
% 其中的 .mat 均通过完整路径加载。

%% 关键依赖检查
required = {'ft_preprocessing', 'ft_definetrial', 'ft_resampledata', ...
            'ft_componentanalysis', 'ft_rejectcomponent', 'ft_channelrepair', ...
            'ft_topoplotER', 'trialfun_BDF_zxm', ...
            'mTRFcrossval', 'mTRFtrain', 'mTRFplot', 'U_topoplot'};
missing = required(cellfun(@(f) exist(f, 'file') ~= 2, required));
if ~isempty(missing)
    error('以下依赖函数未找到，请检查 setup：\n  %s', strjoin(missing, '\n  '));
end

fprintf('[setup] 环境就绪：FieldTrip=%s\n', ftDir);
end
