# 2026-09-18 维护性重构候选七库证据

测量提交为 `c844aa9519ec9bd9bffa3e45fceb3d5d45fb974a`。Cangjie STS `1.1.3` 下完成两批，每批 10 个 workload × 7 个库 × 11 轮，共 770 个单元；各批保留七库 preflight、原始报告、日志和逐进程 RSS。

**此目录的七库完整性不能替代整体性能资格。** [Pure 第二批](../../../../docs/performance/results/2026-09-13-linux-release-pure.md)有两项超过 `1.05` 回退门槛，候选尚未通过性能验收，不是发布声明。完整七库表格见[当前候选报告](../../../../docs/performance/results/2026-09-13-release-seven-library.md)。

## 身份

| 项目 | 值 |
| --- | --- |
| Measured commit | `c844aa9519ec9bd9bffa3e45fceb3d5d45fb974a` |
| Product source SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Effective harness SHA-256 | `8c8e193c4f676484f020a0fcc997204a89993df90aa5cddb3005d2dd095ca251` |
| Candidate identity SHA-256 | `70856862780f30fab9098a671b080eee7e56eb9d24c6c01801ad55e028f8bed7` |
| SDK | STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| CPU | CPU 0，sibling 48；30 秒 idle sample 均 `0.0%` |
| Hostname | 独立 UTS namespace 的 `example-host` |
| Heap | `128MB` |

首批 2/10 workload stable，第二批 3/10 stable。其余行完整保留为 noisy，不声明稳定精确的跨库比例。

## 文件与边界

- `seven-batch-a.tar.gz`、`seven-batch-b.tar.gz`：原始 CSV、日志、RSS、770 行 manifest、metadata、preflight 与派生 summary。
- `harness-source.tar.gz`：实际执行的 `run_full.py` 与 `summarize_full.py`。
- `candidate-source.tar.gz`：172 个候选源码与构建输入文件，包含本轮 `benchmark_input_identity.py`、Pure runner 和 CPU monitor；字节与测量源一致。
- `peer-source.tar.gz`：278 个 peer 源文件。仅两份 `cjpm.toml` 的私有绝对构建路径被规范化：依赖改为相对路径，SDK 使用 `<sdk>` 占位符。复现时将 `<sdk>` 替换为 STS `1.1.3` 的安装目录。
- `source-archive-manifests.json`：源码归档逐文件摘要、测量时的源码摘要，以及规范化前后的两种摘要。两份构建清单的归档字节不冒充原始字节；原始测量 metadata、CSV、日志、RSS 未改写。
- `candidate-build-logs.tar.gz`：本轮候选的未计时构建日志。peer 二进制复用既有、按摘要绑定的产物；不声称本轮重建了 peer，也不公开含私有路径的旧构建日志。
- `fixture-preflight-overlay.patch`：实际使用的 canonical fixture overlay。
- `candidate-fragment.json`、`source-identity.json`：候选、产品、harness 与二进制身份。
- `cpu-selection.json`、`seven-batch-*-run.log`、`seven-batch-*-summary.log`：空闲核心筛选与完整执行输出。
- `archive-inventory.json`：formal、harness 与候选构建日志归档的入口。
- `checksums.txt`：全部 16 个 payload 文件的 SHA-256 清单。

## 校验

在包含全部归档的干净仓库检出中执行：

```sh
bash scripts/ci_job.sh perf-evidence-drift strict
```

门禁校验 archive 安全性、checksum、770-cell 矩阵、RSS、summary 可重生成、两批身份、文档表格与当前产品/harness/发布绑定。不能用 `integrity-only` 放行。

source-only 发布树仅携带此索引与报告；完整原始归档保存在仓库。历史证据保持不变，本轮也不证明真实 Native provider 下 RF-009 writer 的性能。
