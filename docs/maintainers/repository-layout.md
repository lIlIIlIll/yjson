# 仓库布局与发布文件

源码仓库发布为九个包。运行时关系见[架构说明](../architecture.md)。

## 目录职责

| 路径 | 职责 | 发布行为 |
| --- | --- | --- |
| `src/lib_*.cj` | Pure 运行时、公开 API、生成代码接口 | `yjson` 源码目录 |
| `src/*_test.cj` | 根包白盒测试和接口约定测试 | 由 cjpm 执行测试；不参与普通构建 |
| `packages/yjson_macros` | `yjson_macros` 独立仓库的 Git submodule | 独立仓库发布，主仓库保留构建镜像 |
| `packages/yjson_algorithms` | Pointer、Patch、Path、Schema | 可选包 |
| `packages/yjson_backends` | 后端元数据和资源接口 | 高级接口包 |
| `packages/yjson_native_primitives` | 扫描器静态库和第一方 provider 接口 | 第一方内部包 |
| `packages/yjson_native_accel` | 普通 `YJson` 的一次性 Native 初始化 | 可选包 |
| `packages/yjson_native` | Custom Native 命名入口 | 可选包 |
| `packages/yjson_yyjson` | yyjson 命名入口、内置源码及构建脚本 | 可选包 |
| `packages/yjson_schema_formats` | 国际化格式扩展 | 可选包 |
| `packages/*integration*` | 模拟外部使用方的测试 | 仅供仓库使用 |
| `packages/*benchmarks*` | 基准测试程序 | 仅供仓库使用 |
| `native/` | 扫描器、无状态写出原语、DOM 适配器和 C 测试 | 按发布图复制到 Native 暂存目录 |
| `release/` | 发布图、API 快照、cjdoc 配置、清单 | 发布工具 |
| `scripts/` | CI、覆盖率、暂存、验证 | 发布工具 |

## 包内职责边界

| 文件 | 职责 |
| --- | --- |
| `packages/yjson_algorithms/src/json_value_semantics.cj` | Patch 与 Schema 共用的 JSON 等价语义 |
| `packages/yjson_algorithms/src/json_schema_compilation.cj` | Schema 构造期的引用解析与正则编译 |
| `packages/yjson_algorithms/src/json_schema_core_formats.cj` | 内建 Schema format 校验 |
| `packages/yjson_algorithms/src/json_path_filter.cj` | JSONPath filter 的解析与求值 |
| `native/yjson_writer_format.c` | 字符串转义和整数写出的无状态 C 原语 |
| `scripts/benchmark_input_identity.py` | 实际性能输入的文件清单与摘要 |

这些内部文件不增加应用入口。算法继续通过 `JsonValueView` 工作；C 写出原语不管理
仓颉写入器的容器状态与预算。性能 runner 和严格证据校验器共用同一份输入身份规则。

## 开发清单与发布清单

根清单只在 `[test-dependencies]` 中依赖 `yjson_macros` 的独立 Git module。普通 `cjpm build`
构建核心包；`cjpm test` 才加入测试所需的宏依赖。发布暂存使用
`scripts/release_package_stage.py` 复制发布图中声明的源码目录，再换入使用统一版本号的
发布清单。

`release/release-files.txt` 是新候选副本的文件清单。对每个收录的 cjpm 项目，
`release_temp_tree.py` 要求全部 `.cj` 源码、依赖锁定文件和构建钩子完整存在，防止文件名或
手写清单遗漏测试、测试数据或产品源码。

所有 cjpm 测试文件统一使用 `*_test.cj` 后缀。cjpm 和 cjdoc 都依赖这条约定排除测试声明；
不要使用 `test_*.cj` 前缀替代。

## 生成代码

仓库不单独构建或提交生成的 codec。所有 `@JsonCodec` 在声明所在包展开。根测试中生成的类型来自 `*_test.cj` 测试数据，
不属于运行时产品声明。

## 构建钩子的职责

- `yjson_native_primitives/build.cj`：Custom 扫描器和 Compact 静态库；
- `yjson_yyjson/build.cj`：扫描器、辅助代码和内置 yyjson 适配器；
- `yjson_schema_formats/build.cj`：libidn2 接口；
- 基准测试构建钩子：仅供仓库使用的工具。

Pure 核心包、宏、算法、后端接口和加速初始化包不应引入 Native 构建钩子。

## API 文档生成

`release/cjdoc-tool.toml` 固定 cjdoc 源码、提交、源码归档校验和、STS `1.2.0` 和二进制验证要求。
`0.2.0` 文档候选固定使用已发布并通过源码资格验证的 cjdoc `0.7.7`。
`release/cjdoc-policy.toml` 记录经过核对的解析限制，不用隐藏声明代替修复。

`scripts/generate_api_docs.py` 从九包发布图构造隔离的文档 workspace，不维护第二份包清单。
统一站点以根目录 `index.html` 为入口，提供跨包搜索、指南导航与 API 链接。
候选产物包括 HTML、Markdown、Doc IR v16、质量报告和完整 Agent 离线包。
生成代码 SPI、第一方内部接口和 C ABI 按职责展示；八个应用包要求中文契约与逐入口可执行示例。
维护方法见[API 文档注释与 CI](api-documentation.md)。

旧 URL、旧 Doc IR 和旧产物目录不建兼容层。历史发布数据保留在原路径；当前站点的导航
和工具消费方按本候选产物更新。

CI 在 Linux 生成 Pages 产物。本候选要求 Windows/macOS 运行 Pure 包检查和适用示例验证。
Pages 只从全部必需门禁通过、仍为 `main` HEAD 的精确提交部署。

## 维护约束

- 包源码目录新增已纳入版本控制的 `.cj` 文件时同步发布文件清单；
- 开发版和暂存发布版都要通过独立使用方测试；
- 不要将测试数据、基准测试辅助函数、后端策略或发布验证参数加入默认 API；
- 包版本配对、许可证、仅含源码的归档和 cjdoc 的版本信息必须通过检查。
