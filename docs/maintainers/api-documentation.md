# API 文档注释与 CI

API 站点由固定版本的 cjdoc 从发布包图生成。版本和源码校验和见
[`release/cjdoc-tool.toml`](../../release/cjdoc-tool.toml)，解析限制见
[`release/cjdoc-policy.toml`](../../release/cjdoc-policy.toml)。不要用系统中恰好安装的
其他 cjdoc 版本替换这条构建链。产品、宏、示例和文档工具统一使用 STS `1.2.0`。

`0.2.0` 文档候选固定使用 cjdoc `0.7.6`。工具资格、真实生成、平台示例和 Pages 的实际结果
统一记录在[候选实施记录](../implementation/cjdoc-020.md)。

## 写能够进入页面的注释

文档注释放在声明前；带注解的类型应放在注解前。当前固定的 cjdoc 使用
`/** ... */`。普通 `//` 注释和历史 `///` 注释不能代替可绑定的 API 文档注释。
第一段说明行为，后续段落说明约束、所有权和错误；参数使用 `@param`，非 `Unit`
函数使用 `@return`，异常使用 `@throws`。
逐入口示例放在 `@example`，声明需要执行的例子使用 `{run}`，并标明实际依赖的 profile。
示例应断言正常结果；错误示例单独验证错误码或失败行为。

```cangjie
/**
 * 返回调用方指定的节点数预算。
 *
 * @param maxNodes 必须为正数的节点数预算。
 * @return 原样返回的节点数预算。
 * @throws IllegalArgumentException 预算不为正数。
 */
public func checkedBudget(maxNodes: Int64): Int64 {
    if (maxNodes <= 0) { throw IllegalArgumentException("maxNodes must be positive") }
    maxNodes
}
```

注释应描述实际实现，不以函数名的同义改写充数。重载分别说明字符串、UTF-8 字节、
调用方流和显式 codec 的区别。流不会被库关闭，但失败的输出操作可能已经写入部分
内容。只读视图不等于底层可变节点的不可变快照。内部算法注释仍应解释不变量、
边界和取舍，不必全部作为 API 文档暴露。

## 生成与验证

从仓库根目录执行。先启用 STS `1.2.0` 和匹配的 stdx，再检查版本：

```bash
python3 scripts/validate_cangjie_sts.py --check-installed
python3 scripts/test_check_api_documentation.py
python3 scripts/test_generate_api_docs.py
python3 scripts/test_api_doc_source_guide.py
python3 scripts/test_run_api_doc_examples.py
```

生成文档会编译工具并写入产物。使用磁盘临时目录，并确认空间足够：

```bash
install -d -m 0700 "$HOME/.cache/agent-tmp"
findmnt -T "$HOME/.cache/agent-tmp"
df -h "$HOME/.cache/agent-tmp"
doc_task=$(mktemp -d -p "$HOME/.cache/agent-tmp" yjson-docs.XXXXXX)
export TMPDIR="$doc_task" TMP="$doc_task" TEMP="$doc_task"
cjdoc_path=$(scripts/codex_cangjie_env python3 scripts/prepare_cjdoc.py \
  --cache-dir "$doc_task/cjdoc")
scripts/codex_cangjie_env python3 scripts/generate_api_docs.py \
  --cjdoc "$cjdoc_path" \
  --output "$doc_task/site"
scripts/codex_cangjie_env python3 scripts/run_api_doc_examples.py "$doc_task/site"
python3 scripts/check_api_documentation.py "$doc_task/site"
```

目标 `site` 必须不存在。检查命令成功后，从生成目录根部的 `index.html` 打开统一站点。
重跑时另建任务目录，不覆盖已有结果。保留诊断所需失败日志，清理时只删除本次创建的任务目录。

三步分别完成生成、真实消费方执行、完整检查与离线打包。只运行生成命令不会得到已经
验收的示例或最终下载包。工具资格核对实际源码、SDK、静态 stdx、完整构建参数和产物摘要；
cjdoc 产品参数为 `-O2 --fno-chir-function-inlining`，其单测另有 O1 例外。
该例外不用于 yjson 或对比库的性能构建，不能把 cjdoc 的结果写成普通 O2 通过。

## 候选产物与注释覆盖

生成器从发布图构造九包 workspace。统一站点要求跨包搜索、指南与 API 双向链接，并生成
HTML、Markdown、Doc IR v16、质量报告和 `--agent-full` 完整离线包。新产物不适配旧 URL、
旧 Doc IR 或旧目录布局。当前工具消费方应同步更新。

| 产物路径 | 用途 |
| --- | --- |
| `index.html` | yjson 入口、源码索引、示例和下载导航 |
| `html/index.html` | cjdoc 统一 API 参考与指南 |
| `docs.json`、`markdown/`、`coverage/` | 完整站点的 Doc IR v16、Markdown 和展示报告 |
| `quality-standard/`、`standard-quality-evidence.json`、`quality-inputs/` | 原生 standard lint 完整诊断、质量报告及同源绑定证据 |
| `html/agent/manifest.json` | 完整站点的离线 query 与 stdio MCP 入口 |
| `examples/`、`example-execution.json`、`example-mapping.json` | 逐入口消费方源码、依赖清单、实际执行和重载对应记录 |
| `consumer-sources/` | 固定的产品、宏、Native 构建输入、profile 和许可证，不包含旧 target |
| `downloads/yjson-api-docs-offline.zip` | 完整检查通过后生成的离线包，附 SHA-256 文件 |

Doc IR v16 只有项目级仓库字段，不能为统一 workspace 同时表达主仓与独立宏仓。
生成器先收集真实声明位置，再生成普通源码指南，最后由 cjdoc 正常生成所有投影。
`html/concepts/guides/api-source-index.html` 提供逐声明、精确提交和行号的两仓链接；
机器 Doc IR 保留源码路径、位置和模块，不提供误指仓库的自动 source URL。
不得事后替换生成的 JSON、HTML、Markdown 或所有权摘要来修补链接。
逐声明源码指南按完整声明分页，每页最多 32 KiB；分页不能省略声明或截断签名。

已注册指南之间的链接保留为站内导航。README 和指南中指向发布记录、维护文档等
未收录材料的仓库相对链接，在生成前转换为对应仓库精确提交的 HTTPS 链接；宏仓材料
使用独立宏仓的提交。生成器先核对目标属于固定源码，再使用冻结的链接目录转换
workspace Markdown，生成后检查 HTML 中的本地文件链接。
这些补充材料需要联网访问；成为外链目标不会使其正文额外进入生成或编译输入。
已有许可证和发布清单仍按原闭包保留。离线包完整保留已注册指南、API、源码索引、
消费方源码和示例；不要把仓库外链描述为离线资源。

质量检查保留两次未经改写的 cjdoc 输出。第一次使用默认 standard lint 收集完整诊断；
第二次加入源码指南，保留 standard 标签绑定，并在展示配置中关闭重复的诊断输出，
以遵守 Doc IR 对象预算。检查器比较两份输出中全部声明的身份、签名、源码位置、
注释和参数，只排除可选语法高亮字段，再校验原生质量报告和配置的摘要。
应用注释门禁消费 `quality-standard/coverage/quality.json`，不能以展示报告代替完整质量报告。
内部接口的未完成注释仍进入原生诊断，不计入应用包 100% 注释覆盖的分母。

八个应用包为 `yjson`、`yjson_macros`、`yjson_algorithms`、`yjson_backends`、
`yjson_native_accel`、`yjson_native`、`yjson_yyjson` 和 `yjson_schema_formats`。
`yjson_native_primitives` 的第一方内部接口仍进入站点并明确分类，不计入应用注释目标。
生成代码 SPI 和 C ABI 也按用途分类，不作为普通应用入口。

[`release/api-documentation-required.json`](../../release/api-documentation-required.json)
与生成结果共同约束必需声明。应用范围的摘要、参数、适用返回值和示例覆盖要求为 100%，
必须按实际 AST 与 Doc IR 核对，不能只统计源码里的注释符号：

- 收录重载、隐式接口成员、构造器、属性、运算符、枚举项和适用的 protected 成员；继承项按来源去重。
- 说明实际行为、参数、返回值，以及适用的错误、预算、所有权、流处理和资源生命周期。
- 每个可调用入口或语义相同的重载组绑定可执行示例；共用示例实际调用全部标记覆盖的重载。
- 从 Doc IR 提取 `@example` 的同一份正文，按明确的依赖、导入和平台配置构造外部消费方。
  页面代码、预期输出和执行记录必须对应同一示例，不能另写一份只供测试的替代代码。
- 校验文档标签的实际绑定、声明完整性与执行结果。失败或未执行的例子不能记为覆盖通过。

Linux 验证全部适用示例和真实 Native 链接；Windows/macOS 验证 Pure 示例。
进程级加速初始化示例分别在独立进程运行。下载 Agent 包后，还要断网执行真实 `query`
和 stdio MCP 查询，检查跨包检索与指南链接；包内使用说明记录已验证的启动命令。

runner 从同份 Doc IR 与冻结源码构建消费方，记录 profile、prelude、实际依赖产物、
SDK、退出码和输出。每个例子结束后保存记录；编译失败、超时或中断不能留下全量通过状态。
负例必须在自己的示例源码中产生所要求的编译错误，依赖编译失败不能替代负例通过。
离线包中的消费方清单使用 `<modules>` 和 `<project>` 占位符；分别替换为
`consumer-sources` 中对应的包目录和独立消费方目录后编译，不复用下载前的构建缓存。

从完整离线包解压后的根目录启动查询：

```bash
export cjHeapSize=2GB
ulimit -s 131072
cjdoc query --snapshot html/agent/manifest.json --request offline-search-request.json
cjdoc mcp --snapshot html/agent/manifest.json
```

上述 stack 设置适用于 Linux。使用工具资格中记录的 cjdoc 版本，以及包内
`offline-usage.txt` 和生成清单记录的资源条件。完整候选包的实际读取验证使用 2 GB 堆，
逐页检查源码指南全文和 stdio MCP 响应；默认堆下的 OOM 和崩溃不记为通过。
最后一条命令通过 stdio 等待 MCP 客户端请求。不要只复制 manifest，查询需要包内列出的
实际文档资源。`agent-reading-check.json` 保留真实命令、请求、响应和输入未变检查。

静态收集宏的签名、参数、返回类型和注释，保留未展开状态。不执行宏，也不推测生成成员。
无法处理的结构明确报告；不得通过隐藏声明或放宽清单检查制造通过结果。

## CI 产物与发布

现有 `API Documentation` job 在 PR、主分支和开发分支构建中运行共享生成命令。
每次成功生成并通过注释门禁后，上传
`yjson-api-docs-<run-id>-<run-attempt>` 普通 Actions artifact，配置保留 30 天；
最终保留时长仍受仓库与组织策略约束。构建不依赖 PR 拥有 Pages 部署权限。

Windows/macOS 的 Pure 示例 job 下载同次 Linux 生成的文档 artifact，执行完整应用清单中
适用于该平台的例子，明确记录 Linux-only 条目不适用。各平台记录自己的实际 STS `1.2.0`
工具链摘要，不复用 Linux 可执行文件或 SDK 摘要。零条执行或 profile 名称错误不能通过。

Pages 专用 artifact 只在 `main` 的 push 构建上传。正式部署继续要求
`api-docs` 与 `ci-required` 成功，并验证部署提交仍为 `main` HEAD。
PR 文档构建成功不表示已发布上线，也不替代其他质量门禁。

只修改注释也应运行贡献指南要求的 API 清单和源码暂存测试；更改生成链时还必须
完成真实的九包生成。不要将 `target/api-docs` 或临时生成脚本提交到源码仓库。
