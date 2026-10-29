package yjson

import std.collection.*
import std.convert.Parsable
import std.deriving.Derive
import std.io.*

/**
 * JSON 数据模型中的六种值类型。
 *
 * 数字统一标记为 Number；整数、无符号整数、浮点数和保留原文的数字不另设种类。
 *
 * @example 调用并检查结果 {run}
 * ```cangjie
 * println(JsonNode.parse("null").kind() == JsonKind.Null)
 * ```
 * ```output
 * true
 * ```
 * @group 10-application 应用 API
 */
@Derive[Equatable]
public enum JsonKind {
    /** JSON 空值。
     * @group 10-application 应用 API
     */
    Null
    /** JSON 布尔值。
     * @group 10-application 应用 API
     */
    | Boolean
    /** JSON 数字，不区分整数和浮点数。
     * @group 10-application 应用 API
     */
    | Number
    /** JSON 字符串。
     * @group 10-application 应用 API
     */
    | String
    /** JSON 数组。
     * @group 10-application 应用 API
     */
    | Array
    /** JSON 对象。
     * @group 10-application 应用 API
     */
    | Object
}

/**
 * JSON 错误在 UTF-8 输入中的位置。
 *
 * byteOffset 从 0 开始，line 和 column 从 1 开始。列按字节位置计算，不是字符或显示宽度；换行后重新从 1 计数。
 * @group 10-application 应用 API
 */
public struct JsonLocation {
    /**
     * 从 0 开始的 UTF-8 字节偏移。
     * @group 10-application 应用 API
     */
    public let byteOffset: Int64
    /**
     * 从 1 开始的输入行号。
     * @group 10-application 应用 API
     */
    public let line: Int64
    /**
     * 从 1 开始的行内字节列号。
     * @group 10-application 应用 API
     */
    public let column: Int64

    /**
     * 构造已知输入位置，不读取或校验实际输入。
     *
     * @param byteOffset 非负 UTF-8 字节偏移。
     * @param line 正数行号。
     * @param column 正数行内字节列号。
     * @throws IllegalArgumentException 偏移为负，或行号、列号非正。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let position = JsonLocation(3, 2, 1)
     * println(position.byteOffset == 3 && position.line == 2 && position.column == 1)
     * ```
     * ```output
     * true
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var rejected = false
     * try { let _ = JsonLocation(-1, 1, 1) } catch (_: IllegalArgumentException) { rejected = true }
     * println(rejected)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public init(byteOffset: Int64, line: Int64, column: Int64) {
        if (byteOffset < 0) { throw IllegalArgumentException("byteOffset must not be negative") }
        if (line <= 0) { throw IllegalArgumentException("line must be positive") }
        if (column <= 0) { throw IllegalArgumentException("column must be positive") }
        this.byteOffset = byteOffset
        this.line = line
        this.column = column
    }
}

/**
 * 携带错误类别、JSON Pointer 和可选输入位置的 JSON 异常。
 *
 * 使用 code 分支处理错误。path 为空串时表示根值；输入流 I/O 异常和自定义 codec 异常可能原样传播。message 用于诊断，不应从文本提取错误类别。
 * @group 10-application 应用 API
 */
public open class JsonException <: Exception {
    /**
     * 供程序判断的错误类别，如 type_mismatch 或 max_depth。
     * @group 10-application 应用 API
     */
    public let code: String
    /**
     * 错误值的 RFC 6901 JSON Pointer；空串表示根。
     * @group 10-application 应用 API
     */
    public let path: String
    /**
     * 有输入位置时为 Some，否则为 None。
     * @group 10-application 应用 API
     */
    public let location: Option<JsonLocation>

    /**
     * 构造没有原始原因异常的 JSON 错误。
     *
     * @param message 供人阅读的错误说明。
     * @param code 错误类别；默认 json_error。
     * @param path 空串或以 / 开始的 JSON Pointer；构造器只检查此前缀。
     * @param location 已知输入位置；默认 None。
     * @throws IllegalArgumentException 非空 path 不以 / 开始。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let error = JsonException("字段缺失", code: "missing_field", path: "/name",
     *     location: Some(JsonLocation(1, 1, 2)))
     * println(error.code == "missing_field" && error.path == "/name" && error.location.isSome())
     * ```
     * ```output
     * true
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var rejected = false
     * try { let _ = JsonException("错误", path: "id") } catch (_: IllegalArgumentException) { rejected = true }
     * println(rejected)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public init(
        message: String,
        code!: String = "json_error",
        path!: String = "",
        location!: Option<JsonLocation> = None<JsonLocation>
    ) {
        super(message)
        validateJsonExceptionPath(path)
        this.code = code
        this.path = path
        this.location = location
    }

    /**
     * 构造并保留原始原因异常的 JSON 错误。
     *
     * @param message 供人阅读的错误说明。
     * @param causedBy 作为 cause 保留的原始异常。
     * @param code 错误类别；默认 json_error。
     * @param path 空串或以 / 开始的 JSON Pointer；构造器只检查此前缀。
     * @param location 已知输入位置；默认 None。
     * @throws IllegalArgumentException 非空 path 不以 / 开始。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let cause = IllegalArgumentException("输入不合法")
     * let error = JsonException("无法转换", cause, code: "type_mismatch")
     * println(error.code == "type_mismatch" && error.path.isEmpty())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public init(
        message: String,
        causedBy: Exception,
        code!: String = "json_error",
        path!: String = "",
        location!: Option<JsonLocation> = None<JsonLocation>
    ) {
        super(message, causedBy)
        validateJsonExceptionPath(path)
        this.code = code
        this.path = path
        this.location = location
    }

    /**
     * 为继承的异常文本表示提供 JSON 异常类名。
     *
     * @return 字符串 JsonException；子类可以覆盖此名称。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let error = JsonException("输入不合法")
     * println(error.toString().contains("JsonException"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    protected open override func getClassName(): String {
        "JsonException"
    }
}

private func validateJsonExceptionPath(path: String): Unit {
    if (!path.isEmpty() && !path.startsWith("/")) {
        throw IllegalArgumentException("JSON error path must be an RFC 6901 JSON Pointer")
    }
}

/**
 * 类型化 codec 遇到未知对象字段时的策略。
 *
 * 默认 Ignore。这个策略不限制 JsonNode 或 JsonDocument 保存对象字段。
 *
 * @example 调用并检查结果 {run}
 * ```cangjie
 * let options = JsonReadOptions(unknownFieldPolicy: JsonUnknownFieldPolicy.Reject)
 * println(options.rejectsUnknownFields())
 * ```
 * ```output
 * true
 * ```
 * @group 10-application 应用 API
 */
public enum JsonUnknownFieldPolicy {
    /** 类型化解码时跳过 codec 不认识的字段。
     * @group 10-application 应用 API
     */
    Ignore
    /** 遇到不允许的字段或重复键时抛出 JsonException。
     * @group 10-application 应用 API
     */
    | Reject
}

/**
 * 同一个 JSON 对象中出现重复名称时的读取策略。
 *
 * 默认 Reject；显式选用 LastWins 才允许后值覆盖。
 *
 * @example 调用并检查结果 {run}
 * ```cangjie
 * let value = JsonNode.parse("{\"id\":1,\"id\":2}",
 *     config: JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins))
 * println(value["id"].asInt64() == 2)
 * ```
 * ```output
 * true
 * ```
 * @group 10-application 应用 API
 */
public enum JsonDuplicateKeyPolicy {
    /** 对象中重复名称的最后一个值覆盖先前值。
     * @group 10-application 应用 API
     */
    LastWins
    /** 遇到不允许的字段或重复键时抛出 JsonException。
     * @group 10-application 应用 API
     */
    | Reject
}

/**
 * 不可变的读取策略与单次文档资源预算。
 *
 * 默认忽略未知类型化字段、拒绝重复键；输入上限 64 MiB，解码后的单字符串上限 16 MiB，捕获值缓冲上限 8 MiB，容器深度上限 256。所有预算必须为正数，0 不表示无限。
 * @group 10-application 应用 API
 */
public class JsonReadOptions {
    /**
     * 类型化 codec 处理未知对象字段的策略。
     * @group 10-application 应用 API
     */
    public let unknownFieldPolicy: JsonUnknownFieldPolicy
    /**
     * 读取同一对象内重复名称的策略。
     * @group 10-application 应用 API
     */
    public let duplicateKeyPolicy: JsonDuplicateKeyPolicy
    /**
     * 单份文档输入的 UTF-8 字节上限；流读取不为检查此限制而预读到 EOF。
     * @group 10-application 应用 API
     */
    public let maxInputBytes: Int64
    /**
     * 单个键名或字符串解码后的 UTF-8 字节上限。
     * @group 10-application 应用 API
     */
    public let maxStringBytes: Int64
    /**
     * 需要捕获完整值时的字节缓冲上限；不是整个进程的内存限制。
     * @group 10-application 应用 API
     */
    public let maxBufferedValueBytes: Int64
    /**
     * 允许的数组和对象嵌套层数上限。
     * @group 10-application 应用 API
     */
    public let maxDepth: Int64
    let defaultFastPath: Bool

    /**
     * 创建用于一次或多次读取的不可变配置。
     *
     * @param unknownFieldPolicy 未知字段处理策略，默认 Ignore。
     * @param duplicateKeyPolicy 重复键处理策略，默认 Reject。
     * @param maxInputBytes 正数输入字节上限，默认 64 MiB。
     * @param maxStringBytes 正数解码后字符串字节上限，默认 16 MiB。
     * @param maxBufferedValueBytes 正数捕获值缓冲字节上限，默认 8 MiB。
     * @param maxDepth 正数容器嵌套上限，默认 256。
     * @throws IllegalArgumentException 任意预算为 0 或负数。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let options = JsonReadOptions(maxInputBytes: 32, maxStringBytes: 8,
     *     maxBufferedValueBytes: 16, maxDepth: 2)
     * println(JsonNode.parse("[1]", config: options).size() == 1)
     * ```
     * ```output
     * true
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var rejected = false
     * try { let _ = JsonReadOptions(maxInputBytes: 0) } catch (_: IllegalArgumentException) { rejected = true }
     * println(rejected)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public init(
        unknownFieldPolicy!: JsonUnknownFieldPolicy = JsonUnknownFieldPolicy.Ignore,
        duplicateKeyPolicy!: JsonDuplicateKeyPolicy = JsonDuplicateKeyPolicy.Reject,
        maxInputBytes!: Int64 = 64 * 1024 * 1024,
        maxStringBytes!: Int64 = 16 * 1024 * 1024,
        maxBufferedValueBytes!: Int64 = 8 * 1024 * 1024,
        maxDepth!: Int64 = 256
    ) {
        if (maxDepth <= 0) { throw IllegalArgumentException("maxDepth must be positive") }
        if (maxInputBytes <= 0) { throw IllegalArgumentException("maxInputBytes must be positive") }
        if (maxStringBytes <= 0) { throw IllegalArgumentException("maxStringBytes must be positive") }
        if (maxBufferedValueBytes <= 0) { throw IllegalArgumentException("maxBufferedValueBytes must be positive") }
        this.unknownFieldPolicy = unknownFieldPolicy
        this.duplicateKeyPolicy = duplicateKeyPolicy
        this.maxInputBytes = maxInputBytes
        this.maxStringBytes = maxStringBytes
        this.maxBufferedValueBytes = maxBufferedValueBytes
        this.maxDepth = maxDepth
        let unknownIsDefault = match (unknownFieldPolicy) {
            case Ignore => true
            case _ => false
        }
        let duplicateIsDefault = match (duplicateKeyPolicy) {
            case Reject => true
            case _ => false
        }
        this.defaultFastPath = unknownIsDefault && duplicateIsDefault && maxDepth == 256 &&
            maxInputBytes == 64 * 1024 * 1024 && maxStringBytes == 16 * 1024 * 1024 &&
            maxBufferedValueBytes == 8 * 1024 * 1024
    }

    /**
     * 可以共享的不可变默认读取配置。
     * @group 10-application 应用 API
     */
    public static let defaults: JsonReadOptions = JsonReadOptions()

    /**
     * 检查是否拒绝类型化未知字段。
     *
     * @return unknownFieldPolicy 为 Reject 时返回 true。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let options = JsonReadOptions(unknownFieldPolicy: JsonUnknownFieldPolicy.Reject)
     * println(options.rejectsUnknownFields())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func rejectsUnknownFields(): Bool {
        match (unknownFieldPolicy) {
            case Reject => true
            case _ => false
        }
    }

    /**
     * 检查是否拒绝对象重复键。
     *
     * @return duplicateKeyPolicy 为 Reject 时返回 true。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonReadOptions.defaults.rejectsDuplicateKeys())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func rejectsDuplicateKeys(): Bool {
        match (duplicateKeyPolicy) {
            case Reject => true
            case _ => false
        }
    }
}

func jsonReadOptionsUsesDefaultFastPath(options: JsonReadOptions): Bool {
    options.defaultFastPath
}

func jsonReadOptionsRejectsUnknownFields(options: JsonReadOptions): Bool {
    match (options.unknownFieldPolicy) {
        case Reject => true
        case _ => false
    }
}

func jsonReadOptionsRejectsDuplicateKeys(options: JsonReadOptions): Bool {
    match (options.duplicateKeyPolicy) {
        case Reject => true
        case _ => false
    }
}

func jsonLineFromUtf8Bytes(data: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0) {
        return -1
    }
    let limit = if (offset > data.size) {
        data.size
    } else {
        offset
    }
    var line: Int64 = 1
    for (index in 0..limit) {
        if (data[index] == b'\n') {
            line++
        }
    }
    line
}

func jsonColumnFromUtf8Bytes(data: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0) {
        return -1
    }
    let limit = if (offset > data.size) {
        data.size
    } else {
        offset
    }
    var column: Int64 = 1
    for (index in 0..limit) {
        if (data[index] == b'\n') {
            column = 1
        } else {
            column++
        }
    }
    column
}

// Stream readers retain only the current byte buffer, so error positions must
// be reconstructed from absolute newline offsets instead of the current
// cursor. Newlines at the queried offset belong to the preceding line, which
// matches jsonLineFromUtf8Bytes/jsonColumnFromUtf8Bytes.
func jsonStreamLineAt(newlineOffsets: ArrayList<Int64>, offset: Int64): Int64 {
    if (offset < 0) { return -1 }
    var line: Int64 = 1
    for (newlineOffset in newlineOffsets) {
        if (newlineOffset >= offset) { break }
        line++
    }
    line
}

func jsonStreamColumnAt(newlineOffsets: ArrayList<Int64>, offset: Int64): Int64 {
    if (offset < 0) { return -1 }
    for (index in 0..newlineOffsets.size) {
        let reverseIndex = newlineOffsets.size - index - 1
        let newlineOffset = newlineOffsets[reverseIndex]
        if (newlineOffset < offset) { return offset - newlineOffset }
    }
    offset + 1
}

/**
 * 与存储表示无关的 JSON 只读访问接口。
 *
 * 只读访问不使底层 JsonNode 变为快照，也不提供线程安全。托管文档视图保留存储；Native 等资源后端视图依赖所属文档未关闭。需要独立可修改树时调用 materialize。
 * @group 10-application 应用 API
 */
public interface JsonValueView {
    /**
     * 读取 JSON 值种类。
     *
     * @return 六种 JsonKind 之一。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("[1]").root()
     * println(value.kind() == JsonKind.Array)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func kind(): JsonKind
    /**
     * 读取数组长度或对象成员数。
     *
     * @return 容器的直接子项数；标量返回 0。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("[1,2]").root()
     * println(value.size())
     * ```
     * ```output
     * 2
     * ```
     * @group 10-application 应用 API
     */
    func size(): Int64
    /**
     * 按从 0 开始的下标查询数组元素。
     *
     * @param index 数组元素下标。
     * @return 存在时返回共享底层存储的视图，越界返回 None。
     * @throws JsonException 具体实现拒绝非数组访问时抛出；调用前应先确认 kind() 为 Array。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("[7]").root()
     * println(value.element(0).getOrThrow().asInt64() == 7 && value.element(1).isNone())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func element(index: Int64): Option<JsonValueView>
    /**
     * 按名称查询对象成员。
     *
     * @param name 解码后的完整成员名。
     * @return 存在时返回共享底层存储的视图，缺少名称返回 None。
     * @throws JsonException 具体实现拒绝非对象访问时抛出；调用前应先确认 kind() 为 Object。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("{\"id\":7}").root()
     * println(value.member("id").getOrThrow().asInt64() == 7 && value.member("absent").isNone())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func member(name: String): Option<JsonValueView>
    /**
     * 按对象成员顺序读取名称。
     *
     * @param index 从 0 开始的成员序号；必须小于 size()。
     * @return 该位置的解码后名称。
     * @throws JsonException 值不是对象或序号越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("{\"id\":7}").root()
     * println(value.memberName(0))
     * ```
     * ```output
     * id
     * ```
     * @group 10-application 应用 API
     */
    func memberName(index: Int64): String
    /**
     * 按对象成员顺序读取值视图。
     *
     * @param index 从 0 开始的成员序号；必须小于 size()。
     * @return 与 memberName(index) 对应的值；共享底层存储。
     * @throws JsonException 值不是对象或序号越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("{\"id\":7}").root()
     * println(value.memberValue(0).asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    func memberValue(index: Int64): JsonValueView
    /**
     * 读取布尔值，不进行字符串或数字转换。
     *
     * @return 当前布尔值。
     * @throws JsonException 值不是布尔类型；不同存储实现不保证同一错误 code。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("true").root()
     * println(value.asBool())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func asBool(): Bool
    /**
     * 读取解码后的字符串。
     *
     * @return 已处理 JSON 转义的字符串；不包含引号。
     * @throws JsonException 值不是字符串；不同存储实现不保证同一错误 code。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("\"hello\"").root()
     * println(value.asString())
     * ```
     * ```output
     * hello
     * ```
     * @group 10-application 应用 API
     */
    func asString(): String
    /**
     * 读取可精确表示为 Int64 的整数。
     *
     * @return Int64 整数；要求整数表示，不接受 1.0 或 1e0 之类的文本，也不截断小数。
     * @throws JsonException 值类型不符或整数文本超出范围。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("42").root()
     * println(value.asInt64())
     * ```
     * ```output
     * 42
     * ```
     * @group 10-application 应用 API
     */
    func asInt64(): Int64
    /**
     * 读取可精确表示为 UInt64 的非负整数。
     *
     * @return UInt64 整数；要求非负整数表示，不接受负数、小数或指数写法。
     * @throws JsonException 值类型不符或整数文本超出范围。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("42").root()
     * println(value.asUInt64())
     * ```
     * ```output
     * 42
     * ```
     * @group 10-application 应用 API
     */
    func asUInt64(): UInt64
    /**
     * 将 JSON 数字读取为 Float64。
     *
     * @return 浮点近似值；大整数转换可能舍入。
     * @throws JsonException 值不是数字。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("1.5").root()
     * println(value.asFloat64() == 1.5)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func asFloat64(): Float64
    /**
     * 读取当前数字的 JSON 文本。
     *
     * @return 数字文本；是否保留原始拼写由存储表示决定。
     * @throws JsonException 值不是数字。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("1.20e2").root()
     * println(value.asNumberText())
     * ```
     * ```output
     * 1.20e2
     * ```
     * @group 10-application 应用 API
     */
    func asNumberText(): String
    /**
     * 复制为独立可修改树，默认最多访问 100,000 个节点和 256 层。
     *
     * @return 不共享可变子节点的 JsonNode 树。
     * @throws JsonException 超出工作量或深度限制，或遇到循环节点。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("{\"id\":1}").root()
     * let copy = value.materialize()
     * copy["id"] = 2
     * println(value.member("id").getOrThrow().asInt64() == 1 && copy["id"].asInt64() == 2)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func materialize(): JsonNode
    /**
     * 在指定节点预算内复制为独立可修改树。
     *
     * @param maxNodes 正数节点访问上限，含根节点；深度上限仍为 256。
     * @return 不共享可变子节点的 JsonNode 树。
     * @throws IllegalArgumentException maxNodes 非正。
     * @throws JsonException 超出节点或深度预算，或遇到循环节点。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("[1]").root()
     * println(value.materialize(2).toJson())
     * ```
     * ```output
     * [1]
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * let value: JsonValueView = YJson.parseDocument("[1]").root()
     * var code = ""
     * try { let _ = value.materialize(1) } catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * work_limit_exceeded
     * ```
     * @group 10-application 应用 API
     */
    func materialize(maxNodes: Int64): JsonNode
}

/**
 * 由 GC 管理的 JSON 树节点基类。
 *
 * JsonArray 和 JsonObject 可修改，插入子节点不会复制或冻结它。JsonValueView 只限制访问接口，不能隔离其他持有者的修改；deepCopy 和 materialize 才生成独立树。不要并发修改同一棵树。
 * @group 10-application 应用 API
 */
public abstract class JsonNode <: ToString & JsonValueView {
    /**
     * 创建表示 JSON null 的节点。
     *
     * @return 新的 null 节点。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.nullValue.isNull)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public static prop nullValue: JsonNode {
        get() {
            freezeYJsonRuntime()
            JsonNullValue()
        }
    }
    /**
     * 创建布尔节点。
     *
     * @param value 要保存的布尔值。
     * @return 保存该值的 JsonNode。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.boolean(true).asBool())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public static func boolean(value: Bool): JsonNode { JsonBoolValue(value) }
    /**
     * 创建有符号整数节点。
     *
     * @param value 要保存的 Int64 整数。
     * @return 保存该值的 JsonNode。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.int64(-2).asInt64())
     * ```
     * ```output
     * -2
     * ```
     * @group 10-application 应用 API
     */
    public static func int64(value: Int64): JsonNode { JsonIntValue(value) }
    /**
     * 创建无符号整数节点。
     *
     * @param value 要保存的 UInt64 整数。
     * @return 保存该值的 JsonNode。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.uint64(2u64).asUInt64())
     * ```
     * ```output
     * 2
     * ```
     * @group 10-application 应用 API
     */
    public static func uint64(value: UInt64): JsonNode { JsonUIntValue(value) }
    /**
     * 创建浮点数节点。
     *
     * @param value 要保存的 Float64。非有限值在序列化时被拒绝。
     * @return 保存该值的 JsonNode。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.float64(1.5).asFloat64() == 1.5)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public static func float64(value: Float64): JsonNode { JsonFloatValue(value) }
    /**
     * 创建保留数字拼写节点。
     *
     * @param text 符合 JSON 数字语法的完整文本；不允许前后空白。
     * @return 保存该值的 JsonNode。
     * @throws IllegalArgumentException text 不是合法 JSON 数字文本。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.number("1.20e2").asNumberText())
     * ```
     * ```output
     * 1.20e2
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var rejected = false
     * try { let _ = JsonNode.number("01") } catch (_: IllegalArgumentException) { rejected = true }
     * println(rejected)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public static func number(text: String): JsonNode { JsonNumberLiteralValue(text) }
    /**
     * 创建字符串节点。
     *
     * @param value 未加 JSON 引号的字符串；写出时进行转义。
     * @return 保存该值的 JsonNode。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.string("hello").asString())
     * ```
     * ```output
     * hello
     * ```
     * @group 10-application 应用 API
     */
    public static func string(value: String): JsonNode { JsonStringValue(value) }
    /**
     * 创建可修改的空数组。
     *
     * @return 新的空 JsonArray。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.array().size())
     * ```
     * ```output
     * 0
     * ```
     * @group 10-application 应用 API
     */
    public static func array(): JsonArray { JsonArray() }
    /**
     * 用现有节点创建可修改数组。
     *
     * @param items 按顺序放入数组的节点；只复制外层数组，子节点仍共享。
     * @return 包含给定子节点的新 JsonArray。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let child = JsonNode.object()
     * let array = JsonNode.array([child])
     * child["id"] = 7
     * println(array[0]["id"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public static func array(items: Array<JsonNode>): JsonArray { JsonArray(items) }
    /**
     * 创建按插入顺序枚举成员的空对象。
     *
     * @return 新的空 JsonObject。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.object().size())
     * ```
     * ```output
     * 0
     * ```
     * @group 10-application 应用 API
     */
    public static func object(): JsonObject { JsonObject() }

    /**
     * 解析一份完整 JSON 文档，生成可修改树。
     *
     * @param text 完整 JSON 文本。
     * @param config 读取策略及正数资源预算。
     * @return 新建的 JsonNode 树。
     * @throws JsonException 语法、UTF-8、重复键或资源预算检查失败。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.parse("[1]").toJson())
     * ```
     * ```output
     * [1]
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var code = ""
     * try { let _ = JsonNode.parse("[1]", config: JsonReadOptions(maxInputBytes: 2)) }
     * catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * document_too_large
     * ```
     * @group 10-application 应用 API
     */
    public static func parse(text: String, config!: JsonReadOptions = JsonReadOptions.defaults): JsonNode {
        JsonParser(text, config: config).parse()
    }

    /**
     * 解析一份完整 JSON 文档，生成可修改树。
     *
     * @param bytes 完整 JSON 文档的 UTF-8 字节。
     * @param config 读取策略及正数资源预算。
     * @return 新建的 JsonNode 树。
     * @throws JsonException 语法、UTF-8、重复键或资源预算检查失败。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.parse("[1]".toArray()).toJson())
     * ```
     * ```output
     * [1]
     * ```
     * @group 10-application 应用 API
     */
    public static func parse(bytes: Array<Byte>, config!: JsonReadOptions = JsonReadOptions.defaults): JsonNode {
        parseJsonValueFromBytes(bytes, config: config)
    }

    /**
     * 按写出选项序列化当前节点。
     *
     * @param options 缩进、HTML 转义、输出字节和容器深度限制。
     * @return 一份完整 JSON 文本。
     * @throws JsonException 树存在循环、非有限数值，或超出写出预算。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node = JsonNode.object().put("id", JsonNode.int64(1))
     * println(node.toJson())
     * ```
     * ```output
     * {"id":1}
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * let array = JsonArray()
     * array.add(array)
     * var code = ""
     * try { let _ = array.toJson() } catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * cyclic_json_node
     * ```
     * @group 10-application 应用 API
     */
    public func toJson(options!: JsonWriteOptions = JsonWriteOptions.defaults): String {
        freezeYJsonRuntime()
        writeJsonValueToString(this, options)
    }

    /**
     * 将当前节点写入调用方持有的输出流。
     *
     * 底层 I/O 异常原样传播。失败时流可能已包含前缀；不会回滚输出。
     *
     * @param output 输出目标；本操作不关闭该流。
     * @param options 本次写入的格式和资源预算。
     * @throws JsonException 树存在循环、非有限数值，或超出写出预算。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let output = YJsonMemoryOutputStream()
     * JsonNode.parse("[1]").writeJson(output)
     * println(output.toUtf8String())
     * ```
     * ```output
     * [1]
     * ```
     * @group 10-application 应用 API
     */
    public func writeJson(output: OutputStream,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit {
        freezeYJsonRuntime()
        writeJsonValueToStream(this, output, options)
    }

    /**
     * 读取当前节点的 JSON 类型。
     *
     * @return 六种 JsonKind 之一。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.object().kind() == JsonKind.Object)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func kind(): JsonKind
    /**
     * 读取容器的直接子项数。
     *
     * @return 数组元素数、对象成员数；标量返回 0。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.array([JsonNode.int64(1)]).size())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public func size(): Int64

    /**
     * 深复制当前树，隔离所有可变子节点。
     *
     * @return 独立可修改树；共享的输入子树会分别复制。
     * @throws JsonException 超出 100,000 节点或 256 层预算，或发现循环；code 分别为 work_limit_exceeded、max_depth 或 cyclic_json_node。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let original = JsonNode.parse("{\"id\":1}")
     * let copy = original.deepCopy()
     * copy["id"] = 2
     * println(original["id"].asInt64() == 1 && copy["id"].asInt64() == 2)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func deepCopy(): JsonNode {
        deepCopyJsonNode(this)
    }

    /**
     * 深复制当前树，隔离所有可变子节点。
     *
     * @return 独立可修改树；共享的输入子树会分别复制。
     * @throws JsonException 超出 100,000 节点或 256 层预算，或发现循环；code 分别为 work_limit_exceeded、max_depth 或 cyclic_json_node。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let original = JsonNode.parse("{\"id\":1}")
     * let copy = original.materialize()
     * copy["id"] = 2
     * println(original["id"].asInt64() == 1 && copy["id"].asInt64() == 2)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func materialize(): JsonNode { deepCopyJsonNode(this) }

    /**
     * 在指定节点预算内深复制当前树。
     *
     * @param maxNodes 正数节点访问上限，包含根节点；深度上限固定为 256。
     * @return 不共享可变子节点的独立树。
     * @throws IllegalArgumentException maxNodes 非正。
     * @throws JsonException 节点预算、深度预算耗尽，或发现循环。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.parse("[1]").materialize(2).toJson())
     * ```
     * ```output
     * [1]
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var code = ""
     * try { let _ = JsonNode.parse("[1]").materialize(1) }
     * catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * work_limit_exceeded
     * ```
     * @group 10-application 应用 API
     */
    public func materialize(maxNodes: Int64): JsonNode {
        deepCopyJsonNode(this, maxNodes)
    }

    /**
     * 按 JSON 数据模型比较两棵树。
     *
     * 数组顺序参与比较。比较使用共享的 100,000 次节点访问预算和 256 层深度上限；对象大小不同等提前判定仍会检查输入循环。
     *
     * @param other 另一棵要比较的树。
     * @return 值等价时返回 true；忽略对象成员顺序，并比较不同数字拼写的数值。
     * @throws JsonException 超出 100,000 节点或 256 层预算，或发现循环；code 分别为 work_limit_exceeded、max_depth 或 cyclic_json_node。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let left = JsonNode.parse("{\"n\":1,\"ok\":true}")
     * let right = JsonNode.parse("{\"ok\":true,\"n\":1.0}")
     * println(left.equivalentTo(right))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func equivalentTo(other: JsonNode): Bool {
        jsonNodesEquivalent(this, other)
    }

    /**
     * 将节点写成缩进 JSON 文本。
     *
     * @return JSON 文本；无参形式每层使用两个空格。
     * @throws IllegalArgumentException 容器的 indent 包含空格、制表符之外的字符。
     * @throws JsonException 循环、非有限数值或默认 256 层写出预算失败。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node = JsonNode.array([JsonNode.int64(1)])
     * println(node.toPrettyString().contains("\n"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func toPrettyString(): String {
        toPrettyString("  ")
    }

    /**
     * 将节点写成缩进 JSON 文本。
     *
     * @param indent 每层缩进；数组和对象只接受空格或制表符，空串为紧凑格式。
     * @return JSON 文本；无参形式每层使用两个空格。
     * @throws IllegalArgumentException 容器的 indent 包含空格、制表符之外的字符。
     * @throws JsonException 循环、非有限数值或默认 256 层写出预算失败。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node = JsonNode.array([JsonNode.int64(1)])
     * println(node.toPrettyString(" ").contains("\n"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func toPrettyString(indent: String): String

    /**
     * 读取布尔值，不进行字符串或数字转换。
     *
     * @return 当前布尔值。
     * @throws JsonException 值不是布尔类型，code 为 type_mismatch。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("true")
     * println(value.asBool())
     * ```
     * ```output
     * true
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var code = ""
     * try { let _ = JsonNode.int64(1).asBool() } catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * type_mismatch
     * ```
     * @group 10-application 应用 API
     */
    public func asBool(): Bool {
        match (this) {
            case value: JsonBoolValue => value.value
            case _ => throw JsonException("Expected boolean value", code: "type_mismatch")
        }
    }

    /**
     * 读取可精确表示为 Int64 的整数。
     *
     * @return Int64 整数；要求整数表示，不接受 1.0 或 1e0 之类的文本，也不截断小数。
     * @throws JsonException 值类型不符或整数文本超出范围。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("42")
     * println(value.asInt64())
     * ```
     * ```output
     * 42
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var code = ""
     * try { let _ = JsonNode.uint64(UInt64.Max).asInt64() }
     * catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * number_out_of_range
     * ```
     * @group 10-application 应用 API
     */
    public func asInt64(): Int64 {
        match (this) {
            case value: JsonIntValue => value.value
            case value: JsonUIntValue =>
                if (value.value > UInt64(Int64.Max)) {
                    throw JsonException("JSON number is outside Int64 range", code: "number_out_of_range")
                }
                Int64(value.value)
            case value: JsonNumberLiteralValue =>
                try { Int64.parse(value.literal) } catch (_: Exception) {
                    throw JsonException("Expected an exact Int64 value", code: "number_out_of_range")
                }
            case _ => throw JsonException("Expected number value", code: "type_mismatch")
        }
    }

    /**
     * 读取可精确表示为 UInt64 的非负整数。
     *
     * @return UInt64 整数；要求非负整数表示，不接受负数、小数或指数写法。
     * @throws JsonException 值类型不符或整数文本超出范围。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("42")
     * println(value.asUInt64())
     * ```
     * ```output
     * 42
     * ```
     * @group 10-application 应用 API
     */
    public func asUInt64(): UInt64 {
        match (this) {
            case value: JsonUIntValue => value.value
            case value: JsonIntValue =>
                if (value.value < 0) {
                    throw JsonException("JSON number is outside UInt64 range", code: "number_out_of_range")
                }
                UInt64(value.value)
            case value: JsonNumberLiteralValue =>
                try { UInt64.parse(value.literal) } catch (_: Exception) {
                    throw JsonException("Expected an exact UInt64 value", code: "number_out_of_range")
                }
            case _ => throw JsonException("Expected number value", code: "type_mismatch")
        }
    }

    /**
     * 将 JSON 数字读取为 Float64。
     *
     * @return 浮点近似值；大整数转换可能舍入。
     * @throws JsonException 值不是数字。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("1.5")
     * println(value.asFloat64() == 1.5)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func asFloat64(): Float64 {
        match (this) {
            case value: JsonFloatValue => value.value
            case value: JsonIntValue => Float64(value.value)
            case value: JsonUIntValue => Float64(value.value)
            case value: JsonNumberLiteralValue => Float64.parse(value.literal)
            case _ => throw JsonException("Expected number value", code: "type_mismatch")
        }
    }

    /**
     * 读取当前数字的 JSON 文本。
     *
     * @return 数字文本；是否保留原始拼写由存储表示决定。
     * @throws JsonException 值不是数字。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.number("1.20e2").asNumberText())
     * ```
     * ```output
     * 1.20e2
     * ```
     * @group 10-application 应用 API
     */
    public func asNumberText(): String {
        match (this) {
            case value: JsonIntValue => value.value.toString()
            case value: JsonUIntValue => value.value.toString()
            case value: JsonFloatValue => ensureFiniteJsonFloat(value.value); value.value.toString()
            case value: JsonNumberLiteralValue => value.literal
            case _ => throw JsonException("Expected number value", code: "type_mismatch")
        }
    }

    /**
     * 读取解码后的字符串。
     *
     * @return 已处理 JSON 转义的字符串；不包含引号。
     * @throws JsonException 值不是字符串，code 为 type_mismatch。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("\"hello\"")
     * println(value.asString())
     * ```
     * ```output
     * hello
     * ```
     * @group 10-application 应用 API
     */
    public func asString(): String {
        match (this) {
            case value: JsonStringValue => value.value
            case _ => throw JsonException("Expected string value", code: "type_mismatch")
        }
    }

    /**
     * 将当前节点作为可修改数组访问。
     *
     * @return 当前容器本身；不复制、不会隔离后续修改。
     * @throws JsonException 当前节点不是所需容器类型，code 为 type_mismatch。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array()
     * let array = node.asArray()
     * array.add(JsonNode.int64(1))
     * println(node.size())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public func asArray(): JsonArray {
        match (this) {
            case value: JsonArray => value
            case _ => throw JsonException("Expected array value", code: "type_mismatch")
        }
    }

    /**
     * 将当前节点作为可修改对象访问。
     *
     * @return 当前容器本身；不复制、不会隔离后续修改。
     * @throws JsonException 当前节点不是所需容器类型，code 为 type_mismatch。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * let object = node.asObject()
     * object.put("id", JsonNode.int64(1))
     * println(node.size())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public func asObject(): JsonObject {
        match (this) {
            case value: JsonObject => value
            case _ => throw JsonException("Expected object value", code: "type_mismatch")
        }
    }

    /**
     * 按从 0 开始的下标查询数组元素。
     *
     * @param index 数组元素下标。
     * @return 存在时返回共享底层存储的视图，越界返回 None。
     * @throws JsonException 当前值不是数组，code 为 type_mismatch。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("[7]")
     * println(value.element(0).getOrThrow().asInt64() == 7 && value.element(1).isNone())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func element(index: Int64): Option<JsonValueView> {
        match (asArray().get(index)) {
            case Some(value) => Some<JsonValueView>(value)
            case None => None<JsonValueView>
        }
    }

    /**
     * 按名称查询对象成员。
     *
     * @param name 解码后的完整成员名。
     * @return 存在时返回共享底层存储的视图，缺少名称返回 None。
     * @throws JsonException 当前值不是对象，code 为 type_mismatch。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("{\"id\":7}")
     * println(value.member("id").getOrThrow().asInt64() == 7 && value.member("absent").isNone())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func member(name: String): Option<JsonValueView> {
        match (asObject().get(name)) {
            case Some(value) => Some<JsonValueView>(value)
            case None => None<JsonValueView>
        }
    }

    /**
     * 按对象成员顺序读取名称。
     *
     * @param index 从 0 开始的成员序号；必须小于 size()。
     * @return 该位置的解码后名称。
     * @throws JsonException 值不是对象或序号越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("{\"id\":7}")
     * println(value.memberName(0))
     * ```
     * ```output
     * id
     * ```
     * @group 10-application 应用 API
     */
    public func memberName(index: Int64): String { asObject().nameAt(index) }
    /**
     * 按对象成员顺序读取值视图。
     *
     * @param index 从 0 开始的成员序号；必须小于 size()。
     * @return 与 memberName(index) 对应的值；共享底层存储。
     * @throws JsonException 值不是对象或序号越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let value: JsonNode = JsonNode.parse("{\"id\":7}")
     * println(value.memberValue(0).asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func memberValue(index: Int64): JsonValueView { asObject().valueAt(index) }

    /**
     * 检查当前节点是否为 JSON 空值。
     *
     * @return null 节点返回 true，其他节点返回 false。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonNode.nullValue.isNull && !JsonNode.boolean(false).isNull)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public prop isNull: Bool {
        get() {
            match (this) {
                case _: JsonNullValue => true
                case _ => false
            }
        }
    }

    /**
     * 读取对象成员；缺失时抛出异常。
     *
     * @param key 对象成员名。
     * @return 共享的子节点；修改该子节点会影响当前树。
     * @throws JsonException 不是对象或名称缺失；缺失 code 为 missing_key。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = 7
     * println(node["id"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String): JsonNode {
        asObject().get(key).getOrThrow({
            => JsonException("Missing object key '${key}'", code: "missing_key")
        })
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。直接共享所传子节点，不复制。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = JsonNode.int64(7)
     * println(node["id"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: JsonNode): Unit {
        asObject().put(key, value)
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = true
     * println(node["id"].asBool())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: Bool): Unit {
        asObject().put(key, value)
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = 7
     * println(node["id"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: Int64): Unit {
        asObject().put(key, value)
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = 1.5
     * println(node["id"].asFloat64() == 1.5)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: Float64): Unit {
        asObject().put(key, value)
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。将值包装为 JSON 节点；Rune 保存为一个字符的字符串。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = r'x'
     * println(node["id"].asString())
     * ```
     * ```output
     * x
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: Rune): Unit {
        asObject().put(key, value)
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = "hello"
     * println(node["id"].asString())
     * ```
     * ```output
     * hello
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: String): Unit {
        asObject().put(key, value)
    }

    /**
     * 设置对象成员。
     *
     * @param key 对象成员名。
     * @param value 替换值。复制外层数组，数组内子节点仍共享。
     * @throws JsonException 当前节点不是对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.object()
     * node["id"] = [JsonNode.int64(7)]
     * println(node["id"].size())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](key: String, value!: Array<JsonNode>): Unit {
        asObject().put(key, jsonNodeValue(value))
    }

    /**
     * 读取数组元素；缺失时抛出异常。
     *
     * @param index 从 0 开始的数组下标。
     * @return 共享的子节点；修改该子节点会影响当前树。
     * @throws JsonException 不是数组或下标越界；越界 code 为 index_out_of_bounds。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = 7
     * println(node[0].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64): JsonNode {
        asArray().get(index).getOrThrow({
            => JsonException("Array index ${index} is out of bounds", code: "index_out_of_bounds")
        })
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。直接共享所传子节点，不复制。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = JsonNode.int64(7)
     * println(node[0].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: JsonNode): Unit {
        asArray().set(index, value)
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = true
     * println(node[0].asBool())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: Bool): Unit {
        asArray().set(index, value)
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = 7
     * println(node[0].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: Int64): Unit {
        asArray().set(index, value)
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = 1.5
     * println(node[0].asFloat64() == 1.5)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: Float64): Unit {
        asArray().set(index, value)
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。将值包装为 JSON 节点；Rune 保存为一个字符的字符串。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = r'x'
     * println(node[0].asString())
     * ```
     * ```output
     * x
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: Rune): Unit {
        asArray().set(index, value)
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。将值包装为 JSON 节点。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = "hello"
     * println(node[0].asString())
     * ```
     * ```output
     * hello
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: String): Unit {
        asArray().set(index, value)
    }

    /**
     * 设置已有数组元素。
     *
     * @param index 从 0 开始的数组下标。
     * @param value 替换值。复制外层数组，数组内子节点仍共享。
     * @throws JsonException 当前节点不是数组，或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node: JsonNode = JsonNode.array([JsonNode.nullValue])
     * node[0] = [JsonNode.int64(7)]
     * println(node[0].size())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public operator func [](index: Int64, value!: Array<JsonNode>): Unit {
        asArray().set(index, jsonNodeValue(value))
    }
}

func jsonNodeValue(value: JsonNode): JsonNode { value }
func jsonNodeValue(value: Bool): JsonNode { JsonBoolValue(value) }
func jsonNodeValue(value: Int64): JsonNode { JsonIntValue(value) }
func jsonNodeValue(value: UInt64): JsonNode { JsonUIntValue(value) }
func jsonNodeValue(value: Float64): JsonNode { JsonFloatValue(value) }
func jsonNodeValue(value: Rune): JsonNode { JsonStringValue(value.toString()) }
func jsonNodeValue(value: String): JsonNode { JsonStringValue(value) }
func jsonNodeValue(value: Array<JsonNode>): JsonNode { JsonArray(value) }
func jsonNodeValue<T>(value: T): JsonNode where T <: GeneratedCodecProviderV1<T> {
    JsonNode.parse(YJson.toJson(value))
}

class JsonNullValue <: JsonNode {
    public func kind(): JsonKind {
        JsonKind.Null
    }

    public func size(): Int64 { 0 }

    public func toString(): String {
        "null"
    }

    public func toPrettyString(indent: String): String {
        let _ = indent
        toString()
    }
}

class JsonBoolValue <: JsonNode {
    public let value: Bool

    public init(value: Bool) {
        this.value = value
    }

    public func kind(): JsonKind {
        JsonKind.Boolean
    }

    public func size(): Int64 { 0 }

    public func toString(): String {
        value.toString()
    }

    public func toPrettyString(indent: String): String {
        let _ = indent
        toString()
    }
}

class JsonIntValue <: JsonNode {
    public let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func kind(): JsonKind {
        JsonKind.Number
    }

    public func size(): Int64 { 0 }

    public func toString(): String {
        value.toString()
    }

    public func toPrettyString(indent: String): String {
        let _ = indent
        toString()
    }
}

class JsonUIntValue <: JsonNode {
    public let value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    public func kind(): JsonKind { JsonKind.Number }
    public func size(): Int64 { 0 }
    public func toString(): String { value.toString() }
    public func toPrettyString(indent: String): String { let _ = indent; toString() }
}

class JsonFloatValue <: JsonNode {
    public let value: Float64

    public init(value: Float64) {
        this.value = value
    }

    public func kind(): JsonKind {
        JsonKind.Number
    }

    public func size(): Int64 { 0 }

    public func toString(): String {
        ensureFiniteJsonFloat(value)
        value.toString()
    }

    public func toPrettyString(indent: String): String {
        let _ = indent
        toString()
    }
}

class JsonNumberLiteralValue <: JsonNode {
    public let literal: String

    public init(literal: String) {
        if (!isValidJsonNumberLiteral(literal)) {
            throw IllegalArgumentException("Invalid JSON number literal: ${literal}")
        }
        this.literal = literal
    }

    private init(literal: String, parsed: Bool) {
        let _ = parsed
        this.literal = literal
    }

    static func fromParsedLiteral(literal: String): JsonNumberLiteralValue {
        JsonNumberLiteralValue(literal, true)
    }

    public func kind(): JsonKind {
        JsonKind.Number
    }

    public func size(): Int64 { 0 }

    public func toString(): String {
        literal
    }

    public func toPrettyString(indent: String): String {
        let _ = indent
        literal
    }
}

func isValidJsonNumberLiteral(literal: String): Bool {
    unsafe {
        let bytes = literal.rawData()
        if (bytes.isEmpty()) { return false }
        var index: Int64 = 0
        if (bytes[index] == b'-') {
            index++
            if (index >= bytes.size) { return false }
        }
        if (bytes[index] == b'0') {
            index++
            if (index < bytes.size && bytes[index] >= b'0' && bytes[index] <= b'9') {
                return false
            }
        } else {
            if (bytes[index] < b'1' || bytes[index] > b'9') { return false }
            index++
            while (index < bytes.size && bytes[index] >= b'0' && bytes[index] <= b'9') { index++ }
        }
        if (index < bytes.size && bytes[index] == b'.') {
            index++
            if (index >= bytes.size || bytes[index] < b'0' || bytes[index] > b'9') { return false }
            while (index < bytes.size && bytes[index] >= b'0' && bytes[index] <= b'9') { index++ }
        }
        if (index < bytes.size && (bytes[index] == b'e' || bytes[index] == b'E')) {
            index++
            if (index < bytes.size && (bytes[index] == b'+' || bytes[index] == b'-')) { index++ }
            if (index >= bytes.size || bytes[index] < b'0' || bytes[index] > b'9') { return false }
            while (index < bytes.size && bytes[index] >= b'0' && bytes[index] <= b'9') { index++ }
        }
        index == bytes.size
    }
}

class JsonStringValue <: JsonNode {
    public let value: String

    public init(value: String) {
        this.value = value
    }

    public func kind(): JsonKind {
        JsonKind.String
    }

    public func size(): Int64 { 0 }

    public func toString(): String {
        let writer = JsonDirectWriter()
        writer.writeString(value)
        writer.finishString()
    }

    public func toPrettyString(indent: String): String {
        let _ = indent
        toString()
    }
}

/**
 * 可修改、保留元素顺序的 JSON 数组。
 *
 * 元素以引用共享；add、set 和 insert 不深复制子节点。允许重复引用，但形成循环后不能序列化、深复制或比较。
 * @group 10-application 应用 API
 */
public class JsonArray <: JsonNode {
    private let items: ArrayList<JsonNode>

    /**
     * 创建空数组。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonArray().size())
     * ```
     * ```output
     * 0
     * ```
     * @group 10-application 应用 API
     */
    public init() {
        items = ArrayList<JsonNode>()
    }

    /**
     * 直接使用现有可变列表作为数组存储。
     *
     * @param items 共享的元素列表；对该列表的后续修改会影响数组。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let items = ArrayList<JsonNode>()
     * let array = JsonArray(items)
     * items.add(JsonNode.int64(7))
     * println(array[0].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public init(items: ArrayList<JsonNode>) {
        this.items = items
    }

    /**
     * 复制外层数组，保留各子节点引用。
     *
     * @param items 要按原顺序保存的子节点。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let child = JsonNode.object()
     * let array = JsonArray([child])
     * child["id"] = 7
     * println(array[0]["id"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public init(items: Array<JsonNode>) {
        this.items = ArrayList<JsonNode>(items)
    }

    /**
     * 读取数组类型标记。
     *
     * @return 数组类型标记 JsonKind.Array。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonArray().kind() == JsonKind.Array)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func kind(): JsonKind {
        JsonKind.Array
    }

    /**
     * 在末尾添加共享的子节点。
     *
     * @param value 要添加的节点；不进行深复制。
     * @return 当前数组，便于链式调用。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonArray().add(JsonNode.int64(7)).toJson())
     * ```
     * ```output
     * [7]
     * ```
     * @group 10-application 应用 API
     */
    public func add(value: JsonNode): JsonArray {
        items.add(value)
        this
    }

    /**
     * 通过类型的生成 codec 转为节点并追加。
     *
     * @param value 实现匹配运行时生成协议的值；编码后重新解析为独立节点。
     * @return 当前数组。
     * @throws JsonException 编码、默认读取预算或解析失败。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let array = JsonArray().add(DocPoint(7))
     * println(array[0]["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func add<T>(value: T): JsonArray where T <: GeneratedCodecProviderV1<T> {
        add(jsonNodeValue(value))
    }

    /**
     * 替换已有位置的元素，不改变数组长度。
     *
     * @param index 从 0 开始、必须小于 size() 的下标。
     * @param value 直接共享的新节点。
     * @return 当前数组。
     * @throws JsonException 下标越界，code 为 index_out_of_bounds。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let array = JsonArray([JsonNode.int64(1)])
     * println(array.set(0, JsonNode.int64(7)).toJson())
     * ```
     * ```output
     * [7]
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var code = ""
     * try { let _ = JsonArray().set(0, JsonNode.int64(1)) }
     * catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * index_out_of_bounds
     * ```
     * @group 10-application 应用 API
     */
    public func set(index: Int64, value: JsonNode): JsonArray {
        if (index < 0 || index >= items.size) {
            throw JsonException("Array index ${index} is out of bounds", code: "index_out_of_bounds")
        }
        items[index] = value
        this
    }

    /**
     * 将生成 codec 的值转为节点并替换已有元素。
     *
     * @param index 从 0 开始、必须小于 size() 的下标。
     * @param value 编码并重新解析的值；不保留对该值的共享引用。
     * @return 当前数组。
     * @throws JsonException 转换失败、默认预算耗尽或下标越界。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let array = JsonArray([JsonNode.nullValue])
     * array.set(0, DocPoint(7))
     * println(array[0]["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func set<T>(index: Int64, value: T): JsonArray where T <: GeneratedCodecProviderV1<T> {
        set(index, jsonNodeValue(value))
    }

    /**
     * 在指定位置插入节点并后移后续元素。
     *
     * @param index 插入位置，允许 0 到 size()，包含末尾。
     * @param value 直接共享的节点。
     * @return 当前数组。
     * @throws JsonException index 小于 0 或大于 size()。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let array = JsonArray([JsonNode.int64(2)])
     * println(array.insert(0, JsonNode.int64(1)).toJson())
     * ```
     * ```output
     * [1,2]
     * ```
     * @group 10-application 应用 API
     */
    public func insert(index: Int64, value: JsonNode): JsonArray {
        if (index < 0 || index > items.size) {
            throw JsonException("Array index ${index} is out of bounds", code: "index_out_of_bounds")
        }
        items.add(value, at: index)
        this
    }

    /**
     * 移除元素并前移后续元素。
     *
     * @param index 从 0 开始的现有元素下标。
     * @return 被移除的原节点；不复制它。
     * @throws JsonException 下标越界，code 为 index_out_of_bounds。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let array = JsonArray([JsonNode.int64(7)])
     * println(array.removeAt(0).asInt64() == 7 && array.size() == 0)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func removeAt(index: Int64): JsonNode {
        if (index < 0 || index >= items.size) {
            throw JsonException("Array index ${index} is out of bounds", code: "index_out_of_bounds")
        }
        items.remove(at: index)
    }

    /**
     * 读取当前数组长度。
     *
     * @return 直接元素个数，不递归统计子节点。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonArray([JsonNode.int64(1), JsonNode.int64(2)]).size())
     * ```
     * ```output
     * 2
     * ```
     * @group 10-application 应用 API
     */
    public func size(): Int64 {
        items.size
    }

    func values(): ArrayList<JsonNode> {
        items
    }

    /**
     * 查询数组元素，越界时返回 None。
     *
     * @param index 从 0 开始的下标。
     * @return 存在时返回共享子节点，否则 None。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let array = JsonArray([JsonNode.int64(7)])
     * println(array.get(0).getOrThrow().asInt64() == 7 && array.get(1).isNone())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func get(index: Int64): Option<JsonNode> {
        items.get(index)
    }

    /**
     * 以紧凑格式序列化数组。
     *
     * @return 完整 JSON 数组文本。
     * @throws JsonException 含循环或非有限数值，或超过默认深度限制。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonArray([JsonNode.int64(7)]).toString())
     * ```
     * ```output
     * [7]
     * ```
     * @group 10-application 应用 API
     */
    public func toString(): String {
        freezeYJsonRuntime()
        writeJsonValueToString(this, JsonWriteOptions.compact)
    }

    /**
     * 按指定缩进序列化数组。
     *
     * @param indent 只含空格或制表符的每层缩进；空串为紧凑格式。
     * @return JSON 数组文本。
     * @throws IllegalArgumentException indent 含其他字符。
     * @throws JsonException 含循环或非有限数值，或超过默认深度限制。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonArray([JsonNode.int64(7)]).toPrettyString(" ").contains("\n"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func toPrettyString(indent: String): String {
        freezeYJsonRuntime()
        writeJsonValueToString(this, JsonWriteOptions.pretty(indent: indent))
    }
}

/**
 * 按成员插入顺序枚举的可修改 JSON 对象。
 *
 * 名称唯一，put 已有名称时更新值并保留原位置。子节点以引用共享；移除后重新插入的名称排在末尾。
 * @group 10-application 应用 API
 */
public class JsonObject <: JsonNode {
    private let fields: HashMap<String, JsonNode>
    private let names: ArrayList<String>

    /**
     * 创建空对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().size())
     * ```
     * ```output
     * 0
     * ```
     * @group 10-application 应用 API
     */
    public init() {
        fields = HashMap<String, JsonNode>()
        names = ArrayList<String>()
    }

    /**
     * 复制给定映射的成员，但共享子节点。
     *
     * @param fields 初始化成员；初始顺序取决于该 HashMap 的迭代顺序。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let fields = HashMap<String, JsonNode>()
     * let child = JsonNode.object()
     * fields.add("child", child)
     * let object = JsonObject(fields)
     * fields.clear()
     * child["id"] = 7
     * println(object["child"]["id"].asInt64() == 7 && object.size() == 1)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public init(fields: HashMap<String, JsonNode>) {
        this.fields = HashMap<String, JsonNode>()
        names = ArrayList<String>()
        for ((name, value) in fields) { put(name, value) }
    }

    /**
     * 读取对象类型标记。
     *
     * @return 对象类型标记 JsonKind.Object。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().kind() == JsonKind.Object)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func kind(): JsonKind {
        JsonKind.Object
    }

    /**
     * 读取当前对象成员数。
     *
     * @return 不同名称的直接成员个数。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().put("id", JsonNode.int64(7)).size())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public func size(): Int64 {
        fields.size
    }

    /**
     * 检查对象是否包含给定名称。
     *
     * @param key 要查询的完整名称。
     * @return 名称存在时为 true，包括值为 null 的成员。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().put("id", JsonNode.nullValue).contains("id"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func contains(key: String): Bool {
        fields.contains(key)
    }

    /**
     * 新增或替换对象成员，直接共享子节点。
     *
     * @param key 解码后的成员名；已有名称保留原顺序。
     * @param value 要保存的子节点，不深复制。
     * @return 当前对象。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let object = JsonObject().put("id", JsonNode.int64(1))
     * println(object.put("id", JsonNode.int64(7)).toJson())
     * ```
     * ```output
     * {"id":7}
     * ```
     * @group 10-application 应用 API
     */
    public func put(key: String, value: JsonNode): JsonObject {
        if (!fields.contains(key)) { names.add(key) }
        fields.add(key, value)
        this
    }

    /**
     * 通过生成 codec 转为节点后保存到对象。
     *
     * @param key 新增或替换的成员名。
     * @param value 编码并重新解析的值；不共享其可变状态。
     * @return 当前对象。
     * @throws JsonException 编码、默认读取预算或解析失败。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let object = JsonObject().put("point", DocPoint(7))
     * println(object["point"]["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func put<T>(key: String, value: T): JsonObject where T <: GeneratedCodecProviderV1<T> {
        put(key, jsonNodeValue(value))
    }

    /**
     * 查询成员，名称缺失时返回 None。
     *
     * @param key 要查询的完整名称。
     * @return 存在时返回共享子节点，否则 None。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let object = JsonObject().put("id", JsonNode.int64(7))
     * println(object.get("id").getOrThrow().asInt64() == 7 && object.get("absent").isNone())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func get(key: String): Option<JsonNode> {
        fields.get(key)
    }

    /**
     * 删除成员及其枚举位置。
     *
     * @param key 要删除的完整名称。
     * @return 存在时返回被移除的原节点，否则 None。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let object = JsonObject().put("id", JsonNode.int64(7))
     * println(object.remove("id").getOrThrow().asInt64() == 7 && !object.contains("id"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func remove(key: String): Option<JsonNode> {
        let removed = fields.remove(key)
        if (removed.isSome()) {
            for (index in 0..names.size) {
                if (names[index] == key) { names.remove(at: index); break }
            }
        }
        removed
    }

    /**
     * 按插入顺序读取名称。
     *
     * @param index 从 0 开始、必须小于 size() 的成员序号。
     * @return 该序号的成员名。
     * @throws JsonException 序号越界，code 为 index_out_of_bounds。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().put("id", JsonNode.int64(7)).nameAt(0))
     * ```
     * ```output
     * id
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var code = ""
     * try { let _ = JsonObject().nameAt(0) } catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * index_out_of_bounds
     * ```
     * @group 10-application 应用 API
     */
    public func nameAt(index: Int64): String {
        names.get(index).getOrThrow({ =>
            JsonException("Object member index ${index} is out of bounds", code: "index_out_of_bounds")
        })
    }

    /**
     * 按插入顺序读取值。
     *
     * @param index 从 0 开始、必须小于 size() 的成员序号。
     * @return 该序号的共享子节点。
     * @throws JsonException 序号越界，code 为 index_out_of_bounds。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().put("id", JsonNode.int64(7)).valueAt(0).asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func valueAt(index: Int64): JsonNode {
        fields.get(nameAt(index)).getOrThrow({ =>
            JsonException("Object member index ${index} is out of bounds", code: "index_out_of_bounds")
        })
    }

    func entries(): HashMap<String, JsonNode> {
        fields
    }

    /**
     * 按成员插入顺序生成紧凑 JSON 文本。
     *
     * @return 完整 JSON 对象文本。
     * @throws JsonException 含循环或非有限数值，或超过默认深度限制。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().put("id", JsonNode.int64(7)).toString())
     * ```
     * ```output
     * {"id":7}
     * ```
     * @group 10-application 应用 API
     */
    public func toString(): String {
        freezeYJsonRuntime()
        writeJsonValueToString(this, JsonWriteOptions.compact)
    }

    /**
     * 按成员插入顺序生成缩进 JSON 文本。
     *
     * @param indent 只含空格或制表符的每层缩进；空串为紧凑格式。
     * @return 完整 JSON 对象文本。
     * @throws IllegalArgumentException indent 含其他字符。
     * @throws JsonException 含循环或非有限数值，或超过默认深度限制。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(JsonObject().put("id", JsonNode.int64(7)).toPrettyString(" ").contains("\n"))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func toPrettyString(indent: String): String {
        freezeYJsonRuntime()
        writeJsonValueToString(this, JsonWriteOptions.pretty(indent: indent))
    }
}


func isJsonHighSurrogate(value: Int64): Bool {
    value >= 0xD800 && value <= 0xDBFF
}

func isJsonLowSurrogate(value: Int64): Bool {
    value >= 0xDC00 && value <= 0xDFFF
}

func combineJsonSurrogates(high: Int64, low: Int64): UInt32 {
    UInt32(0x10000 + ((high - 0xD800) * 0x400) + (low - 0xDC00))
}

func ensureFiniteJsonFloat(value: Float64): Unit {
    if (value.isNaN() || value.isInf()) {
        throw JsonException("Cannot encode non-finite float value")
    }
}


func writeJsonNodeToCodecWriter(writer: JsonWriter, value: JsonNode): Unit {
    writeJsonNodeToCodecWriterGuarded(writer, value, ArrayList<JsonNode>())
}

private func writeJsonNodeToCodecWriterGuarded(
    writer: JsonWriter,
    value: JsonNode,
    ancestors: ArrayList<JsonNode>
): Unit {
    match (value) {
        case _: JsonNullValue => writer.writeNull()
        case boolValue: JsonBoolValue => writer.writeBool(boolValue.value)
        case intValue: JsonIntValue => writer.writeInt64(intValue.value)
        case uintValue: JsonUIntValue => writer.writeUInt64(uintValue.value)
        case floatValue: JsonFloatValue => writer.writeFloat64(floatValue.value)
        case numberValue: JsonNumberLiteralValue => writer.writeNumberLiteral(numberValue.literal)
        case stringValue: JsonStringValue => writer.writeString(stringValue.value)
        case arrayValue: JsonArray =>
            enterJsonNodeAncestor(arrayValue, ancestors)
            writer.startArray()
            try {
                for (item in arrayValue.values()) {
                    writeJsonNodeToCodecWriterGuarded(writer, item, ancestors)
                }
                writer.endArray()
            } finally {
                ancestors.remove(at: ancestors.size - 1)
            }
        case objectValue: JsonObject =>
            enterJsonNodeAncestor(objectValue, ancestors)
            writer.startObject()
            try {
                for (index in 0..objectValue.size()) {
                    writer.writeName(objectValue.nameAt(index))
                    writeJsonNodeToCodecWriterGuarded(writer, objectValue.valueAt(index), ancestors)
                }
                writer.endObject()
            } finally {
                ancestors.remove(at: ancestors.size - 1)
            }
        case _ => throw JsonException("Unsupported JsonNode implementation")
    }
}

func enterJsonNodeAncestor(value: JsonNode, ancestors: ArrayList<JsonNode>): Unit {
    ensureJsonNodeNotAncestor(value, ancestors)
    ancestors.add(value)
}

func ensureJsonNodeNotAncestor(value: JsonNode, ancestors: ArrayList<JsonNode>): Unit {
    for (ancestor in ancestors) {
        if (refEq(value, ancestor)) {
            throw JsonException("Cyclic JsonNode graph is not supported", code: "cyclic_json_node")
        }
    }
}
