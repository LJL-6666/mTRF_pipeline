function step4_visualize(cfg)
% STEP4_VISUALIZE  逐被试绘制 TRF 波形图与地形图
%
% 输入：output/EEG/Each/sub<编号>/TRF_results/mTRF_model.mat（step3 产物）
% 输出：output/figures/TRF_plot_sub<编号>.png
%       output/figures/Topography_sub<编号>.png

figDir = fullfile(cfg.paths.outputRoot, 'figures');
if ~exist(figDir, 'dir'); mkdir(figDir); end

L = load(fullfile(cfg.paths.root, 'resources', 'label31.mat'));
label31 = L.label31;

eegEach = fullfile(cfg.paths.outputRoot, 'EEG', 'Each');
d = dir(fullfile(eegEach, 'sub*'));
subs = {d([d.isdir]).name};

for s = 1:numel(subs)
    subTag = subs{s};
    modelFile = fullfile(eegEach, subTag, 'TRF_results', 'mTRF_model.mat');
    if exist(modelFile, 'file') ~= 2
        fprintf('[step4] %s 无模型文件，跳过。\n', subTag);
        continue;
    end

    fig1 = fullfile(figDir, ['TRF_plot_' subTag '.png']);
    fig2 = fullfile(figDir, ['Topography_' subTag '.png']);
    if cfg.pipeline.skipExisting && exist(fig1, 'file') && exist(fig2, 'file')
        fprintf('[step4] %s 图已存在，跳过。\n', subTag);
        continue;
    end

    try
        M = load(modelFile); mTRF_model = M.mTRF_model;

        %% TRF 波形图（选定通道）
        chns = cfg.plot.channels;
        chns = chns(chns <= numel(label31));
        figure('color', 'w'); hold on;
        for c = chns
            mTRFplot(mTRF_model.model, 'trf', [], c, cfg.plot.lagXlim);
        end
        legend(label31(chns), 'Fontname', 'Arial', 'Fontsize', 12);
        title(['语音 TRF - 被试 ' subTag], 'Fontname', 'SimHei', 'Fontsize', 14);
        ylabel('幅度 (a.u.)', 'Fontname', 'SimHei', 'Fontsize', 12);
        xlabel('时间延迟 (ms)', 'Fontname', 'SimHei', 'Fontsize', 12);
        set(gca, 'linewidth', 1.5);
        saveas(gcf, fig1);

        %% 地形图（各通道 r 值分布）
        figure('color', 'w', 'Position', [300, 300, 300, 300]);
        U_topoplot(mTRF_model.r, cfg.plot.layoutFile, label31);
        title(['地形图 - 被试 ' subTag], 'Fontname', 'SimHei', 'Fontsize', 14);
        saveas(gcf, fig2);

        close all;
        fprintf('[step4] %s 完成。\n', subTag);

    catch ME
        warning('[step4] %s 绘图失败: %s', subTag, ME.message);
        close all;
    end
end
fprintf('[step4] 全部完成。图片保存在 %s\n', figDir);
end
