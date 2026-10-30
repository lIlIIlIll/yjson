package yjson

import std.collection.*
import std.convert.Parsable
import std.math.numeric.*

private let JSON_STREAM_TAPE_NULL: Byte = 0u8
private let JSON_STREAM_TAPE_BOOL: Byte = 1u8
private let JSON_STREAM_TAPE_INT: Byte = 2u8
private let JSON_STREAM_TAPE_NUMBER: Byte = 3u8
private let JSON_STREAM_TAPE_STRING: Byte = 4u8
private let JSON_STREAM_TAPE_ARRAY: Byte = 5u8
private let JSON_STREAM_TAPE_OBJECT: Byte = 6u8

private class JsonStreamTapeWriteContext {
    let objectContext: Bool
    let countPosition: Int64
    let pathDepth: Int64
    let entryPathPushed: Bool
    var count: UInt32 = 0u32
    var expectingValue: Bool = false
    var pendingObjectPathPushed: Bool = false
    var nextArrayIndex: Int64 = 0

    init(objectContext: Bool, countPosition: Int64, pathDepth: Int64, entryPathPushed: Bool) {
        this.objectContext = objectContext
        this.countPosition = countPosition
        this.pathDepth = pathDepth
        this.entryPathPushed = entryPathPushed
    }
}

/**
 * 将 codec 写入调用记录为 Native 桥接使用的 V1 二进制 tape。
 *
 * 供匹配版本的第一方桥接调用。tape 使用 YJT1 头、类型标签、容器条目数和 UTF-8 数据，不是 JSON 文本。实例只接受一个根值；finishTape 成功后禁止继续写入或再次完成。应用 codec 依赖 JsonWriter。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class BackendTapeWriterV1 <: JsonWriter & GeneratedBulkWriterV1 & GeneratedWriteStateV1Owner {
    private let bytes = ArrayList<Byte>()
    private let contexts = ArrayList<JsonStreamTapeWriteContext>()
    private var rootWritten: Bool = false
    private var finished: Bool = false
    private let generatedState: GeneratedWriteStateV1

    /**
     * 创建含 YJT1 头的空 tape 写入器。
     *
     * config 用于生成代码路径和深度状态；tape 不应用文本排版、HTML 转义或 JSON 输出字节预算。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param config 传给 GeneratedWriteStateV1 的写入选项，默认为 JsonWriteOptions.defaults。
     */
    public init(config!: JsonWriteOptions = JsonWriteOptions.defaults) {
        generatedState = GeneratedWriteStateV1(config)
        bytes.add(b'Y')
        bytes.add(b'J')
        bytes.add(b'T')
        bytes.add(b'1')
    }

    /**
     * 取得共用的生成代码状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 该实例持有的路径和深度状态对象。
     */
    public func generatedWriteStateV1(): GeneratedWriteStateV1 { generatedState }

    /**
     * 取得生成代码状态中的当前 JSON 路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前路径，根位置为空字符串。
     */
    public func path(): String { generatedState.currentPath() }

    /**
     * 创建带当前路径的 JSON 异常。
     *
     * 只构造异常，不抛出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param message 异常消息。
     * @param code 错误码。
     * @return 包含指定消息、错误码和当前路径的 JsonException。
     */
    public func error(message: String, code: String): JsonException {
        JsonException(message, code: code, path: path())
    }

    /**
     * 开始记录一个对象值。
     *
     * 写入类型标签和待回填的条目数，并压入容器上下文。对象中的值须先写字段名。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 已写过根值、对象字段名缺失或容器条目数超出 UInt32 范围。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func startObject(): Unit {
        let pathPushed = beforeValue()
        bytes.add(JSON_STREAM_TAPE_OBJECT)
        let countPosition = bytes.size
        appendUInt32(0u32)
        contexts.add(JsonStreamTapeWriteContext(true, countPosition,
            generatedState.pathDepth(), pathPushed))
    }

    /**
     * 结束当前对象并回填条目数。
     *
     * 结束对象前必须写完最后一个字段的值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有对应容器、容器类型不符或对象仍等待字段值。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func endObject(): Unit { endContainer(true) }

    /**
     * 开始记录一个数组值。
     *
     * 写入类型标签和待回填的条目数，并压入容器上下文。对象中的值须先写字段名。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 已写过根值、对象字段名缺失或容器条目数超出 UInt32 范围。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func startArray(): Unit {
        let pathPushed = beforeValue()
        bytes.add(JSON_STREAM_TAPE_ARRAY)
        let countPosition = bytes.size
        appendUInt32(0u32)
        contexts.add(JsonStreamTapeWriteContext(false, countPosition,
            generatedState.pathDepth(), pathPushed))
    }

    /**
     * 结束当前数组并回填条目数。
     *
     * 结束对象前必须写完最后一个字段的值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有对应容器、容器类型不符或对象仍等待字段值。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func endArray(): Unit { endContainer(false) }

    /**
     * 记录对象的下一个字段名。
     *
     * 按长度和 UTF-8 字节保存名称，随后必须写一个字段值；不检查重复名称。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 待记录的 JSON 字段名。
     * @throws JsonException 当前位置不能写字段名，或名称超过 UInt32 字节长度。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeName(name: String): Unit {
        requireWritable()
        if (contexts.isEmpty()) { throw JsonException("Cannot write a field name outside object") }
        let context = contexts[contexts.size - 1]
        if (!context.objectContext || context.expectingValue) {
            throw JsonException("Cannot write a field name here")
        }
        appendString(name)
        context.expectingValue = true
        context.pendingObjectPathPushed = generatedState.pushAutoField(name, context.pathDepth)
    }

    /**
     * 记录一个null值。
     *
     * 写入 null 类型标签。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 写入位置无效或容器条目数超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeNull(): Unit {
        let pathPushed = beforeValue()
        try { bytes.add(JSON_STREAM_TAPE_NULL) }
        finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 记录一个布尔值。
     *
     * 写入布尔类型标签和 0 或 1 字节。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待记录的布尔值。
     * @throws JsonException 写入位置无效或容器条目数超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeBool(value: Bool): Unit {
        let pathPushed = beforeValue()
        try {
            bytes.add(JSON_STREAM_TAPE_BOOL)
            bytes.add(if (value) { 1u8 } else { 0u8 })
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 记录一个Int64值。
     *
     * 保存整数标签及 64 位整数位模式。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待记录的有符号整数。
     * @throws JsonException 写入位置无效或容器条目数超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeInt64(value: Int64): Unit {
        let pathPushed = beforeValue()
        try {
            bytes.add(JSON_STREAM_TAPE_INT)
            appendUInt64(int64Bits(value))
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 记录一个UInt64值。
     *
     * 不大于 Int64.Max 的值使用整数条目，其余使用十进制数字文本条目。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待记录的无符号整数。
     * @throws JsonException 写入位置无效或容器条目数超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeUInt64(value: UInt64): Unit {
        if (value <= UInt64(0x7FFF_FFFF_FFFF_FFFF)) {
            writeInt64(Int64(value))
        } else {
            writeNumberLiteral(value.toString())
        }
    }

    /**
     * 记录一个有限 Float64值。
     *
     * 拒绝 NaN 和无穷大，再将 value.toString() 作为数字文本保存。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待记录的有限浮点数。
     * @throws JsonException 写入位置无效或容器条目数超限。浮点数为 NaN 或无穷大时也失败。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeFloat64(value: Float64): Unit {
        ensureFiniteJsonFloat(value)
        writeNumberLiteral(value.toString())
    }

    /**
     * 记录一个JSON 数字文本值。
     *
     * 先校验 JSON 数字语法，再保留原拼写。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 符合 JSON 数字语法的完整数字文本。
     * @throws JsonException 写入位置无效或容器条目数超限。数字文本无效时为 invalid_number，长度超限时为 output_too_large。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeNumberLiteral(value: String): Unit {
        let pathPushed = beforeValue()
        try {
            if (!isValidJsonNumberLiteral(value)) {
                throw error("Invalid JSON number literal", "invalid_number")
            }
            bytes.add(JSON_STREAM_TAPE_NUMBER)
            appendString(value)
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 记录一个字符串值。
     *
     * 保存标签、UTF-8 长度和字符串内容，不生成 JSON 转义文本。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 待记录的字符串。
     * @throws JsonException 写入位置无效或容器条目数超限。字符串超过 UInt32 字节长度时为 output_too_large。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func writeString(value: String): Unit {
        let pathPushed = beforeValue()
        try {
            bytes.add(JSON_STREAM_TAPE_STRING)
            appendString(value)
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 将Int64 数组记录为一个数组值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的Int64 数组，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactInt64Array(values: Array<Int64>): Bool {
        startArray()
        for (value in values) { writeInt64(value) }
        endArray()
        true
    }

    /**
     * 将Float64 数组记录为一个数组值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的Float64 数组，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限，或元素为 NaN 或无穷大。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactFloat64Array(values: Array<Float64>): Bool {
        startArray()
        for (value in values) { writeFloat64(value) }
        endArray()
        true
    }

    /**
     * 将String 数组记录为一个数组值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的String 数组，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactStringArray(values: Array<String>): Bool {
        startArray()
        for (value in values) { writeString(value) }
        endArray()
        true
    }

    /**
     * 将Int64 列表记录为一个数组值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的Int64 列表，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactInt64ArrayList(values: ArrayList<Int64>): Bool {
        startArray()
        for (value in values) { writeInt64(value) }
        endArray()
        true
    }

    /**
     * 将String 列表记录为一个数组值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的String 列表，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactStringArrayList(values: ArrayList<String>): Bool {
        startArray()
        for (value in values) { writeString(value) }
        endArray()
        true
    }

    /**
     * 将字符串到 Int64 的映射记录为一个对象值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。字段按映射迭代顺序记录，不额外排序。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的字符串到 Int64 的映射，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactInt64Map(values: HashMap<String, Int64>): Bool {
        startObject()
        for ((name, value) in values) {
            writeName(name)
            writeInt64(value)
        }
        endObject()
        true
    }

    /**
     * 将字符串到 String 的映射记录为一个对象值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。字段按映射迭代顺序记录，不额外排序。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的字符串到 String 的映射，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactStringMap(values: HashMap<String, String>): Bool {
        startObject()
        for ((name, value) in values) {
            writeName(name)
            writeString(value)
        }
        endObject()
        true
    }

    /**
     * 将字符串到 Int64 数组的映射记录为一个对象值。
     *
     * 逐项调用对应 tape 写入方法，正常完成后总是返回 true。字段按映射迭代顺序记录，不额外排序。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 待记录的字符串到 Int64 数组的映射，方法在调用期间遍历其内容。
     * @return 正常完成时为 true；该实现没有返回 false 的分支。
     * @throws JsonException 写入位置或容器状态无效、长度超限。
     * @throws IllegalStateException finishTape 已成功完成。
     */
    public func tryWriteCompactInt64ArrayMap(values: HashMap<String, Array<Int64>>): Bool {
        startObject()
        for ((name, value) in values) {
            writeName(name)
            startArray()
            for (item in value) { writeInt64(item) }
            endArray()
        }
        endObject()
        true
    }

    /**
     * 完成单个根值并导出 tape 字节数组。
     *
     * 仅在所有容器都已关闭且写过根值时成功；成功后将实例置为已完成状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 包含 YJT1 头和一个根值的新字节数组。
     * @throws JsonException 根值缺失或容器尚未闭合，错误码为 codec_contract。
     * @throws IllegalStateException 该实例已经完成。
     */
    public func finishTape(): Array<Byte> {
        requireWritable()
        if (!contexts.isEmpty() || !rootWritten) {
            throw JsonException("Unbalanced JSON tape writer state", code: "codec_contract")
        }
        finished = true
        bytes.toArray()
    }

    private func beforeValue(): Bool {
        requireWritable()
        if (contexts.isEmpty()) {
            if (rootWritten) { throw JsonException("Only one root JSON value may be written") }
            rootWritten = true
            return false
        }
        let context = contexts[contexts.size - 1]
        if (context.objectContext) {
            if (!context.expectingValue) {
                throw JsonException("Object values must be preceded by a field name")
            }
            context.expectingValue = false
            let pathPushed = context.pendingObjectPathPushed
            context.pendingObjectPathPushed = false
            generatedState.beginAutoValue(pathPushed)
            if (context.count == 0xFFFF_FFFFu32) {
                throw JsonException("JSON container is too large", code: "output_too_large")
            }
            context.count++
            return pathPushed
        }
        let pathPushed = generatedState.pushAutoIndex(context.nextArrayIndex, context.pathDepth)
        context.nextArrayIndex++
        generatedState.beginAutoValue(pathPushed)
        if (context.count == 0xFFFF_FFFFu32) {
            throw JsonException("JSON container is too large", code: "output_too_large")
        }
        context.count++
        pathPushed
    }

    private func endContainer(expectedObject: Bool): Unit {
        requireWritable()
        if (contexts.isEmpty()) { throw JsonException("Unbalanced JSON tape writer state") }
        let index = contexts.size - 1
        let context = contexts[index]
        if (context.objectContext != expectedObject || context.expectingValue) {
            throw JsonException("Unbalanced JSON tape writer state")
        }
        patchUInt32(context.countPosition, context.count)
        contexts.remove(at: index)
        generatedState.completeAutoValue(context.entryPathPushed)
    }

    private func appendString(value: String): Unit {
        if (value.size > 0xFFFF_FFFF) {
            throw JsonException("JSON string is too large", code: "output_too_large")
        }
        appendUInt32(UInt32(value.size))
        bytes.add(all: unsafe { value.rawData() })
    }

    private func appendUInt32(value: UInt32): Unit {
        for (shift in 0..4) { bytes.add(UInt8(UInt64(value >> (shift * 8)) & 0xFFu64)) }
    }

    private func appendUInt64(value: UInt64): Unit {
        for (shift in 0..8) { bytes.add(UInt8((value >> (shift * 8)) & 0xFFu64)) }
    }

    private func patchUInt32(position: Int64, value: UInt32): Unit {
        for (shift in 0..4) {
            bytes[position + shift] = UInt8(UInt64(value >> (shift * 8)) & 0xFFu64)
        }
    }

    private func requireWritable(): Unit {
        if (finished) { throw IllegalStateException("JSON tape writer is finished") }
    }

    @OverflowWrapping
    private func int64Bits(value: Int64): UInt64 { UInt64(value) }
}

private class JsonStreamTapeReadContext {
    let objectContext: Bool
    let pathDepth: Int64
    let entryPathPushed: Bool
    var remaining: UInt32
    var expectingValue: Bool = false
    var pendingObjectPathPushed: Bool = false
    var nextArrayIndex: Int64 = 0

    init(objectContext: Bool, remaining: UInt32, pathDepth: Int64, entryPathPushed: Bool) {
        this.objectContext = objectContext
        this.remaining = remaining
        this.pathDepth = pathDepth
        this.entryPathPushed = entryPathPushed
    }
}

/**
 * 顺序消费 Native 桥接产生的 V1 二进制 tape。
 *
 * 直接保留传入字节数组，读取期间调用方不得修改它。构造只检查 YJT1 头及最小长度，读取时检查类型和区间。面向可信的匹配版本 tape，字符串按 UTF-8 直接构造而不重新校验。容器须完整消费，再调用对应结束方法。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class BackendTapeReaderV1 <: JsonReader & GeneratedReadStateV1Owner {
    private let bytes: Array<Byte>
    private let config: JsonReadOptions
    private let replayBudgetPrevalidated: Bool
    private let contexts = ArrayList<JsonStreamTapeReadContext>()
    private var position: Int64 = 4
    private var rootConsumed: Bool = false
    private var valuePrefixReady: Bool = false
    private var valuePrefixPathPushed: Bool = false
    private let generatedState: GeneratedReadStateV1

    /**
     * 创建从 tape 根值开始的读取器。
     *
     * 读取位置从 YJT1 头后开始。config 用于生成代码状态、未知字段策略及派生 replay 读取器；构造器不重新按 JSON 文本规则验证整个 tape。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param bytes 带 YJT1 头的 tape 数组；读取器直接持有它。
     * @param config 读取选项，默认为 JsonReadOptions.defaults。
     * @param replayBudgetPrevalidated 是否由上游完成 replay 字节预算验证；为 true 时 readReplayValue 不再按 maxBytes 检查捕获长度。
     * @throws JsonException 输入长度不足或 YJT1 头不符，错误码为 codec_contract。
     */
    public init(bytes: Array<Byte>, config!: JsonReadOptions = JsonReadOptions.defaults,
        replayBudgetPrevalidated!: Bool = false) {
        this.bytes = bytes
        this.config = config
        this.replayBudgetPrevalidated = replayBudgetPrevalidated
        generatedState = GeneratedReadStateV1(config)
        if (bytes.size < 5 || bytes[0] != b'Y' || bytes[1] != b'J' ||
            bytes[2] != b'T' || bytes[3] != b'1') {
            throw JsonException("Invalid JSON stream tape", code: "codec_contract")
        }
    }

    /**
     * 取得构造时传入的读取选项。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 该读取器保存的 JsonReadOptions。
     */
    public func readConfig(): JsonReadOptions { config }

    /**
     * 取得共用的生成代码状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 该实例持有的路径和深度状态对象。
     */
    public func generatedReadStateV1(): GeneratedReadStateV1 { generatedState }

    /**
     * 取得生成代码状态中的当前 JSON 路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前路径，根位置为空字符串。
     */
    public func path(): String { generatedState.currentPath() }

    /**
     * 查询 tape 对应的文本位置。
     *
     * 二进制 tape 不保存原始 JSON 文本位置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 始终为 None。
     */
    public func location(): Option<JsonLocation> { None<JsonLocation> }

    /**
     * 创建带当前路径的 JSON 异常。
     *
     * 只构造异常，不抛出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param message 异常消息。
     * @param code 错误码。
     * @return 包含指定消息、错误码和当前路径的 JsonException。
     */
    public func error(message: String, code: String): JsonException {
        JsonException(message, code: code, path: path())
    }

    /**
     * 消费一个值并复制为可重放的 tape。
     *
     * 捕获副本含一个新 YJT1 头，与当前读取器后续位置独立。返回值关闭后不能再查询或打开读取器。maxBytes 检查值条目的 tape 字节数，不含新头；replayBudgetPrevalidated 为 true 时跳过该检查。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxBytes 捕获值的 tape 字节预算；0 表示不设此项上限，不能为负。
     * @return 保存该值副本和当前读取选项的 GeneratedReplayValueV1。
     * @throws IllegalArgumentException maxBytes 为负。
     * @throws JsonException tape 或状态无效，或超过未预验证的预算（buffered_value_too_large）。
     */
    public func readReplayValue(maxBytes: Int64): GeneratedReplayValueV1 {
        if (maxBytes < 0) { throw IllegalArgumentException("maxBytes must not be negative") }
        let pathPushed = beforeValue()
        try {
            let start = position
            let end = scanValue(position)
            if (!replayBudgetPrevalidated && maxBytes > 0 && end - start > maxBytes) {
                throw JsonException("Polymorphic JSON object exceeds ${maxBytes} bytes",
                    code: "buffered_value_too_large", path: path())
            }
            position = end
            let captured = ArrayList<Byte>()
            captured.add(b'Y'); captured.add(b'J'); captured.add(b'T'); captured.add(b'1')
            captured.add(all: bytes[start..end])
            JsonStreamTapeReplayValue(captured.toArray(), config)
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 确认已完整消费且只消费一个根值。
     *
     * 要求没有未关闭容器，已读取根值，且当前位置恰好位于输入末尾。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 仍有容器、未读根值或存在尾随数据，错误码为 parse_error。
     */
    public func expectEnd(): Unit {
        if (!contexts.isEmpty() || !rootConsumed || position != bytes.size) {
            fail("Unexpected trailing JSON tape data")
        }
    }

    /**
     * 消费对象条目的头并进入容器。
     *
     * 保存条目数和当前路径上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 读取状态无效、下一值类型不符或 tape 截断，错误码为 parse_error。
     */
    public func startObject(): Unit {
        let pathPushed = beforeValue()
        expectKind(JSON_STREAM_TAPE_OBJECT)
        contexts.add(JsonStreamTapeReadContext(true, readUInt32Raw(),
            generatedState.pathDepth(), pathPushed))
    }

    /**
     * 结束已完整消费的对象上下文。
     *
     * tape 容器没有额外结束标签；本方法校验条目数并弹出上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有对应容器、类型不符或仍有未消费条目或字段值，错误码为 parse_error。
     */
    public func endObject(): Unit { endContainer(true) }

    /**
     * 检查对象是否还有可读取的字段名。
     *
     * 不消费字段名或值；当前字段仍等待值时返回 false。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 对象剩余条目大于零且不等待字段值时为 true。
     * @throws JsonException 当前不在对象上下文中，错误码为 parse_error。
     */
    public func hasObjectField(): Bool {
        let context = currentContext(true)
        !context.expectingValue && context.remaining > 0u32
    }

    /**
     * 消费字段名并定位到字段值。
     *
     * 记录对应自动路径；随后必须消费该字段值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 从 tape 读取的字段名称。
     * @throws JsonException 当前位置不能读字段名或 tape 截断，错误码为 parse_error。
     */
    public func readName(): String {
        let context = currentContext(true)
        if (context.expectingValue || context.remaining == 0u32) {
            fail("Cannot read a field name here")
        }
        let name = readStringRaw()
        context.expectingValue = true
        context.pendingObjectPathPushed = generatedState.pushAutoField(name, context.pathDepth)
        name
    }

    /**
     * 消费字段名并查找候选索引。
     *
     * 未匹配时也已经消费名称，随后仍须消费值；是否拒绝未知名称由 config 决定。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param candidates 按返回索引排列的候选字段名称。
     * @return 首个相等候选的索引；允许未知字段时未匹配返回 -1。
     * @throws JsonException 字段名读取失败，或拒绝未知字段且未匹配（unknown_field）。
     */
    public func readNameId(candidates: Array<String>): Int64 {
        let name = readName()
        for (index in 0..candidates.size) {
            if (candidates[index] == name) { return index }
        }
        if (config.rejectsUnknownFields()) {
            throw JsonException("Unknown JSON field: ${name}", code: "unknown_field")
        }
        -1
    }

    /**
     * 消费数组条目的头并进入容器。
     *
     * 保存条目数和当前路径上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 读取状态无效、下一值类型不符或 tape 截断，错误码为 parse_error。
     */
    public func startArray(): Unit {
        let pathPushed = beforeValue()
        expectKind(JSON_STREAM_TAPE_ARRAY)
        contexts.add(JsonStreamTapeReadContext(false, readUInt32Raw(),
            generatedState.pathDepth(), pathPushed))
    }

    /**
     * 结束已完整消费的数组上下文。
     *
     * tape 容器没有额外结束标签；本方法校验条目数并弹出上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有对应容器、类型不符或仍有未消费条目或字段值，错误码为 parse_error。
     */
    public func endArray(): Unit { endContainer(false) }

    /**
     * 检查数组是否还有未消费元素。
     *
     * 不推进读取位置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前数组剩余元素数大于零时为 true。
     * @throws JsonException 当前不在数组上下文中，错误码为 parse_error。
     */
    public func hasArrayItem(): Bool {
        currentContext(false).remaining > 0u32
    }

    /**
     * 尝试消费一个 null 条目。
     *
     * 不是 null 时保留值标签位置，并缓存已进入的值上下文供下次值读取使用。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 消费 null 时为 true；下一值不是 null 时为 false。
     * @throws JsonException 读取状态无效或 tape 截断，错误码为 parse_error。
     */
    public func tryReadNull(): Bool {
        let pathPushed = beforeValue()
        if (peekByte() != JSON_STREAM_TAPE_NULL) {
            valuePrefixReady = true
            valuePrefixPathPushed = pathPushed
            return false
        }
        position++
        generatedState.completeAutoValue(pathPushed)
        true
    }

    /**
     * 消费一个 null 条目。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 读取状态无效、值不是 null 或 tape 截断，错误码为 parse_error。
     */
    public func readNull(): Unit {
        let pathPushed = beforeValue()
        try { expectKind(JSON_STREAM_TAPE_NULL) }
        finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 消费一个布尔条目。
     *
     * 载荷为零时返回 false，非零时返回 true。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 该条目的布尔值。
     * @throws JsonException 读取状态无效、值类型不符或 tape 截断，错误码为 parse_error。
     */
    public func readBool(): Bool {
        let pathPushed = beforeValue()
        try {
            expectKind(JSON_STREAM_TAPE_BOOL)
            readByteRaw() != 0u8
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 消费一个字符串条目。
     *
     * 按记录长度读取 UTF-8 字节，不重新校验编码。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 字符串内容。
     * @throws JsonException 读取状态无效、值类型不符或 tape 截断，错误码为 parse_error。
     */
    public func readString(): String {
        let pathPushed = beforeValue()
        try {
            expectKind(JSON_STREAM_TAPE_STRING)
            readStringRaw()
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 读取并丢弃一个字符串条目。
     *
     * 内部调用 readString，仍会构造字符串。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 读取状态无效、值不是字符串或 tape 截断，错误码为 parse_error。
     */
    public func skipString(): Unit { let _ = readString() }

    /**
     * 消费一个可表示为 Int64 的整数。
     *
     * 接受整数条目或可由 Int64.parse 解析的数字文本。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Int64。
     * @throws JsonException 读取状态无效、值类型不符、数字不能表示为目标整数或 tape 截断，错误码为 parse_error。
     */
    public func readInt64(): Int64 {
        let pathPushed = beforeValue()
        try {
            match {
                case peekByte() == JSON_STREAM_TAPE_INT => position++; bitsToInt64(readUInt64Raw())
                case peekByte() == JSON_STREAM_TAPE_NUMBER =>
                    position++
                    let literal = readStringRaw()
                    try { Int64.parse(literal) } catch (_: Exception) { fail("Expected integer") }
                case _ => fail("Expected integer")
            }
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 消费一个可表示为 UInt64 的整数。
     *
     * 接受非负整数条目或可由 UInt64.parse 解析的数字文本。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 UInt64。
     * @throws JsonException 读取状态无效、值类型不符、数字不能表示为目标整数或 tape 截断，错误码为 parse_error。
     */
    public func readUInt64(): UInt64 {
        let pathPushed = beforeValue()
        try {
            match {
                case peekByte() == JSON_STREAM_TAPE_INT =>
                    position++
                    let value = bitsToInt64(readUInt64Raw())
                    if (value < 0) { fail("Expected unsigned integer") }
                    UInt64(value)
                case peekByte() == JSON_STREAM_TAPE_NUMBER =>
                    position++
                    let literal = readStringRaw()
                    try { UInt64.parse(literal) } catch (_: Exception) { fail("Expected unsigned integer") }
                case _ => fail("Expected unsigned integer")
            }
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 消费数字并交给 Float64.parse 转换。
     *
     * 先通过 readNumberLiteral 消费数字，再调用标准库解析。不额外限定浮点结果必须有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Float64 值。
     * @throws JsonException 数字条目读取失败。
     * @throws Exception 标准库数值解析失败时传播原异常。
     */
    public func readFloat64(): Float64 { Float64.parse(readNumberLiteral()) }
    /**
     * 消费数字并交给 BigInt.parse 转换。
     *
     * 先通过 readNumberLiteral 消费数字，再调用标准库解析。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 BigInt 值。
     * @throws JsonException 数字条目读取失败。
     * @throws Exception 标准库数值解析失败时传播原异常。
     */
    public func readBigInt(): BigInt { BigInt.parse(readNumberLiteral()) }
    /**
     * 消费数字并交给 Decimal.parse 转换。
     *
     * 先通过 readNumberLiteral 消费数字，再调用标准库解析。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Decimal 值。
     * @throws JsonException 数字条目读取失败。
     * @throws Exception 标准库数值解析失败时传播原异常。
     */
    public func readDecimal(): Decimal { Decimal.parse(readNumberLiteral()) }

    /**
     * 消费一个数字并取得数字文本。
     *
     * 整数条目转换为十进制文本，数字文本条目直接读取内容。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 原数字文本，或整数条目的十进制表示。
     * @throws JsonException 读取状态无效、值类型不符或 tape 截断，错误码为 parse_error。
     */
    public func readNumberLiteral(): String {
        let pathPushed = beforeValue()
        try {
            match {
                case peekByte() == JSON_STREAM_TAPE_INT => position++; bitsToInt64(readUInt64Raw()).toString()
                case peekByte() == JSON_STREAM_TAPE_NUMBER => position++; readStringRaw()
                case _ => fail("Expected number")
            }
        } finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 扫描并跳过一个完整 tape 值。
     *
     * 递归按条目数跳过容器，不物化 JsonNode，不额外设置容器深度预算。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 读取状态无效、标签无效或 tape 截断。
     */
    public func skipValue(): Unit {
        let pathPushed = beforeValue()
        try { position = scanValue(position) }
        finally { generatedState.completeAutoValue(pathPushed) }
    }

    /**
     * 在容器深度预算内跳过一个 tape 值。
     *
     * 标量不消耗深度；每层对象或数组消耗一层预算。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxDepth 允许的相对容器层数，不能为负；0 只允许标量。
     * @throws IllegalArgumentException maxDepth 为负。
     * @throws JsonException tape 或状态无效，或深度超限（max_depth）。
     */
    public func skipValueWithDepth(maxDepth: Int64): Unit {
        if (maxDepth < 0) { throw IllegalArgumentException("maxDepth must not be negative") }
        let pathPushed = beforeValue()
        try { position = scanValueBounded(position, 0, maxDepth) }
        finally { generatedState.completeAutoValue(pathPushed) }
    }

    func copyNextValueTo(writer: JsonWriter): Unit {
        match {
            case peekByte() == JSON_STREAM_TAPE_NULL => readNull(); writer.writeNull()
            case peekByte() == JSON_STREAM_TAPE_BOOL => writer.writeBool(readBool())
            case peekByte() == JSON_STREAM_TAPE_INT => writer.writeInt64(readInt64())
            case peekByte() == JSON_STREAM_TAPE_NUMBER => writer.writeNumberLiteral(readNumberLiteral())
            case peekByte() == JSON_STREAM_TAPE_STRING => writer.writeString(readString())
            case peekByte() == JSON_STREAM_TAPE_ARRAY =>
                startArray(); writer.startArray()
                while (hasArrayItem()) { copyNextValueTo(writer) }
                endArray(); writer.endArray()
            case peekByte() == JSON_STREAM_TAPE_OBJECT =>
                startObject(); writer.startObject()
                while (hasObjectField()) {
                    let name = readName()
                    writer.writeName(name)
                    copyNextValueTo(writer)
                }
                endObject(); writer.endObject()
            case _ => fail("Unknown JSON tape value kind")
        }
    }

    /**
     * 消费一个 tape 值并构造可修改 AST。
     *
     * 重名对象字段后值覆盖前值；数字优先表示为 Int64，其余保留数字文本。此重载不设置节点预算。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 独立构造的 JsonNode 树。
     * @throws JsonException 读取状态、类型标签或 tape 数据无效。
     */
    public func readNode(): JsonNode {
        match {
            case peekByte() == JSON_STREAM_TAPE_NULL => readNull(); JsonNullValue()
            case peekByte() == JSON_STREAM_TAPE_BOOL => JsonBoolValue(readBool())
            case peekByte() == JSON_STREAM_TAPE_INT => JsonIntValue(readInt64())
            case peekByte() == JSON_STREAM_TAPE_NUMBER =>
                let literal = readNumberLiteral()
                try { JsonIntValue(Int64.parse(literal)) }
                catch (_: Exception) { JsonNumberLiteralValue.fromParsedLiteral(literal) }
            case peekByte() == JSON_STREAM_TAPE_STRING => JsonStringValue(readString())
            case peekByte() == JSON_STREAM_TAPE_ARRAY =>
                let value = JsonArray(); startArray()
                while (hasArrayItem()) { value.add(readNode()) }
                endArray(); value
            case peekByte() == JSON_STREAM_TAPE_OBJECT =>
                let value = JsonObject(); startObject()
                while (hasObjectField()) { value.put(readName(), readNode()) }
                endObject(); value
            case _ => fail("Unknown JSON tape value kind")
        }
    }

    /**
     * 在节点预算内消费一个 tape 值并构造 AST。
     *
     * 每个 JSON 值消耗一个节点，包括容器本身，字段名不单独计数。重名对象字段后值覆盖前值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxNodes 允许构造的 JSON 值节点总数，必须为正。
     * @return 独立构造的 JsonNode 树。
     * @throws IllegalArgumentException maxNodes 不为正。
     * @throws JsonException 读取失败或节点预算耗尽（work_limit_exceeded）。
     */
    public func readNode(maxNodes: Int64): JsonNode {
        if (maxNodes <= 0) {
            throw IllegalArgumentException("maxNodes must be positive")
        }
        readNodeBounded([maxNodes])
    }

    private func readNodeBounded(remaining: Array<Int64>): JsonNode {
        if (remaining[0] <= 0) {
            throw JsonException("Materialization work limit exceeded",
                code: "work_limit_exceeded", path: path())
        }
        remaining[0]--
        match {
            case peekByte() == JSON_STREAM_TAPE_NULL => readNull(); JsonNullValue()
            case peekByte() == JSON_STREAM_TAPE_BOOL => JsonBoolValue(readBool())
            case peekByte() == JSON_STREAM_TAPE_INT => JsonIntValue(readInt64())
            case peekByte() == JSON_STREAM_TAPE_NUMBER =>
                let literal = readNumberLiteral()
                try { JsonIntValue(Int64.parse(literal)) }
                catch (_: Exception) { JsonNumberLiteralValue.fromParsedLiteral(literal) }
            case peekByte() == JSON_STREAM_TAPE_STRING => JsonStringValue(readString())
            case peekByte() == JSON_STREAM_TAPE_ARRAY =>
                let value = JsonArray(); startArray()
                while (hasArrayItem()) { value.add(readNodeBounded(remaining)) }
                endArray(); value
            case peekByte() == JSON_STREAM_TAPE_OBJECT =>
                let value = JsonObject(); startObject()
                while (hasObjectField()) {
                    value.put(readName(), readNodeBounded(remaining))
                }
                endObject(); value
            case _ => fail("Unknown JSON tape value kind")
        }
    }

    private func beforeValue(): Bool {
        if (valuePrefixReady) {
            valuePrefixReady = false
            let pathPushed = valuePrefixPathPushed
            valuePrefixPathPushed = false
            return pathPushed
        }
        if (contexts.isEmpty()) {
            if (rootConsumed) { fail("Only one root JSON value may be read") }
            rootConsumed = true
            return false
        }
        let context = contexts[contexts.size - 1]
        if (context.remaining == 0u32) { fail("JSON container has no remaining values") }
        if (context.objectContext) {
            if (!context.expectingValue) { fail("Object values must follow a field name") }
            context.expectingValue = false
            let pathPushed = context.pendingObjectPathPushed
            context.pendingObjectPathPushed = false
            context.remaining--
            generatedState.beginAutoValue(pathPushed)
            return pathPushed
        }
        let pathPushed = generatedState.pushAutoIndex(context.nextArrayIndex, context.pathDepth)
        context.nextArrayIndex++
        context.remaining--
        generatedState.beginAutoValue(pathPushed)
        pathPushed
    }

    private func endContainer(expectedObject: Bool): Unit {
        let context = currentContext(expectedObject)
        if (context.remaining != 0u32 || context.expectingValue) {
            fail("JSON container was not fully consumed")
        }
        contexts.remove(at: contexts.size - 1)
        generatedState.completeAutoValue(context.entryPathPushed)
    }

    private func currentContext(expectedObject: Bool): JsonStreamTapeReadContext {
        if (contexts.isEmpty()) { fail("Not reading a JSON container") }
        let context = contexts[contexts.size - 1]
        if (context.objectContext != expectedObject) { fail("JSON container type mismatch") }
        context
    }

    private func scanValue(start: Int64): Int64 {
        var cursor = start
        let kind = byteAt(cursor); cursor++
        match {
            case kind == JSON_STREAM_TAPE_NULL => cursor
            case kind == JSON_STREAM_TAPE_BOOL => requireRange(cursor, 1); cursor + 1
            case kind == JSON_STREAM_TAPE_INT => requireRange(cursor, 8); cursor + 8
            case kind == JSON_STREAM_TAPE_NUMBER || kind == JSON_STREAM_TAPE_STRING => scanString(cursor)
            case kind == JSON_STREAM_TAPE_ARRAY =>
                let count = uint32At(cursor); cursor += 4
                for (_ in 0..Int64(count)) { cursor = scanValue(cursor) }
                cursor
            case kind == JSON_STREAM_TAPE_OBJECT =>
                let count = uint32At(cursor); cursor += 4
                for (_ in 0..Int64(count)) {
                    cursor = scanString(cursor)
                    cursor = scanValue(cursor)
                }
                cursor
            case _ => fail("Unknown JSON tape value kind")
        }
    }

    private func scanValueBounded(start: Int64, depth: Int64, maxDepth: Int64): Int64 {
        var cursor = start
        let kind = byteAt(cursor); cursor++
        match {
            case kind == JSON_STREAM_TAPE_NULL => cursor
            case kind == JSON_STREAM_TAPE_BOOL => requireRange(cursor, 1); cursor + 1
            case kind == JSON_STREAM_TAPE_INT => requireRange(cursor, 8); cursor + 8
            case kind == JSON_STREAM_TAPE_NUMBER || kind == JSON_STREAM_TAPE_STRING => scanString(cursor)
            case kind == JSON_STREAM_TAPE_ARRAY =>
                requireSkippedContainerDepth(depth, maxDepth)
                let count = uint32At(cursor); cursor += 4
                for (_ in 0..Int64(count)) {
                    cursor = scanValueBounded(cursor, depth + 1, maxDepth)
                }
                cursor
            case kind == JSON_STREAM_TAPE_OBJECT =>
                requireSkippedContainerDepth(depth, maxDepth)
                let count = uint32At(cursor); cursor += 4
                for (_ in 0..Int64(count)) {
                    cursor = scanString(cursor)
                    cursor = scanValueBounded(cursor, depth + 1, maxDepth)
                }
                cursor
            case _ => fail("Unknown JSON tape value kind")
        }
    }

    private func requireSkippedContainerDepth(depth: Int64, maxDepth: Int64): Unit {
        if (depth >= maxDepth) {
            throw JsonException("Maximum JSON depth ${config.maxDepth} exceeded", code: "max_depth")
        }
    }

    private func scanString(start: Int64): Int64 {
        let size = Int64(uint32At(start))
        requireRange(start + 4, size)
        start + 4 + size
    }

    private func readStringRaw(): String {
        let size = Int64(readUInt32Raw())
        requireRange(position, size)
        let value = unsafe { String.fromUtf8Unchecked(bytes[position..position + size]) }
        position += size
        value
    }

    private func readByteRaw(): Byte {
        let value = byteAt(position)
        position++
        value
    }

    private func peekByte(): Byte { byteAt(position) }

    private func expectKind(expected: Byte): Unit {
        if (readByteRaw() != expected) { fail("JSON value type mismatch") }
    }

    private func readUInt32Raw(): UInt32 {
        let value = uint32At(position)
        position += 4
        value
    }

    private func readUInt64Raw(): UInt64 {
        requireRange(position, 8)
        var value = 0u64
        for (shift in 0..8) { value |= UInt64(bytes[position + shift]) << (shift * 8) }
        position += 8
        value
    }

    private func uint32At(start: Int64): UInt32 {
        requireRange(start, 4)
        var value = 0u32
        for (shift in 0..4) { value |= UInt32(bytes[start + shift]) << (shift * 8) }
        value
    }

    private func byteAt(index: Int64): Byte {
        requireRange(index, 1)
        bytes[index]
    }

    private func requireRange(start: Int64, size: Int64): Unit {
        if (start < 0 || size < 0 || start > bytes.size - size) {
            fail("Truncated JSON stream tape")
        }
    }

    private func fail(message: String): Nothing {
        throw JsonException(message, code: "parse_error", path: path())
    }

    @OverflowWrapping
    private func bitsToInt64(value: UInt64): Int64 { Int64(value) }
}

private class JsonStreamTapeReplayValue <: GeneratedReplayValueV1 {
    private let tape: Array<Byte>
    private let config: JsonReadOptions
    private var closed: Bool = false

    init(tape: Array<Byte>, config: JsonReadOptions) {
        this.tape = tape
        this.config = config
    }

    public func isClosed(): Bool { closed }
    public func close(): Unit { closed = true }

    public func rootStringField(name: String): Option<String> {
        requireOpen()
        let reader = BackendTapeReaderV1(tape, config: config)
        var result = None<String>
        reader.startObject()
        while (reader.hasObjectField()) {
            let current = reader.readName()
            if (current == name) { result = Some(reader.readString()) }
            else { reader.skipValue() }
        }
        reader.endObject(); reader.expectEnd()
        result
    }

    public func openObjectReaderExcluding(name: String): JsonReader {
        requireOpen()
        let reader = BackendTapeReaderV1(tape, config: config)
        let writer = BackendTapeWriterV1()
        reader.startObject(); writer.startObject()
        while (reader.hasObjectField()) {
            let current = reader.readName()
            if (current == name) {
                reader.skipValue()
            } else {
                writer.writeName(current)
                reader.copyNextValueTo(writer)
            }
        }
        reader.endObject(); reader.expectEnd(); writer.endObject()
        BackendTapeReaderV1(writer.finishTape(), config: config)
    }

    public func materialize(): JsonNode {
        requireOpen()
        let reader = BackendTapeReaderV1(tape, config: config)
        let value = reader.readNode()
        reader.expectEnd()
        value
    }

    private func requireOpen(): Unit {
        if (closed) { throw IllegalStateException("JSON replay value is closed") }
    }
}
