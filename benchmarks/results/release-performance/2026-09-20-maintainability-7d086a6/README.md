# Pure 直接计时资格证据：7d086a6

候选 `7d086a69200cecb447c64e73fa2b5e61e584ddb7` 的 48 项预检和 528 个正式样本通过。
完整结果、协议边界和历史失败见 [Pure 性能报告](../../../../docs/performance/results/2026-09-13-linux-release-pure.md)。

本目录在完整 Git 检出中保存以下文件。源码发布包只保留本索引，不携带测量归档。

| 文件 | 内容 |
| --- | --- |
| `pure-direct-v4-evidence.tar.gz` | 原始日志、计时与 RSS、线程布局、构建记录、失败尝试和独立重算 |
| `pure-direct-v4-baseline-source.tar.gz` | 冻结的基线源码 |
| `pure-direct-v4-baseline-source-manifest.json` | 基线源码清单及产品、harness 摘要 |
| `pure-direct-v4-validation.json` | 安全解包、隐私、源码绑定和重算结果 |
| `pure-direct-v4-checksums.txt` | 以上四个文件的 SHA-256 |

候选源码复用[七库证据目录](../../full-seven-library/2026-09-20-maintainability-7d086a6/README.md)中的 `candidate-source.tar.gz`。

在完整检出的本目录运行 `sha256sum -c pure-direct-v4-checksums.txt`，核对四个文件。
