# 0.2.0 文档与工具链实施记录

本记录对应已确认的 cjdoc 文档实施方案。状态只依据实际实现、产品接入和验证结果更新。
候选版本为 yjson 九包 `0.2.0`，统一使用 Cangjie STS `1.2.0`。

## 已确认的边界

- 整个 `0.x` 不保证跨版本源码、二进制、生成代码或旧 SDK 兼容。
- 破坏性变更仍须单独确认；本次已批准删除 `@JsonValue`，调用迁至 `@Json`。
- 当前协议和 ABI 校验、资源生命周期、预算和错误语义继续保留。
- 中文注释覆盖八个应用包；九包统一生成站点，内部接口单独分类。
- 每个可调用入口或语义相同的重载组具有独立可执行示例。
- 交付 HTML、Markdown、Doc IR、质量报告和完整 Agent 离线文档包，不提供旧链接或旧格式兼容层。
- cjdoc 以 `0.7.4` 为基线增加源码级宏文档支持。原 `0.7.5` 发行失败后保留 tag，修复以 `0.7.6` 新身份推进。
- 本次包含 cjdoc 发布和 yjson Pages 上线，不发布 yjson 九包或创建其 tag。
- Pure 基线在 STS `1.2.0` 迁移完成、历史适配清理前冻结；本次不证明跨 SDK 性能变化。

## 需求与验收

| ID | 来源条款 | 类别 | 可观察结果 | 实现与入口 | 验证方法及实际结果 | 适用版本 | 状态 | 剩余缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SDK | 统一 STS 1.2.0 | 必需 | 全部产品门禁使用真实 STS 1.2.0 与匹配 stdx | CI、SDK 解析器、开发和发布清单 | 官方 SDK、匹配 stdx、动态与静态环境及实际版本检查通过；5576cdd 核心 O2 587/587、标准语料 3074/3074 通过；主仓托管矩阵待运行 | 0.2.0 候选 | 部分实现 | 最终平台证据 |
| POLICY | 撤销旧兼容保证 | 必需 | 当前政策不再承诺跨版本兼容，历史事实仍可查 | 活跃文档、源码注释、机器清单 | 当前政策与清单已同步；真实九包清单、37 个清单回归及 8 个快照回归通过；最终文本扫描核对了历史记录和当前同版本 SPI fallback，未发现跨版本保证；用户无关文档保留 | 0.2.0 候选 | 部分实现 | 最终托管检查 |
| CLEANUP | 已批准的适配清理 | 必需 | 四个公开宏；内部包装删除且原行为仍通过 | 宏仓、核心、外部消费方 | 宏 PR #9 已合并，实际 Git pin 下核心 O2 583/583；宏消费方 11/11、四宏示例、旧宏拒绝和同名自定义类型通过；无参 struct 缺陷已修复并补回归 | 0.2.0 候选 | 部分实现 | 最终候选托管验收 |
| CJDOC | 源码级宏支持 | 必需 | 宏签名及被包装声明具有真实注释和导航 | cjdoc AST、绑定、缓存及输出 | PR #164、#166 已合并；精确 main 的首次三平台 CI、展示站及 v0.7.6 Release attempt 2 通过；12 项公开资产独立核验通过；两个独立空缓存源码构建、106 项文档链回归及第一份真实九包生成和全文 query/MCP 通过，工具配置已冻结；首次失败和未复现诊断均保留 | PR HEAD 8cd4ccb；main/tag 653457d；tree 06f7d27 | 验收通过 | 工具源码、构建策略或 SDK 变化时重新资格验证 |
| COMMENTS | 应用注释补全 | 必需 | 全部范围内声明具有实际绑定的中文契约 | 八个应用包 | 正式资格 cjdoc 0.7.6 的真实九包 standard lint 与生成通过：459 条应用摘要、383 个参数、210 个适用返回值均为 100%，应用质量 finding 为零 | 输入摘要 044ed6bd；验证 e915182，与 afd4e0b 同树 | 验收通过 | 注释、工具或解析输入变化须重验 |
| EXAMPLES | 逐入口示例 | 必需 | 每个入口或重载组可独立编译运行并断言结果 | 注释示例、隔离消费方 | 正式资格工具批 Linux 333/333 真实编译运行通过，零重试；144 冻结文件、333 份源码和清单通过最终 ZIP 字节绑定；另在断网环境为 11 个 profile 各建立全新消费方并编译运行通过；历史开发批和两个额外 SPI 示例分别保留 | 输入摘要 044ed6bd；验证 e915182 | 部分实现 | Windows/macOS 各 285 条适用示例 |
| SITE | 统一 workspace | 必需 | 九包共用搜索、指南、交叉链接和 Agent 索引 | 发布图派生的文档 workspace | 开发工具九包 workspace 已生成 Doc IR v16、HTML、Markdown、质量报告及 Agent-full；未替代正式工具资格 | 0.2.0 候选 | 部分实现 | 正式工具冻结、最终源码生成与全站检查 |
| AGENT | 离线 Agent 包 | 必需 | 下载后离线 query 与 stdio MCP 可查询真实文档 | 完整生成站点 | 默认堆完整读取失败保留；同源 O2 加关闭 CHIR 内联、2 GB 堆与 Linux 131072 KiB stack 下，17 页源码指南逐 query 和同次 stdio MCP 全文通过 | cjdoc 0.7.5 开发产物 | 部分实现 | 正式资格、最终全量示例和下载产物离线验收 |
| PERFORMANCE | 正式重新测量 | 必需 | 同 SDK Pure 24 用例及七库两批完整证据通过 strict | 冻结测量源码与正式运行器 | 旧 Pure 失败批保留；5576cdd 新 Pure 24 项通过 5% 门槛；七库两批 1540 单元、220 份固定工作量证明及 799 份公开源码记录独立复核通过；干净检出 7d48eb2 的完整 strict 及 40 项回归通过，主 agent 独立重放 checker | 测量 5576cdd；整合 7d48eb2/C9 | 验收通过 | 后续性能输入变化须重新验收 |
| PLATFORMS | 平台与真实边界 | 必需 | Linux 全部适用示例、Windows/macOS Pure 通过 | CI、Native 链接和外部消费方 | 待最终代码托管矩阵 | 最终冻结候选 | 未实现 | 全部托管证据 |
| DELIVERY | PR 与 Pages | 必需 | 上游发布、宏合并和最终 main 站点可核对 | 各独立仓库与 Pages | 宏 PR #9、cjdoc PR #164/#166 已合并并核对源码树；cjdoc main CI、展示站和 v0.7.6 正式发布通过，12 项下载资产已核验；v0.7.5 失败 tag 保留；yjson 主仓 PR 与 Pages 未完成 | 最终提交 | 部分实现 | 主仓库 PR、托管矩阵与线上验收 |

## 验证规则

每项结果记录实际命令、源码或产物身份、SDK、退出码、日志与未运行范围。
本地编译、消费方运行、托管 CI、性能资格和线上部署分别验收，不能相互替代。
历史发布记录及测量失败保持原样；新候选不得复用旧 SDK 的通过结论。

## 开发验证记录

以下按发生顺序保留各次结果及当时缺口；当前验收状态以上方矩阵为准。

- STS `1.2.0`、匹配 stdx `1.2.0.1`：官方归档校验、实际 `cjc` / `cjpm` 版本、
  动态和静态 stdx 探针通过。未构建编译器或 SDK。
- 清理前核心：`cjpm test --no-color`，STS `1.2.0`，583/583 通过，零跳过，退出码 0。
  基线产品源码已保存独立摘要；该运行尚不证明清理后的最终候选。
- cjdoc AST：宏参数、返回类型、嵌套宏包装的原始声明、token 位置的最小编译运行探针通过。
  不将此结果当作完整工具回归或正式发布资格。
- 性能身份校验：新增回归先出现 8 个失败；删除历史 pin/版本归一化并将身份实现本身纳入
  harness 后，`python3 scripts/test_json_pure_perf_compare.py` 19/19 通过，
  `python3 scripts/test_check_seven_library_evidence.py` 40/40 通过。
  尚未完成新候选的正式性能测量，旧证据不对应新 harness。
- 依实际编译、链接和 Python import 补齐测量身份闭包：浮点 formatter、yyjson C/H、
  同时编入 bench 的 algorithms 源码与清单，以及七库汇总器。新增输入的逐项变异先失败，
  修复后 Pure 身份回归 19/19、七库严格证据回归 40/40。未改变用例、阈值或历史样本。
  真实生产候选为 `0e1753ccae19c815670b97b63a998d84ede64595`；Pure 双快照显式使用
  相同 path 依赖 overlay，生产七库候选保留实际 Git pin 与 lock，不混用两种身份。

- STS `1.2.0` / `-O2` 复验：核心视图 131 个独立例子、算法与后端 74 个独立例子通过；
  algorithms 56/56、schema-formats 2/2、native-primitives 2/2、native 16/16。
  backends 编译成功但包含零个包内测试，不将其记为测试用例通过。
- cjdoc 同源全依赖 `-O2` clean build 通过；宏、离线查询和完整工具回归仍独立验收。
- 宏生成器的三个可变 struct 结果绑定已由 `let` 改为 `var`，四个回归模型覆盖不同读取路径。
  修复前保留 18 个编译错误；修复后 runtime 583/583、消费方 11/11、四宏示例通过。
  宏 [PR #9](https://github.com/lIlIIlIll/yjson_macros/pull/9) 已合并，生产依赖固定
  `c9ef52da9ba2d3f77916c40ccb9280db78ee2e07`，主仓库实际 Git pin 下核心 O2 583/583。
  宏仓未配置托管 checks，不将本地结果描述为托管 CI 通过。
- 审阅后的核心 codec 87 个外部消费方示例全部通过；Native 三包 O2 测试分别为
  16/16、13/13、19/19，同份开发 Doc IR 中 39 个 Native 示例真实链接并运行通过。
- API 快照从真实源码生成 1111 条声明。增量只包含获批的 `@JsonValue` 删除和 18 条
  基线源码中早已存在、旧收集器漏记的枚举项；历史补录证明保留源码与收集器摘要。
  `python3 scripts/check_api_inventory.py`、`python3 scripts/test_stage_source_tree.py`、
  `python3 scripts/test_release_temp_tree.py` 通过。全局发布迁移审查仍为 pending。
- 主 agent 在实际 C9 Git 依赖和 STS `1.2.0` 下执行 `scripts/ci_job.sh core`，
  O2 核心 583/583 通过；显式 `YJSON_CI_DEPENDENCY_OVERRIDE=-O2` 的 `examples`、
  `macro-consumer`、`algorithms-consumer` 和 `runtime-freeze` 四个 gate 全部退出 0。
  算法 56/56、宏和算法外部使用方、schema-formats 外部使用方及真实初始化失败恢复均通过。
- 主 agent 复验 API 清单、源码暂存、发布暂存、STS、CI 候选接线及工具资格校验的六项
  Python 检查，全部退出 0。CI 接线回归有 1 项 SDK oracle 按其约定留给 standards gate；
  qualification 单测通过不表示尚未发布的 cjdoc 候选已经取得资格。
- cjdoc 同源产品 O1/O2 clean build 均通过，O2 宏与小型离线 fixture 18/18 通过。
  完整 unit 的 O2 编译出现 ICE 13，尚未执行测试；仅 unit 阶段采用有实测依据的 O1，
  产品优化策略单独验收，不在失败后自动降级。
- cjdoc 同源 O1 unit 678/678 通过，零跳过、零错误；后续 decoder 修改仍须重验。
- 完整离线包的同源普通 O2 query 和 MCP 均 SIGSEGV，O1 对照通过。
  临时改 GC 参数或仅 decoder 缩减通过均未作为修复证据，未验收的提取未提交。
- 同一份 cjdoc 源码的 `-O2 --fno-chir-function-inlining` 产品构建通过，19 条实际 cjc
  调用均包含完整参数。严格 query/MCP 回归 3/3、宏与 fixture 18/18、资源边界 41/41、
  九份 golden 冷暖生成与 roundtrip、两组共 22 页 HTML 通过。
  同参数的完整 unit 编译仍出现四处 ICE 13，零用例运行。
  主 agent 以默认 heap、131072 KiB stack 独立读取完整开发包，query 和 MCP 均退出 0、
  状态为 ok 且各返回两个实际文档匹配；4,189 个 HTML 文件和二进制前后未变。
  产品选择完整 O2 加关闭内联参数，unit 采用明确 O1 例外；正式构建与发行仍须验收。
  不将这些结果写成普通 O2 通过，也不据此声称关闭内联没有性能影响。
- cjdoc 的真实 CHIR worker 在独立空 target 下构建通过；最小文件协议探针实际执行
  `cjc --emit-chir=raw` 和 `stdx.chir.deserializePackage`，真实 fixture 收集通过。
  该结果尚不替代启用 worker 的完整测试。未构建编译器或 SDK。
- 文档工具准备脚本已删除隐藏的 O1 改写，改为调用固定上游的静态 stdx 和 STS wrapper。
  资格 schema 4 与构建证据 v2 核对实际参数、成功构建记录、二进制、SDK executable 和
  静态 stdx 摘要。两项证据篡改回归修复前失败；资格与准备脚本 22/22 通过。
  真实继承 wrapper 的环境探针先发现 PATH 隔离缺口，修复后官方 cjc/cjpm 摘要和版本匹配，
  旧 wrapper 路径、标记及动态 stdx 选择已从构建环境移除。
  配置仍为 candidate，正式上游版本发布前不能通过生产资格检查。
- `YJSON_TEST_STANDARDS_ORACLE=1` 的真实 SDK oracle 通过：正常正例、正常负例和
  malformed schema 异常分别计数，异常不能冒充负例通过。
  `run_standards_conformance.py --include-schema-optional --override-compile-option=-O2`
  使用固定提交与 SHA-256 校验语料，JSON Schema 2263、JSONPath 703、JSON Patch 108，
  共 3074/3074 通过；清单中的临时优化覆盖在结束后恢复。
- 发布暂存清单遗漏了宏与 Native 示例所需的五个 profile/prelude 文件。
  从实际注释契约派生的收录检查先失败，补齐后通过；不以工作区中的文件存在代替暂存产物完整。
- Server 的 Pure 构建审计核对了八次实际计时程序编译，均为显式 `-O2`，不含禁用内联参数。
  七库构建审计发现 json4cj 的三个依赖包没有设置优化参数，26 次实际库编译使用默认 O0。
  已在正式采样前停止，保留原始清单和编译记录；仅给这三个包增加显式 O2，冻结适配摘要后
  重新 clean 构建并审计。未将原始依赖或尚未运行的正式样本记为 O2 通过。
- cjdoc 最终构建策略在干净源码下生成了产品和真实 worker；首次完整测试在默认堆上出现
  677 通过、1 个超过 32 MiB 文档编码的 OOM。正式 CI 已固定 512 MiB 堆，后续按该实际
  条件单独重验 native 测试并继续尚未执行的阶段；默认堆失败证据保留，未降低断言。
- cjdoc 在正式 512 MiB 堆下完成 678/678 单测、Python 工具、CLI、provider、真实浏览器
  和真实仓库 smoke。smoke 收集 4933 条声明、3468 个产物，两次生成逐文件一致。
  这些完整检查适用于 `b56455f`；随后仅更新性能基线的两项实际 Doc IR 摘要，未修改时间、
  RSS 或采样门槛。`40d45cdf` 的规范构建重新执行通过，产品和 worker 二进制逐字节不变；
  最终 identities 与固定 CPU、512 MiB 堆下的原性能硬上限检查通过；
  该结果不证明普通 O2、跨环境性能回归或内联开关影响比例。
  上游 [PR #164](https://github.com/lIlIIlIll/cjdoc/pull/164) 已创建，当时 HEAD 为
  `40d45cdf3808acfb15bcd0d056a1a66d0caa8908`；后续 HEAD 和托管结果见下文。
- 首次正式 Pure 两侧均为实际 `-O2`，不含禁用 CHIR 内联选项；预检、528 个计时样本和
  24 个用例全部完成。`yjsonStringDecodeLargeInt64Map` 的基线与候选约为 14.114 和
  14.917 微秒，CV 分别约 0.56% 和 0.53%，候选 0/11 获胜，回退约 5.7%。
  其他 23 项未超过 5%；本批没有达到 noisy 重跑条件，门禁退出 1，保留全部失败证据。
  七库两批均未开始。回退原因尚未定位，不能仅据源码清理或编译旗标猜测原因。
- 开发 Doc IR 全量诊断保留了 19 个真实编译失败：消费方 prelude 中的 struct 宏展开生成
  `let __result` 后再赋值，触发不可变值错误。原运行未记录实际加载的宏二进制摘要，
  不能据此指定其来源提交；当前 C9 源码与 fresh 消费方通过是独立对照。
  后续 runner 冻结仅含源码的依赖副本，逐例落盘并记录 profile、prelude、SDK 与实际依赖产物摘要。
- `5576cddb1e42a3b391385038ab5b2e3f6d76a77c` 删除资源预检中两处重复的前置空白扫描。
  调用方已消耗空白；分隔符后的扫描保留。四个独立回归覆盖三入口、四类 JSON 空白、
  非法输入的精确位置，以及语法、UTF-8 和预算错误先于重复键的顺序。
  新增测试在旧实现 4/4 通过；最终实现以真实 C9 依赖、STS `1.2.0` 和实际 O2 重新执行
  核心 587/587、标准语料 3074/3074 及宏外部消费方 gate，均退出 0。
  单项交替诊断表明改动值得完整复测，但不替代正式 Pure 和七库资格，也不证明旧回退的根因。
- cjdoc 的三份测试修复已获授权并入原提交，安全更新至
  `f8e5b8f0ac95ef5187b6c84d716dc9f3693fcdd1`。本地临时路径及失效 shell 反例先失败，
  修复后相关 26/26 通过；离线客户端追踪没有网络调用或外部编译器执行。
  产品源码、构建参数及二进制未变。当前 HEAD 的官方 code review 已完成且无发现，
  security review 仍仅适用于旧 HEAD。
- [该 HEAD 的托管 CI](https://github.com/lIlIIlIll/cjdoc/actions/runs/40323987609)
  未通过：Windows 在 native 测试前的 `llc.exe` O2 代码生成中以 `0xC0000005` 退出；
  Linux 678/678 与真实仓库 smoke 通过，随后 `perf_gate.py identities` 生成 self 文档时
  在 512 MiB 堆下收到 GC 线程 SIGSEGV；macOS 665/665 通过，随后严格无效快照测试的
  实际退出码 2 与期望 3 不同。各失败日志保留，尚不确定 Linux 与 Windows 的根因。
  不通过自动重试、降级 O1、降低断言或修改性能门槛放行。
- 完整源码指南保留 1035 条可见声明和原有使用指南。单页按完整声明切分至 32 KiB，
  17 页的 HTML、Markdown 和 Agent 内容全部核对。完整 standard lint 原生报告单独保留；
  两次输出的 3870 条声明除可选高亮字段外完全一致，应用 459 条声明的契约检查通过。
  内部接口的质量缺口仍完整展示，不将全站质量称为 100%。
- 上述完整开发 Agent 包在默认堆下出现 OOM 和 GC 线程崩溃，失败证据保留。
  同源 O1 单次对照读取旧大页通过，不作为根因结论或产品策略降级。
  固定最终 O2 加关闭内联二进制、同一完整包和 stack，仅将堆设为 2 GB 后，
  17 页分别经 query 读取全文，并在同一次 stdio MCP 中读取全文，全部通过。
  正式生成器的实际 reader 路径也独立通过，记录资源条件、请求、完整响应、二进制及全部
  HTML 输入摘要；包内命令已同步。该结果不证明默认堆通过或正式下载产物已验收。
- 文档工具缓存已从源码候选目录移至独立临时 modules 目录，严格源码清单规则保持不变。
  实际 shell 的候选污染反例由失败转为通过，CI 接线 19 项通过、1 项按约定留给 SDK oracle。
- cjdoc `b90f872b755f450fabe1fac5efdd3a344e400b97` 只补入严格无效快照测试中的一行
  临时目录 canonicalization。相同逻辑 symlink 临时父目录下，原始三项 GC/错误状态测试
  全部通过，产品仍拒绝直接使用链接路径。该行并入原提交后安全更新了 PR，未夹带诊断
  workflow 或产品修改；新 HEAD 的官方代码与安全审查均已完成且无发现，托管矩阵仍待验收。
- 新 Pure 候选为 `003dd5b4918ff63618749a5a589f263e74807e38`，对应生产 `5576cdd`。
  主 agent 核验原始归档 2939 个文件及 576 个预检和计时记录，独立复算每个中位数、
  样本 CV、工作量、预热和角色绑核；全部 24 项比率不超过 1.05，最大为
  `1.013942317686197`，最大 CV 约 4.02%。原失败的字符串 Int64 Map 解码比率为
  `1.0023357830205017`。两侧源码构建前后均未变，共享 SDK 与 harness；归档二进制
  逐个匹配各自实测产物的摘要。
  原始归档 SHA-256 为 `d7d9be698641f7634c9cc34c236c1ed74c34606568367188f79e280da786d9d2`。
  这次通过只适用于新候选的 Pure 测量，不替代尚未完成的两批七库和最终 strict 检查。
- 最终离线打包前新增 Agent 收据重验：核对全部 HTML 精确文件集和摘要、真实命令、
  snapshot、资源条件、每页 query 与 MCP 的完整正文。缺失、截断、错页、失败退出、
  资源错配和改包反例均拒绝；不通过重跑 reader 覆盖旧失败。文档流水线 84 项、
  STS 接线 6 项及 CI 接线 19 项通过，后者另有 1 项既定 SDK oracle 未在该套检查运行。
  当前完整 333 条开发示例另行执行中，不计为最终正式工具资格。
- 七库首批调用在首个正确性预检中因缺少 `YJSON_CROSSLANG_CORPUS_DIR` 退出，
  未生成任何正式计时样本。四个仓颉测量程序和 Maven 的本批重建、实际 O2 参数、源码、
  SDK 与锁文件审计均保留。原始归档 SHA-256 为
  `d17419d9ad841f45594a9e0d577d111c479c94854aa43ffdaa17ee1b6684b5f1`。
  后续只补齐既有冻结语料的目录环境，使用新结果目录；不修改 harness、工作量或阈值，
  不将这次预检失败记为有效测量批次。
- 本地开发 cjdoc 使用官方 stdx `1.2.0.1` 归档中的 `static-static-link-extern`，
  托管 cjv 使用同归档的 `static`。两侧版本一致，125 个文件中有 10 个静态库不同；
  这项差异尚不能解释 GC 崩溃。最终工具资格将固定与 CI 相同的普通 static 摘要
  `e62289d5b88af440de04a26a30c79403d024f6accfacfd96607ae409ad9c1df2`。
  已在独立任务目录准备并核验全部 125 个文件，尚未冷构建或授予资格；现有 SDK、
  开发二进制、333 条开发示例和性能证据保持原身份。
- cjdoc `b90f872` 的新托管运行中，macOS 全部 665 个 native 测试、Windows 全部
  659 个 native 测试，以及两平台后续验收和真实高亮 worker 均通过。原始完整日志已保留。
  Windows 与旧失败批使用相同工具链 fingerprint；这次通过不能解释或消除原 LLVM 崩溃。
  Linux 的剩余验收及性能 Doc IR 身份检查已通过，当前仍待最后的可选 worker 任务结束，
  不提前记为整条 CI 通过。
- 随后 cjdoc `b90f872` 的[全部必需 CI](https://github.com/lIlIIlIll/cjdoc/actions/runs/40337513223)
  和[示范站点验收](https://github.com/lIlIIlIll/cjdoc/actions/runs/40337513340)均通过。
  可选 Reader 比较仍为 `invalid-evidence`：主 agent 从归档逐字段核对两份原生 Doc IR，
  仅 `generator.version` 从 `0.7.3` 变为 `0.7.5`；未改变比较规则或将它计为性能通过。
  [PR #164](https://github.com/lIlIIlIll/cjdoc/pull/164)按 main 线性历史规则 rebase 合并，
  main 提交为 `a1852d68ae3ac06dc50f6273eeade8099dee223b`，源码树
  `f36e8f7ba9af91b7dbe2216c3a3963ce262ad6fd` 与经过验收的 PR HEAD 完全一致。
  main 门禁和 `0.7.5` 正式发布仍需单独验证。
- 该 main 提交的 [CI 首次运行](https://github.com/lIlIIlIll/cjdoc/actions/runs/40346738785)
  在官方 stdx 下载阶段因 TCP 443 连接超时失败，Linux 产品构建未启动。
  同提交的展示站任务随后命中完整工具链缓存并完成候选构建；这不证明冷下载恢复，
  也不替代尚未通过的主线必需门禁。首个失败日志和两任务缓存差异已独立核验并保留。
  原次运行的 Windows 659/659、macOS 665/665 native 测试及后续验收均通过；
  主 agent 核验了完整日志、两平台真实高亮 worker 的九步结果和各 89 个 renderer 源码摘要。
  Native 测试均零跳过；Python 工具测试的平台条件跳过另行保留。
  确认精确工具链缓存可用后，已从失败的 Linux 准备 job 执行环境恢复，原失败不覆盖；
  未修改产品源码、编译参数或断言，恢复结果仍待独立验收。
- 首批有效七库测量保留全部 `70 × 11 = 770` 个单元。主 agent 逐字节核验归档
  3012 个文件，使用 `5576cdd` 的真实校验器检查用例绑定、RSS、110 份 yjson
  固定工作量记录，并从原始记录重生成 JSON、CSV 和 Markdown 汇总，均通过。
  原始归档 SHA-256 为 `2d65b6e7ed0dd1692a72d2cf30934f6b1362bf3accd7cb369555898db8502ca5`。
  测量完成后，任务层收据格式化器出现一次索引错误；仅修复收据格式化器并只读复算，
  未修改原始记录或重跑计时。第二批独立重建测量和最终双批 strict 尚未完成。
- 随后该 main 的 [CI](https://github.com/lIlIIlIll/cjdoc/actions/runs/40346738785)
  和[展示站全部分支及发布](https://github.com/lIlIIlIll/cjdoc/actions/runs/40346738705)均通过。
  Linux candidate 和完整验收在 attempt 2 新执行，678/678 native 测试通过，零跳过或错误；
  Windows/macOS 复用原 attempt 1 的成功结果，完整日志逐字节相同，不计为新增执行。
  Linux Python 573 项测试中的 10 项平台跳过单列。真实 self smoke 保留 `partial` 和
  1209 条诊断；CI 性能检查仅为 identity-only，不当作耗时或 RSS 硬上限证明。
  已创建 `v0.7.5` annotated tag，tag object 为 `f16cfb1e30d69692b2d78a4cae795a55b7f73ac2`，
  精确指向 `a1852d68ae3ac06dc50f6273eeade8099dee223b`。
  [正式发布工作流](https://github.com/lIlIIlIll/cjdoc/actions/runs/40362242523)仍在执行，
  tag 不代表公开 Release 已发布，也不提前更新主仓工具资格。
- 第二批七库独立 fresh build 后完成另 770 个单元。主 agent 验证全部 3016 个原始文件，
  重放两批三种汇总，核对 18 个稳定 metadata 字段及 10 个固定工作量用例跨批一致。
  两批合计 1540 个单元、220 份 yjson 固定工作量证明；第一批 8 项、第二批 9 项
  workload 满足 Max CV ≤ 5%，噪声行完整保留，没有第三批。
  完整构建审计的 133 个原始文件也已核验；相关输入子集与整仓来源摘要分别记录，
  公开层和最终干净检出 strict 尚未完成。
- 已授权的 Windows 单次诊断分支 `diag/windows-llc-evidence` 已推送并执行
  [一次工作流](https://github.com/lIlIIlIll/cjdoc/actions/runs/40353536282)。controller 在源码
  Git 身份校验前置失败，实际编译调用为零；现有输出未保留失败子命令 stderr。
  结论为 `BUILD_NOT_STARTED`，既不算 llc 复现，也不算未再现。完整首错和原 ZIP 保留，
  未重复 dispatch，诊断分支未合入 main。
- 正式发布的 macOS、Windows 验收分别在 `scripts/check.sh` 第二次产品构建中发生
  `llc` 崩溃：macOS 为 `yjson.opt.bc`、退出码 139；Windows 为 `markdown.opt.bc`、
  退出码 3221225477。两平台首次产品构建和此前的 preflight 测试均通过。
  首个失败发生在 native 测试之前，不归为测试失败或下载问题；编译器根因仍未知。
  完整首错日志保留，不以 main CI 的较早通过替代正式发布资格。
- 主 agent 独立核验完整源码摘要补充归档的 287 个文件，其中 285 个源文件的字节和权限
  与原 1964 文件归档相同。使用冻结的实际实现重算 262 个输入的 `source_digest`，以及
  各 51 文件的产品与 harness 摘要，均匹配测量身份。该结果补足来源复算，不代表
  最终干净检出的 strict 已通过。
- 七库公开层已纳入工作区。主 agent 独立对比六个原始归档的 7036 个文件，核验全部
  路径替换、799 份原样源码记录、25 份编译产物排除记录和额外来源输入。
  json4cj 的真实 Git commit/tree 已独立重算，194 个文件原样匹配，另三份清单的适配
  diff 与原字节一致；固定来源的 README 许可声明保留，不编造独立许可正文。
  当前 schema 3 marker 的 27 份 payload、测量 Git 身份、源码/依赖身份及 README/报告
  绑定检查通过。API inventory 1111 项、暂存测试 6 项、发布临时树测试 14 项、证据回归
  40 项及 57 条本地链接检查通过；最终干净检出 strict 尚未执行。
- 开发批完整 333 条示例执行通过，零失败、零重试，用时 13210.361 秒，在 21600 秒预算内。
  原始 producer IR 的 SHA-256 为 `c6bb3d51c00c061b5045004241eafda439a5e1a8b58eea11b7e399f0e5a7871c`；
  运行报告为 `46f63c517aa51923b7919c92cca6f563766f076fe7c2da22ec19e821fbe01e91`。
  主 agent 独立核对冻结源码、真实 Git blob、逐项代码和完整消费者摘要、stdout 断言及映射。
  临时构建目录正常清理，保留运行时记录的 executable 与宏产物摘要，不能事后重算已删除二进制。
  旧 19 个失败消费者的代码与完整源码摘要均不变，当前全部通过；旧加载宏的二进制身份未记录，
  仍为未知。该批始终为 `development-only`，正式检查仍按设计拒绝它，未改标为合格证据。
- 发行流程诊断确认 `cjpm build` 默认不增量复用。两次独立 Linux 构建真实通过，第二次开始前
  的 79 个 target 文件与第一次结束相同，19 个包的 verbose 编译命令仍全部重新执行。
  Windows 通过的 CI 使用 `windows-2022`，失败发行使用 `windows-2025`；不能称完整环境相同。
  修复让完整验收链拥有唯一产品构建，并统一 Windows runner；编译器崩溃根因仍未知。
  为保留公开的失败 tag，另准备 `0.7.6`，未移动 `v0.7.5`。修复与版本提交的 124 项 Python
  回归及 actionlint 由主 agent 独立通过。该次旧发行最终为 failure，Linux 验收通过，
  publisher 跳过，未创建公开 Release。
- cjdoc `0.7.6` 的 [PR #166](https://github.com/lIlIIlIll/cjdoc/pull/166) 已创建，
  HEAD 为 `741026e42689c9b288852515cdb43d7554c6a843`。主 agent 独立核验全部 929 个
  冻结归档文件、与最终提交相同的 497 个产品源码和 manifest/lock，以及普通 static stdx
  `e62289d5...`。真实产品构建通过，二进制摘要为
  `83893660898cbd2793eb8605729854799ee7037e35e671d42d0815ddcd6c5484`。
  该次构建记录实际 wrapper 命令与优化策略，未捕获逐包 CJC argv，不借用较早构建的观测。
  官方 updater 生成九份 golden，变化仅为 generator 版本；官方 identities 实测后仅更新
  basic/self 两项文档摘要，其余 baseline 字节和性能阈值未变，随后 exit 0。
  17 项 updater 回归另经主 agent 通过；identities 仍只证明文档身份，不代表性能硬上限通过。
  原先输入预检失败、实际摘要 RED 和旧缓存的精确隔离记录均保留，未改产品保护。
  PR 当前 HEAD 的官方复审、三平台 CI、main 门禁及 `0.7.6` 正式发行仍须完成。
- PR #166 的 `741026e` 已完成官方代码及安全复审，均无发现。两个 Linux 候选构建通过；
  [展示站组装](https://github.com/lIlIIlIll/cjdoc/actions/runs/40375328661)失败，
  [CI 的 Linux 验收](https://github.com/lIlIIlIll/cjdoc/actions/runs/40375328590)在
  678/678 native 测试、provider 和 HTML a11y 通过后，真实 self smoke 因同一链接失败。
  首因为新发布记录使用相对 `release-notes.md`，发布后的概念索引没有该相对文件。
  最小修复改用现有手册项采用的绝对源码链接，并增加发布索引回归；83 项相关测试通过，
  主 agent 独立重跑其中 21 项，并重放两个生产 validator，真实生成页面均由 RED 转 GREEN。
  文档正文变化使 self 摘要改变，仅按官方实际输出机器回填，basic 和其余 baseline 字节、
  性能阈值不变。三文件修复尚未提交，更新已推送历史等待本次明确授权；正式 identities
  仍须在干净的新提交上通过。等待命令曾因 GitHub API HTTP 500 退出，该退出不是 CI 结果。
- 用户已授权两次本地验证 clone 和 PR #166 三文件修复的原提交更新。仅在新磁盘任务目录
  创建主仓 `7d48eb2`、宏 C9 的两个真实 Git 副本，前后均 clean；原仓 HEAD、refs、索引、
  配置及三个用户文件前后完全相同。完整 strict 退出 0，40 项回归通过；主 agent 独立
  重放 strict checker，核验暂存的全部 371 文件、权限和 payload 摘要，均通过。
  暂存 payload 为 `455e0f83d45d18ef12900e1577789ea97c531c0200388d7c6fd7ef83845e80d3`。
  该结果适用于此精确源码，不等于 cjdoc 资格或最终托管平台通过。
- PR #166 的链接、回归测试与 self 实测摘要已分别并入原版本和生成提交，安全更新至
  `4dc5f81e8ff03086f914e3721eb566e9e5007f75`。官方 identities 在干净提交上实际执行退出 0，
  basic/self 摘要分别为 `d2411233...`、`0f86880e...`；产品、SDK、策略和 baseline 前后稳定。
  旧 HEAD 的 macOS 完整通过，Windows 659 项 native 测试通过后，真实高亮步骤的取消 host
  构建退出 1；公开收据没有底层 stderr，根因仍未知，不把它记作已定位的 llc 崩溃。
  [新 HEAD CI](https://github.com/lIlIIlIll/cjdoc/actions/runs/40426118304)和
  [展示站](https://github.com/lIlIIlIll/cjdoc/actions/runs/40426118335)继续单独验收。
- `4dc5f81` 的 Linux CI、真实 self smoke、identities 和高亮 worker 通过，展示站的组装、
  下载源码复现、两个浏览器分片、API 阅读及最终校验全部通过；PR 不执行站点发布。
  当前 HEAD 官方代码复审完成且无发现，安全复审仍只对应旧 `741026e`，没有移用。
  Windows 在根产品首次构建的 `yjson.opt.bc` 上报
  `LLVM ERROR: Cannot emit physreg copy instruction`，位于 X86 copyPhysReg / ExpandPostRA，
  llc 退出 `3221225501`；native 测试未运行。macOS 根产品、665 项 native 及 CLI 通过后，
  provider 消费方编译相同依赖的 llc 退出 139。原完整日志已保留，没有重跑原失败门禁。
  直接观测仅能确认后端 O2，完整 CJC argv、实际 stack 和工具字节身份尚未取得，不能
  仅依版本 fingerprint 或本机依赖 manifest 代替。原始 Git 依赖为 `54b4965`，
  本机缓存的 manifest 与其 Git 版本不同，未据此猜测托管输入。
- 固定 Linux SDK 的最小编译运行 probe 通过；使用原官方归档内 47 个 Windows 模块，
  原样 Git `54b4965` 的一次 Windows 目标 O2 加关闭 CHIR 内联跨编译通过并保留 IR/COFF。
  这不是 Windows 原生运行，也不能解释失败 runner。macOS 跨编译因缺少目标模块在前端
  退出，后端未启动，未修改 SDK。下一步原生取证方案与代码单独准备，旧单次诊断授权
  不视为新一轮权限；工具资格继续保持 candidate。
- 干净验证副本通过 GitButler 快进至 `55f876c`，1987 个主仓和 26 个宏仓 Git blob
  及执行权限独立核验通过。完整 strict 再次退出 0，40 项回归通过；
  `release_temp_tree.py --enforce-clean` 暂存 371 文件，payload 为
  `aae1befd6c05b58896ec94a37d4b9d3252775a6f5930da41977bf5cb58c0afa9`。
  原验证副本及三个用户文件未变化；这些结果仍不替代工具资格或托管平台验收。
- 用户另行批准推送诊断提交
  [`df8ba7b`](https://github.com/lIlIIlIll/cjdoc/commit/df8ba7b39b1f06aa82a66359dd4f5a18569a3983)，
  并触发[一次 Windows/macOS 诊断](https://github.com/lIlIIlIll/cjdoc/actions/runs/40439980860)。
  独立诊断分支固定产品源码 `4dc5f81`，不合入正式门禁；每个平台只执行一次原目标，
  仅捕获到 yjson 的 llc 失败时增加至多一次 600 秒后端跟踪，原目标退出码保持。
  64 项聚焦测试、actionlint、精确 diff/消息/工作树隐私检查通过；两个平台原始失败行
  已实际验证，解析完整工具、输入、输出及 flags，不给原目标新增 `-V`。
  最小 Linux IR 的硬链接捕获和同 SDK 汇编验证通过；该跟踪开关在最小 IR 上生成的
  obj 与无跟踪版本相同，不推断原生目标的开销或故障根因。
  非 UTF-8 完整 IR 按隐私规则扣留，原始 trace 不上传；128 MiB 仅是事后解析上限，
  不是原始日志的磁盘写入上限。本次两平台均在首个 Git snapshot 的
  `git diff --exit-code HEAD --` 处退出 1，完整错误收据及日志已下载；
  preflight CJC、产品目标、后端跟踪调用均为零，不算 llc 复现或未再现。
- 两平台首错 diff 摘要相同，均只涉及既有 CRLF fixture。父 agent 用原字节与 Git blob
  完全一致的文件只读重放，得到相同 diff，证明 Git 换行 clean filter 可产生该观测。
  初始原生拒绝收据没有文件字节清单，因此不能据此声称 checkout 改写了原文件。
  修复改为逐文件原始 Git blob、索引和执行位校验，保留规范化 diff/status 作为独立观测，
  不修改 fixture、不把非空 status 称为 clean，也不允许真实源码、索引或未跟踪文件漂移。
  同次文件读取绑定前后 fd/path 身份，初始拒绝保留可取得的工作快照。
  真实 937 文件树和隔离复制的真实索引重放由旧版拒绝转为新版通过，原索引与 fixture
  未改；74 项聚焦测试通过。本地修复尚未推送，单次诊断没有自动重跑。
- 用户另行批准快进推送三文件修复 `f3a6e44`，并执行
  [诊断 40441741597](https://github.com/lIlIIlIll/cjdoc/actions/runs/40441741597)。
  macOS 收据记录一次目标、退出 0，但完整证据因绝对路径模式被扣留；
  公开层无法复核完整 source/SDK/IR 身份，不把该次 job 成功算作资格通过。
  Windows 在首个文件的 path/fd 属性比较处拒绝，产品目标和 preflight CJC 仍均为零。
  原收据没有失配字段或数值，具体原生差异未知，没有再运行原失败目标。
- 本地四文件诊断修复 `5063800` 已准备。核对
  [CPython 3.12.10 路径属性实现](https://github.com/python/cpython/blob/v3.12.10/Modules/posixmodule.c#L2008-L2018)
  与 [fd 属性实现](https://github.com/python/cpython/blob/v3.12.10/Python/fileutils.c#L1026-L1040)，
  确认 Windows 两种 API 的 ctime 语义不同；仅调整跨 API 比较，保留同 API 前后变化检查。
  该问题可由源码证明，但不能据旧收据认定它是唯一原生失配字段。
  同时只补实际选中 Bash 及 SDKROOT 的精确路径映射；未知内容仍扣留，拒绝摘要只包含
  字段位置、类别、SHA 和长度，并再次扫描隐私。81 项测试、真实 POSIX 源身份重放、
  代码复核和隐私检查通过；Windows 原生效果及 macOS 完整公开结果尚未验证。
  随后按用户授权推送。用户进一步明确后续同范围诊断不再逐次确认；正式 PR #166
  仍为 `4dc5f81`，固定产品源码、优化策略和隐私边界继续保留。
- [诊断 40443975451](https://github.com/lIlIIlIll/cjdoc/actions/runs/40443975451)中，
  Windows 原生源码的 929 文件 raw blob/index 检查通过；最小 CJC、单次 obj llc、
  硬链接捕获、原临时目录清空和同 SDK disassembly 均通过。实际依赖解析退出 0 后，
  yjson 工作树原字节门禁拒绝，产品目标为零。完整 1775 文件快照保留，其中 1475 项
  与 Git blob 不同；主 agent 对全部差异逐文件从真实 `54b4965` Git blob 预测 LF→CRLF，
  SHA 全部匹配。macOS 仍为一次目标退出 0；安全拒绝摘要将剩余绝对路径精确定位到
  最小预检 stdout，匹配长度和 SHA 共同确定为系统归档器路径，完整证据仍扣留。
- 诊断提交 `ce207a3` 固定 Windows resolver 子进程的 Git 换行策略，保留继承配置，
  读取有效配置成功后才继续，最终仍要求全部 raw blob/index 校验，不改既有缓存。
  这轮采用原样 Git bytes，与此前 CRLF 工作输入不同，不能视为原 CI 故障修复。
  macOS 仅增加已观测系统归档器及其别名的精确映射，前后文件摘要单独记录，
  不把路径文件摘要当作实际执行或委托工具证明。87 项回归、真实 Git 配置验证、
  差异复核及隐私检查通过，已启动
  [诊断 40445877300](https://github.com/lIlIIlIll/cjdoc/actions/runs/40445877300)。
  两平台均一次目标退出 0；macOS 完整收据取得，主 agent 将产品 929 文件及三个依赖的
  1775/212/7 文件逐一与固定 Git 对象核对，原字节 SHA、blob、大小和执行位均匹配。
  控制器六个模块与诊断提交匹配，源码、依赖、工具前后身份一致，全部七次调用退出 0；
  硬链接清理及同 SDK 反汇编通过。原始 bitcode 与不可审查的派生 IR 均未公开。
  Windows 完整证据仍被扣留；重复的两个二字符匹配 SHA 分别对应 `/C` 和 `/V`，
  尚无原始上下文，不能据此断言它们是 shell 开关。两平台均未触发后端跟踪。
  这轮诊断未复现原崩溃，不代表正式 CI 修复、工具资格或发行通过。
- 诊断提交 `a6c7e12` 仅为普通日志增加精确、独立、无引号短文本脱敏，并标明公开文本
  有损；原始字节 SHA 保留。不豁免任何路径或凭据，LLVM 派生文本不经过该处理。
  引号或转义有歧义时保留整段原文并继续拒绝；独立复核发现的跨行引号反例已实际
  RED→GREEN。94 项回归、代码复核和精确差异/消息/工作树隐私检查通过，已按持续授权
  推送并单次触发[诊断 40447996830](https://github.com/lIlIIlIll/cjdoc/actions/runs/40447996830)。
  固定产品 `4dc5f81`、O2、每平台一次目标和条件后端跟踪均未改。两平台目标各退出 0；
  macOS 完整收据再次通过逐 Git 对象核验，yjson bitcode 与上一轮 SHA 相同。
  Windows 收据字段已通过隐私检查；只有合并日志仍被保守脱敏及隐私检查拒绝，
  整份公开收据因此继续扣留，尚未取得该日志原始上下文；没有据 job 绿色推断完整证据通过。
- 诊断提交 `dd29067` 将普通构建日志与收据分别检查。私密收据仍扣留所有其他产物；
  仅日志私密时完整安全收据保留，以 `WITHHELD`、规范化 UTF-8 SHA 和字节数记录日志拒绝，
  不生成该日志文件。新增 metadata 同样经过最终隐私扫描，目标失败状态及退出码不变。
  98 项回归、actionlint、独立复核和隐私检查通过；macOS 复用已注明诊断版本的证据，
  [本轮只运行 Windows](https://github.com/lIlIIlIll/cjdoc/actions/runs/40449335939)。
  完整收据取得，主 agent 独立核验产品及三个依赖的 929/1775/212/7 个文件、六个控制器
  模块和前后身份，全部通过；目标一次、退出 0，未触发后端跟踪。公开产物只有收据，
  聚合日志及不可审查 IR 继续扣留。首次产物下载 EOF 后仅重新下载既有产物，未重跑 CI。
  Windows CJC 与 llc 的实际 SHA 分别为 `f4f22304...`、`1ea68362...`；观测命令保持
  O2 和关闭 CHIR 内联。PE 默认栈信息不是实际线程栈测量。本轮仍未复现原崩溃。
- 原失败 CI 的 Windows/macOS 均命中既有 SDK 缓存，诊断则重新安装 SDK；这是输入来源
  差异，尚非根因。只读 API 确认原精确缓存键仍在 `main`，准备隔离恢复并比较工具及
  LLVM 库字节。缓存条目 ID 和 archive version 不能由 restore action 直接观测，不能
  仅据 API 候选身份认定实际恢复了某个 ID；工具向量相同也不证明所有 SDK 模块相同。
  只读诊断提交 `ae584f6` 使用原 path、完整缓存键、明确命中检查和 restore-only action；
  恢复失败即停止，不安装补齐、不保存缓存。独立复核发现的失败收据再次写入异常已实际
  RED→GREEN，失败时仅输出固定提示并退出 1。新增缓存测试 10 项通过；既有 98 项测试及
  actionlint 所校验字节未变，证据继续适用。精确 diff、消息和工作树隐私检查通过，
  已推送并单次选择 `cache-identity` 模式；该模式不执行 SDK 安装、编译器或产品目标。
  [实际缓存取证](https://github.com/lIlIIlIll/cjdoc/actions/runs/40451015580)两平台通过，
  原生产品捕获 job 明确跳过；主 agent 独立核对精确命中键、控制器及共享模块 SHA，
  并与已验收的新安装 SDK 收据逐项比较。Windows 17 项、macOS 19 项工具及 LLVM 库的
  大小与 SHA 全部相同。这排除这些文件的缓存字节差异，不证明所有 SDK 模块相同，
  也不证明原失败进程的实际加载状态或崩溃根因。
- 诊断提交 `f353132` 仅对 Windows 固定依赖采用 Git 实际转换生成的 CRLF catalog；
  其全部 1775 个 yjson 工作文件与此前原生拒绝快照匹配。主产品仍要求 raw Git bytes，
  三个依赖仍要求完整 canonical tree/index，只将工作字节比对切换到冻结 catalog，
  明确记录 `rawGitBlobsVerified=false`，不将转换后的文件称作原始 Git blob。
  首次解析前关闭继承 Git 配置、属性和模板输入；独立复核发现的 catalog 身份遗漏及
  local include/includeIf 漏检均补回归，三条断言实际 RED→GREEN。
  123 项 Python 测试、actionlint、独立复核及精确差异/消息/工作树隐私检查通过。
  [Windows 单次诊断 40454209281](https://github.com/lIlIIlIll/cjdoc/actions/runs/40454209281)
  中，主 agent 将 929 个产品文件逐 Git 对象核对，将 1775/212/7 个依赖工作文件逐项
  与 catalog 核对；树、canonical index 和前后控制器、源码、依赖、工具身份检查通过。
  索引结论来自精确控制器执行，原始 index 未公开；此前拒绝快照没有索引证明，不能借用。
  目标一次、退出 0，全部七次调用退出 0，没有触发后端跟踪。公开收据 SHA 为
  `4ecb3d5c51d211713dc549e7a7a6fb7e1eb99e8671a942080ea0505ce0eb080a`；
  聚合日志和不可审查 IR 仍扣留。日志首次下载 EOF 后只重新下载既有日志，未重跑 job。
  捕获的 yjson bitcode 为 8313004 字节，SHA
  `fbfa84e7608a0a5a44153c09d9d7051076eae0a602dbeab5b96e7ee0c93f0525`，
  与此前 canonical LF 诊断完全相同，实际工具向量也相同。换行差异没有复现原始故障；
  不能据此声明所有环境差异已排除，正式 PR、工具资格和发行仍未通过。
- 原失败 Actions 实际检出合成 merge `c98e1db12cda9fa5ec5171ed53050d7372349ce1`；
  日志及只读 Git API 已确认它的 tree 与冻结产品 `4dc5f81` 完全相同，父提交为
  `a1852d6` 和 `4dc5f81`。不能将合成 merge 的 commit 身份直接写成分支 HEAD。
  进一步核对原 Windows 失败实际使用 C 盘继承 Temp，而此前诊断强制了 D 盘私有临时目录；
  原入口还经过 `check.sh → ci_stage.py → Bash --inner build`，此前直接调用 cjpm。
- 诊断提交 `b7b1cac` 恢复根工作区检出、原精确 SDK cache+setup、继承的
  TMP/TEMP/RUNNER_TEMP、原 wrapper 日志位置及实际 preflight/build 阶段链；
  去掉额外 CJC 编译预检、独立解析和 verbose。这仍是阶段前缀复现，保留分开调用的
  外层差异，不称完整 acceptance gate。原 Temp 只观察，不清理；同卷 retained 目录
  位于监视根之外。长短路径通过原生 API 和 same-file/目录身份核对，再按完整失败 argv
  唯一绑定，不按 basename 猜测。成功时只称首条观测到的 yjson IR，不推断它来自 root。
  独立复核发现的入口异常泄漏已补四条实际 RED→GREEN；新增 21 项及未变的既有 123 项
  测试、actionlint、差异复核和隐私检查通过，原目标非零退出码在后续异常时仍保留。
  [原 Windows 阶段诊断 40457288296](https://github.com/lIlIIlIll/cjdoc/actions/runs/40457288296)
  精确 cache 命中，真实 preflight 42 项及 build 阶段通过；原生产品捕获和缓存检查的
  其他模式明确跳过。目标一次、退出 0，root 与 worker 两条真实 wrapper 记录均为
  `build --jobs 1`、`-O2 --fno-chir-function-inlining`；这证明实际 wrapper 策略，
  不能替代未观测的逐包 CJC argv。主 agent 独立核对 929 个产品 Git 对象、1994 个依赖
  工作文件/catalog/canonical index、八个控制器模块和完整候选身份，均通过；
  依赖在目标开始前不存在，结束后才核验，不声称已有依赖前后快照相等。
  22 条捕获均由编译器清理原路径，唯一 yjson IR 仍为 `8313004B / fbfa84e7...f0525`，
  与此前诊断相同；17 项工具向量也相同。实际 Temp 目录身份前后相同，三次记录调用
  全部退出 0，未触发后端跟踪。安全构建日志与完整收据已取得，收据 SHA 为
  `dbbf6db245b221ab0bee155e469790a2c1f2eb46fd158bc6db9adc655ba3cb6a`。
  这轮仍未复现原错误，不代表原完整 CI、工具资格或发行通过；macOS 的真实前置阶段
  状态和完整 gate 外层仍待对齐。
- 完整 gate 诊断 `7720e54` 固定原合成 merge `c98e1db`，恢复两平台无 stage 参数的
  原始完整命令及顺序，并绑定 GitHub step 实际 Bash 的前后 SHA。macOS fixture 按原
  workflow 边界保存并恢复，真实 Bash fixture 验证原字节、权限和失败码；仅保留 yjson IR，
  未扩大原本的后端跟踪范围。154 项测试、actionlint、独立复核及隐私检查通过。
  初版旧测试错误地将整个 workflow 限为 Windows，已将其约束保留在原 capture 模式，
  另增完整模式隔离断言；初次失败及误生成的初版冻结记录均保留为拒绝证据，冻结助手已
  改为核对各真实退出码、日志 SHA 和测试数后才生成记录。
  [两平台完整诊断 40459710387](https://github.com/lIlIIlIll/cjdoc/actions/runs/40459710387)
  均结束为失败，但原因必须分别判断。
  Windows 完整安全回执已独立验收：929 产品 Git 对象、1994 依赖工作文件、canonical
  index、九个控制器模块和候选文件身份通过；原目标一次、退出 1，yjson 已通过且 IR
  仍为 `fbfa84e7...f0525`。首个实际失败是 markdown 的 llc，退出 `3221225477`
  （`0xC0000005`），栈位于 `MachineRegisterInfo::addRegOperandToUseList`、
  `InstrEmitter` 和 `SelectionDAGISel`。仅记录到一条失败的 root build wrapper，
  native/Python/CLI/provider 后续阶段未运行。该轮只保留 yjson IR，不能跟踪 markdown，
  未触发 yjson 后端重放。收据 SHA 为
  `a1daa8bebfac6f8cdc825eb2f6360f848c6c00c5d74682f6073c5186ca58b481`。
  macOS 最小回执记录目标一次、退出 0；job 退出 2，完整回执被隐私检查扣留，
  `privacyLocations` 为空。原日志未输出额外失败类别，具体取证失败仍为 UNKNOWN；
  不将其解释为编译器失败，也不借目标退出 0 宣称完整资格通过。
  独立纯函数反例证明安全字符串 `Build:` 后跟换行，序列化为 JSON 后可被误认作
  Windows 盘符，而逐字段检查均通过。这证明发布检查存在表示层假阳性，但尚不能
  据此断言它是该次 macOS 隐私拒绝的唯一原因，或解释 job 的额外退出 2。

- 诊断提交 `884edea` 修正 JSON 表示层误拒绝：发布前递归检查真实字符串的键和值，
  最终序列化后重新解析并检查；原始日志和 LLVM 文本检查保持不变。最小拒绝收据保留
  受控失败状态、退出码、阶段及错误文本 SHA。独立审查发现的私密键加私密子值会阻止
  最小收据生成，已补实际 RED→GREEN，私密键只保留哈希位置。完整模式仅保留 yjson、
  markdown 两种 IR；必须唯一匹配原失败完整 argv，才允许一次条件后端跟踪，markdown
  反汇编仍只在私有目录。165 项测试、actionlint、独立复核及隐私检查通过。
  [两平台完整诊断 40464909664](https://github.com/lIlIIlIll/cjdoc/actions/runs/40464909664)
  中，两个原始完整目标均一次退出 0，preflight、build、native、Python、CLI 和 provider
  阶段均通过，Windows/macOS 原生测试分别为 659/665。主 agent 逐文件核验两平台
  929 个产品 Git 对象、1994 个依赖工作文件、九个控制器模块及 16 个候选文件，均通过；
  Windows 依赖按冻结 CRLF catalog 核验，macOS 按原始 Git blob 核验。源码、控制器、
  工具及原 Temp 身份前后相同。
  Windows 控制器退出 0，完整收据 SHA 为
  `5fb953c49d5df1cea433939c3ccda8321e3b4ff643a3eb005db899ac9dc83cb4`。
  四条 wrapper 记录确认 root、worker、provider 使用 O2 并关闭 CHIR 内联，单测使用
  既定 O1；这些策略记录不替代逐包 CJC argv。六条 yjson/markdown 捕获均已由编译器
  清理原路径，首条观测 yjson IR 仍为 `fbfa84e7...f0525`，未触发后端跟踪。
  macOS 控制器退出 2，完整安全收据 SHA 为
  `79573076248e64386d6f46deb91a467ff0c593fb2c7e1b73a4645ccdaabd3731`。
  此次明确记录 `OSError: [Errno 9] Bad file descriptor`，最终完整性检查通过；IR 捕获
  和 wrapper 记录未取得，不能把目标退出 0 当作观测器验收。实际底层错误仍待定位，
  不将该错误称作编译器故障。两平台仅公开安全日志与收据，没有原始 IR；本轮没有复现
  原 llc 崩溃，也不证明正式 CI、工具资格或发行通过。

- 诊断提交 `e0670e9` 修复观测器停止时的异常遮蔽：信号发送失败后仍 join，先保留
  线程首错，再报告信号失败或超时，捕获仍判失败。按
  [Apple kevent 契约](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/kevent.2.html)
  保留 `EV_ERROR` 的整数系统错误码和固定消息，不输出路径或 descriptor ident。
  七项新增收尾回归修复前出现三项 ERROR，另一个错误码回归的两条断言修复前失败；
  最终 173 项测试、actionlint、独立复核及隐私检查通过。仅运行
  [macOS 诊断 40470167329](https://github.com/lIlIIlIll/cjdoc/actions/runs/40470167329)，
  Windows 复用上一轮明确绑定提交的证据。
  主 agent 再次逐文件核验 929 产品文件和 1994 依赖文件的原始 Git blob、九个控制器
  模块及 16 个候选文件，前后源码、控制器、工具和 Temp 身份相同。原始完整目标一次
  退出 0，全部阶段通过，原生测试 665 项通过；观测器为 `CAPTURE_MISSED`、退出 2。
  完整安全收据 SHA 为
  `9e6968d1ca9b105fb6e31eca8b20f4c37dbff6436aab1c8fb84b539331391c1c`。
  此次线程首错明确为打开共享 Temp 下 `com.apple.inputanalyticsd` 时遭到权限拒绝，
  后续才是停止信号的 `Bad file descriptor`。这定位了本轮观测失败，不能推断较早
  未保留首错的轮次具有同一原因。未取得 IR 或 wrapper 记录，未触发后端跟踪，原 llc
  崩溃仍未解释；正式 CI、工具资格和发行继续未通过。

- 诊断提交 `1963ee1` 将完整 macOS 模式的订阅与扫描同时限定到继承 Temp 下的
  `cangjie-tmp-*` 一级目录及其子树，Temp 根仍监听，未修改 TMPDIR、目录权限或 CJC
  参数。范围依据编译器 `v1.2.0` 的固定 Git 对象 `91c24c4`、此前 42 条原生路径和
  本轮选中 CJC 的字面量检查；这是显式观测协议，不是 SDK 二进制精确重建证明。
  范围内权限、枚举和事件错误仍失败，符号链接、协议漂移和 SDK 字节变化均拒绝；
  目录删除竞争不能在没有 IR 时生成成功。默认捕获模式保留原范围。初始 12 项回归
  有八条 RED 断言，另行直接重放无关目录的 open 权限拒绝；补充删除竞争后，
  全部 186 项测试、actionlint、独立复核及隐私检查通过。
  [macOS 单次诊断 40475522686](https://github.com/lIlIIlIll/cjdoc/actions/runs/40475522686)
  中，原完整目标与控制器均退出 0，全部阶段通过，原生测试 665 项通过。
  主 agent 独立核验 929 产品文件、1994 依赖文件、九个控制器模块及 17 个候选文件，
  前后身份通过；SDK 工具及 LLVM 库 19 项、平台归档器一项的大小和 SHA 均与此前
  macOS 诊断相同。初版父验收器误将这 20 项总数写为 19，拒绝记录保留；修正计数后
  重新核验既有产物，没有重跑 CI。
  六条捕获均位于声明的编译器目录范围，原路径已由编译器清理；首条观测 yjson IR
  仍为 `b4b17f6a...db87a`。四条 wrapper 记录确认 root、worker、provider 保持 O2 并
  关闭 CHIR 内联，单测保持 O1；不将 wrapper 记录当作逐包 CJC argv。完整收据 SHA 为
  `8d718e994add81b0f610d40f5e9e2db4229bc54d20dd77a0475cc0ad7f7fbb50`，
  只公开安全日志与收据，原始 IR 仍私有，未触发后端跟踪。本轮观测器修复通过原生验证，
  原 llc 崩溃仍未复现或解释；正式 CI、工具资格和发行尚未通过。

- 上游 [PR #165](https://github.com/lIlIIlIll/cjdoc/pull/165) 合入 `main` 的精确提交为
  `9bf41bbd6e91a6cea4ff8dd109403abd7618776b`。`but pull --check` 只预览到正式
  `fix/release-candidate-build` 需要重排，未移动已推送历史。独立无 Git 源码投影保留
  原 PR 的 28 文件范围；仅资源预算测试和 `tests/perf/baseline.json` 与新 main 重叠。
  预算测试三方合并保留新 main 的 131072 边界断言及 0.7.6 版本断言；真实定向测试
  四项通过，681 项因过滤未运行。产品用 O2 加关闭 CHIR 内联真实构建，单测使用既定
  O1 隔离 target，产品二进制前后 SHA 均为
  `bafcda792e11cfc5baf12bf424ca7618f74c425decec59fbbd7225f1dbbac291`。
  发布参数、执行图、安全及更新器 38 项 Python 测试和构建接线 21 项测试通过；
  首轮发布测试因缺少仓库 Python 模块路径出现三项导入错误，原日志保留，按官方发现
  所需模块路径重跑后通过，没有修改断言。
  新程序通过真实 CLI 与未修改的官方 `measure_identities` 生成函数分别生成 basic/self，
  两次摘要一致：basic 仍为 `d2411233...e68`，self 为
  `d16032fd9d26e459de2d50964e07e36f73f2a7d80b9e276dae0ae6fe07d8aed7`。
  预览只更新这两条真实摘要，全部性能门槛和其他基线字段保持不变，未运行时间/RSS 测量。
  官方 golden 更新器使用新 producer 及隔离操作副本的真实已提交 fixture；九个子树与
  新 main 相同，144 个输入文件前后未变，生成的九份 golden 与原 PR 字节完全相同。
  操作副本实际 HEAD 是 GitButler workspace commit `81a4ba8`，tree 与诊断分支
  `1963ee1` 相同；初次误将 HEAD 当作分支 tip 的拒绝记录保留，未修复 HEAD 或索引。
  最终预览共 988 文件，计算得到的 Git tree SHA1 为
  `b6840bbcb724ed574801d3144b728c30e5ee49f7`，该树尚未写入 Git，不能当作已有提交。
  无 Git 投影不具备正式来源门禁；实际提交上的完整 identities、最新三平台 CI、官方
  当前 HEAD 复审和发行资格仍须完成。正式 PR 与诊断分支的已推送历史均未因此改写。

- 用户授权后，在新的隔离副本中停用诊断栈，只应用 PR #166 正式分支，通过
  `but pull` 同步 `main` 的 `9bf41bb`。唯一冲突是 self 文档摘要，使用此前真实 producer
  已核验的 `d16032fd...aed7` 解决，未改性能门槛。四个逻辑提交依次为 `b296e21`、
  `90ee5b9`、`db94419` 和 `6900943f3549c582064a8c9aeb87b4bc03cc8068`。
  最终 Git tree 为 `b6840bbcb724ed574801d3144b728c30e5ee49f7`，988 个文件逐项匹配
  已审查预览，原诊断分支仍为 `1963ee1`，原工作区未参与此次同步。
  另一个验证副本由 GitButler 签出精确正式提交，真实干净身份核验通过；首次核验因
  agent 导入脚本时生成 Python 缓存而拒绝，记录保留，仅清理该副本中自行生成的缓存。
  CRLF fixture 原始字节及权限始终与 HEAD 相同，没有通过修改源码或索引放宽门禁。
  `scripts/check.sh preflight --repo .` 的 42 项测试和完整
  `scripts/perf_gate.py identities` 均退出 0；后者明确绑定 `sourceCommit=6900943...8068`。
  identities 使用此前同字节预览源码构建的 producer `bafcda79...ac291`，basic/self 摘要
  与两次预览生成一致，仅证明文档身份，未测量时间或 RSS。验证后再次核验源码身份未变。
  完整 GitButler diff 与隐私检查通过，已用保留保护检查和 pre-push hook 的 `but push`
  将远端同一 PR 从 `4dc5f81` 更新至 `6900943`。远端 base 是 `9bf41bb`，冲突已解除。
  [新 CI 40488905847](https://github.com/lIlIIlIll/cjdoc/actions/runs/40488905847) 与
  [新展示站 40488905897](https://github.com/lIlIIlIll/cjdoc/actions/runs/40488905897)
  已启动，官方摘要的 `code_review` 对完整新 HEAD 为 `running`；不复用旧 security SHA
  或旧 CI 结果。最新三平台验收、官方复审、0.7.6 发行和 yjson 工具资格仍未完成。

- `6900943` 的三平台 CI `40488905847` 与展示站 `40488905897` 均首次退出 0。
  官方代码复审在完整该 SHA 上完成，提出 P2：发布流程在 macOS 的已知 CRLF fixture
  恢复之前执行源码洁净检查，可能使已通过验收的目标无法打包。新增回归执行真实 workflow
  shell，并对真实已提交 Git fixture 调用产品 `exact_worktree_identity()`；原 workflow
  下 CRLF 正例为 RED，其余八项通过。将原有两个身份检查移入恢复后的收据步骤，并保留
  `CJDOC_RELEASE_COMMIT` 后，相关 64 项 Python 测试和 actionlint 通过。
  正例确认恢复后的原始 CRLF 字节，反例确认其他源码变脏、验收失败、恢复失败及发布
  身份失败均阻止收据。独立复核确认仅 workflow 与执行回归两文件变化，其他 986 文件、
  产品编译选项和 SDK 身份未变；本地 fixture 不替代真实 macOS Release 验收。
  修复并入原发布流程提交，仍保留四个逻辑提交，安全更新后的正式 HEAD 为
  `155fb458f90fa6f29f89c74ca8f4d1582b61792c`，tree 为
  `f360c6c90267321e5940ead9071182193fc011f5`。该精确提交的 preflight 42 项及完整
  identities 再次退出 0，仍使用同字节产品源码构建的 `bafcda79...ac291`，basic/self
  摘要未变。代码和回归验证后，已解决对应 P2 conversation。
  [新 CI 40497099839](https://github.com/lIlIIlIll/cjdoc/actions/runs/40497099839) 与
  [新展示站 40497099903](https://github.com/lIlIIlIll/cjdoc/actions/runs/40497099903)
  已启动，必须验收新 HEAD 的正式结果及官方复审后才能合并、发布。

- `155fb45` 的官方代码复审明确在完整 HEAD 上 `completed`，无发现、无未决发现。
  CI `40497099839` 的 Linux candidate、Linux 全部验收及展示站 `40497099903` 通过；
  Windows/macOS 失败，未重试。两平台 preflight、主程序与 worker build、原生测试、
  Python 工具测试及 CLI 均通过，失败都在 provider fixture 的再次编译。
  macOS 原生 672 项通过，随后 `cjdoc.opt.bc` 的 llc 退出 139；Windows 原生 666 项
  通过，随后 `markdown.opt.bc` 的 llc 退出 `3221225477`，栈顶为
  `MachineRegisterInfo::addRegOperandToUseList`，经 `InstrEmitter` 和 SelectionDAG。
  原始失败日志分别为 1253397、1311162 字节，SHA 为
  `66c57e18e14d30d3f6b1b0d212065ae0932fa128e52c01ed8d168ec1c1db8532` 和
  `efe4e1a9d4ff180653ae01ed7c71e8cb419c342c7e975df75b7345ace49c1fe3`。
  实际测试合并为 `bf0e39ddddb28c28c71fddc595910619257b48c4`；GitHub Git 对象已核验
  tree 为 `f360c6c`，父提交依次为 `9bf41bb`、`155fb45`。原始 IR 未取得，不能从这份
  日志断定具体失败函数或编译器根因。
  Windows 另有 `provider_build_cache: unbound variable`：函数返回时局部变量已失效，
  EXIT trap 因而无法完成清理。真实 shell 回归在原脚本上有两项 RED，六项定向回归及
  阶段、发布相关共 64 项修复后通过，`bash -n` 通过。修复只让 provider 函数在子 shell
  中完成原有清理，保留原始失败退出码、既有输出拒绝及无关文件；后续已并入原提交。
  这修复了失败收尾，llc 崩溃仍待固定本轮源码的 IR 取证与原生验证，未构建或修改 SDK。

- 针对本轮失败增加独立的 `pr166-provider-155` 诊断入口，提交
  `a1ef6e5db0f9214a990627b008e13ef06f6eb485`，父提交仍为 `1963ee1`。
  七个诊断文件的 199 项回归、actionlint、独立审查和隐私检查通过。它固定实际失败的
  `bf0e39d` 测试合并及 `155fb45` 源码，不包含尚未提交的 provider 清理修复；
  前后均检查相同 source tree，保留原 SDK 缓存、O2 参数和完整目标的阶段顺序。
  新 scope 仅保留 `cjdoc.opt.bc`、`markdown.opt.bc`；只有完整原始失败行唯一绑定到
  捕获的 IR、工具与参数，才允许一次最多 600 秒的后端跟踪。旧诊断 scope 不变，
  新 scope 的原始及派生 IR 均不公开，仅上传通过检查的 receipt/log，保留三天。
  推送曾因 GitButler 处理旧正式祖先而被专用 hook 拒绝，远端未变；随后仅在本任务
  隔离 manager 中切回既有 workspace、更新诊断比较基线并切回原分支，未执行 setup、
  未改写冻结提交。受保护的快进推送及原隐私 hook 均通过，正式 PR 保持 `155fb45`。
  [诊断 40509688775](https://github.com/lIlIIlIll/cjdoc/actions/runs/40509688775)
  的 Windows/macOS 原始完整目标均一次退出 0，分别通过 666、672 项原生测试。
  父验收逐文件核对了每个平台的 988 个源码文件、1994 个依赖文件、10 个控制模块和
  20 个候选文件，前后身份及既有 SDK 工具向量一致。四条 wrapper 记录确认产品仍为
  O2 加关闭 CHIR 函数内联，单测仍为 O1。两平台均未触发后端跟踪；这证明本轮未复现，
  不证明 llc 已修复，也不替代正式 PR CI。安全收据 SHA 分别为
  `6759d3bcc36ac5dae437cb43bd6fc5fee9e9adb96b76a22cf51369ff5f8a8b96` 和
  `6ab1381a85ca14fd002ce7f99583e8065cfbebbd63df53f29ca5661f09205ae7`。

- provider 清理的两文件修复经独立审查后并入原发布流程提交，仍保留四个逻辑提交。
  新正式 HEAD 为 `4909a9f974f9f648f3fda71f88760e306a291cae`，tree 为
  `6e5e06fb30197484b305511ce5b7cc52dfdfd382`；相对 `155fb45` 只有这两文件变化。
  新的干净检出通过 preflight 42 项及完整 identities；复用同字节产品源码的已构建
  producer，不宣称另一次本地产品重建。原始失败与 64 项清理验证记录保留。
  官方 `code_review` 已在完整 `4909a9f` SHA 上 completed，无发现及未决发现，旧安全
  审查不复用。[正式 CI 40517201766](https://github.com/lIlIIlIll/cjdoc/actions/runs/40517201766)
  与[展示站 40517201641](https://github.com/lIlIIlIll/cjdoc/actions/runs/40517201641)
  已由同一 PR 更新自动启动；首次结果及后续修复记录如下。

- `4909a9f` 的首次 CI 中，Windows、Linux 及展示站通过；macOS 原生 672 项通过，
  Python 工具测试 594 项中两项清理回归失败、12 项跳过，后续 CLI/provider 未运行。
  首个错误仍为 `provider_build_cache: unbound variable`，位于系统 `/bin/bash` 的 EXIT
  清理，不能归为该轮 llc 故障。失败日志 SHA 为
  `94e1719eae028ebb6788cc55f40d4e44f20a78e7aa51cc48ac08e168bfd9aeed`。
  在隔离目录用 GNU 官方源码构建 Bash 3.2.57 测试工具，原六项清理测试同样有两项 RED，
  但 GNU 版本表现为返回 0 而非 macOS 的返回 1/局部变量失效；没有将 Linux 构建宣称为
  macOS 二进制证明。该工具未安装到系统，也未构建或修改 Cangjie SDK。

- 新修复让三个 provider 路径变量仅由子 shell 隔离，避免 EXIT 时依赖函数局部变量。
  唯一 EXIT handler 显式保留原始命令失败；仅原命令成功时，清理失败才决定退出码。
  命令后显式退出以覆盖旧 Bash 继续执行的差异，预存输出拒绝和清理所有权不变。
  回归改经真实 `dispatch_stage`，补充父作用域隔离与双重失败场景；当前 Bash 66 项
  相关检查、真实 GNU Bash 3.2 的八项回归及两版语法检查通过，独立审查通过。
  修复并入原发布流程提交，仍保留四个逻辑提交，新 HEAD 为
  `8cd4ccbb7683e430835f064450895b88c0269d53`，tree 为
  `06f7d27491f8952b1df63163dca292d8cb8378d5`；相对 `4909a9f` 仍只有这两文件变化。
  精确干净检出再次通过 preflight 42 项及完整 identities，产品输入和 O2 策略未变。
  官方 `code_review` 在完整新 SHA 上 completed，无发现和未决发现；
  [正式 CI 40528520996](https://github.com/lIlIIlIll/cjdoc/actions/runs/40528520996) 与
  [展示站 40528520952](https://github.com/lIlIIlIll/cjdoc/actions/runs/40528520952)
  的首次运行均通过。主 agent 独立读取两平台完整日志：macOS/Windows 各 596 项 Python
  测试通过，包含同一组八项清理回归，native 分别 672/666 项通过、零跳过；preflight、
  build、Python、CLI 和 provider 全部阶段通过。原日志 SHA 分别为
  `0a8682331d206425d3371ab2d74c9da8537386195f6e22180c556775173003a9` 和
  `294f627f75ded1a2916af57b759eb0cfe1f19ed23ae47499e47d5ac08f8b3a31`。
  Linux candidate、完整 Linux 验收及展示站也通过。本地独立短诊断仍未推送、未执行。

- 合并前重新核对 PR 的 23 个检查均成功或按路由跳过，官方 `code_review` 在完整
  `8cd4ccb` 上 completed 且无发现；HEAD 和已核验双父提交的测试合并提交
  `f959d1de5cd796c9c9484f18d0fa1d109495563d` 均具有成功的复审门禁。
  [PR #166](https://github.com/lIlIIlIll/cjdoc/pull/166) 已按主线线性历史规则 rebase 合并，
  精确 main 为 `653457d1aa46ef2939cd10e130d7e1b16fd5d999`，源码树仍为
  `06f7d27491f8952b1df63163dca292d8cb8378d5`。保留四个逻辑提交，未跳过保护检查。
  合并提交的 main CI、0.7.6 tag/Release 和 yjson 最终工具资格继续单独验收，尚不计为通过；
  旧 llc 崩溃未复现，清理修复和本轮通过均不能证明其编译器根因已解决。

- `653457d` 的[主线 CI 40536370055](https://github.com/lIlIIlIll/cjdoc/actions/runs/40536370055)
  与[展示站 40536370204](https://github.com/lIlIIlIll/cjdoc/actions/runs/40536370204)
  首次运行均成功。主 agent 核对完整平台日志、Linux 的 html-a11y 与真实 smoke 阶段，
  又在精确干净 main 上执行真实仓库双次生成和冻结性能硬上限，两项均退出 0，源码身份未变。
  本地预检复用已核验 334 项产品输入相同的 producer，不称另一次本地构建或正式发布。
  新 annotated tag `v0.7.6` 的对象为 `742f292a9b1b0fedd012062b068b5b7f86a9b538`，
  指向精确 main；旧 `v0.7.5` 未移动。源码归档 SHA 为
  `ac116b3fb587505f7ebae93c0b44fd6befa9a61464dbe77af208e31f8125646d`。

- [v0.7.6 首次 Release 40546453166](https://github.com/lIlIIlIll/cjdoc/actions/runs/40546453166)
  失败，未重试。macOS 候选通过；Windows 在首次产品构建的 yjson llc 中以
  `3221225477` 退出，栈为 `MachineRegisterInfo::addRegOperandToUseList`，原日志 SHA 为
  `c1c134c0865e2ac1481cfdbf7f85d0b506a5874ac14494029c4ed1a697ecc1e9`。
  Linux 已通过完整验收与两次真实仓库生成，随后性能门禁的首个 self cold 样本以
  SIGSEGV 退出，唯一运行时栈位于 `MapleRuntime::BaseObject::GetSize`；原日志 SHA 为
  `4b4e1d34da62e6144f1a2d38cc6eecee9339478969d299bd6d7c5cc3c741b485`。
  发布器按保护条件跳过，GitHub API 确认公开 Release 不存在。两类失败不合并归因。

- 主线封存 Linux 候选的 binary SHA 为
  `e6bc2e2529ede407d1b0a9ed00a3c8ef2c51d416270082474e3417852b65c377`，
  与 Release 崩溃日志中的实际 binary 完全相同；源码树、SDK/stdx 指纹也相同。
  主 agent 由就绪标记核验候选 tar 的摘要、大小、run/attempt 与提交，再执行同一 binary、
  同一精确源码、512 MB 堆和固定 CPU 下的 self cold 最小命令：8 MiB 与 128 MiB 栈
  各一次均退出 0，Doc IR 均为 `d16032fd...d8aed7`，输入前后未变。
  原 runner 栈上限没有观测值，此对照没有复现崩溃，不能据此认定栈是根因或扩大资源放行。

- 新诊断提交 `12fd23458d0c84fd3cd959b18c9c792ea1d37bbc` 仅增加三个诊断文件，
  父提交为 `653457d`，已推送到独立 `diag/release076-evidence`，主线与两个失败 tag 未动。
  Windows 从真实 `v0.7.6` workflow 提取并校验原发布 shell，使用原 SDK 归档与完整参数，
  被动保留 IR；仅唯一匹配实际失败完整 argv 时允许原有一次、600 秒后端跟踪。
  Linux 使用主线相同摘要的封存 binary 和原性能门禁；仅在唯一绑定到首个 self cold 的
  SIGSEGV 时追加一次、600 秒 GDB 跟踪，明确区别于原目标。两平台均拒绝第二 attempt。
  只上传经过既有隐私检查的日志和收据，保留三天；原始 IR、未脱敏调试输出与源码不直接公开。
  16 项新回归、199 项冻结捕获库回归、actionlint 和隐私检查通过。超时回归真实启动后代
  进程，验证同一会话内的不同进程组也被终止；最终使用 pidfd 的有界退出通知，消除
  `/proc` 回收与瞬时状态的测试竞态，旧测试失败记录保留。首次原生结果尚待验收。

- [原生诊断 40558132138](https://github.com/lIlIIlIll/cjdoc/actions/runs/40558132138)
  首次完成，两平台原目标均一次退出 0。主 agent 逐字节核验 989 个固定源码 Git blob、
  Windows 的 1994 个冻结依赖文件、10 个控制器模块、20 个候选文件及 17 个 SDK 工具；
  前后身份均相同，Windows 工具向量与此前完整安全回执相同。Windows 原发布 shell
  通过 preflight、build、666 项 native、596 项 Python、CLI 和 provider，四条 wrapper
  记录仍使用既定产品完整参数与单测 O1 例外，后端跟踪为零。
  Linux 使用与失败 Release 相同的 binary 和 runtime，512 MB 堆、实测 16 MiB 栈，
  原性能硬上限通过，GDB 跟踪为零。两份安全收据 SHA 分别为
  `7de412eb62def1c1227b165e22ddbe2b31cf9b26a931e60c326a43834fae8e63` 和
  `42ce954fc806d24a523612400717fbdefaa975d69646469241a9e64c15994d9a`。
  这批没有复现原故障，不能替代失败的 Release，未从成功回执推断编译器或运行时已修复。

- 另一次本地内存压力探针使用同一 Linux binary/runtime、精确源码、固定 CPU、16 MiB 栈，
  只将堆改为 256 MB，并在 GDB 中为原 `BaseObject::GetSize` 元数据读取指令设置条件信号
  观察点。仓颉正常的线程信号继续透传；本次正常退出，Doc IR 仍为 `d16032fd...d8aed7`，
  没有匹配信号、其它调试停止、超时或 core。源码、binary 和 runtime 前后未变。
  探针日志 SHA 为 `55ec2a1abc369eb7470a7535a7ad08fce87fae8e0d71203312024e717e103afd`。
  它只用于定位内存压力边界，不改变正式 512 MB 条件，也不提供发布资格。

## v0.7.6 单次续跑与源码冷构建

- 用户明确允许对正式 Release `40546453166` 执行一次完整 attempt 2，并仅在原有三平台、
  性能及发布门禁全部通过后发布。调用前核对了源码 `653457d` 和 tag object `742f292`；
  不移动 tag，不改 SDK、产品参数或门禁，不自动再次重跑。首次失败和诊断证据保持原样。
- 使用已核对的精确源码归档，两次分别在不存在的缓存目录执行
  `python3 scripts/prepare_cjdoc.py --config <candidate-config> --archive <source-archive> --cache-dir <empty-cache>`。
  归档 SHA-256 为 `ac116b3fb587505f7ebae93c0b44fd6befa9a61464dbe77af208e31f8125646d`，
  私有候选配置 SHA-256 为 `c65e560f88dbe5bff17fea7ef9c5581ac17af3e3b787d4da994cca1c1db4cde7`。
  两次均核验普通 static stdx 摘要 `e62289d5b88af440de04a26a30c79403d024f6accfacfd96607ae409ad9c1df2`，
  各记录一次 `-O2 --fno-chir-function-inlining` 产品构建，退出码均为 0，用时分别为
  401.429 秒、317.037 秒。二进制 SHA-256 分别为
  `faf319e2866a691b5b5f7ff2cd73e366212dea574d208236979e10d48ad1c009` 和
  `a8577e5f52e81892fb7f213475c279e59ce777337027de028067b43838aa0f1d`；
  保留两份收据，不据此声称二进制可重现。
- 资格、准备、生成、源码指南、应用文档检查及示例 runner 六项 Python 回归分别为
  12、10、25、15、28、16 项，共 106 项，全部通过。
- 第一份冷构建已在主仓 `0566f14`、宏 C9 的真实九包上完成 standard lint 和完整生成，
  用时 719.570 秒，退出码 0。459 条应用声明摘要、383 个参数、210 个适用返回值
  均为 100%，应用质量 finding 为零，不支持声明为空；四宏保持源码级静态收集。
  17 页源码指南的 query 和同次 stdio MCP 全文读取通过，资源条件为 2 GB heap、
  Linux 131072 KiB stack，读取收据 SHA-256 为
  `844f0851a989a283ef0ad60cbe77b0c19203e5fab44421fadd0dd55a8169a5c9`。
  这批使用私有候选配置；生成时主仓配置仍为 candidate，未执行这批的消费方示例，
  不将它算作公开发布、最终源码示例或托管验收。
- 经明确授权的 [Release attempt 2](https://github.com/lIlIIlIll/cjdoc/actions/runs/40546453166/attempts/2)
  三平台及发布器全部通过；[公开 v0.7.6 Release](https://github.com/lIlIIlIll/cjdoc/releases/tag/v0.7.6)
  已生成。主 agent 下载并独立核验全部 12 项资产、GitHub 摘要、六份校验文件、三份包清单、
  精确源码 payload 和独立可执行文件与包内二进制的一致性。
  公开 Linux 二进制摘要仍为首次失败时的 `e6bc2e2529ede407d1b0a9ed00a3c8ef2c51d416270082474e3417852b65c377`；
  本次未改变 SDK、参数、源码或门禁。各平台资产摘要见[候选证据](../../release/0.2.0/evidence.md)。
  主仓工具配置现已采用上述两次冷构建使用的精确配置，SHA-256 不变，状态为 qualified。

## 最终源码交付闭包修正

- 对主仓 `9b14777` 的 Git tree `e3c76191e4bb0bdd240d22f91a1cf863973af418`
  建立干净验证提交 `a3742db`，逐项核对 1987 个主仓文件和 26 个宏仓文件的原始 Git blob
  与执行权限。两者源码树相同，提交身份不同；不将验证提交冒充主仓提交。
- `release_temp_tree.py --enforce-clean` 通过，随后默认完整
  `scripts/ci_fresh_checkout.sh` 在 API 文档的 Python 回归退出 1：
  `test_real_downloadable_source_closure_keeps_licenses` 找不到
  `packages/yjson_macros/LICENSE`。此前 API 清单与实际 cjdoc 源码资格构建通过；
  最终 333 条消费方示例尚未执行。失败日志 SHA-256 为
  `8a055f06dea9830895f1aabc0cf2934447eba3397b0735bf7ed392ad012d07f2`。
- 发布暂存清单现收录宏包许可证；闭包检查同时要求每个已收录包中实际存在的 `LICENSE`。
  新回归先出现 `ValueError not raised`，修复后单项、全部 15 项暂存回归、6 项源码暂存
  回归和 API 清单检查通过。另用真实暂存树重放原失败用例，退出 0；该树未强制干净，
  只用于回归，不作为正式候选。暂存宏许可证 SHA-256 为
  `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`。
- 同一干净验证提交的 `bash scripts/ci_job.sh perf-evidence-drift strict` 退出 0，
  包含 40 项回归及完整身份、摘要、校验和与结果检查。日志 SHA-256 为
  `6ccf5a8643a8d4ad209f0093bc78078e3424a0ce9e49e36055bd311f836f5665`。
  许可证修复后产品与 harness 输入摘要仍分别为
  `eb31d8ab82a5ed9149fc1fbf2955f7b9f6796acf4af1ab612fb03a1d6f446e99` 和
  `230ccd61c2dd5bc85de33db9f2f27745c0f95e6fe7512bf8a1427a7b35cc2904`；
  这项修复不改变测量输入。
- 最终 ZIP 生成前重新读取 `consumer-sources/` 和 `examples/`：冻结源码必须与记录的文件
  集合和原始字节一致；示例只允许索引页及按声明和示例序号确定的 `.cj`、`.toml`。
  每份正文和清单必须对应实际执行输入，拒绝新增、缺失、改写、非规范路径、符号链接及
  非普通文件。清单生成与核对共用一个模板，显式传入实际依赖优化选项并使用 LF；
  正式交付仍要求普通 O2，不依赖检查进程的环境猜测选项。
  原修复前 19 个边界子场景及新增文件的 4 个子场景均真实失败，修复后通过。
  主 agent 独立重跑文档检查、runner、生成器及源码指南四组回归，共 100 项通过；
  发布暂存 15 项、源码暂存 6 项、API 清单、Markdown 链接与隐私检查也通过。
  这些回归只证明交付校验行为，尚不证明最终 333 条示例已经执行。

## 正式工具的最终本地验证

- 主仓候选 `afd4e0b0017214678d0cd8287a1fc7f40e9ba22a` 与干净验证提交
  `e9151825008b4374ba3aa881e268299273b3a625` 的 Git tree 均为
  `23703cd61bc9dc3c5fab04e3113159dca96e0c14`。再次逐项核对主仓 1987 个 blob、宏仓
  26 个 blob 和执行权限；`release_temp_tree.py --enforce-clean` 收录 372 个文件并通过。
- 默认完整 `scripts/ci_fresh_checkout.sh` 使用 STS `1.2.0`、动态 stdx 和显式普通 O2。
  API 清单、cjdoc 源码资格、真实九包生成、Linux 333/333 消费方、最终文档检查、
  runtime-freeze 和核心 587/587 通过。标准语料下载在返回 HTTP 响应前断连，整轮退出 1；
  保留失败日志，SHA-256 为
  `e63cc18a26cb9741c450e90619a509a5bfeb2671683e2fab4bd65b1fa3369a01`。
  不把这次默认整轮运行记为通过。
- 最终生成输入摘要为
  `044ed6bd7325fb659a56920575990f66938e5933ff6652b44a030dc817294c32`；
  工具二进制摘要为 `2070020efb4af6e4363626323816685422a344ab07a89a299cb883e3e5031951`，
  工具来源、SDK 和 `-O2 --fno-chir-function-inlining` 策略通过资格检查。
  应用注释和示例覆盖率全部为 100%，原生 standard lint 的应用 finding 为零。
  执行记录 SHA-256 为 `341f5a1ff3ed5234a8d7810dfe18c485eeb3d9364fd2a3bd01e70ebc6f30a9aa`；
  最终覆盖报告 SHA-256 为 `b3a636fc901ede97946701e4ae831719bf7fecc7796d898e0efcbfd9d59ef9e7`。
- 三个固定官方语料归档随后分别下载并通过原有 SHA-256 校验。使用 runner 已有的
  `--cache <disk-cache> --offline --override-compile-option=-O2` 完成标准集 2110/2110、
  含可选格式集 3074/3074；schema-formats 包测试也通过。固定提交、语料基数和断言不变。
  标准集日志 SHA-256 为 `03612e3fed0a3844e405ff4a1e2bc858719ff614ec9418f22cc9739b14420c9b`，
  含可选格式集为 `1bc5c84744105befc149e18dd36d633b2056f64a75f4bac68773bdcd1c211f5e`。
- 同一干净验证提交继续通过 examples、macro-consumer、algorithms-consumer、
  registry-rehearsal、custom-native、yyjson-native、native-clang、native-gcc 和 sanitizer。
  下一项 fuzz-short 已启动后，私有日志收集器因非 UTF-8 字节退出，未取得该次 fuzz 退出码；
  保留异常记录。改为原始字节收集后，单独执行规范 fuzz-short，5000 个语义差分样本通过，
  退出 0，日志 SHA-256 为 `7759501e1c82e8d14b4f6dd59ed701c50e4c9c5bcc938d7c9f60a281782c7d6b`。
  未改产品源码、样本数或门禁断言。
- 完整本地离线 ZIP 为 15,276,038 字节，SHA-256 为
  `55882577456a7d885e08c7e145db699db15e17d135e04652b14447632e646c23`。
  解压核对 5330 个文件与已验收站点逐字节相同；在只有 loopback、无路由的独立网络
  命名空间执行 18 次 query 和同次 stdio MCP，17 页源码指南全文一致，全部解压输入未变。
  读取使用第二份独立冷构建，二进制 `a8577e5f`，与生成器二进制身份分别记录。
  离线读取收据 SHA-256 为 `7d092b15a78920464935f5bd038fefbea7ee5e426a16e6ec2a30f7510b8c53ce`。
  另从包内原始源码和清单，为全部 11 个 profile 各创建一个无 target 的独立项目，
  断网编译运行全部通过；收据 SHA-256 为
  `2974c83005b57e9d99cb6d34b4b8d796fd61c2dbe70046cd0ea146175b9aad39`。
  这是本地正式包验收，尚不表示托管下载或线上 Pages 已验证。

## 主仓 PR 与外部 codec 契约

- [主仓 PR #12](https://github.com/lIlIIlIll/yjson/pull/12) 已建立为 Draft，首次 HEAD 为
  `292967ceed73aabac1794a17210c2aee5892cc4c`，首次托管运行 `40660261262`。
  `Generated code change risk` 首先失败；本地相同 base/HEAD 也退出 1。
  `lib_json_direct_codec.cj` 的变化只有源码注释，但现有保守路径规则仍要求新增外部
  `_test.cj` 的行为断言。原有消费方通过，不能替代这项 diff 要求；保留原失败，不放宽规则。
- `api_documentation_contract_test.cj` 新增手写 `JsonCodec` 的公开 reader/writer 契约测试：
  字符串、UTF-8 字节和流读取一致；写出使用独立字面量 oracle；null 保留，字面及转义
  Unicode 都按解码后的 UTF-8 字节数执行读取预算，超限保留错误码和位置信息。
  STS `1.2.0`、O2 依赖下，完整 `macro-consumer` 的 40 项、实际可执行消费方及暂存宏
  消费方全部通过。此处使用明确标记 `clean_enforced=false` 的回归副本，不冒充干净候选。
  日志 SHA-256 为 `5e7153d63887a139607b3c34370a8e5f548eec444d432c5f7112582678f90233`。
  新测试提交的完整生成代码风险门禁通过：改变文件 196 个，其中风险文件 1 个。
- 这项补测不改变产品、文档生成或测量输入；三项输入摘要分别仍为
  `eb31d8ab82a5ed9149fc1fbf2955f7b9f6796acf4af1ab612fb03a1d6f446e99`、
  `044ed6bd7325fb659a56920575990f66938e5933ff6652b44a030dc817294c32` 和
  `230ccd61c2dd5bc85de33db9f2f27745c0f95e6fe7512bf8a1427a7b35cc2904`。
  既有最终本地 333 条示例、离线包和严格性能结果按输入字节等价复用，托管最新 HEAD 仍须通过。

## 当前续接

完整任务未完成。经用户确认，Windows llc 崩溃和 Linux 运行时崩溃暂按偶发工具链故障
分别记录，根因未定。首次失败、后续固定源码诊断和资源对照未复现的结果均保留；现有证据
不能证明两者具有共同根因，也不能确定具体 SDK 缺陷。

原 Windows 失败 IR 和 Linux 故障 core／寄存器现场未归档，托管 runner 已结束，
因此故障定位仍有证据缺口。偶发分类不增加必须先修复 SDK 的验收条件，也不代表故障已修复。
当前未修改或构建 SDK。

正式 Release 和工具源码资格已通过，`release/cjdoc-tool.toml` 已冻结为 qualified。
最终源码的正式工具生成、Linux 333 条示例、本地完整 ZIP 的断网 query/MCP 与 11 个 profile
重建已经通过。后续完成 Windows/macOS 各 285 条适用示例（各 48 条不适用）、托管下载包、
主仓候选 PR 和最终 main Pages 浏览器验收。既有开发批、最终本地批和托管结果分别记录，
不把尚未执行的维度标为通过。

## 跨仓库源码链接

Doc IR v16 只有项目级 repository，不能为独立宏仓表达第二组 repository/revision。
统一 workspace 不填写一个会误指宏源码的全局仓库。生成前构造标准源码指南，按模块记录
主仓库与宏仓的真实提交，并提供逐声明源码链接；指南由 cjdoc 正常纳入 HTML、Markdown
和 Agent 资源摘要。保留 v16 的 `source.path`、位置和模块信息，不改写生成后的机器产物，
也不把自动 symbol source URL 宣称为已支持。最终验收应实际核对两仓源码链接。
