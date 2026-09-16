# yjson 0.1.0 发布证据

本页记录 `0.1.0` 候选的可审计验收状态。结果区分本地验证、托管 CI 和尚未执行的发布动作；性能证据只按已运行的门禁描述，不把冻结结果写成新的基准测量。

## 1. 候选身份

| Field | Value |
| --- | --- |
| Planned release identity | `0.1.0` |
| Candidate source commit | `104fbfa1a7919eb96c9fc0a46d5126d716211e6d` |
| Candidate source tree | `12ade6231caeefa3d45fdaf1e619853a230604b5` |
| Source-only candidate | `304` files; `clean_enforced=true` |
| Candidate manifest SHA-256 | `2b23daa959d44aa35a7824e751b479b79af35b0cc42cd441dd84bdf03365d54c` |
| Candidate payload SHA-256 | `8c8d6a01f8cfef19c2fe9583f1a60fbc2fbb17574c5bbc074f7207f70333cd67` |
| Package manifests | 9 packages; all version `0.1.0` |
| Release graph | `release/release-graph.toml`; status=`release-ready` |
| Qualification SDK | Cangjie STS `1.1.3`; `cjc`/`cjpm` `1.1.3` |
| cjdoc qualification input | source distribution, cjdoc `0.7.2`, revision `a56343875d4106a7f14d2c1c5685e3cdb411c4b4` |
| cjdoc source archive SHA-256 | `7b850efe40307f240eec6e6547175b771bea205d77b323dec3c76443490df9f4` |

`release/cjdoc-tool.toml` intentionally uses a pinned source archive and `cjpm build`.
The qualification gate requires `distribution = "source"`; the Linux binary release asset is
not substituted for this reproducible source-qualified path.

## 2. Gate 状态

| Gate | Status | Evidence |
| --- | --- | --- |
| Public API inventory | PASS | `check_api_inventory.py`: 1,094 declarations, 9 packages, 17 reviewed deltas |
| Release graph and source-only staging | PASS | `release_temp_tree.py /tmp/yjson-release-stage --enforce-clean`: 304 files; provenance above |
| Release static checks | PASS | API inventory, stage tree, release-temp-tree, STS, CI wiring, cjdoc qualification and release-graph test suites all passed |
| Markdown link check | PASS | `check_local_markdown_links.py docs/maintainers/releasing.md`: 2 links |
| cjdoc qualification | PASS | local `cjdoc-qualification` gate passed under STS `1.1.3`; hosted API Documentation also passed |
| Pure Cangjie core | PASS | hosted main CI run `35142368048`, all 28 jobs passed |
| Core coverage | PASS | `Core Coverage` job `104952834869` passed in run `35142368048` |
| Native, yyjson, sanitizer, fuzz and cross-platform gates | PASS | all corresponding jobs passed in hosted main CI run `35142368048` |
| API documentation and Pages | PASS | API Documentation job `104952779188`; Deploy API Documentation job `104954117865`; <https://liliilill.github.io/yjson/> |
| Package rehearsal | PASS | local registry-style rehearsal: 9 modules, 579 tests passed; hosted `registry-rehearsal` also passed |
| Performance evidence drift | PASS | `bash scripts/ci_job.sh perf-evidence-drift strict`: 25 tests passed; frozen evidence checksums, manifests, identities and summaries are consistent |
| New release benchmark | NOT RUN | no new performance benchmark was run for commit `104fbfa1`; frozen evidence is not presented as a new measurement |
| Native acceleration claim | NOT CLAIMED | no precise Native acceleration claim is made for this release |
| Hosted PR CI | PASS | yjson PR [#1](https://github.com/lIlIIlIll/yjson/pull/1), run [35141341924](https://github.com/lIlIIlIll/yjson/actions/runs/35141341924), 27/27 jobs passed |
| Hosted main CI | PASS | post-merge run [35142368048](https://github.com/lIlIIlIll/yjson/actions/runs/35142368048), merge commit `104fbfa1`, 28/28 jobs passed |
| Annotated tag | NOT RUN | tag creation is intentionally after evidence review |
| GitHub Release | NOT RUN | assets are built locally but not yet uploaded |
| Central package registry | NOT RUN | no separate registry endpoint was invoked |

The first post-merge Pages attempt failed because the repository Pages site was not enabled.
Pages was then enabled for workflow deployment and the failed jobs were rerun; run
`35142368048` completed with all 28 jobs passed. This is recorded as resolved setup, not as an
initially passing run.

## 3. 发布资产

The package assets were generated from the source-only candidate with
`scripts/release_registry_rehearsal.py` through the registry rehearsal path. The rehearsal
reported `registry-style rehearsal passed modules=9`; all nine archives are unpublished at this
stage.

| Package | Asset | SHA-256 |
| --- | --- | --- |
| `yjson` | `yjson-0.1.0.cjp` | `3669bcf0e555ae95a2c66cbc76a06a47375f42c3922b30cc5adccff8a945b8d4` |
| `yjson_algorithms` | `yjson_algorithms-0.1.0.cjp` | `e01580c168d331b6d71307b4f20436577654a86908452006fc6ac9ca0c85349c` |
| `yjson_backends` | `yjson_backends-0.1.0.cjp` | `53d0e59794d72cdde62e2c4e6fe10f872f23b43df3cf83fb770d904e4cb6862b` |
| `yjson_macros` | `yjson_macros-0.1.0.cjp` | `e9de109f513cf41e2edd397779a9c56a30fd23afac5b95f717a4199b830e9b9d` |
| `yjson_native` | `yjson_native-0.1.0.cjp` | `067a8f87df40b89aa2403e36381b10a4e02e035d6b6dffafe0dbbfb7eb4f1bfd` |
| `yjson_native_accel` | `yjson_native_accel-0.1.0.cjp` | `86a716ab67a54087a5de9fe47f9f70a878062ba84efc0f0b5a7382dea9a82990` |
| `yjson_native_primitives` | `yjson_native_primitives-0.1.0.cjp` | `07ee3f9257f1c357a9262026344ffd71aa211e6e02955dc409ae75217778df94` |
| `yjson_schema_formats` | `yjson_schema_formats-0.1.0.cjp` | `3bebff0857b35ed27b20098b0cca70948dbb8e557c33d76b314aa27df1822f84` |
| `yjson_yyjson` | `yjson_yyjson-0.1.0.cjp` | `856b709a4a3763b1051c2a06dca25453eb1cf6a09d7ad352e75e65ce4ba5a372` |

The release asset bundle also contains `checksums.txt`, `manifest.json` and
`environment.json`. The local checksum inventory validates all nine `.cjp` files and both JSON
metadata files; the inventory itself is not included in its own checksum list.

## 4. 性能与回退

`perf-evidence-drift strict` passed against the repository's frozen performance evidence and
verified the recorded measurement commit, product-source digest, harness digest, checksums,
manifests and summaries. No new benchmark was run for `104fbfa1`; therefore this release makes
no new throughput, latency, RSS or Native acceleration claim. The established Deep Nested decode
performance evidence remains protected by the strict drift gate.

## 5. 决定

```text
Public API inventory: PASS
Source-only staging: PASS
STS 1.1.3 validation: PASS
Local registry-style rehearsal: PASS (9 modules, 579 tests)
Hosted PR CI: PASS (27/27)
Hosted main CI and Pages: PASS (28/28)
Frozen performance evidence drift: PASS
Native acceleration claim: NOT CLAIMED
Release decision: CANDIDATE VERIFIED; TAG AND GITHUB RELEASE PENDING
```

发布流程和未执行动作见
[`docs/maintainers/releasing.md`](../../docs/maintainers/releasing.md)。
