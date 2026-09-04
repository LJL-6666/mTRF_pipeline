# mTRF_pipeline

MATLAB 端到端流水线：用**语音包络**拟合**前向时间响应函数（forward TRF）**，预测连续语音刺激下的 EEG 响应，并输出通道级预测相关与地形图。

适用于 Neuracle BDF 采集、按试次播放顺序对齐刺激的实验范式。参数集中在 `config_default.m`；FieldTrip 与 mTRF 已随仓库提供。原始 EEG / 音频数据不入库，需自备后才能完整重跑；仓库内附带 **sub2 / sub3 案例图与模型** 供对照。

---

## 方法摘要

| 环节 | 做法（默认） |
|---|---|
| 刺激特征 | 单声道 wav → Hilbert 包络 → 重采样至 128 Hz → 截取分析窗 → 全局 z-score |
| EEG | BDF 按 trigger 分段 → 250 Hz → 50 Hz 陷波 → runica →（可选）剔伪迹成分 → 邻域修坏道 → 平均重参考 → 128 Hz → 带通（默认 theta 4–8 Hz）→ 同窗截取与 z-score |
| 对齐 | 行为 CSV 的 `videoIndex`（可改）将刺激重排到与 EEG 试次一致的播放顺序 |
| 模型 | 前向 mTRF（`dir=1`）；`mTRFcrossval` 在候选 λ 上选通道平均 r 最大者，再 `mTRFtrain` |
| 可视化 | 选定通道 TRF 波形；各通道最优 λ 下平均预测相关 r 的地形图 |

默认分析窗 5–40 s、TRF 延迟 −500–500 ms、λ = 10^(−1…3)。均可在 config 修改。

> **已知设计保留**：`prestim=1` 时，EEG 按分段内样本索引截取 `5*fs+1:40*fs`，相对触发约对应刺激后 4–39 s，与音频的 5–40 s 存在约 **1 s 固定偏移**（与原始分析一致）。严格对齐可将 `cfg.eeg.prestim` 设为 0 并同步调整 `cfg.analysis.timeWin`。详见第 7 节。

---

## 1. 环境

| 项目 | 要求 |
|---|---|
| MATLAB | R2018b+（需 Signal Processing Toolbox：`hilbert` / `resample`） |
| FieldTrip | 已内置 `external/fieldtrip-20181205` |
| mTRF | 已内置 `external/mtrf` |
| runica | 已内置 `src/utils/runica.m`（覆盖 FieldTrip 旧版，避免 `rndreset` 报错） |
| 系统 | Windows / Linux / macOS（路径均用 `fullfile`） |

克隆后一般**不必再装** FieldTrip / mTRF。内存建议 ≥8 GB（单被试 ICA 峰值约 4–8 GB）；磁盘每被试中间文件约 1–2 GB。

---

## 2. 仓库里有什么 / 没有什么

**有：** 流水线代码、FieldTrip、mTRF、电极资源、`output/figures/` 案例图、`output/EEG/Each/sub*/TRF_results/mTRF_model.mat` 案例模型。

**无：** `data/` 下原始音频与 EEG（体积与隐私）；`output/Audio/` 与 `EEG_preprocess/` 中间 mat（可重算）。

---

## 3. 数据摆放（换数据只改这里 + config）

```
data/
├─ audio/
│   ├─ 1.wav … N.wav          % N = cfg.stim.nAudio；默认 44100 Hz；取左声道
└─ EEG/
    ├─ <编号>/                % 纯数字文件夹名，如 2、3、33
    │   ├─ data.bdf           % 文件名固定
    │   ├─ evt.bdf
    │   ├─ *rating*.csv       % 须含刺激顺序列（默认列名 videoIndex）
    │   └─ ica_reject.txt     % 可选：ICA 伪迹成分编号，如 1 5 17
    └─ …
```

硬性约定：

1. 音频名为连续 `1.wav` … `N.wav`；
2. CSV 含播放顺序列（默认 `videoIndex`，取值对应音频编号）；
3. BDF 触发码与 `cfg.eeg.trigger`（默认 21）一致。

---

## 4. 快速开始

```matlab
cd mTRF_pipeline            % 仓库根目录
% 编辑 config_default.m（音频数、trigger、通道、时间窗、频段、TRF 等）
main                        % 依次执行 step1–step4
```

产物目录：

```
output/
├─ Audio/                   % 本地生成：Audiodataraw / Envelope_raw / Envelope_analysis
├─ EEG/Each/sub<编号>/
│   ├─ EEG_preprocess/      % 本地生成：S0…S8、EEG_analysis
│   └─ TRF_results/mTRF_model.mat
└─ figures/
    ├─ TRF_plot_sub<编号>.png
    └─ Topography_sub<编号>.png
```

常用开关（均在 `config_default.m`）：

- `cfg.pipeline.skipExisting = true`：终产物已存在则跳过；
- 只改某被试：删掉其 `output/EEG/Each/sub<编号>/` 后重跑；
- 只改 TRF / 绘图：`doStep1=false; doStep2=false;` 后跑 `main`；
- 单被试调试：`cfg.eeg.subjects = [33];`

---

## 5. 案例结果怎么看

仓库已含 **sub2、sub3** 的案例输出（无需本地数据即可打开）：

| 文件 | 含义 |
|---|---|
| `output/figures/TRF_plot_sub*.png` | 默认通道（config 中 `cfg.plot.channels`，默认 2 与 13）上的前向 TRF 波形 |
| `output/figures/Topography_sub*.png` | 最优 λ 下各通道平均预测相关 **r** 的头皮分布 |
| `…/TRF_results/mTRF_model.mat` | 变量 `mTRF_model`：`.CV` 交叉验证、`.r` 通道 r、`.t` 延迟轴 (ms)、`.model` 训练模型、`.lambda` 所选正则 |

MATLAB 中：

```matlab
S = load('output/EEG/Each/sub2/TRF_results/mTRF_model.mat');
M = S.mTRF_model;
disp(M.lambda);          % 最优 λ
disp(mean(M.r));         % 通道平均预测相关
```

自备数据完整跑通后，应得到同结构文件；数值会因 ICA 随机性与数据而异，形态应可对照案例图解读。

---

## 6. 换一批新数据

1. 按第 3 节放入 `data/`。  
2. 检查 `config_default.m`：`nAudio`、`trigger` / `prestim` / `poststim`、`rawChannels` / `rerefChans`、`bandpass`、`timeWin`、`lagWin` / `lambdas`。  
3. **ICA（建议，影响质量）**  
   - 先不设 `ica_reject.txt` 跑完 step2，得到 `S3_ICA.mat`；  
   - 用 `ft_databrowser` / `ft_topoplotIC` 标出眼电/肌电成分；  
   - 写入 `data/EEG/<编号>/ica_reject.txt`（空格或逗号分隔）；  
   - 删除该被试 output 目录，重跑 step2–4。  
   - 无名单时不剔除成分（与早期脚本行为一致），并会警告。  
4. 运行 `main`。

### 换电极帽 / 通道数

| 资源 | 作用 | 处理 |
|---|---|---|
| `resources/label31.mat` | 通道名（图例 / 地形图标签） | 换成新帽子通道名 cell |
| `resources/eeg_neighbours_29.mat` | 坏道修复邻域 | `ft_prepare_neighbours` 重做 |
| `resources/easycapM1.mat` | `ft_channelrepair` 电极位置 | 换成新布局 |
| `cfg.plot.layoutFile` | 地形图 layout（默认 FieldTrip 内 `easycap-M1.txt`） | 指向新 layout |

同步修改 `cfg.eeg.rawChannels` 与 `cfg.preproc.rerefChans`。

---

## 7. 复现说明（必读）

1. **刺激–EEG 约 1 s 窗偏移**：见文首方法摘要；为保持与原分析可比而保留。  
2. **trialfun**：原 `ft_trialfun_BDF_zxm` 已佚失；现用 `src/utils/trialfun_BDF_zxm.m`（按触发值、−prestim～+poststim 截取，丢弃越界事件）。  
3. **runica**：勿删 `src/utils/runica.m`，否则 FieldTrip 20181205 内置版可能报 `unknown flag`（`rndreset`）。  
4. **随机性**：ICA 与交叉验证折划分无固定种子，两次运行成分编号与 r 可有小幅差异。  
5. **耗时**：单被试 step2 约 10–30 分钟（ICA 为主）。

---

## 8. 项目结构

```
mTRF_pipeline/
├─ main.m                 % 唯一入口
├─ setup.m                % 路径与依赖自检（main 自动调用）
├─ config_default.m       % 全部实验 / 分析参数
├─ LICENSE                % 本仓库流水线代码：MIT；第三方见文内说明
├─ README.md
├─ src/
│   ├─ step1_extract_envelope.m
│   ├─ step2_preprocess_eeg.m
│   ├─ step3_run_trf.m
│   ├─ step4_visualize.m
│   └─ utils/             % U_topoplot, trialfun_BDF_zxm, runica
├─ external/
│   ├─ fieldtrip-20181205/
│   └─ mtrf/
├─ resources/             % label31, eeg_neighbours_29, easycapM1.mat
├─ data/                  % 本地自备（不入库）
└─ output/                % figures + TRF_results 案例已入库；中间文件本地生成
```

---

## 9. 常见问题（FAQ）

**Q: 克隆后直接 `main` 报找不到数据 / 没有 sub*？**  
A: 正常。需自备 `data/audio` 与 `data/EEG`。无数据时可先查看第 5 节案例图与 `mTRF_model.mat`。

**Q: `未找到 FieldTrip` / `ft_*` 找不到？**  
A: 确认 `external/fieldtrip-20181205` 完整（勿只拷空目录）；在仓库根目录运行 `main`（会调 `setup`）。勿手动 `cd` 进 `src` 再跑导致路径错乱。

**Q: ICA 报 `unknown flag` / `rndreset`？**  
A: `src/utils` 未在路径最前，或 `runica.m` 被删。重新在根目录执行 `setup` / `main`。

**Q: step3 提示找不到 rating CSV 或缺少 `videoIndex`？**  
A: 被试文件夹内需有文件名含 `cfg.eeg.csvPattern`（默认 `rating`）的 csv，且含 `cfg.eeg.orderColumn` 列；列名不一致时改 config，不必改代码。

**Q: `videoIndex 超出音频数量`？**  
A: CSV 中的编号必须落在 `1…cfg.stim.nAudio`；检查刺激个数与行为表是否同一套材料。

**Q: 试次数与音频数不一致？**  
A: 分段 trigger 数量决定 EEG 试次数；须与 CSV 行数、可索引的刺激一致。检查 `cfg.eeg.trigger` 与事件标记是否匹配。

**Q: 地形图 / 修坏道报 layout 相关错误？**  
A: 核对 `cfg.preproc.repairLayout`、`cfg.plot.layoutFile` 与 `resources/label31.mat` 通道数是否与数据一致。

**Q: 重跑不更新结果？**  
A: `skipExisting=true` 时会跳过。删除对应被试 output 目录，或暂时关闭 skip。

**Q: 可以只画图、不重训模型吗？**  
A: 可以。`doStep1/2/3=false; doStep4=true;`，且已有 `mTRF_model.mat`。

---

## 10. 许可证与引用

- **本仓库流水线代码**（`src/`、`main.m`、`setup.m`、`config_default.m` 等）：[MIT](LICENSE)。  
- **FieldTrip**：GPL（见 `external/fieldtrip-20181205/COPYING`）。整体再分发时请遵守各组件条款。  
- **mTRF**：BSD 3-Clause（`external/mtrf/LICENSE`）。  
- **runica**：保留 `src/utils/runica.m` 内原作者声明。

请引用：

- Crosse, M. J., Di Liberto, G. M., Bednar, A., & Lalor, E. C. (2016). The Multivariate Temporal Response Function (mTRF) Toolbox. *Frontiers in Human Neuroscience*.  
- Oostenveld, R., Fries, P., Maris, E., & Schoffelen, J.-M. (2011). FieldTrip: Open source software for advanced analysis of MEG, EEG, and invasive electrophysiological data. *Computational Intelligence and Neuroscience*.
