# mTRF 分析流水线（可迁移复现版）

从 `mTRF分析代码` 整理出的方法论代码：**语音包络 → EEG → 前向 TRF 模型 → 可视化** 的端到端流水线。
所有依赖已打包在项目内，迁移到新机器后按本说明配置即可直接复现，无需调试。

---

## 1. 环境要求

| 项目 | 要求 |
|---|---|
| MATLAB | R2018b 及以上（需 Signal Processing Toolbox：hilbert/resample） |
| FieldTrip | **已内置** `external/fieldtrip-20181205`（含 `template/electrode/easycap-M1.txt`） |
| mTRF 工具箱 | **已内置** `external/mtrf`（21 个核心函数 + LICENSE） |
| runica（ICA） | **已内置** `src/utils/runica.m`（来自 EEGLAB，自包含无依赖） |
| 操作系统 | Windows / Linux / macOS 均可（代码全部用 fullfile 拼路径） |

> 克隆后无需再装 FieldTrip / mTRF；二者已随仓库携带（许可证见各自目录）。
> 仓库附带 **案例结果**（`output/figures/` 与各被试 `TRF_results/`），便于对照；原始 `data/` 与 EEG 预处理中间文件不入库，需自备数据才能端到端重跑。

---

## 2. 数据摆放约定（换数据只看这里）

```
data/
├─ audio/
│   ├─ 1.wav
│   ├─ 2.wav
│   └─ ... N.wav            （N = config 里 cfg.stim.nAudio，44100Hz）
└─ EEG/
    ├─ 2/                    ← 被试编号文件夹（纯数字命名）
    │   ├─ data.bdf          ← Neuracle 原始数据（必须叫这个名）
    │   ├─ evt.bdf
    │   ├─ exp1_xxx_rating.csv   ← 行为文件，须含刺激播放顺序列（默认列名 videoIndex）
    │   └─ ica_reject.txt    ← 【可选】ICA 伪迹成分编号，如 "1 5 17"（见第 4 节）
    ├─ 3/
    └─ ...
```

三点硬性要求：
1. 音频文件名必须是 `编号.wav`（1 到 N 连续）；
2. 行为 CSV 中须有播放顺序列（默认 `videoIndex`，列名可在 config 改）；
3. bdf 中的分段触发码与 config 的 `cfg.eeg.trigger`（默认 21）一致。

---

## 3. 快速开始

```matlab
cd mTRF_pipeline          % 项目根目录
% 打开 config_default.m，按注释修改参数（音频数、trigger、时间窗、频段等）
main                      % 端到端运行 step1~step4
```

运行后输出：

```
output/
├─ Audio/
│   ├─ Audiodataraw.mat / Envelope_raw.mat / Envelope_analysis.mat
├─ EEG/Each/sub<编号>/
│   ├─ EEG_preprocess/S0_rawdata.mat ... S8_filtered.mat, EEG_analysis.mat
│   └─ TRF_results/mTRF_model.mat     （CV / r / t / model / lambda）
└─ figures/
    ├─ TRF_plot_sub<编号>.png          （TRF 波形图）
    └─ Topography_sub<编号>.png        （各通道 r 值地形图）
```

- 重复运行 `main` 时，已存在的产物自动跳过（`cfg.pipeline.skipExisting`）。
- 只改了某被试数据：删掉其 `output/EEG/Each/sub<编号>/` 后重跑即可。
- 只改 TRF 参数：设 `cfg.pipeline.doStep1=false; doStep2=false;` 只跑 step3/4。

---

## 4. 换一批新数据的完整操作清单

1. **摆数据**：按第 2 节约定放入 `data/`。
2. **改参数**：`config_default.m` 中重点检查：
   - `cfg.stim.nAudio` 音频个数
   - `cfg.eeg.trigger` 触发码、`prestim/poststim` 分段窗
   - `cfg.eeg.rawChannels` / `rerefChans`（通道数不同必改）
   - `cfg.preproc.bandpass` 频段（默认 theta 4–8Hz）
   - `cfg.analysis.timeWin` 分析时间窗（默认 5–40s）
   - `cfg.trf.lagWin` / `lambdas` TRF 延迟窗与正则候选
3. **ICA 剔除名单**（影响复现质量的关键步骤，原为人工操作）：
   - 先不设 `ica_reject.txt` 跑一遍 step2（得到 `S3_ICA.mat`）；
   - 用 `ft_databrowser` / `ft_topoplotIC` 查看成分，把眼电/肌电成分编号写入
     `data/EEG/<编号>/ica_reject.txt`（如 `1 5 17`）；
   - 删除该被试 output 目录，重跑 step2~4。
   - 没有名单时行为与原始代码一致（不剔除），但会有警告提示。
4. **跑 `main`**。

### 换采集设备（帽子/通道布局不同）时，额外替换 `resources/` 下三样：

| 文件 | 作用 | 不匹配时的处理 |
|---|---|---|
| `label31.mat` | 通道名（绘图 legend/地形图标签） | 换成新帽子的通道名 cell 数组 |
| `eeg_neighbours_29.mat` | 坏道修复的邻域定义 | 用 `ft_prepare_neighbours` 重新生成 |
| `cfg.plot.layoutFile` | 地形图电极布局 | 指向新帽子的 layout/electrode 文件 |

---

## 5. 项目结构与各文件职责

```
mTRF_pipeline/
├─ main.m                        端到端入口（唯一需要运行的脚本）
├─ setup.m                       路径配置与依赖自检（main 自动调用）
├─ config_default.m              全部参数（唯一需要修改的文件）
├─ README.md                     本说明
├─ src/
│   ├─ step1_extract_envelope.m  音频 -> Hilbert 包络 -> 重采样128Hz -> 截取 -> 全局z归一化
│   ├─ step2_preprocess_eeg.m    bdf -> 分段 -> 250Hz -> 陷波 -> ICA -> 剔成分
│   │                            -> 坏道修复 -> 平均重参考 -> 128Hz -> 带通 -> 截取归一化
│   ├─ step3_run_trf.m           刺激按播放顺序重排 -> mTRFcrossval选λ -> mTRFtrain -> 模型
│   ├─ step4_visualize.m         TRF 波形图 + r 值地形图
│   └─ utils/
│       ├─ U_topoplot.m          地形图绘制（封装 ft_topoplotER）
│       └─ trialfun_BDF_zxm.m    Neuracle BDF 分段函数（替代已佚失的 ft_trialfun_BDF_zxm，
│                                行为与通用 BDF trialfun 一致：按触发值截取 -prestim~+poststim）
├─ external/
│   ├─ fieldtrip-20181205/       FieldTrip 完整副本（约 158MB，含模板电极文件；已入库）
│   └─ mtrf/                     mTRF 核心函数 21 个 + LICENSE/README/CITATION
├─ resources/
│   ├─ eeg_neighbours_29.mat     29 通道邻域定义
│   └─ label31.mat               31 通道名
├─ data/                         输入数据（本地自备，不入库）
└─ output/
    ├─ figures/                  案例图（已入库）：TRF / 地形图 PNG
    └─ EEG/Each/sub*/TRF_results/  案例模型（已入库）；EEG_preprocess/ 中间文件不入库
```

---

## 6. 已知特性与注意事项（复现必读）

1. **时间对齐**：EEG 分段起点为触发前 1s（prestim=1），step2 按分段内样本索引截取
   `5*fs+1 : 40*fs`，即实际对应触发后约 4–39s；音频截取 5–40s。二者存在约 1s 的
   固定偏移——这是原始代码的既有行为，本版**原样保留**以保证结果可比。如需严格对齐，
   把 `cfg.eeg.prestim` 改为 0 并同步调整 `cfg.analysis.timeWin`。
2. **trialfun 替换**：原代码引用的 `ft_trialfun_BDF_zxm` 原文件已佚失，本版用行为等价的
   `src/utils/trialfun_BDF_zxm.m` 替代（按触发值筛选、-prestim~+poststim 截取、丢弃超界事件）。
   已在测试数据上验证：事件识别数量与试次生成均正确。
3. **runica 版本**：FieldTrip 20181205 自带的精简版 runica 不支持 `rndreset` 参数，
   会导致 ICA 报错 "unknown flag"。本版在 `src/utils/` 放置了新版 EEGLAB 的
   runica.m（路径优先级更高，自动遮蔽旧版），请勿删除。
4. **easycapM1 布局**：`ft_channelrepair`（坏道修复）必须提供电极位置信息，原代码用
   `cfg.layout='easycapM1.lay'`（该文件只存在于新版 FieldTrip）。本版已从 FieldTrip 官方
   仓库下载等价的 `resources/easycapM1.mat` 并在 config 中指向它，换帽子时需替换。
5. **耗时与内存**：单被试 step2 约 10–30 分钟（runica ICA 占大头），峰值内存约 4–8GB；
   `S0_rawdata.mat`/`S3_ICA.mat` 以 -v7.3 保存。磁盘每被试约需 1–2GB 中间文件。
6. **随机性**：runica 与 mTRFcrossval 的分折无固定随机种子，两次运行的 ICA 成分编号与
   交叉验证 r 值可能有轻微差异，属正常现象。
7. **原项目中的 TRF3（只跑单被试）与 TRF1（云端版）已合并**：单被试调试用
   `cfg.eeg.subjects = [33]` 指定即可。

---

## 7. 引用

- mTRF 工具箱：Crosse, M. J., Di Liberto, G. M., Bednar, A., & Lalor, E. C. (2016).
  The Multivariate Temporal Response Function (mTRF) Toolbox. *Frontiers in Human Neuroscience*.
  （`external/mtrf/CITATION`）
- FieldTrip：Oostenveld, R., et al. (2011). FieldTrip: Open source software for advanced
  analysis of MEG, EEG... *Computational Intelligence and Neuroscience*.
