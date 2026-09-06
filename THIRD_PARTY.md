# 第三方组件清单

本仓库在 `external/` 下**随仓库分发** FieldTrip 与 mTRF 工具箱，以保证流水线在任意机器上取得一致结果。
本文件说明其来源、许可、以及本仓库对其所做的改动与裁剪。

> 顶层 `LICENSE`（MIT）**只适用于本仓库自有代码**：`src/`、`main.m`、`setup.m`、`config_default.m`。
> `external/` 下的代码适用各自原许可，其中 FieldTrip 为 GPL-3.0——因此
> **本仓库整体的再分发受 GPL 条款约束**。

## 一、随仓库分发的组件

| 组件 | 版本 | 许可 | 上游 |
|---|---|---|---|
| FieldTrip | 见下方「二」 | GPL-3.0 | https://github.com/fieldtrip/fieldtrip |
| mTRF-Toolbox | v2.x（核心函数子集） | BSD-3-Clause | https://github.com/mickcrosse/mTRF-Toolbox |

许可全文保留在 `external/fieldtrip-20181205/COPYING` 与 `external/mtrf/LICENSE`，未做改动。
`src/utils/runica.m` 保留其原作者声明。

## 二、对 vendored 组件的本地改动（重要）

`external/fieldtrip-20181205/` 这份副本**并非上游某个 tag 的原样拷贝**，已核实存在下列情况：

1. **一处功能性改动。** `ft_componentanalysis.m:513`

   ```matlab
   % 上游 2018-12-05 版本：
   optarg = [ft_cfg2keyval(cfg.runica) {'reset_randomseed' 0}];
   % 本副本：
   optarg = [ft_cfg2keyval(cfg.runica) {'rndreset' 'yes'}];
   ```

   这与 `src/utils/runica.m`（覆盖 FieldTrip 内置版本）是**配套的一对**：本副本向 runica
   传 `rndreset`，而上游 20181205 自带的 runica 不认这个 flag——这正是 README 第 7 节
   「勿删 `src/utils/runica.m`」那条注意事项的来由。

   该参数控制 ICA 的随机种子处理方式。**换回上游版本会改变 ICA 分解结果**，进而改变
   成分剔除与最终 TRF 预测相关。保留此副本是有意为之。

2. **快照日期与目录名不完全对应。** 目录名为 `fieldtrip-20181205`，但比对上游同日提交
   （`a078b9fe`）发现 `ft_channelrepair.m` 等文件存在差异（仅为换行排版，无功能影响），
   说明该快照实际早于 2018-12-05。**未核实其确切上游修订号。**

以上两点是本仓库不改用「自动下载上游 FieldTrip」方案的原因：那样做会静默改变已产出的结果。

## 三、为控制体积而移除的内容

下列内容与本流水线（BDF → 分段 → ICA → 带通 → 前向 mTRF）无关，已从仓库及其历史中移除。
如需相关功能，请从上游获取完整 FieldTrip 覆盖到 `external/` 下。

| 移除项 | 原因 |
|---|---|
| `fieldtrip/external/spm12/` | SPM12 的 MRI 模板与 DARTEL 工具箱，本流水线不做源定位 |
| `fieldtrip/template/anatomy,atlas,sourcemodel/` | 解剖模板与图谱，同上 |
| `fieldtrip/external/{ricoh,yokogawa}_meg_reader/` | **专有 EULA 组件，不可再分发** |
| `fieldtrip/external/{mffmatlabio,egi_mff}/` | EGI MFF 格式读取器（含 Java jar），本流水线读 BDF |
| `fieldtrip/external/eeglab/ica_linux` | binica 独立二进制；本流水线使用 `runica` |
| `*.mexw32`、`*.mexglx`、`*.mexmac`、`*.mexmaci` | 32 位与 PowerPC 平台的预编译二进制 |
| `*.pdf` | 厂商手册与 EULA 附带 PDF |

**保留**：`template/layout/`（地形图 layout，`config_default.m` 默认指向 `easycap-M1.txt`）。

## 四、引用

- Crosse, M. J., Di Liberto, G. M., Bednar, A., & Lalor, E. C. (2016). The Multivariate Temporal Response Function (mTRF) Toolbox. *Frontiers in Human Neuroscience*.
- Oostenveld, R., Fries, P., Maris, E., & Schoffelen, J.-M. (2011). FieldTrip. *Computational Intelligence and Neuroscience*.
