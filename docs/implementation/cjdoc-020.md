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
- cjdoc 以 `0.7.4` 为基线增加源码级宏文档支持，候选正式版为 `0.7.5`。
- 本次包含 cjdoc 发布和 yjson Pages 上线，不发布 yjson 九包或创建其 tag。
- Pure 基线在 STS `1.2.0` 迁移完成、历史适配清理前冻结；本次不证明跨 SDK 性能变化。

## 需求与验收

| ID | 来源条款 | 类别 | 可观察结果 | 实现与入口 | 验证方法及实际结果 | 适用版本 | 状态 | 剩余缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SDK | 统一 STS 1.2.0 | 必需 | 全部产品门禁使用真实 STS 1.2.0 与匹配 stdx | CI、SDK 解析器、开发和发布清单 | 官方 SDK、匹配 stdx、动态与静态环境及实际版本检查通过；核心 583/583 通过；托管矩阵待运行 | 0.2.0 候选 | 部分实现 | 接线、编译、运行与平台证据 |
| POLICY | 撤销旧兼容保证 | 必需 | 当前政策不再承诺跨版本兼容，历史事实仍可查 | 活跃文档、源码注释、机器清单 | 当前政策与清单已同步；真实九包清单、37 个清单回归及 8 个快照回归通过；历史记录保留 | 0.2.0 候选 | 部分实现 | 最终政策扫描与托管检查 |
| CLEANUP | 已批准的适配清理 | 必需 | 四个公开宏；内部包装删除且原行为仍通过 | 宏仓、核心、外部消费方 | 宏 PR #9 已合并，实际 Git pin 下核心 O2 583/583；宏消费方 11/11、四宏示例、旧宏拒绝和同名自定义类型通过；无参 struct 缺陷已修复并补回归 | 0.2.0 候选 | 部分实现 | 最终候选托管验收 |
| CJDOC | 源码级宏支持 | 必需 | 宏签名及被包装声明具有真实注释和导航 | cjdoc AST、绑定、缓存及输出 | STS 1.2.0 AST 编译运行探针通过；源码宏 CLI 生成已验证，完整上游门禁待运行 | cjdoc 0.7.5 候选 | 部分实现 | 完整上游验收与发布 |
| COMMENTS | 应用注释补全 | 必需 | 全部范围内声明具有实际绑定的中文契约 | 八个应用包 | 开发 Doc IR 绑定检查通过：459 条应用声明摘要、383 个参数、210 个适用返回值；尚非正式工具资格结果 | 0.2.0 候选 | 部分实现 | 正式工具与最终源码重验 |
| EXAMPLES | 逐入口示例 | 必需 | 每个入口或重载组可独立编译运行并断言结果 | 注释示例、隔离消费方 | STS 1.2.0 O2：核心视图 131/131、算法与后端 74/74、审阅后核心 codec 87/87、Native 同份 Doc IR 示例 39/39；全量提取 335 个示例待统一执行 | 0.2.0 候选 | 部分实现 | 正式 Doc IR 与全量结果 |
| SITE | 统一 workspace | 必需 | 九包共用搜索、指南、交叉链接和 Agent 索引 | 发布图派生的文档 workspace | 开发工具九包 workspace 已生成 Doc IR v16、HTML、Markdown、质量报告及 Agent-full；未替代正式工具资格 | 0.2.0 候选 | 部分实现 | 正式工具冻结、最终源码生成与全站检查 |
| AGENT | 离线 Agent 包 | 必需 | 下载后离线 query 与 stdio MCP 可查询真实文档 | 完整生成站点 | 普通 O2 的真实 query/MCP 崩溃；同源 O2 关闭 CHIR 内联后，完整开发包的 query/MCP 独立通过 | cjdoc 0.7.5 候选 | 部分实现 | 最终正式工具与下载产物离线验收 |
| PERFORMANCE | 正式重新测量 | 必需 | 同 SDK Pure 24 用例及七库两批完整证据通过 strict | 冻结测量源码与正式运行器 | 用户已明确批准上传并测量；Server 核对 1958 个生产文件及两份各 200 文件的 Git 快照通过，正式运行尚待完成 | 冻结候选 0e1753c | 部分实现 | 真实编译参数、528 个 Pure 样本与两批各 770 单元 |
| PLATFORMS | 平台与真实边界 | 必需 | Linux 全部适用示例、Windows/macOS Pure 通过 | CI、Native 链接和外部消费方 | 待最终代码托管矩阵 | 最终冻结候选 | 未实现 | 全部托管证据 |
| DELIVERY | PR 与 Pages | 必需 | 上游发布、宏合并和最终 main 站点可核对 | 各独立仓库与 Pages | 宏 PR #9 已合并并固定真实提交；cjdoc 发布、主仓库 PR 与 Pages 尚未完成 | 最终提交 | 部分实现 | 上游发布、主仓库与线上验收 |

## 验证规则

每项结果记录实际命令、源码或产物身份、SDK、退出码、日志与未运行范围。
本地编译、消费方运行、托管 CI、性能资格和线上部署分别验收，不能相互替代。
历史发布记录及测量失败保持原样；新候选不得复用旧 SDK 的通过结论。

## 开发验证记录

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

## 跨仓库源码链接

Doc IR v16 只有项目级 repository，不能为独立宏仓表达第二组 repository/revision。
统一 workspace 不填写一个会误指宏源码的全局仓库。生成前构造标准源码指南，按模块记录
主仓库与宏仓的真实提交，并提供逐声明源码链接；指南由 cjdoc 正常纳入 HTML、Markdown
和 Agent 资源摘要。保留 v16 的 `source.path`、位置和模块信息，不改写生成后的机器产物，
也不把自动 symbol source URL 宣称为已支持。最终验收应实际核对两仓源码链接。
