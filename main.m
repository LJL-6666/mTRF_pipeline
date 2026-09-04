% MAIN  mTRF 分析流水线端到端入口
%
% 用法：
%   1. 按 README 摆放数据、修改 config_default.m
%   2. 在 MATLAB 中 cd 到本目录，运行:  main
%
% 流程：
%   step1  音频 -> Hilbert 包络 -> 重采样 -> 截取 -> 归一化
%   step2  每被试 bdf -> 分段 -> 滤波/ICA/重参考 -> 带通 -> 截取 -> 归一化
%   step3  每被试 刺激按播放顺序重排 -> 交叉验证选 lambda -> 训练 mTRF 模型
%   step4  每被试 TRF 波形图 + 地形图

clear; clc; close all;

setup();                       % 配置路径并检查依赖
cfg = config_default();        % 读取全部参数

tStart = tic;

if cfg.pipeline.doStep1
    fprintf('\n========== STEP 1: 音频包络提取 ==========\n');
    step1_extract_envelope(cfg);
end

if cfg.pipeline.doStep2
    fprintf('\n========== STEP 2: EEG 预处理 ==========\n');
    step2_preprocess_eeg(cfg);
end

if cfg.pipeline.doStep3
    fprintf('\n========== STEP 3: TRF 建模 ==========\n');
    step3_run_trf(cfg);
end

if cfg.pipeline.doStep4
    fprintf('\n========== STEP 4: 结果绘图 ==========\n');
    step4_visualize(cfg);
end

fprintf('\n全部完成，总耗时 %.1f 分钟。结果见: %s\n', toc(tStart)/60, cfg.paths.outputRoot);
