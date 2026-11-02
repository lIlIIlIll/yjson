# Issue #15：仓颉实现缺陷修复

## 范围与当前结论

[Issue #15](https://github.com/lIlIIlIll/yjson/issues/15) 跟踪本页 R01–R19。
当前状态：**完整完成本页 R01–R19 的实现与验收**。修复与验证在独立工作副本进行，不改动原工作区、暂存区或既有分支。
用户追加授权 push、创建 PR、合并及合并后关闭 Issue；执行记录见下文“PR 交付”。

实现基线为主仓库 `c474263c72615f30b030bf9e8cf86b4573fbef12`，宏依赖为
`d819745310f8cc6aa416e1298f706ea5138b7d16`。宏源码属于独立仓库，分支及最终依赖绑定单独记录。
修复前审查基于 `4241647e51c9324ffe7ebb60946857c28e1bbce1` 与宏
`c9ef52da9ba2d3f77916c40ccb9280db78ee2e07` 的工作树快照；其生产源码摘要为
`373adeebd974b6f641bd674db69ce54ff63bff3acc9cee294c2aa401b2da39c8`。
旧证据仅用于对应未改变的缺陷路径，不代替修复后验证。

## 需求—实现—验收矩阵

所有条目均来自 Issue 同名条款，均为必需项；没有批准移出范围的条目。状态区分未实现、
部分实现、已实现但未验证、验收通过、外部阻塞和经明确批准移出范围。
R01–R19 及公共门禁 G1–G3 均已通过。下表 S1 指生产修复提交
`0d4d39a3e92ccaf4d3d0a37367160973dad21dbd` 与宏 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。
V1–V8 的命令、源码摘要和证据见下节；后续验收记录与证据清单不改变已测产品或 harness。

| ID / 来源 | 必需/条件 | 可观察验收结果 | 实现与产品接入位置 | 验证方法及实际结果 | 适用版本 | 状态 | 剩余缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R01 / Issue R01 | 必需 | 生成 Map 拒绝普通/转义等价重复键；LastWins 正常 | 宏 `codec_decode_plan.cj` 改走策略感知 codec | V1、V2 的具体/隐式/语义入口及 map 回归通过 | S1 | 验收通过 | 无 |
| R02 / Issue R02 | 必需 | 嵌套自定义 codec 拒绝重复键；对象作用域互不污染 | `FastSemanticReaderAdapter.readName` 的对象名称集合 | V2 嵌套 codec 回归及 V8 严格探针通过 | S1 | 验收通过 | 无 |
| R03 / Issue R03 | 必需 | 集合元素跳过未知字段仍执行重复键、深度及语法策略 | 宏 `readFastDirect` 调用 `skipValue` | V1、V2 的未知嵌套值、深度及非法语法回归通过 | S1 | 验收通过 | 无 |
| R04 / Issue R04 | 必需 | Native 不匹配内联访问抛 JsonException；正确访问和关闭语义保持 | `NativeCompactJsonValue.asInt64/asBool` 在资源检查后核对种类 | V3、V6 和 V8 真实后端公共入口通过 | S1 | 验收通过 | 无 |
| R05 / Issue R05 | 必需 | yyjson direct/回退均拒绝非布尔访问 | `YyjsonJsonValue.asBool` 不再读取无关 node 0 | V3 的 direct、转义重复键回退、关闭及并发回归通过；V6/V8 通过 | S1 | 验收通过 | 无 |
| R06 / Issue R06 | 必需 | 转义扩张后安全写出后续字段；String/bytes 与语义路径一致 | 宏 `json_codec.cj` 恢复剩余字段容量界限，不复制已有输出 | V1、V2 的转义扩张、后续字段和输出边界回归通过 | S1 | 验收通过 | 无 |
| R07 / Issue R07、#9 的 002 | 必需 | skip 接受空白和跨块分隔符，仍拒绝尾随逗号 | fast/direct 三个对象 skip 循环消费分隔符后空白 | V1 根包、V2 单字节流及下一字段/元素边界、V8 通过 | S1 | 验收通过 | 无 |
| R08 / Issue R08 | 必需 | 分文件嵌套模型编译并往返；首次并发使用安全 | 类型化 provider、延迟字段状态和递归能力查询保护 | V1、V2 跨文件、8 worker 并发、递归模型、动态能力撤销/恢复及独立程序通过；G3 Deep Nested 对照通过 | S1 | 验收通过 | 无 |
| R09 / Issue R09 | 必需 | 接口模型正常；真实父类字段组合，多态不回归 | `GeneratedInheritedObjectFieldsV1<T>` 和无反射父类型检查 | V1/V2 接口、泛型接口、混合继承、两/三层父类及现有多态通过 | S1 | 验收通过 | 无 |
| R10 / Issue R10 | 必需 | 具体 String 与泛型/bytes/语义入口遵守同一默认预算 | `newValidatedFastReader` 接入具体生成入口 | V1/V2 的 256 层、8 MiB 临界及超限回归通过；四入口仍拒绝短非法输入 | S1 | 验收通过 | 无 |
| R11 / Issue R11 | 必需 | map 与内层数组分别计深度，空 map 边界保持 | 四个批量 writer 入口检查一层或两层容器 | V2 String/bytes/stream、生成字段和 raw SPI；V8 通过 | S1 | 验收通过 | 无 |
| R12 / Issue R12 | 必需 | 手写语义容器与生成 raw 容器合计深度 | raw 对象入口复用 semantic + raw 深度检查 | V2 混合 codec、pretty 对照及合法边界通过 | S1 | 验收通过 | 无 |
| R13 / Issue R13 | 必需 | readNode 完整消费多元素嵌套数组，不重复消费分隔符 | `FastSemanticReaderAdapter.readNode` 先准备值前缀 | V2 多层节点、非法分隔符回归；V8 通过 | S1 | 验收通过 | 无 |
| R14 / Issue R14 | 必需 | Pure 内联及普通节点的类型错误保持 JsonException | 四个 `CompactJsonValue` 标量入口先检查内联种类 | V1 对象/数组/根标量错误、正确访问和后续可用性；V8 通过 | S1 | 验收通过 | 无 |
| R15 / Issue R15 | 必需 | 不完整 bool 返回 parse_error；合法值保持 | fast/direct bool 首字节访问前检查 EOF | V1/V2 空白、截断、具体/泛型、bytes/stream；V8 通过 | S1 | 验收通过 | 无 |
| R16 / Issue R16 | 必需 | 非法支持关键词及未使用的非法子 schema 在构造阶段拒绝 | Schema 形状/取值校验、共享子 schema 位置及精确整数检查 | V4 未用分支、外部资源、整数边界和 vocabulary；V7 全量标准语料；V8 通过 | S1 | 验收通过 | 无 |
| R17 / Issue R17 | 必需 | 非法 Unicode 变量返回 false，Unicode literal 与 ASCII 模板正确 | URI template 保留 UTF-8 literal 切片，按字节识别 ASCII 操作符 | V5 Unicode/操作符/控制字符/非法结构、V7 optional formats、V8 通过 | S1 | 验收通过 | 无 |
| R18 / Issue R18 | 必需 | 无定位 OOM 保持 out_of_memory/location=None；有效定位保留 | 两个后端错误包装器把负偏移映射为无 location | V3 精确偏移；V8 对真实静态库的单次 calloc 故障注入通过 | S1；V8 包装器源码相同 | 验收通过 | 无 |
| R19 / Issue R19 | 必需 | map 错误保留父路径和 Pointer 转义，退出后恢复 | 两个 fast Int64 map 入口维护自己的路径槽 | V2 数组索引、生成父字段、转义键和成功读取；V8 通过 | S1 | 验收通过 | 无 |

## 验证记录

修复前复现使用 Linux x86_64、STS `1.2.0`、`-O2`、128 MiB 栈；Native/yyjson 使用真实依赖，
国际化格式使用 libidn2 `2.3.8`。探针捕获异常后退出 0 不表示产品契约通过。
R18 是窄范围分配故障注入，不是实际耗尽机器内存。

已使用 STS `1.2.0`、`-O2` 编译实际运行时、算法、backend、Native、yyjson 和格式库。
同一严格探针在审查快照与修复副本上的结果如下；非零退出码表示预期的修复前失败。

| 探针 | 覆盖 | 审查快照 | 修复副本 | 任务证据目录中的日志 |
| --- | --- | --- | --- | --- |
| `runtime-contracts.cj` | R02、R07、R11、R13、R14、R15、R19 | 7 项失败，退出 7 | 7 项通过，退出 0 | `logs/runtime-contracts-baseline-run.log`、`logs/runtime-contracts-run.log` |
| `backend-schema-contracts.cj` | R04、R05、R16、R17 | 4 项失败，退出 4 | 4 项通过，退出 0 | `logs/backend-schema-baseline-run.log`、`logs/backend-schema-contracts-run.log` |
| `allocation-contract.cj` | R18 | Native OOM 被负位置异常覆盖，退出 1 | Native/yyjson OOM、有效定位及正常解析均通过，退出 0 | `logs/allocation-contract-baseline-run.log`、`logs/allocation-contract-run.log` |

### 完整功能验证

V1 和 V2 的报告都绑定同一 `yjson.package-source/1` 快照：
运行时 `fcb8a1ef9b020bae02ca731cf2e45916c03a1566d2ca90c996f0177a26ef66a5`，
宏 `4687474127aa78c7d92ae2e09a15e9e6c1360fbe7f14e805c5cd48e97c5fc01f`。
报告保存逐文件摘要。之后修改的 README、记录和 Git pin 不改变这些已测 `.cj` 文件；
生产 Git 依赖路径仍由 G1 单独核验。

| 证据 | 实际命令/入口 | 结果 | 任务证据目录中的记录 |
| --- | --- | --- | --- |
| V1 | 宏仓库 `python3 tests/run_characterization.py --runtime <checkout> --output-dir <task>/macro-characterization-fourth --override-compile-option=-O2` | runtime 599/599、宏消费方 17/17；四个文档消费方构建和执行通过；删除宏按预期编译拒绝 | `macro-characterization-fourth/report.json` 及同目录日志 |
| V2 | 冻结 runtime、宏及 `codec_integration`，对齐本地依赖后 `cjpm test --no-color`；随后 `scripts/run_cjpm_executable.sh` | 78/78，实际消费方程序退出 0 | `codec-integration-twelfth/report.json`、`consumer-test.log`、`consumer-executable.log` |
| V3 | `modules-fourth/yjson_native` 与 `yjson_yyjson` 中 `cjpm test --no-color` | Native 19/19，yyjson 23/23，退出 0 | `logs/optimized-native-test.log`、`logs/optimized-yyjson-test.log` |
| V4 | `modules-fourth/yjson_algorithms` 中 `cjpm test --no-color` | 63/63，退出 0 | `logs/optimized-algorithms-test.log` |
| V5 | `modules-fourth/yjson_schema_formats` 中 `cjpm test --no-color` | 4/4，退出 0 | `logs/optimized-formats-test.log` |
| V6 | `python3 scripts/release_consumer_checks.py --modules-root <task>/modules-fourth --override-compile-option=-O2` | core、macro、algorithms、schema_formats、native、yyjson 六个外部程序全部通过 | `logs/optimized-external-consumers.log` |
| V7 | `python3 scripts/run_standards_conformance.py --cache <task>/standards-suites --offline --include-schema-optional --override-compile-option=-O2 --keep-manifest <task>/optimized-standards-manifest.json --report <task>/optimized-standards-report.log` | Schema 2263（含 optional 964）、Path 703、Patch 108，共 3074/3074 | `optimized-standards-report.log`、`optimized-standards-manifest.json` |
| V8 | 上表三个严格探针；独立跨文件初始化程序 | 严格探针均由失败转为通过；跨文件程序从 SIGSEGV 转为输出正确 JSON、退出 0 | 上表日志及 `logs/cross-file-init-run.log`、`logs/cross-file-init-fixed-run.log` |

`modules-fourth` 由冻结提交 `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd`
运行 `python3 scripts/release_package_stage.py <task>/modules-fourth --development` 生成。
包测试只在临时树补入根包的本地宏 test dependency，并把宏优化级别设为 `-O2`；
不改发布 manifest 的依赖语义。所有构建使用 STS `1.2.0`、`-O2` 和 128 MiB 栈。
V3–V7 已在性能修复后的最终 `.cj` 源码重新通过。V8 保留修复前失败与修复后通过的严格探针，
其后端访问、Schema、格式和错误路径实现未再改动；共享运行时和生成代码另由 V1、V2、G1 核验。

接口与暂存检查已实际通过：`python3 scripts/check_api_inventory.py`（1128 条声明）、
`python3 scripts/test_stage_source_tree.py`（6 项）和
`python3 scripts/test_release_temp_tree.py`（15 项）。
证据文档加入后再次通过，记录为 `logs/publication-api-inventory.log`、
`logs/publication-source-stage.log` 和 `logs/publication-temp-tree.log`；初次记录保留。

生产 Git pin 路径另以 `YJSON_CI_DEPENDENCY_OVERRIDE=-O2 bash scripts/ci_job.sh macro-consumer`
实际验证：78/78 集成测试、消费方可执行程序和暂存宏外部消费方全部通过，退出 0。
宏 pin 为 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`，仅使用进程级 URL 路由从本地宏仓库取该提交；
日志为 `logs/optimized-pinned-macro.log`。初次候选曾在 SDK 版本前置校验处退出 2：
任务设置的弃用 `CJPM_CONFIG` 令 `cjpm --version` 多出警告，而版本校验要求单行输出。
移除该变量并使用隔离 HOME 后通过；没有放宽版本解析或产品断言，首次日志仍保留。

全部十个变更 Markdown 的链接检查已通过，记录为 `logs/publication-markdown.log`。实际命令：

```sh
python3 scripts/check_local_markdown_links.py \
  CHANGELOG.md README.md docs/codec-generation.md docs/schema.md docs/implementation/issue-15.md \
  docs/performance/README.md \
  docs/performance/results/2026-10-30-issue-15-contracts-pure.md \
  docs/performance/results/2026-10-30-issue-15-contracts-seven-library.md \
  benchmarks/results/full-seven-library/2026-10-30-issue-15-contracts/README.md \
  packages/yjson_macros/README.md
```

### 首次失败及范围外问题

- R08 去掉跨文件私有引用后，曾暴露 codec 全局初始化顺序导致的 SIGSEGV。延迟状态发布修复后，
  独立程序及完整集成均通过；V2 还覆盖并发首次使用、递归能力查询和能力不支持时的写入回退。
- 动态能力回归测试初次编译因自定义 codec 全局变量声明顺序失败；调整新测试的声明顺序后，
  V2 的 78 项用例全部通过，未修改生产能力检查或降低断言。
- yyjson 新增定位测试最初把尾随逗号的期望位置写成右括号。实际 yyjson 指向逗号；
  按 `native/vendor/yyjson/yyjson.c` 的错误定位分支修正新用例为 offset=6、line=2、column=3，
  未修改生产错误定位或其他断言，最终 23/23 通过。
- Schema vocabulary 诊断在基线与候选两侧均因非法字符串 `minimum` 于构造阶段抛异常；
  `logs/schema-vocabulary-baseline-run.log` 与 `logs/schema-vocabulary-candidate-run.log`
  保留这一既有行为，不计为回归或 PASS。
- 已在修复前源码复现并单独登记：宏
  [#11 泛型跨文件继承](https://github.com/lIlIIlIll/yjson_macros/issues/11)、
  [#12 命名构造参数](https://github.com/lIlIIlIll/yjson_macros/issues/12)，以及主仓库
  [#16 普通快速标量错误缺少父路径](https://github.com/lIlIIlIll/yjson/issues/16)。
  这些不属于 R01–R19，未扩展为本任务修复项。

### 公共门禁

- G1 已通过：生产源码冻结为 `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd`，
  宏为 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。真实 Git pin 的集成与外部消费方均通过。
- G2 已通过：S1 的干净源码导出通过；加入证据后的干净检出
  `6630fba97bafd52deedc93b02f7638564f1ec838` 再次通过
  `python3 scripts/check_seven_library_evidence.py --print-current-candidate` 和
  `python3 scripts/release_temp_tree.py <task>/evidence-release-source --enforce-clean`。
  后者复制 387 个文件。记录为 `logs/evidence-clean-identity-second.log` 和
  `logs/evidence-clean-release-export.log`。复制的 Git index 与源码不一致的首次失败保留；
  在任务副本内通过 GitButler 模式切换重建 index 后通过，没有修改产品源码或放宽干净树要求。
- G3 已通过：最终源码的完整 Pure 24 项、每项 11 轮通过，所有 C/B ≤ 1.05，
  最大比率为 1.043291，最大单侧 CV 为 2.275%。相对修复前 HEAD 的 Deep Nested
  String/Bytes 比率分别为 1.000132 和 0.999884。完整结果见
  [Pure 报告](../performance/results/2026-10-30-issue-15-contracts-pure.md)。
  初次候选的完整 Pure 因 Person 编码约 1.953 倍、ProfileBundle 编码约 1.50 倍而退出 1；
  首批原始样本、失败候选和六组三轮诊断均保留，诊断不计为正式资格。
  采用具体类型字段状态、稳定 compact 能力缓存和短输入预算证明后，重新冻结并完成全矩阵。
  七库准备首次因校验脚本使用错误的 SDK 清单序列化格式而停止，未开始测量。
  改用原协议后，1179 项 SDK 清单与原始摘要完全一致，真实生产 Git pin 的 `-O2` 构建通过；
  未更换 SDK，也未放宽断言。两批七库各完成 770 个单元，均有 7/10 workload 全库稳定，
  yjson 的十项在两批中均稳定；预检、SDK、源码、产物和离线重算全部通过。
  完整结果见[七库报告](../performance/results/2026-10-30-issue-15-contracts-seven-library.md)。
  干净检出 `6630fba97bafd52deedc93b02f7638564f1ec838` 的
  `bash scripts/ci_job.sh perf-evidence-drift strict` 通过：40/40 回归，源码新鲜度、摘要、
  清单、身份和汇总检查全部通过，退出 0。公开证据目录保留
  `strict-verification.json` 和原样的 `strict-verification.log`。
  原 strict 因旧证据绑定旧源码而失败，保留 `logs/strict-evidence-before-refresh.log`；
  不使用 `integrity-only` 放行。

上述验收记录不包含托管 CI、Windows/macOS 或发布资格；本地 Linux 结果不代替这些维度。
PR 创建后的托管检查与合并结果以对应 GitHub PR 和 Issue 记录为准。

## 兼容性与交付

恢复既有重复键、资源限制、类型错误、路径和 Schema 契约，不删除应用 API，不改变默认选项或 C ABI。
新增的类型化继承字段、延迟状态、能力查询和默认预算预检接口属于生成代码 SPI，已同步 API 清单与快照。
不使用 `std.reflect`；未生成对象字段协议的真实父类仍拒绝，接口不被误当作父类。

宏修复已提交到独立仓库的 `fix/issue-15-cangjie-macros`：
`2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。主仓库使用
`fix/issue-15-cangjie-contracts`；初次冻结的生产修复提交为 `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd`。
所有使用方 manifest/lock 同步绑定上述宏提交。
初次验收通过进程级 Git URL 路由读取该精确宏提交；公开远端依赖验证另列于下节，不混称为同一次验证。
升级时同步运行时与宏、重新展开并编译消费方；回退时整体回退这组配对源码，不混用新宏和旧运行时。
合并顺序为宏仓库、主仓库；主仓合并后才关闭 Issue #15。不创建 tag，不发布包。

## PR 交付

发布前使用 GitButler 更新到主仓 `main` 的 `f632e0951110f1fcaeb2a88deb696174ef16990e`，
生产修复提交重放为 `a6c2bcee935fd380182b1df3882a9ad394e019f0`。宏 pin 不变。
更新前后逐项比较产品和 harness 输入清单，两者与 S1 的已测输入完全相同：

- 产品摘要：`e53700605a8d479abd69b504a138278dc0f9e7be1df6bcd5a8332d0e6e7e5368`。
- harness 摘要：`3f1c2c1de5ae803f99e344a9a283057674ff2de72154cb66389b5b6d833dc8c5`。

以上是源码等价性核验，不是新一轮性能测量；保留原始测量提交、首次失败和全部原始样本。
[宏 PR #13](https://github.com/lIlIIlIll/yjson_macros/pull/13) 已普通 merge，
合并提交为 `ded48ae2a4d8eb9847467d1fc767da05b8dc415c`，保留精确依赖提交
`2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。宏仓没有 GitHub Actions 工作流；
主仓 PR 负责该配对候选的托管检查。

更新上游后的干净候选 `6cdff21e32ef83bb2a553551c50d97f6d7062076` 已完成：

- `bash scripts/ci_job.sh perf-evidence-drift strict`：40/40 回归及完整新鲜度、校验和、
  清单、身份和汇总检查通过，退出 0，日志为 `logs/publication-rebased-strict.log`。
- 启用 STS `1.2.0` 后，以新的空 HOME、清除本地 Git 路由执行以下命令：
  79/79 集成测试、实际程序和暂存宏外部消费方通过，退出 0，
  日志为 `logs/publication-public-macro-consumer.log`。本次实际使用公开远端宏 pin，
  与上文初次验收的本地 URL 路由证据分开记录。

```sh
env -u CJPM_CONFIG GIT_CONFIG_COUNT=0 HOME=<empty-home> \
  YJSON_CI_DEPENDENCY_OVERRIDE=-O2 bash scripts/ci_job.sh macro-consumer
```

本轮仅提交 Issue #15 的修复、回归、接口清单及验收证据，
不包含复制到独立工作副本的其他工作树修改。

### PR 首轮门禁与修正

[主仓 PR #20](https://github.com/lIlIIlIll/yjson/pull/20) 的首轮
[CI 41383879415](https://github.com/lIlIIlIll/yjson/actions/runs/41383879415)
绑定 `9a5ba39bafddaa10ec0bf582b1c9b8a55d1ffc25`，出现以下失败；这些记录不计为通过：

- API Documentation 的仓库链接集成测试写死了旧性能报告文件名。删除具体文件名集合和文件数量快照，
  保留当前链接必须进入发布清单、补充材料正文不能成为生成输入、冻结源码可独立构造文档工作区的契约。
  `python3 scripts/test_generate_api_docs.py` 已通过 51 项；真实冻结与工作区构造冒烟验证了两个新报告链接，
  并通过临时故障注入证明“读取补充材料正文”仍会被该测试拒绝。
  记录为 `logs/pr-doc-link-contracts.log` 和 `publication-20261102/doc-link-smoke.log`。
- Core Coverage 未收集已有的外部 codec 回归。收集器加入 `codec_integration` 的核心库覆盖记录，
  不新增重复测试，不把消费方或宏源码纳入分母，不改覆盖率门槛。
- `core` 和 `registry-rehearsal` 的日志明确记录 runner 收到关闭信号，前者退出 143，后者取消；
  日志中没有对应的源码失败诊断，仍须由后续托管矩阵完成验证。

`bash scripts/coverage.sh` 已实际通过，包含根包 599 项、外部消费方 79 项、十个独立进程场景
和 Native 加速 13 项。对相同基线 `f632e0951110f1fcaeb2a88deb696174ef16990e` 的产品 diff，
继续使用原 `coverage-baseline.toml` 检查：

| 指标 | 首轮 CI | 补入消费方后本地结果 | 门槛 |
| --- | --- | --- | --- |
| 核心行 | 8672/10449，83.0% | 8853/10449，84.7% | 80% |
| 核心分支 | 3834/5330，71.9% | 3914/5330，73.4% | 70% |
| 改动行 | 111/134，82.8% | 132/134，98.5% | 90% |
| 改动分支 | 54/90，60.0% | 79/90，87.8% | 80% |

命令与结果分别保存为 `logs/pr-consumer-coverage.log` 和 `logs/pr-consumer-patch-coverage.log`；
LCOV 为独立工作副本的 `coverage/lcov.info`。改动覆盖率命令：

```sh
python3 scripts/check_patch_coverage.py --diff <task>/publication-20261102/coverage-patch.diff \
  --lcov coverage/lcov.info --baseline coverage-baseline.toml
```

本次未修改仓颉产品源码、性能测量脚本或覆盖率门槛；产品与 harness 的逐项输入清单仍与 S1 相同。
修正后的托管 CI、合并与 Issue 关闭以 PR #20 和 Issue #15 的最终记录为准，不以本地结果替代。
