# 0.1.0 发布证据

本页记录 `0.1.0` 候选的可审计验收状态。每个结果绑定测量提交、源码身份、
SDK、runner、命令和校验和；不把本地结果写成 hosted 结果，也不把诊断性能数据
写成发布资格。

## 1. 冻结身份

| Field | Value |
| --- | --- |
| Planned release identity | `0.1.0` |
| Candidate measured commit | `b0f16eb1f908908d61f55868b512e50e844345eb` |
| Candidate tree | `862822f34a904d82fe256af36a6f9062694c07a3` |
| Package manifest | 九个 package，版本均为 `0.1.0` |
| Release graph | `release/release-graph.toml`；status=`migration` |
| Evidence updated | `2026-09-10T03:26:01Z` |
| Local qualification host | Linux Arch `7.2.3-Arch1-3`, x86_64；Intel Core i7-8700 |
| Local qualification SDK | Cangjie `1.1.0-alpha.20260829040003 (cjnative)`；cjpm `1.1.3` |
| Hosted PR SDK | `1.3.0-alpha.20260829010011`；resolution=`pinned-known-good` |

本地编译器 `cjc` SHA-256 为
`bc0f32df9c610dcbb05f437552ff57ec6c6e075a54721f46cc9c882a62d2d836`，
`cjpm` SHA-256 为
`b867fca2fd0d4bc19bf195e7872f6f13d5019fd3ba5f409291814f7c5bdfa313`。
本地工具链为 `/home/elliot/cangjie_sdk/daily/cangjie`，clang=`22.1.8`，
gcc=`16.2.1`。Hosted PR 为
[#20](https://github.com/lIlIIlIll/yjson/pull/20)，最新成功 run 为
[`34414477049`](https://github.com/lIlIIlIll/yjson/actions/runs/34414477049)。

## 2. Gate 状态

| Gate | Status | Evidence |
| --- | --- | --- |
| Public API/C ABI mechanical inventory | PASS | `1094` Cangjie declarations；九包 inventory；C ABI delta 全部 `reviewed-for-0.1.0` |
| Public API migration review | **BLOCKING** | `release/public-cangjie-delta-bfd29.toml` 仍有 `unclassified` / `pending-migration-review` 组；发布图仍为 `migration` |
| Local Linux fresh candidate | PASS | `zsh scripts/codex_cangjie_env bash scripts/ci_fresh_checkout.sh`；exit `0`；575 个 root tests、standards `2110/2110`，native、sanitizer、fuzz、consumer 和 registry rehearsal 均完成 |
| Hosted PR CI | PASS | run `34414477049`；Linux required jobs、Core Coverage、API docs、registry rehearsal、Windows Pure、macOS Pure 和 Linux Native 均成功；PR Pages deployment 按 workflow 预期 skipped |
| Hosted main CI / Pages | NOT RUN | 发布阻断未关闭，尚未合并到 `main` |
| Coverage | PASS | project line `8479/10329=82.1%`、branch `3705/5250=70.6%`；changed core line `115/115=100.0%`、branch `38/44=86.4%`；hosted Core Coverage 成功 |
| Source-only staging | PASS | `stage_source_tree` 复制 `358` 个文件并通过 `--check`；`release_temp_tree --enforce-clean` 复制 `290` 个文件并通过 |
| Package rehearsal | PASS | b0 fresh-checkout 的九包独立暂存、构建、registry-style consumer 和导出检查成功；最终 release assets 尚未生成 |
| Seven-library matrix | DIAGNOSTIC | bddbe6 源码闭包，两批各 `770/770`；两批均 `0/10` 稳定，不作完整七库发布资格或精确比例声明 |
| Three-library release performance | **BLOCKING** | 见第 3 节；完成两批 36 workload、11 轮测量后仍有大量 noisy 行 |
| Pure baseline/candidate qualification | **BLOCKING** | 见第 3 节；正式 runner 的四个 `yjsonDocument*` case 与当前 benchmark 源码漂移；可用 24-case 子集未通过 enforce |
| Native acceleration | PASS | b0 精确源码闭包、11 轮、CPU 4、128 MiB、RSS、checksum 全部通过 |
| Release policy | **BLOCKING** | API migration review、Pure target/performance gate、main workflow 和 Pages 尚未关闭 |
| Annotated tag / GitHub Release | NOT RUN | 尚未创建 tag、release 或上传资产 |
| Central package registry | NOT RUN | 未授权发布；没有执行 central publication |

## 3. 性能证据

### 三库共同 workload

两批均在 `ubuntu2223131`、Cangjie `1.1.0-alpha.20260803040049`、cjpm
`1.1.3`、固定 CPU 8、128 MiB 堆上运行。每批包含完整 36 个 yjson、
stdx.json、cjfast_json 共同 workload，11 轮，workload 旋转、偶数轮反转、
库顺序逐轮旋转。

- 第一批归档 SHA-256：
  `44def26482738ad89e77903d16efee6e458be6c2600ff45839767946693c8bce`
- 第二批归档 SHA-256：
  `dfc9b2f1c623fc7bb2857ad3f3cb4a6248fd59e178f19e876148de3db1986b17`
- 第一批：稳定 `0/36`，noisy `36/36`。
- 第二批：稳定 `2/36`，noisy `34/36`；两批均保留在 runner 归档中，第二批仍 noisy，按方法不再继续重跑。

第二批固定大数组 decode 行为：yjson `103947.506 ns`、cjfast_json
`77994.667 ns`，Y/C=`1.334x`，yjson 仅赢 `1/11`，yjson CV=`12.79%`。
该行及其他 noisy 行只保留方向证据，不发布精确比例；由于第二批仍未满足
CV 门槛，三库正式性能 gate 为 BLOCKING。

### Pure 基线/候选

`json_pure_perf_compare.py` 的默认 case 列表包含当前
`packages/benchmarks` 中不存在的四个 `yjsonDocument*` 方法，因此完整命令
无法形成合法的全量报告。以性能父提交
`9d4387192296ce7c3ec5a5024e52ad0084bf7891` 为 baseline、b0 为 candidate，
保留其余 24 个可用 case 后运行 11 轮、CPU 8、128 MiB、`--rebuild --enforce`；
结果归档 SHA-256 为
`fe10c2a302e728015284be0ef67ac648c6cb3abd64fada4a397080289f7e76ac`，
命令 exit `1`。

目标 `yjsonStringDecodeLargeProfileArray`：baseline `74.633 us`，candidate
`75.182 us`，C/B=`1.007x`，improvement=`-0.7%`，candidate wins=`2/11`；
目标要求为提升至少 `5%` 且 wins 至少 `5/11`。另有 case 的 CV 超过 `5%`，
因此该 A/B 结果不能作为发布资格。

### Native acceleration

在 b0 精确源码上，固定 CPU 4、128 MiB、11 轮、Pure/Native 交替进程，7 个
case 均通过 RSS 和内容 checksum：

| Case | Pure | Native | Native/Pure | Wins | CV P/N |
| --- | ---: | ---: | ---: | ---: | ---: |
| `writeNumericArray` | `4125838.22 ns` | `553839.09 ns` | `0.134x` | `11/11` | `3.96%/3.70%` |
| `writeNumericBytes` | `4568168.44 ns` | `508837.38 ns` | `0.111x` | `11/11` | `3.02%/3.08%` |
| `readNumericArray` | `1778874.28 ns` | `1271620.56 ns` | `0.715x` | `11/11` | `1.69%/1.83%` |
| `readNumericDocument` | `2491597.20 ns` | `1640251.43 ns` | `0.658x` | `11/11` | `3.31%/3.06%` |
| `writeEscapedStrings` | `448960.56 ns` | `451154.82 ns` | `1.005x` | `5/11` | `2.82%/2.29%` |
| `writeEscapedBytes` | `405649.37 ns` | `411648.00 ns` | `1.015x` | `5/11` | `1.91%/3.86%` |
| `writePlainStrings` | `114671.78 ns` | `113378.18 ns` | `0.989x` | `6/11` | `3.33%/3.69%` |

Native 归档 SHA-256：
`8a580e1d66d3ac44cce81786531517b07603f169b3e3b15b2cd32872b004b54d`。
Native 运行源码闭包 SHA-256 为
`c923cddabb5182faadee9a2756543c1a3bea89afc9f8590e64f2ad515d0a68d9`。

## 4. 决定

```text
Local fresh-source simulation: PASS
Hosted PR execution: PASS
Coverage: PASS (project 82.1%/70.6%; changed core 100.0%/86.4%)
Native acceleration qualification: PASS
Three-library performance qualification: BLOCKING
Pure baseline/candidate qualification: BLOCKING
Public API migration review: BLOCKING
Hosted main execution and Pages: NOT RUN
Release decision: BLOCKED; no merge, tag, GitHub Release, or registry publication
```

待关闭项：完成 `activateJsonNativePrimitivesV1` 与新增 native writer declarations
的 migration review；修复或重新定义 Pure A/B runner 与当前 benchmark case contract；
并提供满足方法门槛的完整性能证据。关闭前不得创建 `0.1.0` tag 或 GitHub Release。
