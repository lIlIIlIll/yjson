# 2026-10-26 0.2.0 候选七库测量

生产候选 `5576cddb1e42a3b391385038ab5b2e3f6d76a77c` 完成两批独立构建的完整测量，
每批 `10 workloads × 7 libraries × 11 rounds = 770` 个单元，共 1540 个。
主 agent 已逐项复核原始记录并重放汇总。第一批 8/10、第二批 9/10 workload 满足
七库的 `Max CV <= 5%`；其余行仍保留，不能用于稳定的跨库比例结论。
公开证据、完整来源摘要和报告绑定已复核；整合提交 `7d48eb2` 的干净检出通过
`bash scripts/ci_job.sh perf-evidence-drift strict`。该结果不代表 yjson 已发布。

同 SDK 的 [Pure 回退检查](2026-10-26-cjdoc-020-pure.md)已通过。完整候选状态见
[实施记录](../../implementation/cjdoc-020.md)，原始记录、冻结源码和构建审计见
[七库证据索引](../../../benchmarks/results/full-seven-library/2026-10-26-cjdoc-020/README.md)。
本次不发布 yjson，也不证明 Native、默认运行时配置或跨 SDK 性能。

## 测量条件

- Linux x86_64；Cangjie STS `1.2.0`、stdx `1.2.0.1`；全部仓颉产品与依赖实际编译均为显式 `-O2`。
- 未加入 cjdoc 的 `--fno-chir-function-inlining`。json4cj 的三个依赖清单通过显式 overlay 统一为 O2，并审计实际参数。
- 每批重新构建四个仓颉程序和 Maven/JDK 17 程序，记录 SDK、Git pin、19 份 `cjpm.toml`、实际产物和链接库的前后摘要；生产全树校验覆盖 18 份锁文件，测量 harness 明确绑定其中 4 份。
- 仓颉沿用 SDKBench；yjson 使用 fixed-work protocol v1。Java 使用 JMH `1.37`，每个外层轮次一个 fork、`3 × 500 ms` 预热和 `1 × 1 s` 测量。
- 堆配置为 `128MB`，仓颉 `cjProcessorNum=1`；七库仍单核绑定。每批重新采集 30 秒空闲窗口，所选 CPU 1 与 sibling 49 均为 0.0%。
- workload 和七库顺序轮换，偶数轮反转 workload 顺序；使用语义等价的公开 typed API，有直接 typed 路径时不退回 DOM。
- 每个有效批次先通过七库 fixture 预检。全部进程保留 RSS；每批 110 份 yjson 固定工作量记录跨轮、跨批一致。

下表单位为 **微秒/操作**，数值为 11 个外层轮次中位数。`Max CV` 为该 workload 七库中
最大的样本 CV；超过 5% 的行按 noisy 保留。SDKBench 与 JMH、Pure 直接计时分别属于
不同协议，不拼接样本。详细方法见[性能方法](../methodology.md)。

## 第一批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.401 | 1.042 | 0.903 | 0.999 | 0.910 | 0.176 | 0.066 | 2.81% |
| Address decode | 0.249 | 1.869 | 0.562 | 1.786 | 0.693 | 0.325 | 0.072 | 4.13% |
| Person encode | 1.067 | 4.062 | 5.664 | 2.226 | 3.756 | 0.568 | 0.270 | 1.75% |
| Person decode | 1.539 | 7.166 | 4.924 | 6.217 | 4.713 | 1.131 | 0.420 | 2.80% |
| Large Array encode | 18.601 | 37.858 | 80.542 | 37.713 | 34.588 | 9.034 | 4.158 | 2.74% |
| Large Array decode | 37.422 | 64.370 | 43.312 | 64.661 | 43.671 | 18.913 | 5.131 | 5.15% |
| Large Map encode | 3.739 | 25.593 | 46.868 | 29.457 | 27.922 | 1.784 | 1.730 | 5.05% |
| Large Map decode | 11.876 | 53.491 | 58.693 | 50.218 | 49.980 | 5.430 | 3.939 | 1.53% |
| Deep Nested encode | 20.854 | 29.904 | 51.385 | 29.115 | 26.104 | 4.491 | 2.484 | 2.30% |
| Deep Nested decode | 47.046 | 48.748 | 36.358 | 44.244 | 32.940 | 10.367 | 3.416 | 1.79% |

第一批 `Large Array decode` 的 Max CV 为 5.15%，`Large Map encode` 为 5.05%；
两行均为 noisy，原始样本不删除。

## 第二批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.389 | 1.046 | 0.901 | 1.005 | 0.911 | 0.178 | 0.066 | 4.58% |
| Address decode | 0.249 | 1.876 | 0.562 | 1.781 | 0.694 | 0.327 | 0.072 | 3.65% |
| Person encode | 1.072 | 4.067 | 5.659 | 2.226 | 3.736 | 0.573 | 0.274 | 1.65% |
| Person decode | 1.529 | 7.136 | 4.931 | 6.194 | 4.732 | 1.127 | 0.422 | 1.74% |
| Large Array encode | 18.582 | 38.068 | 80.519 | 37.754 | 34.651 | 9.100 | 4.150 | 3.04% |
| Large Array decode | 37.424 | 64.517 | 43.316 | 64.646 | 43.641 | 18.958 | 5.127 | 6.63% |
| Large Map encode | 3.741 | 25.576 | 46.896 | 29.436 | 27.811 | 1.785 | 1.740 | 4.62% |
| Large Map decode | 11.873 | 53.633 | 58.544 | 50.433 | 49.665 | 5.418 | 3.957 | 1.68% |
| Deep Nested encode | 20.798 | 29.941 | 51.388 | 29.257 | 26.026 | 4.515 | 2.456 | 1.81% |
| Deep Nested decode | 47.085 | 48.827 | 36.425 | 44.393 | 32.946 | 10.377 | 3.398 | 3.52% |

第二批仅 `Large Array decode` 为 noisy，Max CV 为 6.63%。README 的简表只列第二批
满足稳定性标准的九行，不表示这些比率在其他环境或每一批都成立。没有第三批或计时重试。

## 输入身份与复核

| 输入 | 固定身份 |
| --- | --- |
| 测量提交 | `5576cddb1e42a3b391385038ab5b2e3f6d76a77c` |
| 产品源码 SHA-256 | `eb31d8ab82a5ed9149fc1fbf2955f7b9f6796acf4af1ab612fb03a1d6f446e99` |
| 有效 harness SHA-256 | `230ccd61c2dd5bc85de33db9f2f27745c0f95e6fe7512bf8a1427a7b35cc2904` |
| 对比库适配 SHA-256 | `5f09b209c66d504a2533b261a922e63cc8312ea549aa88619d9c4160c058f4fc` |
| 九包版本依赖身份 SHA-256 | `9b42e8299476f41b6be5c62440cc2edf847863f4c5137d2b6864b260224b9944` |
| 独立宏仓提交 | `c9ef52da9ba2d3f77916c40ccb9280db78ee2e07` |
| 第一批原归档 SHA-256 | `2d65b6e7ed0dd1692a72d2cf30934f6b1362bf3accd7cb369555898db8502ca5` |
| 第二批原归档 SHA-256 | `4b9ef3e435de287df5ad21531ce87f146bbb6e95e5627a82ec1c07e4b3329f63` |

主 agent 核验第一批 3012、第二批 3016 个原始文件；从真实测量提交取得的校验器检查
全部单元的用例绑定、RSS、固定工作量和 JSON/CSV/Markdown 汇总重放。两批 18 个稳定
metadata 字段全部相同，10 个 yjson 用例的固定工作量跨批相同；三个实际 harness 脚本
与可信源码逐字节一致。原 build-audits 包的 133 个文件也已核验，公开层另保留归一化说明。

源码摘要覆盖实际使用的三个仓颉对比库及其宏和本地依赖，并与两批构建后、计时前和
最终导出相符。每批结束的即时校验覆盖生产全树、清单、overlay、SDK 和产物，没有
再次重算全部对比库源码摘要。三个对比库消费方的空锁文件仅保留最终快照；
不将其描述为独立的锁文件前后校验。Java 的外部库另由固定 POM、构建日志和 fat-jar
摘要绑定，源码不计入本地 harness 的源码摘要。
原始归档和公开层分别使用各自摘要，路径规范化不改写测量值、源码或真实输入身份。

## 准备失败与历史记录

首次调用因未设置 `YJSON_CROSSLANG_CORPUS_DIR`，在正确性预检中退出，正式计时样本为零。
沿用 Pure 的冻结语料、补齐该环境变量并另建结果目录后，才开始两批有效测量；未改变
harness、fixture、工作量或阈值。原失败归档保留，SHA-256 为
`d17419d9ad841f45594a9e0d577d111c479c94854aa43ffdaa17ee1b6684b5f1`。
第一批完成后的任务层收据格式化器曾出现索引错误；仅修复格式化器并只读复算，
没有修改原始记录或重跑该批计时。

旧 SDK 的 [0.1.1 七库报告](2026-09-13-release-seven-library.md)及此前 Pure 失败保持原判定，
只适用于各自的源码、SDK 和协议，不作为当前候选通过的证据。
