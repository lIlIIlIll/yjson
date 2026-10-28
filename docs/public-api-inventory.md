# yjson 0.2 公开 API 清单

本页说明 `0.2.0` 候选的接口职责与升级要求。完整声明列表位于
[`release/public-api-snapshot.txt`](../release/public-api-snapshot.txt)，经过评审的破坏性
变更与新增 API 位于
[`release/public-api-inventory.toml`](../release/public-api-inventory.toml)。相对于冻结基线的完整
Cangjie 声明差异及逐项分类位于
[`release/public-cangjie-delta-0.2.0.toml`](../release/public-cangjie-delta-0.2.0.toml)。
当前差异基线为 `0f2071a0ad59ad43a369abe51abaceaf873f0c63` 的已发布声明快照。
较早的 [`bfd29 差异记录`](../release/public-cangjie-delta-bfd29.toml)保持原样，仅供查询当时的评审事实。

运行：

```terminal
python3 scripts/check_api_inventory.py
```

命令检查九个包的版本、发布依赖图、API 清单、快照生成器回归测试和当前快照。漏项、错配或
证据漂移会返回非零状态。`migration` 阶段允许完整记录的待评审组；发布图为 `release-ready`
时，全部组和全局发布批准都必须完成。

## 普通应用入口

普通应用使用以下入口：

```cangjie
YJson.toJson(value)
YJson.fromJson<T>(text)
YJson.parseDocument(text)
JsonNode.parse(text)
```

`JsonDocument` 提供 `root()`、`materialize()` 和 JSON 输出。它不包含 backend identity、
`Resource`、`close()` 或 `isClosed()`。String、bytes 和 stream overload 使用同一
`JsonReadOptions`、`JsonWriteOptions`、codec 和 error contract。

`JsonValueView` 提供统一的只读接口。managed document、高级 backend 和
`JsonNode` 都能交给 serializer 与算法；修改必须通过 `JsonNode` 的修改 API。

## 快照收集范围

生成器收集顶层 public declaration、外部可见 public 类型的成员、interface 的隐式 public
成员和每个 enum case，首项、同行与分行写法使用相同记录。private 或默认 internal 类型中的 public 成员不会进入快照。多行类型头被
规范化成单条声明。C ABI 快照另含 `native/*.h` 导出的 `YJ_*` prototype。

快照检查会拒绝未评审的差异，但仍需要人工评审兼容性。公开声明变化时，先运行：

```terminal
python3 scripts/generate_public_api_snapshot.py --write
```

随后从固定的完整基线提交生成候选差异：

```terminal
python3 scripts/check_api_inventory.py --write-cangjie-delta 0f2071a0ad59ad43a369abe51abaceaf873f0c63
```

逐条审查 diff，并同步 inventory。不要手工编辑快照。生成器只分类，不批准变更；所有新生成的组
都从 `pending-migration-review` 开始。

差异文件把每条 removed/added declaration 放入且只放入一个 review group。每组记录分类、
理由和 review status；全局 `approved-for-release` 只有在没有漏项、重复项、未分类声明或 pending
group 时才有效。组的 `reviewed-for-0.2.0` 状态必须与差异文件的 `target_version` 和发布图版本一致，
旧版本的评审不能替代当前候选评审。`release-ready` graph 会再次执行这项检查。

旧采集器漏掉的 enum case 记录单列为 `existing-enum-case-inventory`，不计为新增 API。
[`基线采集证据`](../release/0.2.0/enum-case-inventory.json)记录相同采集器处理精确基线源码的结果、
源码摘要和采集器摘要。检查器只允许将基线集合中确实存在的 case 纳入该组；真正新增的 case
必须另行评审。本轮唯一破坏性声明删除为已确认的 `@JsonValue` 别名，整个发布仍未获批准。

## 生成代码协议

`yjson` 与独立仓库 [`yjson_macros`](https://github.com/lIlIIlIll/yjson_macros) 是同一个
lockstep release。macro 输出面向 `generated_support.v1` 并嵌入 protocol version 1；不匹配时
明确失败。

V1 只描述当前候选的生产契约。升级时同步第一方依赖，重新展开宏并编译消费方，不能据此
混用不同版本的宏、运行时或预编译产物。

普通 generated codec bridge 是
`GeneratedCodecProviderV1<T>.generatedCodecV1(_: GeneratedCodecTokenV1<T>): JsonCodec<T>`。
`GeneratedCodecTokenV1<T>` 是零状态的重载 token，使继承链上的父类和子类各自返回精确
`JsonCodec<T>`。宏展开和 runtime dispatch 之间不经过 `Any`、erase/reify adapter 或运行时
类型转换。

bridge 声明因跨 package 展开而必须 public，但不是普通应用入口。应用使用
`@JsonCodec`、`@Json({...})`、`JsonCodec<T>`、`YJson` 和 `JsonCodecs`。

## 可选包

| Package | 用途 | 生命周期 |
| --- | --- | --- |
| `yjson_macros` | 编译期 generated codec 和 JSON literal | 与 runtime lockstep，不在运行期加载 |
| `yjson_algorithms` | Pointer、Patch、Path 和 Schema | 默认有限预算；cursor 单线程 |
| `yjson_schema_formats` | 国际化 Schema format | 在 Schema 构造前安装到 registry |
| `yjson_native_accel` | 启动时初始化 Native primitive | 进程级冻结；不能 uninstall 或切换 |
| `yjson_native_primitives` | scanner/provider closed SPI | 只供第一方 Native package |
| `yjson_backends` | metadata 和 explicit-resource interface | 不提供任意 strategy registry |
| `yjson_native` | `NativeBackends.customNative` | 返回显式 resource |
| `yjson_yyjson` | `YyjsonBackends.yyjson` | 返回显式 resource |

Schema resource URI 只通过注入的 `UriResolver` 在构造阶段解析。成功构造后，compiled schema
不再保留 resolver。

## 0.x 兼容政策

整个 `0.x` 阶段的 patch 和 minor 都不保证跨版本源码、API、ABI、生成代码或旧 SDK 兼容。
`0.2.0` 统一使用 STS `1.2.0`。升级时同步所用的第一方包，重新生成并编译消费方。

破坏性变更仍须逐项说明影响、提供迁移方法，并取得用户明确确认。当前候选已确认删除
`@JsonValue`，调用迁到 `@Json`，不保留宏别名。`JsonAlias` 字段读取别名、当前生成协议、
ABI 错配检查、预算和资源生命周期语义保留。

声明快照与 API 差异评审继续检查当前接口；独立消费方验证当前包配对和实际行为。
未来候选不再要求以冻结的旧消费方二进制完成跨版本链接矩阵，也不据此承诺可替换旧动态库。

`0.1.1` 在 STS `1.1.3`、Linux x86_64 下的有限兼容 PASS 保留在
[`release/0.1.1/binary-compatibility.json`](../release/0.1.1/binary-compatibility.json)。
它只证明记录的产物组合，不外推到 `0.2.0`、其他 SDK 或其他应用。
历史 tag、发布证据和性能报告保持不可变。九包顺序与接口分类来自
[`release/release-graph.toml`](../release/release-graph.toml)，成熟度标签不提供兼容保证。
