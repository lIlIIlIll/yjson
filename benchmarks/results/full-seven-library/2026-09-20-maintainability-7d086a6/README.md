# 2026-09-20 维护性候选七库证据

测量提交：`7d086a69200cecb447c64e73fa2b5e61e584ddb7`；七库协议：SDKBench `YJSON_FIXED_WORK_V1`，`cjProcessorNum=1`。
两批各完成 770 个唯一且成功的测量单元、7 个 preflight 和 110 份 yjson 固定工作量证明；全部 1,540 个单元都有正值 RSS sidecar。
完整表格和资格边界见[当前报告](../../../../docs/performance/results/2026-09-13-release-seven-library.md)。

这组七库证据与通过的 [Pure direct A/B](../../../../docs/performance/results/2026-09-13-linux-release-pure.md)属于不同协议：七库使用 SDKBench 比较七个库，Pure 回退门禁使用 `YJSON_PURE_DIRECT_V1` 比较冻结基线与候选；两者不拼接样本或比较绝对延迟。

| 项目 | 值 |
| --- | --- |
| Measured commit | `7d086a69200cecb447c64e73fa2b5e61e584ddb7` |
| Measured tree | `53527121b6bdca31586505ec838b5b092cd15924` |
| Product source SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Effective harness SHA-256 | `43461d89631bd104fc93f32b0319dfc3d386c5a6a1266cd47bec4d1e2559268f` |
| Candidate identity SHA-256 | `67dca1cfe2b00efbf3cb4f85e3d2a4c5fb1fb9260483a138796c5813d6235a10` |
| SDK | STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| 仓颉运行时 | 单核绑定；`cjHeapSize=128MB`；`cjProcessorNum=1` |
| CPU | CPU 1，sibling 49；30 秒 idle sample 均为 `0.0%` |
| Stable workloads | 第一批 0/10；第二批 1/10；其余行完整保留为 noisy |

## 文件与边界

- `seven-direct-7d086a-batch11-v1-a.tar.gz`、`seven-direct-7d086a-batch11-v1-b.tar.gz`：两批原始报告、日志、RSS、770 行 manifest、metadata、preflight、固定工作量 sidecar 和派生 summary。
- `harness-source.tar.gz`：实际执行的权威 `run_full.py`、`benchmark_fixed_work.py` 和 `summarize_full.py`。
- `candidate-source.tar.gz`：179 个冻结提交文件；51 个产品输入和 28 个 harness 输入全部存在，候选内容没有规范化改写。
- `peer-source.tar.gz`：278 个历史对照源码文件；两份构建清单保留已披露的路径规范化。
- `source-archive-manifests.json`：源码归档的逐文件摘要；候选 capsule 与冻结提交的 179 个文件逐字节相等。
- `candidate-build-logs.tar.gz`：唯一一次候选 clean compile-only 构建。yjson/stdx 共用本轮候选程序；五个 peer 库的固定二进制按 SHA-256 复用，没有重建。
- `source-identity.json`、`candidate-fragment.json`、`archive-inventory.json`：候选、源码、harness、二进制和归档身份。
- `fixture-preflight-overlay.patch`：绑定到本轮身份的 fixture overlay，不是运行器补丁。
- `cpu-selection.json`、`seven-direct-*-run.log`、`seven-direct-*-summary.log`：空闲核心筛选、本轮完整执行输出和汇总输出。
- `checksums.txt`：以上全部 16 个 payload 文件的 SHA-256 清单。

## 包装与历史边界

首版包装虽然包含正确的当前批次归档，但错误复制了历史 run/summary 日志，因此被拒绝并只在远端保留为失败历史；本目录来自修正后的 v2 包。v2 在 benchmark lock 下重新绑定当前日志，没有重跑任何 benchmark 行，也没有改写测量数据。
旧 `c844aa9` 的 Pure 第二批失败、固定采样 OOM、截断批次和其他被拒包装保持原状态，不作为本轮通过证据。

## 复核

在包含全部归档的干净候选检出中执行：

```sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/ci_job.sh perf-evidence-drift strict
```

严格门禁核对校验和、安全解包、两批 770-cell 矩阵、RSS、220 份 yjson 固定工作量证明、可重生成 summary、文档表格，以及当前产品、harness 和发布绑定。不能用 `integrity-only` 代替。
source-only 发布树只携带索引和报告；完整原始归档保留在仓库。
