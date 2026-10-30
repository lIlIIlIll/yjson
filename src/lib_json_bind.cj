package yjson

import std.ast.*
import std.collection.*

// 供调用方宏展开使用的集合别名，使生成的辅助函数不依赖调用方的集合导入。
/**
 * 为宏展开代码提供 ArrayList 类型别名。
 *
 * 生成辅助函数通过 yjson 引用集合类型，不要求使用方额外导入 std.collection。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public type YJsonArrayList<T> = ArrayList<T>
/**
 * 为宏展开代码提供 HashMap 类型别名。
 *
 * 生成辅助函数通过 yjson 引用集合类型，不要求使用方额外导入 std.collection。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public type YJsonHashMap<K, V> = HashMap<K, V>

/**
 * 指定生成 codec 字段或枚举构造项的 JSON 名称。
 *
 * 在 @JsonCodec 字段或枚举构造项上使用 @JsonName["wire_name"]。字段采用该名称读写，枚举采用该名称作为构造项标记；同一类型中的名称和别名不得冲突。
 * @group 10-application 应用 API
 */
@Annotation
public class JsonName {
    /**
     * JSON 字段名称。
     * @group 10-application 应用 API
     */
    public let value: String

    /**
     * 保存指定的 JSON 字段名称。
     *
     * @param value JSON 字段名称。
     *
     * @example 元数据构造（core） {run}
     * ```cangjie
     * let name = JsonName("wire_name")
     * if (name.value != "wire_name") { throw Exception("字段名称不符") }
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public const init(value: String) {
        this.value = value
    }
}

/**
 * 从生成的 JSON 编码与解码中排除字段。
 *
 * 在 @JsonCodec 类型的字段上使用 @JsonIgnore。被忽略字段不从输入读取，也不写入输出。
 * @group 10-application 应用 API
 */
@Annotation
public class JsonIgnore {
    /**
     * 创建忽略字段的注解。
     *
     * @example 注解效果（core-codec） {run}
     * ```cangjie
     * let _ = JsonIgnore()
     * let text = YJson.toJson<DocIgnoredField>(DocIgnoredField())
     * let decoded = YJson.fromJson<DocIgnoredField>("{\"visible\":8,\"secret\":99}")
     * docRequire(text == "{\"visible\":7}" && decoded.visible == 8 && decoded.secret == 9)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public const init() {}
}

/**
 * 在生成的 Option 字段为 None 时输出 JSON null。
 *
 * 在字段上使用 @JsonIncludeNull；未使用此注解的 None 字段可从对象输出中省略。
 * @group 10-application 应用 API
 */
@Annotation
public class JsonIncludeNull {
    /**
     * 创建保留 null 输出的字段注解。
     *
     * @example 注解效果（core-codec） {run}
     * ```cangjie
     * let _ = JsonIncludeNull()
     * let text = YJson.toJson<DocNullField>(DocNullField())
     * docRequire(text == "{\"optional\":null}")
     * docRequire(YJson.fromJson<DocNullField>(text).optional.isNone())
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public const init() {}
}

/**
 * 为生成 codec 的字段添加只用于输入的别名。
 *
 * 使用 @JsonAlias["old_name"]，可重复声明。编码仍使用首选名称；别名不改变重复键策略。
 * @group 10-application 应用 API
 */
@Annotation
public class JsonAlias {
    /**
     * 解码时接受的备选字段名称。
     * @group 10-application 应用 API
     */
    public let value: String

    /**
     * 保存解码时接受的字段别名。
     *
     * @param value 解码时接受的备选字段名称。
     *
     * @example 元数据构造（core） {run}
     * ```cangjie
     * let alias = JsonAlias("legacy_name")
     * if (alias.value != "legacy_name") { throw Exception("字段别名不符") }
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public const init(value: String) {
        this.value = value
    }
}

// Retained AST metadata emitted by @JsonUsing. Applications should use the
// macro rather than spelling this annotation directly.
/**
 * 保存 @JsonUsing 宏留下的codec 源码表达式元数据。
 *
 * 该注解是宏处理之间的保留载体，不执行表达式。应用使用 @JsonUsing；codec 分析阶段读取保留的源码。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
@Annotation
public class JsonUsingMetadata {
    /**
     * 保存供宏分析读取的codec 源码表达式文本。
     *
     * 保存源码文本，不是运行时解析后的 codec 或类型对象。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public let expression: String

    /**
     * 保存 @JsonUsing 的codec 源码表达式。
     *
     * 只赋值，不解析或校验表达式。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param expression 宏需要保留的codec 源码表达式文本。
     * @example 元数据构造（core） {run}
     * ```cangjie
     * let metadata = JsonUsingMetadata("CustomCodec")
     * if (metadata.expression != "CustomCodec") { throw Exception("表达式不符") }
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     */
    public const init(expression: String) {
        this.expression = expression
    }
}

/**
 * 选择已声明多态映射使用的 JSON 判别字段。
 *
 * 与 @JsonCodec、@JsonSubtype 配合使用。默认判别字段为 type；解码根据已声明的判别值选择子类型。
 * @group 10-application 应用 API
 */
@Annotation
public class JsonPolymorphic {
    /**
     * 用于选择子类型的 JSON 字段名称。
     * @group 10-application 应用 API
     */
    public let discriminator: String

    /**
     * 保存用于选择子类型的判别字段名称。
     *
     * @param discriminator 用于选择子类型的对象字段，默认为 type。
     *
     * @example 元数据构造（core） {run}
     * ```cangjie
     * let defaults = JsonPolymorphic()
     * let custom = JsonPolymorphic(discriminator: "kind")
     * if (defaults.discriminator != "type" || custom.discriminator != "kind") { throw Exception("判别字段不符") }
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public const init(discriminator!: String = "type") {
        this.discriminator = discriminator
    }
}

// Retained AST metadata emitted by @JsonSubtype. Each expression contains a
// wire discriminator followed by a concrete subtype, for example
// `@JsonSubtype["dog", Dog]`.
/**
 * 保存 @JsonSubtype 宏留下的判别值和具体子类型的源码表达式元数据。
 *
 * 该注解是宏处理之间的保留载体，不执行表达式。应用使用 @JsonSubtype；codec 分析阶段读取保留的源码。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
@Annotation
public class JsonSubtypeMetadata {
    /**
     * 保存供宏分析读取的判别值和具体子类型的源码表达式文本。
     *
     * 保存源码文本，不是运行时解析后的 codec 或类型对象。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public let expression: String

    /**
     * 保存 @JsonSubtype 的判别值和具体子类型的源码表达式。
     *
     * 只赋值，不解析或校验表达式。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param expression 宏需要保留的判别值和具体子类型的源码表达式文本。
     * @example 元数据构造（core） {run}
     * ```cangjie
     * let metadata = JsonSubtypeMetadata("dog,Dog")
     * if (metadata.expression != "dog,Dog") { throw Exception("子类型映射不符") }
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     */
    public const init(expression: String) {
        this.expression = expression
    }
}
