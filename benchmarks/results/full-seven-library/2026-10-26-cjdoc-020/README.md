# 0.2.0 候选七库测量证据

生产候选 `5576cddb1e42a3b391385038ab5b2e3f6d76a77c` 完成两批七库测量。
每批为 10 个 workload × 7 个库 × 11 轮，共 770 个唯一计时单元；另保留每批 7 份正确性预检。
两批共 1540 个计时单元、220 份 yjson 固定工作量证明，没有删除样本或跨批汇总。
完整表格和测量边界见[七库报告](../../../../docs/performance/results/2026-10-26-cjdoc-020-seven-library.md)。

| 批次 | Stable（最大单库 CV ≤ 5%） | Noisy |
| --- | ---: | --- |
| 第一批 | 8/10 | `large_array_decode`、`large_map_encode` |
| 第二批 | 9/10 | `large_array_decode` |

Noisy 行完整保留，不改判为 stable，不据此声明稳定的跨库精确倍数。
两批使用同一 STS `1.2.0`、产品、peer 和测量协议；归档分别保存 fresh 构建、SDK、参数、
依赖来源与锁范围、产物摘要、预检、raw reports、RSS、metadata 和 summary。
本次整理验证公开层和数据组件，**未执行完整 CLI strict，也不证明发布资格通过**。

## 证据文件

以下 payload 留在源码仓库本目录，source-only 发布树只携带本索引和结果报告。
文件可从[仓库目录](https://github.com/lIlIIlIll/yjson/tree/main/benchmarks/results/full-seven-library/2026-10-26-cjdoc-020)取得；
`checksums.txt` 绑定全部 payload，不要求发布清单收录原始 tar 包。

- `seven-library-020-batch1.tar.gz`、`seven-library-020-batch2.tar.gz`：保留原文件名和同名 root，分别为 3012、3016 个普通文件。
- `seven-library-020-harness.tar.gz`：528 个普通文件，含冻结源码、真实 `run_full.py`、`summarize_full.py`、`benchmark_fixed_work.py`、fixture patch、来源与许可。
- `seven-library-020-build-audits-source-only.tar.gz`：两次独立 fresh 构建的日志、实际 argv/env、SDK、19 份 manifest 前后摘要及保留的锁文件输入和产物收据，共 118 个普通文件。
- `final-5576-seven-preflight-firstcause-source-only.tar.gz`：首次缺少必要 corpus 环境准备导致的失败，共 49 个普通文件；原判定为 `STOPPED_BEFORE_FIRST_TIMED_SEVEN_CELL`，计时单元为 0。后续 formatter 失败也保留在 build audit，未隐藏或转为测量成功。
- `yjson-020-source-digest-inputs.tar.gz`：285 份原始源码/构建输入及 2 份来源 JSON，覆盖原整仓 `source_digest` 实际读取的全部 262 文件；由真实 frozen 算法复算精确匹配原 metadata，同时复算 product/harness 各 51 文件摘要。
- `parent-source-digest-verification.json`：父 agent 对原 1964 文件生产归档与完整摘要补充包的独立逐字节、mode 及实际算法复核。
- `source-input-manifest.json`、`license-extension-validation.json`：冻结源码逐文件 before/after 摘要与许可附加记录。
- `path-normalization.json`：全部原归档成员及额外输入的原始/公开 SHA-256、大小、替换次数、排除原因和原包身份。
- `independent-validation.json`、`two-batch-stable-identity.json`：独立核对 1540 单元、RSS、220 份固定工作量证明、18 个稳定 metadata 字段和 10 个固定工作量 case；可信汇总器重放两次，`summary.json/csv/md` 均逐字节一致。
- `parent-seven-two-batch-verification.json`、`seven-two-batch-independent-verification.json`、`seven-canonical-rows.json`：父 agent 和测量 agent 的原始独立复核收据及表格记录。
- `parent-public-layer-verification.json`：父 agent 核对六个原始归档的 7036 个成员、799 份源码记录、全部路径替换和排除项的独立收据。
- `json4cj-license-source-receipt.json`、`parent-json4cj-source-verification.json`、`json4cj-manifest-adaptations-from-a185.patch`：真实公开 a185 源与 197 被测文件的逐项绑定、独立复核和三份 manifest 的精确适配 diff。
- `json4cj-df204-source-binding.json`、`json4cj-opt29e51-source-binding.json`、`json4cj-public-history-source-correlation.json`：保留较早候选来源的差异与最终历史匹配过程，不把 main/opt 分支误当被测版本。
- `license-receipt-correction.json`：原许可收据中固定树计数文字从 215 修正到真实 219 的记录，源码、README 和 patch 未改。
- `lock-and-peer-source-evidence-scope.json`、`supplement-source-digest-independent-verification.json`：锁与来源证据的精确范围及补充源码独立复核。
- `deterministic-rebuild-validation.json`、`publication-content-audit.json`：重复生成及递归内容审计记录。

## 来源、许可与公开边界

原始 526 文件 harness 中的 508 份 source-input、3 个 canonical 脚本及 fixture patch 均逐字节保留。
后续 licensed 输入仅新增宏仓库的 `LICENSE`，其字节与真实 C9 commit/tree 对应的 Git blob 一致；
旧 526 文件包的父复核与新增许可复核分别记录，不把旧收据当作新包的完整证明。

json4cj 的真实公开来源为 commit `a185e9ac0df95ee2a9715941b13f21f2a2a4f674`、
tree `585465ae5d92d65310dded727d40397d1998654f`。197 份被测文件中 194 份与公开 Git blob
逐字节一致，只有 3 份 `cjpm.toml` 存在已记录的 SDK 适配和批准的 `-O2` 差异；被测文件原字节均保留。
公开 harness 在 licensed 527 文件之外，仅追加该固定提交的原 `README.md`（17365 bytes）；
其第 705/707 行为 License/MIT 声明。未找到独立 `LICENSE`/`NOTICE` 或完整 MIT 正文，不编造许可全文，
也不把该来源事实扩大为法律合规结论。

相关 yjson 冻结输入覆盖 canonical product/harness 文件清单；它是原整仓工作区的子集。
metadata 的原始整仓 `yjson` source digest 保持不变，不以子集摘要替代它。另附完整摘要输入胶囊，
从原 1964 文件生产归档复制相关原字节；实际复算为 `b179395b3b60ea90a114306fbea9b56062ac75c44a5633e14e55ff11969f7e76`。
peer/harness 的 6 项来源摘要也已从保留源码重新计算并精确匹配 metadata。

19 项前后监测值均为 `cjpm.toml` manifest。原任务审计器还在每次边界核对生产归档全部
1964 文件，包含 18 份生产 `cjpm.lock`；canonical harness 明列 4 份测量锁。peer/harness 的
cjjson、json4cj、cjfast 锁只保留最终内容，没有独立 pre/post 字段，不能泛称全部 peer 锁前后稳定。
原始 `prePostSdkSourceLocksStable` 字段保留，其适用范围由单独收据说明。

原始完整输入身份：

| 输入 | SHA-256 |
| --- | --- |
| batch1 | `2d65b6e7ed0dd1692a72d2cf30934f6b1362bf3accd7cb369555898db8502ca5` |
| batch2 | `4b9ef3e435de287df5ad21531ce87f146bbb6e95e5627a82ec1c07e4b3329f63` |
| 原 harness（526 文件） | `1daf5e13c55050b6b60d87f1a8e2efbdb1fdaee28ddda7f55816cf9cdcbb43f8` |
| licensed harness（527 文件） | `5cf24615ab599d56d95110c3bc5c61177146decf1d685c005fc4ada9e3d3a3f1` |
| 完整摘要补充胶囊 | `a8a123ef62d83de8192b4851b9e3019451d6c3da26078a8ff3a9d3378034c5ed` |
| build audits | `5a76872b79107048f4483f0cfeaef4b571d2976596141793fd2de4b6fdba9dd3` |
| 首次准备失败 | `d17419d9ad841f45594a9e0d577d111c479c94854aa43ffdaa17ee1b6684b5f1` |

大体积原 build audit 和失败原包仅私有原样保留。公开层排除 25 份 ELF/JAR 成员记录，
实际 SHA-256、大小和原成员位置仍保留；其中包含两批及失败包的重复产物。
两个任务层临时自动化脚本也仅私有保留，公开记录原 SHA、大小与排除原因。
它们不是 canonical runner 或冻结产品/peer 源码；必须实际运行的源码、fixture、协议和阈值均未因此删除。
公开包不含 Git 历史/objects 或编译产物，也不提供可直接重放的二进制环境。

## 路径规范化与复核

仅证据文本中的绝对临时路径前缀替换为 `<work>`、`<snapshot>` 或 `$HOME`。
所有测量值、源码字节、来源摘要、SDK/产物 SHA、原失败状态和 noisy 判定保持不变。
归档成员排序固定，uid/gid 为 0，owner/group 为空，tar/gzip 时间戳为 0；源码执行位保留。
检查涵盖嵌套内容、编译产物、Git 对象、链接、路径穿越、本机路径/用户名/主机、私有地址和凭据。
原公开第三方版权内容和测试用示例地址按原字节保留。

在完整仓库证据目录核对摘要：

```sh
cd benchmarks/results/full-seven-library/2026-10-26-cjdoc-020
sha256sum -c checksums.txt
```

完整 `perf-evidence-drift strict` 还需父任务在整合 README、报告、marker 和来源绑定后的干净检出中执行。
本目录的数据组件复核和私有 trusted summary 重放不替代该命令，不使用 `integrity-only` 作为通过声明。
