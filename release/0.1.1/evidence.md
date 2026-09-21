# yjson 0.1.1 发布候选记录

本页记录 `0.1.1` 候选的可审计验收状态。只有实际执行并绑定到最终候选的结果才能改为
`PASS`。本页创建时没有候选提交、托管 CI 结果、发布产物或发布动作，因此对应字段保持
`NOT RECORDED` 或 `NOT RUN`。

## 1. 候选身份

| Field | Value |
| --- | --- |
| Planned release identity | `0.1.1` |
| Candidate source commit | NOT RECORDED |
| Candidate source tree | NOT RECORDED |
| Release record commit | NOT RECORDED |
| Source-only candidate | NOT RECORDED |
| Candidate manifest SHA-256 | NOT RECORDED |
| Candidate payload SHA-256 | NOT RECORDED |
| Package manifests | 9 packages planned at version `0.1.1`; final candidate check NOT RUN |
| Release graph | `release/release-graph.toml`; planned version `0.1.1` |
| Macro source commit | `0847b59e0c8c47b7c5b52b550ef8765c0cbddb03`; main-repository gitlink verification pending |
| Qualification SDK | Required: Cangjie STS `1.1.3`; resolved `cjc`/`cjpm` identity NOT RECORDED |
| cjdoc qualification input | NOT RECORDED |

已检入的 public API 和 C ABI 快照相对 `0.1.0` 没有变化。该快照关系不代替冻结旧
consumer 的链接和调用矩阵，也不构成二进制兼容声明。

## 2. Gate 状态

| Gate | Status | Evidence |
| --- | --- | --- |
| Public API inventory and nine-package pairing | NOT RUN | Final candidate command and output not recorded |
| Public API and C ABI snapshot comparison | NOT RUN | Final candidate comparison not recorded |
| Frozen `0.1.0` consumer binary compatibility matrix | NOT RUN | Link and call results not recorded |
| Release graph and source-only staging | NOT RUN | Candidate provenance and digests not recorded |
| Release static checks | NOT RUN | No final candidate check bundle recorded |
| Markdown link check | NOT RUN | No final candidate result recorded |
| cjdoc qualification | NOT RUN | No generated artifact or digest recorded |
| Local fresh-checkout simulation | NOT RUN | No final candidate run recorded |
| Pure Cangjie core | NOT RUN | No final candidate run recorded |
| Core and patch coverage | NOT RUN | No final candidate report recorded |
| Native, yyjson, sanitizer, fuzz and cross-platform gates | NOT RUN | No final candidate run recorded |
| API documentation and Pages | NOT RUN | No hosted run or deployment recorded |
| Package rehearsal | NOT RUN | No final candidate archives recorded |
| Release performance comparison | NOT RUN | Must run on the authorized SSH server against a clean, independent candidate |
| Deep Nested decode regression protection | NOT RUN | No candidate A/B result recorded |
| Native acceleration claim | NOT CLAIMED | This release does not claim a new Native acceleration result |
| Hosted PR CI | NOT RUN | No run ID recorded |
| Hosted main CI | NOT RUN | No run ID recorded |
| Annotated tag | NOT RUN | No tag object recorded |
| GitHub Release | NOT RUN | No release URL or asset inventory recorded |
| Central package registry | NOT RUN | No publish action recorded |

本地准备检查不能替代最终候选、托管 CI 或发布动作的证据。协调者应在每项完成后记录精确命令、
候选身份、运行 ID、产物摘要和结果，不得把一个环境的结果复制为另一个环境的 `PASS`。

## 3. 发布资产

| Package | Planned asset | Status | SHA-256 |
| --- | --- | --- | --- |
| `yjson` | `yjson-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_macros` | `yjson_macros-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_algorithms` | `yjson_algorithms-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_backends` | `yjson_backends-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_native_primitives` | `yjson_native_primitives-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_native_accel` | `yjson_native_accel-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_native` | `yjson_native-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_yyjson` | `yjson_yyjson-0.1.1.cjp` | NOT BUILT | NOT RECORDED |
| `yjson_schema_formats` | `yjson_schema_formats-0.1.1.cjp` | NOT BUILT | NOT RECORDED |

`checksums.txt`、`manifest.json`、`environment.json`、SBOM 和附件清单均为
`NOT RECORDED`。

## 4. 性能与回退

`0.1.1` 不声明新的吞吐、延迟、RSS 或 Native acceleration 数值。正式回退资格必须按
[`docs/performance/methodology.md`](../../docs/performance/methodology.md)在授权的 SSH server
上执行独立、干净的 baseline/candidate A/B。Deep Nested decode 仍是必须保护的用例。

## 5. 决定

```text
Candidate identity: NOT RECORDED
Public API inventory: NOT RUN
Source-only staging: NOT RUN
STS 1.1.3 validation: NOT RUN
Frozen consumer binary compatibility: NOT RUN
Release performance qualification: NOT RUN
Hosted PR CI: NOT RUN
Hosted main CI and Pages: NOT RUN
Annotated tag: NOT RUN
GitHub Release: NOT RUN
Native acceleration claim: NOT CLAIMED
Release decision: PENDING
```

发布流程见 [`docs/maintainers/releasing.md`](../../docs/maintainers/releasing.md)。
