# yjson 文档

第一次使用 yjson，从项目 [README 的快速开始](../README.md#快速开始)运行一个
`@JsonCodec` 示例。已有项目需要接入时，先看 [API 选择指南](choosing-an-api.md)。

当前文档面向九包 `0.2.0` 候选，产品、宏、示例和文档工具统一使用 Cangjie STS `1.2.0`。
候选不代表已发布；实现、工具资格、示例、CI 与 Pages 的实际结果见
[候选实施记录](implementation/cjdoc-020.md)。

接收外部输入前，请检查[资源限制](resource-limits.md)，并按 `JsonException.code`
处理 JSON 错误。完整示例见 [`packages/examples`](../packages/examples/README.md)。

当前版本的升级步骤见 [0.1.x → 0.2.0 迁移说明](migration/0.1-to-0.2.md)。

## 常用任务

| 任务 | 文档 |
| --- | --- |
| 为 class、struct、enum 生成 codec | [`@JsonCodec` 生成指南](codec-generation.md) |
| 在源码中构造 JSON literal | [`@Json` expression macro](choosing-an-api.md#按需求选择) |
| 编写自定义编解码器 | [自定义 Codec](custom-codecs.md) |
| 解析、修改或只读查询 JSON | [AST 与只读 Document](ast-and-compact.md) |
| 通过流读写 JSON | [Stream I/O](streams.md) |
| 启用原生加速或使用可选后端 | [Backend 使用指南](backends.md) |
| 设置读写策略并处理错误 | [配置与错误](configuration-and-errors.md) |
| 限制输入、输出和算法工作量 | [资源限制](resource-limits.md) |
| 校验 JSON Schema draft 2020-12 | [JSON Schema](schema.md) |
| 使用 Pointer、Path 或 Patch | [JSON Pointer、JSONPath 与 Patch](path-and-patch.md) |

## API 参考

API 参考从九包发布图和源码注释生成。候选要求统一搜索、指南导航和跨包链接，并交付
HTML、Markdown、Doc IR v16、质量报告与完整 Agent 离线包。生成前启用 STS `1.2.0`
及匹配的 stdx，在磁盘上创建任务目录：

```terminal
install -d -m 0700 "$HOME/.cache/agent-tmp"
findmnt -T "$HOME/.cache/agent-tmp"
df -h "$HOME/.cache/agent-tmp"
doc_task=$(mktemp -d -p "$HOME/.cache/agent-tmp" yjson-docs.XXXXXX)
export TMPDIR="$doc_task" TMP="$doc_task" TEMP="$doc_task"
scripts/codex_cangjie_env python3 scripts/validate_cangjie_sts.py --check-installed
cjdoc_path=$(scripts/codex_cangjie_env python3 scripts/prepare_cjdoc.py \
  --cache-dir "$doc_task/cjdoc")
scripts/codex_cangjie_env python3 scripts/generate_api_docs.py \
  --cjdoc "$cjdoc_path" \
  --output "$doc_task/site"
scripts/codex_cangjie_env python3 scripts/run_api_doc_examples.py "$doc_task/site"
python3 scripts/check_api_documentation.py "$doc_task/site"
```

`--output` 指定的目录必须不存在。脚本会校验工具来源、版本和校验和，再检查生成结果中的
包信息、Doc IR 格式、错误和不支持的声明。随后执行真实消费方示例，完整检查通过后生成
离线下载包。站点入口为输出根部的 `index.html`。
CI 上传通过检查的文档，合并到 `main` 且全部必需门禁通过后才部署 GitHub Pages。

文档工具固定为 cjdoc `0.7.7`；精确源码、SDK 和构建策略见[工具配置](../release/cjdoc-tool.toml)，
资格与交付结果见[候选实施记录](implementation/cjdoc-020.md)。
`0.2.0` 保留四个应用宏：`@Json`、`@JsonCodec`、`@JsonUsing` 和 `@JsonSubtype`。
`@JsonValue` 已批准删除，旧调用迁到 `@Json`。字段上的 `@JsonAlias` 读取别名保留。

宏文档静态收集声明、参数、返回类型和注释，恢复 `@Derive` 包裹的源码声明，保留未展开状态。
这项文档处理不执行宏，也不推测生成成员；无法处理的结构仍须明确报告。
精确签名见[API 快照](../release/public-api-snapshot.txt)，解析限制记录在
[`release/cjdoc-policy.toml`](../release/cjdoc-policy.toml)。最终结果以实际生成与检查为准。

八个应用包要求完整中文契约和逐入口可执行示例；内部接口按职责分类。
注释规则、覆盖率验收、离线 `query` 与 stdio MCP 验证见
[API 文档维护指南](maintainers/api-documentation.md)。新站点不为旧 URL、旧 Doc IR 或旧产物布局
建立兼容层。

## 选型与版本

- [库能力对比](library-comparison.md)：比较接口能力和使用限制。
- [性能文档](performance/README.md)：方法、原始结果和适用边界。
- [公开 API 清单](public-api-inventory.md)：九包当前声明与评审变化。
- [Release notes](../RELEASE_NOTES.md)和 [Changelog](../CHANGELOG.md)：用户可见变化。

整个 `0.x` 阶段不保证 patch 或 minor 之间的源码、API、ABI、生成代码或旧 SDK 兼容。
升级时同步第一方依赖，重新展开宏并编译消费方。历史发布与测量记录保留备查，只适用于
各自记录的版本和环境。

## 维护者入口

- [架构与包依赖](architecture.md)
- [仓库布局与发布文件](maintainers/repository-layout.md)
- [测试、标准套件与 CI](maintainers/testing.md)
- [Native 后端实现](maintainers/native-internals.md)
- [发布流程](maintainers/releasing.md)
- [公开 API 与 ABI 变化清单](public-api-inventory.md)

`release/` 保存候选清单和一次性证据；`docs/performance/results/` 保存带日期的测量结果；
`docs/archive/` 保存已经归档的计划。
