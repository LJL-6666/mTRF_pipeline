function cfg = config_default()
% CONFIG_DEFAULT  mTRF 分析流水线全部参数（唯一需要修改的文件）
%
% 换一批新数据时，只需：
%   1. 按 data/ 目录约定摆放数据（见 README.md 第 2 节）
%   2. 修改本文件中的参数
%   3. 运行 main.m
%
% 任何脚本内部都不再含硬编码路径或参数。

cfg = struct();

%% ===== 1. 路径（迁移后必查）=====
% 项目根目录（默认自动获取本文件所在目录，一般无需修改）
cfg.paths.root       = fileparts(mfilename('fullpath'));
% 输入数据根目录：其下应有 audio/ 和 EEG/ 两个子目录
cfg.paths.dataRoot   = fullfile(cfg.paths.root, 'data');
% 输出根目录（自动生成）
cfg.paths.outputRoot = fullfile(cfg.paths.root, 'output');

%% ===== 2. 刺激（音频）参数 =====
cfg.stim.nAudio   = 28;          % 音频个数，文件名须为 1.wav ... N.wav
cfg.stim.fsAudio  = 44100;       % 音频原始采样率 (Hz)

%% ===== 3. EEG 采集与分段参数 =====
cfg.eeg.subjects      = 'all';   % 'all' = 处理 data/EEG 下全部编号文件夹；或给编号向量如 [2 3 5]
cfg.eeg.rawChannels   = 1:31;    % 读取的原始通道（bdf 通道序号）
cfg.eeg.trigger       = 21;      % 分段用触发码
cfg.eeg.prestim       = 1;       % 触发前时长 (秒)
cfg.eeg.poststim      = 40;      % 触发后时长 (秒)
% 行为 CSV：在被试文件夹内按文件名特征查找，须包含刺激播放顺序列
cfg.eeg.csvPattern    = 'rating';      % CSV 文件名特征（找不到则退回该文件夹第一个 .csv）
cfg.eeg.orderColumn   = 'videoIndex';  % 刺激播放顺序的列名

%% ===== 4. EEG 预处理参数（step2）=====
cfg.preproc.resampleFs1 = 250;        % 第一级重采样 (Hz)
cfg.preproc.notch       = [48 51];    % 工频陷波 (Hz)
% ICA 伪迹成分剔除名单：每个被试文件夹下放 ica_reject.txt（数字空格/逗号分隔）。
% 文件缺失或为空 -> 不剔除（与原始代码行为一致），但会给出警告。
% 名单需人工查看 ICA 成分后确定（README 第 4 节有操作流程）。
cfg.preproc.icaRejectFile = 'ica_reject.txt';
% 坏道修复用的电极布局（ft_channelrepair 必需）：原版为新 FieldTrip 的 easycapM1 布局，
% 已存为 resources/easycapM1.mat；换帽子时替换。
cfg.preproc.repairLayout  = fullfile(cfg.paths.root, 'resources', 'easycapM1.mat');
cfg.preproc.rerefChans    = 1:29;     % 平均重参考使用的通道
cfg.preproc.fsDown        = 128;      % 最终采样率 (Hz)，TRF 与包络均用此率
cfg.preproc.bandpass      = [4 8];    % 带通频段 (Hz)，当前为 theta；换频段改这里
cfg.preproc.filterOrder   = 64;       % FIR 滤波阶数（单向）

%% ===== 5. 分析时间窗（step1/step2 共用，单位：秒）=====
% 音频与 EEG 截取相同的时间区间做 TRF。
% 注意：EEG 分段起点为 -1s（prestim），截取按分段内样本索引进行，
% 与原始代码行为完全一致（详见 README 第 6 节"已知特性"）。
cfg.analysis.timeWin = [5 40];

%% ===== 6. TRF 参数（step3）=====
cfg.trf.lambdas = 10.^(-1:3);  % 岭回归正则参数候选
cfg.trf.lagWin  = [-500 500];  % 时间延迟范围 (ms)
cfg.trf.dir     = 1;           % 1 = 前向模型（刺激 -> EEG）

%% ===== 7. 绘图参数（step4）=====
cfg.plot.channels = [2 13];        % TRF 波形图展示的通道（对应 resources/label31.mat 的序号）
cfg.plot.lagXlim  = [-800 800];    % 波形图横轴范围 (ms)
% 地形图 layout：默认用 external 内 FieldTrip 自带的 easycap-M1.txt
cfg.plot.layoutFile = fullfile(cfg.paths.root, 'external', 'fieldtrip-20181205', ...
                               'template', 'electrode', 'easycap-M1.txt');

%% ===== 8. 流程开关 =====
cfg.pipeline.doStep1 = true;   % 音频包络提取（全部音频一次完成）
cfg.pipeline.doStep2 = true;   % EEG 预处理（逐被试）
cfg.pipeline.doStep3 = true;   % TRF 建模（逐被试）
cfg.pipeline.doStep4 = true;   % 绘图（逐被试）
cfg.pipeline.skipExisting = true;  % 最终产物已存在时跳过该被试该步骤

end
