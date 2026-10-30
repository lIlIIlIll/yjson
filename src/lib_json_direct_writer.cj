package yjson

import std.collection.*
import std.io.*

const JSON_DIRECT_BYTES_INITIAL_CAPACITY: Int64 = 128
const JSON_DIRECT_PRETTY_STRING_INITIAL_CAPACITY: Int64 = 512
const JSON_STREAM_BUFFER_CAPACITY: Int64 = 4096
const JSON_STREAM_DIRECT_WRITE_THRESHOLD: Int64 = 2048
const JSON_DIRECT_INT64_MAP_ENTRY_RESERVE_HINT: Int64 = 8
const JSON_DIRECT_INT64_MAP_RESERVE_LIMIT: Int64 = 4096

private class JsonDirectSemanticPathContext {
    let pathDepth: Int64
    let entryPathPushed: Bool
    var pendingObjectPathPushed: Bool = false
    var nextArrayIndex: Int64 = 0

    init(pathDepth: Int64, entryPathPushed: Bool) {
        this.pathDepth = pathDepth
        this.entryPathPushed = entryPathPushed
    }
}

private func directStringWriterInitialCapacity(config: JsonWriteOptions): Int64 {
    if (config.newline == "\n" && config.indent == "    " && config.useSpaceAfterSeparators && !config.htmlSafe) {
        return JSON_DIRECT_PRETTY_STRING_INITIAL_CAPACITY
    }
    JSON_DIRECT_BYTES_INITIAL_CAPACITY
}

private func shouldEscapeJsonAscii(byte: Int64, htmlSafe: Bool): Bool {
    if (byte < 32 || byte == Int64(b'"') || byte == Int64(b'\\')) {
        return true
    }
    htmlSafe && (
        byte == Int64(b'<') ||
        byte == Int64(b'>') ||
        byte == Int64(b'&') ||
        byte == Int64(b'=') ||
        byte == Int64(b'\''))
}

private func jsonHexNibbleByte(value: Int64): Byte {
    if (value < 10) {
        return UInt8(48 + value)
    }
    UInt8(87 + value)
}

func jsonRawInt64Size(value: Int64): Int64 {
    if (value < 0) {
        if (value == -0x8000_0000_0000_0000) {
            return 20
        }
        return 1 + jsonRawUInt64Size(UInt64(-value))
    }
    jsonRawUInt64Size(UInt64(value))
}

func jsonRawUInt64Size(value: UInt64): Int64 {
    if (value < 10u64) {
        return 1
    }
    if (value < 100u64) {
        return 2
    }
    if (value < 1000u64) {
        return 3
    }
    if (value < 10000u64) {
        return 4
    }
    if (value < 100000u64) {
        return 5
    }
    var current = value
    var size: Int64 = 0
    while (current != 0u64) {
        current /= 10u64
        size++
    }
    size
}

func jsonRawCompactStringEscapeIndex(value: String): Int64 {
    unsafe {
        let bytes = value.rawData()
        var index: Int64 = 0
        while (index < bytes.size && bytes[index] >= 32u8 &&
            bytes[index] != b'"' && bytes[index] != b'\\') {
            index++
        }
        if (index < bytes.size) { return index }
    }
    -1
}

func jsonRawInt64MapReserveHint(prefixSize: Int64, entryCount: Int64): Int64 {
    let entryHint = JSON_DIRECT_INT64_MAP_ENTRY_RESERVE_HINT
    if (prefixSize >= JSON_DIRECT_INT64_MAP_RESERVE_LIMIT - 2) {
        return JSON_DIRECT_INT64_MAP_RESERVE_LIMIT
    }
    let remaining = JSON_DIRECT_INT64_MAP_RESERVE_LIMIT - prefixSize - 2
    if (entryCount > remaining / entryHint) {
        return JSON_DIRECT_INT64_MAP_RESERVE_LIMIT
    }
    prefixSize + 2 + entryCount * entryHint
}

abstract class JsonDirectWriterTarget {
    public func bytesWritten(): Int64

    protected func writeText(value: String): Unit

    protected func writeTextRange(value: String, start: Int64, end: Int64): Unit

    protected func writeByte(value: Byte): Unit

    protected func writeBytes(value: Array<Byte>): Unit

    protected func writeBytesRange(value: Array<Byte>, start: Int64, end: Int64): Unit

    protected func reserveCapacity(additional: Int64): Unit

    protected func tryWriteNativeInt64Array(values: ArrayList<Int64>): Bool

    protected func writeStringLiteralNoEscape(value: String): Unit

    protected func writeStringLiteralNoEscapeName(value: String): Unit

    protected func writeEscapedStringLiteralFromFirstEscape(value: String, firstEscape: Int64, htmlSafe: Bool): Unit

    protected func writeTextStringLiteralNoEscape(prefix: String, value: String): Unit

    protected func writeTextStringArrayListNoEscape(prefix: String, values: ArrayList<String>, totalStringSize: Int64): Unit

    protected func writeCompactInt64Map(prefix: String, values: HashMap<String, Int64>): Unit

    protected func writeCompactInt64Array(values: Array<Int64>): Unit

    protected func writeCompactFloat64Array(values: Array<Float64>): Unit

    protected func writeNewlineAndIndent(newline: String, indent: String, depth: Int64): Unit

    protected func writeObjectEntryNameInt64NoEscape(first: Bool, name: String, value: Int64): Bool

    protected func writeBoolText(value: Bool): Unit

    protected func writeInt64Text(value: Int64): Unit

    protected func writeUInt64Text(value: UInt64): Unit

    protected func writeFloat64Text(value: Float64): Unit

    protected func finish(): Unit

}

/**
 * 为生成代码的字符串和字节写出路径保存 UTF-8 输出缓冲。
 *
 * 只维护已写字节，不检查 JSON 容器、语义路径、最大深度或输出预算。NoEscape 成员依赖调用方的免转义判断，Fast 成员还依赖预先保留的容量。JsonDirectWriter.generatedBufferV1 将此目标提供给生成 codec。原始字节调用方负责保证 UTF-8 有效性。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class DirectBufferWriterTarget <: JsonDirectWriterTarget {
    private var buffer: Array<Byte>
    private var used: Int64 = 0

    /**
     * 创建供生成代码写出 UTF-8 内容的内存缓冲目标。
     *
     * 只分配初始缓冲区，不写入 JSON 内容。实际写入路径要求初始容量为正数。容量 0 用于流写出器的占位目标。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param capacity 初始缓冲区字节容量，默认 128。实际写入时使用正数。
     */
    public init(capacity!: Int64 = JSON_DIRECT_BYTES_INITIAL_CAPACITY) {
        buffer = Array<Byte>(capacity, repeat: 0)
    }
    /**
     * 清除已写长度并复用已经分配的缓冲区。
     *
     * 保留缓冲容量。后续写入从缓冲区开头重新开始。
     *
     * @group 30-first-party-internal 第一方内部接口
     */
    public func reset(): Unit {
        used = 0
    }

    /**
     * 将字符串的 UTF-8 字节原样追加到缓冲区。
     *
     * 不添加双引号或转义，也不解析 JSON。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 要原样写入的文本。
     */
    public func writeText(value: String): Unit {
        writeTextRange(value, 0, value.size)
    }

    /**
     * 将字符串指定字节区间原样追加到缓冲区。
     *
     * 使用 UTF-8 字节偏移，不按字符索引。end 不大于 start 时不写入内容。其余调用必须提供有效区间，并保证最终文本的 UTF-8 有效性。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 包含待写片段的字符串。
     * @param start 片段首字节的偏移，包含该位置。
     * @param end 片段结束偏移，不包含该位置。
     */
    public func writeTextRange(value: String, start: Int64, end: Int64): Unit {
        let size = end - start
        if (size <= 0) {
            return
        }
        ensureCapacity(used + size)
        unsafe {
            value.rawData().copyTo(buffer, start, used, size)
        }
        used += size
    }

    /**
     * 追加一个未经 JSON 或 UTF-8 校验的原始字节。
     *
     * 供生成代码写出语法字节或已校验内容。调用方保证最终内容的结构和 UTF-8 有效性。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 要原样追加的字节。
     */
    public func writeByte(value: Byte): Unit {
        ensureCapacity(used + 1)
        writeRawByteNoEnsure(value)
    }

    /**
     * 追加未经解析的原始字节数组。
     *
     * 不转义，也不校验 JSON 结构或 UTF-8。空数组不产生输出。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 要原样追加的字节。
     */
    public func writeBytes(value: Array<Byte>): Unit {
        if (value.isEmpty()) { return }
        ensureCapacity(used + value.size)
        value.copyTo(buffer, 0, used, value.size)
        used += value.size
    }

    /**
     * 追加原始字节数组的半开区间。
     *
     * 使用字节偏移。end 不大于 start 时不写入内容。其余调用必须提供有效的数组区间。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 包含待写片段的字节数组。
     * @param start 片段首字节的偏移，包含该位置。
     * @param end 片段结束偏移，不包含该位置。
     */
    public func writeBytesRange(value: Array<Byte>, start: Int64, end: Int64): Unit {
        let size = end - start
        if (size <= 0) { return }
        ensureCapacity(used + size)
        value.copyTo(buffer, start, used, size)
        used += size
    }

    /**
     * 为后续追加的内容预留缓冲容量。
     *
     * additional 为正数时，保证当前已写内容之后至少还能容纳相应字节数。非正数不触发操作，已写长度不变。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param additional 需要在当前已写内容之后额外容纳的字节数。
     */
    public func reserveCapacity(additional: Int64): Unit {
        if (additional > 0) {
            ensureCapacity(used + additional)
        }
    }

    /**
     * 尝试使用已安装的 Native 实现写出紧凑 Int64 列表。
     *
     * 元素数量未达到内部阈值、未启用 Native 实现或本次 Native 缓冲容量不足时返回 false。返回 false 时不增加已写长度，调用方可改用通用写出路径。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param values 按列表顺序写出的 Int64 元素。
     * @return 完整数组已经写入时为 true。未采用该路径时为 false。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func tryWriteNativeInt64Array(values: ArrayList<Int64>): Bool {
        if (values.size < YJSON_NATIVE_MIN_WRITER_INT64_COUNT) { return false }
        let required = values.size * 21 + 1
        ensureCapacity(used + required)
        if (let Some(written) <- jsonNativeFormatInt64ArrayInto(values, buffer, used)) {
            used += written
            return true
        }
        false
    }

    /**
     * 原样加引号写入不需要转义的字符串。
     *
     * 不扫描或转义字符串内容，调用方保证其中没有需要 JSON 转义的字符。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 不需要 JSON 转义的字符串内容。
     */
    public func writeStringLiteralNoEscape(value: String): Unit {
        ensureCapacity(used + value.size + 2)
        buffer[used] = b'"'
        used++
        unsafe {
            value.rawData().copyTo(buffer, 0, used, value.size)
        }
        used += value.size
        buffer[used] = b'"'
        used++
    }

    /**
     * 原样加引号写入免转义字符串字段名并追加冒号。
     *
     * 供生成代码写出已经验证的字段名。不扫描或转义内容，也不自动写出逗号。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 不需要 JSON 转义的字段名。
     */
    public func writeStringLiteralNoEscapeName(value: String): Unit {
        ensureCapacity(used + value.size + 3)
        buffer[used] = b'"'
        used++
        unsafe {
            value.rawData().copyTo(buffer, 0, used, value.size)
        }
        used += value.size
        buffer[used] = b'"'
        used++
        buffer[used] = b':'
        used++
    }

    /**
     * 原样加引号写入免转义 UTF-8 字节字段名并追加冒号。
     *
     * 供生成代码写出已经验证的字段名。不扫描或转义内容，也不自动写出逗号。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 有效 UTF-8 且不需要 JSON 转义的字段名字节。
     */
    public func writeStringLiteralNoEscapeName(value: Array<Byte>): Unit {
        ensureCapacity(used + value.size + 3)
        buffer[used] = b'"'
        used++
        value.copyTo(buffer, 0, used, value.size)
        used += value.size
        buffer[used] = b'"'
        used++
        buffer[used] = b':'
        used++
    }

    /**
     * 从已知首个转义位置开始写出完整 JSON 字符串字面量。
     *
     * 包含两端双引号，并转义控制字符、双引号和反斜线。调用方保证 firstEscape 之前的字节不需要按所选规则转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 要加引号并转义的字符串。
     * @param firstEscape 首个需要转义的 UTF-8 字节偏移，必须位于字符串有效范围内。
     * @param htmlSafe 是否同时转义小于号、大于号、与号、等号和单引号。
     */
    public func writeEscapedStringLiteralFromFirstEscape(value: String, firstEscape: Int64, htmlSafe: Bool): Unit {
        ensureCapacity(used + value.size + 8)
        writeRawByteNoEnsure(b'"')
        var segmentStart: Int64 = 0
        if (!htmlSafe) {
            for (index in firstEscape..value.size) {
                let byte = Int64(value[index])
                if (byte > 127 || !(byte < 32 || byte == Int64(b'"') || byte == Int64(b'\\'))) {
                    continue
                }
                ensureCapacity(used + (index - segmentStart) + 6 + (value.size - index) + 1)
                copyTextRangeNoEnsure(value, segmentStart, index)
                writeAsciiEscapeNoEnsure(byte)
                segmentStart = index + 1
            }
            ensureCapacity(used + (value.size - segmentStart) + 1)
            copyTextRangeNoEnsure(value, segmentStart, value.size)
            writeRawByteNoEnsure(b'"')
            return
        }
        for (index in firstEscape..value.size) {
            let byte = Int64(value[index])
            if (byte > 127 || !shouldEscapeJsonAscii(byte, htmlSafe)) {
                continue
            }
            ensureCapacity(used + (index - segmentStart) + 6 + (value.size - index) + 1)
            copyTextRangeNoEnsure(value, segmentStart, index)
            writeAsciiEscapeNoEnsure(byte)
            segmentStart = index + 1
        }
        ensureCapacity(used + (value.size - segmentStart) + 1)
        copyTextRangeNoEnsure(value, segmentStart, value.size)
        writeRawByteNoEnsure(b'"')
    }

    /**
     * 追加原始前缀和无需转义的字符串字面量。
     *
     * 前缀原样写入，value 两端添加双引号，内容不扫描或转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param prefix 字面量之前原样追加的文本。
     * @param value 不需要 JSON 转义的字符串内容。
     */
    public func writeTextStringLiteralNoEscape(prefix: String, value: String): Unit {
        ensureCapacity(used + prefix.size + value.size + 2)
        copyTextNoEnsure(prefix)
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsure(value)
        writeRawByteNoEnsure(b'"')
    }

    /**
     * 追加原始前缀和无需转义的字符串列表。
     *
     * 前缀原样写入，列表写成紧凑 JSON 数组。调用方预先确认所有元素无需 JSON 转义，并提供准确的字符串总字节数以预留容量。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param prefix 数组之前原样追加的文本。
     * @param values 按列表顺序输出、均无需 JSON 转义的字符串。
     * @param totalStringSize 所有字符串的 UTF-8 字节数之和，必须足以覆盖实际内容。
     */
    public func writeTextStringArrayListNoEscape(prefix: String, values: ArrayList<String>, totalStringSize: Int64): Unit {
        ensureCapacity(used + prefix.size + totalStringSize + values.size * 3 + 2)
        copyTextNoEnsure(prefix)
        writeRawByteNoEnsure(b'[')
        if (values.size != 0) {
            writeRawByteNoEnsure(b'"')
            copyTextNoEnsure(values[0])
            writeRawByteNoEnsure(b'"')
            for (index in 1..values.size) {
                writeRawByteNoEnsure(b',')
                writeRawByteNoEnsure(b'"')
                copyTextNoEnsure(values[index])
                writeRawByteNoEnsure(b'"')
            }
        }
        writeRawByteNoEnsure(b']')
    }

    /**
     * 追加原始前缀和字符串键 Int64 值的紧凑 JSON 对象。
     *
     * 前缀原样写入。对象按 HashMap 的迭代顺序输出，对键执行标准 JSON 转义，不额外转义 HTML 敏感字符。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param prefix 对象之前原样追加的文本，调用方保证它适合当前位置。
     * @param values 要写出的键值映射。
     */
    public func writeCompactInt64Map(prefix: String, values: HashMap<String, Int64>): Unit {
        reserveCapacity(jsonRawInt64MapReserveHint(prefix.size, values.size))
        ensureCapacity(used + prefix.size + 1)
        copyTextNoEnsure(prefix)
        writeRawByteNoEnsure(b'{')
        var first = true
        for ((key, item) in values) {
            let firstEscape = jsonRawCompactStringEscapeIndex(key)
            if (firstEscape < 0) {
                ensureCapacity(used + key.size + 24)
                if (!first) {
                    writeRawByteNoEnsure(b',')
                }
                writeRawByteNoEnsure(b'"')
                copyTextNoEnsure(key)
                writeRawByteNoEnsure(b'"')
                writeRawByteNoEnsure(b':')
                writeInt64NoEnsure(item)
            } else {
                if (!first) {
                    writeByte(b',')
                }
                writeEscapedStringLiteralFromFirstEscape(key, firstEscape, false)
                ensureCapacity(used + 21)
                writeRawByteNoEnsure(b':')
                writeInt64NoEnsure(item)
            }
            first = false
        }
        writeByte(b'}')
    }

    /**
     * 将 Int64 数组追加为紧凑 JSON 数组。
     *
     * 按数组顺序输出，优先尝试 Native 数组格式化，未采用时使用通用十进制写出路径。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param values 要按顺序写出的 Int64 数组。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeCompactInt64Array(values: Array<Int64>): Unit {
        ensureCapacity(used + values.size * 4 + 2)
        if (let Some(written) <- jsonNativeFormatInt64ArrayInto(values, buffer, used)) {
            used += written
            return
        }
        ensureCapacity(used + values.size * 21 + 1)
        writeRawByteNoEnsure(b'[')
        if (!values.isEmpty()) {
            writeInt64NoEnsure(values[0])
            for (index in 1..values.size) {
                writeRawByteNoEnsure(b',')
                writeInt64NoEnsure(values[index])
            }
        }
        writeRawByteNoEnsure(b']')
    }

    /**
     * 将 Float64 数组追加为紧凑 JSON 数组。
     *
     * 按数组顺序输出，优先尝试 Native 数组格式化，未采用时使用各元素的浮点文本。此缓冲级入口不检查有限性，调用方须预先排除 NaN 和无穷大。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param values 已经由调用方检查为有限值的 Float64 数组。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeCompactFloat64Array(values: Array<Float64>): Unit {
        reserveCapacity(values.size * 20 + 2)
        if (let Some(written) <- jsonNativeFormatFloat64ArrayInto(values, buffer, used)) {
            used += written
            return
        }
        reserveCapacity(values.size * 42 + 2)
        writeRawByteNoEnsure(b'[')
        if (!values.isEmpty()) {
            var text = values[0].toString()
            ensureCapacity(used + text.size)
            copyTextNoEnsure(text)
            for (index in 1..values.size) {
                writeRawByteNoEnsure(b',')
                text = values[index].toString()
                ensureCapacity(used + text.size)
                copyTextNoEnsure(text)
            }
        }
        writeRawByteNoEnsure(b']')
    }

    /**
     * 追加换行文本和指定层数的缩进。
     *
     * newline 原样写入一次，然后将 indent 原样重复 depth 次。调用方提供非负深度。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param newline 本次先写入的换行文本，可为空。
     * @param indent 每一层使用的缩进文本。
     * @param depth 缩进重复次数，必须非负。
     */
    public func writeNewlineAndIndent(newline: String, indent: String, depth: Int64): Unit {
        ensureCapacity(used + newline.size + indent.size * depth)
        copyTextNoEnsure(newline)
        for (_ in 0..depth) {
            copyTextNoEnsure(indent)
        }
    }

    /**
     * 向缓冲区写入免转义字符串字段名和 Int64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 要写出的有符号整数。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameInt64NoEscape(first: Bool, name: String, value: Int64): Bool {
        ensureCapacity(used + name.size + 24)
        if (!first) {
            writeRawByteNoEnsure(b',')
        }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsure(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeInt64NoEnsure(value)
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和 Int64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的有效 UTF-8 字段名字节。
     * @param value 要写出的有符号整数。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameInt64NoEscape(first: Bool, name: Array<Byte>, value: Int64): Bool {
        ensureCapacity(used + name.size + 24)
        if (!first) {
            writeRawByteNoEnsure(b',')
        }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeInt64NoEnsure(value)
        false
    }

    // Generated compact objects reserve their scalar field budget once before
    // entering the field loop.  These variants deliberately omit the
    // repeated capacity branch on that proven buffer path.
    /**
     * 在已预留容量的缓冲区中写入免转义字符串字段名和 Int64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。调用方必须预先为完整字段及可能的逗号预留足够容量，本入口省略相应容量检查。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 要写出的有符号整数。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameInt64NoEscapeFast(first: Bool, name: String, value: Int64): Bool {
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsureFast(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeInt64NoEnsure(value)
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和字符串字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。字符串值也原样加引号，调用方保证字段名和值都不需要 JSON 转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 不需要 JSON 转义的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameStringNoEscape(
        first: Bool, name: String, value: String
    ): Bool {
        ensureCapacity(used + name.size + value.size + 6)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsure(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsure(value)
        writeRawByteNoEnsure(b'"')
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和字符串字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。字符串值也原样加引号，调用方保证字段名和值都不需要 JSON 转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的有效 UTF-8 字段名字节。
     * @param value 不需要 JSON 转义的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameStringNoEscape(
        first: Bool, name: Array<Byte>, value: String
    ): Bool {
        ensureCapacity(used + name.size + value.size + 6)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsure(value)
        writeRawByteNoEnsure(b'"')
        false
    }

    // Generated compact records reserve the complete string bound before
    // entering the field loop. Keep the common unescaped case free of a
    // repeated capacity check; callers must use writeObjectEntryNameStringFast
    // so values containing JSON escapes take the checked path.
    /**
     * 在已预留容量的缓冲区中写入免转义字符串字段名和字符串字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。字符串值也原样加引号，调用方保证字段名和值都不需要 JSON 转义。调用方必须预先为完整字段及可能的逗号预留足够容量，本入口省略相应容量检查。需要检查值中转义字符的生成调用应使用 JsonDirectWriter.writeRawObjectEntryKnownNameStringFast。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 不需要 JSON 转义的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameStringNoEscapeFast(
        first: Bool, name: String, value: String
    ): Bool {
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsureFast(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'"')
        if (!value.isEmpty()) {
            unsafe { value.rawData().copyTo(buffer, 0, used, value.size) }
            used += value.size
        }
        writeRawByteNoEnsure(b'"')
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和需要转义的字符串值。
     *
     * 字段名原样复制，值从 firstEscape 开始扫描并转义。调用方保证此前字节不需转义。非首项调用还须保证缓冲区至少留有一个字节用于先写入逗号。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的字段名。
     * @param value 要加引号并转义的字符串值。
     * @param firstEscape 值中首个需要转义的 UTF-8 字节偏移，必须位于值的有效范围内。
     * @param htmlSafe 是否同时转义 HTML 敏感 ASCII 字符。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameStringEscaped(
        first: Bool, name: String, value: String, firstEscape: Int64, htmlSafe: Bool
    ): Bool {
        // Keep the object-name prefix and escaped value in one buffer hot
        // path.  The previous implementation made two helper calls, each
        // repeating the capacity check and string-literal bookkeeping.  T9's
        // escape workload has eight such fields, so the fused form removes a
        // measurable amount of per-field dispatch without changing escaping.
        if (!first) { writeRawByteNoEnsure(b',') }
        ensureCapacity(used + name.size + value.size * 6 + 8)
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'"')
        var segmentStart: Int64 = 0
        if (!htmlSafe) {
            for (index in firstEscape..value.size) {
                let byte = Int64(value[index])
                if (byte > 127 || !(byte < 32 || byte == Int64(b'"') || byte == Int64(b'\\'))) {
                    continue
                }
                copyTextRangeNoEnsure(value, segmentStart, index)
                writeAsciiEscapeNoEnsure(byte)
                segmentStart = index + 1
            }
        } else {
            for (index in firstEscape..value.size) {
                let byte = Int64(value[index])
                if (byte > 127 || !shouldEscapeJsonAscii(byte, htmlSafe)) {
                    continue
                }
                copyTextRangeNoEnsure(value, segmentStart, index)
                writeAsciiEscapeNoEnsure(byte)
                segmentStart = index + 1
            }
        }
        copyTextRangeNoEnsure(value, segmentStart, value.size)
        writeRawByteNoEnsure(b'"')
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和需要转义的字符串值。
     *
     * 字段名原样复制，值从 firstEscape 开始扫描并转义。调用方保证此前字节不需转义。非首项调用还须保证缓冲区至少留有一个字节用于先写入逗号。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的有效 UTF-8 字段名字节。
     * @param value 要加引号并转义的字符串值。
     * @param firstEscape 值中首个需要转义的 UTF-8 字节偏移，必须位于值的有效范围内。
     * @param htmlSafe 是否同时转义 HTML 敏感 ASCII 字符。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameStringEscaped(
        first: Bool, name: Array<Byte>, value: String, firstEscape: Int64, htmlSafe: Bool
    ): Bool {
        if (!first) { writeRawByteNoEnsure(b',') }
        ensureCapacity(used + name.size + value.size * 6 + 8)
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'"')
        var segmentStart: Int64 = 0
        if (!htmlSafe) {
            for (index in firstEscape..value.size) {
                let byte = Int64(value[index])
                if (byte > 127 || !(byte < 32 || byte == Int64(b'"') || byte == Int64(b'\\'))) {
                    continue
                }
                copyTextRangeNoEnsure(value, segmentStart, index)
                writeAsciiEscapeNoEnsure(byte)
                segmentStart = index + 1
            }
        } else {
            for (index in firstEscape..value.size) {
                let byte = Int64(value[index])
                if (byte > 127 || !shouldEscapeJsonAscii(byte, htmlSafe)) {
                    continue
                }
                copyTextRangeNoEnsure(value, segmentStart, index)
                writeAsciiEscapeNoEnsure(byte)
                segmentStart = index + 1
            }
        }
        copyTextRangeNoEnsure(value, segmentStart, value.size)
        writeRawByteNoEnsure(b'"')
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和布尔字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 写为 true 或 false 的字段值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameBoolNoEscape(
        first: Bool, name: String, value: Bool
    ): Bool {
        ensureCapacity(used + name.size + 8)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        if (value) {
            writeRawByteNoEnsure(b't')
            writeRawByteNoEnsure(b'r')
            writeRawByteNoEnsure(b'u')
            writeRawByteNoEnsure(b'e')
        } else {
            writeRawByteNoEnsure(b'f')
            writeRawByteNoEnsure(b'a')
            writeRawByteNoEnsure(b'l')
            writeRawByteNoEnsure(b's')
            writeRawByteNoEnsure(b'e')
        }
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和布尔字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的有效 UTF-8 字段名字节。
     * @param value 写为 true 或 false 的字段值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameBoolNoEscape(
        first: Bool, name: Array<Byte>, value: Bool
    ): Bool {
        ensureCapacity(used + name.size + 8)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        if (value) {
            writeRawByteNoEnsure(b't')
            writeRawByteNoEnsure(b'r')
            writeRawByteNoEnsure(b'u')
            writeRawByteNoEnsure(b'e')
        } else {
            writeRawByteNoEnsure(b'f')
            writeRawByteNoEnsure(b'a')
            writeRawByteNoEnsure(b'l')
            writeRawByteNoEnsure(b's')
            writeRawByteNoEnsure(b'e')
        }
        false
    }

    /**
     * 在已预留容量的缓冲区中写入免转义字符串字段名和布尔字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。调用方必须预先为完整字段及可能的逗号预留足够容量，本入口省略相应容量检查。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 写为 true 或 false 的字段值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameBoolNoEscapeFast(
        first: Bool, name: String, value: Bool
    ): Bool {
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsureFast(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        if (value) {
            writeRawByteNoEnsure(b't')
            writeRawByteNoEnsure(b'r')
            writeRawByteNoEnsure(b'u')
            writeRawByteNoEnsure(b'e')
        } else {
            writeRawByteNoEnsure(b'f')
            writeRawByteNoEnsure(b'a')
            writeRawByteNoEnsure(b'l')
            writeRawByteNoEnsure(b's')
            writeRawByteNoEnsure(b'e')
        }
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和 UInt64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 要写出的无符号整数。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameUInt64NoEscape(
        first: Bool, name: String, value: UInt64
    ): Bool {
        ensureCapacity(used + name.size + 24)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeUInt64Digits(value)
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和 UInt64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的有效 UTF-8 字段名字节。
     * @param value 要写出的无符号整数。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameUInt64NoEscape(
        first: Bool, name: Array<Byte>, value: UInt64
    ): Bool {
        ensureCapacity(used + name.size + 24)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeUInt64Digits(value)
        false
    }

    /**
     * 在已预留容量的缓冲区中写入免转义字符串字段名和 UInt64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。调用方必须预先为完整字段及可能的逗号预留足够容量，本入口省略相应容量检查。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 要写出的无符号整数。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameUInt64NoEscapeFast(
        first: Bool, name: String, value: UInt64
    ): Bool {
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsureFast(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeUInt64DigitsNoEnsure(value)
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和 Float64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。先拒绝非有限值，再尝试 Native 浮点格式化。未采用时写入浮点文本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 要写出的有限浮点值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameFloat64NoEscape(
        first: Bool, name: String, value: Float64
    ): Bool {
        ensureFiniteJsonFloat(value)
        ensureCapacity(used + name.size + 44)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        if (let Some(written) <- jsonNativeFormatFloat64Into(value, buffer, used)) {
            used += written
        } else {
            writeText(value.toString())
        }
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和 Float64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。先拒绝非有限值，再尝试 Native 浮点格式化。未采用时写入浮点文本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的有效 UTF-8 字段名字节。
     * @param value 要写出的有限浮点值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameFloat64NoEscape(
        first: Bool, name: Array<Byte>, value: Float64
    ): Bool {
        ensureFiniteJsonFloat(value)
        ensureCapacity(used + name.size + 44)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        if (let Some(written) <- jsonNativeFormatFloat64Into(value, buffer, used)) {
            used += written
        } else {
            writeText(value.toString())
        }
        false
    }

    /**
     * 在已预留容量的缓冲区中写入免转义字符串字段名和 Float64 字段值。
     *
     * 供已建立 raw 对象上下文的生成代码调用。字段名原样复制，不执行转义。调用方必须预先为完整字段及可能的逗号预留足够容量，本入口省略相应容量检查。先拒绝非有限值，再尝试 Native 浮点格式化。未采用时写入浮点文本。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要 JSON 转义的字段名。
     * @param value 要写出的有限浮点值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameFloat64NoEscapeFast(
        first: Bool, name: String, value: Float64
    ): Bool {
        ensureFiniteJsonFloat(value)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        copyTextNoEnsureFast(name)
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        if (let Some(written) <- jsonNativeFormatFloat64Into(value, buffer, used)) {
            used += written
        } else {
            // The generated reserve bound covers the normal native format;
            // retain the existing checked fallback for unusual float text.
            writeText(value.toString())
        }
        false
    }

    // Fused compact container entries used by generated object codecs.  The
    // caller has already established raw-container depth; keeping the field
    // name and value in this concrete target avoids three wrapper calls for
    // every small Array<Int64> field.
    /**
     * 向缓冲区写入免转义字符串字段名和紧凑 Int64 数组字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。数组按元素顺序输出，符合条件时尝试 Native 格式化。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的字段名。
     * @param values 要写出的 Int64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameInt64ArrayNoEscape(
        first: Bool, name: String, values: Array<Int64>
    ): Bool {
        if (values.size >= YJSON_NATIVE_MIN_WRITER_INT64_COUNT) {
            ensureCapacity(used + name.size + 4)
            if (!first) { writeRawByteNoEnsure(b',') }
            writeRawByteNoEnsure(b'"')
            unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
            used += name.size
            writeRawByteNoEnsure(b'"')
            writeRawByteNoEnsure(b':')
            writeCompactInt64Array(values)
            return false
        }
        ensureCapacity(used + name.size + values.size * 21 + 6)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'[')
        if (!values.isEmpty()) {
            writeInt64NoEnsure(values[0])
            for (index in 1..values.size) {
                writeRawByteNoEnsure(b',')
                writeInt64NoEnsure(values[index])
            }
        }
        writeRawByteNoEnsure(b']')
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和紧凑 Int64 数组字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。数组按元素顺序输出，符合条件时尝试 Native 格式化。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的有效 UTF-8 字段名字节。
     * @param values 要写出的 Int64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameInt64ArrayNoEscape(
        first: Bool, name: Array<Byte>, values: Array<Int64>
    ): Bool {
        if (values.size >= YJSON_NATIVE_MIN_WRITER_INT64_COUNT) {
            ensureCapacity(used + name.size + 4)
            if (!first) { writeRawByteNoEnsure(b',') }
            writeRawByteNoEnsure(b'"')
            name.copyTo(buffer, 0, used, name.size)
            used += name.size
            writeRawByteNoEnsure(b'"')
            writeRawByteNoEnsure(b':')
            writeCompactInt64Array(values)
            return false
        }
        ensureCapacity(used + name.size + values.size * 21 + 6)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeRawByteNoEnsure(b'[')
        if (!values.isEmpty()) {
            writeInt64NoEnsure(values[0])
            for (index in 1..values.size) {
                writeRawByteNoEnsure(b',')
                writeInt64NoEnsure(values[index])
            }
        }
        writeRawByteNoEnsure(b']')
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和紧凑 Int64 映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。映射按自身迭代顺序输出。映射键执行标准 JSON 转义，不额外转义 HTML 敏感字符。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的字段名。
     * @param values 字符串键与 Int64 值的映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameInt64MapNoEscape(
        first: Bool, name: String, values: HashMap<String, Int64>
    ): Bool {
        ensureCapacity(used + name.size + 4)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        writeCompactInt64Map("", values)
        false
    }

    // Generated T9-style maps use deterministic ASCII keys (for example
    // `key0`/`k0`).  Keep a dedicated hot path for that generated shape: the
    // generic map writer must scan every key for JSON escapes, while this
    // path can copy the key bytes directly and avoid one full pass per key.
    // Callers are responsible for restricting this method to known-safe keys.
    /**
     * 向缓冲区写入免转义字符串字段名和紧凑 Int64 映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。映射按自身迭代顺序输出。映射键直接复制，不扫描转义字符。调用方须保证键是可直接放入 JSON 字符串的 ASCII 文本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的字段名。
     * @param values 键为无需转义 ASCII 文本、值为 Int64 的映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameInt64MapKnownAsciiKeys(
        first: Bool, name: String, values: HashMap<String, Int64>
    ): Bool {
        ensureCapacity(used + name.size + 4)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        // The compact generated map keys are short ASCII names.  Reserve a
        // bounded per-entry budget up front so medium maps do not grow while
        // copying each key/value pair; individual checks below still protect
        // arbitrary key/value sizes.
        reserveCapacity(values.size * 32 + 2)
        reserveCapacity(jsonRawInt64MapReserveHint(0, values.size))
        writeRawByteNoEnsure(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            ensureCapacity(used + mapName.size + 24)
            if (!mapFirst) { writeRawByteNoEnsure(b',') }
            writeRawByteNoEnsure(b'"')
            unsafe { mapName.rawData().copyTo(buffer, 0, used, mapName.size) }
            used += mapName.size
            writeRawByteNoEnsure(b'"')
            writeRawByteNoEnsure(b':')
            writeInt64NoEnsure(value)
            mapFirst = false
        }
        writeRawByteNoEnsure(b'}')
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和紧凑 Int64 映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。映射按自身迭代顺序输出。映射键直接复制，不扫描转义字符。调用方须保证键是可直接放入 JSON 字符串的 ASCII 文本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的有效 UTF-8 字段名字节。
     * @param values 键为无需转义 ASCII 文本、值为 Int64 的映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeObjectEntryNameInt64MapKnownAsciiKeys(
        first: Bool, name: Array<Byte>, values: HashMap<String, Int64>
    ): Bool {
        ensureCapacity(used + name.size + 4)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        reserveCapacity(values.size * 32 + 2)
        reserveCapacity(jsonRawInt64MapReserveHint(0, values.size))
        writeRawByteNoEnsure(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            ensureCapacity(used + mapName.size + 24)
            if (!mapFirst) { writeRawByteNoEnsure(b',') }
            writeRawByteNoEnsure(b'"')
            unsafe { mapName.rawData().copyTo(buffer, 0, used, mapName.size) }
            used += mapName.size
            writeRawByteNoEnsure(b'"')
            writeRawByteNoEnsure(b':')
            writeInt64NoEnsure(value)
            mapFirst = false
        }
        writeRawByteNoEnsure(b'}')
        false
    }

    /**
     * 向缓冲区写入免转义字符串字段名和紧凑 Int64 数组映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。映射按自身迭代顺序输出。映射键执行标准 JSON 转义，不额外转义 HTML 敏感字符。数组按元素顺序输出，符合条件时尝试 Native 格式化。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的字段名。
     * @param values 字符串键与 Int64 数组值的映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameInt64ArrayMapNoEscape(
        first: Bool, name: String, values: HashMap<String, Array<Int64>>
    ): Bool {
        ensureCapacity(used + name.size + 4)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        reserveCapacity(values.size * 64 + 2)
        reserveCapacity(jsonRawInt64MapReserveHint(0, values.size))
        writeRawByteNoEnsure(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            let firstEscape = jsonRawCompactStringEscapeIndex(mapName)
            if (!mapFirst) { writeRawByteNoEnsure(b',') }
            if (firstEscape < 0) {
                writeStringLiteralNoEscapeName(mapName)
            } else {
                writeEscapedStringLiteralFromFirstEscape(mapName, firstEscape, false)
                writeRawByteNoEnsure(b':')
            }
            writeCompactInt64Array(value)
            mapFirst = false
        }
        writeRawByteNoEnsure(b'}')
        false
    }

    // ASCII-key counterpart of the nested Int64-array map path.  This is
    // deliberately separate from the general writer because generated code
    // opts into it only for the compact, known-shape benchmark path.
    /**
     * 向缓冲区写入免转义字符串字段名和紧凑 Int64 数组映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。映射按自身迭代顺序输出。映射键直接复制，不扫描转义字符。调用方须保证键是可直接放入 JSON 字符串的 ASCII 文本。数组按元素顺序输出，符合条件时尝试 Native 格式化。调用方还须保证已知键形状及剩余容量足以直接写入各映射键。此路径不为任意键长重新预留容量。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的字段名。
     * @param values 键和值都由调用方限制为已知形状、键无需转义的 Int64 数组映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameInt64ArrayMapKnownAsciiKeys(
        first: Bool, name: String, values: HashMap<String, Array<Int64>>
    ): Bool {
        ensureCapacity(used + name.size + 4)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        unsafe { name.rawData().copyTo(buffer, 0, used, name.size) }
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        reserveCapacity(values.size * 64 + 2)
        reserveCapacity(jsonRawInt64MapReserveHint(0, values.size))
        writeRawByteNoEnsure(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            if (!mapFirst) { writeRawByteNoEnsure(b',') }
            writeRawByteNoEnsure(b'"')
            unsafe { mapName.rawData().copyTo(buffer, 0, used, mapName.size) }
            used += mapName.size
            writeRawByteNoEnsure(b'"')
            writeRawByteNoEnsure(b':')
            if (value.size >= YJSON_NATIVE_MIN_WRITER_INT64_COUNT) {
                writeCompactInt64Array(value)
            } else {
                // The generated nested-collection workload uses small
                // arrays. Inline that case to avoid the generic array
                // reserve/native-probe pair for every map entry.
                ensureCapacity(used + value.size * 21 + 2)
                writeRawByteNoEnsure(b'[')
                if (!value.isEmpty()) {
                    writeInt64NoEnsure(value[0])
                    for (index in 1..value.size) {
                        writeRawByteNoEnsure(b',')
                        writeInt64NoEnsure(value[index])
                    }
                }
                writeRawByteNoEnsure(b']')
            }
            mapFirst = false
        }
        writeRawByteNoEnsure(b'}')
        false
    }

    /**
     * 向缓冲区写入免转义 UTF-8 字节字段名和紧凑 Int64 数组映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用，字段名原样复制。映射按自身迭代顺序输出。映射键直接复制，不扫描转义字符。调用方须保证键是可直接放入 JSON 字符串的 ASCII 文本。数组按元素顺序输出，符合条件时尝试 Native 格式化。调用方还须保证已知键形状及剩余容量足以直接写入各映射键。此路径不为任意键长重新预留容量。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 不需要转义的有效 UTF-8 字段名字节。
     * @param values 键和值都由调用方限制为已知形状、键无需转义的 Int64 数组映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeObjectEntryNameInt64ArrayMapKnownAsciiKeys(
        first: Bool, name: Array<Byte>, values: HashMap<String, Array<Int64>>
    ): Bool {
        ensureCapacity(used + name.size + 4)
        if (!first) { writeRawByteNoEnsure(b',') }
        writeRawByteNoEnsure(b'"')
        name.copyTo(buffer, 0, used, name.size)
        used += name.size
        writeRawByteNoEnsure(b'"')
        writeRawByteNoEnsure(b':')
        reserveCapacity(values.size * 64 + 2)
        reserveCapacity(jsonRawInt64MapReserveHint(0, values.size))
        writeRawByteNoEnsure(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            if (!mapFirst) { writeRawByteNoEnsure(b',') }
            writeRawByteNoEnsure(b'"')
            unsafe { mapName.rawData().copyTo(buffer, 0, used, mapName.size) }
            used += mapName.size
            writeRawByteNoEnsure(b'"')
            writeRawByteNoEnsure(b':')
            if (value.size >= YJSON_NATIVE_MIN_WRITER_INT64_COUNT) {
                writeCompactInt64Array(value)
            } else {
                ensureCapacity(used + value.size * 21 + 2)
                writeRawByteNoEnsure(b'[')
                if (!value.isEmpty()) {
                    writeInt64NoEnsure(value[0])
                    for (index in 1..value.size) {
                        writeRawByteNoEnsure(b',')
                        writeInt64NoEnsure(value[index])
                    }
                }
                writeRawByteNoEnsure(b']')
            }
            mapFirst = false
        }
        writeRawByteNoEnsure(b'}')
        false
    }
    /**
     * 追加布尔值对应的 JSON 文本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 写为 true 或 false 的布尔值。
     */
    public func writeBoolText(value: Bool): Unit {
        if (value) {
            writeText("true")
        } else {
            writeText("false")
        }
    }

    /**
     * 以十进制文本追加一个 Int64 值。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 要写出的有符号整数。
     */
    public func writeInt64Text(value: Int64): Unit {
        ensureCapacity(used + 21)
        writeInt64NoEnsure(value)
    }

    /**
     * 以十进制文本追加一个 UInt64 值。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 要写出的无符号整数。
     */
    public func writeUInt64Text(value: UInt64): Unit {
        writeUInt64Digits(value)
    }

    /**
     * 追加 Float64 的数值文本。
     *
     * 优先尝试 Native 浮点格式化，未采用时使用 toString。此缓冲级入口不检查有限性，调用方须预先排除 NaN 和无穷大。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 已由调用方检查为有限值的浮点数。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeFloat64Text(value: Float64): Unit {
        ensureCapacity(used + 40)
        if (let Some(written) <- jsonNativeFormatFloat64Into(value, buffer, used)) {
            used += written
            return
        }
        writeText(value.toString())
    }

    private func ensureCapacity(required: Int64): Unit {
        if (required <= buffer.size) {
            return
        }
        var newCapacity = buffer.size * 2
        while (newCapacity < required) {
            newCapacity *= 2
        }
        let newBuffer = Array<Byte>(newCapacity, repeat: 0)
        buffer.copyTo(newBuffer, 0, 0, used)
        buffer = newBuffer
    }

    private func writeRawByteNoEnsure(value: Byte): Unit {
        buffer[used] = value
        used++
    }

    private func writeUInt64Digits(value: UInt64): Unit {
        ensureCapacity(used + 20)
        writeUInt64DigitsNoEnsure(value)
    }

    private func writeInt64NoEnsure(value: Int64): Unit {
        if (value < 0) {
            if (value == -0x8000_0000_0000_0000) {
                copyTextNoEnsure("-9223372036854775808")
                return
            }
            writeRawByteNoEnsure(b'-')
            writeUInt64DigitsNoEnsure(UInt64(-value))
            return
        }
        writeUInt64DigitsNoEnsure(UInt64(value))
    }

    private func writeUInt64DigitsNoEnsure(value: UInt64): Unit {
        if (value == 0u64) {
            writeRawByteNoEnsure(b'0')
            return
        }
        if (value < 10u64) {
            writeRawByteNoEnsure(UInt8(48u64 + value))
            return
        }
        if (value < 100u64) {
            writeRawByteNoEnsure(UInt8(48u64 + value / 10u64))
            writeRawByteNoEnsure(UInt8(48u64 + value % 10u64))
            return
        }
        if (value < 1000u64) {
            writeRawByteNoEnsure(UInt8(48u64 + value / 100u64))
            let rest = value % 100u64
            writeRawByteNoEnsure(UInt8(48u64 + rest / 10u64))
            writeRawByteNoEnsure(UInt8(48u64 + rest % 10u64))
            return
        }
        if (value < 10000u64) {
            writeRawByteNoEnsure(UInt8(48u64 + value / 1000u64))
            var rest = value % 1000u64
            writeRawByteNoEnsure(UInt8(48u64 + rest / 100u64))
            rest %= 100u64
            writeRawByteNoEnsure(UInt8(48u64 + rest / 10u64))
            writeRawByteNoEnsure(UInt8(48u64 + rest % 10u64))
            return
        }
        if (value < 100000u64) {
            writeRawByteNoEnsure(UInt8(48u64 + value / 10000u64))
            var rest = value % 10000u64
            writeRawByteNoEnsure(UInt8(48u64 + rest / 1000u64))
            rest %= 1000u64
            writeRawByteNoEnsure(UInt8(48u64 + rest / 100u64))
            rest %= 100u64
            writeRawByteNoEnsure(UInt8(48u64 + rest / 10u64))
            writeRawByteNoEnsure(UInt8(48u64 + rest % 10u64))
            return
        }
        var current = value
        let end = used + 20
        var cursor = end
        while (current != 0u64) {
            let digit = current % 10u64
            cursor--
            buffer[cursor] = UInt8(48u64 + digit)
            current /= 10u64
        }
        let size = end - cursor
        buffer.copyTo(buffer, cursor, used, size)
        used += size
    }

    private func copyTextNoEnsure(value: String): Unit {
        unsafe {
            value.rawData().copyTo(buffer, 0, used, value.size)
        }
        used += value.size
    }
    
    // Generated scalar fields use short, compile-time ASCII names. Avoid
    // dispatching tiny copies through the generic raw-data copy routine while
    // retaining the fallback for arbitrary longer names.
    private func copyTextNoEnsureFast(value: String): Unit {
        let size = value.size
        if (size == 0) { return }
        unsafe {
            let bytes = value.rawData()
            if (size == 1) {
                buffer[used] = bytes[0]
            } else if (size == 2) {
                buffer[used] = bytes[0]
                buffer[used + 1] = bytes[1]
            } else if (size == 3) {
                buffer[used] = bytes[0]
                buffer[used + 1] = bytes[1]
                buffer[used + 2] = bytes[2]
            } else if (size == 4) {
                buffer[used] = bytes[0]
                buffer[used + 1] = bytes[1]
                buffer[used + 2] = bytes[2]
                buffer[used + 3] = bytes[3]
            } else {
                bytes.copyTo(buffer, 0, used, size)
            }
        }
        used += size
    }

    private func copyTextRangeNoEnsure(value: String, start: Int64, end: Int64): Unit {
        let size = end - start
        if (size <= 0) {
            return
        }
        unsafe {
            value.rawData().copyTo(buffer, start, used, size)
        }
        used += size
    }


    private func writeAsciiEscapeNoEnsure(byte: Int64): Unit {
        if (byte == Int64(b'"')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b'"')
            return
        }
        if (byte == Int64(b'\\')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b'\\')
            return
        }
        if (byte == Int64(b'\b')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b'b')
            return
        }
        if (byte == Int64(b'\f')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b'f')
            return
        }
        if (byte == Int64(b'\n')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b'n')
            return
        }
        if (byte == Int64(b'\r')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b'r')
            return
        }
        if (byte == Int64(b'\t')) {
            writeRawByteNoEnsure(b'\\')
            writeRawByteNoEnsure(b't')
            return
        }
        writeRawByteNoEnsure(b'\\')
        writeRawByteNoEnsure(b'u')
        writeRawByteNoEnsure(b'0')
        writeRawByteNoEnsure(b'0')
        writeRawByteNoEnsure(jsonHexNibbleByte(byte >> 4))
        writeRawByteNoEnsure(jsonHexNibbleByte(byte & 0xF))
    }


    /**
     * 完成内存目标的写出阶段。
     *
     * 此目标没有待刷新的外部资源，本方法不修改缓冲区，也不检查 JSON 结构或预算。
     *
     * @group 30-first-party-internal 第一方内部接口
     */
    public func finish(): Unit {}

    /**
     * 返回当前缓冲区的已写字节数。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 自创建或最近一次 reset 以来追加的字节数。
     */
    public func bytesWritten(): Int64 { used }


    /**
     * 将已经写入的缓冲内容构造成 UTF-8 字符串。
     *
     * 使用免校验的 UTF-8 构造路径。调用方必须保证通过原始字节入口写入的内容也是有效 UTF-8。本方法不检查 JSON 完整性。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 由当前已写字节构造的字符串。
     */
    public func buildString(): String {
        // Every writer entry point appends either bytes copied from a String or
        // JSON syntax/number bytes generated by this module. The buffer is
        // therefore already valid UTF-8; validating it again here only scans
        // the complete encoded payload a second time.
        unsafe { String.fromUtf8Unchecked(buffer[0..used]) }
    }

    /**
     * 返回缓冲区中已经写入的字节。
     *
     * 不检查 JSON 完整性，也不重置已写长度。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 当前已写部分对应的字节数组。
     */
    public func buildBytes(): Array<Byte> {
        buffer[0..used]
    }
}


class DirectStreamWriterTarget <: JsonDirectWriterTarget {
    private let out: OutputStream
    private let buffer: Array<Byte>
    private let maxBytes: Int64
    private var used: Int64 = 0
    private var committed: Int64 = 0
    private var limitFailed: Bool = false

    init(out: OutputStream, config: JsonWriteOptions) {
        this.out = out
        this.buffer = Array<Byte>(JSON_STREAM_BUFFER_CAPACITY, repeat: 0)
        this.maxBytes = config.maxOutputBytes
    }

    public func writeText(value: String): Unit {
        writeTextRange(value, 0, value.size)
    }

    public func writeTextRange(value: String, start: Int64, end: Int64): Unit {
        let size = end - start
        if (size <= 0) {
            return
        }
        ensureAdditionalOutput(size)
        if (size >= JSON_STREAM_DIRECT_WRITE_THRESHOLD) {
            flushBuffer()
            unsafe {
                out.write(value.rawData()[start..end])
            }
            committed += size
            return
        }
        if (used + size > buffer.size) {
            flushBuffer()
        }
        unsafe {
            value.rawData().copyTo(buffer, start, used, size)
        }
        used += size
        if (used == buffer.size) {
            flushBuffer()
        }
    }

    public func writeByte(value: Byte): Unit {
        writeRawByte(value)
    }

    public func writeBytes(value: Array<Byte>): Unit {
        if (value.isEmpty()) { return }
        ensureAdditionalOutput(value.size)
        if (value.size >= JSON_STREAM_DIRECT_WRITE_THRESHOLD) {
            flushBuffer()
            out.write(value)
            committed += value.size
            return
        }
        if (used + value.size > buffer.size) { flushBuffer() }
        value.copyTo(buffer, 0, used, value.size)
        used += value.size
    }

    public func writeBytesRange(value: Array<Byte>, start: Int64, end: Int64): Unit {
        let size = end - start
        if (size <= 0) { return }
        ensureAdditionalOutput(size)
        if (size >= JSON_STREAM_DIRECT_WRITE_THRESHOLD) {
            flushBuffer()
            out.write(value[start..end])
            committed += size
            return
        }
        if (used + size > buffer.size) { flushBuffer() }
        value.copyTo(buffer, start, used, size)
        used += size
    }

    public func reserveCapacity(additional: Int64): Unit {
        if (additional > 0 && additional < buffer.size) {
            ensureBufferedCapacity(additional)
        }
    }

    public func tryWriteNativeInt64Array(values: ArrayList<Int64>): Bool {
        let _ = values
        false
    }

    public func writeStringLiteralNoEscape(value: String): Unit {
        writeRawByte(b'"')
        writeText(value)
        writeRawByte(b'"')
    }

    public func writeStringLiteralNoEscapeName(value: String): Unit {
        writeRawByte(b'"')
        writeText(value)
        writeRawByte(b'"')
        writeRawByte(b':')
    }

    public func writeEscapedStringLiteralFromFirstEscape(value: String, firstEscape: Int64, htmlSafe: Bool): Unit {
        writeRawByte(b'"')
        var segmentStart: Int64 = 0
        if (!htmlSafe) {
            for (index in firstEscape..value.size) {
                let byte = Int64(value[index])
                if (byte > 127 || !(byte < 32 || byte == Int64(b'"') || byte == Int64(b'\\'))) {
                    continue
                }
                writeTextRange(value, segmentStart, index)
                writeAsciiEscape(byte)
                segmentStart = index + 1
            }
            writeTextRange(value, segmentStart, value.size)
            writeRawByte(b'"')
            return
        }
        for (index in firstEscape..value.size) {
            let byte = Int64(value[index])
            if (byte > 127 || !shouldEscapeJsonAscii(byte, htmlSafe)) {
                continue
            }
            writeTextRange(value, segmentStart, index)
            writeAsciiEscape(byte)
            segmentStart = index + 1
        }
        writeTextRange(value, segmentStart, value.size)
        writeRawByte(b'"')
    }

    public func writeTextStringLiteralNoEscape(prefix: String, value: String): Unit {
        writeText(prefix)
        writeRawByte(b'"')
        writeText(value)
        writeRawByte(b'"')
    }

    public func writeTextStringArrayListNoEscape(prefix: String, values: ArrayList<String>, totalStringSize: Int64): Unit {
        reserveCapacity(prefix.size + totalStringSize + values.size * 3 + 2)
        writeText(prefix)
        writeRawByte(b'[')
        if (values.size != 0) {
            writeStringLiteralNoEscape(values[0])
            for (index in 1..values.size) {
                writeRawByte(b',')
                writeStringLiteralNoEscape(values[index])
            }
        }
        writeRawByte(b']')
    }

    public func writeCompactInt64Map(prefix: String, values: HashMap<String, Int64>): Unit {
        reserveCapacity(jsonRawInt64MapReserveHint(prefix.size, values.size))
        writeText(prefix)
        writeRawByte(b'{')
        var first = true
        for ((key, item) in values) {
            let firstEscape = jsonRawCompactStringEscapeIndex(key)
            if (firstEscape < 0) {
                first = writeObjectEntryNameInt64NoEscape(first, key, item)
            } else {
                if (!first) {
                    writeRawByte(b',')
                }
                writeEscapedStringLiteralFromFirstEscape(key, firstEscape, false)
                writeRawByte(b':')
                writeInt64Text(item)
                first = false
            }
        }
        writeRawByte(b'}')
    }

    public func writeCompactInt64Array(values: Array<Int64>): Unit {
        reserveCapacity(values.size * 21 + 1)
        writeRawByte(b'[')
        if (!values.isEmpty()) {
            writeInt64Text(values[0])
            for (index in 1..values.size) {
                writeRawByte(b',')
                writeInt64Text(values[index])
            }
        }
        writeRawByte(b']')
    }

    public func writeCompactFloat64Array(values: Array<Float64>): Unit {
        reserveCapacity(values.size * 24 + 2)
        writeRawByte(b'[')
        if (!values.isEmpty()) {
            writeFloat64Text(values[0])
            for (index in 1..values.size) {
                writeRawByte(b',')
                writeFloat64Text(values[index])
            }
        }
        writeRawByte(b']')
    }

    public func writeNewlineAndIndent(newline: String, indent: String, depth: Int64): Unit {
        writeText(newline)
        for (_ in 0..depth) {
            writeText(indent)
        }
    }

    public func writeObjectEntryNameInt64NoEscape(first: Bool, name: String, value: Int64): Bool {
        if (!first) {
            writeRawByte(b',')
        }
        writeStringLiteralNoEscapeName(name)
        writeInt64Text(value)
        false
    }

    public func writeBoolText(value: Bool): Unit {
        if (value) {
            writeText("true")
        } else {
            writeText("false")
        }
    }

    public func writeInt64Text(value: Int64): Unit {
        if (value < 0) {
            if (value == -0x8000_0000_0000_0000) {
                writeText("-9223372036854775808")
                return
            }
            writeRawByte(b'-')
            writeUInt64Digits(UInt64(-value))
            return
        }
        writeUInt64Digits(UInt64(value))
    }

    public func writeUInt64Text(value: UInt64): Unit {
        writeUInt64Digits(value)
    }

    public func writeFloat64Text(value: Float64): Unit {
        ensureBufferedCapacity(40)
        if (let Some(written) <- jsonNativeFormatFloat64Into(value, buffer, used)) {
            ensureAdditionalOutput(written)
            used += written
            return
        }
        writeText(value.toString())
    }

    private func flushBuffer(): Unit {
        if (used == 0) {
            return
        }
        if (used == buffer.size) {
            out.write(buffer)
        } else {
            out.write(buffer[0..used])
        }
        committed += used
        used = 0
    }

    private func ensureBufferedCapacity(additional: Int64): Unit {
        if (used + additional > buffer.size) {
            flushBuffer()
        }
    }

    private func writeRawByte(value: Byte): Unit {
        ensureAdditionalOutput(1)
        ensureBufferedCapacity(1)
        buffer[used] = value
        used++
        if (used == buffer.size) {
            flushBuffer()
        }
    }

    private func writeUInt64Digits(value: UInt64): Unit {
        ensureAdditionalOutput(jsonRawUInt64Size(value))
        if (value == 0u64) {
            writeRawByteNoLimit(b'0')
            return
        }
        if (value < 10u64) {
            writeRawByteNoLimit(UInt8(48u64 + value))
            return
        }
        if (value < 100u64) {
            ensureBufferedCapacity(2)
            buffer[used] = UInt8(48u64 + value / 10u64)
            buffer[used + 1] = UInt8(48u64 + value % 10u64)
            used += 2
            return
        }
        if (value < 1000u64) {
            ensureBufferedCapacity(3)
            buffer[used] = UInt8(48u64 + value / 100u64)
            let rest = value % 100u64
            buffer[used + 1] = UInt8(48u64 + rest / 10u64)
            buffer[used + 2] = UInt8(48u64 + rest % 10u64)
            used += 3
            return
        }
        if (value < 10000u64) {
            ensureBufferedCapacity(4)
            buffer[used] = UInt8(48u64 + value / 1000u64)
            var rest = value % 1000u64
            buffer[used + 1] = UInt8(48u64 + rest / 100u64)
            rest %= 100u64
            buffer[used + 2] = UInt8(48u64 + rest / 10u64)
            buffer[used + 3] = UInt8(48u64 + rest % 10u64)
            used += 4
            return
        }
        if (value < 100000u64) {
            ensureBufferedCapacity(5)
            buffer[used] = UInt8(48u64 + value / 10000u64)
            var rest = value % 10000u64
            buffer[used + 1] = UInt8(48u64 + rest / 1000u64)
            rest %= 1000u64
            buffer[used + 2] = UInt8(48u64 + rest / 100u64)
            rest %= 100u64
            buffer[used + 3] = UInt8(48u64 + rest / 10u64)
            buffer[used + 4] = UInt8(48u64 + rest % 10u64)
            used += 5
            return
        }
        ensureBufferedCapacity(20)
        var current = value
        let end = used + 20
        var cursor = end
        while (current != 0u64) {
            let digit = current % 10u64
            cursor--
            buffer[cursor] = UInt8(48u64 + digit)
            current /= 10u64
        }
        let size = end - cursor
        buffer.copyTo(buffer, cursor, used, size)
        used += size
    }

    private func writeRawByteNoLimit(value: Byte): Unit {
        ensureBufferedCapacity(1)
        buffer[used] = value
        used++
        if (used == buffer.size) {
            flushBuffer()
        }
    }

    private func ensureAdditionalOutput(additional: Int64): Unit {
        if (limitFailed) {
            throwOutputLimit()
        }
        let written = bytesWritten()
        if (maxBytes > 0 && (written > maxBytes || additional > maxBytes - written)) {
            limitFailed = true
            throwOutputLimit()
        }
    }

    private func throwOutputLimit(): Nothing {
        throw JsonException(
            "Encoded JSON exceeds ${maxBytes} bytes",
            code: "output_too_large"
        )
    }


    private func writeAsciiEscape(byte: Int64): Unit {
        if (byte == Int64(b'"')) {
            writeRawByte(b'\\')
            writeRawByte(b'"')
            return
        }
        if (byte == Int64(b'\\')) {
            writeRawByte(b'\\')
            writeRawByte(b'\\')
            return
        }
        if (byte == Int64(b'\b')) {
            writeRawByte(b'\\')
            writeRawByte(b'b')
            return
        }
        if (byte == Int64(b'\f')) {
            writeRawByte(b'\\')
            writeRawByte(b'f')
            return
        }
        if (byte == Int64(b'\n')) {
            writeRawByte(b'\\')
            writeRawByte(b'n')
            return
        }
        if (byte == Int64(b'\r')) {
            writeRawByte(b'\\')
            writeRawByte(b'r')
            return
        }
        if (byte == Int64(b'\t')) {
            writeRawByte(b'\\')
            writeRawByte(b't')
            return
        }
        writeRawByte(b'\\')
        writeRawByte(b'u')
        writeRawByte(b'0')
        writeRawByte(b'0')
        writeRawByte(jsonHexNibbleByte(byte >> 4))
        writeRawByte(jsonHexNibbleByte(byte & 0xF))
    }


    public func finish(): Unit {
        if (limitFailed) {
            throwOutputLimit()
        }
        flushBuffer()
        out.flush()
    }

    public func bytesWritten(): Int64 { committed + used }

}

/**
 * 供 codec 和生成代码将一个 JSON 根值直接写入字符串、字节数组或调用方流。
 *
 * 语义入口维护容器状态和 JSON Pointer，raw 入口依赖生成代码维护对象字段、逗号和相配的边界。内存目标的总输出预算在完成阶段检查，部分转义路径还会提前检查。流目标在追加内容时检查预算。流的所有权属于调用方，finish 刷新但不关闭流，失败时可能已有部分输出。生成代码取得的缓冲目标只能用于字符串或字节目标。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class JsonDirectWriter <: GeneratedSupportV1Writer & GeneratedWriteStateV1Owner {
    private static let ARRAY_FIRST: UInt8 = 0x1
    private static let ARRAY_NEXT: UInt8 = 0x0
    private static let OBJECT_FIRST: UInt8 = 0x3
    private static let OBJECT_NEXT: UInt8 = 0x2
    private static let OBJECT_EXPECTING_VALUE: UInt8 = 0x6
    private static let OBJECT_MASK: UInt8 = 0x2
    private static let FIRST_MASK: UInt8 = 0x1
    private static let EXPECTING_VALUE_MASK: UInt8 = 0x4
    private static let RAW_ARRAY: UInt8 = 0x1
    private static let RAW_OBJECT: UInt8 = 0x2

    private static let ESCAPE_TABLE: Array<UInt8> = buildEscapeLookupTable(false)
    private static let ESCAPE_TABLE_HTML: Array<UInt8> = buildEscapeLookupTable(true)

    private static func buildEscapeLookupTable(htmlSafe: Bool): Array<UInt8> {
        let table = Array<UInt8>(256, repeat: 0)
        for (byte in 0..128) {
            if (shouldEscapeJsonAscii(byte, htmlSafe)) {
                table[byte] = 1
            }
        }
        table
    }

    private let target: JsonDirectWriterTarget
    // String/bytes encoding is the dominant generated-code path. Keep its
    // concrete target alongside the polymorphic stream target so compact raw
    // field writes do not pay runtime method-table lookup for every token.
    private let bufferTarget: DirectBufferWriterTarget
    private let config: JsonWriteOptions
    private var generatedState: Option<GeneratedWriteStateV1> = None<GeneratedWriteStateV1>
    private let multiline: Bool
    private let resultKind: UInt8
    private var contexts: Option<ArrayList<UInt8>> = None<ArrayList<UInt8>>
    private var semanticPathContexts: Option<ArrayList<JsonDirectSemanticPathContext>> =
        None<ArrayList<JsonDirectSemanticPathContext>>
    private var rootWritten: Bool = false
    private var rawDepth: Int64 = 0
    // The generated compact string/bytes path has already established a
    // single raw root and emits balanced object boundaries from generated
    // code. Keep a small state bit so those boundaries avoid the general
    // container-kind stack and result-target dispatch.
    private var generatedCompactRawFast: Bool = false
    private var rawRootPreclaimed: Bool = false
    // Keep the common generated path allocation-free. The overflow stack is
    // allocated only for raw nesting deeper than 64 containers.
    private var rawKnownKinds: UInt64 = 0u64
    private var rawObjectKinds: UInt64 = 0u64
    private var rawOverflowKinds: Option<ArrayList<UInt8>> = None<ArrayList<UInt8>>
    private var lastRawString: Option<String> = None<String>
    private var lastRawStringEscapeIndex: Int64 = -1

    /**
     * 创建输出字符串的直接 JSON 写出器。
     *
     * pretty 为 true 时使用 JsonWriteOptions.pretty() 的两空格缩进预设，否则使用 compact 预设。最终字符串由 finishString 取得。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param pretty 是否采用两空格缩进的格式化输出，默认 false。
     */
    public init(pretty!: Bool = false) {
        let writerConfig = if (pretty) { JsonWriteOptions.pretty() } else { JsonWriteOptions.compact }
        bufferTarget = DirectBufferWriterTarget(capacity: directStringWriterInitialCapacity(writerConfig))
        target = bufferTarget
        config = writerConfig
        multiline = !config.newline.isEmpty()
        resultKind = 0
    }

    /**
     * 按给定写出选项创建字符串目标的直接 JSON 写出器。
     *
     * 保留配置中的缩进、HTML 转义、输出字节预算和最大深度。最终字符串由 finishString 取得。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param config 本次写出使用的不可变格式和资源限制。
     */
    public init(config: JsonWriteOptions) {
        bufferTarget = DirectBufferWriterTarget(capacity: directStringWriterInitialCapacity(config))
        target = bufferTarget
        this.config = config
        multiline = !config.newline.isEmpty()
        resultKind = 0
    }

    /**
     * 创建将 JSON 写入调用方输出流的直接写出器。
     *
     * 流由调用方持有。finish 会写出内部剩余缓冲并刷新该流，但不会关闭流。写出失败时流中可能已有部分内容。此目标使用 finish 完成写出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param out 接收 UTF-8 JSON 字节的输出流，所有权保留在调用方。
     * @param config 格式和资源限制，默认使用紧凑预设。
     */
    public init(out: OutputStream, config!: JsonWriteOptions = JsonWriteOptions.compact) {
        bufferTarget = DirectBufferWriterTarget(capacity: 0)
        target = DirectStreamWriterTarget(out, config)
        this.config = config
        multiline = !config.newline.isEmpty()
        resultKind = 2
    }

    private init(target: DirectBufferWriterTarget, config: JsonWriteOptions, resultKind: UInt8) {
        bufferTarget = target
        this.target = target
        this.config = config
        multiline = !config.newline.isEmpty()
        this.resultKind = resultKind
    }

    /**
     * 创建输出 UTF-8 字节数组的直接 JSON 写出器。
     *
     * 最终字节由 finishBytes 取得。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param config 格式和资源限制，默认使用紧凑预设。
     * @return 使用内存字节目标的新写出器。
     */
    public static func bytes(config!: JsonWriteOptions = JsonWriteOptions.compact): JsonDirectWriter {
        JsonDirectWriter(DirectBufferWriterTarget(), config, 1)
    }

    private func rawTargetWriteByte(value: Byte): Unit {
        if (resultKind == 2) { target.writeByte(value) } else { bufferTarget.writeByte(value) }
    }

    private func rawTargetWriteText(value: String): Unit {
        if (resultKind == 2) { target.writeText(value) } else { bufferTarget.writeText(value) }
    }

    private func rawTargetWriteStringNoEscape(value: String): Unit {
        if (resultKind == 2) {
            target.writeStringLiteralNoEscape(value)
        } else {
            bufferTarget.writeStringLiteralNoEscape(value)
        }
    }

    private func rawTargetWriteNameNoEscape(value: String): Unit {
        if (resultKind == 2) {
            target.writeStringLiteralNoEscapeName(value)
        } else {
            bufferTarget.writeStringLiteralNoEscapeName(value)
        }
    }

    private func rawTargetWriteInt64(value: Int64): Unit {
        if (resultKind == 2) { target.writeInt64Text(value) } else { bufferTarget.writeInt64Text(value) }
    }

    private func rawTargetWriteUInt64(value: UInt64): Unit {
        if (resultKind == 2) { target.writeUInt64Text(value) } else { bufferTarget.writeUInt64Text(value) }
    }

    private func rawTargetWriteFloat64(value: Float64): Unit {
        if (resultKind == 2) { target.writeFloat64Text(value) } else { bufferTarget.writeFloat64Text(value) }
    }

    private func rawTargetWriteBool(value: Bool): Unit {
        if (resultKind == 2) { target.writeBoolText(value) } else { bufferTarget.writeBoolText(value) }
    }

    /**
     * 创建绑定到当前写出器的生成代码游标。
     *
     * 游标继续操作同一个写出器及其目标和状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 绑定到当前 JsonDirectWriter 的写出游标。
     */
    public func generatedCursorV1(): GeneratedSupportV1WriteCursor {
        GeneratedSupportV1WriteCursor(this)
    }
    /**
     * 返回供生成代码直接写入的缓冲目标。
     *
     * 字符串和字节目标使用该缓冲区作为实际输出目标。流模式下返回的是零容量占位缓冲区，生成代码不得通过它写出流内容。此方法本身不检查目标种类。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 此写出器持有的同一个 DirectBufferWriterTarget。
     */
    public func generatedBufferV1(): DirectBufferWriterTarget {
        bufferTarget
    }

    private func writeState(): GeneratedWriteStateV1 {
        match (generatedState) {
            case Some(value) => value
            case None =>
                let value = GeneratedWriteStateV1(config)
                generatedState = Some(value)
                value
        }
    }

    /**
     * 返回当前写出器共享的生成代码遍历状态。
     *
     * 首次访问时按写出配置创建状态，后续访问复用同一个状态对象，用于生成代码维护路径和遍历深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前写出器持有的 GeneratedWriteStateV1。
     */
    public func generatedWriteStateV1(): GeneratedWriteStateV1 { writeState() }

    /**
     * 返回当前写出路径的 JSON Pointer。
     *
     * 路径由语义入口及生成代码共享的遍历状态提供。根路径为空串。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前 JSON Pointer，根为长度为零的字符串。
     */
    public func path(): String { writeState().currentPath() }

    /**
     * 构造携带当前 JSON Pointer 的 JSON 异常。
     *
     * 只构造异常对象，不主动抛出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param message 供人阅读的错误说明。
     * @param code 供程序判断的错误类别。
     * @return 携带 message、code 和当前路径的 JsonException。
     */
    public func error(message: String, code: String): JsonException {
        JsonException(message, code: code, path: path())
    }

    /**
     * 核对完整根值并完成目标写出。
     *
     * 要求恰有一个完整根值，且语义容器、raw 容器和预占值状态均已结束。流目标随后写出剩余缓冲并刷新流，最后检查总输出字节数。不会关闭调用方流。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 根值未完成、容器未闭合或预占值未消费，错误码为 writer_state。总输出超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入或刷新操作抛出异常时，原样传播该异常。
     */
    public func finish(): Unit {
        ensureCompleteWriterState()
        target.finish()
        enforceOutputLimit()
    }

    /**
     * 完成写出并取得字符串结果。
     *
     * 先核对完整根值、完成目标写出并检查输出字节预算，再确认目标类型。只适用于通过字符串目标构造器创建的写出器。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前完整 JSON 的字符串。
     * @throws JsonException 根值或容器状态不完整，错误码为 writer_state。超过输出预算，错误码为 output_too_large。目标类型不匹配时也抛出此异常。
     * @throws Exception 在流目标上误用时，完成阶段可能传播输出流写入或刷新的异常。
     */
    public func finishString(): String {
        ensureCompleteWriterState()
        target.finish()
        enforceOutputLimit()
        if (resultKind != 0) {
            throw JsonException("JsonDirectWriter is not a string writer")
        }
        match (target) {
            case stringTarget: DirectBufferWriterTarget => stringTarget.buildString()
            case _ => throw JsonException("JsonDirectWriter is not a string writer")
        }
    }

    /**
     * 取得由生成 codec 已经写完的紧凑 JSON 字符串。
     *
     * 供生成代码已经保证一个完整、平衡 raw 根值的入口调用。本方法省略根值和容器状态复核，完成目标写出、检查输出预算和字符串目标类型后构造结果。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 已完成的生成式紧凑 JSON 字符串。
     * @throws JsonException 超过 maxOutputBytes，错误码为 output_too_large。当前目标不是字符串目标时也抛出此异常。
     * @throws Exception 在流目标上误用时，完成阶段可能传播输出流写入或刷新的异常。
     */
    public func finishGeneratedCompactString(): String {
        target.finish()
        enforceOutputLimit()
        if (resultKind != 0) {
            throw JsonException("JsonDirectWriter is not a string writer")
        }
        bufferTarget.buildString()
    }
    /**
     * 判断当前字符串写出器是否满足生成代码复用条件。
     *
     * 只有字符串目标、空缩进、关闭 HTML 额外转义、不限制输出字节数且最大深度为 256 时返回 true。该判断只检查目标和配置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 满足生成代码复用条件时为 true，否则为 false。
     */
    public func canReuseGeneratedCompactWriter(): Bool {
        resultKind == 0 && config.indent.isEmpty() && !config.htmlSafe &&
            config.maxOutputBytes == 0 && config.maxDepth == 256
    }

    /**
     * 在配置允许时重置字符串写出器以供生成代码复用。
     *
     * 满足 canReuseGeneratedCompactWriter 时，清除输出长度、路径、容器、根值、raw 状态和字符串转义缓存，并保留已分配的输出缓冲区。不满足条件时直接返回，不修改状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     */
    public func resetForGeneratedReuse(): Unit {
        if (!canReuseGeneratedCompactWriter()) { return }
        bufferTarget.reset()
        match (generatedState) {
            case Some(state) => state.resetForReuse()
            case None => ()
        }
        contexts = None<ArrayList<UInt8>>
        semanticPathContexts = None<ArrayList<JsonDirectSemanticPathContext>>
        rootWritten = false
        rawDepth = 0
        generatedCompactRawFast = false
        rawRootPreclaimed = false
        rawKnownKinds = 0u64
        rawObjectKinds = 0u64
        rawOverflowKinds = None<ArrayList<UInt8>>
        lastRawString = None<String>
        lastRawStringEscapeIndex = -1
    }

    /**
     * 完成写出并取得 UTF-8 字节数组结果。
     *
     * 先核对完整根值、完成目标写出并检查输出字节预算，再确认目标类型。只适用于通过 JsonDirectWriter.bytes 创建的字节目标。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前完整 JSON 的 UTF-8 字节数组。
     * @throws JsonException 根值或容器状态不完整，错误码为 writer_state。超过输出预算，错误码为 output_too_large。目标类型不匹配时也抛出此异常。
     * @throws Exception 在流目标上误用时，完成阶段可能传播输出流写入或刷新的异常。
     */
    public func finishBytes(): Array<Byte> {
        ensureCompleteWriterState()
        target.finish()
        enforceOutputLimit()
        if (resultKind != 1) {
            throw JsonException("JsonDirectWriter is not a bytes writer")
        }
        match (target) {
            case bytesTarget: DirectBufferWriterTarget => bytesTarget.buildBytes()
            case _ => throw JsonException("JsonDirectWriter is not a bytes writer")
        }
    }

    private func enforceOutputLimit(): Unit {
        if (config.maxOutputBytes > 0 && target.bytesWritten() > config.maxOutputBytes) {
            throw JsonException(
                "Encoded JSON exceeds ${config.maxOutputBytes} bytes",
                code: "output_too_large"
            )
        }
    }

    private func ensureCompleteWriterState(): Unit {
        if (!rootWritten || !contextsAreEmpty() || rawDepth != 0 || rawRootPreclaimed) {
            throw JsonException("JSON writer requires exactly one complete root value", code: "writer_state")
        }
    }

    private func contextValues(): ArrayList<UInt8> {
        match (contexts) {
            case Some(value) => value
            case None =>
                let value = ArrayList<UInt8>()
                contexts = Some(value)
                value
        }
    }

    private func contextsAreEmpty(): Bool {
        match (contexts) {
            case Some(value) => value.isEmpty()
            case None => true
        }
    }

    private func semanticPathContextValues(): ArrayList<JsonDirectSemanticPathContext> {
        match (semanticPathContexts) {
            case Some(value) => value
            case None =>
                let value = ArrayList<JsonDirectSemanticPathContext>()
                semanticPathContexts = Some(value)
                value
        }
    }

    func canWriteRawCompactValue(): Bool {
        contextsAreEmpty() && !rootWritten && !multiline && !config.useSpaceAfterSeparators && !config.htmlSafe
    }

    /**
     * 尝试为紧凑生成代码预占下一个 raw 值的位置。
     *
     * 配置启用换行、分隔符后空格或 HTML 额外转义时返回 false，不预占值。成功时先执行语义值前置处理，后续 raw 写入负责消费该预占位置并输出完整值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 已经预占位置并可使用紧凑 raw 写出时为 true，否则为 false。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryBeginGeneratedCompactRawValue(): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        beforeValue()
        generatedCompactRawFast = resultKind != 2
        rawRootPreclaimed = true
        true
    }

    /**
     * 在已有 raw 写出流程中追加一个原始字节。
     *
     * 消费尚未使用的 raw 值预占标记，但不主动建立根值或校验 JSON 语法。调用方保证最终结构和 UTF-8 有效性。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要原样写入的语法或内容字节。
     * @throws JsonException 流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawByte(value: Byte): Unit {
        consumeRawRootPreclaim()
        rawTargetWriteByte(value)
    }

    /**
     * 开始一个 raw JSON 数组。
     *
     * 检查当前容器深度，在需要时占用语义值位置，并记录 raw 数组类别。调用方负责数组内部元素及逗号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawBeginArray(): Unit {
        beginRawContainer(RAW_ARRAY)
        rawTargetWriteByte(b'[')
    }

    /**
     * 结束顶部 raw JSON 数组。
     *
     * 核对 raw 栈顶部是数组后写入右方括号，不自动处理父级字段或逗号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有可结束的 raw 容器，或顶部容器不是数组，错误码为 writer_state。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawEndArray(): Unit {
        endRawContainer(RAW_ARRAY)
        rawTargetWriteByte(b']')
    }

    /**
     * 开始一个 raw JSON 对象。
     *
     * 调用方负责对象字段及逗号。普通路径记录容器类别。已选用生成紧凑缓冲路径时只更新 raw 深度，由生成代码保证容器配对。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawBeginObject(): Unit {
        if (generatedCompactRawFast) {
            if (rawDepth == 0) {
                if (rawRootPreclaimed) { rawRootPreclaimed = false }
                else { beforeValue() }
            }
            if (rawDepth >= config.maxDepth) {
                throw JsonException(
                    "Maximum JSON depth ${config.maxDepth} exceeded",
                    code: "max_depth",
                    path: ""
                )
            }
            rawDepth++
            bufferTarget.writeByte(b'{')
            return
        }
        beginRawContainer(RAW_OBJECT)
        rawTargetWriteByte(b'{')
    }

    /**
     * 结束当前 raw JSON 对象。
     *
     * 普通路径核对顶部容器类别。生成紧凑缓冲路径只检查 raw 深度为正并递减深度，由生成代码保证对象边界配对。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有可结束的 raw 容器，或普通路径顶部容器不是对象，错误码为 writer_state。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawEndObject(): Unit {
        if (generatedCompactRawFast) {
            if (rawDepth <= 0) {
                throw JsonException("Unbalanced JSON writer state", code: "writer_state")
            }
            rawDepth--
            bufferTarget.writeByte(b'}')
            return
        }
        endRawContainer(RAW_OBJECT)
        rawTargetWriteByte(b'}')
    }

    func reserveRawCollectionCapacity(count: Int64): Unit {
        if (count < 4) { return }
        var hint = count * 64 + 2
        if (hint > 4096) { hint = 4096 }
        target.reserveCapacity(hint)
    }


    /**
     * 按当前转义配置写入 raw 对象字段名和冒号。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名执行标准 JSON 转义及配置要求的 HTML 额外转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param value 要按当前配置转义的字段名。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryName(first: Bool, value: String): Bool {
        if (!first) {
            rawTargetWriteByte(b',')
        }
        writeStringLiteralName(value)
        false
    }

    /**
     * 写入已知免转义字符串字段名和冒号。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownName(first: Bool, name: String): Bool {
        if (!first) { rawTargetWriteByte(b',') }
        rawTargetWriteNameNoEscape(name)
        false
    }

    /**
     * 仅向缓冲目标写入已知免转义 UTF-8 字节字段名和冒号。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。此字节字段名重载不会根据目标种类切换到流写出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的有效 UTF-8 字段名字节。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownName(first: Bool, name: Array<Byte>): Bool {
        writeRawObjectEntryKnownNameBuffer(first, name)
    }

    private func writeRawObjectEntryKnownNameBuffer(first: Bool, name: String): Bool {
        if (!first) { bufferTarget.writeByte(b',') }
        bufferTarget.writeStringLiteralNoEscapeName(name)
        false
    }

    private func writeRawObjectEntryKnownNameBuffer(first: Bool, name: Array<Byte>): Bool {
        if (!first) { bufferTarget.writeByte(b',') }
        bufferTarget.writeStringLiteralNoEscapeName(name)
        false
    }

    /**
     * 写入已知免转义字段名和按配置转义的字符串字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。字符串值按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameString(
        first: Bool, name: String, value: String
    ): Bool {
        let firstEscape = firstRawStringEscapeIndex(value)
        if (firstEscape < 0 && resultKind != 2) {
            return bufferTarget.writeObjectEntryNameStringNoEscape(first, name, value)
        }
        let next = writeRawObjectEntryKnownName(first, name)
        beginRawScalar()
        if (firstEscape < 0) {
            rawTargetWriteStringNoEscape(value)
        } else {
            writeStringLiteralFromFirstEscape(value, firstEscape)
        }
        next
    }

    /**
     * 写入已知免转义字段名和布尔字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的布尔值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameBool(
        first: Bool, name: String, value: Bool
    ): Bool {
        let next = writeRawObjectEntryKnownName(first, name)
        rawTargetWriteBool(value)
        next
    }

    /**
     * 写入已知免转义字段名和 Int64 字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的 Int64 值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameInt64(
        first: Bool, name: String, value: Int64
    ): Bool {
        if (resultKind == 2) {
            return target.writeObjectEntryNameInt64NoEscape(first, name, value)
        }
        bufferTarget.writeObjectEntryNameInt64NoEscape(first, name, value)
    }

    // Static compact codecs used by String/bytes entry points never target a
    // stream. Keep a buffer-only seam for those generated calls so each
    // scalar field avoids the resultKind branch and stream virtual dispatch.
    /**
     * 仅向缓冲目标写入已知免转义字段名和 Int64 字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的 Int64 值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownNameInt64Buffer(
        first: Bool, name: String, value: Int64
    ): Bool {
        bufferTarget.writeObjectEntryNameInt64NoEscape(first, name, value)
    }

    /**
     * 写入已知免转义字段名和 UInt64 字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的 UInt64 值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameUInt64(
        first: Bool, name: String, value: UInt64
    ): Bool {
        let next = writeRawObjectEntryKnownName(first, name)
        rawTargetWriteUInt64(value)
        next
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和 UInt64 字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的 UInt64 值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownNameUInt64Buffer(
        first: Bool, name: String, value: UInt64
    ): Bool {
        bufferTarget.writeObjectEntryNameUInt64NoEscape(first, name, value)
    }

    /**
     * 写入已知免转义字段名和有限 Float64 字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。写出前检查所有浮点值均有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的有限浮点字段值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameFloat64(
        first: Bool, name: String, value: Float64
    ): Bool {
        ensureFiniteJsonFloat(value)
        let next = writeRawObjectEntryKnownName(first, name)
        rawTargetWriteFloat64(value)
        next
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和有限 Float64 字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。写出前检查所有浮点值均有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的有限浮点字段值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeRawObjectEntryKnownNameFloat64Buffer(
        first: Bool, name: String, value: Float64
    ): Bool {
        ensureFiniteJsonFloat(value)
        bufferTarget.writeObjectEntryNameFloat64NoEscape(first, name, value)
    }

    /**
     * 写入已知免转义字段名和紧凑 Int64 数组字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的 Int64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameInt64Array(
        first: Bool, name: String, values: Array<Int64>
    ): Bool {
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownName(first, name)
        if (resultKind == 2) {
            target.writeCompactInt64Array(values)
        } else {
            bufferTarget.writeCompactInt64Array(values)
        }
        next
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和 Int64 映射字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。映射键执行标准 JSON 转义，不额外转义 HTML 敏感字符，适用于关闭 HTML 额外转义的紧凑生成路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的 Int64 映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。
     */
    public func writeRawObjectEntryKnownNameInt64MapBuffer(
        first: Bool, name: String, values: HashMap<String, Int64>
    ): Bool {
        ensureContainerDepth()
        bufferTarget.writeObjectEntryNameInt64MapNoEscape(first, name, values)
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和 ASCII 安全键的 Int64 映射字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。这是生成基准形状使用的已知 ASCII 键路径，映射键不扫描或转义。任意键应使用会检查转义的通用入口。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 键为无需转义 ASCII 文本的 Int64 映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。
     */
    public func writeRawObjectEntryKnownNameInt64MapKnownAsciiBuffer(
        first: Bool, name: String, values: HashMap<String, Int64>
    ): Bool {
        ensureContainerDepth()
        bufferTarget.writeObjectEntryNameInt64MapKnownAsciiKeys(first, name, values)
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和字符串映射字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。这是关闭 HTML 额外转义的紧凑生成路径，对映射键和值执行 JSON 转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的字符串映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。
     */
    public func writeRawObjectEntryKnownNameStringMapBuffer(
        first: Bool, name: String, values: HashMap<String, String>
    ): Bool {
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownNameBuffer(first, name)
        bufferTarget.writeByte(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            let firstEscape = jsonRawCompactStringEscapeIndex(mapName)
            if (firstEscape < 0 && firstStringEscapeIndex(value) < 0) {
                bufferTarget.writeObjectEntryNameStringNoEscape(mapFirst, mapName, value)
            } else {
                if (!mapFirst) { bufferTarget.writeByte(b',') }
                if (firstEscape < 0) {
                    bufferTarget.writeStringLiteralNoEscapeName(mapName)
                } else {
                    bufferTarget.writeEscapedStringLiteralFromFirstEscape(
                        mapName, firstEscape, config.htmlSafe)
                    bufferTarget.writeByte(b':')
                }
                let valueEscape = firstStringEscapeIndex(value)
                if (valueEscape < 0) {
                    bufferTarget.writeStringLiteralNoEscape(value)
                } else {
                    bufferTarget.writeEscapedStringLiteralFromFirstEscape(
                        value, valueEscape, config.htmlSafe)
                }
            }
            mapFirst = false
        }
        bufferTarget.writeByte(b'}')
        next
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和 Int64 数组映射字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。映射键执行标准 JSON 转义，不额外转义 HTML 敏感字符，适用于关闭 HTML 额外转义的紧凑生成路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的 Int64 数组映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeRawObjectEntryKnownNameInt64ArrayMapBuffer(
        first: Bool, name: String, values: HashMap<String, Array<Int64>>
    ): Bool {
        ensureContainerDepth()
        bufferTarget.writeObjectEntryNameInt64ArrayMapNoEscape(first, name, values)
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和 ASCII 安全键的 Int64 数组映射字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。这是生成基准形状使用的已知 ASCII 键路径，映射键不扫描或转义。任意键应使用会检查转义的通用入口。调用方还须保证已知键形状及剩余容量足以直接写入各映射键。此路径不为任意键长重新预留容量。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 键形状与写入容量已由生成代码约束、键无需 JSON 转义的 ASCII 键 Int64 数组映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeRawObjectEntryKnownNameInt64ArrayMapKnownAsciiBuffer(
        first: Bool, name: String, values: HashMap<String, Array<Int64>>
    ): Bool {
        ensureContainerDepth()
        bufferTarget.writeObjectEntryNameInt64ArrayMapKnownAsciiKeys(first, name, values)
    }

    /**
     * 写入已知免转义字段名和紧凑 Float64 数组字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。写出前检查所有浮点值均有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 所有元素均为有限值的 Float64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameFloat64Array(
        first: Bool, name: String, values: Array<Float64>
    ): Bool {
        for (value in values) { ensureFiniteJsonFloat(value) }
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownName(first, name)
        if (resultKind == 2) {
            target.writeCompactFloat64Array(values)
        } else {
            bufferTarget.writeCompactFloat64Array(values)
        }
        next
    }

    /**
     * 写入已知免转义字段名和紧凑字符串数组字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。字符串值按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的字符串数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameStringArray(
        first: Bool, name: String, values: Array<String>
    ): Bool {
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownName(first, name)
        rawTargetWriteByte(b'[')
        for (index in 0..values.size) {
            if (index > 0) { rawTargetWriteByte(b',') }
            writeRawString(values[index])
        }
        rawTargetWriteByte(b']')
        next
    }

    /**
     * 仅向缓冲目标写入已知免转义字符串字段名和字符串字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。字符串值按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownNameStringBuffer(
        first: Bool, name: String, value: String
    ): Bool {
        let firstEscape = firstRawStringEscapeIndex(value)
        if (firstEscape < 0) {
            return bufferTarget.writeObjectEntryNameStringNoEscape(first, name, value)
        }
        bufferTarget.writeObjectEntryNameStringEscaped(
            first, name, value, firstEscape, config.htmlSafe)
    }

    // Generated compact records use this buffer-only seam after reserving the
    // object budget. Reuse the writer's long-string escape cache, then skip
    // the target capacity check only for the proven unescaped case.
    /**
     * 在预留容量后写入已知免转义字段名和字符串字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。字符串值按当前配置执行转义。调用方先预留整个对象所需容量。无需转义的值直接写入，需要转义的值改走会扩容的分支。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownNameStringFast(
        first: Bool, name: String, value: String
    ): Bool {
        let firstEscape = firstRawStringEscapeIndex(value)
        if (firstEscape < 0) {
            return bufferTarget.writeObjectEntryNameStringNoEscapeFast(first, name, value)
        }
        bufferTarget.writeObjectEntryNameStringEscaped(
            first, name, value, firstEscape, config.htmlSafe)
    }

    /**
     * 仅向缓冲目标写入已知免转义 UTF-8 字节字段名和字符串字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。字符串值按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的有效 UTF-8 字段名字节。
     * @param value 要写出的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownNameStringBuffer(
        first: Bool, name: Array<Byte>, value: String
    ): Bool {
        let firstEscape = firstRawStringEscapeIndex(value)
        if (firstEscape < 0) {
            return bufferTarget.writeObjectEntryNameStringNoEscape(first, name, value)
        }
        bufferTarget.writeObjectEntryNameStringEscaped(
            first, name, value, firstEscape, config.htmlSafe)
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和布尔字段值。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param value 要写出的布尔值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     */
    public func writeRawObjectEntryKnownNameBoolBuffer(
        first: Bool, name: String, value: Bool
    ): Bool {
        bufferTarget.writeObjectEntryNameBoolNoEscape(first, name, value)
    }

    /**
     * 仅向缓冲目标写入已知免转义字段名和 Int64 数组字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的 Int64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeRawObjectEntryKnownNameInt64ArrayBuffer(
        first: Bool, name: String, values: Array<Int64>
    ): Bool {
        ensureContainerDepth()
        bufferTarget.writeObjectEntryNameInt64ArrayNoEscape(first, name, values)
    }

    /**
     * 仅向缓冲目标写入已知免转义字符串字段名和 Float64 数组字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。写出前检查所有浮点值均有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 所有元素均为有限值的 Float64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeRawObjectEntryKnownNameFloat64ArrayBuffer(
        first: Bool, name: String, values: Array<Float64>
    ): Bool {
        for (value in values) { ensureFiniteJsonFloat(value) }
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownNameBuffer(first, name)
        bufferTarget.writeCompactFloat64Array(values)
        next
    }

    /**
     * 仅向缓冲目标写入已知免转义 UTF-8 字节字段名和 Float64 数组字段。
     *
     * 供字符串或字节目标的生成代码调用，直接追加到内存缓冲区。调用方维护 raw 对象结构和语义路径。流目标不得使用此入口。字段名直接复制，调用方保证按当前规则无需转义。写出前检查所有浮点值均有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的有效 UTF-8 字段名字节。
     * @param values 所有元素均为有限值的 Float64 数组。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     */
    public func writeRawObjectEntryKnownNameFloat64ArrayBuffer(
        first: Bool, name: Array<Byte>, values: Array<Float64>
    ): Bool {
        for (value in values) { ensureFiniteJsonFloat(value) }
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownNameBuffer(first, name)
        bufferTarget.writeCompactFloat64Array(values)
        next
    }

    /**
     * 写入已知免转义字段名和紧凑 Int64 映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。映射键执行标准 JSON 转义，不额外转义 HTML 敏感字符，适用于关闭 HTML 额外转义的紧凑生成路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的 Int64 映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameInt64Map(
        first: Bool, name: String, values: HashMap<String, Int64>
    ): Bool {
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownName(first, name)
        writeRawInt64Map("", values)
        next
    }

    /**
     * 写入已知免转义字段名和紧凑字符串映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。映射键和值按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的字符串映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameStringMap(
        first: Bool, name: String, values: HashMap<String, String>
    ): Bool {
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownName(first, name)
        rawTargetWriteByte(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            mapFirst = writeRawObjectEntryNameString(mapFirst, mapName, value)
        }
        rawTargetWriteByte(b'}')
        next
    }

    /**
     * 写入已知免转义字段名和紧凑 Int64 数组映射字段。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名直接复制，调用方保证按当前规则无需转义。映射按自身迭代顺序输出。映射键按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 按当前转义规则无需转义的字段名。
     * @param values 要写出的 Int64 数组映射。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryKnownNameInt64ArrayMap(
        first: Bool, name: String, values: HashMap<String, Array<Int64>>
    ): Bool {
        ensureContainerDepth()
        let next = writeRawObjectEntryKnownName(first, name)
        rawTargetWriteByte(b'{')
        var mapFirst = true
        for ((mapName, value) in values) {
            mapFirst = writeRawObjectEntryName(mapFirst, mapName)
            if (resultKind == 2) {
                target.writeCompactInt64Array(value)
            } else {
                bufferTarget.writeCompactInt64Array(value)
            }
        }
        rawTargetWriteByte(b'}')
        next
    }
    /**
     * 按当前转义配置写入 raw 对象字段名和字符串字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名执行标准 JSON 转义及配置要求的 HTML 额外转义。字符串值按当前配置执行转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 要按当前配置转义的字段名。
     * @param value 要写出的字符串值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryNameString(first: Bool, name: String, value: String): Bool {
        if (!first) {
            rawTargetWriteByte(b',')
        }
        writeStringLiteralName(name)
        writeRawString(value)
        false
    }

    /**
     * 按当前转义配置写入 raw 对象字段名和 Int64 字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名执行标准 JSON 转义及配置要求的 HTML 额外转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 要按当前配置转义的字段名。
     * @param value 要写出的 Int64 值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryNameInt64(first: Bool, name: String, value: Int64): Bool {
        let firstEscape = firstStringEscapeIndex(name)
        if (firstEscape < 0) {
            if (resultKind == 2) {
                return target.writeObjectEntryNameInt64NoEscape(first, name, value)
            }
            return bufferTarget.writeObjectEntryNameInt64NoEscape(first, name, value)
        }
        if (!first) {
            rawTargetWriteByte(b',')
        }
        writeStringLiteralName(name)
        rawTargetWriteInt64(value)
        false
    }

    /**
     * 按当前转义配置写入 raw 对象字段名和 UInt64 字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名执行标准 JSON 转义及配置要求的 HTML 额外转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 要按当前配置转义的字段名。
     * @param value 要写出的 UInt64 值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryNameUInt64(first: Bool, name: String, value: UInt64): Bool {
        let next = writeRawObjectEntryName(first, name)
        rawTargetWriteUInt64(value)
        next
    }

    /**
     * 按当前转义配置写入 raw 对象字段名和有限 Float64 字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名执行标准 JSON 转义及配置要求的 HTML 额外转义。写出前检查所有浮点值均有限。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 要按当前配置转义的字段名。
     * @param value 要写出的有限浮点字段值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryNameFloat64(first: Bool, name: String, value: Float64): Bool {
        ensureFiniteJsonFloat(value)
        let next = writeRawObjectEntryName(first, name)
        rawTargetWriteFloat64(value)
        next
    }

    /**
     * 按当前转义配置写入 raw 对象字段名和布尔字段值。
     *
     * 供已建立 raw 对象上下文的紧凑生成代码调用。调用方维护字段顺序、逗号状态和语义路径。字段名执行标准 JSON 转义及配置要求的 HTML 额外转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首个字段。false 时先写入逗号。
     * @param name 要按当前配置转义的字段名。
     * @param value 要写出的布尔值。
     * @return 恒为 false，供调用方作为后续字段的 first 状态。
     * @throws JsonException 启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawObjectEntryNameBool(first: Bool, name: String, value: Bool): Bool {
        if (!first) {
            rawTargetWriteByte(b',')
        }
        writeStringLiteralName(name)
        rawTargetWriteBool(value)
        false
    }

    func writeRawStringArrayList(prefix: String, values: ArrayList<String>): Unit {
        var totalStringSize: Int64 = 0
        for (value in values) {
            if (firstStringEscapeIndex(value) >= 0) {
                writeRawStringArrayListFallback(prefix, values)
                return
            }
            totalStringSize += value.size
        }
        target.writeTextStringArrayListNoEscape(prefix, values, totalStringSize)
    }

    private func writeRawStringArrayListFallback(prefix: String, values: ArrayList<String>): Unit {
        target.writeText(prefix)
        if (values.size == 0) {
            target.writeText("[]")
            return
        }
        target.writeByte(b'[')
        writeRawString(values[0])
        for (index in 1..values.size) {
            target.writeByte(b',')
            writeRawString(values[index])
        }
        target.writeByte(b']')
    }

    func writeRawInt64Map(prefix: String, values: HashMap<String, Int64>): Unit {
        target.writeCompactInt64Map(prefix, values)
    }

    func tryWriteCompactRawMap<T>(values: HashMap<String, T>, codec: JsonRawWriteCodec<T>): Bool {
        if (!canWriteRawCompactValue()) {
            return false
        }
        ensureContainerDepth()
        beforeValue()
        rawDepth++
        try {
            target.reserveCapacity(jsonRawInt64MapReserveHint(0, values.size))
            target.writeByte(b'{')
            var first = true
            for ((name, item) in values) {
                if (first) {
                    first = false
                } else {
                    target.writeByte(b',')
                }
                let firstEscape = jsonRawCompactStringEscapeIndex(name)
                if (firstEscape < 0) {
                    target.writeStringLiteralNoEscapeName(name)
                } else {
                    target.writeEscapedStringLiteralFromFirstEscape(name, firstEscape, false)
                    target.writeByte(b':')
                }
                codec.writeRaw(item, this)
            }
            target.writeByte(b'}')
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑 Int64 数组。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按数组顺序输出整数。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的 Int64 数组。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactInt64Array(values: Array<Int64>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            if (resultKind == 2) {
                target.writeCompactInt64Array(values)
            } else {
                bufferTarget.writeCompactInt64Array(values)
            }
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑 Float64 数组。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按数组顺序输出有限浮点值。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。任一元素为 NaN 或无穷大时也返回 false。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的 Float64 数组。
     * @return 已写出完整容器时为 true。配置不适用或包含非有限浮点值时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactFloat64Array(values: Array<Float64>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        for (value in values) {
            if (value.isNaN() || value.isInf()) { return false }
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            if (resultKind == 2) {
                target.writeCompactFloat64Array(values)
            } else {
                bufferTarget.writeCompactFloat64Array(values)
            }
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑字符串数组。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按数组顺序输出字符串，对内容执行标准 JSON 转义。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的字符串数组。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactStringArray(values: Array<String>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            target.writeByte(b'[')
            for (index in 0..values.size) {
                if (index > 0) { target.writeByte(b',') }
                writeRawString(values[index])
            }
            target.writeByte(b']')
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑 Int64 列表。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按列表顺序输出整数，优先尝试 Native 列表格式化。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的 Int64 列表。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactInt64ArrayList(values: ArrayList<Int64>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            if (target.tryWriteNativeInt64Array(values)) { return true }
            var totalValueSize: Int64 = 0
            for (item in values) {
                totalValueSize += jsonRawInt64Size(item)
            }
            target.reserveCapacity(totalValueSize + values.size + 1)
            target.writeByte(b'[')
            if (!values.isEmpty()) {
                target.writeInt64Text(values[0])
                for (index in 1..values.size) {
                    target.writeByte(b',')
                    target.writeInt64Text(values[index])
                }
            }
            target.writeByte(b']')
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑字符串列表。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按列表顺序输出字符串，对内容执行标准 JSON 转义。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的字符串列表。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactStringArrayList(values: ArrayList<String>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            writeRawStringArrayList("", values)
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑 Int64 映射。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按映射迭代顺序输出对象，键执行标准 JSON 转义。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的 Int64 映射。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactInt64Map(values: HashMap<String, Int64>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            writeRawInt64Map("", values)
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑字符串映射。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按映射迭代顺序输出对象，对键和值执行标准 JSON 转义。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的字符串映射。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactStringMap(values: HashMap<String, String>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            target.writeByte(b'{')
            var first = true
            for ((name, value) in values) {
                first = writeRawObjectEntryNameString(first, name, value)
            }
            target.writeByte(b'}')
        } finally {
            rawDepth--
        }
        true
    }

    /**
     * 尝试在当前值位置写出紧凑 Int64 数组映射。
     *
     * 配置使用换行、分隔符后空格或 HTML 额外转义时返回 false，不开始该值。按映射迭代顺序输出对象键和数组值，键执行标准 JSON 转义。采用该路径时检查容器入口深度并占用当前值位置，调用方不另写该容器的外层边界。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param values 要写出的 Int64 数组映射。
     * @return 已写出完整容器时为 true。配置不适用时为 false。
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func tryWriteCompactInt64ArrayMap(values: HashMap<String, Array<Int64>>): Bool {
        if (multiline || config.useSpaceAfterSeparators || config.htmlSafe) {
            return false
        }
        ensureContainerDepth()
        beginRawValue()
        rawDepth++
        try {
            target.writeByte(b'{')
            var first = true
            for ((name, value) in values) {
                first = writeRawObjectEntryName(first, name)
                if (resultKind == 2) {
                    target.writeCompactInt64Array(value)
                } else {
                    bufferTarget.writeCompactInt64Array(value)
                }
            }
            target.writeByte(b'}')
        } finally {
            rawDepth--
        }
        true
    }

    func writeRawString(value: String): Unit {
        beginRawScalar()
        let firstEscape = firstRawStringEscapeIndex(value)
        if (firstEscape < 0) {
            rawTargetWriteStringNoEscape(value)
            return
        }
        writeStringLiteralFromFirstEscape(value, firstEscape)
    }

    /**
     * 在当前 raw 值位置写入 JSON null。
     *
     * 位于 raw 容器内时不自动写逗号。容器外则消费预占位置或执行语义值前置处理。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawNull(): Unit {
        beginRawScalar()
        rawTargetWriteText("null")
    }

    func writeRawBool(value: Bool): Unit {
        beginRawScalar()
        rawTargetWriteBool(value)
    }

    func writeRawInt64(value: Int64): Unit {
        beginRawScalar()
        rawTargetWriteInt64(value)
    }

    /**
     * 在当前 raw 值位置写入 UInt64 十进制文本。
     *
     * 位于 raw 容器内时不自动写逗号。容器外则消费预占位置或执行语义值前置处理。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写出的无符号整数。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeRawUInt64(value: UInt64): Unit {
        beginRawScalar()
        rawTargetWriteUInt64(value)
    }

    func writeRawFloat64(value: Float64): Unit {
        ensureFiniteJsonFloat(value)
        beginRawScalar()
        rawTargetWriteFloat64(value)
    }

    func writeRawNumberValue(value: String): Unit {
        beginRawScalar()
        rawTargetWriteText(value)
    }

    private func beginRawScalar(): Unit {
        beginRawValue()
    }

    private func beginRawValue(): Unit {
        if (rawDepth != 0) { return }
        if (rawRootPreclaimed) {
            rawRootPreclaimed = false
            return
        }
        beforeValue()
    }

    private func beginRawContainer(kind: UInt8): Unit {
        if (currentContainerDepth() >= config.maxDepth) {
            throw JsonException(
                "Maximum JSON depth ${config.maxDepth} exceeded",
                code: "max_depth",
                path: path()
            )
        }
        if (rawDepth == 0) {
            if (rawRootPreclaimed) {
                rawRootPreclaimed = false
            } else {
                beforeValue()
            }
        }
        rememberRawContainerKind(kind)
        rawDepth++
    }

    private func endRawContainer(expectedKind: UInt8): Unit {
        if (rawDepth <= 0) {
            throw JsonException("Unbalanced JSON writer state", code: "writer_state")
        }
        let index = rawDepth - 1
        if (rawContainerKind(index) != expectedKind) {
            throw JsonException("Mismatched raw JSON container close", code: "writer_state")
        }
        forgetRawContainerKind(index)
        rawDepth--
    }

    private func rememberRawContainerKind(kind: UInt8): Unit {
        if (rawDepth < 64) {
            let mask = 1u64 << rawDepth
            rawKnownKinds |= mask
            if (kind == RAW_OBJECT) {
                rawObjectKinds |= mask
            }
            return
        }
        let position = rawDepth - 64
        let values = match (rawOverflowKinds) {
            case Some(existing) => existing
            case None =>
                let created = ArrayList<UInt8>()
                rawOverflowKinds = Some(created)
                created
        }
        if (values.size != position) {
            throw JsonException("Invalid raw JSON container stack", code: "writer_state")
        }
        values.add(kind)
    }

    private func rawContainerKind(index: Int64): UInt8 {
        if (index < 64) {
            let mask = 1u64 << index
            if ((rawKnownKinds & mask) == 0u64) { return 0u8 }
            if ((rawObjectKinds & mask) == 0u64) { RAW_ARRAY } else { RAW_OBJECT }
        } else {
            let position = index - 64
            match (rawOverflowKinds) {
                case Some(values) => values[position]
                case None => 0u8
            }
        }
    }

    private func forgetRawContainerKind(index: Int64): Unit {
        if (index < 64) {
            let mask = 1u64 << index
            rawKnownKinds ^= mask
            if ((rawObjectKinds & mask) != 0u64) { rawObjectKinds ^= mask }
            return
        }
        match (rawOverflowKinds) {
            case Some(values) => values.remove(at: values.size - 1)
            case None => ()
        }
    }

    private func consumeRawRootPreclaim(): Unit {
        if (rawDepth == 0 && rawRootPreclaimed) {
            rawRootPreclaimed = false
        }
    }

    /**
     * 在当前语义值位置开始一个 JSON 对象。
     *
     * 检查容器深度，处理根值或父容器分隔符，并记录新容器及其语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func startObject(): Unit {
        ensureContainerDepth()
        let pathPushed = beforeValue()
        target.writeByte(b'{')
        contextValues().add(OBJECT_FIRST)
        semanticPathContextValues().add(JsonDirectSemanticPathContext(writeState().pathDepth(), pathPushed))
    }

    /**
     * 结束当前语义对象并恢复父级写出路径。
     *
     * 检查顶部容器类别。对象还有未写值的字段时不能结束。非空且配置使用换行时，先写出父级缩进，再输出结束符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有对应的开放容器、顶部容器类别不符或对象仍在等待字段值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func endObject(): Unit {
        let context = popContext(true)
        let values = contextValues()
        if ((context & FIRST_MASK) == 0 && multiline) {
            writeNewlineAndIndent(values.size)
        }
        target.writeByte(b'}')
        let pathContexts = semanticPathContextValues()
        let pathContext = pathContexts.remove(at: pathContexts.size - 1)
        writeState().completeAutoValue(pathContext.entryPathPushed)
    }

    /**
     * 在当前语义值位置开始一个 JSON 数组。
     *
     * 检查容器深度，处理根值或父容器分隔符，并记录新容器及其语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前字段或容器入口超过 maxDepth，错误码为 max_depth。已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func startArray(): Unit {
        ensureContainerDepth()
        let pathPushed = beforeValue()
        target.writeByte(b'[')
        contextValues().add(ARRAY_FIRST)
        semanticPathContextValues().add(JsonDirectSemanticPathContext(writeState().pathDepth(), pathPushed))
    }

    /**
     * 结束当前语义数组并恢复父级写出路径。
     *
     * 检查顶部容器类别。非空且配置使用换行时，先写出父级缩进，再输出结束符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 没有对应的开放容器、顶部容器类别不符或对象仍在等待字段值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func endArray(): Unit {
        let context = popContext(false)
        let values = contextValues()
        if ((context & FIRST_MASK) == 0 && multiline) {
            writeNewlineAndIndent(values.size)
        }
        target.writeByte(b']')
        let pathContexts = semanticPathContextValues()
        let pathContext = pathContexts.remove(at: pathContexts.size - 1)
        writeState().completeAutoValue(pathContext.entryPathPushed)
    }

    /**
     * 在当前语义对象中写入字段名并等待字段值。
     *
     * 按当前 HTML 转义选项写出带双引号的字段名和冒号，需要时追加分隔空格，同时为接下来的值记录字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param name 要写出的字段名，可以包含需要 JSON 转义的字符。
     * @throws JsonException 当前不在语义对象中，或上一个字段还没有写入值。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeName(name: String): Unit {
        beforeName()
        writeStringLiteralName(name)
        if (config.useSpaceAfterSeparators) {
            target.writeText(" ")
        }
        let pathContexts = semanticPathContextValues()
        let pathContext = pathContexts[pathContexts.size - 1]
        pathContext.pendingObjectPathPushed = writeState().pushAutoField(name, pathContext.pathDepth)
    }

    private func beforeName(): Unit {
        if (contextsAreEmpty()) {
            throw JsonException("Cannot write a field name outside object")
        }
        let values = contextValues()
        let index = values.size - 1
        let context = values[index]
        if ((context & OBJECT_MASK) == 0 || (context & EXPECTING_VALUE_MASK) != 0) {
            throw JsonException("Cannot write a field name here")
        }
        if ((context & FIRST_MASK) != 0) {
            writeEntryPrefix(values.size)
        } else {
            target.writeByte(b',')
            writeEntryPrefix(values.size)
        }
        values[index] = OBJECT_EXPECTING_VALUE
    }

    /**
     * 在当前语义值位置写入 JSON null。
     *
     * 自动处理父容器的分隔符和路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeNull(): Unit {
        let pathPushed = beforeValue()
        try { target.writeText("null") } finally { writeState().completeAutoValue(pathPushed) }
    }

    /**
     * 在当前语义值位置写入一个布尔值。
     *
     * 自动处理父容器的分隔符和路径。写出结束或抛出异常后结束本次自动路径范围。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写出的 Bool 值。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeBool(value: Bool): Unit {
        let pathPushed = beforeValue()
        try { target.writeBoolText(value) } finally { writeState().completeAutoValue(pathPushed) }
    }

    /**
     * 在当前语义值位置写入一个有符号整数。
     *
     * 自动处理父容器的分隔符和路径。写出结束或抛出异常后结束本次自动路径范围。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写出的 Int64 值。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeInt64(value: Int64): Unit {
        let pathPushed = beforeValue()
        try { target.writeInt64Text(value) } finally { writeState().completeAutoValue(pathPushed) }
    }

    /**
     * 在当前语义值位置写入一个无符号整数。
     *
     * 自动处理父容器的分隔符和路径。写出结束或抛出异常后结束本次自动路径范围。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写出的 UInt64 值。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeUInt64(value: UInt64): Unit {
        let pathPushed = beforeValue()
        try { target.writeUInt64Text(value) } finally { writeState().completeAutoValue(pathPushed) }
    }

    /**
     * 在当前语义值位置写入一个有限 Float64 值。
     *
     * 自动处理父容器的分隔符和路径，拒绝 NaN 和无穷大。先尝试 Native 浮点格式化，未采用时使用浮点文本。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写出的有限浮点值。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。浮点值为 NaN 或无穷大。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeFloat64(value: Float64): Unit {
        let pathPushed = beforeValue()
        try {
            ensureFiniteJsonFloat(value)
            target.writeFloat64Text(value)
        } finally { writeState().completeAutoValue(pathPushed) }
    }

    /**
     * 在当前语义值位置写入已经验证的 JSON 数字字面量。
     *
     * 先校验完整 JSON 数字语法，再原样写入文本。不把数字转成浮点数或整数。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 必须完全符合 JSON 数字语法的文本。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。value 不是合法的完整 JSON 数字字面量，错误码为 invalid_number。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeNumberLiteral(value: String): Unit {
        let pathPushed = beforeValue()
        try {
            if (!isValidJsonNumberLiteral(value)) {
                throw error("Invalid JSON number literal", "invalid_number")
            }
            target.writeText(value)
        } finally { writeState().completeAutoValue(pathPushed) }
    }

    /**
     * 在当前语义值位置写入 JSON 字符串。
     *
     * 自动处理父容器分隔符和路径，并按当前配置添加双引号、执行标准 JSON 转义及适用的 HTML 额外转义。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写出的字符串内容。
     * @throws JsonException 已经写入根值，或当前对象尚未写字段名而不能接受值。启用的 Native 写出路径检查失败，错误码为 acceleration_writer_failure。流目标追加内容时超过 maxOutputBytes，错误码为 output_too_large。
     * @throws Exception 调用方输出流的写入操作抛出异常时，原样传播该异常。
     */
    public func writeString(value: String): Unit {
        let pathPushed = beforeValue()
        try { writeStringLiteral(value) } finally { writeState().completeAutoValue(pathPushed) }
    }

    private func beforeValue(): Bool {
        if (contextsAreEmpty()) {
            if (rootWritten) {
                throw JsonException("JSON writer accepts exactly one root value", code: "writer_state")
            }
            rootWritten = true
            return false
        }
        let values = contextValues()
        let index = values.size - 1
        let context = values[index]
        if ((context & OBJECT_MASK) != 0) {
            if ((context & EXPECTING_VALUE_MASK) == 0) {
                throw JsonException("Object values must be preceded by a field name")
            }
            values[index] = OBJECT_NEXT
            let pathContext = semanticPathContextValues()[index]
            let pathPushed = pathContext.pendingObjectPathPushed
            pathContext.pendingObjectPathPushed = false
            writeState().beginAutoValue(pathPushed)
            return pathPushed
        }
        let pathContext = semanticPathContextValues()[index]
        let pathPushed = writeState().pushAutoIndex(pathContext.nextArrayIndex, pathContext.pathDepth)
        pathContext.nextArrayIndex++
        if ((context & FIRST_MASK) != 0) {
            writeEntryPrefix(values.size)
            values[index] = ARRAY_NEXT
            writeState().beginAutoValue(pathPushed)
            return pathPushed
        }
        target.writeByte(b',')
        writeEntryPrefix(values.size)
        writeState().beginAutoValue(pathPushed)
        pathPushed
    }

    private func ensureContainerDepth(): Unit {
        if (currentContainerDepth() >= config.maxDepth) {
            throw JsonException(
                "Maximum JSON depth ${config.maxDepth} exceeded",
                code: "max_depth",
                path: path()
            )
        }
    }

    private func currentContainerDepth(): Int64 {
        let semanticDepth = match (contexts) {
            case Some(value) => value.size
            case None => 0
        }
        semanticDepth + rawDepth
    }

    private func popContext(expectedObject: Bool): UInt8 {
        if (contextsAreEmpty()) {
            throw JsonException("Unbalanced JSON writer state")
        }
        let values = contextValues()
        let index = values.size - 1
        let context = values[index]
        let objectContext = (context & OBJECT_MASK) != 0
        let expectingFieldValue = (context & EXPECTING_VALUE_MASK) != 0
        if (objectContext != expectedObject || expectingFieldValue) {
            throw JsonException("Unbalanced JSON writer state")
        }
        values.remove(at: index)
        context
    }

    private func writeEntryPrefix(depth: Int64): Unit {
        if (multiline) {
            writeNewlineAndIndent(depth)
        }
    }

    private func writeNewlineAndIndent(depth: Int64): Unit {
        target.writeNewlineAndIndent(config.newline, config.indent, depth)
    }

    private func writeStringLiteral(value: String): Unit {
        let firstEscape = firstStringEscapeIndex(value)
        if (firstEscape < 0) {
            rawTargetWriteStringNoEscape(value)
            return
        }
        writeStringLiteralFromFirstEscape(value, firstEscape)
    }

    private func writeStringLiteralName(value: String): Unit {
        let firstEscape = firstStringEscapeIndex(value)
        if (firstEscape < 0) {
            rawTargetWriteNameNoEscape(value)
            return
        }
        writeStringLiteralFromFirstEscape(value, firstEscape)
        rawTargetWriteByte(b':')
    }

    private func writeStringLiteralFromFirstEscape(value: String, firstEscape: Int64): Unit {
        if (let Some(required) <- jsonNativeEscapedStringSize(value, config.htmlSafe)) {
            enforceAdditionalOutputLimit(required)
            if (let Some(escaped) <- jsonNativeEscapeString(value, config.htmlSafe, required)) {
                if (resultKind == 2) { target.writeBytes(escaped) } else { bufferTarget.writeBytes(escaped) }
                return
            }
        }
        if (resultKind == 2) {
            target.writeEscapedStringLiteralFromFirstEscape(value, firstEscape, config.htmlSafe)
        } else {
            bufferTarget.writeEscapedStringLiteralFromFirstEscape(value, firstEscape, config.htmlSafe)
        }
    }

    private func enforceAdditionalOutputLimit(additional: Int64): Unit {
        if (config.maxOutputBytes > 0 && (target.bytesWritten() > config.maxOutputBytes ||
            additional > config.maxOutputBytes - target.bytesWritten())) {
            throw JsonException(
                "Encoded JSON exceeds ${config.maxOutputBytes} bytes",
                code: "output_too_large"
            )
        }
    }

    private func firstStringEscapeIndex(value: String): Int64 {
        let table = if (config.htmlSafe) { ESCAPE_TABLE_HTML } else { ESCAPE_TABLE }
        unsafe {
            let bytes = value.rawData()
            for (index in 0..bytes.size) {
                if (table[Int64(bytes[index])] != 0) {
                    return index
                }
            }
        }
        -1
    }

    private func firstRawStringEscapeIndex(value: String): Int64 {
        if (value.size == 0) { return -1 }
        if (value.size < 256) { return firstStringEscapeIndex(value) }
        if (let Some(previous) <- lastRawString) {
            if (previous == value) { return lastRawStringEscapeIndex }
        }
        let result = firstStringEscapeIndex(value)
        lastRawString = Some(value)
        lastRawStringEscapeIndex = result
        return result
    }

}
