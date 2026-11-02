# `@JsonCodec` 生成指南

在类型声明上添加 `yjson_macros` 提供的 `@JsonCodec`，编译时即可生成对应的
`JsonCodec<T>` 和 `GeneratedCodecProviderV1<T>` 实现。宏随调用方的包一起编译，
不扫描源码目录，也不向仓库写入生成文件。

## 最小声明

```cangjie
import yjson.*
import yjson_macros.*

@JsonCodec
class User {
    public let id: Int64
    public var name: String

    public init(id: Int64, name: String) {
        this.id = id
        this.name = name
    }
}
```

非泛型类型得到 `UserJson: JsonCodec<User>`。随后既可以使用自动推导 codec 的入口，也可以显式传 codec：

```cangjie
let text = YJson.toJson(User(7, "Alice"))
let same = YJson.toJson(User(7, "Alice"), codec: UserJson)
```

泛型类型得到 `TypeJson<T>(): JsonCodec<Type<T>>` 函数。参与自动推导的泛型参数必须满足
`GeneratedCodecProviderV1<T>` 约束；使用 `@JsonUsing` 的字段由显式 codec 决定。

## 支持范围

- class 和 struct；
- enum，包括带关联值的构造器；
- 泛型声明；
- 通过 `@JsonPolymorphic` 和重复 `@JsonSubtype` 声明的封闭多态映射。

## 字段规则

只有 public、非 static、具有显式类型的字段默认参与。private、protected、internal 和默认
可见字段不参与。

| 标记 | 行为 |
| --- | --- |
| `@JsonIgnore` | 排除字段 |
| `@JsonName["wire_name"]` | 修改写出名称和主读取名称 |
| `@JsonAlias["old_name"]` | 增加读取时接受的别名，可重复 |
| `@JsonIncludeNull` | `Option` 为 `None` 时仍写出 `null` |
| `@JsonUsing[codecExpression]` | 为字段选择自定义 codec |

```cangjie
@JsonCodec
class Profile {
    @JsonName["profile_id"]
    @JsonAlias["legacy_id"]
    public let id: Int64

    @JsonIncludeNull
    public var nickname: Option<String>

    @JsonIgnore
    public var cacheKey: String = ""

    public init(id: Int64, nickname: Option<String>) {
        this.id = id
        this.nickname = nickname
    }
}
```

JSON 名称和别名在同一类型中必须唯一。

## 构造和缺失字段

宏选择参数最多的构造器，并按参数名匹配字段。构造器未覆盖的可变字段在
构造后赋值；不可变字段必须由构造器接收。构造参数默认值可以处理缺失输入，
`Option<T>` 字段也不是必需字段。

- 必需字段缺失：`missing_field`。
- 未知字段：默认忽略；`JsonUnknownFieldPolicy.Reject` 时为 `unknown_field`。
- 重复键：默认拒绝并返回 `duplicate_key`；`LastWins` 必须显式选择。

这些策略也适用于生成的 Map 字段、集合元素及忽略字段中的嵌套值。键名按解码后的字符串
比较，转义写法不同但解码相同的名称仍是重复键。跳过未知值不绕过深度、缓冲和重复键检查。

具体模型的 String 快速入口与泛型、bytes、stream 入口遵守相同的读取预算；
默认最大容器深度为 256，最大缓冲值大小为 8 MiB。

## 嵌套 codec 与初始化

默认生成的嵌套字段通过类型化 provider 获取 codec，不引用其他源码文件中的私有全局变量。
依赖其他生成模型的字段 codec 延迟到首次使用时初始化，字段状态保留具体类型。
初始化门只负责并发发布；成功结果只发布一次，失败不发布部分状态。
显式 `@JsonUsing` 表达式仍在所属 codec 初始化时求值，不改变用户表达式的求值时机。

紧凑 raw 写入前先检查参与字段的能力；不支持该路径或遇到递归能力查询时，使用语义写入。
仅当全部参与依赖都证明 compact 能力在实例生命周期内恒为 true 时，才缓存肯定结果。
动态自定义 codec 仍实时查询，递归中的暂时否定结果不缓存；实际值的容器深度仍受写入选项约束。

## 多态类型

```cangjie
@JsonCodec
@JsonSubtype["dog", Dog]
@JsonSubtype["cat", Cat]
@JsonPolymorphic[discriminator: "kind"]
open class Animal {
    public let id: Int64
    public init(id: Int64) { this.id = id }
}
```

每个子类型都必须有 codec。上例用 `kind` 字段选择子类型；字段缺失时报
`missing_discriminator`，值不在映射中时报 `unknown_discriminator`。
生成的读取器先缓冲完整根值，读取判别字段后，再把同一份数据交给对应子类型的 codec。
宏为具体 class 和 struct 生成类型明确的对象读写接口，按这些接口分派子类型，
避免误用从 open 基类继承的 codec。

具体子类型编码时组合真实父类与子类的字段；解码仍按所选构造器及可变字段赋值规则处理。
仅实现接口（如 `ToString`）不要求接口提供对象字段 codec。真实父类必须提供匹配的生成字段协议，
否则报 `codec_contract`。父类与子类各自保留对应的 `JsonCodec<T>`，无需把模型值擦除后再向下转换。

捕获大小受 `JsonReadOptions.maxBufferedValueBytes` 约束，默认 8 MiB；超限使用
`buffered_value_too_large`。根值分派不重复计入容器深度。

## 版本边界

`yjson` 和 `yjson_macros` 必须来自同一候选或同一次发布，并使用 STS `1.2.0`。
升级第一方依赖后重新展开宏、编译应用。整个 `0.x` 阶段不保证旧生成代码或旧 SDK 可继续使用。

宏生成代码使用协议版本 1，协议不匹配时报
`generated_protocol_mismatch`。

V1 是当前候选中宏与运行时的匹配契约，不提供跨版本混用保证。`0.2.0` 删除 JSON literal
宏别名 `@JsonValue`，调用改为 `@Json`。字段上的 `@JsonAlias` 仍用于接受额外的输入名称。

生成代码通过 `generated_support.v1` 调用运行库。默认快速路径还直接引用
`JsonFastReader`、`JsonDirectWriter` 和 `ReadCursor`，这些类型也随 V1 协议一起演进。
快速路径先调用 `GeneratedSupportV1.enterGeneratedEntry()`，校验协议并冻结运行时配置，
再开始解析。

生成代码通过以下方法查找 codec：
`GeneratedCodecProviderV1<T>.generatedCodecV1(_: GeneratedCodecTokenV1<T>): JsonCodec<T>`。
无状态的 token 让父类和子类通过参数类型区分同名方法。provider 保留 `JsonCodec<T>` 的类型，
模型值不经过 `Any` 擦除和类型恢复适配器。递归 compact 能力检查在线程局部栈中暂存 codec 引用，
只用于识别同一模型类型的递归查询；退出查询时释放该栈项，不缓存模型值。
稳定能力证明由独立的实例级原子标记保存，不与线程局部递归状态混用。

应用应直接声明 `yjson` 和 `yjson_macros` 依赖。不要直接调用生成支持接口或对象读写辅助方法。
这些声明设为 public 是为了让宏跨包展开，应用代码无需调用。
