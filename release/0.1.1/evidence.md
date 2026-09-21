# yjson 0.1.1 发布记录

`0.1.1` 已于 `2026-09-21T07:18:36Z` 发布为
[GitHub Release](https://github.com/lIlIIlIll/yjson/releases/tag/0.1.1)，并设为 Latest。
九个包、tag 和附件均绑定下面的精确合并提交；中央 package registry 未发布。

## 1. 发布身份

| Field | Value |
| --- | --- |
| Release identity | `0.1.1` |
| Release source commit | `5578133e7111ea462decb014a109ed7ca196824e` |
| Release source tree | `917e8a6db6e183e90ddf24e6537371a187178f56` |
| Annotated tag | `0.1.1` |
| Tag object | `92207032335e2ca0fe8741eab18d19f3da6fb78d`; annotated, unsigned |
| Tag target | `5578133e7111ea462decb014a109ed7ca196824e` |
| GitHub Release | [0.1.1](https://github.com/lIlIIlIll/yjson/releases/tag/0.1.1); ID `392757140` |
| Candidate PR | [#7](https://github.com/lIlIIlIll/yjson/pull/7) |
| Qualified source candidate | `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab` |
| Candidate evidence commit | `e1b6d9792f342b4164b7512d4efaeabaa829feda` |
| Macro source commit | `0847b59e0c8c47b7c5b52b550ef8765c0cbddb03`; [macro PR #7](https://github.com/lIlIIlIll/yjson_macros/pull/7) |
| Final source-only export | 337 files; clean enforced; exact release commit |
| Final manifest SHA-256 | `62c8115786c924ad67057dea2f15643fd401622e4e1e714fafd5ad678df2066b` |
| Final payload SHA-256 | `d7814b6161e183341a0251a28097c9c318e6f287daa4d52aef89e9e25137ef3d` |
| Package pairing | All nine packages and their first-party version dependencies are `0.1.1` |
| Qualification SDK | Cangjie STS `1.1.3` |

初始本地资格绑定源码候选 `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab`，其 333-file 导出摘要保留在
[本地资格 receipt](local-verification.json)。最终附件在 main 门禁通过后，从 337-file
精确合并候选重新构建；没有复用合并前的包或校验和。合并树与候选证据提交的树一致。
本页是发布后的结果记录，不改变已发布 tag、源码或附件。

## 2. Gate 结果

| Gate | Status | Evidence |
| --- | --- | --- |
| Public API inventory and package pairing | PASS | 1,094 declarations; 9 packages; 17 reviewed deltas |
| Public API / C ABI snapshot | PASS | Same blob as actual published `0.1.0` source: `640b4891fa55245de7c3cacd7caec45c802073c9` |
| Frozen `0.1.0` consumer compatibility | PASS, scoped | [Matrix and consumer sources](binary-compatibility.json); 28 frozen hashes unchanged |
| Source-only staging | PASS | Final commit, clean flag and digests above |
| Release static checks | PASS | API inventory; stage-source tests 6; release-temp tests 13 |
| Markdown links | PASS | All 13 candidate Markdown files; 88 local links; result-record update checked separately |
| Evidence checker tests | PASS | 40 tests; complete run after an initial 120-second command timeout |
| Performance drift | PASS, strict | Exact clean evidence commit; freshness, checksums, manifests, source identities, fixed work and regenerated summaries |
| Local fresh-checkout simulation | PASS | [17-gate receipt](local-verification.json); exit 0; no unhandled exceptions |
| Pure core | PASS | Local 583 tests; hosted core and coverage jobs PASS |
| Native / yyjson / sanitizers / fuzz / colink | PASS, Linux | Hosted release-candidate main jobs PASS; local Native 16 and yyjson 19 tests |
| Windows and macOS Pure | PASS | Hosted `Pure (windows-2022)` and `Pure (macos-14)` jobs |
| Core coverage | PASS | Hosted `Core Coverage`; no percentage inferred from status alone |
| cjdoc qualification | PASS | Source-qualified `0.7.2`; local and hosted gates |
| Pure performance | PASS | 24 × 11 × 2 formal samples; 48 preflight; all C/B ≤ 1.05 |
| Deep Nested decode | PASS | String +0.321852%; bytes +0.150699%; within the unchanged 5% gate |
| Seven-library matrix | PASS, integrity | 1,540 successful cells; 220 fixed-work proofs; stable rows 1/10 and 0/10; noisy rows retained |
| PR CI | PASS | [Run 35569076198](https://github.com/lIlIIlIll/yjson/actions/runs/35569076198); 27 success, Pages skipped as expected on PR |
| Code and security review | COMPLETE | Both completed on the exact candidate head; no findings or unresolved threads |
| Release-candidate main CI | PASS | [Run 35570121534](https://github.com/lIlIIlIll/yjson/actions/runs/35570121534); all 28 jobs success |
| Final package rehearsal | PASS | Nine packages; deterministic reproduction and external consumers; no skip-consumers flag |
| Final source-byte comparison | PASS | 87 Cangjie source files and 21 native payload files match release source/submodule |
| Downloaded release assets | PASS | All 12 files match local SHA-256 and GitHub asset digests |
| API documentation / Pages | PASS | [Public portal](https://liliilill.github.io/yjson/); releaseVersion `0.1.1`; nine HTTP 200 package entries; rendered portal and core API page inspected |
| Native acceleration claim | NOT CLAIMED | No new acceleration claim |
| Central package registry | NOT PUBLISHED | Not authorized or attempted |

本地资格命令使用 `CANGJIE_SDK_ROOT=$HOME/cangjie_sdk/sts1.1.3`、`DISABLE_ZOXIDE=1`
和 `YJSON_CI_DEPENDENCY_OVERRIDE=-O1`。`core` 保留自身优化设置。
公开本地日志为 `local-verification.log.gz`；仅规范化路径及非法 UTF-8 fuzz 字节的显示，摘要在 receipt 中。

最终打包执行：

```sh
python3 scripts/release_temp_tree.py <new-source-only-directory> --enforce-clean
scripts/codex_cangjie_env python3 scripts/release_registry_rehearsal.py <new-rehearsal-directory> \
  --candidate-root <source-only-directory> --require-clean-candidate \
  --consumer-override-compile-option=-O1 --bundle-override-compile-option=-O1
sha256sum -c checksums.txt
```

## 3. 发布资产

| Package | Asset | SHA-256 |
| --- | --- | --- |
| `yjson` | `yjson-0.1.1.cjp` | `46e2e6925c730cde250fadf4d120d5dcba47c052b5129775e7515e1ebe13ca2f` |
| `yjson_macros` | `yjson_macros-0.1.1.cjp` | `b594a9f43ca4019516ec6659c24932425f44e749791d3945f368b7bedb1d4e91` |
| `yjson_algorithms` | `yjson_algorithms-0.1.1.cjp` | `e55a214ee97ef86ac474618d2d2e07e4fc1c68f092c67972664c106782d6d36f` |
| `yjson_backends` | `yjson_backends-0.1.1.cjp` | `2e5db1e37a9eda9e363990847ae753739e841937111410d81463da488ddc6228` |
| `yjson_native_primitives` | `yjson_native_primitives-0.1.1.cjp` | `3e6dc969a25f04d812bf18d84a6b7bb8257d03b158109b027632a3dc1d7bfa22` |
| `yjson_native_accel` | `yjson_native_accel-0.1.1.cjp` | `ae0bf10b9533dde600dfbed9bd57d8fc3e958ff4ef86ac75be08a740b6f71b47` |
| `yjson_native` | `yjson_native-0.1.1.cjp` | `75c8d0b8630abdedd837b304663f7d86549584d69495219e4dddfbf513f38d6b` |
| `yjson_yyjson` | `yjson_yyjson-0.1.1.cjp` | `aa526cb9e18d94931d40dcd89f7eb88aeb92adbb74c4651322256a4d2b80abec` |
| `yjson_schema_formats` | `yjson_schema_formats-0.1.1.cjp` | `700fc7fa4f845c5d0b897c2356b7a93a27d0e84501f1b85c43641567bcf7f36d` |

| Metadata asset | SHA-256 |
| --- | --- |
| `checksums.txt` | `e66f7ef03350fc0b896c42d6601ed3828a9fe05d4534f8ae62080e7682634868` |
| `manifest.json` | `955f612e01d7d599433503a2520fd22f7b20b4475798e437a99662805903b095` |
| `environment.json` | `c2db68030038b7aace252ceae96e5ff803124ed0c7267dd58139cd816fb16ec2` |

附件均位于 [GitHub Release](https://github.com/lIlIIlIll/yjson/releases/tag/0.1.1)。
`manifest.json` 记录发布提交、干净导出、逐包摘要、源码比对和 `yjson.source-components/1`
依赖/许可证清单。第一方包为 Apache-2.0；vendored yyjson `0.12.0` 为 MIT，随
`yjson_native_primitives` 和 `yjson_yyjson` 收录。系统提供的 libidn2 不打包，许可证字段为
`NOASSERTION`，不冒充完整的系统依赖审计。

`environment.json` 记录实际 SDK 工具摘要和打包覆盖参数；不包含开发机用户名、主机名或绝对路径。
GitHub 上的 12 个文件全部下载回验，且发布后的 asset digest 与本地摘要一致。

## 4. 文档部署

发布候选 main run `35570121534` 的 Pages job 成功部署
<https://liliilill.github.io/yjson/>。公开 `api-docs.json` 的 releaseVersion 为 `0.1.1`，
包含九个包；浏览器检查了入口和实际渲染的 core API 页面。

| cjdoc input | Value |
| --- | --- |
| Generator version | `0.7.2` |
| Source revision | `a56343875d4106a7f14d2c1c5685e3cdb411c4b4` |
| Source archive SHA-256 | `7b850efe40307f240eec6e6547175b771bea205d77b323dec3c76443490df9f4` |
| Local qualified binary SHA-256 | `0bafe5cfe03934cd095a758c734ebe02ae3d4d1dc7a540b956c5df526209ca76` |
| Hosted release deployment binary SHA-256 | `fd950462bd39bd5fad6bcb46c40743f2b91debd71e3cc68d3e449b30d2f7ae78` |

本地和托管构建的二进制摘要分别记录，不把其中一个冒充另一个。

## 5. 性能与历史基线

[Pure 报告](../../docs/performance/results/2026-09-13-linux-release-pure.md)使用独立固定工作量的进程内直接计时；
[七库报告](../../docs/performance/results/2026-09-13-release-seven-library.md)使用 SDKBench。
两种协议不拼接样本，不比较绝对延迟。七库第二批没有 stable 行，因此 README 不展示跨库精确比例。

实际发布的 `0.1.0` 包对应 runtime `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372`
与 macro `fec0adce41f73d037d876cbac7a28aee8108bb5c`，与旧 tag 不一致。
43 个 runtime 和 2 个宏源文件的逐字节核对及下载摘要已记录；差异另见
[issue #6](https://github.com/lIlIIlIll/yjson/issues/6)。历史 tag 和附件未改动。
首次错误 tag-baseline 的部分测量中止后单独保留，不进入正式结果。

冻结旧消费者矩阵也使用实际发布附件。它证明记录的 Linux x86_64 / STS 1.1.3
代表性静态重链接和动态替换场景，不保证任意程序、其他 SDK 或其他平台的二进制兼容。

## 6. 决定

```text
Release source and annotated tag: VERIFIED
Hosted release-candidate main CI: PASS (28 jobs)
Pure regression qualification: PASS
Seven-library integrity: PASS (noisy rows retained)
Final nine-package rehearsal and source-byte checks: PASS
Twelve downloaded assets and checksums: PASS
Pages 0.1.1 deployment: VERIFIED
GitHub Release: PUBLISHED, LATEST
Central package registry: NOT PUBLISHED
Native acceleration claim: NOT CLAIMED
```

发布流程见[发布指南](../../docs/maintainers/releasing.md)。
