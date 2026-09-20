# 2026-09-18 单并发维护性候选七库证据

测量提交：`f4aed80847e77fee12a156e8644f65ab34c64092`；协议：`fixed-work-cj1-v1`。
两批各完成 770 个单元、7 个 preflight 和 110 份 yjson 工作量证明。
完整表格和资格边界见[当前报告](../../../../docs/performance/results/2026-09-13-release-seven-library.md)。
七库证据完整不等于 [Pure A/B](../../../../docs/performance/results/2026-09-13-linux-release-pure.md) 或发布资格通过。

| 项目 | 值 |
| --- | --- |
| Product source SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Effective harness SHA-256 | `721fec53e1a190c71e2996396474870f2516add82ca0be4a94ab143465d0ffba` |
| Candidate identity SHA-256 | `8eb3be733b99dd03b06af7d41eb797cfb527ff4d1fc5ea162941d68b6dc40d0e` |
| SDK | STS `1.1.3` |
| 仓颉运行时 | 单核绑定；`cjHeapSize=128MB`；`cjProcessorNum=1` |
| CPU | CPU 17，sibling 65；30 秒 idle sample 均为 `0.0%` |
| Stable workloads | 两批各 1/10；其余行保留为 noisy |

## 文件

- `seven-fixed-work-cj1-v1-a.tar.gz`、`seven-fixed-work-cj1-v1-b.tar.gz`：原始报告、日志、RSS、manifest、metadata、preflight 和 summary。
- `harness-source.tar.gz`：实际执行的权威 `run_full.py`、固定工作量校验器和 summarizer。
- `candidate-source.tar.gz`：177 个冻结提交文件，包含全部 77 个产品与 harness 输入；候选内容没有规范化改写。
- `peer-source.tar.gz`：278 个历史对照源码文件；保留两份构建清单已披露的路径规范化。复现时把 `<sdk>` 替换为 STS 安装目录。
- `source-archive-manifests.json`：逐文件原始摘要与归档摘要。
- `candidate-build-logs.tar.gz`：本轮唯一一次候选构建；yjson/stdx 共享新程序，其他对照产物按摘要复用。
- `source-identity.json`、`candidate-fragment.json`、`archive-inventory.json`：来源、产物和归档身份。
- `fixture-preflight-overlay.patch`：已绑定的 fixture overlay，不是运行器补丁。
- `checksums.txt`：全部 16 个 payload 的 SHA-256；其他日志记录完整执行与汇总过程。

## 复核

在包含归档的干净候选中执行 `bash scripts/ci_job.sh perf-evidence-drift strict`。
严格门禁还核对单并发配置、固定工作量和当前源码身份；不能用 `integrity-only` 代替。
旧 `c844aa9`、失败的固定采样 v1 和截断批次不作为本方案的通过证据。
source-only 发布树只携带索引与报告，完整原始归档保留在仓库。
