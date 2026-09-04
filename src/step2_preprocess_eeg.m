function step2_preprocess_eeg(cfg)
% STEP2_PREPROCESS_EEG  逐被试 EEG 预处理
%
% 输入（data/EEG/<编号>/）：
%   data.bdf + evt.bdf      Neuracle 原始数据
%   ica_reject.txt (可选)   ICA 伪迹成分编号（空格/逗号分隔）；缺失则不剔除
%
% 输出（output/EEG/Each/sub<编号>/EEG_preprocess/）：
%   S0_rawdata.mat     分段后的原始数据（-prestim ~ +poststim s）
%   S1_resample.mat    重采样到 resampleFs1
%   S2_notchfilter.mat 工频陷波
%   S3_ICA.mat         runica 独立成分
%   S4_ICA_removed.mat 剔除伪迹成分后的数据
%   S5_channelrepaired.mat 坏道邻域平均修复
%   S6_reref.mat       平均重参考
%   S7_downsample.mat  重采样到 fsDown
%   S8_filtered.mat    带通（cfg.preproc.bandpass）
%   EEG_analysis.mat   截取时间窗 + 全局 z 归一化（step3 的输入）

eegRoot = fullfile(cfg.paths.dataRoot, 'EEG');

%% 确定被试列表
if isequal(cfg.eeg.subjects, 'all')
    d = dir(eegRoot);
    subs = {d([d.isdir]).name};
    subs = subs(~ismember(subs, {'.', '..'}));
else
    subs = arrayfun(@num2str, cfg.eeg.subjects, 'UniformOutput', false);
end
fprintf('[step2] 共 %d 个被试待处理。\n', numel(subs));

for s = 1:numel(subs)
    subID = subs{s};
    subDir = fullfile(eegRoot, subID);
    outDir = fullfile(cfg.paths.outputRoot, 'EEG', 'Each', ['sub' subID], 'EEG_preprocess');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    finalFile = fullfile(outDir, 'EEG_analysis.mat');
    if cfg.pipeline.skipExisting && exist(finalFile, 'file')
        fprintf('[step2] sub%s 已完成，跳过。\n', subID);
        continue;
    end

    try
        %% S0 读取与分段
        bdf = fullfile(subDir, 'data.bdf');
        if ~exist(bdf, 'file'); error('缺少 %s', bdf); end
        ft_cfg = [];
        ft_cfg.dataset = bdf;
        ft_cfg.channel = cfg.eeg.rawChannels;
        ft_cfg.trialdef.eventtype  = 'trigger';
        ft_cfg.trialdef.eventvalue = cfg.eeg.trigger;
        ft_cfg.trialdef.prestim    = cfg.eeg.prestim;
        ft_cfg.trialdef.poststim   = cfg.eeg.poststim;
        ft_cfg.trialfun = 'trialfun_BDF_zxm';
        ft_cfg = ft_definetrial(ft_cfg);
        S0_rawdata = ft_preprocessing(ft_cfg);
        save(fullfile(outDir, 'S0_rawdata.mat'), 'S0_rawdata', '-v7.3');

        %% S1 重采样
        ft_cfg = []; ft_cfg.resamplefs = cfg.preproc.resampleFs1;
        S1_resample = ft_resampledata(ft_cfg, S0_rawdata);
        save(fullfile(outDir, 'S1_resample.mat'), 'S1_resample');
        clear S0_rawdata

        %% S2 工频陷波
        ft_cfg = []; ft_cfg.bsfilter = 'yes'; ft_cfg.bsfreq = cfg.preproc.notch;
        S2_notchfilter = ft_preprocessing(ft_cfg, S1_resample);
        save(fullfile(outDir, 'S2_notchfilter.mat'), 'S2_notchfilter');
        clear S1_resample

        %% S3 ICA（runica，耗时较长）
        ft_cfg = []; ft_cfg.method = 'runica';
        S3_ICA = ft_componentanalysis(ft_cfg, S2_notchfilter);
        save(fullfile(outDir, 'S3_ICA.mat'), 'S3_ICA', '-v7.3');

        %% S4 剔除伪迹成分（名单来自被试文件夹下的 ica_reject.txt）
        rejectFile = fullfile(subDir, cfg.preproc.icaRejectFile);
        components = read_ica_reject_list(rejectFile);
        if isempty(components)
            warning('[step2] sub%s 未提供 ICA 剔除名单（%s），本被试不剔除成分。', ...
                    subID, cfg.preproc.icaRejectFile);
        end
        ft_cfg = []; ft_cfg.component = components;
        S4_ICA_removed = ft_rejectcomponent(ft_cfg, S3_ICA, S2_notchfilter);
        save(fullfile(outDir, 'S4_ICA_removed.mat'), 'S4_ICA_removed');
        clear S3_ICA S2_notchfilter

        %% S5 坏道修复（邻域平均）
        nb = load(fullfile(cfg.paths.root, 'resources', 'eeg_neighbours_29.mat'));
        ft_cfg = [];
        ft_cfg.method = 'average';
        ft_cfg.neighbours = nb.neighbours;
        % ft_channelrepair 需要电极位置信息（即使是 average 法），由布局文件提供
        ft_cfg.layout = cfg.preproc.repairLayout;
        S5_channelrepaired = ft_channelrepair(ft_cfg, S4_ICA_removed);
        save(fullfile(outDir, 'S5_channelrepaired.mat'), 'S5_channelrepaired');
        clear S4_ICA_removed

        %% S6 平均重参考
        ft_cfg = []; ft_cfg.reref = 'yes'; ft_cfg.refchannel = cfg.preproc.rerefChans;
        S6_reref = ft_preprocessing(ft_cfg, S5_channelrepaired);
        save(fullfile(outDir, 'S6_reref.mat'), 'S6_reref');
        clear S5_channelrepaired

        %% S7 重采样到最终采样率
        ft_cfg = []; ft_cfg.resamplefs = cfg.preproc.fsDown;
        S7_downsample = ft_resampledata(ft_cfg, S6_reref);
        save(fullfile(outDir, 'S7_downsample.mat'), 'S7_downsample');
        clear S6_reref

        %% S8 带通滤波
        ft_cfg = [];
        ft_cfg.bpfilter = 'yes'; ft_cfg.bpfreq = cfg.preproc.bandpass;
        ft_cfg.bpfilttype = 'fir'; ft_cfg.bpfiltdir = 'onepass';
        ft_cfg.bpfiltord = cfg.preproc.filterOrder;
        S8_filtered = ft_preprocessing(ft_cfg, S7_downsample);
        save(fullfile(outDir, 'S8_filtered.mat'), 'S8_filtered');
        clear S7_downsample

        %% 截取时间窗 + 全局 z 归一化
        fq = cfg.preproc.fsDown;
        nTrial = numel(S8_filtered.trial);
        nChan  = size(S8_filtered.trial{1}, 1);
        idx = cfg.analysis.timeWin(1)*fq + 1 : ...
              min(cfg.analysis.timeWin(2)*fq, size(S8_filtered.trial{1}, 2));

        EEG_analysis = cell(nTrial, 1);
        for i = 1:nTrial
            EEG_analysis{i} = S8_filtered.trial{i}(1:nChan, idx)';   % 转置为 时间 x 通道
        end
        allvals = cell2mat(EEG_analysis);
        m = mean(allvals(:)); sd = std(allvals(:));
        for i = 1:nTrial
            EEG_analysis{i} = (EEG_analysis{i} - m) / sd;
        end
        save(finalFile, 'EEG_analysis');
        fprintf('[step2] sub%s 完成（%d 试次，%d 通道）。\n', subID, nTrial, nChan);

    catch ME
        warning('[step2] sub%s 处理失败: %s', subID, ME.message);
    end
end
fprintf('[step2] 全部完成。\n');
end


function components = read_ica_reject_list(fname)
% 读取 ICA 剔除成分名单；文件不存在或为空返回 []
components = [];
if exist(fname, 'file') ~= 2; return; end
txt = strtrim(fileread(fname));
if isempty(txt); return; end
components = str2double(regexp(txt, '[0-9]+', 'match'))';
components = components(~isnan(components));
end
