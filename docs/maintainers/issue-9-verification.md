# Issue 9 修复与验证记录

关联 [issue #9](https://github.com/lIlIIlIll/yjson/issues/9) 与
[PR #10](https://github.com/lIlIIlIll/yjson/pull/10)。当前结论：**未完整完成**。

## 当前 STS 1.2.0 候选验收

- 本轮 BASE：`ae44984c729ac5149fef051ab828fb11fa5a89a9`。
- 原 PR：`9212a50f00160ec0834f39c68f6ef6e1e9b6248f`；已用 GitButler 重放到 BASE，
  合并发布清单增量并保留 main 的逗号后空白处理。
- 首次冻结源码 C1：`57cfddb61834fb1d3c5c2e573ff6d986124045e2`，已受保护推送到原 PR，
  保持 Draft。其完整 Pure 资格失败，后续编码热路径修复仍须重新冻结和验收。
- C2：`87f37a76ff02d1214158c787ca6732aaa97ecbd6`，仍为 Draft；完整 Pure 再次失败，
  新增的固定上界优化在 Int64 Map 编码路径出现稳定回退，已撤回该实验。
- 当前冻结 C3：`aa128768beaaa4383586ae306ab0c0d2f74ce172`；保留容量 span 短路，
  撤回固定上界实验；原 PR 保持 Draft，最终交付仍须以下完整资格。
- 宏 pin：`2bfd34c08c421c04a0cd8e3d1326140849f1f21b`；九包候选 `0.2.0`，
  SDK STS `1.2.0`，文档工具 cjdoc `0.7.7`。本轮运行结果不得由下方旧 SDK 证据替代。
- 历史 [CI run 37011774364](https://github.com/lIlIIlIll/yjson/actions/runs/37011774364)
  已结束，根失败是 Seven-library evidence drift 的 product SHA 不匹配，
  CI Required 随之失败；不再标作运行中。

下列来源均为 Issue #9 对应条款及其实施交付要求。状态只记录本轮证据。
下文分别记录冻结 C1、后续热路径修复与最终 HEAD；C1 的失败不能改写成新候选通过。

| 需求 ID | 来源/必需性 | 可观察验收 | 实现与测试 | 版本/状态 | 剩余缺口 |
| --- | --- | --- | --- | --- | --- |
| 001 | 001，必需 | 解码键判重、作用域独立；15 组合线性工作量 | direct/fast reader；issue9 skip 与 consumer；scaling script | 已实现，聚焦验证通过 | 最终干净检出与托管门禁 |
| 002 | 002，必需 | 合法空白所有分块读到后续值，非法语法仍拒绝 | main Issue15 与 issue9 skip 测试 | 已实现，聚焦验证通过 | 最终干净检出与托管门禁 |
| 003 | 003，必需 | 预算前置；cycle/depth/DAG；输入不变 | algorithms patch；work_limits_test | 已实现，71 项算法测试、标准套件通过 | 最终干净检出与托管门禁 |
| 004 | 004，必需 | 零容量前进；负数拒绝；溢出不写入 | direct writer；writer/document 测试 | 已实现，core 与公开 API smoke 通过 | 最终干净检出与托管门禁 |
| 005 | 005，必需 | 同路径 move 必须验证源存在 | jsonPatchMove；pointer patch 测试 | 已实现，算法、标准套件与外部 smoke 通过 | 最终干净检出与托管门禁 |
| 006 | 006，必需 | 超限分配前拒绝；合法输入拥有式复制 | parseOwned；writer/document 测试 | 已实现；8 MiB/limit64 分配 1032 bytes、GC=0；所有权 smoke 通过 | 最终干净检出与托管门禁 |
| 007 | 007，必需 | F16/F32 目标舍入；Pure/Native/yyjson；负零生命周期 | target float、builtin、tape、Native C/CJ 与测试 | 已实现；collection、两完整后端、各 7869 个 oracle 向量通过 | 最终干净检出、coverage 与托管门禁 |
| 008 | 008，必需 | 流错误真实 byte offset/line/column，无坐标不伪造 | parser cursor、resource helper、resource tests | 已实现；跨窗口与转义测试通过 | 最终干净检出与托管门禁 |
| CI | 交付要求，必需 | O2 core/consumer/native/standards/coverage/打包与全部 Required | ci_job、fresh checkout、hosted CI | C3 干净 O2 core/consumer、专项 oracle 与 scaling 通过；历史平台结果单列 | 最终完整 fresh checkout 与该 HEAD 的全部 Required |
| 性能 | 交付要求，必需 | Pure 24 项、Deep Nested 2 项、两批七库及 strict freshness | 服务器源绑定测量与可信离线复算 | C3 Pure/HEAD、两批七库和可信离线复算通过；C1/C2 均保持 FAIL | 证据提交后的最终 strict |

### 本轮实际验证（冻结前）

SDK 均为 `cjc`/`cjpm` STS `1.2.0`。以下适用于 BASE 重放后的工作源码，
不是最终提交的干净检出资格。

| 命令/场景 | 实际结果 | 证据边界 |
| --- | --- | --- |
| `check_skip_work_scaling.py --work-dir <task>/skip-candidate` | PASS，15/15；128/256/512 键各执行同量 hash、0 equality；翻倍工作量 2 倍 | O2，8192 KiB native 栈，SDK 默认 managed 栈 |
| `check_target_float_rounding.py` 与 `--native` | 各 7869 向量、0 mismatches | O2；Native 模式只覆盖 primitives，不替代两个完整后端 |
| 临时外部 consumer 的 `cjpm run` | exit 0；Float32 bits=1065353217，零容量输出 abc，缺源同路径 move 为 json_patch_path，覆盖原 bytes 后 name=Alice | O2，8192 KiB 栈；真实公开 API 执行 |
| `ci_job.sh core` 两次工作源码运行 | 各 629/629，0 skipped/errors/failed；第二次包含宽对象与跨窗口回归 | 服务器 O2；最终干净检出仍须完整运行 |
| 新增 Native 文档级负零回归，修复前 `cjpm test --no-color` | 20 PASS、1 FAIL；两个 bulk 物化重载均把 -0 改为 0，Float64 bits 从 9223372036854775808 变为 0 | 已复现；view 级物化保持负零，缺口在 tape NUMBER 的整数折叠 |
| 修复后 Native 包 `cjpm test --no-color` | 21/21，0 skipped/errors/failed；bulk 物化保留 -0 文本与 Float64 bits | 与上行构成真实失败前/通过后证据 |
| algorithms 包 `cjpm test --no-color` | 71/71，0 skipped/errors/failed | 包含预算前停止、cycle、256/257 深度、DAG 与原地失败不变 |
| codec integration 包 `cjpm test --no-color` | 84/84，0 skipped/errors/failed | 包含新 array/map/Option 困难舍入与未知对象后的兄弟值 |
| 独立服务器进程运行 owned allocation 回归 | 8 MiB 输入、limit64，分配 1032 bytes、GC=0；1 PASS | filter 明确选中 1 项，628 项未选中；不记为整套 core 通过 |
| 分别运行 `ci_job.sh yyjson-native`、`native-clang`、`native-gcc`、`sanitizer`、`fuzz-short` | 均 exit 0；初次 yyjson 25/25 与暂存 consumer 通过；fuzz 5000 案例 | 后续含 fallback-inline 负零回归的 yyjson 26/26 及外部 consumer 也通过 |
| 第一批迁移验证失败 | macro consumer 的新测试错误使用 enum ==；algorithms consumer 缺 idn2.h；custom-native 误带入跨主机 build-script-cache；co-link 缺第二份 yyjson | 保存首次结果；测试改用 match，安装私有依赖、移除本轮误复制缓存并绑定校验通过的 yyjson 0.11.1 后重新验证，不放宽门禁 |
| 首次 coverage | core 629/629 后，consumer 编译因上述 enum == 失败 | 已修正测试，consumer 84/84 后重新采集；本次失败不算 coverage 通过 |
| API inventory、source-stage、release-temp | PASS；1128 声明，9 包；6 项 staging 与 15 项 temp-tree 测试通过 | 不证明运行行为或发布资格 |
| STS、candidate-wiring、cjdoc qualification 单测 | 6/6、19 PASS+1 明确 SDK 场景 skipped、12/12 | standards gate 必须实际执行被跳过的 SDK 场景 |
| 修正依赖后分别运行 `ci_job.sh macro-consumer`、`algorithms-consumer`、`custom-native`、`yyjson-native` | 均 exit 0，无未处理异常；consumer 84/84、algorithms 71/71、Native 21/21、yyjson 26/26，独立暂存使用方均通过 | 服务器 O2；保留第一批失败，不以重试代替根因修复 |
| `ci_job.sh yyjson-colink` | exit 0，四种组合通过 | 第二份源码为已核验 SHA-256 的 yyjson 0.11.1 |
| `ci_job.sh standards-conformance` 与 `schema-formats-conformance` | 分别 2110/2110、3074/3074；格式包 4/4；无 skipped 或未处理异常 | 离线冻结语料；实际执行本地单测中跳过的 SDK oracle 场景 |
| 仅公开 API 数值测试的 coverage 采集 | 项目行 9217/10592=87.0%、分支 4110/5496=74.8%，项目门槛通过；patch 分支 164/208=78.8%，未达到 80% | 不恢复任意错误候选值的内部校正函数测试；不降低门槛 |
| 拆分受保护表达式后 `bash scripts/coverage.sh` 与 `check_patch_coverage.py` | 项目行 9221/10596=87.0%、分支 4112/5496=74.8%；patch 行 265/276=96.0%、分支 167/208=80.3%，原门槛全部通过 | core 629/629、consumer 84/84、runtime 10 场景、Native accel 13/13；未恢复内部数值测试 |

用户选择仅保留公开 API 数值测试。覆盖率归一化器会保守地将条件行附带的未覆盖编译器检查边算为
未覆盖源分支；例如公开溢出测试已执行抛错行，但带减法的条件仍有未覆盖分支。
本轮把受保护的算术、窗口索引和显式判断分开，不修改判断、错误语义、checker 或阈值；
修改后的完整采集与 patch 检查均通过；不以归一化限制说明替代结果。

性能快照使用相同当前 harness、STS 和 path/lock overlay。固定发布基线保留原运行时及配套宏
`d819745310f8cc6aa416e1298f706ea5138b7d16`，其产品摘要仍为
`ee7b04b11c99ef76e0bb4ff07266466b702895ea35eff01aaa44362d94e8c4b6`；
BASE 与候选使用当前宏 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。
准备时把当前宏配给旧基线的构建失败，缺少 `GeneratedStableCompactWriteCodecV1` 等接口，
首次日志已保存。没有改旧基线运行时补接口；恢复其原宏配对后重新构建，不把依赖差异隐藏为
相同宏源码，也不把这次构建记为正式性能测量。
恢复原宏配对后的 STS 1.2.0 benchmark clean build 已通过，产品摘要未变，工作树干净。

负零修复仅排除 tape NUMBER 中的精确 `-0`；普通整数继续折叠。
永久回归同时检查独立节点、两个文档物化重载、错误 kind 和关闭后 resource_closed。

### 冻结 C1 与首次完整 Pure 失败

C1 的专用干净检出核验主仓与宏身份、产品及 harness 清单一致。
`release_temp_tree.py --enforce-clean` 实际复制 396 文件，
`check_generated_change_risk.py --base <BASE> --head HEAD` 通过，changed=36、risk=4。
外部 consumer 以 8192 KiB native 栈运行，保留负零物化、overflow reserve 后原内容，
以及两个流预算错误的 byte=3、line=2、column=3，进程 exit 0。

`ci_job.sh api-docs` 在 C1 上实际通过：九包站点、1052 声明、333 个 Doc IR 示例零失败，
应用契约覆盖率全部 100%。浏览器通过真实搜索与成员页核对 Float32 目标舍入、
writer 构造器零/负容量与溢出承诺、Merge Patch 复制前预算及 cycle/depth 错误。
托管运行 [41559520417](https://github.com/lIlIIlIll/yjson/actions/runs/41559520417)
已观察到 Windows/macOS Pure、Core Coverage 及多项 Linux 门禁成功；
Seven-library evidence drift 失败，不能把该次运行写为 Required 全绿。

2026-11-03 UTC 开始的正式 Pure 批按固定发布基线、当前共同 harness、STS 1.2.0 和实际 O2
完成 24 项 × 11 轮 × 2 侧，即 528 个正式单元及 48 个预检单元。
全部单侧 CV 不超过 3.499%，下列六项超过原有 C/B≤1.05：

| 用例 | C/B |
| --- | ---: |
| String encode Deep Nested Profiles | 1.069107 |
| String encode Person | 1.184501 |
| String encode Large Profile Array | 1.120838 |
| bytes encode ProfileBundle | 1.081583 |
| bytes encode Escaped Unicode String | 1.084746 |
| encode Person Memory | 1.056957 |

该批保持 FAIL；不因其他解码行改善而抵消，也不按 noisy 重跑。
原始日志、RSS、sidecar、源码快照与实际编译 argv 已封存为 3212 个普通文件，
原始私有包 SHA-256 为
`96fc882e5e76a19d3a6a3eef475fbf90f8bb5ff5a48558f4f8d572bc44965eba`。
正式 HEAD 对照及七库尚未开始。

服务器 perf 事件因 paranoid=4 被拒绝，未修改系统权限。使用原二进制、原 case 工作量及断言，
由父进程 GDB 采集 24 次侵入式栈，实际出现 buffer reserve/ensure-capacity 路径。
此类采样不计为性能或测试验收。单变量三轮诊断确认，已在剩余 span 内的请求可避免再次求和和
进入增长路径；增长、负尺寸及溢出仍走原受检路径。诊断不替代后续完整 24 项资格。

### 冻结 C2 前的 writer 实验与检查

一、二操作数预留只在所有操作数非负、且剩余 span 足够的证明成立时提前返回；
增长、负数与溢出继续进入受检路径。流式原 case 的直接采样出现
`writeTextStringArrayListNoEscape`；C2 实验的实际 O2 反汇编显示，
将固定 Int64 上界写为私有编译期常量后，`Int64.Max` getter 调用由 4 次降为 0 次。
该实验未切换 overflow 策略或移除尺寸检查，但因后续完整资格的 Map 回退而撤回。

单变量 memory 三轮对照为 C/B=1.0134，不能据此声称改善。六项探索对照也不是完整资格；
后续必须用重新冻结源码执行完整 24 项、HEAD Deep Nested 与两批七库。

| 命令/场景 | 实际结果 | 证据边界 |
| --- | --- | --- |
| `bash scripts/coverage.sh` | core 629/629、consumer 84/84、runtime 10 场景、Native accel 13/13；项目行 9225/10601=87.0%、分支 4120/5508=74.8% | 后续 writer 源码，coverage 使用原有 O0 instrumentation，不替代 O2 资格 |
| `check_patch_coverage.py` | patch 行 270/281=96.1%、分支 177/220=80.5%，原门槛通过 | 包含全部新增 fast-fit 分支；未增加私有实现测试 |
| 外部 consumer `cjpm clean`、`cjpm build` 后实际运行 | exit 0；Float32 bits、abc、缺源 move、Alice、负零物化、overflow 后内容及两种流错误精确坐标均符合预期 | O2，8192 KiB native 栈、默认 managed 栈 |
| API inventory、source-stage、release-temp | PASS；1128 声明、9 包；staging 6/6、temp-tree 15/15 | 公开签名未变；完整干净资格仍待运行 |

### C2 完整资格失败与来源隔离

C2 的专用导出核验 HEAD、宏、产品及 harness 身份一致，工作树干净；
`release_temp_tree.py --enforce-clean` 复制 396 文件，generated risk 为 changed=36、risk=4。
干净源码的 O2 `core` 为 629/629，`macro-consumer` 为 84/84，
可执行 consumer 与九模块暂存后的独立 macro consumer 通过，无 skipped 或未处理异常。

正式 Pure 按原 24 项、11 轮执行完 528 个计时与 48 个预检单元。
C1 的六项超限均回到门槛内，但 `yjsonStringEncodeLargeInt64Map` 的 C/B 为
1.096678；两侧 CV 为 0.60% / 0.31%。这是稳定回退，不按噪声重复同源码完整批。
保留 3247 个普通文件、全部宏构建输入与 SDK/实际 O2 回执；原始私有包 SHA-256 为
`9fa8757bbf75be34350f7f8938e96bc482984cb818e36a76083c41d8f9109929`，
下载后每个成员的字节数和 SHA-256 均与封存清单一致。

三个相邻源码变体各只改变 writer，使用已核验的原 O2 产物、相同完整 harness 做三轮隔离。
一操作数与二操作数 fast-fit 的 Map 对照分别为 0.986 / 0.975；
只加入固定上界常量后为 1.102，且三轮均更慢，Person 对照未显示可靠收益。
因此保留两个已证明的 span 短路，恢复原 `Int64.Max` 上界表达式；
不根据少四次 getter 调用推断整体更快，也不放宽错误或溢出检查。

### 撤回后源码检查（C3 冻结前）

| 检查 | 实际结果 | 边界 |
| --- | --- | --- |
| 完整 coverage 与原 patch gate | 项目行 9225/10601=87.0%、分支 4121/5508=74.8%；patch 行 270/281=96.1%、分支 177/220=80.5%；所有门槛通过 | 仅保留公开数值测试，core/consumer/runtime/accel 全部通过 |
| O2 外部 consumer clean build 后运行 | 上述全部公开 API 输出、溢出后内容与精确坐标断言通过，exit 0 | 8192 KiB native 栈，默认 managed 栈；不代替完整资格 |

### 冻结 C3 的已执行验证

C3 的产品摘要为 `a0ca74e163e77bf33a0c48267b2b0dc0f51e81b85178dc7a6eba1a20c0bd34c6`，
生产 harness 为 `0f16fde97703cf34328a37cbbdfa37ceb6d20d636e0a48f3ea8a2de2beefad8e`；
临时测量快照使用同一完整 path/lock overlay，不改变生产宏 pin。

| 检查 | 实际结果 | 证据边界 |
| --- | --- | --- |
| 干净 C3 的 O2 `core` 与 `macro-consumer` | 629/629、84/84，均 0 skipped/errors/failed；真实 integration executable 和暂存后的独立 macro consumer 通过 | STS 1.2.0、九包 0.2.0，不代替最终 17 门禁 |
| C3 的 `check_target_float_rounding.py` 与 `--native` | 各 7869 向量、0 mismatches，exit 0 | O2、8192 KiB native 栈、默认 managed 栈；Native 模式只覆盖 primitives |
| C3 的 `check_skip_work_scaling.py` | 15/15，128/256/512 键分别同量 hash、0 equality，errors=[] | 五条实际 parser 路径，O2、8192 KiB native 栈；不声明恶意 hash 碰撞复杂度 |
| `release_temp_tree.py --enforce-clean` 与 generated risk | 396 文件；changed=36、risk=4；exit 0 | 精确 C3 与正确宏的独立干净导出 |
| C3 正式 Pure release 第一批 | 完整 24 项、11 轮、528 计时与 48 预检；全部 C/B≤1.05、全部单侧 CV≤5%；实际 O2 审计通过 | 服务器；无 CV 噪声重跑条件，HEAD 与七库另行验收 |
| C3 对本轮 BASE 的 Deep Nested 第一批 | String/bytes 两项各 11 轮，44 计时与 4 预检；C/B 分别约 0.997 / 1.002，双方 CV 均小于 1%；独立 gates 与实际 O2 审计通过 | 未传 `--enforce`；检查 gates 和前后源码、宏、SDK 身份，未仅凭 exit 0 判断 |

七库两批已顺序完成，各 770 个唯一单元，全部 RSS 为正、各 110 份 fixed-work 证明通过。
第一批 10/10 稳定，第二批 6/10 稳定、4/10 noisy；原样保留两批，不补单元、不第三批追分。
可信 checkout 独立重算全部 1540 单元、七个源码树、完整生产闭包、SDK 清单和实际生产 execve。
完整 Pure 572 计时及 52 预检也从日志/RSS/sidecar 复算，所有比率仍在原门槛内。
九个公开存档共 18262 个普通文件，完整内容审计的 58 项匹配均逐项绑定 SDK 或匿名 namespace 源证据。
报告与重放入口见[本轮 Pure](../performance/results/2026-11-03-issue-9-contracts-pure.md)、
[七库](../performance/results/2026-11-03-issue-9-contracts-seven-library.md)和
[证据索引](../../benchmarks/results/full-seven-library/2026-11-03-issue-9-contracts/README.md)。
历史诊断公开包保留 1638 个普通文件，全部载荷和非 owner 属性逐成员一致，
仅匿名化 owner/compression metadata；measurementStatus 为 `DIAGNOSTIC_ONLY`。
内容审计的 12 项匹配均为冻结 SDK 中的 unittest mock 库标识，已逐项核验并保留原字节。

C3 的托管 [CI run 41585591000](https://github.com/lIlIIlIll/yjson/actions/runs/41585591000)
已结束：Windows/macOS Pure 与 API 示例、API Documentation、Core Coverage、
全部 Linux Tests、STS、guardrails、generated risk 与 Stream evidence drift 成功。
Seven-library evidence drift 失败，CI Required 汇总失败；PR 上 Pages 部署按条件 skipped。
这是精确 C3 的实际结果，不替代更新性能证据后最终 HEAD 的全部 Required。

### E 的托管 CI 与 Ready 前本地评审

证据提交 `9b7ec549ea15508bbbc0feb8853277a697cd90a1` 的托管
[CI run 41609265583](https://github.com/lIlIIlIll/yjson/actions/runs/41609265583)
已结束：29 个 job 成功，PR Pages 部署按条件 skipped，CI Required 成功。
该结果只适用于 E，不替代后续修复的本地验证与最终 HEAD 托管 CI。

Ready 前必须完成本地 subagent 评审、修复及增量复审，直到没有未解决问题。
首轮三片评审覆盖核心 reader/writer/数值转换、算法及 Native 生命周期、性能证据闭包；
核心片未发现可操作问题，其余两片确认以下三项。PR 仍保持 Draft。

| 评审 ID | 公开可观察问题 | 修复与实际验证 | 当前状态 |
| --- | --- | --- | --- |
| PR10-AN-01 | yyjson 负零 `asInt64()` 与 `close()` 竞争，把 `resource_closed` 映射为 `number_out_of_range` | 外部 STS 1.2.0、`-O2` 使用方在第 0 轮实际复现；数字文本读取移出转换异常捕获。修复后直接运行使用方：2000 轮、14640179 次成功读取、退出 0；`ci_job.sh yyjson-native` 26/26、暂存外部使用方通过 | 源码增量复审 resolved；待最终提交连续性确认 |
| EVID-01 | README 的 `verify-seven.py --trusted .` 因子进程改变工作目录而找不到汇总器 | 参数路径先绝对化；完整两批七库数据以相对 trusted 路径重放成功，仅 verifier hash 变化 | 源码增量复审 resolved；待最终提交连续性确认 |
| EVID-02 | Pure verifier 对空结果目录或缺 HEAD Deep Nested 矩阵错误返回 PASS | 必须包含资格声明中的两个不同矩阵，且实际目录集合完全一致；两种不完整输入修复前均错误通过、修复后均退出 1 且不写 PASS，完整矩阵重放通过 | 源码增量复审 resolved；待最终提交连续性确认 |

上述 Pure 空目录及缺矩阵的修复前 PASS 是合成不完整输入的错误接受证明，不是测量资格结果。
重放程序来自可信检出，不执行归档中的程序；九份原始测量/诊断归档及数值样本未修改。

当前修复不改变 `product_manifest()` 或 `harness_manifest()` 的任何输入；摘要仍分别为
`a0ca74e163e77bf33a0c48267b2b0dc0f51e81b85178dc7a6eba1a20c0bd34c6` 和
`0f16fde97703cf34328a37cbbdfa37ceb6d20d636e0a48f3ea8a2de2beefad8e`。
`packages/benchmarks/cjpm.toml` 仅依赖 yjson、宏和 algorithms，不依赖独立 yyjson 包。
因此 C3 的 Pure/七库测量闭包可复用；原始完整 repo 快照摘要仍指 C3，不冒称最终仓库整树相同。
yyjson 生命周期行为则必须以上述新运行及最终 HEAD 门禁验收，不复用旧后端结果。

## 历史记录：2026-10-02 / STS 1.1.3

以下只适用于原 PR 及其当时环境，不证明当前候选通过。

## 基线与环境

- 创建分支及提交前核对的最新 main：`0f2071a0ad59ad43a369abe51abaceaf873f0c63`。
- 独立分支：`fix/issue-9-json-correctness`。
- 宏子模块保持 `0847b59e0c8c47b7c5b52b550ef8765c0cbddb03`。
- Linux x86_64，官方 Cangjie STS 1.1.3；`cjc`、`cjpm` 均报告 1.1.3。
- SDK 归档 SHA-256：`2b68905afc466e665ae181595c63f96c18d75fd2c1fb6c6f0cb64e179c28d61a`。
- Native：Clang 15.0.7、GCC；libidn2 2.3.7。本容器需要仅映射自身及直接子进程 `/proc` 路径的兼容层才能启动 cjpm。
- 专项 `-O2` 编译与运行使用 Linux 8192 KiB 栈，仓颉运行时环境使用 SDK 默认配置。仓库 CI gate 继续使用其原有 128 MiB 编译栈。
- 默认资源预算、Reject 重复键策略、测试、CI 配置和性能基线均保持原值。

## 逐项证据

各项先加入回归、保存实际失败，再修改实现。可能不终止的旧实现使用独立进程和外部超时，终止整个进程组。

| 项目 | 修复前实际证据 | 实现与回归 | 修复后 |
| --- | --- | --- | --- |
| 001 | 两个 reader 对 128/256/512 个唯一键分别执行 8128/32640/130816 次名称比较；线性工作量断言失败 | `lib_json_direct_reader.cj`、`lib_json_fast_reader.cj`：每个对象独立的解码名称 HashSet；`json_issue9_skip_test.cj`、外部 unknown-skip 测试 | 对应 128/256/512 次集合插入；Reject/LastWins、转义等价重复键、父子同名键通过 |
| 002 | 手写与 generated consumer 的合法逗号后空白输入报 Unexpected token；raw bounded 路径也独立复现 | 三条对象 skip 路径消费逗号后的 JSON 空白；空格/TAB/CR/LF、嵌套未知字段、String/bytes、逐字节及所有分块位置测试 | 核心 6 项、外部 2 项通过；尾随逗号和非 JSON 空白继续拒绝 |
| 003 | 预算 8 的展开视图仍读取 131070 个子节点；Patch、Merge target/patch 循环分别在 5 秒超时后终止 | `yjson_algorithms/src/lib_json_patch.cj`：显式祖先栈，获取子节点前计费，复制前验证；Merge 两个输入均先验证，使用已复制 patch 子树 | 小预算只读 7/6 个子节点且未 materialize；循环 `cyclic_json_node`，深度超限 `max_depth`，预算 `work_limit_exceeded`；256/257 深度、DAG 每次出现计费、输入不变均通过 |
| 004 | 零容量 writer 8 秒超时；容量加法/乘法超限泄漏 OverflowException | `lib_json_direct_writer.cj`：零规范化为 1，负数 IllegalArgumentException；增长及所有容量预留使用受检算术，超限 `output_too_large` | 零、1、默认、扩容边界、Int64 边界及失败后内容保持通过 |
| 005 | 缺失路径 move 到自身未抛异常，回归失败 | `jsonPatchMove()` 在同路径返回前 evaluate 源；对象/数组/根/转义 Pointer 回归 | 缺源、越界、数组 `-` 返回 `json_patch_path`；存在路径保持原值，失败不修改输入 |
| 006 | 8 MiB bytes、maxInputBytes=64 的拒绝路径分配 8393968 字节，GC=0 | `CompactJsonDocument.parseOwned()` 分配前检查长度；limit-1/limit/limit+1、分配量和修改原 bytes 后文档不变测试 | 同 SDK、`-O2` 拒绝路径分配 1080 字节，GC=0；拥有式复制保留 |
| 007 | SDK 与 yjson 将 `1.0000000596046448` 舍入到 Float32 `0x3f800000`，而目标最近偶数舍入应为 `0x3f800001`；Float16 中点及溢出边界也失败；完整 Native/yyjson 各有 24 个负零位断言失败 | `lib_json_target_float.cj` 与 builtin/generated 桥：原文对精确目标中点比较，Float64 前缀仅作候选；backend tape 数字先验证语法；`native/yjson_compact.c`、`native/yjson_yyjson.c` 保留 `-0` 原文，view 与物化节点的整数访问器维持 0 | 核心 6 项、generated 41 项、Native primitives 3 项通过；生产 YJson Pure/Native primitives 各 7869 个有理数 oracle 向量零不匹配；完整 Native/yyjson consumer（含 Pure 对照）各 1216 个位断言零失败，持久回归包含 root/inline view、materialize 与逐字节 stream |
| 008 | 换行后 `"ab"`、maxStringBytes=1 的流错误报告第一行；两个位置回归失败 | 资源错误通过 InputCursor 定位；未消费窗口也扫描换行；未知坐标返回 None；覆盖 CRLF、UTF-8 byte column、每种分块与资源错误 | 资源专项最终 21/21、与 skip 合计 27/27 通过；示例为 byteOffset=3、line=2、column=3 |

001 的初始计数只在临时诊断副本中加入，产品没有计数器。持久回归脚本 `scripts/check_skip_work_scaling.py` 在临时副本中用同一包装键委托实际 String hash/equality，运行真实 parser 与 Array/HashSet 控制流；五种输入路径的旧版 equality 为 8128/32640/130816，新版 hash 为 128/256/512、equality 为 0。未知源码形状会失败，不声称验证了恶意哈希碰撞行为。007 的 oracle 使用 Python Fraction 独立计算 IEEE-754 最近偶数舍入，不以 SDK 的浮点 parser 作预期值。

007 追加验收真实发现 Native/yyjson 把负零整数压缩为 INT 0。先运行 C kind/text/tape 和仓颉位断言得到失败，再排除这一字面量的整数折叠；序列化现在保留 `-0`，普通整数仍使用原表示。旧 yyjson C 断言中的 `-0`→`0` 及混合数字统计按该语义修正，性能基线未修改。SDK 的 UInt64 文本 parser 拒绝 `-0`，因此另补先失败的 view 及 materialize 兼容性回归，维持 `asInt64()`/`asUInt64()` 为 0；`lib_json_value.cj` 只对精确 `-0` 返回 UInt64 0，其他负数、非法语法与 typed UInt64 的拒绝保持原有行为。

## 实际 gate 结果

consumer 与 standards 的 `YJSON_CI_DEPENDENCY_OVERRIDE=-O1` 与当前工作流的既有配置一致；专项默认栈 `-O2` 结果单独列出。

| 命令/检查 | 实际结果 |
| --- | --- |
| 临时源码副本仅把根 compile-option 改为 `-O0`，`cjpm test --no-color --no-progress` | 604/604 PASS，0 skipped/errors；补充验证，不能替代正式 core gate |
| `scripts/ci_job.sh core`，原始 `-O2` | FAIL，LLVM opt OOM，测试尚未执行；cgroup 峰值 8590163968 字节，oom_kill 4→5 |
| 未修改 main 上原样 `cjpm test --no-color` | 相同 LLVM opt OOM，oom_kill 3→4，证明完整 `-O2` 构建在本容器的 8 GiB 限制下存在基线阻塞 |
| 专项 `-O2`、8192 KiB 栈 | 最终 writer/document 13 项、reader/location 27 项、float 6 项，算法 60 项 PASS；临时工作量测试另通过 |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh macro-consumer` | 41/41、可执行程序及暂存包独立 macro consumer PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh algorithms-consumer` | 60/60、暂存 algorithms/schema-formats consumer PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 YJSON_STANDARDS_OFFLINE=1 scripts/ci_job.sh standards-conformance` | oracle 测试 PASS；Schema 1299、JSONPath 703、Patch 108，共 2110/2110 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 YJSON_STANDARDS_OFFLINE=1 scripts/ci_job.sh schema-formats-conformance` | 格式包 2/2；含可选语料的 Schema 2263、JSONPath 703、Patch 108，共 3074/3074 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh custom-native` | 最终 primitives 3/3、accel 13/13、native 17/17、暂存 Native consumer 和导出符号检查 PASS；零跳过，峰值 3.45 GB，未新增 OOM |
| `scripts/ci_job.sh runtime-freeze` | 原优化配置，10 个独立进程场景 PASS |
| `python3 scripts/check_target_float_rounding.py` / 加 `--native` | 生产 Pure/Native primitives 各 7869 向量，0 mismatches；`-O2`、8192 KiB 栈 |
| 完整 Native/yyjson 浮点 consumer 与持久包测试 | consumer 各 1216 位断言、0 failures、真实 executable exit 0，运行栈另核对 8192 KiB；Native 17/17、yyjson 20/20 PASS，构建使用其既有 `-O1` 配置 |
| `scripts/ci_job.sh native-clang` / `native-gcc` | PASS，C `-O2` 与警告检查 |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh yyjson-native` | 最终 20/20 与暂存 yyjson consumer PASS；零跳过，峰值 2.43 GB，未新增 OOM |
| `scripts/ci_job.sh yyjson-colink` | PASS，四种链接组合；固定 0.11.1 tag 对应 commit 的源码及 Git blob SHA 核验 |
| `scripts/ci_job.sh sanitizer` / `fuzz-short` | FAIL，Clang/GCC 的 LSan 因容器 PID namespace 与 `/proc` 不一致报 fatal；fuzz 保留 5000 个案例配置和 detect_leaks=1，没有禁用 LSan |
| `scripts/ci_job.sh cjdoc-qualification` | 6 项资格回归、固定源码构建及真实二进制资格检查 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh examples` | generated codec、AST 与 builtin codec 示例全部运行 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh registry-rehearsal` | FAIL；完整核心测试构建在 LLVM opt `-O1` 阶段 OOM，峰值 8589852672 字节，oom_kill 5→6，测试尚未执行 |
| 独立 `release_registry_rehearsal.py`，原有 bundle/consumer `-O1` 参数 | 最终补充 PASS：346 文件的 clean 候选、九模块确定性打包/复刻与全部六类外部消费者；191.07 秒，峰值 2525470720 字节，未新增 OOM。包括最终 Native、materialize 与清单修复，不替代上述完整 gate |
| `python3 scripts/check_skip_work_scaling.py`，再加 `--source-ref 0f2071a0ad59ad43a369abe51abaceaf873f0c63` | 真实 `-O2`、8192 KiB 栈：当前 PASS，旧 main FAIL；五种路径与三个规模均动态计数，策略回归通过 |
| `scripts/ci_job.sh perf-evidence-drift strict` | 40 个校验器测试 PASS；freshness FAIL，当前源码与冻结测量身份不同 |
| `TAR_OPTIONS=--no-same-owner scripts/ci_job.sh stream-docs` | PASS；该环境参数只处理容器无法恢复归档 uid/gid 的限制，内容与数值证据仍全部核对 |
| API inventory、source-stage、release-temp 单元检查 | PASS；1094 个公开声明，9 包，新增文件已纳入发布清单 |
| CI guardrails | 性能策略 20 项、consumer 策略 2 项、STS 4 项 PASS；健康 sanitizer 探针与 3 个真实 `/proc` 子进程发现用例受上述环境问题阻塞 |
| `scripts/coverage.sh` + `scripts/check_patch_coverage.py` | PASS；原覆盖流程下核心 613/613、runtime 10 个场景、Native accel 13/13；项目行 9029/10506=85.9%、分支 4001/5432=73.7%；改动行 265/265=100%、分支 181/204=88.7%，原阈值全部满足 |

## 复现精度检查

在准备好的 STS 1.1.3 环境与普通 8192 KiB 栈下执行：

```sh
python3 scripts/check_target_float_rounding.py
python3 scripts/check_target_float_rounding.py --native
python3 scripts/check_skip_work_scaling.py
```

脚本构建临时外部使用方，调用生产 `YJson`，覆盖正负中点两侧、偶数/奇数 tie、所有目标 exponent field、次正规数、溢出边界、负零、随机十进制与长指数抵消；不会修改仓库清单。

## 未完成的验收

- 正式完整 `-O2` core 及完整 registry-rehearsal gate 的可用运行结果，LSan/guardrails 的正常进程环境结果，以及托管平台与完整 CI Required 结果。
- 新源码的真实七库性能测量与性能 freshness 验收。原 runner 的实际准备检查失败：缺完整 peer 工作区、CPU 筛选输入、GNU time、JDK/Maven 及 STS 1.1.3 stdx；尚未完成 correctness preflight 或测量。既有测量、阈值和基线保持冻结，不能把原源码的结果绑定到本次修复。
- 不自动合并；issue 在验收完成前保持打开。
