# Pure 直接计时资格证据：c5ccfd6

候选 `c5ccfd6953ea57adedc4c642dbb51aa2fbb9a12a` 的 48 个预检和 528 个正式单元通过。
24 项均满足 C/B ≤ 1.05，48 个单侧 CV 均 ≤ 5%；没有第二批。
完整结果、协议边界和历史失败见[Pure 性能报告](../../../../docs/performance/results/2026-09-13-linux-release-pure.md)。

源码发布包只保留本索引；完整 Git 检出保存以下归档。

| 文件 | 内容 |
| --- | --- |
| `pure-direct-review-v4-evidence.tar.gz` | 3,456 个文件：本轮原始进程、构建与 CPU 记录、独立复核，以及明确分开的 110 个源码修复诊断进程 |
| `pure-direct-review-failed-candidates.tar.gz` | 8,759 个文件：三批失败正式测量、一次中止、一次构建前拒绝、源码归档和复核；失败结论未改 |
| `pure-direct-review-baseline-source.tar.gz` | 175 个冻结基线文件；不改写源码内容 |
| `pure-direct-review-baseline-source-manifest.json` | 基线逐文件摘要及产品、harness 绑定 |
| `pure-direct-review-v4-validation.json` | 安全解包、隐私、源码重建、计时与 RSS 重算结果 |
| `pure-direct-review-v4-checksums.txt` | 以上五个 payload 文件的 SHA-256 |

候选源码复用[七库证据目录](../../full-seven-library/2026-09-20-maintainability-c5ccfd6/README.md)的 `candidate-source.tar.gz`。
基线和候选的源码归档均覆盖全部 51 个产品输入和 28 个 harness 输入。

在完整检出的本目录运行：

```sh
sha256sum -c pure-direct-review-v4-checksums.txt
```

`pure-direct-review-v4-evidence.tar.gz` 内的 `checksums.sha256` 记录除自身以外的全部成员摘要。
`validation/reparse-validation.json` 保存从原始日志、direct 与 RSS sidecar 和线程布局重算的结果。
诊断数据不作为正式样本。失败归档通过完整性检查，不改变其性能门禁失败的结论。
