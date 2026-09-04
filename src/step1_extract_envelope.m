function step1_extract_envelope(cfg)
% STEP1_EXTRACT_ENVELOPE  音频 -> Hilbert 包络 -> 重采样 -> 时间窗截取 -> 全局归一化
%
% 输入（data/audio/）：1.wav ... N.wav（N = cfg.stim.nAudio）
% 输出（output/Audio/）：
%   Audiodataraw.mat        原始音频（每 cell 一条，取第 1 声道）
%   Envelope_raw.mat        重采样到 fsDown 的包络
%   Envelope_analysis.mat   截取时间窗并全局 z 归一化后的包络（step3 的输入）

audioDir = fullfile(cfg.paths.dataRoot, 'audio');
outDir   = fullfile(cfg.paths.outputRoot, 'Audio');
if ~exist(outDir, 'dir'); mkdir(outDir); end

analysisFile = fullfile(outDir, 'Envelope_analysis.mat');
if cfg.pipeline.skipExisting && exist(analysisFile, 'file')
    fprintf('[step1] %s 已存在，跳过。\n', analysisFile);
    return;
end

fq_old = cfg.stim.fsAudio;
fq_new = cfg.preproc.fsDown;

%% 读取全部音频
Audiodataraw = cell(cfg.stim.nAudio, 1);
for i = 1:cfg.stim.nAudio
    f = fullfile(audioDir, sprintf('%d.wav', i));
    if ~exist(f, 'file')
        error('[step1] 缺少音频文件: %s', f);
    end
    a = audioread(f);
    Audiodataraw{i} = a(:, 1);   % 取第 1 声道
end
save(fullfile(outDir, 'Audiodataraw.mat'), 'Audiodataraw');
fprintf('[step1] 已读取 %d 个音频。\n', numel(Audiodataraw));

%% 提取包络（Hilbert 幅值）并重采样
Envelope_raw = cell(cfg.stim.nAudio, 1);
for i = 1:cfg.stim.nAudio
    Envelope_raw{i} = resample(abs(hilbert(Audiodataraw{i})), fq_new, fq_old);
end
save(fullfile(outDir, 'Envelope_raw.mat'), 'Envelope_raw');

%% 截取分析时间窗
idx = cfg.analysis.timeWin(1)*fq_new + 1 : cfg.analysis.timeWin(2)*fq_new;
Envelope_analysis = cell(numel(Envelope_raw), 1);
for i = 1:numel(Envelope_raw)
    if length(Envelope_raw{i}) < max(idx)
        warning('[step1] 音频 %d 短于所选时间窗，使用其全部长度。', i);
        Envelope_analysis{i} = Envelope_raw{i};
    else
        Envelope_analysis{i} = Envelope_raw{i}(idx);
    end
end

%% 全局 z 归一化（所有音频拼接后的均值/方差）
allvals = cell2mat(Envelope_analysis);
m = mean(allvals(:));
s = std(allvals(:));
for i = 1:numel(Envelope_analysis)
    Envelope_analysis{i} = (Envelope_analysis{i} - m) / s;
end

save(analysisFile, 'Envelope_analysis');
fprintf('[step1] 完成 -> %s\n', analysisFile);
end
