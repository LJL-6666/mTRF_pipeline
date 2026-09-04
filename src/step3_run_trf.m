function step3_run_trf(cfg)
% STEP3_RUN_TRF  逐被试 TRF 建模
%
% 输入：
%   output/Audio/Envelope_analysis.mat                  step1 产物
%   output/EEG/Each/sub<编号>/EEG_preprocess/EEG_analysis.mat   step2 产物
%   data/EEG/<编号>/*rating*.csv                        行为文件（含刺激播放顺序列）
%
% 输出（output/EEG/Each/sub<编号>/TRF_results/mTRF_model.mat）：
%   mTRF_model 结构体，字段：
%     .CV     交叉验证结果（含各 lambda 的预测相关 r）
%     .r      最优 lambda 下各通道平均 r（地形图用）
%     .t      TRF 时间延迟轴 (ms)
%     .model  mTRFtrain 训练出的前向模型
%     .lambda 选出的最优正则参数

audioFile = fullfile(cfg.paths.outputRoot, 'Audio', 'Envelope_analysis.mat');
if exist(audioFile, 'file') ~= 2
    error('[step3] 未找到 %s，请先运行 step1。', audioFile);
end
S = load(audioFile); stim_all = S.Envelope_analysis;

eegEach = fullfile(cfg.paths.outputRoot, 'EEG', 'Each');
d = dir(fullfile(eegEach, 'sub*'));
subs = {d([d.isdir]).name};
if isempty(subs); error('[step3] %s 下没有 sub* 文件夹，请先运行 step2。', eegEach); end

Fs      = cfg.preproc.fsDown;
lambdas = cfg.trf.lambdas;

for s = 1:numel(subs)
    subTag  = subs{s};                 % 如 'sub33'
    subNum  = subTag(4:end);           % 如 '33'
    saveDir = fullfile(eegEach, subTag, 'TRF_results');
    modelFile = fullfile(saveDir, 'mTRF_model.mat');

    if cfg.pipeline.skipExisting && exist(modelFile, 'file')
        fprintf('[step3] %s 已完成，跳过。\n', subTag);
        continue;
    end

    try
        %% 读取刺激播放顺序（行为 CSV）
        csvDir = fullfile(cfg.paths.dataRoot, 'EEG', subNum);
        csvFile = find_rating_csv(csvDir, cfg.eeg.csvPattern);
        if isempty(csvFile)
            warning('[step3] %s 未找到行为 CSV（%s），跳过。', subTag, csvDir);
            continue;
        end
        T = readtable(csvFile);
        if ~ismember(cfg.eeg.orderColumn, T.Properties.VariableNames)
            warning('[step3] %s 的 CSV 缺少 %s 列，跳过。', subTag, cfg.eeg.orderColumn);
            continue;
        end
        video_order = T.(cfg.eeg.orderColumn);

        %% 加载 EEG
        eegFile = fullfile(eegEach, subTag, 'EEG_preprocess', 'EEG_analysis.mat');
        if exist(eegFile, 'file') ~= 2
            warning('[step3] 未找到 %s 的 EEG_analysis.mat，跳过。', subTag);
            continue;
        end
        E = load(eegFile); resp = E.EEG_analysis;

        %% 按播放顺序重排刺激
        if max(video_order) > numel(stim_all)
            warning('[step3] %s 的 videoIndex 超出音频数量，跳过。', subTag);
            continue;
        end
        stim = stim_all(video_order);

        %% 交叉验证选 lambda
        [CV, t] = mTRFcrossval(stim, resp, Fs, cfg.trf.dir, ...
                               cfg.trf.lagWin(1), cfg.trf.lagWin(2), lambdas);
        [~, bestIdx] = max(mean(mean(CV.r, 1), 3));
        bestLambda = lambdas(bestIdx);

        %% 训练最终模型
        model = mTRFtrain(stim, resp, Fs, cfg.trf.dir, ...
                          cfg.trf.lagWin(1), cfg.trf.lagWin(2), bestLambda);

        mTRF_model = struct();
        mTRF_model.CV     = CV;
        mTRF_model.r      = squeeze(mean(CV.r(:, bestIdx, :)));
        mTRF_model.t      = t;
        mTRF_model.model  = model;
        mTRF_model.lambda = bestLambda;

        if ~exist(saveDir, 'dir'); mkdir(saveDir); end
        save(modelFile, 'mTRF_model');
        fprintf('[step3] %s 完成：最优 lambda = %g，平均 r = %.3f\n', ...
                subTag, bestLambda, mean(mTRF_model.r));

    catch ME
        warning('[step3] %s 处理失败: %s', subTag, ME.message);
    end
end
fprintf('[step3] 全部完成。\n');
end


function csvFile = find_rating_csv(csvDir, pattern)
% 在 csvDir 下优先找文件名含 pattern 的 csv；找不到则退回第一个 csv
csvFile = '';
files = dir(fullfile(csvDir, '*.csv'));
if isempty(files); return; end
hit = find(contains({files.name}, pattern), 1);
if isempty(hit); hit = 1; end
csvFile = fullfile(csvDir, files(hit).name);
end
