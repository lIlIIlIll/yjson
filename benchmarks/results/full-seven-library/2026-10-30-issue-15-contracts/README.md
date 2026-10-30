# Issue #15 修复候选性能证据

测量生产提交 `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd`，宏提交 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。
2026-10-30 UTC 完成完整 Pure 回退检查、修复前 HEAD 的 Deep Nested 对照及两批七库测量。
本目录不表示候选已经发布，也不代替托管 CI 或跨平台资格。

结果见[七库报告](../../../../docs/performance/results/2026-10-30-issue-15-contracts-seven-library.md)
和 [Pure 报告](../../../../docs/performance/results/2026-10-30-issue-15-contracts-pure.md)。
最终验收见 [Issue #15 实施记录](../../../../docs/implementation/issue-15.md)。

## 原始结果与输入

- `seven-library-issue15-batch1.tar.gz`、`seven-library-issue15-batch2.tar.gz`：每批 770 个单元，各含 3000 个文件；包含全部 fixture 预检、原始报告、日志、RSS、固定工作量与控制记录。
- `seven-library-issue15-build-audits.tar.gz`：真实生产 Git pin 的构建、实际 argv、SDK 清单和产物摘要；标明对照程序复用，并保留首次准备失败。没有产物二进制。
- `seven-library-issue15-harness.tar.gz`：843 个源码或回执文件，包含可信 runner、完整生产输入、对照源码和许可来源。
- `pure-issue15-qualified.tar.gz`：完整 24 项及额外两项 HEAD 对照，分别为 528 和 44 个计时进程，另有 48 和 4 个预检进程。
- `pure-issue15-first-failure.tar.gz`：初次候选的完整 24 项失败记录，保留全部 528 个计时进程，未改判为通过。
- `pure-issue15-source-inputs.tar.gz`：发布基线、修复前 HEAD、初次失败候选和最终候选四个快照，各 200 个冻结输入文件；另附第一方许可、快照身份和逐文件摘要，不含 Git 历史。

## 校验记录

- `frozen-candidate-binding.json`：从干净生产源码取得的版本、依赖、产品和 harness 身份。
- `server-packet-inventory.json`、`download-verification.json`：服务器三个公开包的摘要及全部成员的下载校验。
- `public-harness-archive.json`：公开源码包的完整文件清单、源码摘要与归档摘要。
- `canonical-report-rows.json`：由两批原始汇总生成的报告行和 README 稳定行。
- `seven-offline-verification.json`：可信检出重算原始报告、固定工作量、RSS、case 绑定和跨批身份的结果。
- `pure-offline-verification.json`：从直接计时 sidecar 独立计算中位数、CV、比率与配对胜轮，并核对源码和首次失败。
- `pure-publication-projection.json`：Pure 原始下载包与公开包之间的逐成员等价检查。公开层只匿名化 tar owner 字段，所有文件内容、路径、类型、权限、时间和长度保持不变；原包与公开包摘要分开记录。
- `publication-content-audit.json`：归档路径、成员类型、owner 字段、UTF-8 内容、二进制与隐私模式检查。
- `strict-verification.json`、`strict-verification.log`：干净检出 `6630fba` 的完整 strict 门禁，40 项回归及源码、清单、身份、汇总检查全部通过；日志原样保留。

七库公开包在服务器打包时已经使用匿名 owner 字段，下载后字节不变。源码包保留真实许可，
不改写上游源码；显式合成的 Windows 路径脱敏测试不是开发机信息。
`checksums.txt` 绑定全部归档和机器可读记录。检查时只运行可信检出的 Python，不执行归档脚本。
