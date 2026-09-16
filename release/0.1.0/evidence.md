# yjson 0.1.0 发布证据

本页记录 `0.1.0` 候选的可审计验收状态。结果区分本地验证、托管 CI 和尚未执行的发布动作；性能证据只按已运行的门禁描述，不把冻结结果写成新的基准测量。

## 1. 候选身份

| Field | Value |
| --- | --- |
| Planned release identity | `0.1.0` |
| Candidate source commit | `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372` |
| Candidate source tree | `4f8df96188c021cb7ab2a82c7e236482ded90844` |
| Release record commit | `54b4965dee0f0b96710cbc678ec5ec9a126b055c` (evidence-only merge after the package candidate) |
| Source-only candidate | `304` files; `clean_enforced=true` |
| Candidate manifest SHA-256 | `2b23daa959d44aa35a7824e751b479b79af35b0cc42cd441dd84bdf03365d54c` |
| Candidate payload SHA-256 | `20259909f2201c43feea7b18f79be23b95539626f2764a1b5079c0445aa5e140` |
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
| Release graph and source-only staging | PASS | `release_temp_tree.py /tmp/yjson-release-stage-final --enforce-clean`: 304 files; provenance above |
| Release static checks | PASS | API inventory, stage tree, release-temp-tree, STS, CI wiring, cjdoc qualification and release-graph test suites all passed |
| Markdown link check | PASS | `check_local_markdown_links.py docs/maintainers/releasing.md`: 2 links |
| cjdoc qualification | PASS | local `cjdoc-qualification` gate passed under STS `1.1.3`; hosted API Documentation also passed |
| Local fresh-checkout simulation | PASS | `scripts/ci_fresh_checkout.sh`; 17 release jobs completed, including source staging and registry rehearsal |
| Pure Cangjie core | PASS | hosted main CI run `35149045188`, all 28 jobs passed |
| Core coverage | PASS | `Core Coverage` job `104972440310` passed in run `35149045188` |
| Native, yyjson, sanitizer, fuzz and cross-platform gates | PASS | all corresponding jobs passed in hosted main CI run `35149045188` |
| API documentation and Pages | PASS | API Documentation job `104972440372`; Deploy API Documentation job `104974551665`; <https://liliilill.github.io/yjson/> |
| Package rehearsal | PASS | local fresh-checkout rehearsal passed 9 modules; hosted `registry-rehearsal` job `104972440688` also passed |
| Performance evidence drift | PASS | hosted `Seven-library evidence drift` job `104972375139` passed; local strict run also passed 25 tests |
| New release benchmark | NOT RUN | no new performance benchmark was run for commit `89c22a93`; frozen evidence is not presented as a new measurement |
| Native acceleration claim | NOT CLAIMED | no precise Native acceleration claim is made for this release |
| Hosted PR CI | PASS | yjson PR [#1](https://github.com/lIlIIlIll/yjson/pull/1), run [35141341924](https://github.com/lIlIIlIll/yjson/actions/runs/35141341924), 27/27 jobs passed |
| Hosted main CI | PASS | post-merge run [35149045188](https://github.com/lIlIIlIll/yjson/actions/runs/35149045188), merge commit `54b4965d`, 28/28 jobs passed |
| Annotated tag | PASS | tag object `c91859feb77aeba392a1fad0f99d731df66be831`; target commit `54b4965dee0f0b96710cbc678ec5ec9a126b055c` |
| GitHub Release | PASS | [0.1.0](https://github.com/lIlIIlIll/yjson/releases/tag/0.1.0), published `2026-09-16T21:01:48Z`, 12 assets uploaded |
| Central package registry | NOT RUN | no separate registry endpoint was invoked |

The first post-merge Pages attempt failed because the repository Pages site was not enabled.
Pages was then enabled for workflow deployment and the failed jobs were rerun; run `35142368048`
completed with all 28 jobs passed. The final evidence-record merge `54b4965d` was then verified by
run `35149045188`, including the Pages deployment job `104974551665`. These setup and rerun facts
are recorded separately from the final main CI result.

## 3. 发布资产

The package assets were generated from the source-only candidate commit `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372` with
`scripts/release_registry_rehearsal.py` through the registry rehearsal path. The rehearsal
reported `registry-style rehearsal passed modules=9`; all nine archives are attached to the
GitHub Release. The tag `0.1.0` targets the evidence-record commit `54b4965dee0f0b96710cbc678ec5ec9a126b055c`; the package archive manifest intentionally binds artifacts to the earlier package candidate `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372`, whose package source inputs are unchanged by the evidence-only merge.

| Package | Asset | SHA-256 |
| --- | --- | --- |
| `yjson` | `yjson-0.1.0.cjp` | `fbedf299f102c3ef00b23132e12a484c419ad7167595e1995c864b2a1e584999` |
| `yjson_algorithms` | `yjson_algorithms-0.1.0.cjp` | `b98052fef3e438a80c5f7d746a3187aa91663975b8401516b2391cbe6a147ec0` |
| `yjson_backends` | `yjson_backends-0.1.0.cjp` | `31d4ca4dfd16c2051529c7553e0cb0c51832ce977d1696a904520de2f70343d4` |
| `yjson_macros` | `yjson_macros-0.1.0.cjp` | `e9de109f513cf41e2edd397779a9c56a30fd23afac5b95f717a4199b830e9b9d` |
| `yjson_native` | `yjson_native-0.1.0.cjp` | `d0d257477725fa7a47f2231afea58b451c999d0ff487f9fc6523e20ef06d83b6` |
| `yjson_native_accel` | `yjson_native_accel-0.1.0.cjp` | `a0de10adb688c5400598c7e8c95de0e63387c2b957165abfccdd77168c4c70cd` |
| `yjson_native_primitives` | `yjson_native_primitives-0.1.0.cjp` | `07ee3f9257f1c357a9262026344ffd71aa211e6e02955dc409ae75217778df94` |
| `yjson_schema_formats` | `yjson_schema_formats-0.1.0.cjp` | `6faf008a1e91d6243497b91d7dec822b513fa4c21adee0841d4de944d2b35c8f` |
| `yjson_yyjson` | `yjson_yyjson-0.1.0.cjp` | `37824422d743e35d5a933532adb0c096978a8307ca36c813f6b20560dae9bcc7` |

The release asset bundle also contains `checksums.txt`, `manifest.json` and `environment.json`.
The local checksum inventory validates all nine `.cjp` files and both JSON metadata files; the
inventory itself is not included in its own checksum list. The uploaded metadata digests are:
`checksums.txt` = `c3372e1f54d929aeec1423a3725902daa9e0ed56456798721930841c4fbbeaa0`,
`manifest.json` = `10af1123fb7c437270cc7f2cc3f6bf0a8b533ab00f40ad5dd17f212264209fc3`, and
`environment.json` = `e94f2b99e2a822e8ad441b8283bb0f63f38d0481caab10796d5ef94b9b08a455`.

## 4. 性能与回退

`perf-evidence-drift strict` passed against the repository's frozen performance evidence and
verified the recorded measurement commit, product-source digest, harness digest, checksums,
manifests and summaries. No new benchmark was run for `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372`; therefore this release makes
no new throughput, latency, RSS or Native acceleration claim. The established Deep Nested decode
performance evidence remains protected by the strict drift gate.

## 5. 决定

```text
Public API inventory: PASS
Source-only staging: PASS
STS 1.1.3 validation: PASS
Local registry-style rehearsal: PASS (9 modules, 579 tests)
Hosted PR CI: PASS (27/27)
Hosted main CI and Pages: PASS (run 35149045188, 28/28)
Annotated tag: PASS (tag object c91859feb77aeba392a1fad0f99d731df66be831)
GitHub Release: PASS (12 assets)
Frozen performance evidence drift: PASS
Native acceleration claim: NOT CLAIMED
Release decision: PUBLISHED (tag `0.1.0` and GitHub Release assets)
```

发布流程和中心包仓库未执行动作见
[`docs/maintainers/releasing.md`](../../docs/maintainers/releasing.md)。
