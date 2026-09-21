# 0.1.1 七库完整测量证据

测量提交 `ce39e57ba6ade281d232bc0d82abfafdf91f5bb5`，主仓库源码候选 `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab`。
完整结果与边界见[七库报告](../../../../docs/performance/results/2026-09-13-release-seven-library.md)。
两批各 770 个唯一成功单元，共 1,540 单元、220 份 yjson 固定工作量证明。
完整性 PASS；第一批 1/10、第二批 0/10 workload 满足 Max CV ≤ 5%，不得将 noisy 行解释为稳定跨库比例。
没有删样本、第三批或跨协议拼接。

## 证据内容

本目录除本索引外的文件保留于 Git 仓库，不进入 source-only 发布树。
`checksums.txt` 绑定全部 18 个 payload：

- 两份 `seven-release-011-batch11-v1-*.tar.gz`：完整 raw reports、manifest、RSS、固定工作量、preflight、metadata 与 summary。
- 对应 run/summary 日志：当前两批执行记录。
- `candidate-source.tar.gz`：179 个候选文件，覆盖全部产品与 harness 输入。
- `peer-source.tar.gz`：278 个固定 peer 源文件。
- `source-archive-manifests.json`：逐文件来源与归档摘要。
- `harness-source.tar.gz`、`fixture-preflight-overlay.patch`：实际运行器、汇总器与固定工作量解析器及 fixture overlay。
- `candidate-build-logs.tar.gz`：本轮唯一候选构建及二进制核验。
- `candidate-fragment.json`、`source-identity.json`、`archive-inventory.json`：产品、harness、版本依赖、二进制与归档身份。
- `cpu-selection.json`：30 秒空闲筛选，CPU 3 与 sibling 51 均为 0.0%。
- `pure-prerequisite-state.json`：完整 Pure A/B 前置门禁通过。
- `path-normalization.json`：1,985 个文件的原始/公开摘要，以及临时打包器修正记录。

产品 SHA-256：`9e22b132f38b28f15ef698a373247ac91ad4bdbe922bd8fae42c1b09cdcf30cf`。
有效 harness SHA-256：`4d34fcb5e5a160e46c293efd996ac9fc416aa2858d316d163e1cf7c22bba1cc3`。
版本依赖身份 SHA-256：`e809af61d164287dbf18f320977334c52d2140ebb3358fe6834f2e34e1147549`。

日志只规范化工作目录前缀，原始 SDK 诊断、计时值和源码字节不改写。
SDK 稳定身份比较复用仓库既有 `stable_identity`，不把诊断时间戳或线程 ID 当作版本差异。
规范化归档已重新解析全部单元；不得用重新打包替换或重跑测量样本。

```sh
cd benchmarks/results/full-seven-library/2026-09-21-release-011
sha256sum -c checksums.txt
```

在包含完整归档的干净候选中执行严格门禁：

```sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/ci_job.sh perf-evidence-drift strict
```

该门禁还会重生成 summary、核对 README 和报告表格，并绑定当前源码与九包发布配置；不得改用 `integrity-only` 放行。
