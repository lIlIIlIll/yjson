# 正式性能证据独立复核

本次有界离线复核完成，13 项核验全部通过，未发现可确认的阻塞缺陷。Pure release 的回归阈值通过；两批七库的原始矩阵、工作量、RSS 和派生摘要一致。七库存在应保留的 noisy 组合。此结论不等于主仓完整 strict PR 门禁通过：新的 marker、README 和结果页绑定尚未装配，也未执行对应干净检出门禁。

本报告以 `$P28` 表示本任务父目录。所有下载原件保留在 `perf/downloads/`，原解包保留在 `perf/extracted/`。只在 `performance-independent-replay.dbss84y3/` 创建副本、审查脚本和派生结果。没有修改产品、原始归档或正式计时数据，没有编译、重测、触发远端、发布或进行 Git 写入。

## 身份与重放方式

| 项目 | 核验值 |
| --- | --- |
| 生产源码提交 | `ac4f8b987910a473ada7d77f10ce6cd3c12d2248` |
| 宏提交 | `d819745310f8cc6aa416e1298f706ea5138b7d16` |
| product SHA-256 | `4251be5ff98c50a91afdd162ae130d94f8bf2a70c85faf5da6a78304232771af` |
| effective harness SHA-256 | `9d457f09101cb4466a82b000d2494e9c12b2f495b5b16b4fef809811a60d8852` |
| 测量 overlay SHA-256 | `5f09b209c66d504a2533b261a922e63cc8312ea549aa88619d9c4160c058f4fc` |
| Pure 共同 harness SHA-256 | `dc28db7743c93f1550bad1f31e15455bc213c486a54c131e6b0f9a8cd16de9a6` |

重新计算五包 SHA 和各成员 SHA，并核对原解包文件，全部与 `perf/downloads/inventory.json` 一致：

| 原包 | 文件数 | SHA-256 |
| --- | ---: | --- |
| `pure-release-020.tar.gz` | 2887 | `36ab90c69f96157bef5743916ff9b020029550d5f2c30639d140877000f8a2ec` |
| `seven-library-020-batch1.tar.gz` | 3016 | `2a335821d005a20a23e598012b342c48eb8fe2b882e861a0b7dc67da5db046fc` |
| `seven-library-020-batch2.tar.gz` | 3016 | `c73e455b2f80ac3442fdedb925f13664df81664db75c98787db07cdcc75b6fec` |
| `seven-library-020-build-audits.tar.gz` | 125 | `7fc2003792b80b05c1dd459b0fcf1ef38f28bc091aee37365207090ad89abc2a` |
| `seven-library-020-harness.tar.gz` | 496 | `61741e0b61ddb1e3d0e59ca6bb82b1480db254744c868e617af94ae1130d799a` |

执行的是可信主仓代码。`scripts/check_seven_library_evidence.py` 的 SHA-256 为 `445592b3439d4e3506da13aeb40b3131c5141a27399acc705720a882590fdf9d`。主仓 `run_full.py`、`summarize_full.py`、`benchmark_fixed_work.py` 与原归档对应文件逐字节一致，没有执行下载包里的 Python 程序。

分别对两批新副本调用 `read_metadata_and_validate()`，再调用 `regenerate_and_compare_summary()`，后者实际执行主仓 `summarize_full.py --min-runs 11` 和 `check_json_numeric_equivalence.py`。两批 `summary.json` 均数值等价，`summary.csv`、`summary.md` 均字节一致。没有调用需要正式 marker、README 和当前检出绑定的整套 `verify()`。

实际离线脚本为 `review_probe.py`、`review_supplement.py`、`review_final_bindings.py`，均在上述独立目录以 `python3 -B` 执行。最终结构化结论为该目录的 `review-results.json`。校验脚本只读原件；摘要写入新副本。早期审查脚本对清单扩展名和 SDK 快照结构的错误假设已按实际字段纠正，未通过改变正式证据或断言掩盖；最终 13 项状态均为 PASS。

## Pure：24 项 × 11 轮

基线与候选各 24 项、每项 11 轮，共 264 对、528 个正式进程；另有 48 个 preflight。逐一重读 stdout、direct sidecar 和 RSS sidecar，以主仓 `benchmark_pure_direct.parse_direct_result()` 验证固定操作数、预热下限、分段数、成功的测试计数；核对每个 sidecar 与摘要样本对应，正式格无重复。直接计时是 `elapsed_ns / operations`，没有用进程墙钟替代。

由原样本重新计算 baseline/candidate 统计量、候选/基线中位数比值、成对胜轮数和 `evaluate_gates()`，与原摘要一致：

- 24/24 项 `candidate / baseline <= 1.05`；最大值 `1.0179362279930575`，对应 `yjsonStringEncodePerson`。
- 24/24 项两侧 CV 均不超过 5%；全局最大值为基线 `yjsonStringDecodeProfileBundle` 的 `3.207140979104709%`。
- `gate_mode=release`，原 `gates.passed=true`。此模式实际强制回归上限，不强制优化目标或 CV 门槛；本次额外重算确认 CV 也全部满足 5%。不能把本次 release 结果描述成已执行 optimization 目标门禁。
- Pure 使用样本标准差计算 CV；七库使用总体标准差计算 CV。本复核分别重放各自原方法，没有混用口径。

两侧导出各 200 个文件均重新散列，匹配 `snapshot-export-receipts.json`；product 清单和共同 harness 也从导出字节重算。源码身份在构建前后相同，`dirty=false`：

| 变体 | 提交 | tree | product SHA-256 |
| --- | --- | --- | --- |
| baseline | `d5cf460a6c5cdfb25a07bd45e97bd04d7336ea87` | `2d648afbc19f2f65284a54cc80ef88265d06f5b1` | `ee7b04b11c99ef76e0bb4ff07266466b702895ea35eff01aaa44362d94e8c4b6` |
| candidate | `641bc25d5a15062282feea45b9adba2185c9f434` | `f75104309dc6c21fba95cf16f35428fa611e57ec` | `4251be5ff98c50a91afdd162ae130d94f8bf2a70c85faf5da6a78304232771af` |

Pure candidate 是共同依赖闭包的隔离快照；生产源码仍绑定真实宏 Git pin。两者 product 摘要一致，Pure 共同 harness 与生产 harness 的摘要不同且分别明确记录，不能把两个 harness 身份混为一项。

## 七库：完整性与 stable/noisy

每批恰好 770 行、770 个唯一格，等于 10 workload × 7 library × 11 rounds；不存在缺格、重复格或额外格。770 份 RSS 均与 sidecar 相符。每批 110 个 yjson 格均验证独立 stdout/fixed-work sidecar、case 绑定和固定工作量，其余 660 格未冒称拥有 yjson fixed-work 证明。两批同 workload 的 `batches/batch_size/operations` 完全一致：200 batches，每格操作数按 workload 固定，例如 Address encode/decode 为 3276800，Person decode 为 409600，Deep Nested decode 为 12800。

两批 preflight 的 COMPLETE 均存在，14 个归档报告均用主仓 `validate_report()` 验证准确的 library/case 绑定；本次没有重新运行 fixture。正式计时执行预构建可执行文件；`run_full.py:239` 固定 Cangjie `cjProcessorNum=1`，`:587` 设置 `cjHeapSize=128MB`，`:263`/`:298` 分别构造 Cangjie/JMH 命令，`:643` 起记录正式轮次。构建 trace 在正式计时前结束。

| 批次 | CV ≤ 5% 的库/工作负载组合 | 全七库均稳定的 workload | yjson 自身稳定 workload |
| --- | ---: | ---: | ---: |
| batch1 | 69/70 | 9/10 | 10/10，最大 CV 2.945003% |
| batch2 | 67/70 | 7/10 | 10/10，最大 CV 4.544604% |

全部 noisy 组合如下，文档应保留这些标记：

| 批次 | workload | library | CV |
| --- | --- | --- | ---: |
| batch1 | `large_array_decode` | `jackson` | 6.61306163755353% |
| batch2 | `address_encode` | `stdx_json` | 7.166776452129329% |
| batch2 | `large_array_decode` | `jackson` | 5.020714480250131% |
| batch2 | `large_map_encode` | `fastjson2` | 6.50562558200225% |

`stable_cv_le_5_percent` 是该 workload 七库 CV 的最大值判定，因此表中 9/10、7/10 与各组合的 69/70、67/70 不矛盾。主仓摘要程序在 noisy 时仍可正常退出；两批 exit 0 不能替代稳定性分类。成对比值方向是 `yjson / peer`，大于 1 表示 yjson 更慢；原摘要包含这类结果，文档必须保留其方向，不能表述为所有场景均更快。

## SDK、真实编译参数与产物绑定

23 份环境快照的已记录环境与身份一致；其中 9 份为含 SDK 文件清单摘要的完整边界快照，14 份为环境中间快照。CJC/CJPM 均为 1.2.0。SDK 清单为 1179 项，摘要 `ea7984dc5c37c02acf7f7119c24d7633a3b655f0c71350a8aa910c87abe00b5a`；CJC 二进制摘要 `023be1bb2ded1078906fc91919b3c1175ad14436ad88d23d505f7b8dcd0d7118` 与 Pure toolchain 和全部编译收据一致。相同已记录环境、源树摘要和 overlay 与两批元数据匹配。

逐条检查 14 份 compiler-argv 收据的 1799 条记录；其中 131 条被收据标为测量编译。每条测量记录的优化选项序列实际只有 `[-O2]`，最后有效选项为 `-O2`；没有出现先 O2、后 O1/O0 的覆盖。扫描、版本查询、构建辅助、编译期宏和未使用的测试启动器按实际职责分开，未把它们缺少 O2 误判为被测运行时代码。

另外从两批共 16 个原始 execve 日志重新解析，处理 unfinished/resumed 配对和失败的 PATH 候选：每批 481 次成功 native compiler exec，其中 39 次成功测量编译；两批合计 962/78，未决 execve 为 0。78 次成功测量编译均绑定所选 SDK 的编译器，最后有效优化全部为 O2。原收据的逐条记录可由日志重放得到；少量未完成行在收据中保留了后来失败的 PATH 候选，故 131 条收据标记记录不能直接称为 131 次成功编译。本项未造成优化参数或 SDK 身份矛盾。

Pure baseline/candidate 两份收据共记录 8 条测量编译，最后有效优化也全部为 O2。原五包没有提供 Pure 对应的原始 execve trace，本次对 Pure 的参数深度限于已散列的实际 argv 收据；七库则额外重放了原始 trace。

在归档 argv、已记录构建环境和清单中均未发现 `fno-`、CJDOC 配置或 cjdoc 路径泄漏。环境审计工具对其运行环境的检查逻辑已读取；本结论没有扩展为对未归档环境变量的独立观测。正式运行的 128MB/单 processor 由 runner 另行设定，不能因构建环境快照中的这两项为 null 而误判正式运行缺配置。

两批元数据内全部 Cangjie 产物 SHA 都与各自 `final-build-readiness.json` 对上，且两批相同；yjson/stdx 共用的七库二进制为 `7b2357a0502f36f02341b04685622ebd97a1136cb95cc0738d94a50a589fa6ca`。Pure baseline/candidate 二进制分别为 `a2ef68c47f49dc60d5283e2f7feae2f8b6941bb728b2ff8987f3b3fa1ccccc1c`、`375b881d725e0ee5b81e7b0b2e602f24b736a5a8659829566dcb86325671ba3b`，与准备收据相符。三份 linked-runtime 收据中 45 个同名动态库的摘要一致。

两批均独立重建 Maven，JAR 各 7363572 bytes，但 SHA 分别为 `81ad3897e737cf4ce3f70b2dd074afcbbc95d433775aedab8b6914561cf42fec`、`89e1f5eb6cb837889815ab5122bc3ab1bac7d541a25143f8d270878f3842d026`。Java 源码摘要、版本与批内构建记录一致；本报告不声称两批 JAR 字节相同，也未凭不同 JAR SHA 推断产品回归。SDK 和被测二进制本体未包含在本次五个数据归档中，本次验证的是归档的摘要/来源/调用记录一致性，没有重新散列远端现存二进制。

## peer source_digest 与完整源码装配

按可信 `run_full.source_digest()` 从归档字节重新计算全部七根来源摘要，并逐项核对 `source-input-manifests.json`、两批 metadata 和三份 build-readiness：

| source-inputs 根 | 纳入 digest 的文件数 | 重算 SHA-256 |
| --- | ---: | --- |
| `cangjieJSON-upstream` | 37 | `3cbc88bec383ce9b2a4bddf1d19dfc2e3cdd27520ecad46caa17ee2910f80dc2` |
| `cjfast-json` | 32 | `cca9574435230c10928df3fdf97ac2173098d56fc268f53fc845d6761c10d350` |
| `harness/cjjson` | 2 | `f88531b32bfbbf2a897a6a6b4d2bd52f3da19c6db257f29f573e07c1d66ba398` |
| `harness/java` | 3 | `26fc932638449295066eae5da5ca8c0c036041e337217e5533e824e8b7840cc9` |
| `harness/json4cj` | 2 | `9d394e35bc1411c8e06ccc7accd3d1b906a354a7b53689280e91fdad676ba8eb` |
| `json4cj` | 197 | `cfe474e19fd040b82c037ce34695c713564b19f2600ede8da8ee65189725f4ce` |
| `repo` | 184 | `c853aaf10d81eea5b94e5d3dffd7c370ab228b5be32ef4babf13580cd1e89349` |

该 digest 原算法只纳入 `.cj/.toml/.java/.xml`，排除 `.git/target/build-script-cache`。归档额外带的五个 LICENSE 不属于该摘要，不应当作“清单多出文件”错误。此摘要也不等于覆盖 Python/native C 输入的完整 canonical harness 摘要。

追加只读核验 `perf/public-assembly/`：

- 完整 `source-inputs/repo` 的 502 个文件逐项匹配原 `canonical-production-source.tar.gz`，原包 SHA 为 `9ac9240619307db68e5fe67ec701eae797d8a84d96fcd61cb6fa0e109fb2ab47`。187 个原重叠文件全部同字节，新增 315 文件来自冻结导出。原下载五包仍未改。
- 从完整目录实际重新生成 51 项 product manifest 和 51 项 effective harness manifest，分别逐项等于 `complete-product-manifest.json`、`complete-effective-harness-manifest.json` 及测量前 identity 清单；摘要仍为 4251be…/9d457f…。
- 用可信 `release_candidate_binding()` 在完整冻结导出上重算，结果逐字段等于 `frozen-candidate-binding.json`。候选 identity 为 `20ba99ff997c35bc277601c6fd8a4f76fb84ad460925b6c21e4a08f6facdfa22`；版本 0.2.0、根 manifest/lock、release graph 与 lockstep 清单均绑定。
- 完整装配后再算七根 `source_digest`，全部不变。新 harness tar 内文件与装配目录逐文件匹配。`source-closure-verification.json` 关于重叠、新增、两清单摘要、原件未改的声明均获字节核验支持；其中 `cleanCheckoutGeneratorExecuted=false` 被保留，未误写为已完成干净检出验证。

## 证据限制与下一步

数值完整性、归档完整性、来源摘要、固定工作量、CV 分类和已记录实际优化参数已在本次范围内验收。没有已确认的产品回归超阈值或来源摘要冲突。七库的四条 noisy 记录是实际测量特性，需直接展示。

本次没有运行 `cjpm`、原生测试或任何性能测量；没有重跑 workflow、下载新远端数据、触发发布。也没有执行完整 `check_seven_library_evidence.py` / `perf-evidence-drift strict`、干净检出生成器、README/结果页/正式 marker 的最终绑定。主 agent 完成这些文档和 marker 装配后，应在最终干净候选上运行原 strict 门禁；只有该证据才支持完整 PR 性能资格结论。
