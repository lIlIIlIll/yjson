# yjson 0.1.1 发布候选记录

本页区分源码候选资格、托管 CI 和最终发布。已完成的本地证明绑定源码提交
`fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab`；尚未执行的发布动作不记为通过。

## 1. 候选身份

| Field | Value |
| --- | --- |
| Planned release identity | `0.1.1` |
| Qualified source commit | `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab` |
| Qualified source tree | `0abc1cd6f153b49f82db8fe720c1e475fd965e68` |
| Final merged release commit | NOT RECORDED |
| Source-only candidate | PASS; 333 files; clean enforced |
| Candidate manifest SHA-256 | `0813c1b2837b60d3504c409cf6ba604e8fb48db7e9d67000bc85f29aab4c3a29` |
| Candidate payload SHA-256 | `b9c88a4a4ec66b7bf0637fa1c0d26fb606d83dfc811ce7aeb40356530f4e713f` |
| Package manifests | 9 packages at `0.1.1`; inventory and rehearsal PASS |
| Release graph | `release/release-graph.toml`; version `0.1.1` |
| Macro source commit | `0847b59e0c8c47b7c5b52b550ef8765c0cbddb03`; gitlink and dependency pins match |
| Qualification SDK | Cangjie STS `1.1.3`; Linux x86_64 |
| cjdoc qualification | `0.7.2`; source revision `a56343875d4106a7f14d2c1c5685e3cdb411c4b4` |
| Qualified cjdoc binary SHA-256 | `0bafe5cfe03934cd095a758c734ebe02ae3d4d1dc7a540b956c5df526209ca76` |

以上摘要属于证据提交前冻结的源码候选，不是最终发布包身份。合并后必须从通过 main
门禁的精确提交重新导出、构建九个包并计算摘要，不能复用候选包的校验和。

## 2. Gate 状态

| Gate | Status | Evidence |
| --- | --- | --- |
| Public API inventory and nine-package pairing | PASS | 1,094 declarations; 9 packages; 17 reviewed deltas |
| Public API and C ABI snapshot comparison | PASS | Same snapshot blob as actual published `0.1.0` source: `640b4891fa55245de7c3cacd7caec45c802073c9` |
| Frozen `0.1.0` consumer binary compatibility | PASS, scoped | [Matrix and consumer sources](binary-compatibility.json); 28 frozen hashes unchanged |
| Release graph and source-only staging | PASS, source candidate | Clean enforced; provenance above |
| Release static checks | PASS, local | API inventory; stage-source tests 6; release-temp tests 13 |
| Markdown link check | PASS | All 13 release Markdown files checked; 88 local links exist |
| cjdoc qualification | PASS, local | Qualified binary digest above |
| Local fresh-checkout simulation | PASS | [17-gate receipt](local-verification.json); exit 0; no unhandled exceptions |
| Pure Cangjie core | PASS, local | 583 tests; core gate retains normal optimization settings |
| Native, yyjson, sanitizer and fuzz | PASS, local Linux | Included in the 17-gate simulation; Native 16 and yyjson 19 tests |
| Windows and macOS | NOT RUN | Await hosted candidate matrix |
| Core and patch coverage | NOT RUN | Await hosted candidate reports |
| API documentation | PASS, local | Nine packages generated in fresh-checkout simulation |
| Pages deployment | NOT RUN | Await hosted main deployment |
| Package rehearsal | PASS, source candidate | Nine-package staging, deterministic bundles and external consumers; final merged assets not built |
| Pure release performance comparison | PASS | 24 cases × 11 rounds × 2 sides; 528 formal cells; independent reparse PASS |
| Deep Nested decode protection | PASS | String +0.321852%; bytes +0.150699%; both within the 5% gate |
| Seven-library matrix | PASS, integrity | Two complete 770-cell batches; 220 fixed-work proofs; stable workloads 1/10 and 0/10; no stable cross-library ratio claim |
| Native acceleration claim | NOT CLAIMED | No new acceleration result claimed |
| Hosted PR CI | NOT RUN | No run ID recorded |
| Hosted main CI | NOT RUN | No run ID recorded |
| Annotated tag | NOT RUN | No tag object recorded |
| GitHub Release | NOT RUN | No release URL or asset inventory recorded |
| Central package registry | NOT AUTHORIZED | No registry publish action |

本地命令使用 `CANGJIE_SDK_ROOT=$HOME/cangjie_sdk/sts1.1.3`、`DISABLE_ZOXIDE=1`
和 `YJSON_CI_DEPENDENCY_OVERRIDE=-O1`。`core` 门禁保留自身优化设置；其他适用门禁使用
依赖覆盖值。命令为 `scripts/codex_cangjie_env bash scripts/ci_fresh_checkout.sh`。
本地结果不替代托管平台、覆盖率、Pages 或真实 provider 的证明。

公开日志为同目录的 `local-verification.log.gz`，摘要记录在 JSON receipt 中。
只规范化 SDK、home 和临时目录前缀；fuzz 输入的非法 UTF-8 字节以十六进制转义保留。

## 3. 发布资产

| Package | Planned asset | Status | SHA-256 |
| --- | --- | --- | --- |
| `yjson` | `yjson-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_macros` | `yjson_macros-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_algorithms` | `yjson_algorithms-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_backends` | `yjson_backends-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_native_primitives` | `yjson_native_primitives-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_native_accel` | `yjson_native_accel-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_native` | `yjson_native-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_yyjson` | `yjson_yyjson-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |
| `yjson_schema_formats` | `yjson_schema_formats-0.1.1.cjp` | NOT BUILT FROM MERGED CANDIDATE | NOT RECORDED |

最终附件为九个 `.cjp`、`checksums.txt`、`manifest.json` 和 `environment.json`。
最终提交、逐包摘要、依赖及许可证清单在构建后记录，当前不声明已发布。

## 4. 性能与回退

正式 Pure 资格使用固定工作量的进程内直接计时；七库矩阵使用独立 SDKBench 协议，
两者不拼接样本。Deep Nested string/bytes decode 均纳入完整 Pure 批次。

实际发布的 `0.1.0` 包对应 runtime `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372`
和 macro `fec0adce41f73d037d876cbac7a28aee8108bb5c`，与 `0.1.0` tag 不一致。
已通过全部 43 个 runtime 源文件和 2 个宏源文件的逐字节比较确认，并记录为
[issue #6](https://github.com/lIlIIlIll/yjson/issues/6)。历史 tag 和附件没有改动。

首次以 tag 为基线的部分测量已中止并保留，不进入正式统计；新批次使用实际发布源码。
冻结旧消费者矩阵也以下载并核验过的发布包为基线，而不是 tag。

## 5. 决定

```text
Source candidate identity: RECORDED
Public API inventory and source-only staging: PASS
Local STS 1.1.3 validation: PASS
Frozen consumer binary compatibility: PASS (Linux x86_64, representative matrix)
Pure release performance qualification: PASS
Seven-library matrix: PASS (integrity; noisy rows retained)
Hosted PR CI: NOT RUN
Hosted main CI and Pages: NOT RUN
Annotated tag and GitHub Release: NOT RUN
Native acceleration claim: NOT CLAIMED
Release decision: PENDING
```

发布流程见[发布指南](../../docs/maintainers/releasing.md)。
