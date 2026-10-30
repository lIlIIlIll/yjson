package yjson

import std.collection.*
import std.io.*
import std.math.numeric.*
import std.sync.AtomicOptionReference
import std.time.*

/**
 * 供手写 codec 读取一个 JSON 值的语义接口。
 *
 * 通过 JsonCodec.read 获得 reader。容器必须成对开始与结束；字段名和数组分隔由 reader 管理。读取遵守调用的 JsonReadOptions，错误可带 JSON 路径和源码位置。reader 由 YJson 管理，codec 不应保存或关闭它。
 * @group 10-application 应用 API
 */
public interface JsonReader {
    /**
     * 返回当前值的 JSON 路径。
     *
     * @return 根为 RFC 6901 JSON Pointer 的空串；嵌套值包含字段或数组索引。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.path() == "" )
     *     reader.readInt64()
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func path(): String
    /**
     * 返回当前位置的源码坐标。
     *
     * @return 有源码位置信息时返回坐标，否则为 None。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.location().isSome())
     *     reader.readInt64()
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func location(): Option<JsonLocation>
    /**
     * 构造带当前路径和位置的 JSON 错误；此方法不抛出错误，也不消费输入。
     *
     * @param message 具体错误原因。
     * @param code 可供调用方判断的错误码。
     * @return 带当前读取上下文的异常。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     let problem = reader.error("业务值不符", "business_value")
     *     docRequire(problem.code == "business_value" && problem.path == "" )
     *     reader.readInt64()
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func error(message: String, code: String): JsonException
    /**
     * 消费对象的开始符号并进入对象。
     *
     * @throws JsonException 当前位置不是对象，或容器深度超限。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startObject()
     *     reader.endObject()
     *     7
     * })
     * docRequire(YJson.fromJson("{}", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func startObject(): Unit
    /**
     * 消费对象的结束符号并离开对象。
     *
     * @throws JsonException 容器不匹配、字段值未读完或结束符号缺失。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startObject()
     *     reader.endObject()
     *     7
     * })
     * docRequire(YJson.fromJson("{}", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func endObject(): Unit
    /**
     * 检查当前对象是否还有字段，不消费字段名称。
     *
     * @return 对象尚未到结束符号时为 true。
     * @throws JsonException 当前不在对象中。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startObject()
     *     docRequire(reader.hasObjectField())
     *     docRequire(reader.readName() == "n")
     *     let result = reader.readInt64()
     *     docRequire(!reader.hasObjectField())
     *     reader.endObject()
     *     result
     * })
     * docRequire(YJson.fromJson("{\"n\":7}", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func hasObjectField(): Bool
    /**
     * 消费当前对象的下一个字段名称和冒号。
     *
     * @return 反转义后的字段名称。
     * @throws JsonException 字段语法无效或违反重复键策略。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startObject()
     *     docRequire(reader.readName() == "n")
     *     let result = reader.readInt64()
     *     reader.endObject()
     *     result
     * })
     * docRequire(YJson.fromJson("{\"n\":7}", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readName(): String
    /**
     * 消费数组的开始符号并进入数组。
     *
     * @throws JsonException 当前位置不是数组，或容器深度超限。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startArray()
     *     reader.endArray()
     *     7
     * })
     * docRequire(YJson.fromJson("[]", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func startArray(): Unit
    /**
     * 消费数组的结束符号并离开数组。
     *
     * @throws JsonException 容器不匹配或结束符号缺失。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startArray()
     *     reader.endArray()
     *     7
     * })
     * docRequire(YJson.fromJson("[]", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func endArray(): Unit
    /**
     * 检查当前数组是否还有元素，不消费下一个值。
     *
     * @return 数组尚未到结束符号时为 true。
     * @throws JsonException 当前不在数组中。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.startArray()
     *     docRequire(reader.hasArrayItem())
     *     let result = reader.readInt64()
     *     docRequire(!reader.hasArrayItem())
     *     reader.endArray()
     *     result
     * })
     * docRequire(YJson.fromJson("[7]", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func hasArrayItem(): Bool
    /**
     * 若下一个值为 null 则消费它；其他值保持可读。
     *
     * @return 已消费 null 时为 true，否则为 false。
     * @throws JsonException null 的语法无效或资源限制被触发。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.tryReadNull())
     *     7
     * })
     * docRequire(YJson.fromJson("null", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func tryReadNull(): Bool
    /**
     * 消费一个 JSON null。
     *
     * @throws JsonException 下一个值不是 null。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.readNull()
     *     7
     * })
     * docRequire(YJson.fromJson("null", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readNull(): Unit
    /**
     * 消费一个 JSON 布尔值。
     *
     * @return 对应的 Bool 值。
     * @throws JsonException 下一个值不是 JSON 布尔值。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readBool())
     *     7
     * })
     * docRequire(YJson.fromJson("true", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readBool(): Bool
    /**
     * 消费一个 JSON 字符串并反转义。
     *
     * @return 解码后的字符串。
     * @throws JsonException 字符串、UTF-8 或转义无效，或字符串预算超限。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readString() == "你好")
     *     7
     * })
     * docRequire(YJson.fromJson("\"你好\"", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readString(): String
    /**
     * 消费一个 Int64 范围内的 JSON 整数。
     *
     * @return 有符号整数。
     * @throws JsonException 不是整数或超出 Int64 范围。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.readInt64()
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readInt64(): Int64
    /**
     * 消费一个 UInt64 范围内的非负 JSON 整数。
     *
     * @return 无符号整数。
     * @throws JsonException 数字为负、不是整数或超出 UInt64 范围。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readUInt64() == 7u64)
     *     7
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readUInt64(): UInt64
    /**
     * 消费 JSON 数字并转换为 Float64。
     *
     * @return 转换后的浮点数。
     * @throws JsonException 数字语法无效；数值转换异常可继续传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readFloat64() == 7.0)
     *     7
     * })
     * docRequire(YJson.fromJson("7.0", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readFloat64(): Float64
    /**
     * 消费 JSON 整数并解析为任意精度整数。
     *
     * @return 数字对应的 BigInt。
     * @throws JsonException 输入不是有效数字；数值转换异常可继续传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readBigInt() == BigInt.parse("7"))
     *     7
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readBigInt(): BigInt
    /**
     * 消费 JSON 数字并解析为 Decimal。
     *
     * @return 数字对应的 Decimal。
     * @throws JsonException 输入不是有效数字；数值转换异常可继续传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readDecimal() == Decimal.parse("7.25"))
     *     7
     * })
     * docRequire(YJson.fromJson("7.25", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readDecimal(): Decimal
    /**
     * 消费一个 JSON 数字并保留它的字面文本。
     *
     * @return 未转换成机器数值的数字文本。
     * @throws JsonException 输入不符合 JSON 数字语法。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readNumberLiteral() == "7e2")
     *     7
     * })
     * docRequire(YJson.fromJson("7e2", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readNumberLiteral(): String
    /**
     * 消费并跳过一个完整 JSON 值，继续校验语法和读取预算。
     *
     * @throws JsonException 被跳过的值无效或超出资源限制。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     reader.skipValue()
     *     7
     * })
     * docRequire(YJson.fromJson("{\"nested\":[1,null]}", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func skipValue(): Unit
    /**
     * 消费一个 JSON 值并物化为可变节点树。
     *
     * @return 与输入值对应的 JsonNode。
     * @throws JsonException 输入无效或超出读取预算。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader =>
     *     docRequire(reader.readNode().asInt64() == 7)
     *     7
     * })
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func readNode(): JsonNode
}

/**
 * 保存已捕获的 JSON 值，供生成的多态 codec 查询和重放。
 *
 * 因生成 codec 位于消费方包而公开。实现可使用 JsonNode 或二进制 tape 保存值，通常由捕获方在 finally 中关闭。关闭后查询、重放和 materialize 都会失败；普通应用无需实现此协议。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedReplayValueV1 <: Resource {
    /**
     * 读取捕获的根对象中指定名称的字符串字段。
     *
     * 字段不存在时返回 None。重复键拒绝在捕获时完成；允许 LastWins 时按该策略查找。查询要求根值为对象，匹配字段为字符串。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 待查询的根对象字段名。
     * @return 存在时返回字段字符串，否则返回 None。
     * @throws JsonException 根值不是对象，或匹配字段不是字符串。
     * @throws IllegalStateException 捕获值已经关闭。
     */
    func rootStringField(name: String): Option<String>

    /**
     * 为捕获的根对象创建省略指定字段的新 reader。
     *
     * 省略所有与 name 同名的字段。重复键拒绝已在捕获阶段执行；rootStringField 使用 LastWins 查找。具体实现可复制 tape，或将过滤后的节点重新写为文本再读取。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 在新 reader 中省略的根对象字段名。
     * @return 从过滤后根对象开始读取的新语义 reader。
     * @throws JsonException 根值不是对象，或过滤后的值在重放时超过读取、写出或节点处理限制。
     * @throws IllegalStateException 捕获值已经关闭。
     */
    func openObjectReaderExcluding(name: String): JsonReader

    /**
     * 以 JsonNode 形式取得捕获的完整 JSON 值。
     *
     * 不保证深拷贝：节点实现可返回已捕获节点，tape 实现会从 tape 构造节点。调用方需要独立可变副本时应另外复制。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 包含捕获值的 JsonNode，具体实现可能返回已有节点。
     * @throws JsonException 从捕获表示构造节点时遇到无效数据或资源限制。
     * @throws IllegalStateException 捕获值已经关闭。
     */
    func materialize(): JsonNode
}

/**
 * 供手写 codec 输出一个 JSON 值的语义接口。
 *
 * 通过 JsonCodec.write 获得 writer。对象中先写字段名再写值，容器必须成对开始与结束。调用遵守 JsonWriteOptions；非有限浮点数和非法数值字面量会失败。codec 不负责结束文档或关闭调用方的流。
 * @group 10-application 应用 API
 */
public interface JsonWriter {
    /**
     * 返回当前输出值的 JSON 路径。
     *
     * @return 根为 RFC 6901 JSON Pointer 的空串；嵌套值包含字段或数组索引。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     docRequire(writer.path() == "" )
     *     writer.writeInt64(value)
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func path(): String
    /**
     * 构造带当前输出路径的 JSON 错误；此方法本身不抛出错误。
     *
     * @param message 具体错误原因。
     * @param code 可供调用方判断的错误码。
     * @return 带当前路径的异常。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     let problem = writer.error("业务值不符", "business_value")
     *     docRequire(problem.code == "business_value" && problem.path == "" )
     *     writer.writeInt64(value)
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func error(message: String, code: String): JsonException
    /**
     * 开始一个 JSON 对象。
     *
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.startObject()
     *     writer.endObject()
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "{}")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func startObject(): Unit
    /**
     * 结束当前 JSON 对象。
     *
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.startObject()
     *     writer.endObject()
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "{}")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func endObject(): Unit
    /**
     * 开始一个 JSON 数组。
     *
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.startArray()
     *     writer.endArray()
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "[]")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func startArray(): Unit
    /**
     * 结束当前 JSON 数组。
     *
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.startArray()
     *     writer.endArray()
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "[]")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func endArray(): Unit
    /**
     * 向当前对象写入字段名称，并准备接收一个字段值。
     *
     * @param name 未转义的字段名称，由 writer 负责转义。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.startObject()
     *     writer.writeName("n")
     *     writer.writeInt64(value)
     *     writer.endObject()
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "{\"n\":7}")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeName(name: String): Unit
    /**
     * 写入 JSON null。
     *
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeNull()
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "null")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeNull(): Unit
    /**
     * 写入 JSON 布尔值。
     *
     * @param value 待输出的布尔值。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeBool(true)
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "true")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeBool(value: Bool): Unit
    /**
     * 写入有符号整数的 JSON 数字表示。
     *
     * @param value 待输出的 Int64。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeInt64(value)
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeInt64(value: Int64): Unit
    /**
     * 写入无符号整数的 JSON 数字表示。
     *
     * @param value 待输出的 UInt64。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeUInt64(7u64)
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeUInt64(value: UInt64): Unit
    /**
     * 写入有限浮点数的 JSON 数字表示。
     *
     * @param value 待输出的有限 Float64；NaN 和无穷大会失败。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeFloat64(7.25)
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.fromJson(YJson.toJson(7, codec: codec), codec: JsonCodecs.float64) == 7.25)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeFloat64(value: Float64): Unit
    /**
     * 校验并原样写入一个 JSON 数字字面量。
     *
     * @param value 满足 JSON 数字语法的文本；不接受引号或前后空白。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeNumberLiteral("7e2")
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7e2")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeNumberLiteral(value: String): Unit
    /**
     * 转义并写入一个 JSON 字符串。
     *
     * @param value 未转义的字符串内容。
     * @throws JsonException 输出状态不匹配、值无效或输出预算超限；流的 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer =>
     *     writer.writeString("你好")
     * }, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "\"你好\"")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func writeString(value: String): Unit
}

// Runtime-owned cursor state used only by the matching generated-code SPI.
// It is deliberately absent from JsonCodec, JsonReader, and JsonWriter so
// application codecs never manage mutable path or depth bookkeeping.
/**
 * 暴露 writer 所拥有的生成代码写入状态。
 *
 * GeneratedSupportV1.writeState 通过此协议取得共享状态。状态属于当前 writer，不应在不同写入调用之间共享。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedWriteStateV1Owner {
    /**
     * 返回此 writer 本次写入所使用的共享状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 记录生成代码字段路径、数组下标和遍历深度的状态对象。
     */
    func generatedWriteStateV1(): GeneratedWriteStateV1
}

interface GeneratedReadStateV1Owner {
    func generatedReadStateV1(): GeneratedReadStateV1
}

/**
 * 提供内置 codec 和生成 codec 可选的集合批量写入能力。
 *
 * 返回 true 表示已写入完整集合值，返回 false 要求调用方通过 JsonWriter 的结构接口回退。能力实现仍使用当前 writer 的配置与资源限制。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedBulkWriterV1 {
    /**
     * 尝试将Int64 数组作为完整JSON 数组批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 数组的Int64 数组。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactInt64Array(values: Array<Int64>): Bool
    /**
     * 尝试将Float64 数组作为完整JSON 数组批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。具体 JsonDirectWriter 在发现非有限浮点数时返回 false；结构化回退仍会拒绝该值，tape writer 会在写入时拒绝该值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 数组的Float64 数组。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器拒绝非有限浮点数，或检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactFloat64Array(values: Array<Float64>): Bool
    /**
     * 尝试将字符串数组作为完整JSON 数组批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 数组的字符串数组。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactStringArray(values: Array<String>): Bool
    /**
     * 尝试将Int64 列表作为完整JSON 数组批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 数组的Int64 列表。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactInt64ArrayList(values: ArrayList<Int64>): Bool
    /**
     * 尝试将字符串列表作为完整JSON 数组批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 数组的字符串列表。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactStringArrayList(values: ArrayList<String>): Bool
    /**
     * 尝试将字符串键、Int64 值的映射作为完整JSON 对象批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 对象的字符串键、Int64 值的映射。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactInt64Map(values: HashMap<String, Int64>): Bool
    /**
     * 尝试将字符串键、字符串值的映射作为完整JSON 对象批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 对象的字符串键、字符串值的映射。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactStringMap(values: HashMap<String, String>): Bool
    /**
     * 尝试将字符串键、Int64 数组值的映射作为完整JSON 对象批量写入。
     *
     * 返回 false 时由调用方执行结构化写入回退。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 按当前遍历顺序编码为JSON 对象的字符串键、Int64 数组值的映射。
     * @return 已完成写入时为 true，需要调用方回退时为 false。
     * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
     */
    func tryWriteCompactInt64ArrayMap(values: HashMap<String, Array<Int64>>): Bool
}

/**
 * 尝试通过 writer 的批量能力写入Int64 数组。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 数组的Int64 数组。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactInt64Array(
    writer: JsonWriter,
    values: Array<Int64>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactInt64Array(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入Float64 数组。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。具体 JsonDirectWriter 在发现非有限浮点数时返回 false；结构化回退仍会拒绝该值，tape writer 会在写入时拒绝该值。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 数组的Float64 数组。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器拒绝非有限浮点数，或检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactFloat64Array(
    writer: JsonWriter,
    values: Array<Float64>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactFloat64Array(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入字符串数组。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 数组的字符串数组。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactStringArray(
    writer: JsonWriter,
    values: Array<String>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactStringArray(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入Int64 列表。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 数组的Int64 列表。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactInt64ArrayList(
    writer: JsonWriter,
    values: ArrayList<Int64>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactInt64ArrayList(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入字符串列表。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 数组的字符串列表。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactStringArrayList(
    writer: JsonWriter,
    values: ArrayList<String>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactStringArrayList(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入字符串键、Int64 值的映射。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 对象的字符串键、Int64 值的映射。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactInt64Map(
    writer: JsonWriter,
    values: HashMap<String, Int64>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactInt64Map(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入字符串键、字符串值的映射。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 对象的字符串键、字符串值的映射。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactStringMap(
    writer: JsonWriter,
    values: HashMap<String, String>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactStringMap(values)
        case _ => false
    }
}

/**
 * 尝试通过 writer 的批量能力写入字符串键、Int64 数组值的映射。
 *
 * writer 实现 GeneratedBulkWriterV1 时转发对应方法，否则返回 false。本函数不执行结构化回退。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前集合值的语义 writer，可选实现批量写入协议。
 * @param values 待编码为JSON 对象的字符串键、Int64 数组值的映射。
 * @return 批量实现的结果；writer 未提供该能力时为 false。
 * @throws JsonException 写入器检测到无效状态、深度或输出限制错误。
 */
public func jsonTryWriteCompactInt64ArrayMap(
    writer: JsonWriter,
    values: HashMap<String, Array<Int64>>
): Bool {
    match (writer) {
        case bulk: GeneratedBulkWriterV1 => bulk.tryWriteCompactInt64ArrayMap(values)
        case _ => false
    }
}

/**
 * 定义 T 与一个 JSON 值之间的双向转换。
 *
 * write 和 read 必须采用相同的表示。实现只处理分配给它的一个值，不关闭流，不结束整个文档。YJson 负责验证输入末尾并完成输出。示例使用 core-codec profile 的 DocCallbackCodec，将回调接入真实 YJson reader/writer。
 * @group 10-application 应用 API
 */
public interface JsonCodec<T> {
    /**
     * 写入一个值，保持调用方拥有文档和流的生命周期。
     *
     * @param value 待编码的应用值。
     * @param writer 在当前值位置开始输出的 writer。
     * @throws JsonException JSON 表示不匹配；应用 codec 与 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7")
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func write(value: T, writer: JsonWriter): Unit

    /**
     * 读取分配给此 codec 的一个值，不消费其后的另一个值。
     *
     * @param reader 位于下一个 JSON 值的 reader。
     * @return 解码后的应用值。
     * @throws JsonException JSON 表示不匹配；应用 codec 与 I/O 异常可传播。
     *
     * @example 真实消费方（core-codec） {run}
     * ```cangjie
     * let codec = DocCallbackCodec<Int64>({value, writer => writer.writeInt64(value)}, {reader => reader.readInt64()})
     * docRequire(YJson.toJson(7, codec: codec) == "7")
     * docRequire(YJson.fromJson("7", codec: codec) == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    func read(reader: JsonReader): T
}

/**
 * 提供生成对象的字段写入接口及完整值的读写能力。
 *
 * writeObjectFields 只输出该 codec 所属对象的字段，供继承字段合并和多态分派使用。外围 codec 负责对象边界及该对象的深度记账。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedObjectCodecV1<T> <: JsonCodec<T> {
    /**
     * 向已开始的 JSON 对象写入此 codec 所属类型的字段。
     *
     * 不写对象的开始和结束标记。生成代码根据字段标注处理名称、可选值和字段 codec，并在需要时维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 提供待写字段值的对象。
     * @param writer 当前对象已开始、可继续接收字段的语义写入器。
     * @throws JsonException 字段值不能按其 codec 编码，或写入器检测到无效状态、深度或输出限制。
     */
    func writeObjectFields(value: T, writer: JsonWriter): Unit
}

/**
 * 保留类型参数 T 的无状态生成 codec 标记。
 *
 * 静态 provider 以此标记作为参数，使继承链上的不同 T 可以形成重载。标记不保存 codec 或读写状态。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class GeneratedCodecTokenV1<T> {
    init() {}
}

/**
 * 通过静态方法提供 T 的完整 JSON codec。
 *
 * 供匹配版本的生成代码和运行时进行类型化分派。生成的具体类型和内置类型可以实现此协议；返回的 codec 负责一个完整 JSON 值的表示。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCodecProviderV1<T> {
    /**
     * 返回此类型的完整 JSON codec。
     *
     * 生成的 provider 会核对生成协议版本；内置 provider 返回对应的内置 codec。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param _ 携带 T 类型信息、用于区分静态重载的无状态标记。
     * @return 用于读写一个 T 值的 codec。
     * @throws JsonException 生成的 provider 检测到运行时协议版本不匹配，code 为 generated_protocol_mismatch。
     */
    static func generatedCodecV1(_: GeneratedCodecTokenV1<T>): JsonCodec<T>
}

/**
 * 通过 T 的静态 provider 写入 compact JSON 值。
 *
 * 满足相应类型约束的 YJson 重载可直接调用此方法，保留具体生成 codec 的静态分派。调用流程仍需检查 compact 写入条件，并维护深度、路径和输出限制。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCompactCodecProviderV1<T> {
    /**
     * 通过此类型的生成 codec 直接写入 compact JSON 值。
     *
     * 生成的实现先进入生成代码入口，校验协议并冻结运行时选择，再调用具体 codec 的 writeCompactRawWithWriter。外围流程负责确认 compact 模式并建立写入位置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待编码的 T 值。
     * @param writer 当前调用拥有的具体写入器，已准备写入 compact 值。
     * @throws JsonException 生成协议不匹配、运行时初始化失败、值不能编码，或超过写入深度限制。
     */
    static func generatedCompactRawV1(value: T, writer: JsonDirectWriter): Unit
}

/**
 * 通过静态方法提供具体类型自身的对象 codec。
 *
 * 此协议与完整 codec provider 分开：多态基类 codec 负责子类型选择，具体子类型的对象 codec 暴露其自身字段。继承对象的完整写入流程可组合基类和子类的字段。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedObjectCodecProviderV1<T> {
    /**
     * 返回此类型自身的对象 codec。
     *
     * 生成的 provider 核对生成协议版本后返回具体对象 codec。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param _ 携带 T 类型信息、用于区分静态重载的无状态标记。
     * @return 可读取对象并向已开始的对象写入自身字段的 codec。
     * @throws JsonException 生成的 provider 检测到运行时协议版本不匹配，code 为 generated_protocol_mismatch。
     */
    static func generatedObjectCodecV1(_: GeneratedCodecTokenV1<T>): GeneratedObjectCodecV1<T>
}

/**
 * 调用 T 的静态 provider 获取完整 JSON codec。
 *
 * 构造 GeneratedCodecTokenV1<T> 后直接调用 T.generatedCodecV1，不保存 codec 缓存或执行读写。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @return T 的静态 provider 返回的 codec。
 * @throws JsonException 生成的 provider 检测到运行时协议版本不匹配，code 为 generated_protocol_mismatch。
 */
public func generatedCodecV1Of<T>(): JsonCodec<T> where T <: GeneratedCodecProviderV1<T> {
    T.generatedCodecV1(GeneratedCodecTokenV1<T>())
}

/**
 * 调用 T 的静态 provider 获取其自身的对象 codec。
 *
 * 构造 GeneratedCodecTokenV1<T> 后直接调用 T.generatedObjectCodecV1，供继承字段合并和多态分派使用。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @return T 的静态 provider 返回的对象 codec。
 * @throws JsonException 生成的 provider 检测到运行时协议版本不匹配，code 为 generated_protocol_mismatch。
 */
public func generatedObjectCodecV1Of<T>(): GeneratedObjectCodecV1<T>
    where T <: GeneratedObjectCodecProviderV1<T> {
    T.generatedObjectCodecV1(GeneratedCodecTokenV1<T>())
}

// Kept as an internal optimization surface for the existing built-in codecs.
/**
 * 为 codec 增加匹配版本的 fast reader 读取能力。
 *
 * 运行时和生成代码在支持的读取选项下选择此能力。该协议仍继承 JsonCodec 的语义读写入口，不表示所有调用都使用 fast reader。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCodecV1<T> <: JsonCodec<T> {
    /**
     * 通过匹配版本的 fast reader 解码一个 T 值。
     *
     * 只消费当前值；外围调用负责检查文档末尾。实现需保留与自身语义读取入口一致的值表示，并维护生成读取状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 当前定位在待解码值的匹配版本 reader。
     * @return 从当前 JSON 值解码得到的 T 值。
     * @throws JsonException 输入语法、类型或数值范围不符合 codec 契约，超过读取限制，或生成 reader 与运行时协议不匹配。
     */
    func readFast(reader: GeneratedSupportV1Reader): T
}
/**
 * 为递归 codec 提供具体 JsonFastReader 读取入口。
 *
 * 泛型容器在内层 codec 也提供此能力时直接递归调用。内层缺少该能力时，当前容器实现转到 cursor 读取路径，再按已解析的内层能力调用。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedDirectFastReadCodecV1<T> <: JsonCodec<T> {
    /**
     * 保留具体 reader 类型并解码一个 T 值。
     *
     * 容器实现优先复用内层的具体 reader 能力；缺少该能力时转入自身的 cursor 读取路径。只消费当前值，不检查整个文档末尾。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 当前定位在待解码值的具体 fast reader。
     * @return 从当前 JSON 值解码得到的 T 值。
     * @throws JsonException 输入不符合 codec 的 JSON 表示，超过读取限制，或嵌套 codec 读取失败。
     */
    func readFastDirect(reader: JsonFastReader): T
}

/**
 * 为 codec 提供复用已解析读取 cursor 的入口。
 *
 * 递归调用可向内层传递同一个 cursor。当前容器优先使用内层的 cursor 能力，缺少时调用其匹配版本 fast 入口；生成字段读取也按已解析能力选择对应路径。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCursorReadCodecV1<T> <: JsonCodec<T> {
    /**
     * 使用与 reader 对应的现有 cursor 解码一个 T 值。
     *
     * 调用方传入同一次读取的 reader 和 cursor，递归实现可继续复用 cursor。此方法只消费当前值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 拥有当前读取配置、路径和深度状态的匹配版本 reader。
     * @param cursor 由同一 reader 解析得到、定位在当前值的读取 cursor。
     * @return 从当前 JSON 值解码得到的 T 值。
     * @throws JsonException 输入不符合 codec 的 JSON 表示，超过读取限制，或生成 reader 与运行时协议不匹配。
     */
    func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): T
}

/**
 * 为 codec 增加保留匹配版本 writer 的写入入口。
 *
 * 生成代码通过此入口传递 writer，并按 codec 能力和写入配置选择 compact 或语义写入。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedDirectWriteCodecV1<T> <: JsonCodec<T> {
    /**
     * 通过匹配版本 writer 写入一个 T 值。
     *
     * 生成对象和容器实现会先检查 compact 能力与格式条件；条件不满足时继续使用相同 writer 的语义结构接口。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待编码的 T 值。
     * @param writer 接收当前值并保存本次写入状态的匹配版本 writer。
     * @throws JsonException 值不能按 codec 表示编码，或写入器检测到无效状态、深度或输出限制。
     */
    func writeDirect(value: T, writer: GeneratedSupportV1Writer): Unit
}

/**
 * 为 codec 增加可查询的 compact raw 写入能力。
 *
 * 能力检查覆盖嵌套 codec 是否支持所需写入路径；writer 的格式条件由外围调用另行检查。compact 写入仍须维护编码上下文。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCompactWriteCodecV1<T> <: GeneratedDirectWriteCodecV1<T> {
    /**
     * 报告此 codec 及所需嵌套 codec 是否支持 compact raw 写入。
     *
     * 此查询不检查具体 writer 的缩进、空格或 htmlSafe 配置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 具备所需 compact raw 能力时为 true，否则为 false。
     */
    func supportsCompactRaw(): Bool
    /**
     * 按已确认的能力写入一个 compact raw 值。
     *
     * 调用方须先确认 supportsCompactRaw，并使 writer 处于允许 compact 值的写入位置。此入口不负责选择语义回退路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待编码的 T 值。
     * @param writer 已准备接收 compact raw 值的匹配版本 writer。
     * @throws JsonException 嵌套 compact 能力不可用、值不能编码，或发生深度、写入状态及输出限制错误。
     */
    func writeCompactRaw(value: T, writer: GeneratedSupportV1Writer): Unit
}

/**
 * 为 codec 提供复用现有 writer cursor 的 compact 写入能力。
 *
 * 自定义 codec 和递归 codec 可复用同一个 cursor。调用方先查询能力，并另行检查 writer 是否允许 compact 输出。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCursorWriteCodecV1<T> <: JsonCodec<T> {
    /**
     * 报告此 codec 是否可以使用已有 cursor 写入 compact 值。
     *
     * 当前容器还会根据内层 codec 的对应能力计算结果；此查询不检查具体 writer 的格式配置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 具备所需 cursor compact 写入能力时为 true，否则为 false。
     */
    func supportsCompactCursorWrite(): Bool
    /**
     * 通过与 writer 对应的现有 cursor 写入一个 compact 值。
     *
     * 调用方须先确认 supportsCompactCursorWrite，并准备当前值的 compact 写入位置。递归实现可将同一个 cursor 继续传给内层 codec。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待编码的 T 值。
     * @param writer 拥有本次写入配置、路径和深度状态的匹配版本 writer。
     * @param cursor 由同一 writer 解析得到、接收当前值的写入 cursor。
     * @throws JsonException 嵌套 compact 能力不可用、值不能编码，或发生深度、写入状态及输出限制错误。
     */
    func writeCompactWithCursor(value: T, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit
}

/**
 * 组合生成对象的 compact 写入、cursor 写入和 fast 读取能力。
 *
 * 静态支持 compact 的生成对象可通过一个接口暴露这些能力，供 YJson 的特定重载和泛型容器调用。该接口还增加具体 JsonDirectWriter 的写入入口。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCompactCursorWriteCodecV1<T> <:
    GeneratedCompactWriteCodecV1<T> & GeneratedCursorWriteCodecV1<T> &
    GeneratedCodecV1<T> & GeneratedCursorReadCodecV1<T> {
    /**
     * 使用现有 cursor 输出生成对象的 compact JSON 值。
     *
     * 生成实现增加当前对象的深度，写入对象边界及字段，并在 finally 中归还深度。需要路径信息的嵌套字段在调用前后成对压入和弹出字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 提供待写字段值的对象。
     * @param writer 拥有本次编码状态的匹配版本 writer。
     * @param cursor 由同一 writer 解析得到的写入 cursor。
     * @throws JsonException 字段值不能编码、嵌套 compact 能力不可用，或发生深度、写入状态及输出限制错误。
     */
    func writeCompactRawWithCursor(value: T, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit
    /**
     * 通过具体 JsonDirectWriter 输出生成对象的 compact JSON 值。
     *
     * 生成实现保留具体 writer 类型，写入对象边界及字段，并维护当前对象深度与需要的字段路径。外围流程负责确认 compact 写入条件。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 提供待写字段值的对象。
     * @param writer 已准备接收 compact 值的具体 writer。
     * @throws JsonException 字段值不能编码，或发生深度、写入状态及输出限制错误。
     */
    func writeCompactRawWithWriter(value: T, writer: JsonDirectWriter): Unit
}
/**
 * 为元素 codec 提供整个 ArrayList 的 compact 批量写入入口。
 *
 * ArrayList codec 在构造时解析此可选能力，写入时可让元素 codec 为完整循环复用一个 writer cursor。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedCompactArrayListElementCodecV1<T> {
    /**
     * 将列表写为 compact JSON 数组，并在元素间复用 cursor。
     *
     * 生成实现为数组计入一层深度，按列表顺序写入元素，并维护当前数组下标路径；每个元素仍由该元素 codec 写入。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 按当前列表顺序编码的元素集合。
     * @param writer 已准备接收 compact 数组值的匹配版本 writer。
     * @throws JsonException 元素不能编码，或发生深度、写入状态及输出限制错误。
     */
    func writeCompactRawArrayList(value: ArrayList<T>, writer: GeneratedSupportV1Writer): Unit
}

/**
 * 根据 codec 能力选择匹配版本写入或普通语义写入。
 *
 * codec 实现 GeneratedDirectWriteCodecV1 时调用 writeDirect，否则调用 codec.write。此函数不自行选择 compact 格式，也不结束整个文档。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param codec 决定当前值 JSON 表示的 codec。
 * @param value 待编码的值。
 * @param writer 接收当前值的匹配版本 writer，同时可作为 JsonWriter 使用。
 * @throws JsonException 被调用的 codec 或 writer 拒绝值、状态或资源限制。
 */
public func writeJsonDirectWith<T>(
    codec: JsonCodec<T>,
    value: T,
    writer: GeneratedSupportV1Writer
): Unit {
    match (codec) {
        case direct: GeneratedDirectWriteCodecV1<T> => direct.writeDirect(value, writer)
        case _ => codec.write(value, writer)
    }
}

/**
 * 在 writer 格式允许时为一个 compact raw 值建立写入位置。
 *
 * 直接转发 writer 的对应能力。JsonDirectWriter 在多行、分隔符后带空格或 htmlSafe 模式下返回 false；成功时执行当前值的状态转换并预留 raw 根位置。返回 false 后由调用方选择语义写入。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 即将接收当前值的匹配版本 writer。
 * @return 已建立 compact raw 写入位置时为 true，格式条件不允许时为 false。
 * @throws JsonException writer 已有根值、对象缺少字段名，或当前写入状态无效。
 */
public func jsonTryBeginGeneratedCompactRawValue(writer: GeneratedSupportV1Writer): Bool {
    writer.tryBeginGeneratedCompactRawValue()
}

/**
 * 写入 compact 对象的开始标记。
 *
 * 直接转发 writer 的 raw 容器入口。调用方负责成对结束容器及生成上下文的深度和路径记账。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象的匹配版本 writer。
 * @throws JsonException 超过容器深度限制，或 writer 当前状态不允许开始该值。
 */
public func jsonWriteGeneratedCompactObjectBegin(writer: GeneratedSupportV1Writer): Unit {
    writer.writeRawBeginObject()
}

/**
 * 写入 compact 对象的结束标记。
 *
 * 直接转发 writer 的 raw 容器结束入口。调用方负责与开始标记配对，不能以此代替生成上下文的 leaveValue。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 当前 raw 对象尚未结束的匹配版本 writer。
 * @throws JsonException raw 容器栈为空，或当前写入路径检测到容器结束标记不匹配。
 */
public func jsonWriteGeneratedCompactObjectEnd(writer: GeneratedSupportV1Writer): Unit {
    writer.writeRawEndObject()
}

/**
 * 写入 compact 数组的开始标记。
 *
 * 直接转发 writer 的 raw 容器入口。调用方负责成对结束容器及生成上下文的深度和路径记账。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 数组的匹配版本 writer。
 * @throws JsonException 超过容器深度限制，或 writer 当前状态不允许开始该值。
 */
public func jsonWriteGeneratedCompactArrayBegin(writer: GeneratedSupportV1Writer): Unit {
    writer.writeRawBeginArray()
}

/**
 * 写入 compact 数组的结束标记。
 *
 * 直接转发 writer 的 raw 容器结束入口。调用方负责与开始标记配对，不能以此代替生成上下文的 leaveValue。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 当前 raw 数组尚未结束的匹配版本 writer。
 * @throws JsonException raw 容器栈为空，或当前写入路径检测到容器结束标记不匹配。
 */
public func jsonWriteGeneratedCompactArrayEnd(writer: GeneratedSupportV1Writer): Unit {
    writer.writeRawEndArray()
}

/**
 * 直接向 compact raw 输出写入逗号。
 *
 * 不判断是否为第一个元素，也不更新语义容器计数。调用方负责将逗号放在合法的成员或元素之间。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收 raw 逗号字节的匹配版本 writer。
 */
public func jsonWriteGeneratedCompactComma(writer: GeneratedSupportV1Writer): Unit {
    writer.writeRawByte(b',')
}

/**
 * 写入 compact 对象字段名及冒号，并按需要补逗号。
 *
 * 字段名通过 writer 的字符串转义逻辑写出。调用方随后仍须写入该字段的值，并将返回值保存为下一次调用的 first。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象字段的匹配版本 writer。
 * @param first 当前字段是对象首个输出字段时为 true，否则为 false。
 * @param name 待转义写出的 JSON 字段名。
 * @return false，表示对象已经写入一个字段名。
 */
public func jsonWriteGeneratedCompactObjectEntryName(
    writer: GeneratedSupportV1Writer,
    first: Bool,
    name: String
): Bool {
    writer.writeRawObjectEntryName(first, name)
}

/**
 * 写入 compact 对象的字段名和字符串值。
 *
 * 根据 first 补写逗号，再通过 writer 写出转义后的字段名与对应值。调用方将返回值作为下一字段的 first，并维护需要的字段路径。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象字段的匹配版本 writer。
 * @param first 当前字段是对象首个输出字段时为 true，否则为 false。
 * @param name 待转义写出的 JSON 字段名。
 * @param value 当前字段的字符串值。
 * @return false，表示对象已经写入一个完整字段。
 */
public func jsonWriteGeneratedCompactObjectEntryString(
    writer: GeneratedSupportV1Writer,
    first: Bool,
    name: String,
    value: String
): Bool {
    writer.writeRawObjectEntryNameString(first, name, value)
}

/**
 * 写入 compact 对象的字段名和布尔值。
 *
 * 根据 first 补写逗号，再通过 writer 写出转义后的字段名与对应值。调用方将返回值作为下一字段的 first，并维护需要的字段路径。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象字段的匹配版本 writer。
 * @param first 当前字段是对象首个输出字段时为 true，否则为 false。
 * @param name 待转义写出的 JSON 字段名。
 * @param value 当前字段的布尔值。
 * @return false，表示对象已经写入一个完整字段。
 */
public func jsonWriteGeneratedCompactObjectEntryBool(
    writer: GeneratedSupportV1Writer,
    first: Bool,
    name: String,
    value: Bool
): Bool {
    writer.writeRawObjectEntryNameBool(first, name, value)
}

/**
 * 写入 compact 对象的字段名和Int64 整数值。
 *
 * 根据 first 补写逗号，再通过 writer 写出转义后的字段名与对应值。调用方将返回值作为下一字段的 first，并维护需要的字段路径。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象字段的匹配版本 writer。
 * @param first 当前字段是对象首个输出字段时为 true，否则为 false。
 * @param name 待转义写出的 JSON 字段名。
 * @param value 当前字段的Int64 整数值。
 * @return false，表示对象已经写入一个完整字段。
 */
public func jsonWriteGeneratedCompactObjectEntryInt64(
    writer: GeneratedSupportV1Writer,
    first: Bool,
    name: String,
    value: Int64
): Bool {
    writer.writeRawObjectEntryNameInt64(first, name, value)
}

/**
 * 写入 compact 对象的字段名和UInt64 整数值。
 *
 * 根据 first 补写逗号，再通过 writer 写出转义后的字段名与对应值。调用方将返回值作为下一字段的 first，并维护需要的字段路径。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象字段的匹配版本 writer。
 * @param first 当前字段是对象首个输出字段时为 true，否则为 false。
 * @param name 待转义写出的 JSON 字段名。
 * @param value 当前字段的UInt64 整数值。
 * @return false，表示对象已经写入一个完整字段。
 */
public func jsonWriteGeneratedCompactObjectEntryUInt64(
    writer: GeneratedSupportV1Writer,
    first: Bool,
    name: String,
    value: UInt64
): Bool {
    writer.writeRawObjectEntryNameUInt64(first, name, value)
}

/**
 * 写入 compact 对象的字段名和Float64 数字值。
 *
 * 根据 first 补写逗号，再通过 writer 写出转义后的字段名与对应值。调用方将返回值作为下一字段的 first，并维护需要的字段路径。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param writer 接收当前 raw 对象字段的匹配版本 writer。
 * @param first 当前字段是对象首个输出字段时为 true，否则为 false。
 * @param name 待转义写出的 JSON 字段名。
 * @param value 当前字段的Float64 数字值。
 * @return false，表示对象已经写入一个完整字段。
 * @throws JsonException value 为 NaN 或无穷大，不能表示为 JSON 数字。
 */
public func jsonWriteGeneratedCompactObjectEntryFloat64(
    writer: GeneratedSupportV1Writer,
    first: Bool,
    name: String,
    value: Float64
): Bool {
    writer.writeRawObjectEntryNameFloat64(first, name, value)
}

interface JsonRawWriteCodec<T> <: JsonCodec<T> {
    func writeRaw(value: T, writer: GeneratedSupportV1Writer): Unit
}

private const GENERATED_PATH_MANUAL: UInt8 = 0u8
private const GENERATED_PATH_AUTO_CLAIMABLE: UInt8 = 1u8
private const GENERATED_PATH_AUTO_ACTIVE: UInt8 = 2u8

private class GeneratedPathStateV1 {
    private var values: Array<String>
    private var indices: Array<Int64>
    private var origins: Array<UInt8>
    private var count: Int64 = 0

    init() {
        values = Array<String>(16, repeat: "")
        indices = Array<Int64>(16, repeat: -1)
        origins = Array<UInt8>(16, repeat: 0)
    }

    func size(): Int64 { count }

    private func ensureCapacity(): Unit {
        if (count < values.size) { return }
        let grown = values.size * 2
        let nextValues = Array<String>(grown, repeat: "")
        let nextIndices = Array<Int64>(grown, repeat: -1)
        let nextOrigins = Array<UInt8>(grown, repeat: 0)
        for (position in 0..count) {
            nextValues[position] = values[position]
            nextIndices[position] = indices[position]
            nextOrigins[position] = origins[position]
        }
        values = nextValues
        indices = nextIndices
        origins = nextOrigins
    }

    private func writeSlot(value: String, index: Int64, origin: UInt8): Unit {
        ensureCapacity()
        values[count] = value
        indices[count] = index
        origins[count] = origin
        count++
    }

    func pushField(name: String): Unit {
        if (count > 0 &&
            origins[count - 1] == GENERATED_PATH_AUTO_CLAIMABLE &&
            indices[count - 1] < 0 &&
            values[count - 1] == name) {
            origins[count - 1] = GENERATED_PATH_MANUAL
            return
        }
        writeSlot(name, -1, GENERATED_PATH_MANUAL)
    }

    func pushIndex(index: Int64): Unit {
        if (count > 0 &&
            origins[count - 1] == GENERATED_PATH_AUTO_CLAIMABLE &&
            indices[count - 1] == index) {
            origins[count - 1] = GENERATED_PATH_MANUAL
            return
        }
        writeSlot("", index, GENERATED_PATH_MANUAL)
    }

    func pushAutoField(name: String, baseDepth: Int64): Bool {
        if (count > baseDepth) { return false }
        writeSlot(name, -1, GENERATED_PATH_AUTO_CLAIMABLE)
        true
    }

    func pushAutoIndex(index: Int64, baseDepth: Int64): Bool {
        if (count > baseDepth) { return false }
        writeSlot("", index, GENERATED_PATH_AUTO_CLAIMABLE)
        true
    }

    func beginAutoValue(pushed: Bool): Unit {
        if (pushed && count > 0 && origins[count - 1] == GENERATED_PATH_AUTO_CLAIMABLE) {
            origins[count - 1] = GENERATED_PATH_AUTO_ACTIVE
        }
    }

    func completeAutoValue(pushed: Bool): Unit {
        if (pushed && count > 0 && origins[count - 1] == GENERATED_PATH_AUTO_ACTIVE) {
            count--
        }
    }

    func pop(): Unit { if (count > 0) { count-- } }

    func reset(): Unit { count = 0 }

    func updateLastField(name: String): Unit {
        if (count == 0) { return }
        values[count - 1] = name
        indices[count - 1] = -1
    }

    func updateLastIndex(index: Int64): Unit {
        if (count == 0) { return }
        values[count - 1] = ""
        indices[count - 1] = index
    }

    func pointer(): String {
        if (count == 0) { return "" }
        let result = StringBuilder()
        for (position in 0..count) {
            result.append("/")
            if (indices[position] >= 0) { result.append(indices[position].toString()) }
            else { result.append(jsonPointerEscape(values[position])) }
        }
        result.toString()
    }

}

private struct GeneratedTraversalStateV1 {
    private let maxDepth: Int64
    private var depth: Int64 = 0
    private var path: Option<GeneratedPathStateV1> = None<GeneratedPathStateV1>

    init(maxDepth: Int64) { this.maxDepth = maxDepth }

    mut func pushField(name: String): Unit { pathState().pushField(name) }
    mut func pushIndex(index: Int64): Unit { pathState().pushIndex(index) }
    mut func popPath(): Unit { if (let Some(value) <- path) { value.pop() } }
    mut func updateLastField(name: String): Unit {
        if (let Some(value) <- path) { value.updateLastField(name) }
    }
    mut func updateLastIndex(index: Int64): Unit {
        if (let Some(value) <- path) { value.updateLastIndex(index) }
    }

    func pathDepth(): Int64 { match (path) { case Some(value) => value.size(); case None => 0 } }
    mut func pushAutoField(name: String, baseDepth: Int64): Bool {
        pathState().pushAutoField(name, baseDepth)
    }
    mut func pushAutoIndex(index: Int64, baseDepth: Int64): Bool {
        pathState().pushAutoIndex(index, baseDepth)
    }
    mut func beginAutoValue(pushed: Bool): Unit {
        if (let Some(value) <- path) { value.beginAutoValue(pushed) }
    }
    mut func completeAutoValue(pushed: Bool): Unit {
        if (let Some(value) <- path) { value.completeAutoValue(pushed) }
    }

    mut func enterValue(): Unit {
        if (depth >= maxDepth) {
            throw JsonException("Maximum JSON depth ${maxDepth} exceeded", code: "max_depth", path: currentPath())
        }
        depth++
    }
    mut func leaveValue(): Unit { if (depth > 0) { depth-- } }
    func remainingDepth(): Int64 { maxDepth - depth }
    func currentPath(): String {
        match (path) { case Some(value) => value.pointer(); case None => "" }
    }
    mut func reset(): Unit {
        depth = 0
        match (path) { case Some(value) => value.reset(); case None => () }
    }

    private mut func pathState(): GeneratedPathStateV1 {
        match (path) {
            case Some(value) => value
            case None =>
                let value = GeneratedPathStateV1()
                path = Some(value)
                value
        }
    }
}

/**
 * 记录一次生成代码写入过程的路径与遍历深度。
 *
 * 由配套运行时 writer 创建并持有，深度上限来自本次写入选项。路径与深度分别记账，压入路径不会增加深度；生成代码需成对退出已经进入的值。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class GeneratedWriteStateV1 {
    private var traversal: GeneratedTraversalStateV1

    init(config: JsonWriteOptions) {
        traversal = GeneratedTraversalStateV1(config.maxDepth)
    }

    /**
     * 将字段名加入当前错误路径。
     *
     * 若运行时刚自动压入同名字段位置，则接管该位置，避免重复路径片段；否则追加新片段。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 当前处理字段的 JSON 名称。
     */
    public func pushField(name: String): Unit { traversal.pushField(name) }
    /**
     * 将数组下标加入当前错误路径。
     *
     * 若运行时刚自动压入相同数组位置，则接管该位置，避免重复路径片段；否则追加新片段。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param index 当前处理元素从 0 开始的数组下标。
     */
    public func pushIndex(index: Int64): Unit { traversal.pushIndex(index) }
    /**
     * 移除当前路径的最后一个片段。
     *
     * 路径为空时不执行操作。此方法不减少遍历深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public func popPath(): Unit { traversal.popPath() }
    /**
     * 将当前路径的最后一个片段改为字段名。
     *
     * 用于字段循环复用现有片段；路径为空时不执行操作。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 替换最后一个路径片段的 JSON 字段名。
     */
    public func updateLastField(name: String): Unit { traversal.updateLastField(name) }
    /**
     * 将当前路径的最后一个片段改为数组下标。
     *
     * 用于元素循环复用现有片段；路径为空时不执行操作。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param index 替换最后一个路径片段的从 0 开始的数组下标。
     */
    public func updateLastIndex(index: Int64): Unit { traversal.updateLastIndex(index) }

    func pathDepth(): Int64 { traversal.pathDepth() }
    func pushAutoField(name: String, baseDepth: Int64): Bool {
        traversal.pushAutoField(name, baseDepth)
    }
    func pushAutoIndex(index: Int64, baseDepth: Int64): Bool {
        traversal.pushAutoIndex(index, baseDepth)
    }
    func beginAutoValue(pushed: Bool): Unit { traversal.beginAutoValue(pushed) }
    func completeAutoValue(pushed: Bool): Unit { traversal.completeAutoValue(pushed) }

    /**
     * 在深度上限内进入一层生成值遍历。
     *
     * 先检查当前深度是否已达到选项中的 maxDepth，通过后才增加深度。成功进入后应在 finally 中调用 leaveValue。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前深度已达到 maxDepth，code 为 max_depth，错误携带当前路径。
     */
    public func enterValue(): Unit { traversal.enterValue() }
    /**
     * 退出一层已进入的生成值遍历。
     *
     * 当前深度大于 0 时减 1；深度为 0 时不执行操作。此方法不修改路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public func leaveValue(): Unit { traversal.leaveValue() }
    /**
     * 为一个待写对象进入一层生成值遍历。
     *
     * 当前实现只执行与 enterValue 相同的深度检查和递增，不使用对象身份进行环检测。成功进入后应在 finally 中调用 leaveObject。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 当前待写对象；此参数不参与深度计算。
     * @throws JsonException 当前深度已达到 maxDepth，code 为 max_depth，错误携带当前路径。
     */
    public func enterObject<T>(value: T): Unit { let _ = value; traversal.enterValue() }
    /**
     * 归还 enterObject 计入的一层深度。
     *
     * 当前深度大于 0 时减 1；深度为 0 时不执行操作。此方法不修改字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public func leaveObject(): Unit { traversal.leaveValue() }
    /**
     * 返回当前路径的 JSON Pointer 文本。
     *
     * 根路径为空字符串；字段名中的 ~ 转义为 ~0，/ 转义为 ~1，数组位置使用十进制下标。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 由当前字段和数组位置组成的 JSON Pointer；根位置为 ""。
     */
    public func currentPath(): String { traversal.currentPath() }
    func resetForReuse(): Unit { traversal.reset() }
}

/**
 * 记录一次生成代码读取过程的路径与遍历深度。
 *
 * 由配套运行时 reader 创建并持有，深度上限来自本次读取选项。路径与深度分别记账，压入路径不会增加深度；生成代码需成对退出已经进入的值。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class GeneratedReadStateV1 {
    private var traversal: GeneratedTraversalStateV1

    init(config: JsonReadOptions) {
        traversal = GeneratedTraversalStateV1(config.maxDepth)
    }

    /**
     * 将字段名加入当前错误路径。
     *
     * 若运行时刚自动压入同名字段位置，则接管该位置，避免重复路径片段；否则追加新片段。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 当前处理字段的 JSON 名称。
     */
    public func pushField(name: String): Unit { traversal.pushField(name) }
    /**
     * 将数组下标加入当前错误路径。
     *
     * 若运行时刚自动压入相同数组位置，则接管该位置，避免重复路径片段；否则追加新片段。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param index 当前处理元素从 0 开始的数组下标。
     */
    public func pushIndex(index: Int64): Unit { traversal.pushIndex(index) }
    /**
     * 移除当前路径的最后一个片段。
     *
     * 路径为空时不执行操作。此方法不减少遍历深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public func popPath(): Unit { traversal.popPath() }
    func updateLastField(name: String): Unit { traversal.updateLastField(name) }
    func updateLastIndex(index: Int64): Unit { traversal.updateLastIndex(index) }

    func pathDepth(): Int64 { traversal.pathDepth() }
    func pushAutoField(name: String, baseDepth: Int64): Bool {
        traversal.pushAutoField(name, baseDepth)
    }
    func pushAutoIndex(index: Int64, baseDepth: Int64): Bool {
        traversal.pushAutoIndex(index, baseDepth)
    }
    func beginAutoValue(pushed: Bool): Unit { traversal.beginAutoValue(pushed) }
    func completeAutoValue(pushed: Bool): Unit { traversal.completeAutoValue(pushed) }

    /**
     * 在深度上限内进入一层生成值遍历。
     *
     * 先检查当前深度是否已达到选项中的 maxDepth，通过后才增加深度。成功进入后应在 finally 中调用 leaveValue。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前深度已达到 maxDepth，code 为 max_depth，错误携带当前路径。
     */
    public func enterValue(): Unit { traversal.enterValue() }
    /**
     * 退出一层已进入的生成值遍历。
     *
     * 当前深度大于 0 时减 1；深度为 0 时不执行操作。此方法不修改路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public func leaveValue(): Unit { traversal.leaveValue() }
    /**
     * 返回当前生成值遍历尚可进入的层数。
     *
     * 结果为配置的 maxDepth 减去已进入且尚未退出的层数，不表示剩余节点数或未读取输入的实际深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 本次读取的深度上限减去当前遍历深度。
     */
    public func remainingDepth(): Int64 { traversal.remainingDepth() }
    /**
     * 返回当前路径的 JSON Pointer 文本。
     *
     * 根路径为空字符串；字段名中的 ~ 转义为 ~0，/ 转义为 ~1，数组位置使用十进制下标。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 由当前字段和数组位置组成的 JSON Pointer；根位置为 ""。
     */
    public func currentPath(): String { traversal.currentPath() }
}

private func jsonPointerEscape(value: String): String {
    value.replace("~", "~0").replace("/", "~1")
}

class LambdaFastRawJsonCodec<T> <: GeneratedCodecV1<T> &
    GeneratedCursorReadCodecV1<T> & GeneratedCursorWriteCodecV1<T> & JsonRawWriteCodec<T> {
    private let writerFn: (T, JsonWriter) -> Unit
    private let readerFn: (JsonReader) -> T
    private let fastReaderFn: (JsonFastReader) -> T
    private let rawWriterFn: (T, JsonDirectWriter) -> Unit

    public init(
        writerFn: (T, JsonWriter) -> Unit,
        readerFn: (JsonReader) -> T,
        fastReaderFn: (JsonFastReader) -> T,
        rawWriterFn: (T, JsonDirectWriter) -> Unit
    ) {
        this.writerFn = writerFn
        this.readerFn = readerFn
        this.fastReaderFn = fastReaderFn
        this.rawWriterFn = rawWriterFn
    }

    public func write(value: T, writer: JsonWriter): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        let _ = context
        match (writer) {
            case direct: JsonDirectWriter =>
                if (direct.canWriteRawCompactValue()) {
                    rawWriterFn(value, direct)
                } else {
                    writerFn(value, writer)
                }
            case _ => writerFn(value, writer)
        }
    }

    public func writeRaw(value: T, writer: GeneratedSupportV1Writer): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        rawWriterFn(value, yJsonGeneratedWriterV1(writer))
    }

    public func supportsCompactCursorWrite(): Bool { true }

    public func writeCompactWithCursor(value: T, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = writer
        rawWriterFn(value, cursor.generatedWriterV1())
    }

    public func read(reader: JsonReader): T {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        let _ = context
        readerFn(reader)
    }

    public func readFast(reader: GeneratedSupportV1Reader): T {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        let _ = context
        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): T {
        let context = GeneratedSupportV1.readState(reader)
        let _ = context
        fastReaderFn(cursor.generatedReaderV1())
    }
}

/**
 * 要求 codec 通过匹配版本的 fast 入口解码当前值。
 *
 * 先取得运行时读取状态，再检查 codec 是否实现 GeneratedCodecV1。缺少该能力时抛出错误，不自动调用语义 read，也不检查文档末尾。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param codec 必须提供 GeneratedCodecV1 读取能力的 codec。
 * @param reader 定位在当前值、由匹配运行时拥有的生成 reader。
 * @return fast 入口从当前 JSON 值解码得到的值。
 * @throws JsonException codec 缺少 fast 能力时 code 为 codec_contract；reader 协议不匹配或实际解码失败时也会抛出。
 */
public func readJsonFastWith<T>(codec: JsonCodec<T>, reader: GeneratedSupportV1Reader): T {
    let context = GeneratedSupportV1.readState(reader)
    match (codec) {
        case fast: GeneratedCodecV1<T> => fast.readFast(reader)
        case _ => throw JsonException("Codec does not provide a fast-reader implementation",
            code: "codec_contract", path: context.currentPath())
    }
}

func readJsonNestedFastWith<T>(codec: JsonCodec<T>, reader: GeneratedSupportV1Reader): T {
    match (codec) {
        case direct: GeneratedDirectFastReadCodecV1<T> =>
            direct.readFastDirect(GeneratedSupportV1.readFastReader(reader))
        case fast: GeneratedCodecV1<T> => fast.readFast(reader)
        case _ => codec.read(yJsonSemanticReaderV1(reader))
    }
}


func readJsonNestedFastWithCursor<T>(codec: JsonCodec<T>, reader: GeneratedSupportV1Reader,
    cursor: GeneratedSupportV1ReadCursor): T {
    match (codec) {
        case fast: GeneratedCursorReadCodecV1<T> => fast.readFastWithCursor(reader, cursor)
        case legacy: GeneratedCodecV1<T> => legacy.readFast(reader)
        case _ => codec.read(yJsonSemanticReaderV1(reader))
    }
}

private class ContractFastCodecAdapter<T> <: GeneratedCodecV1<T> {
    private let inner: JsonCodec<T>

    public init(inner: JsonCodec<T>) {
        this.inner = inner
    }

    public func write(value: T, writer: JsonWriter): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        inner.write(value, writer)
    }

    public func read(reader: JsonReader): T {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        inner.read(reader)
    }

    public func readFast(reader: GeneratedSupportV1Reader): T {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        readJsonNestedFastWith(inner, reader)
    }
}

private func resolvedGeneratedCodecV1<T>(codec: JsonCodec<T>): GeneratedCodecV1<T> {
    match (codec) {
        case fast: GeneratedCodecV1<T> => fast
        case _ => ContractFastCodecAdapter<T>(codec)
    }
}

private class OptionJsonCodec<T> <: GeneratedCodecV1<Option<T>> &
    GeneratedCursorReadCodecV1<Option<T>> & GeneratedCompactWriteCodecV1<Option<T>> &
    GeneratedCursorWriteCodecV1<Option<T>> {
    private let inner: JsonCodec<T>
    private let directInner: Option<GeneratedDirectWriteCodecV1<T>>
    private let compactRawInner: Option<GeneratedCompactWriteCodecV1<T>>
    private let cursorReadInner: Option<GeneratedCursorReadCodecV1<T>>
    private let cursorWriteInner: Option<GeneratedCursorWriteCodecV1<T>>

    public init(inner: JsonCodec<T>) {
        this.inner = inner
        this.directInner = match (inner) {
            case direct: GeneratedDirectWriteCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectWriteCodecV1<T>>
        }
        this.compactRawInner = match (inner) {
            case raw: GeneratedCompactWriteCodecV1<T> => Some(raw)
            case _ => None<GeneratedCompactWriteCodecV1<T>>
        }
        this.cursorReadInner = match (inner) {
            case cursor: GeneratedCursorReadCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorReadCodecV1<T>>
        }
        this.cursorWriteInner = match (inner) {
            case cursor: GeneratedCursorWriteCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorWriteCodecV1<T>>
        }
    }

    public func write(value: Option<T>, writer: JsonWriter): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        match (writer) {
            case direct: JsonDirectWriter =>
                writeDirect(value, direct)
                return
            case _ => ()
        }
        match (value) {
            case Some(item) => inner.write(item, writer)
            case None => writer.writeNull()
        }
    }

    public func writeDirect(value: Option<T>, writer: GeneratedSupportV1Writer): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        if (supportsCompactRaw() && writer.tryBeginGeneratedCompactRawValue()) {
            writeCompactRaw(value, writer)
            return
        }
        match (value) {
            case Some(item) =>
                match (directInner) {
                    case Some(direct) => direct.writeDirect(item, writer)
                    case None => inner.write(item, writer)
                }
            case None => writer.writeNull()
        }
    }

    public func supportsCompactRaw(): Bool {
        if (let Some(cursor) <- cursorWriteInner) {
            return cursor.supportsCompactCursorWrite()
        }
        match (compactRawInner) {
            case Some(raw) => raw.supportsCompactRaw()
            case None => false
        }
    }

    public func writeCompactRaw(value: Option<T>, writer: GeneratedSupportV1Writer): Unit {

        writeCompactWithCursor(value, writer, GeneratedSupportV1.writeCursor(writer))
    }

    public func supportsCompactCursorWrite(): Bool { supportsCompactRaw() }

    public func writeCompactWithCursor(value: Option<T>, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        match (value) {
            case Some(item) =>
                match (cursorWriteInner) {
                    case Some(raw) => raw.writeCompactWithCursor(item, writer, cursor)
                    case None => match (compactRawInner) {
                        case Some(raw) => raw.writeCompactRaw(item, writer)
                        case None => throw JsonException("Compact raw codec is unavailable")
                    }
                }
            case None => cursor.writeRawNull()
        }
    }

    public func read(reader: JsonReader): Option<T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        if (reader.tryReadNull()) {
            return None<T>
        }
        Some(inner.read(reader))
    }

    public func readFast(reader: GeneratedSupportV1Reader): Option<T> {

        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): Option<T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        if (cursor.tryReadRawNull()) {
            return None<T>
        }
        match (cursorReadInner) {
            case Some(fast) => Some(fast.readFastWithCursor(reader, cursor))
            case None => Some(readJsonNestedFastWith(inner, reader))
        }
    }
}

private class StringOptionJsonCodec <: GeneratedCodecV1<Option<String>> &
    GeneratedCursorReadCodecV1<Option<String>> & GeneratedCursorWriteCodecV1<Option<String>> {
    public func write(value: Option<String>, writer: JsonWriter): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        let _ = context
        let _ = context
        match (value) {
            case Some(item) => writer.writeString(item)
            case None => writer.writeNull()
        }
    }

    public func read(reader: JsonReader): Option<String> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        let _ = context
        if (reader.tryReadNull()) {
            return None<String>
        }
        Some(reader.readString())
    }

    public func readFast(reader: GeneratedSupportV1Reader): Option<String> {

        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): Option<String> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        let _ = context
        if (cursor.tryReadRawNull()) {
            return None<String>
        }
        Some(cursor.readRawString())
    }

    public func supportsCompactCursorWrite(): Bool { true }

    public func writeCompactWithCursor(value: Option<String>, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = writer
        match (value) {
            case Some(item) => cursor.writeRawString(item)
            case None => cursor.writeRawNull()
        }
    }
}

private class Int64ArrayJsonCodec <: GeneratedCodecV1<Array<Int64>> &
    GeneratedCursorReadCodecV1<Array<Int64>> & GeneratedCompactWriteCodecV1<Array<Int64>> &
    GeneratedCursorWriteCodecV1<Array<Int64>> {
    public func write(value: Array<Int64>, writer: JsonWriter): Unit {
        match (writer) {
            case direct: GeneratedSupportV1Writer => writeDirect(value, direct)
            case _ => writeStructural(value, writer)
        }
    }

    private func writeStructural(value: Array<Int64>, writer: JsonWriter): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            writer.startArray()
            for (item in value) { writer.writeInt64(item) }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func writeDirect(value: Array<Int64>, writer: GeneratedSupportV1Writer): Unit {
        if (jsonTryWriteCompactInt64Array(writer, value)) { return }
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            writer.startArray()
            for (item in value) { writer.writeInt64(item) }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactRaw(): Bool { true }

    public func writeCompactRaw(value: Array<Int64>, writer: GeneratedSupportV1Writer): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            if (!jsonTryWriteCompactInt64Array(writer, value)) {
                throw JsonException("Compact raw codec is unavailable")
            }
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactCursorWrite(): Bool { true }

    public func writeCompactWithCursor(value: Array<Int64>, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = cursor
        writeCompactRaw(value, writer)
    }

    public func read(reader: JsonReader): Array<Int64> {
        ArrayJsonCodec<Int64>(Int64Json).read(reader)
    }

    public func readFast(reader: GeneratedSupportV1Reader): Array<Int64> {
        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): Array<Int64> {
        let context = GeneratedSupportV1.readState(reader)
        context.enterValue()
        try {
            if (let Some(result) <- yJsonTryReadNativeInt64ArrayListV1(reader)) {
                return result.toArray()
            }
            cursor.startRawArray()
            if (!cursor.hasRawArrayItem(true)) {
                cursor.endRawArray()
                return Array<Int64>()
            }
            let result = ArrayList<Int64>(cursor.suggestRawArrayCapacity())
            var first = true
            while (cursor.hasRawArrayItem(first)) {
                cursor.beforeRawArrayItem(first)
                result.add(cursor.readRawInt64())
                first = false
            }
            cursor.endRawArray()
            return result.toArray()
        } finally {
            context.leaveValue()
        }
    }
}

private class ArrayJsonCodec<T> <: GeneratedCodecV1<Array<T>> &
    GeneratedDirectFastReadCodecV1<Array<T>> &
    GeneratedCursorReadCodecV1<Array<T>> & GeneratedCompactWriteCodecV1<Array<T>> &
    GeneratedCursorWriteCodecV1<Array<T>> {
    private let inner: JsonCodec<T>
    private let fastInner: GeneratedCodecV1<T>
    private let directFastInner: Option<GeneratedDirectFastReadCodecV1<T>>
    private let directInner: Option<GeneratedDirectWriteCodecV1<T>>
    private let compactRawInner: Option<GeneratedCompactWriteCodecV1<T>>
    private let cursorReadInner: Option<GeneratedCursorReadCodecV1<T>>
    private let cursorWriteInner: Option<GeneratedCursorWriteCodecV1<T>>

    public init(inner: JsonCodec<T>) {
        this.inner = inner
        this.fastInner = resolvedGeneratedCodecV1(inner)
        this.directFastInner = match (inner) {
            case direct: GeneratedDirectFastReadCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectFastReadCodecV1<T>>
        }
        this.directInner = match (inner) {
            case direct: GeneratedDirectWriteCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectWriteCodecV1<T>>
        }
        this.compactRawInner = match (inner) {
            case raw: GeneratedCompactWriteCodecV1<T> => Some(raw)
            case _ => None<GeneratedCompactWriteCodecV1<T>>
        }
        this.cursorReadInner = match (inner) {
            case cursor: GeneratedCursorReadCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorReadCodecV1<T>>
        }
        this.cursorWriteInner = match (inner) {
            case cursor: GeneratedCursorWriteCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorWriteCodecV1<T>>
        }
    }

    public func write(value: Array<T>, writer: JsonWriter): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        match (writer) {
            case direct: JsonDirectWriter =>
                writeDirect(value, direct)
                return
            case _ => ()
        }
        context.enterValue()
        try {
            writer.startArray()
            if (!value.isEmpty()) {
                context.pushIndex(0)
                try {
                    for (index in 0..value.size) {
                        if (index > 0) {
                            context.updateLastIndex(index)
                        }
                        inner.write(value[index], writer)
                    }
                } finally {
                    context.popPath()
                }
            }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func writeDirect(value: Array<T>, writer: GeneratedSupportV1Writer): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        if (supportsCompactRaw() && writer.tryBeginGeneratedCompactRawValue()) {
            writeCompactRaw(value, writer)
            return
        }
        context.enterValue()
        try {
            writer.startArray()
            if (!value.isEmpty()) {
                context.pushIndex(0)
                try {
                    for (index in 0..value.size) {
                        if (index > 0) {
                            context.updateLastIndex(index)
                        }
                        match (directInner) {
                            case Some(direct) => direct.writeDirect(value[index], writer)
                            case None => inner.write(value[index], writer)
                        }
                    }
                } finally {
                    context.popPath()
                }
            }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactRaw(): Bool {
        if (let Some(cursor) <- cursorWriteInner) {
            return cursor.supportsCompactCursorWrite()
        }
        match (compactRawInner) {
            case Some(raw) => raw.supportsCompactRaw()
            case None => false
        }
    }

    public func writeCompactRaw(value: Array<T>, writer: GeneratedSupportV1Writer): Unit {

        writeCompactWithCursor(value, writer, GeneratedSupportV1.writeCursor(writer))
    }

    public func supportsCompactCursorWrite(): Bool { supportsCompactRaw() }

    public func writeCompactWithCursor(value: Array<T>, writer: GeneratedSupportV1Writer,
        rawWriter: GeneratedSupportV1WriteCursor): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        context.enterValue()
        try {
            rawWriter.reserveRawCollectionCapacity(value.size)
            rawWriter.writeRawBeginArray()
            if (!value.isEmpty()) {
                // writeCompactRaw is reachable only after supportsCompactRaw
                // has confirmed this invariant.
                context.pushIndex(0)
                try {
                    for (index in 0..value.size) {
                        if (index > 0) {
                            rawWriter.writeRawByte(b',')
                            context.updateLastIndex(index)
                        }
                        match (cursorWriteInner) {
                            case Some(raw) => raw.writeCompactWithCursor(value[index], writer, rawWriter)
                            case None => compactRawInner.getOrThrow().writeCompactRaw(value[index], writer)
                        }
                    }
                } finally {
                    context.popPath()
                }
            }
            rawWriter.writeRawEndArray()
        } finally {
            context.leaveValue()
        }
    }

    public func read(reader: JsonReader): Array<T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            let result = ArrayList<T>()
            reader.startArray()
            var index: Int64 = 0
            while (reader.hasArrayItem()) {
                context.pushIndex(index)
                try {
                    result.add(inner.read(reader))
                } finally {
                    context.popPath()
                }
                index++
            }
            reader.endArray()
            return result.toArray()
        } finally {
            context.leaveValue()
        }
    }

    public func readFast(reader: GeneratedSupportV1Reader): Array<T> {
        readFastDirect(GeneratedSupportV1.readFastReader(reader))
    }

    public func readFastDirect(reader: JsonFastReader): Array<T> {
        let directFast = match (directFastInner) {
            case Some(value) => value
            case None => return readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
        }
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawArray()
            if (!reader.hasRawArrayItem(true)) {
                reader.endRawArray()
                return Array<T>()
            }
            let capacity = reader.suggestRawCollectionCapacity()
            let result = if (capacity > 4) {
                ArrayList<T>(capacity)
            } else {
                ArrayList<T>()
            }
            var first = true
            var index: Int64 = 0
            context.pushIndex(index)
            try {
                while (reader.hasRawArrayItem(first)) {
                    reader.beforeRawArrayItem(first)
                    if (!first) {
                        context.updateLastIndex(index)
                    }
                    result.add(directFast.readFastDirect(reader))
                    first = false
                    index++
                }
            } finally {
                context.popPath()
            }
            reader.endRawArray()
            return result.toArray()
        } finally {
            context.leaveValue()
        }
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): Array<T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            cursor.startRawArray()
            if (!cursor.hasRawArrayItem(true)) {
                cursor.endRawArray()
                return Array<T>()
            }
            let capacity = cursor.suggestRawCollectionCapacity()
            let result = if (capacity > 4) {
                ArrayList<T>(capacity)
            } else {
                ArrayList<T>()
            }
            var first = true
            var index: Int64 = 0
            if (cursor.hasRawArrayItem(first)) {
                context.pushIndex(index)
                try {
                    while (true) {
                        cursor.beforeRawArrayItem(first)
                        if (!first) {
                            context.updateLastIndex(index)
                        }
                        match (cursorReadInner) {
                            case Some(fast) => result.add(fast.readFastWithCursor(reader, cursor))
                            case None => result.add(fastInner.readFast(reader))
                        }
                        first = false
                        index++
                        if (!cursor.hasRawArrayItem(first)) {
                            break
                        }
                    }
                } finally {
                    context.popPath()
                }
            }
            cursor.endRawArray()
            return result.toArray()
        } finally {
            context.leaveValue()
        }
    }
}

private class ArrayListJsonCodec<T> <: GeneratedCodecV1<ArrayList<T>> &
    GeneratedDirectFastReadCodecV1<ArrayList<T>> &
    GeneratedCursorReadCodecV1<ArrayList<T>> & GeneratedCompactWriteCodecV1<ArrayList<T>> &
    GeneratedCursorWriteCodecV1<ArrayList<T>> {
    private let inner: JsonCodec<T>
    private let fastInner: GeneratedCodecV1<T>
    private let directFastInner: Option<GeneratedDirectFastReadCodecV1<T>>
    private let directInner: Option<GeneratedDirectWriteCodecV1<T>>
    private let compactRawInner: Option<GeneratedCompactWriteCodecV1<T>>
    private let compactRawArrayListInner: Option<GeneratedCompactArrayListElementCodecV1<T>>
    private let cursorReadInner: Option<GeneratedCursorReadCodecV1<T>>
    private let cursorWriteInner: Option<GeneratedCursorWriteCodecV1<T>>

    public init(inner: JsonCodec<T>) {
        this.inner = inner
        this.fastInner = resolvedGeneratedCodecV1(inner)
        this.directFastInner = match (inner) {
            case direct: GeneratedDirectFastReadCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectFastReadCodecV1<T>>
        }
        this.directInner = match (inner) {
            case direct: GeneratedDirectWriteCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectWriteCodecV1<T>>
        }
        this.compactRawInner = match (inner) {
            case raw: GeneratedCompactWriteCodecV1<T> => Some(raw)
            case _ => None<GeneratedCompactWriteCodecV1<T>>
        }
        this.compactRawArrayListInner = match (inner) {
            case bulk: GeneratedCompactArrayListElementCodecV1<T> => Some(bulk)
            case _ => None<GeneratedCompactArrayListElementCodecV1<T>>
        }
        this.cursorReadInner = match (inner) {
            case cursor: GeneratedCursorReadCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorReadCodecV1<T>>
        }
        this.cursorWriteInner = match (inner) {
            case cursor: GeneratedCursorWriteCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorWriteCodecV1<T>>
        }
    }

    public func write(value: ArrayList<T>, writer: JsonWriter): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        match (writer) {
            case direct: JsonDirectWriter =>
                writeDirect(value, direct)
                return
            case _ => ()
        }
        context.enterValue()
        try {
            writer.startArray()
            var index: Int64 = 0
            if (!value.isEmpty()) {
                context.pushIndex(0)
                try {
                    for (position in 0..value.size) {
                        if (index > 0) {
                            context.updateLastIndex(index)
                        }
                        inner.write(value[position], writer)
                        index++
                    }
                } finally {
                    context.popPath()
                }
            }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func writeDirect(value: ArrayList<T>, writer: GeneratedSupportV1Writer): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        if (supportsCompactRaw() && writer.tryBeginGeneratedCompactRawValue()) {
            writeCompactRaw(value, writer)
            return
        }
        context.enterValue()
        try {
            writer.startArray()
            var index: Int64 = 0
            if (!value.isEmpty()) {
                context.pushIndex(0)
                try {
                    for (position in 0..value.size) {
                        if (index > 0) {
                            context.updateLastIndex(index)
                        }
                        match (directInner) {
                            case Some(direct) => direct.writeDirect(value[position], writer)
                            case None => inner.write(value[position], writer)
                        }
                        index++
                    }
                } finally {
                    context.popPath()
                }
            }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactRaw(): Bool {
        if (let Some(cursor) <- cursorWriteInner) {
            return cursor.supportsCompactCursorWrite()
        }
        match (compactRawInner) {
            case Some(raw) => raw.supportsCompactRaw()
            case None => false
        }
    }

    public func writeCompactRaw(value: ArrayList<T>, writer: GeneratedSupportV1Writer): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        if (let Some(bulk) <- compactRawArrayListInner) {
            bulk.writeCompactRawArrayList(value, writer)
            return
        }
        writeCompactWithCursor(value, writer, GeneratedSupportV1.writeCursor(writer))
    }

    public func supportsCompactCursorWrite(): Bool { supportsCompactRaw() }

    public func writeCompactWithCursor(value: ArrayList<T>, writer: GeneratedSupportV1Writer,
        rawWriter: GeneratedSupportV1WriteCursor): Unit {

        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            rawWriter.reserveRawCollectionCapacity(value.size)
            rawWriter.writeRawBeginArray()
            var index: Int64 = 0
            if (!value.isEmpty()) {
                // writeCompactRaw is reachable only after supportsCompactRaw
                // has confirmed this invariant.
                context.pushIndex(0)
                try {
                    for (position in 0..value.size) {
                        if (index > 0) {
                            rawWriter.writeRawByte(b',')
                            context.updateLastIndex(index)
                        }
                        match (cursorWriteInner) {
                            case Some(raw) => raw.writeCompactWithCursor(value[position], writer, rawWriter)
                            case None => compactRawInner.getOrThrow().writeCompactRaw(value[position], writer)
                        }
                        index++
                    }
                } finally {
                    context.popPath()
                }
            }
            rawWriter.writeRawEndArray()
        } finally {
            context.leaveValue()
        }
    }

    public func read(reader: JsonReader): ArrayList<T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            let result = ArrayList<T>()
            reader.startArray()
            var index: Int64 = 0
            while (reader.hasArrayItem()) {
                context.pushIndex(index)
                try {
                    result.add(inner.read(reader))
                } finally {
                    context.popPath()
                }
                index++
            }
            reader.endArray()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func readFast(reader: GeneratedSupportV1Reader): ArrayList<T> {
        readFastDirect(GeneratedSupportV1.readFastReader(reader))
    }

    public func readFastDirect(reader: JsonFastReader): ArrayList<T> {
        let directFast = match (directFastInner) {
            case Some(value) => value
            case None => return readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
        }
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawArray()
            if (!reader.hasRawArrayItem(true)) {
                reader.endRawArray()
                return ArrayList<T>()
            }
            let capacity = reader.suggestRawCollectionCapacity()
            let result = if (capacity > 4) {
                ArrayList<T>(capacity)
            } else {
                ArrayList<T>()
            }
            var first = true
            var index: Int64 = 0
            context.pushIndex(index)
            try {
                while (reader.hasRawArrayItem(first)) {
                    reader.beforeRawArrayItem(first)
                    if (!first) {
                        context.updateLastIndex(index)
                    }
                    result.add(directFast.readFastDirect(reader))
                    first = false
                    index++
                }
            } finally {
                context.popPath()
            }
            reader.endRawArray()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): ArrayList<T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            cursor.startRawArray()
            if (!cursor.hasRawArrayItem(true)) {
                cursor.endRawArray()
                return ArrayList<T>()
            }
            let capacity = cursor.suggestRawCollectionCapacity()
            let result = if (capacity > 4) {
                ArrayList<T>(capacity)
            } else {
                ArrayList<T>()
            }
            var first = true
            var index: Int64 = 0
            if (cursor.hasRawArrayItem(first)) {
                context.pushIndex(index)
                try {
                    while (true) {
                        cursor.beforeRawArrayItem(first)
                        if (!first) {
                            context.updateLastIndex(index)
                        }
                        match (cursorReadInner) {
                            case Some(fast) => result.add(fast.readFastWithCursor(reader, cursor))
                            case None => result.add(fastInner.readFast(reader))
                        }
                        first = false
                        index++
                        if (!cursor.hasRawArrayItem(first)) {
                            break
                        }
                    }
                } finally {
                    context.popPath()
                }
            }
            cursor.endRawArray()
            return result
        } finally {
            context.leaveValue()
        }
    }
}

private class Int64ArrayListJsonCodec <: GeneratedCodecV1<ArrayList<Int64>> &
    GeneratedCursorReadCodecV1<ArrayList<Int64>> &
    GeneratedCursorWriteCodecV1<ArrayList<Int64>> {
    public func write(value: ArrayList<Int64>, writer: JsonWriter): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        let _ = context
        context.enterValue()
        try {
            if (jsonTryWriteCompactInt64ArrayList(writer, value)) {
                return
            }
            writer.startArray()
            for (index in 0..value.size) {
                writer.writeInt64(value[index])
            }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }
    public func read(reader: JsonReader): ArrayList<Int64> {
        let context = GeneratedSupportV1.readState(reader)
        let _ = context
        ArrayListJsonCodec<Int64>(Int64Json).read(reader)
    }
    public func readFast(reader: GeneratedSupportV1Reader): ArrayList<Int64> {
        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }
    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): ArrayList<Int64> {
        let context = GeneratedSupportV1.readState(reader)
        let _ = context
        context.enterValue()
        try {
            if (let Some(result) <- yJsonTryReadNativeInt64ArrayListV1(reader)) {
                return result
            }
            cursor.startRawArray()
            if (!cursor.hasRawArrayItem(true)) {
                cursor.endRawArray()
                return ArrayList<Int64>()
            }
            let result = ArrayList<Int64>(cursor.suggestRawArrayCapacity())
            var first = true
            while (cursor.hasRawArrayItem(first)) {
                cursor.beforeRawArrayItem(first)
                result.add(cursor.readRawInt64())
                first = false
            }
            cursor.endRawArray()
            return result
        } finally {
            context.leaveValue()
        }
    }
    public func supportsCompactCursorWrite(): Bool { true }
    public func writeCompactWithCursor(value: ArrayList<Int64>, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = cursor
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            if (!jsonTryWriteCompactInt64ArrayList(writer, value)) {
                throw JsonException("Compact raw codec is unavailable")
            }
        } finally {
            context.leaveValue()
        }
    }
}

private class StringArrayListJsonCodec <: GeneratedCodecV1<ArrayList<String>> &
    GeneratedCursorReadCodecV1<ArrayList<String>> &
    GeneratedCursorWriteCodecV1<ArrayList<String>> {
    public func write(value: ArrayList<String>, writer: JsonWriter): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        let _ = context
        context.enterValue()
        try {
            if (jsonTryWriteCompactStringArrayList(writer, value)) {
                return
            }
            writer.startArray()
            for (index in 0..value.size) {
                writer.writeString(value[index])
            }
            writer.endArray()
        } finally {
            context.leaveValue()
        }
    }

    public func read(reader: JsonReader): ArrayList<String> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            let result = ArrayList<String>()
            reader.startArray()
            while (reader.hasArrayItem()) {
                result.add(reader.readString())
            }
            reader.endArray()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func readFast(reader: GeneratedSupportV1Reader): ArrayList<String> {

        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): ArrayList<String> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            cursor.startRawArray()
            if (!cursor.hasRawArrayItem(true)) {
                cursor.endRawArray()
                return ArrayList<String>()
            }
            let result = ArrayList<String>(cursor.suggestRawArrayCapacity())
            var first = true
            while (cursor.hasRawArrayItem(first)) {
                cursor.beforeRawArrayItem(first)
                result.add(cursor.readRawString())
                first = false
            }
            cursor.endRawArray()
            return result
        } finally {
            context.leaveValue()
        }
    }
    public func supportsCompactCursorWrite(): Bool { true }
    public func writeCompactWithCursor(value: ArrayList<String>, writer: GeneratedSupportV1Writer,
        cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = cursor
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            if (!jsonTryWriteCompactStringArrayList(writer, value)) {
                throw JsonException("Compact raw codec is unavailable")
            }
        } finally {
            context.leaveValue()
        }
    }
}

// Concrete generated-code bridges. They are public only because macro output
// may live in a consumer package; ordinary users should use YJson codecs.
/**
 * 将当前 JSON 数组解码为字符串列表。
 *
 * 为数组计入一层生成读取深度，并在 finally 中归还。使用语义数组入口，按输入顺序逐项读取字符串。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值、由运行时拥有的语义 reader。
 * @return 按输入顺序构造的新字符串列表。
 * @throws JsonException reader 不由运行时拥有，或读取值的语法、类型、范围及资源限制不符合要求。
 */
public func __yJsonReadStringArrayList(reader: JsonReader): ArrayList<String> {
    let context = GeneratedSupportV1.readState(reader)
    let _ = context
    context.enterValue()
    try {
        let result = ArrayList<String>();
        reader.startArray()
        while (reader.hasArrayItem()) {
            result.add(reader.readString())
        }
        reader.endArray();
        result
    } finally {
        context.leaveValue()
    }
}

/**
 * 将当前 JSON 数组解码为字符串列表。
 *
 * 为数组计入一层生成读取深度，并在 finally 中归还。使用 raw 数组和字符串入口，并按 reader 提示选择初始容量。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值的匹配版本生成 reader。
 * @return 按输入顺序构造的新字符串列表。
 * @throws JsonException reader 与运行时协议不匹配，或读取值的语法、类型、范围及资源限制不符合要求。
 */
public func __yJsonReadFastStringArrayList(reader: GeneratedSupportV1Reader): ArrayList<String> {

    let context = GeneratedSupportV1.readState(reader)

    let _ = context
    context.enterValue()
    try {
        reader.startRawArray()
        if (!reader.hasRawArrayItem(true)) {
            reader.endRawArray();
            return ArrayList<String>()
        }
        let result = ArrayList<String>(reader.suggestRawArrayCapacity());
        var first = true
        while (reader.hasRawArrayItem(first)) {
            reader.beforeRawArrayItem(first);
            result.add(reader.readRawString());
            first = false
        }
        reader.endRawArray();
        result
    } finally {
        context.leaveValue()
    }
}

/**
 * 通过内置字符串列表 codec 写入一个 JSON 数组。
 *
 * 先取得运行时写入状态，再调用 JsonCodecs.arrayList(JsonCodecs.string).write；实际 codec 选择批量能力或结构化写入。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param value 按当前列表顺序写出的字符串集合。
 * @param writer 接收当前数组值、由运行时拥有的语义 writer。
 * @throws JsonException writer 不由运行时拥有，或发生深度、写入状态及输出限制错误。
 */
public func __yJsonWriteStringArrayList(
    value: ArrayList<String>,
    writer: JsonWriter
): Unit {

    let context = GeneratedSupportV1.writeState(writer)

    let _ = context
    JsonCodecs.arrayList(JsonCodecs.string).write(value, writer)
}

/**
 * 将可选字符串写为标量或 JSON null。
 *
 * Some 写入所包含的标量，None 写入 null。先取得运行时写入状态，再调用语义 writer。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param value 待编码的可选字符串值。
 * @param writer 接收当前值、由运行时拥有的语义 writer。
 * @throws JsonException writer 不由运行时拥有，或当前写入状态及输出限制不允许写入该值。
 */
public func __yJsonWriteStringOption(value: Option<String>, writer: JsonWriter): Unit {

    let context = GeneratedSupportV1.writeState(writer)

    let _ = context
    let _ = context
    match (value) {
        case Some(item) => writer.writeString(item);
        case None => writer.writeNull()
    }
}

/**
 * 将 JSON null 或字符串解码为可选值。
 *
 * null 返回 None，其他输入必须能按对应标量类型读取。只消费当前值，不检查文档末尾。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值、由运行时拥有的语义 reader。
 * @return null 对应 None，字符串对应 Some。
 * @throws JsonException reader 不由运行时拥有，或读取值的语法、类型、范围及资源限制不符合要求。
 */
public func __yJsonReadStringOption(reader: JsonReader): Option<String> {

    let context = GeneratedSupportV1.readState(reader)

    let _ = context
    let _ = context
    if (reader.tryReadNull()) {
        None<String>
    } else {
        Some(reader.readString())
    }
}

/**
 * 将 JSON null 或字符串解码为可选值。
 *
 * null 返回 None，其他输入必须能按对应标量类型读取。只消费当前值，不检查文档末尾。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值的匹配版本生成 reader。
 * @return null 对应 None，字符串对应 Some。
 * @throws JsonException reader 与运行时协议不匹配，或读取值的语法、类型、范围及资源限制不符合要求。
 */
public func __yJsonReadFastStringOption(reader: GeneratedSupportV1Reader): Option<String> {

    let context = GeneratedSupportV1.readState(reader)

    let _ = context
    let _ = context
    if (reader.tryReadRawNull()) {
        None<String>
    } else {
        Some(reader.readRawString())
    }
}

/**
 * 将可选Int64 整数写为标量或 JSON null。
 *
 * Some 写入所包含的标量，None 写入 null。先取得运行时写入状态，再调用语义 writer。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param value 待编码的可选Int64 整数值。
 * @param writer 接收当前值、由运行时拥有的语义 writer。
 * @throws JsonException writer 不由运行时拥有，或当前写入状态及输出限制不允许写入该值。
 */
public func __yJsonWriteInt64Option(value: Option<Int64>, writer: JsonWriter): Unit {
    let context = GeneratedSupportV1.writeState(writer)
    let _ = context
    match (value) {
        case Some(item) => writer.writeInt64(item)
        case None => writer.writeNull()
    }
}

/**
 * 将 JSON null 或Int64 整数解码为可选值。
 *
 * null 返回 None，其他输入必须能按对应标量类型读取。只消费当前值，不检查文档末尾。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值、由运行时拥有的语义 reader。
 * @return null 对应 None，Int64 整数对应 Some。
 * @throws JsonException reader 不由运行时拥有，或读取值的语法、类型、范围及资源限制不符合要求。
 */
public func __yJsonReadInt64Option(reader: JsonReader): Option<Int64> {
    let context = GeneratedSupportV1.readState(reader)
    let _ = context
    if (reader.tryReadNull()) {
        None<Int64>
    } else {
        Some(reader.readInt64())
    }
}

/**
 * 将 JSON null 或Int64 整数解码为可选值。
 *
 * null 返回 None，其他输入必须能按对应标量类型读取。只消费当前值，不检查文档末尾。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值的匹配版本生成 reader。
 * @return null 对应 None，Int64 整数对应 Some。
 * @throws JsonException reader 与运行时协议不匹配，或读取值的语法、类型、范围及资源限制不符合要求。
 */
public func __yJsonReadFastInt64Option(reader: GeneratedSupportV1Reader): Option<Int64> {
    let context = GeneratedSupportV1.readState(reader)
    let _ = context
    if (reader.tryReadRawNull()) {
        None<Int64>
    } else {
        Some(reader.readRawInt64())
    }
}

private class HashMapJsonCodec<T> <: GeneratedCodecV1<HashMap<String, T>> &
    GeneratedDirectFastReadCodecV1<HashMap<String, T>> &
    GeneratedCursorReadCodecV1<HashMap<String, T>> &
    GeneratedCompactWriteCodecV1<HashMap<String, T>> &
    GeneratedCursorWriteCodecV1<HashMap<String, T>> {
    private let inner: JsonCodec<T>
    private let fastInner: GeneratedCodecV1<T>
    private let directFastInner: Option<GeneratedDirectFastReadCodecV1<T>>
    private let rawInner: Option<JsonRawWriteCodec<T>>
    private let directInner: Option<GeneratedDirectWriteCodecV1<T>>
    private let compactRawInner: Option<GeneratedCompactWriteCodecV1<T>>
    private let cursorReadInner: Option<GeneratedCursorReadCodecV1<T>>
    private let cursorWriteInner: Option<GeneratedCursorWriteCodecV1<T>>

    public init(inner: JsonCodec<T>) {
        this.inner = inner
        this.fastInner = resolvedGeneratedCodecV1(inner)
        this.directFastInner = match (inner) {
            case direct: GeneratedDirectFastReadCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectFastReadCodecV1<T>>
        }
        this.rawInner = match (inner) {
            case raw: JsonRawWriteCodec<T> => Some(raw)
            case _ => None<JsonRawWriteCodec<T>>
        }
        this.directInner = match (inner) {
            case direct: GeneratedDirectWriteCodecV1<T> => Some(direct)
            case _ => None<GeneratedDirectWriteCodecV1<T>>
        }
        this.compactRawInner = match (inner) {
            case raw: GeneratedCompactWriteCodecV1<T> => Some(raw)
            case _ => None<GeneratedCompactWriteCodecV1<T>>
        }
        this.cursorReadInner = match (inner) {
            case cursor: GeneratedCursorReadCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorReadCodecV1<T>>
        }
        this.cursorWriteInner = match (inner) {
            case cursor: GeneratedCursorWriteCodecV1<T> => Some(cursor)
            case _ => None<GeneratedCursorWriteCodecV1<T>>
        }
    }

    public func write(value: HashMap<String, T>, writer: JsonWriter): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        match (writer) {
            case direct: JsonDirectWriter =>
                writeDirect(value, direct)
                return
            case _ => ()
        }
        context.enterValue()
        try {
            if (let Some(raw) <- rawInner) {
                match (writer) {
                    case direct: JsonDirectWriter =>
                        if (direct.tryWriteCompactRawMap(value, raw)) { return }
                    case _ => ()
                }
            }
            writer.startObject()
            if (!value.isEmpty()) {
                var first = true
                try {
                    for ((name, item) in value) {
                        writer.writeName(name)
                        if (first) {
                            context.pushField(name)
                            first = false
                        } else {
                            context.updateLastField(name)
                        }
                        inner.write(item, writer)
                    }
                } finally {
                    if (!first) {
                        context.popPath()
                    }
                }
            }
            writer.endObject()
        } finally {
            context.leaveValue()
        }
    }

    public func writeDirect(value: HashMap<String, T>, writer: GeneratedSupportV1Writer): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        if (supportsCompactRaw() && writer.tryBeginGeneratedCompactRawValue()) {
            writeCompactRaw(value, writer)
            return
        }
        context.enterValue()
        try {
            if (let Some(raw) <- rawInner) {
                if (yJsonGeneratedWriterV1(writer).tryWriteCompactRawMap(value, raw)) {
                    return
                }
            }
            writer.startObject()
            if (!value.isEmpty()) {
                var first = true
                try {
                    for ((name, item) in value) {
                        writer.writeName(name)
                        if (first) {
                            context.pushField(name)
                            first = false
                        } else {
                            context.updateLastField(name)
                        }
                        match (directInner) {
                            case Some(direct) => direct.writeDirect(item, writer)
                            case None => inner.write(item, writer)
                        }
                    }
                } finally {
                    if (!first) {
                        context.popPath()
                    }
                }
            }
            writer.endObject()
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactRaw(): Bool {
        if (let Some(cursor) <- cursorWriteInner) {
            return cursor.supportsCompactCursorWrite()
        }
        match (compactRawInner) {
            case Some(raw) => raw.supportsCompactRaw()
            case None => false
        }
    }

    public func writeCompactRaw(value: HashMap<String, T>, writer: GeneratedSupportV1Writer): Unit {

        writeCompactWithCursor(value, writer, GeneratedSupportV1.writeCursor(writer))
    }

    public func supportsCompactCursorWrite(): Bool { supportsCompactRaw() }

    public func writeCompactWithCursor(value: HashMap<String, T>, writer: GeneratedSupportV1Writer,
        rawWriter: GeneratedSupportV1WriteCursor): Unit {

        let context = GeneratedSupportV1.writeState(writer)

        let _ = context
        context.enterValue()
        try {
            rawWriter.writeRawBeginObject()
            if (!value.isEmpty()) {
                // writeCompactRaw is reachable only after supportsCompactRaw
                // has confirmed this invariant.
                var first = true
                try {
                    for ((name, item) in value) {
                        if (first) {
                            context.pushField(name)
                        } else {
                            context.updateLastField(name)
                        }
                        first = rawWriter.writeRawObjectEntryName(first, name)
                        match (cursorWriteInner) {
                            case Some(raw) => raw.writeCompactWithCursor(item, writer, rawWriter)
                            case None => compactRawInner.getOrThrow().writeCompactRaw(item, writer)
                        }
                    }
                } finally {
                    context.popPath()
                }
            }
            rawWriter.writeRawEndObject()
        } finally {
            context.leaveValue()
        }
    }

    public func read(reader: JsonReader): HashMap<String, T> {

        let context = GeneratedSupportV1.readState(reader)
        let config = GeneratedSupportV1.readOptions(reader)

        let _ = context
        context.enterValue()
        let rejects = jsonReadOptionsRejectsDuplicateKeys(config)
        try {
            let result = HashMap<String, T>()
            reader.startObject()
            while (reader.hasObjectField()) {
                let name = reader.readName()
                context.pushField(name)
                try {
                    let decoded = inner.read(reader)
                    if (rejects) {
                        match (result.add(name, decoded)) {
                            case Some(_) =>
                                throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                                    path: context.currentPath())
                            case None => ()
                        }
                    } else {
                        result[name] = decoded
                    }
                } finally {
                    context.popPath()
                }
            }
            reader.endObject()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func readFast(reader: GeneratedSupportV1Reader): HashMap<String, T> {
        readFastDirect(GeneratedSupportV1.readFastReader(reader))
    }

    public func readFastDirect(reader: JsonFastReader): HashMap<String, T> {
        let directFast = match (directFastInner) {
            case Some(value) => value
            case None => return readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
        }
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawObject()
            if (!reader.hasRawObjectField(true)) {
                reader.endRawObject()
                return HashMap<String, T>()
            }
            let result = HashMap<String, T>(reader.suggestRawObjectCapacity())
            var first = true
            let firstName = reader.readRawName(true)
            context.pushField(firstName)
            try {
                let decodedFirst = directFast.readFastDirect(reader)
                result[firstName] = decodedFirst
                first = false
                while (reader.hasRawObjectField(first)) {
                    let name = reader.readRawName(first)
                    context.updateLastField(name)
                    let decoded = directFast.readFastDirect(reader)
                    match (result.add(name, decoded)) {
                        case Some(_) =>
                            throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                                path: context.currentPath())
                        case None => ()
                    }
                }
            } finally {
                context.popPath()
            }
            reader.endRawObject()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): HashMap<String, T> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            cursor.startRawObject()
            if (!cursor.hasRawObjectField(true)) {
                cursor.endRawObject()
                return HashMap<String, T>()
            }
            let result = HashMap<String, T>(cursor.suggestRawObjectCapacity())
            var first = true
            let firstName = cursor.readRawName(true)
            context.pushField(firstName)
            try {
                let decodedFirst = match (cursorReadInner) {
                    case Some(fast) => fast.readFastWithCursor(reader, cursor)
                    case None => fastInner.readFast(reader)
                }
                match (result.add(firstName, decodedFirst)) {
                    case Some(_) =>
                        throw JsonException("Duplicate object key '${firstName}'", code: "duplicate_key",
                            path: context.currentPath())
                    case None => ()
                }
                first = false
                while (cursor.hasRawObjectField(first)) {
                    let name = cursor.readRawName(first)
                    context.updateLastField(name)
                    let decoded = match (cursorReadInner) {
                        case Some(fast) => fast.readFastWithCursor(reader, cursor)
                        case None => fastInner.readFast(reader)
                    }
                    match (result.add(name, decoded)) {
                        case Some(_) =>
                            throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                                path: context.currentPath())
                        case None => ()
                    }
                }
            } finally {
                context.popPath()
            }
            cursor.endRawObject()
            return result
        } finally {
            context.leaveValue()
        }
    }
}

private class Int64ArrayHashMapJsonCodec <: GeneratedCodecV1<HashMap<String, Array<Int64>>> &
    GeneratedCursorReadCodecV1<HashMap<String, Array<Int64>>> &
    GeneratedCompactWriteCodecV1<HashMap<String, Array<Int64>>> &
    GeneratedCursorWriteCodecV1<HashMap<String, Array<Int64>>> {
    private let fallback = HashMapJsonCodec<Array<Int64>>(Int64ArrayJsonCodec())

    public func write(value: HashMap<String, Array<Int64>>, writer: JsonWriter): Unit {
        match (writer) {
            case direct: GeneratedSupportV1Writer => writeDirect(value, direct)
            case _ => fallback.write(value, writer)
        }
    }

    public func writeDirect(
        value: HashMap<String, Array<Int64>>,
        writer: GeneratedSupportV1Writer
    ): Unit {
        if (jsonTryWriteCompactInt64ArrayMap(writer, value)) { return }
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            writer.startObject()
            for ((name, items) in value) {
                writer.writeName(name)
                writer.startArray()
                for (item in items) { writer.writeInt64(item) }
                writer.endArray()
            }
            writer.endObject()
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactRaw(): Bool { true }

    public func writeCompactRaw(
        value: HashMap<String, Array<Int64>>,
        writer: GeneratedSupportV1Writer
    ): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            if (!jsonTryWriteCompactInt64ArrayMap(writer, value)) {
                throw JsonException("Compact raw codec is unavailable")
            }
        } finally {
            context.leaveValue()
        }
    }

    public func read(reader: JsonReader): HashMap<String, Array<Int64>> {
        fallback.read(reader)
    }

    public func readFast(reader: GeneratedSupportV1Reader): HashMap<String, Array<Int64>> {
        fallback.readFast(reader)
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): HashMap<String, Array<Int64>> {
        fallback.readFastWithCursor(reader, cursor)
    }

    public func supportsCompactCursorWrite(): Bool { true }

    public func writeCompactWithCursor(value: HashMap<String, Array<Int64>>,
        writer: GeneratedSupportV1Writer, cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = cursor
        writeCompactRaw(value, writer)
    }
}

private class Int64HashMapJsonCodec <: GeneratedCodecV1<HashMap<String, Int64>> &
    GeneratedCursorReadCodecV1<HashMap<String, Int64>> &
    GeneratedCursorWriteCodecV1<HashMap<String, Int64>> {
    public func write(value: HashMap<String, Int64>, writer: JsonWriter): Unit {
        let context = GeneratedSupportV1.writeState(writer)
        let _ = context
        context.enterValue()
        try {
            if (jsonTryWriteCompactInt64Map(writer, value)) {
                return
            }
            writer.startObject()
            for ((name, item) in value) {
                writer.writeName(name)
                writer.writeInt64(item)
            }
            writer.endObject()
        } finally {
            context.leaveValue()
        }
    }

    public func read(reader: JsonReader): HashMap<String, Int64> {

        let context = GeneratedSupportV1.readState(reader)
        let config = GeneratedSupportV1.readOptions(reader)

        let _ = context
        context.enterValue()
        let rejects = jsonReadOptionsRejectsDuplicateKeys(config)
        try {
            let result = HashMap<String, Int64>()
            reader.startObject()
            while (reader.hasObjectField()) {
                let name = reader.readName()
                let decoded = reader.readInt64()
                if (rejects) {
                    match (result.add(name, decoded)) {
                        case Some(_) =>
                            context.pushField(name)
                            try {
                                throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                                    path: context.currentPath())
                            } finally {
                                context.popPath()
                            }
                        case None => ()
                    }
                } else {
                    result[name] = decoded
                }
            }
            reader.endObject()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func readFast(reader: GeneratedSupportV1Reader): HashMap<String, Int64> {

        readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
    }

    public func readFastWithCursor(reader: GeneratedSupportV1Reader,
        cursor: GeneratedSupportV1ReadCursor): HashMap<String, Int64> {

        let context = GeneratedSupportV1.readState(reader)

        let _ = context
        context.enterValue()
        try {
            cursor.startRawObject()
            if (!cursor.hasRawObjectField(true)) {
                cursor.endRawObject()
                return HashMap<String, Int64>()
            }
            let result = HashMap<String, Int64>(cursor.suggestRawObjectCapacity())
            var first = true
            while (cursor.hasRawObjectField(first)) {
                let name = cursor.readRawName(first)
                let decoded = cursor.readRawInt64()
                context.updateLastField(name)
                match (result.add(name, decoded)) {
                    case Some(_) =>
                        throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                            path: context.currentPath())
                    case None => ()
                }
                first = false
            }
            cursor.endRawObject()
            return result
        } finally {
            context.leaveValue()
        }
    }

    public func supportsCompactCursorWrite(): Bool { true }

    public func writeCompactWithCursor(value: HashMap<String, Int64>,
        writer: GeneratedSupportV1Writer, cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = cursor
        let context = GeneratedSupportV1.writeState(writer)
        context.enterValue()
        try {
            if (!jsonTryWriteCompactInt64Map(writer, value)) {
                throw JsonException("Compact raw codec is unavailable")
            }
        } finally {
            context.leaveValue()
        }
    }
}

/**
 * 将当前 JSON 对象解码为字符串键、Int64 值的映射。
 *
 * 按本次读取配置处理重复键：Reject 抛出 duplicate_key，LastWins 保留最后一次读取的值。为对象计入一层生成读取深度，并在 finally 中归还。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值、由运行时拥有的语义 reader。
 * @return 包含解码后对象成员的新映射。
 * @throws JsonException reader 不由运行时拥有，或读取值的语法、类型、范围及资源限制不符合要求。重复键被拒绝时 code 为 duplicate_key。
 */
public func __yJsonReadInt64HashMap(reader: JsonReader): HashMap<String, Int64> {

    let context = GeneratedSupportV1.readState(reader)
    let config = GeneratedSupportV1.readOptions(reader)

    let _ = context
    context.enterValue()
    let rejects = jsonReadOptionsRejectsDuplicateKeys(config)
    try {
        let result = HashMap<String, Int64>()
        reader.startObject()
        while (reader.hasObjectField()) {
            let name = reader.readName()
            let decoded = reader.readInt64()
            if (rejects) {
                match (result.add(name, decoded)) {
                    case Some(_) =>
                        context.pushField(name)
                        try {
                            throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                                path: context.currentPath())
                        } finally {
                            context.popPath()
                        }
                    case None => ()
                }
            } else {
                result[name] = decoded
            }
        }
        reader.endObject()
        result
    } finally {
        context.leaveValue()
    }
}

/**
 * 将当前 JSON 对象解码为字符串键、Int64 值的映射。
 *
 * fast 入口拒绝重复键，code 为 duplicate_key；不会读取 LastWins 配置来放宽此检查。为对象计入一层生成读取深度，并在 finally 中归还。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param reader 定位在当前值的匹配版本生成 reader。
 * @return 包含解码后对象成员的新映射。
 * @throws JsonException reader 与运行时协议不匹配，或读取值的语法、类型、范围及资源限制不符合要求。重复键被拒绝时 code 为 duplicate_key。
 */
public func __yJsonReadFastInt64HashMap(reader: GeneratedSupportV1Reader): HashMap<String, Int64> {

    let context = GeneratedSupportV1.readState(reader)

    let _ = context
    context.enterValue()
    try {
        reader.startRawObject()
        if (!reader.hasRawObjectField(true)) {
            reader.endRawObject()
            return HashMap<String, Int64>()
        }
        let result = HashMap<String, Int64>(reader.suggestRawObjectCapacity())
        var first = true
        while (reader.hasRawObjectField(first)) {
            let name = reader.readRawName(first)
            context.updateLastField(name)
            let decoded = reader.readRawInt64()
            match (result.add(name, decoded)) {
                case Some(_) =>
                    throw JsonException("Duplicate object key '${name}'", code: "duplicate_key",
                        path: context.currentPath())
                case None => ()
            }
            first = false
        }
        reader.endRawObject()
        result
    } finally {
        context.leaveValue()
    }
}

/**
 * 通过内置映射 codec 写入字符串键、Int64 值的 JSON 对象。
 *
 * 先取得运行时写入状态，再调用 JsonCodecs.stringMap(JsonCodecs.int64).write；实际 codec 选择批量能力或结构化写入。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @param value 按当前映射遍历顺序写出的对象成员。
 * @param writer 接收当前对象值、由运行时拥有的语义 writer。
 * @throws JsonException writer 不由运行时拥有，或发生深度、写入状态及输出限制错误。
 */
public func __yJsonWriteInt64HashMap(
    value: HashMap<String, Int64>,
    writer: JsonWriter
): Unit {

    let context = GeneratedSupportV1.writeState(writer)

    let _ = context
    JsonCodecs.stringMap(JsonCodecs.int64).write(value, writer)
}

private func writeJsonValueView(writer: JsonWriter, value: JsonValueView): Unit {
    // JsonNode is itself a view, but mutable DOM values require the guarded
    // serializer so direct and indirect cycles fail deterministically.
    match (value) {
        case node: JsonNode =>
            writeJsonNodeToCodecWriter(writer, node)
            return
        case _ => ()
    }
    match (value.kind()) {
        case JsonKind.Null => writer.writeNull()
        case JsonKind.Boolean => writer.writeBool(value.asBool())
        case JsonKind.Number => writer.writeNumberLiteral(value.asNumberText())
        case JsonKind.String => writer.writeString(value.asString())
        case JsonKind.Array =>
            writer.startArray()
            for (index in 0..value.size()) {
                let item = value.element(index).getOrThrow({ =>
                    JsonException("Array view changed during traversal", code: "view_contract")
                })
                writeJsonValueView(writer, item)
            }
            writer.endArray()
        case JsonKind.Object =>
            writer.startObject()
            for (index in 0..value.size()) {
                writer.writeName(value.memberName(index))
                writeJsonValueView(writer, value.memberValue(index))
            }
            writer.endObject()
    }
}

/**
 * Stateless entry points for typed JSON encoding, decoding, and documents.
 */
private let yJsonGeneratedCompactWriterPool = AtomicOptionReference<JsonDirectWriter>()

private func generatedCompactWriterConfig(options: JsonWriteOptions): Bool {
    options.indent.isEmpty() && !options.htmlSafe &&
        options.maxOutputBytes == 0 && options.maxDepth == 256
}

private func acquireGeneratedCompactWriter(options: JsonWriteOptions): JsonDirectWriter {
    if (!generatedCompactWriterConfig(options)) {
        return JsonDirectWriter(options)
    }
    match (yJsonGeneratedCompactWriterPool.swap(None)) {
        case Some(value) => return value
        case None => ()
    }
    JsonDirectWriter(options)
}

private func releaseGeneratedCompactWriter(writer: JsonDirectWriter): Unit {
    if (!writer.canReuseGeneratedCompactWriter()) { return }
    writer.resetForGeneratedReuse()
    let _ = yJsonGeneratedCompactWriterPool.compareAndSwap(None, Some(writer))
}

/**
 * JSON 编解码、只读视图输出和托管文档的应用入口。
 *
 * 无 codec 参数的重载采用 T 的生成 codec；显式 codec 重载也接受手写 codec。每次读取消费一个完整文档，输入输出流由调用方管理。可选原生加速须在进程第一次普通 YJson 操作前初始化。示例的 core-codec profile 提供完整模型和导入。
 * @group 10-application 应用 API
 */
public class YJson {
    /**
     * 为生成代码取得当前调用独占的字符串 writer。
     *
     * 这是跨包生成代码支持入口，普通应用使用 YJson.toJson。空缩进、非 htmlSafe、无输出字节上限且 maxDepth 为 256 时，可从单槽池取出 writer；其他配置新建 writer，不加入该池。使用后应在 finally 中释放。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param options 本次写入的格式、转义策略、输出预算和深度上限。
     * @return 本次调用持有、使用后须释放的 JsonDirectWriter。
     */
    public static func acquireGeneratedCompactStringWriter(
        options: JsonWriteOptions
    ): JsonDirectWriter {
        acquireGeneratedCompactWriter(options)
    }

    /**
     * 将可复用的生成字符串 writer 重置后尝试放回单槽池。
     *
     * 不可复用的 writer 直接返回；池已有 writer 时不替换现有项。调用后不得继续使用、保留或共享此 writer。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 由生成 compact 字符串入口取得、当前调用已结束使用的 writer。
     */
    public static func releaseGeneratedCompactStringWriter(
        writer: JsonDirectWriter
    ): Unit {
        releaseGeneratedCompactWriter(writer)
    }

    /**
     * 将一个完整 JSON 文档解析为由 GC 管理的只读文档。
     *
     * 借用不可变字符串的 UTF-8 存储，并由文档保留字符串所有者。需要可变节点时调用 materialize；文档无需显式关闭。
     *
     * @param text 一个完整的 JSON 文本。
     * @param config 解析策略与正数资源限制；默认 JsonReadOptions.defaults。
     * @return 具有只读根视图的托管文档。
     * @throws JsonException 输入不是有效 JSON，或超过解析资源限制。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "7"
     * let bytes = unsafe { text.rawData().clone() }
     * docRequire(YJson.parseDocument(text).root().asInt64() == 7)
     * let owned = YJson.parseDocument(bytes)
     * bytes[0] = b'9'
     * docRequire(owned.root().asInt64() == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func parseDocument(text: String,
        config!: JsonReadOptions = JsonReadOptions.defaults): JsonDocument {
        freezeYJsonRuntime()
        parseManagedJsonDocument(text, config)
    }

    /**
     * 将一个完整 JSON 文档解析为由 GC 管理的只读文档。
     *
     * 复制输入字节后解析，调用方随后修改原数组不影响返回文档。需要可变节点时调用 materialize；文档无需显式关闭。
     *
     * @param bytes 一个完整文档的 UTF-8 字节。
     * @param config 解析策略与正数资源限制；默认 JsonReadOptions.defaults。
     * @return 具有只读根视图的托管文档。
     * @throws JsonException 输入不是有效 JSON，或超过解析资源限制。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "7"
     * let bytes = unsafe { text.rawData().clone() }
     * docRequire(YJson.parseDocument(text).root().asInt64() == 7)
     * let owned = YJson.parseDocument(bytes)
     * bytes[0] = b'9'
     * docRequire(owned.root().asInt64() == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func parseDocument(bytes: Array<Byte>,
        config!: JsonReadOptions = JsonReadOptions.defaults): JsonDocument {
        freezeYJsonRuntime()
        parseManagedJsonDocument(bytes, config)
    }

    /**
     * 将一个值编码为 JSON 文本。
     *
     * 直接读取视图，无需先物化可变树。
     *
     * @param value 待编码的只读视图。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 JSON 文本。
     * @throws JsonException 输入不是有效 JSON，或超过解析资源限制。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value: JsonValueView = JsonNode.int64(7)
     * docRequire(YJson.toJson(value) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJson(value: JsonValueView,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String {
        freezeYJsonRuntime()
        let writer = JsonDirectWriter(options)
        writeJsonValueView(writer, value)
        writer.finishString()
    }

    /**
     * 将一个值编码为 UTF-8 JSON 字节。
     *
     * 直接读取视图，无需先物化可变树。
     *
     * @param value 待编码的只读视图。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 UTF-8 字节。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value: JsonValueView = JsonNode.int64(7)
     * docRequire(String.fromUtf8(YJson.toJsonBytes(value)) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJsonBytes(value: JsonValueView,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte> {
        freezeYJsonRuntime()
        let writer = JsonDirectWriter.bytes(config: options)
        writeJsonValueView(writer, value)
        writer.finishBytes()
    }

    /**
     * 向调用方的输出流写入一个 JSON 值。
     *
     * 直接读取视图，无需先物化可变树。流归调用方所有，函数不关闭它；失败时可能已写入部分内容，不回滚输出。
     *
     * @param value 待编码的只读视图。
     * @param output 调用方拥有的输出流。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value: JsonValueView = JsonNode.int64(7)
     * let output = YJsonMemoryOutputStream()
     * YJson.writeJson(value, output)
     * docRequire(output.toUtf8String() == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func writeJson(value: JsonValueView, output: OutputStream,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit {
        freezeYJsonRuntime()
        let writer = JsonDirectWriter(output, config: options)
        // Resolve the root kind before the first output token so a closed
        // resource-backed view fails without producing a new prefix.
        let _ = value.kind()
        writeJsonValueView(writer, value)
        writer.finish()
    }

    /**
     * 将一个值编码为 JSON 文本。
     *
     * 采用 T 的生成 codec。
     *
     * @param value 待编码的应用值。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 JSON 文本。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * let expected = "{\"x\":7}"
     * docRequire(YJson.toJson<DocCodecPoint>(value) == expected)
     * docRequire(YJson.toJson<DocCodecPoint>(value, codec: DocCodecPointJson) == expected)
     * docRequire(YJson.toJson<DocCodecPoint>(value, codec: semantic) == expected)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJson<T>(value: T,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String where T <: GeneratedCodecProviderV1<T> {
        encodeString(value, generatedCodecV1Of<T>(), options)
    }

    /**
     * 将一个值编码为 JSON 文本。
     *
     * 紧凑输出路径调用 T 的静态生成 provider；格式或预算要求语义写入时使用传入 codec。codec 必须与 T 的生成 provider 配套，不可用它替换此重载的紧凑表示。
     *
     * @param value 待编码的应用值。
     * @param codec 定义值的 JSON 表示的 codec。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 JSON 文本。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * let expected = "{\"x\":7}"
     * docRequire(YJson.toJson<DocCodecPoint>(value) == expected)
     * docRequire(YJson.toJson<DocCodecPoint>(value, codec: DocCodecPointJson) == expected)
     * docRequire(YJson.toJson<DocCodecPoint>(value, codec: semantic) == expected)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJson<T>(value: T,
        codec!: GeneratedCompactCursorWriteCodecV1<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String
        where T <: GeneratedCompactCodecProviderV1<T> {
        encodeStringStatic(value, codec, options)
    }

    /**
     * 将一个值编码为 JSON 文本。
     *
     * 采用传入的 codec。
     *
     * @param value 待编码的应用值。
     * @param codec 定义值的 JSON 表示的 codec。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 JSON 文本。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * let expected = "{\"x\":7}"
     * docRequire(YJson.toJson<DocCodecPoint>(value) == expected)
     * docRequire(YJson.toJson<DocCodecPoint>(value, codec: DocCodecPointJson) == expected)
     * docRequire(YJson.toJson<DocCodecPoint>(value, codec: semantic) == expected)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJson<T>(value: T, codec!: JsonCodec<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String {
        encodeString(value, codec, options)
    }

    /**
     * 将一个值编码为 UTF-8 JSON 字节。
     *
     * 采用 T 的生成 codec。
     *
     * @param value 待编码的应用值。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 UTF-8 字节。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * let expected = "{\"x\":7}"
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value)) == expected)
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value, codec: DocCodecPointJson)) == expected)
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value, codec: semantic)) == expected)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJsonBytes<T>(value: T,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte> where T <: GeneratedCodecProviderV1<T> {
        encodeBytes(value, generatedCodecV1Of<T>(), options)
    }

    /**
     * 将一个值编码为 UTF-8 JSON 字节。
     *
     * 采用传入的 codec。
     *
     * @param value 待编码的应用值。
     * @param codec 定义值的 JSON 表示的 codec。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 UTF-8 字节。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * let expected = "{\"x\":7}"
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value)) == expected)
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value, codec: DocCodecPointJson)) == expected)
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value, codec: semantic)) == expected)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJsonBytes<T>(value: T,
        codec!: GeneratedCompactCursorWriteCodecV1<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte> {
        encodeBytes(value, codec, options)
    }

    /**
     * 将一个值编码为 UTF-8 JSON 字节。
     *
     * 采用传入的 codec。
     *
     * @param value 待编码的应用值。
     * @param codec 定义值的 JSON 表示的 codec。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @return 序列化后的 UTF-8 字节。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * let expected = "{\"x\":7}"
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value)) == expected)
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value, codec: DocCodecPointJson)) == expected)
     * docRequire(String.fromUtf8(YJson.toJsonBytes<DocCodecPoint>(value, codec: semantic)) == expected)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func toJsonBytes<T>(value: T, codec!: JsonCodec<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte> {
        encodeBytes(value, codec, options)
    }

    /**
     * 向调用方的输出流写入一个 JSON 值。
     *
     * 采用 T 的生成 codec。流归调用方所有，函数不关闭它；失败时可能已写入部分内容，不回滚输出。
     *
     * @param value 待编码的应用值。
     * @param output 调用方拥有的输出流。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let generated = YJsonMemoryOutputStream()
     * YJson.writeJson<DocCodecPoint>(value, generated)
     * docRequire(generated.toUtf8String() == "{\"x\":7}")
     * let explicitCodec = YJsonMemoryOutputStream()
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * YJson.writeJson<DocCodecPoint>(value, explicitCodec, codec: semantic)
     * docRequire(explicitCodec.toUtf8String() == "{\"x\":7}")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func writeJson<T>(value: T, output: OutputStream,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit where T <: GeneratedCodecProviderV1<T> {
        encodeStream(value, generatedCodecV1Of<T>(), output, options)
    }

    /**
     * 向调用方的输出流写入一个 JSON 值。
     *
     * 采用传入的 codec。流归调用方所有，函数不关闭它；失败时可能已写入部分内容，不回滚输出。
     *
     * @param value 待编码的应用值。
     * @param output 调用方拥有的输出流。
     * @param codec 定义值的 JSON 表示的 codec。
     * @param options 格式与输出预算；默认 JsonWriteOptions.defaults。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let value = DocCodecPoint(7)
     * let generated = YJsonMemoryOutputStream()
     * YJson.writeJson<DocCodecPoint>(value, generated)
     * docRequire(generated.toUtf8String() == "{\"x\":7}")
     * let explicitCodec = YJsonMemoryOutputStream()
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * YJson.writeJson<DocCodecPoint>(value, explicitCodec, codec: semantic)
     * docRequire(explicitCodec.toUtf8String() == "{\"x\":7}")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func writeJson<T>(value: T, output: OutputStream, codec!: JsonCodec<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit {
        encodeStream(value, codec, output, options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用 T 的生成 codec。
     *
     * @param text 一个完整的 JSON 文本。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(text: String,
        options!: JsonReadOptions = JsonReadOptions.defaults): T where T <: GeneratedCodecProviderV1<T> {
        decodeString(text, generatedCodecV1Of<T>(), options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用传入的 codec。
     *
     * @param text 一个完整的 JSON 文本。
     * @param codec 定义 T 的 JSON 表示，必须消费一个值的 codec。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(text: String,
        codec!: GeneratedCompactCursorWriteCodecV1<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeString(text, codec, options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用传入的 codec。
     *
     * @param text 一个完整的 JSON 文本。
     * @param codec 定义 T 的 JSON 表示，必须消费一个值的 codec。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(text: String, codec!: JsonCodec<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeString(text, codec, options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用 T 的生成 codec。
     *
     * @param bytes UTF-8 编码的完整文档。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(bytes: Array<Byte>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T where T <: GeneratedCodecProviderV1<T> {
        decodeBytes(bytes, generatedCodecV1Of<T>(), options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用传入的 codec。
     *
     * @param bytes UTF-8 编码的完整文档。
     * @param codec 定义 T 的 JSON 表示，必须消费一个值的 codec。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(bytes: Array<Byte>,
        codec!: GeneratedCompactCursorWriteCodecV1<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeBytes(bytes, codec, options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用传入的 codec。
     *
     * @param bytes UTF-8 编码的完整文档。
     * @param codec 定义 T 的 JSON 表示，必须消费一个值的 codec。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(bytes: Array<Byte>, codec!: JsonCodec<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeBytes(bytes, codec, options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用 T 的生成 codec。输入流归调用方所有，函数不关闭它，底层 I/O 异常可传播。
     *
     * @param input 调用方拥有的输入流。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(input: InputStream,
        options!: JsonReadOptions = JsonReadOptions.defaults): T where T <: GeneratedCodecProviderV1<T> {
        decodeStream(input, generatedCodecV1Of<T>(), options)
    }

    /**
     * 将一个完整 JSON 文档解码为 T，并拒绝尾随的非空白数据。
     *
     * 采用传入的 codec。输入流归调用方所有，函数不关闭它，底层 I/O 异常可传播。
     *
     * @param input 调用方拥有的输入流。
     * @param codec 定义 T 的 JSON 表示，必须消费一个值的 codec。
     * @param options 读取策略与资源限制；默认 JsonReadOptions.defaults。
     * @return 解码后的应用值。
     * @throws JsonException JSON 语法、值或资源限制无效；自定义 codec 与 I/O 异常可传播。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let text = "{\"x\":7}"
     * let bytes = unsafe { text.rawData().clone() }
     * let semantic: JsonCodec<DocCodecPoint> = DocCodecPointJson
     * docRequire(YJson.fromJson<DocCodecPoint>(text).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(text, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: DocCodecPointJson).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(bytes, codec: semantic).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text)).x == 7)
     * docRequire(YJson.fromJson<DocCodecPoint>(YJsonByteArrayInputStream(text), codec: semantic).x == 7)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func fromJson<T>(input: InputStream, codec!: JsonCodec<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeStream(input, codec, options)
    }

    private static func encodeString<T>(value: T,
        codec: GeneratedCompactCursorWriteCodecV1<T>,
        options: JsonWriteOptions): String {
        GeneratedSupportV1.enterGeneratedEntry()
        let writer = acquireGeneratedCompactWriter(options)
        try {
            if (writer.tryBeginGeneratedCompactRawValue()) {
                codec.writeCompactRawWithWriter(value, writer)
                return writer.finishGeneratedCompactString()
            }
            codec.write(value, writer)
            writer.finishString()
        } finally {
            releaseGeneratedCompactWriter(writer)
        }
    }

    private static func encodeStringStatic<T>(value: T,
        codec: GeneratedCompactCursorWriteCodecV1<T>,
        options: JsonWriteOptions): String
        where T <: GeneratedCompactCodecProviderV1<T> {
        GeneratedSupportV1.enterGeneratedEntry()
        let writer = acquireGeneratedCompactWriter(options)
        try {
            if (writer.tryBeginGeneratedCompactRawValue()) {
                T.generatedCompactRawV1(value, writer)
                return writer.finishGeneratedCompactString()
            }
            codec.write(value, writer)
            writer.finishString()
        } finally {
            releaseGeneratedCompactWriter(writer)
        }
    }

    private static func encodeString<T>(value: T, codec: JsonCodec<T>,
        options: JsonWriteOptions): String {
        GeneratedSupportV1.enterGeneratedEntry()
        let writer = JsonDirectWriter(options)
        writeEncoded(value, codec, writer)
        writer.finishString()
    }

    private static func encodeBytes<T>(value: T,
        codec: GeneratedCompactCursorWriteCodecV1<T>,
        options: JsonWriteOptions): Array<Byte> {
        GeneratedSupportV1.enterGeneratedEntry()
        let writer = JsonDirectWriter.bytes(config: options)
        if (writer.tryBeginGeneratedCompactRawValue()) {
            codec.writeCompactRawWithWriter(value, writer)
            return writer.finishBytes()
        }
        codec.write(value, writer)
        writer.finishBytes()
    }

    private static func encodeBytes<T>(value: T, codec: JsonCodec<T>,
        options: JsonWriteOptions): Array<Byte> {
        GeneratedSupportV1.enterGeneratedEntry()
        let writer = JsonDirectWriter.bytes(config: options)
        writeEncoded(value, codec, writer)
        writer.finishBytes()
    }

    private static func encodeStream<T>(value: T, codec: JsonCodec<T>, output: OutputStream,
        options: JsonWriteOptions): Unit {
        GeneratedSupportV1.enterGeneratedEntry()
        let writer = JsonDirectWriter(output, config: options)
        writeEncoded(value, codec, writer)
        writer.finish()
    }

    private static func decodeString<T>(text: String,
        codec: GeneratedCompactCursorWriteCodecV1<T>,
        options: JsonReadOptions): T {
        GeneratedSupportV1.enterGeneratedEntry()
        if (jsonReadOptionsUsesDefaultFastPath(options)) {
            validateJsonResourceLimits(unsafe { text.rawData() }, options)
            let reader = JsonFastReader(text)
            let result = codec.readFast(reader)
            reader.expectEnd()
            return result
        }
        let reader = JsonDirectReader(text, config: options)
        let result = codec.read(reader)
        reader.expectEnd()
        result
    }

    private static func writeEncoded<T>(value: T, codec: JsonCodec<T>,
        writer: JsonDirectWriter): Unit {
        match (codec) {
            case compact: GeneratedCompactCursorWriteCodecV1<T> =>
                if (writer.tryBeginGeneratedCompactRawValue()) {
                    compact.writeCompactRawWithCursor(value, writer, writer.generatedCursorV1())
                    return
                }
            case _ => ()
        }
        match (codec) {
            case cursor: GeneratedCursorWriteCodecV1<T> =>
                if (cursor.supportsCompactCursorWrite() && writer.tryBeginGeneratedCompactRawValue()) {
                    cursor.writeCompactWithCursor(value, writer, writer.generatedCursorV1())
                    return
                }
            case _ => ()
        }
        codec.write(value, writer)
    }
    private static func decodeString<T>(text: String, codec: JsonCodec<T>,
        options: JsonReadOptions): T {
        GeneratedSupportV1.enterGeneratedEntry()
        if (jsonReadOptionsUsesDefaultFastPath(options)) {
            validateJsonResourceLimits(unsafe { text.rawData() }, options)
            match (codec) {
                case fast: GeneratedCodecV1<T> =>
                    let reader = JsonFastReader(text)
                    let result = fast.readFast(reader)
                    reader.expectEnd()
                    return result
                case cursor: GeneratedCursorReadCodecV1<T> =>
                    let reader = JsonFastReader(text)
                    let result = cursor.readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
                    reader.expectEnd()
                    return result
                case _ => ()
            }
        }
        let reader = JsonDirectReader(text, config: options)
        let result = codec.read(reader)
        reader.expectEnd()
        result
    }

    private static func decodeBytes<T>(bytes: Array<Byte>,
        codec: GeneratedCompactCursorWriteCodecV1<T>,
        options: JsonReadOptions): T {
        GeneratedSupportV1.enterGeneratedEntry()
        if (jsonReadOptionsUsesDefaultFastPath(options)) {
            validateJsonResourceLimits(bytes, options)
            let reader = JsonFastReader(bytes)
            let result = codec.readFast(reader)
            reader.expectEnd()
            return result
        }
        let reader = JsonDirectReader(bytes, config: options)
        let result = codec.read(reader)
        reader.expectEnd()
        result
    }

    private static func decodeBytes<T>(bytes: Array<Byte>, codec: JsonCodec<T>,
        options: JsonReadOptions): T {
        GeneratedSupportV1.enterGeneratedEntry()
        if (jsonReadOptionsUsesDefaultFastPath(options)) {
            validateJsonResourceLimits(bytes, options)
            match (codec) {
                case fast: GeneratedCodecV1<T> =>
                    let reader = JsonFastReader(bytes)
                    let result = fast.readFast(reader)
                    reader.expectEnd()
                    return result
                case cursor: GeneratedCursorReadCodecV1<T> =>
                    let reader = JsonFastReader(bytes)
                    let result = cursor.readFastWithCursor(reader, GeneratedSupportV1.readCursor(reader))
                    reader.expectEnd()
                    return result
                case _ => ()
            }
        }
        let reader = JsonDirectReader(bytes, config: options)
        let result = codec.read(reader)
        reader.expectEnd()
        result
    }

    private static func decodeStream<T>(input: InputStream, codec: JsonCodec<T>,
        options: JsonReadOptions): T {
        GeneratedSupportV1.enterGeneratedEntry()
        let reader = JsonDirectReader(input, config: options)
        let result = codec.read(reader)
        reader.expectEnd()
        result
    }
}

/**
 * 内置值 codec 与容器 codec 工厂。
 *
 * 将 codec 传入 YJson 的显式 codec 重载。可组合 Option、数组、列表和字符串键映射；不会把任意类型的对象键自动转换成字符串。
 * @group 10-application 应用 API
 */
public class JsonCodecs {
    /**
     * JSON 布尔值的 codec。
     *
     * 解码拒绝不符合此表示的输入。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.bool
     * let value = YJson.fromJson("true", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "true")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop bool: JsonCodec<Bool> { get() { BoolJson } }
    /**
     * 以 JSON 数字表示 Int64 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.int64
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop int64: JsonCodec<Int64> { get() { Int64Json } }
    /**
     * 以 JSON 数字表示 Int32 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.int32
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop int32: JsonCodec<Int32> { get() { Int32Json } }
    /**
     * 以 JSON 数字表示 Int16 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.int16
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop int16: JsonCodec<Int16> { get() { Int16Json } }
    /**
     * 以 JSON 数字表示 Int8 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.int8
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop int8: JsonCodec<Int8> { get() { Int8Json } }
    /**
     * 以 JSON 数字表示 UInt64 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.uint64
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop uint64: JsonCodec<UInt64> { get() { UInt64Json } }
    /**
     * 以 JSON 数字表示 UInt32 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.uint32
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop uint32: JsonCodec<UInt32> { get() { UInt32Json } }
    /**
     * 以 JSON 数字表示 UInt16 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.uint16
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop uint16: JsonCodec<UInt16> { get() { UInt16Json } }
    /**
     * 以 JSON 数字表示 UInt8 的 codec。
     *
     * 整数解码校验目标类型的取值范围。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.uint8
     * let value = YJson.fromJson("7", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop uint8: JsonCodec<UInt8> { get() { UInt8Json } }
    /**
     * 以 JSON 数字表示 Float64 的 codec。
     *
     * 浮点编码拒绝 NaN 与无穷大；解码按目标浮点精度转换。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.float64
     * let value = YJson.fromJson("7.25", codec: codec)
     * docRequire(value == Float64(7.25))
     * docRequire(YJson.fromJson(YJson.toJson(value, codec: codec), codec: codec) == value)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop float64: JsonCodec<Float64> { get() { Float64Json } }
    /**
     * 以 JSON 数字表示 Float32 的 codec。
     *
     * 浮点编码拒绝 NaN 与无穷大；解码按目标浮点精度转换。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.float32
     * let value = YJson.fromJson("7.25", codec: codec)
     * docRequire(value == Float32(7.25))
     * docRequire(YJson.fromJson(YJson.toJson(value, codec: codec), codec: codec) == value)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop float32: JsonCodec<Float32> { get() { Float32Json } }
    /**
     * 以 JSON 数字表示 Float16 的 codec。
     *
     * 浮点编码拒绝 NaN 与无穷大；解码按目标浮点精度转换。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.float16
     * let value = YJson.fromJson("7.25", codec: codec)
     * docRequire(value == Float16(7.25))
     * docRequire(YJson.fromJson(YJson.toJson(value, codec: codec), codec: codec) == value)
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop float16: JsonCodec<Float16> { get() { Float16Json } }
    /**
     * JSON 字符串的 codec。
     *
     * 解码拒绝不符合此表示的输入。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.string
     * let value = YJson.fromJson("\"你好\"", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "\"你好\"")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop string: JsonCodec<String> { get() { StringJson } }
    /**
     * 恰好一个 Unicode 标量值的字符串 codec。
     *
     * 解码拒绝不符合此表示的输入。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.rune
     * let value = YJson.fromJson("\"中\"", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "\"中\"")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop rune: JsonCodec<Rune> { get() { RuneJson } }
    /**
     * 以 JSON 整数表示 BigInt 的 codec。
     *
     * 解码拒绝不符合此表示的输入。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.bigInt
     * let value = YJson.fromJson("123456789012345678901234567890", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "123456789012345678901234567890")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop bigInt: JsonCodec<BigInt> { get() { BigIntJson } }
    /**
     * 以 JSON 数字表示 Decimal 的 codec。
     *
     * 解码拒绝不符合此表示的输入。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.decimal
     * let value = YJson.fromJson("7.25", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "7.25")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop decimal: JsonCodec<Decimal> { get() { DecimalJson } }
    /**
     * 以 RFC 3339 字符串表示 DateTime 的 codec。
     *
     * 解码拒绝不符合此表示的输入。
     *
     * @return 可传给 YJson 显式 codec 重载的 codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.rfc3339DateTime
     * let value = YJson.fromJson("\"2024-01-02T03:04:05+08:00\"", codec: codec)
     * docRequire(YJson.toJson(value, codec: codec) == "\"2024-01-02T03:04:05+08:00\"")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static prop rfc3339DateTime: JsonCodec<DateTime> { get() { DateTimeJson } }

    /**
     * 为可选值组合 codec；None 对应 JSON null。
     *
     * 容器保留 inner 的值表示和错误行为；对象键仍为字符串。
     *
     * @param inner 用于包含值的 codec。
     * @return 组合后的 Option codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.option(JsonCodecs.int64)
     * docRequire(YJson.fromJson("null", codec: codec).isNone())
     * docRequire(YJson.fromJson("7", codec: codec).getOrThrow() == 7)
     * docRequire(YJson.toJson(Some(7), codec: codec) == "7")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func option<T>(inner: JsonCodec<T>): JsonCodec<Option<T>> {
        match (inner) {
            case _: LambdaFastRawJsonCodec<String> =>
                return (StringOptionJsonCodec() as JsonCodec<Option<T>>).getOrThrow()
            case _ => OptionJsonCodec(inner)
        }
    }

    /**
     * 为 Array 组合 JSON 数组 codec。
     *
     * 容器保留 inner 的值表示和错误行为；对象键仍为字符串。
     *
     * @param inner 用于每个数组元素的 codec。
     * @return 组合后的 Array codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.array(JsonCodecs.int64)
     * let value = YJson.fromJson("[1,2]", codec: codec)
     * docRequire(value.size == 2 && value[1] == 2)
     * docRequire(YJson.toJson(value, codec: codec) == "[1,2]")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func array<T>(inner: JsonCodec<T>): JsonCodec<Array<T>> {
        match (inner) {
            case _: LambdaFastRawJsonCodec<Int64> =>
                return (Int64ArrayJsonCodec() as JsonCodec<Array<T>>).getOrThrow()
            case _ => ArrayJsonCodec(inner)
        }
    }

    /**
     * 为 ArrayList 组合 JSON 数组 codec。
     *
     * 容器保留 inner 的值表示和错误行为；对象键仍为字符串。
     *
     * @param inner 用于每个列表元素的 codec。
     * @return 组合后的 ArrayList codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.arrayList(JsonCodecs.int64)
     * let value = YJson.fromJson("[1,2]", codec: codec)
     * docRequire(value.size == 2 && value[1] == 2)
     * docRequire(YJson.toJson(value, codec: codec) == "[1,2]")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func arrayList<T>(inner: JsonCodec<T>): JsonCodec<ArrayList<T>> {
        match (inner) {
            case _: LambdaFastRawJsonCodec<Int64> =>
                return (Int64ArrayListJsonCodec() as JsonCodec<ArrayList<T>>).getOrThrow()
            case _: LambdaFastRawJsonCodec<String> =>
                return (StringArrayListJsonCodec() as JsonCodec<ArrayList<T>>).getOrThrow()
            case _ => ArrayListJsonCodec(inner)
        }
    }

    /**
     * 为字符串键 HashMap 组合 JSON 对象 codec。
     *
     * 容器保留 inner 的值表示和错误行为；对象键仍为字符串。
     *
     * @param inner 用于每个对象成员值的 codec。
     * @return 组合后的 HashMap codec。
     *
     * @example 独立消费方（core-codec） {run}
     * ```cangjie
     * let codec = JsonCodecs.stringMap(JsonCodecs.int64)
     * let value = YJson.fromJson("{\"n\":7}", codec: codec)
     * docRequire(value["n"] == 7)
     * docRequire(YJson.toJson(value, codec: codec) == "{\"n\":7}")
     * println("ok")
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public static func stringMap<T>(inner: JsonCodec<T>): JsonCodec<HashMap<String, T>> {
        match (inner) {
            case _: LambdaFastRawJsonCodec<Int64> =>
                return (Int64HashMapJsonCodec() as JsonCodec<HashMap<String, T>>).getOrThrow()
            case _: Int64ArrayJsonCodec =>
                return (Int64ArrayHashMapJsonCodec() as JsonCodec<HashMap<String, T>>).getOrThrow()
            case _ => ()
        }
        HashMapJsonCodec(inner)
    }
}

extend Bool <: GeneratedCodecProviderV1<Bool> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Bool>): JsonCodec<Bool> {
        JsonCodecs.bool
    }
}

extend Int64 <: GeneratedCodecProviderV1<Int64> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Int64>): JsonCodec<Int64> {
        JsonCodecs.int64
    }
}

extend Int32 <: GeneratedCodecProviderV1<Int32> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Int32>): JsonCodec<Int32> {
        JsonCodecs.int32
    }
}

extend Int16 <: GeneratedCodecProviderV1<Int16> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Int16>): JsonCodec<Int16> {
        JsonCodecs.int16
    }
}

extend Int8 <: GeneratedCodecProviderV1<Int8> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Int8>): JsonCodec<Int8> {
        JsonCodecs.int8
    }
}

extend UInt64 <: GeneratedCodecProviderV1<UInt64> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<UInt64>): JsonCodec<UInt64> {
        JsonCodecs.uint64
    }
}

extend UInt32 <: GeneratedCodecProviderV1<UInt32> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<UInt32>): JsonCodec<UInt32> {
        JsonCodecs.uint32
    }
}

extend UInt16 <: GeneratedCodecProviderV1<UInt16> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<UInt16>): JsonCodec<UInt16> {
        JsonCodecs.uint16
    }
}

extend UInt8 <: GeneratedCodecProviderV1<UInt8> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<UInt8>): JsonCodec<UInt8> {
        JsonCodecs.uint8
    }
}

extend Float64 <: GeneratedCodecProviderV1<Float64> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Float64>): JsonCodec<Float64> {
        JsonCodecs.float64
    }
}

extend Float32 <: GeneratedCodecProviderV1<Float32> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Float32>): JsonCodec<Float32> {
        JsonCodecs.float32
    }
}

extend Float16 <: GeneratedCodecProviderV1<Float16> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Float16>): JsonCodec<Float16> {
        JsonCodecs.float16
    }
}

extend String <: GeneratedCodecProviderV1<String> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<String>): JsonCodec<String> {
        JsonCodecs.string
    }
}

extend Rune <: GeneratedCodecProviderV1<Rune> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Rune>): JsonCodec<Rune> {
        JsonCodecs.rune
    }
}

extend BigInt <: GeneratedCodecProviderV1<BigInt> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<BigInt>): JsonCodec<BigInt> {
        JsonCodecs.bigInt
    }
}

extend Decimal <: GeneratedCodecProviderV1<Decimal> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Decimal>): JsonCodec<Decimal> {
        JsonCodecs.decimal
    }
}

extend<T> Option<T> <: GeneratedCodecProviderV1<Option<T>> where T <: GeneratedCodecProviderV1<T> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Option<T>>): JsonCodec<Option<T>> {
        JsonCodecs.option(generatedCodecV1Of<T>())
    }
}

extend<T> Array<T> <: GeneratedCodecProviderV1<Array<T>> where T <: GeneratedCodecProviderV1<T> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<Array<T>>): JsonCodec<Array<T>> {
        JsonCodecs.array(generatedCodecV1Of<T>())
    }
}

extend<T> ArrayList<T> <: GeneratedCodecProviderV1<ArrayList<T>> where T <: GeneratedCodecProviderV1<T> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<ArrayList<T>>): JsonCodec<ArrayList<T>> {
        JsonCodecs.arrayList(generatedCodecV1Of<T>())
    }
}

extend<T> HashMap<String, T> <: GeneratedCodecProviderV1<HashMap<String, T>>
    where T <: GeneratedCodecProviderV1<T> {
    public static func generatedCodecV1(_: GeneratedCodecTokenV1<HashMap<String, T>>): JsonCodec<HashMap<String, T>> {
        JsonCodecs.stringMap(generatedCodecV1Of<T>())
    }
}
