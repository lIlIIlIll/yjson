# API 注释候选性能证据

测量生产提交 `ac4f8b987910a473ada7d77f10ce6cd3c12d2248`，宏提交 `d819745310f8cc6aa416e1298f706ea5138b7d16`。
测量时间为 2026-10-29 UTC。本目录保留原始结果、输入、构建回执与本地公开层补全证明。
干净检出 `d8859ee` 的完整 strict 检查与 40 项回归已通过；本目录不表示 yjson 已发布。

结果见[七库报告](../../../../docs/performance/results/2026-10-30-api-contracts-seven-library.md)
和 [Pure 报告](../../../../docs/performance/results/2026-10-30-api-contracts-pure.md)。

- `seven-library-020-batch1.tar.gz`、`seven-library-020-batch2.tar.gz`：两批原始归档，各 770 个单元，未改写。
- `pure-release-020.tar.gz`：Pure 原始归档，528 个计时进程与 48 个预检进程。
- `seven-library-020-build-audits.tar.gz`：实际编译 argv、SDK/源码/依赖/产物前后回执及日志；不含产物二进制。
- `seven-library-020-harness.tar.gz`：可信 runner、实际七库源码输入、完整生产输入和公开许可来源证明。
- `pure-020-source-snapshots.tar.gz`：两个固定测量快照的源码及原有第一方许可；不含 Git 历史或二进制。
- `snapshot-export-receipts.json`：两个快照的真实 commit/tree 和逐文件摘要。
- `source-closure-verification.json`：从原冻结导出补全 315 个文件的字节校验与范围。
- `frozen-candidate-binding.json`：从上述固定源码计算的九包版本、清单、锁文件与产品/harness 绑定。
- `original-server-packet-inventory.json`、`download-verification.json`：原五包及全部成员的传输完整性校验。
- `canonical-report-rows.json`：从两批原始汇总生成的全文表与 README 稳定行。

- `independent-validation.md`：13 项独立离线核验、原始 argv 重放及证据深度限定。
- `publication-content-audit.json`：归档逐成员隐私、路径与文件类型检查。

原始下载 harness 只覆盖 `source_digest` 所选扩展名，公开层增加 Python、Native C、锁文件等
完整输入。原下载包摘要与新公开包摘要分开记录；所有正式结果归档均保持字节不变。
json4cj 源码来源与 README 中的 MIT 声明按真实公开树保留；不补写不存在的许可文件。

所有 `.tar.gz` 都只含普通文件。`checksums.txt` 绑定本目录的归档及机器可读校验收据。

`strict-verification.json` 和原始日志记录该次干净检出、命令、退出码及适用提交。
发布源码暂存曾发现新报告缺少收录，现将两份报告、证据索引和复核记录加入发布清单；原始数据归档仍保留在源码仓库。
