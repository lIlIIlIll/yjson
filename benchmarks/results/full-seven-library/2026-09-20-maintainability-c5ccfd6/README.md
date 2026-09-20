# 2026-09-20 维护性候选七库证据

测量提交：`c5ccfd6953ea57adedc4c642dbb51aa2fbb9a12a`；协议：SDKBench `YJSON_FIXED_WORK_V1`。
两批各有 770 个唯一成功单元、7 个 preflight 和 110 份 yjson 固定工作量证明；全部 1,540 个单元都有正值 RSS sidecar。
完整表格和资格边界见[当前报告](../../../../docs/performance/results/2026-09-13-release-seven-library.md)。

同一源码和 harness 的 [Pure direct A/B](../../../../docs/performance/results/2026-09-13-linux-release-pure.md)通过原有回退门槛。
Pure 与七库使用不同协议，不拼接样本或比较绝对延迟；性能资格通过不等于发布资格通过。

| 项目 | 值 |
| --- | --- |
| Measured commit | `c5ccfd6953ea57adedc4c642dbb51aa2fbb9a12a` |
| Measured tree | `9fdaf2bf352dd78bb3db2686d986082e15887c8d` |
| Product source SHA-256 | `9e22b132f38b28f15ef698a373247ac91ad4bdbe922bd8fae42c1b09cdcf30cf` |
| Effective harness SHA-256 | `7b65d3cfc50c50bfbeb4ddce20e84183619ea7081a775f2a8152336fb4a1e2ab` |
| Candidate identity SHA-256 | `9fad27007d044de3d115b97317aa9b5deea6b9725c9deea79cb4cb6c3b33ac20` |
| SDK | STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| 仓颉运行时 | 单核绑定；`cjHeapSize=128MB`；`cjProcessorNum=1` |
| CPU | CPU 0，sibling 48；30 秒 idle sample 均为 `0.0%` |
| Stable workloads | 第一批 3/10；第二批 2/10；其余行保留为 noisy |

## 文件与边界

- `seven-review-c5ccfd69-batch11-v1-a.tar.gz`、`seven-review-c5ccfd69-batch11-v1-b.tar.gz`：两批报告、日志、RSS、manifest、metadata、preflight、固定工作量 sidecar 和 summary。
- `harness-source.tar.gz`：实际执行的 `run_full.py`、`benchmark_fixed_work.py`、`summarize_full.py`，与权威源逐字节相等。
- `candidate-source.tar.gz`：179 个冻结提交文件，覆盖 51 个产品输入和 28 个 harness 输入；没有规范化改写候选源码。
- `peer-source.tar.gz`：278 个对照源码文件；两份构建清单保留此前披露的路径规范化。
- `source-archive-manifests.json`：源码归档的逐文件摘要。
- `candidate-build-logs.tar.gz`：唯一一次候选 clean compile-only 构建日志。yjson/stdx 共用本轮候选程序；其余五库按 SHA-256 复用固定二进制，没有重建。
- `source-identity.json`、`candidate-fragment.json`、`archive-inventory.json`：候选、源码、harness、二进制和归档身份。
- `pure-prerequisite-state.json`：先通过 Pure direct 再运行七库的状态记录。
- `fixture-preflight-overlay.patch`：绑定到本轮身份的 fixture overlay，不是运行器补丁。
- `cpu-selection.json`、`seven-review-*-run.log`、`seven-review-*-summary.log`：核心筛选、本轮执行输出和汇总输出。
- `path-normalization.json`：1,985 个日志或报告文件的原始/公开摘要，以及被拒包装的摘要和原因。
- `checksums.txt`：以上全部 18 个 payload 的 SHA-256 清单。

## 包装与历史边界

首包因日志内保留测量工作目录被拒；后续一次未禁用字节码的打包调用产生 Python 缓存，也被拒绝。
原始数据和被拒包装保留。最终包只把日志和报告的测量工作目录前缀替换为 `<work>`，不修改源码和测量值，不重跑 benchmark。
规范化后的两批重新解析通过，固定工作量和 summary 与原始数据一致；候选构建日志同时记录原始和公开摘要。
此前 Pure stream、Large Map encode 超限、旧协议失败和历史包装错误保持原状态，不作为本轮通过证据。

## 复核

在包含全部归档的干净候选中执行：

```sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/ci_job.sh perf-evidence-drift strict
```

严格门禁核对校验和、安全解包、两批 770-cell 矩阵、RSS、220 份固定工作量证明、可重生成的 summary、文档表格，以及当前产品、harness 和发布绑定。
不能用 `integrity-only` 代替。source-only 发布树只携带索引和报告，完整归档保留在仓库。
