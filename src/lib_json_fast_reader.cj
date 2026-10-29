package yjson

import std.collection.*
import std.convert.Parsable
import std.math.numeric.*
import std.time.*

private let YJSON_NATIVE_SKIP_MIN_REMAINING_BYTES: Int64 = 128
private let YJSON_RAW_NUMBER_SMALL_DIGITS: Int64 = 18

// Package-internal object-key representation used by CompactJsonDocument.
// A no-escape key retains only its validated source range; escaped keys keep
// the decoded semantic String so raw spellings such as "a" and "\u0061"
// still compare as the same JSON member name.
struct JsonObjectKeyView {
    let sourceStart: Int64
    let sourceLength: Int64
    let owned: Option<String>

    init(sourceStart: Int64, sourceLength: Int64) {
        this.sourceStart = sourceStart
        this.sourceLength = sourceLength
        this.owned = None<String>
    }

    init(value: String) {
        this.sourceStart = -1
        this.sourceLength = 0
        this.owned = Some(value)
    }

    func isSource(): Bool { sourceStart >= 0 }
}

/**
 * 提供匹配版本生成代码使用的字节游标读取实现。
 *
 * raw 方法推进游标，但不完整管理容器、字段路径或生成代码深度；相应状态由生成代码和 GeneratedReadStateV1 协作维护。公开构造器均用默认选项。数组输入直接保留，字符串输入保留原字符串及其 UTF-8 数据；读取期间不得修改共享数组。Fast 入口不额外保证完整语义校验或数值精度。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class JsonFastReader <: GeneratedSupportV1Reader & GeneratedReadStateV1Owner {
    private let data: Array<Byte>
    private let size: Int64
    private let validateStrings: Bool
    private let config: JsonReadOptions
    private let sourceText: Option<String>
    private var index: Int64 = 0
    private var rawTokenStart: Int64 = 0
    private var rawTokenEnd: Int64 = 0
    private var rawTokenNumberDigitCount: Int64 = 0
    private var rawTokenNumberScale: Int64 = 0
    private var rawTokenNumberSmallUnscaled: Int64 = 0
    private var rawTokenNumberSmallUnscaledValid = true
    private var rawTokenNumberNegative = false
    private var rawTokenNumberHasExponent = false
    private var rawTokenNumberHasNonZero = false
    private var rawDateTimeCacheEpochSecond: Int64 = 0
    private var rawDateTimeCacheOffsetSeconds: Int64 = 0
    private var rawDateTimeCacheValue: Option<DateTime> = None<DateTime>
    // Linear duplicate scan for policy-aware unknown-object skips. The
    // window [base..count) always holds the current object level only;
    // an aborted skip leaves the cursor stale, which the next level's
    // base snapshot simply skips over.
    private var skipSeenNames: Array<String> = Array<String>(16, repeat: "")
    private var skipSeenCount: Int64 = 0

    private func ensureSkipSeenCapacity(): Unit {
        if (skipSeenCount < skipSeenNames.size) { return }
        let grown = Array<String>(skipSeenNames.size * 2, repeat: "")
        for (position in 0..skipSeenCount) { grown[position] = skipSeenNames[position] }
        skipSeenNames = grown
    }

    private let generatedState = GeneratedReadStateV1(JsonReadOptions.defaults)

    /**
     * 以字符串的 UTF-8 数据创建读取游标。
     *
     * 保留原字符串，不先复制为整份独立输入；字符串模式不重复执行字节输入的 UTF-8 校验。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param text 待读取的 JSON 文本。
     */
    public init(text: String) {
        unsafe {
            data = text.rawData()
        }
        size = data.size
        validateStrings = false
        config = JsonReadOptions.defaults
        sourceText = Some(text)
    }

    /**
     * 以共享字节数组创建读取游标。
     *
     * 不复制数组，调用方在读取期间不得修改它；字符串解码的检查路径会校验 UTF-8。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param bytes 待读取的 UTF-8 JSON 字节数组。
     */
    public init(bytes: Array<Byte>) {
        data = bytes
        size = bytes.size
        validateStrings = true
        config = JsonReadOptions.defaults
        sourceText = None<String>
    }

    /**
     * 跳过尾部空白并确认没有剩余字节。
     *
     * 只检查游标之后的输入，不验证调用方是否已读过一个根值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 跳过空白后仍有输入，错误码为 parse_error。
     */
    public func expectEnd(): Unit {
        skipSpaces()
        if (hasMore()) {
            fail("Unexpected trailing input")
        }
    }

    /**
     * 取得读取器共用的生成代码状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 该实例持有的路径和深度状态对象。
     */
    public func generatedReadStateV1(): GeneratedReadStateV1 { generatedState }

    // Package consumers such as CompactJsonDocument need only the semantic
    // token kind; exposing it avoids duplicating whitespace and token-start
    // validation while keeping the reader cursor and source private.
    /**
     * 查看下一个值的起始字节所表示的类型。
     *
     * 跳过空白，但不消费值，也不校验完整 token。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 下一个值的 JsonKind。
     * @throws JsonException 输入结束或起始字节不是可识别的 JSON 值，错误码为 parse_error。
     */
    public func peekRawKind(): JsonKind {
        skipSpaces()
        if (!hasMore()) { fail("Unexpected end of JSON input") }
        match (peek()) {
            case b'n' => JsonKind.Null
            case b't' | b'f' => JsonKind.Boolean
            case b'"' => JsonKind.String
            case b'[' => JsonKind.Array
            case b'{' => JsonKind.Object
            case b'-' | b'0' | b'1' | b'2' | b'3' | b'4' | b'5' | b'6' | b'7' | b'8' | b'9' => JsonKind.Number
            case _ => fail("Unexpected token")
        }
    }

    func position(): Int64 {
        index
    }

    func semanticLocation(): Option<JsonLocation> {
        Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
            jsonColumnFromUtf8Bytes(data, index)))
    }

    func semanticError(message: String, code: String): JsonException {
        JsonException(message, code: code, path: generatedState.currentPath(),
            location: semanticLocation())
    }

    func rewind(position: Int64): Unit {
        index = position
    }

    func tryReadNativeInt64ArrayList(): Option<ArrayList<Int64>> {
        let original = index
        skipSpaces()
        if (!hasMore() || peek() != b'[' || size - index < 1024) {
            index = original
            return None<ArrayList<Int64>>
        }
        let converted = match (jsonNativeParseInt64Array(data, index)) {
            case Some(value) => value
            case None =>
                index = original
                return None<ArrayList<Int64>>
        }
        let result = ArrayList<Int64>(converted.count)
        for (offset in 0..converted.count) { result.add(converted.values[offset]) }
        index = converted.end
        Some(result)
    }

    func tryEndRawObject(): Bool {
        if (hasMore() && peek() == b'}') {
            index++
            return true
        }
        false
    }

    func tryStartRawObjectCompact(): Bool {
        skipSpaces()
        if (hasMore() && peek() == b'{') {
            index++
            return true
        }
        false
    }

    func tryNextRawObjectFieldCompact(first: Bool): Bool {
        if (!hasMore()) {
            return false
        }
        let current = peek()
        if (current == b' ' || current == b'\n' || current == b'\r' || current == b'\t' || current == b'}') {
            return false
        }
        if (first) {
            return current == b'"'
        }
        if (current != b',' || index + 1 >= size || data[index + 1] != b'"') {
            return false
        }
        index++
        true
    }

    // Generated-code bridge for the allocation-free ordered object path.  It
    // consumes only an exact compact `"name":` token (and the comma when this
    // is not the first field).  A miss is transactional so generated codecs
    // can immediately continue with the general name dispatcher.
    /**
     * 尝试消费紧凑对象中精确匹配的字段 token。
     *
     * 只匹配无空白的双引号名称和紧随其后的冒号；非首字段还消费前导逗号。不解码转义。失败时不改变游标，可接着走通用字段读取。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首字段；为 false 时必须先匹配逗号。
     * @param expectedNameBytes 预期名称的原始 UTF-8 字节，不含引号、冒号或逗号。
     * @return 精确匹配并消费成功时为 true，否则为 false。
     */
    public func tryReadRawCompactNameTokenBytes(
        first: Bool,
        expectedNameBytes: Array<Byte>
    ): Bool {
        var currentIndex = index
        if (!first) {
            if (currentIndex >= size || data[currentIndex] != b',') {
                return false
            }
            currentIndex++
        }
        let nameSize = expectedNameBytes.size
        if (currentIndex + nameSize + 3 > size ||
            data[currentIndex] != b'"') {
            return false
        }
        currentIndex++
        match (nameSize) {
            case 1 =>
                if (data[currentIndex] != expectedNameBytes[0]) { return false }
            case 2 =>
                if (data[currentIndex] != expectedNameBytes[0] ||
                    data[currentIndex + 1] != expectedNameBytes[1]) {
                    return false
                }
            case 3 =>
                if (data[currentIndex] != expectedNameBytes[0] ||
                    data[currentIndex + 1] != expectedNameBytes[1] ||
                    data[currentIndex + 2] != expectedNameBytes[2]) {
                    return false
                }
            case 4 =>
                if (data[currentIndex] != expectedNameBytes[0] ||
                    data[currentIndex + 1] != expectedNameBytes[1] ||
                    data[currentIndex + 2] != expectedNameBytes[2] ||
                    data[currentIndex + 3] != expectedNameBytes[3]) {
                    return false
                }
            case _ =>
                for (offset in 0..nameSize) {
                    if (data[currentIndex + offset] != expectedNameBytes[offset]) {
                        return false
                    }
                }
        }
        currentIndex += nameSize
        if (data[currentIndex] != b'"' || data[currentIndex + 1] != b':') {
            return false
        }
        index = currentIndex + 2
        true
    }
    /**
     * 消费对象开始符。
     *
     * 跳过空白后消费 {，不压入或弹出语义容器状态，也不自动计算生成代码深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 缺少预期分隔符或输入结束，错误码为 parse_error。
     */
    public func startRawObject(): Unit {
        skipSpaces()
        expectByte(b'{')
    }

    /**
     * 按剩余字节数估算对象初始容量。
     *
     * 不推进游标，不统计真实字段数。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 4 到 256 之间的容量提示。
     */
    public func suggestRawObjectCapacity(): Int64 {
        // Object entries are usually much smaller than the conservative
        // generic container hint (especially String -> Int64 maps). A
        // capacity based on the remaining compact bytes avoids repeated
        // HashMap growth for medium/large generated maps while retaining a
        // bounded allocation for untrusted input.
        let remaining = size - index
        if (remaining <= 16) {
            return 4
        }
        let estimate = remaining / 8 + 1
        match {
            case estimate < 4 => 4
            case estimate > 256 => 256
            case _ => estimate
        }
    }

    /**
     * 消费对象结束符。
     *
     * 跳过空白后消费 }，不压入或弹出语义容器状态，也不自动计算生成代码深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 缺少预期分隔符或输入结束，错误码为 parse_error。
     */
    public func endRawObject(): Unit {
        skipSpaces()
        expectByte(b'}')
    }

    /**
     * 检查游标是否仍可能有字段。
     *
     * 跳过空白后只判断是否到达输入末尾或 }，不消费逗号，也不校验后续值。当前实现不使用 first。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 保留的首项状态参数；该实现不依此参数分支。
     * @return 仍有字节且当前字节不是 } 时为 true。
     */
    public func hasRawObjectField(first: Bool): Bool {
        skipSpaces()
        let _ = first
        hasMore() && peek() != b'}'
    }

    // Compact generated containers have no whitespace.  Keep the delimiter
    // check branch-only; readRawNameFast() consumes the comma when needed.
    /**
     * 按首项状态检查对象是否还有下一项。
     *
     * 跳过空白；首项判断当前字节是否不是 }，后续项判断是否为逗号。结果不代表后续内容已通过语法校验，逗号仍由后续读取消费。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否还未消费该容器的第一项。
     * @return 当前位置符合对应首项或逗号条件时为 true。
     */
    public func hasRawObjectFieldFast(first: Bool): Bool {
        if (!hasMore()) { return false }
        var current = data[index]
        if (isJsonSpace(current)) {
            skipSpaces()
            if (!hasMore()) { return false }
            current = data[index]
        }
        if (first) {
            current != b'}'
        } else {
            current == b','
        }
    }

    func nextRawObjectField(first: Bool): Bool {
        if (first) {
            if (hasMore()) {
                let current = peek()
                if (current == b'}') {
                    return false
                }
                if (!isJsonSpace(current)) {
                    return true
                }
            }
        } else if (hasMore() && peek() == b',') {
            index++
            if (hasMore() && !isJsonSpace(peek())) {
                return true
            }
            skipSpaces()
            return true
        }
        skipSpaces()
        if (hasMore() && peek() == b'}') {
            return false
        }
        if (!first) {
            expectByte(b',')
            skipSpaces()
        }
        true
    }

    /**
     * 消费字段名前的分隔符、名称和冒号。
     *
     * 跳过空白；非首字段先消费逗号。本方法不更新生成代码路径，也不处理未知字段或重复键策略。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首字段；为 false 时先消费逗号。
     * @return 解码后的 JSON 字段名。
     * @throws JsonException 分隔符、字符串或冒号无效，或字符串校验失败。
     */
    public func readRawName(first: Bool): String {
        let original = index
        skipSpaces()
        if (!first) {
            expectByte(b',')
            skipSpaces()
        }
        if (!hasMore() || data[index] != b'"') {
            index = original
            return readRawNameChecked(first)
        }
        index++
        let start = index
        while (index < size) {
            let current = data[index]
            if (current == b'"') {
                let end = index
                index++
                skipSpaces()
                expectByte(b':')
                return stringFromUtf8Range(start, end)
            }
            if (current == b'\\' || current < 0x20 || current >= 0x80) {
                index = original
                return readRawNameChecked(first)
            }
            index++
        }
        index = original
        readRawNameChecked(first)
    }

    private func readRawNameChecked(first: Bool): String {
        beforeRawFieldName(first)
        let name = parseString()
        afterRawFieldName()
        name
    }

    /**
     * 消费字段名前的分隔符、名称和冒号。
     *
     * 跳过空白；非首字段先消费逗号。本方法不更新生成代码路径，也不处理未知字段或重复键策略。当前实现转调 readRawName。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首字段；为 false 时先消费逗号。
     * @return 解码后的 JSON 字段名。
     * @throws JsonException 分隔符、字符串或冒号无效，或字符串校验失败。
     */
    public func readRawNameFast(first: Bool): String {
        readRawName(first)
    }

    // Compact-only seam: unlike readRawName(), the common no-escape path does
    // not materialize a transient String and does not need a later reverse
    // scan to recover the source range.
    func readRawObjectKeyView(first: Bool): JsonObjectKeyView {
        beforeRawFieldName(first)
        expectByte(b'"')
        let start = index
        while (index < size) {
            let current = data[index]
            if (current == b'"') {
                let end = index
                index++
                afterRawFieldName()
                return JsonObjectKeyView(start, end - start)
            }
            if (current == b'\\') {
                let value = parseEscapedString(start)
                afterRawFieldName()
                return JsonObjectKeyView(value)
            }
            if (current < 0x20) {
                failAt("Unescaped control character in string literal", index)
            }
            if (current >= 0x80) {
                if (validateStrings) {
                    index += validatedUtf8WidthAt(index)
                    continue
                }
            }
            index++
        }
        fail("Unterminated string literal")
    }

    /**
     * 消费对象字段名并匹配 UTF-8 候选名称。
     *
     * 同时消费前导分隔符和尾随冒号；按解码后的名称匹配，不更新路径或自行拒绝未知字段。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前对象的首字段。
     * @param candidates 按返回索引排列的有效 UTF-8 字段名字节数组。
     * @return 匹配候选的索引，未匹配时为 -1。
     * @throws JsonException 字段语法或字符串内容无效。
     * @throws Exception 候选名称在需要转换为字符串的路径中不是有效 UTF-8。
     */
    public func readRawNameIdBytes(first: Bool, candidates: Array<Array<Byte>>): Int64 {
        beforeRawFieldName(first)
        let id = match (tryParseSimpleNameId(candidates)) {
            case Some(value) => value
            case None => parseNameIdBytes(candidates)
        }
        afterRawFieldName()
        id
    }

    func readRawNameAfterSeparator(): String {
        let name = parseString()
        afterRawFieldName()
        name
    }

    /**
     * 消费数组开始符。
     *
     * 跳过空白后消费 [，不压入或弹出语义容器状态，也不自动计算生成代码深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 缺少预期分隔符或输入结束，错误码为 parse_error。
     */
    public func startRawArray(): Unit {
        skipSpaces()
        expectByte(b'[')
    }

    func tryStartRawArrayCompact(): Bool {
        skipSpaces()
        if (hasMore() && peek() == b'[') {
            index++
            return true
        }
        false
    }

    // Capacity hint retained for the existing scalar collection helpers.
    /**
     * 按剩余字节数估算数组初始容量。
     *
     * 不推进游标，不统计真实元素数。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 4 到 64 之间的容量提示。
     */
    public func suggestRawArrayCapacity(): Int64 {
        suggestContainerCapacity(32)
    }

    /**
     * 为已消费开始符的数组估算初始容量。
     *
     * 不推进游标，不保证等于元素数。根数组可采样前部内容；其他位置按剩余字节估算。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 根据当前位置及可采样内容得到的容量提示。
     */
    public func suggestRawCollectionCapacity(): Int64 {
        let remaining = size - index
        if (remaining >= 3072 && isRootRawArrayPosition()) {
            return sampleRootArrayCapacity(remaining)
        }
        let estimate = remaining / 64 + 1
        if (estimate < 48) {
            return 4
        }
        if (estimate > 64) {
            return 64
        }
        estimate
    }

    private func isRootRawArrayPosition(): Bool {
        var opener = index - 1
        while (opener >= 0 && isJsonSpace(data[opener])) { opener-- }
        if (opener < 0 || data[opener] != b'[') { return false }
        for (cursor in 0..opener) {
            if (!isJsonSpace(data[cursor])) { return false }
        }
        true
    }

    private func sampleRootArrayCapacity(remaining: Int64): Int64 {
        let sampleEnd = if (index + 512 < size) { index + 512 } else { size }
        var cursor = index
        var depth: Int64 = 0
        var entries: Int64 = 1
        var inString = false
        var escaped = false
        while (cursor < sampleEnd) {
            let current = data[cursor]
            if (inString) {
                if (escaped) {
                    escaped = false
                } else if (current == b'\\') {
                    escaped = true
                } else if (current == b'"') {
                    inString = false
                }
            } else {
                match (current) {
                    case b'"' => inString = true
                    case b'[' | b'{' => depth++
                    case b'}' => if (depth > 0) { depth-- }
                    case b']' =>
                        if (depth == 0) {
                            return if (entries < 4) { 4 } else { entries }
                        }
                        depth--
                    case b',' => if (depth == 0) { entries++ }
                    case _ => ()
                }
            }
            cursor++
        }
        if (entries < 2) {
            let conservative = remaining / 64 + 1
            return if (conservative > 1024) { 1024 } else { conservative }
        }
        // The sampled window is non-empty and at least two entries were seen,
        // so averageBytes is positive and the estimate cannot be below 8.
        let averageBytes = (cursor - index) / entries
        let estimate = remaining / averageBytes + 1
        if (estimate > 1024) { 1024 } else { estimate }
    }

    /**
     * 消费数组结束符。
     *
     * 跳过空白后消费 ]，不压入或弹出语义容器状态，也不自动计算生成代码深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 缺少预期分隔符或输入结束，错误码为 parse_error。
     */
    public func endRawArray(): Unit {
        skipSpaces()
        expectByte(b']')
    }

    func tryEndRawArrayCompact(): Bool {
        if (hasMore() && peek() == b']') {
            index++
            return true
        }
        false
    }

    /**
     * 检查游标是否仍可能有元素。
     *
     * 跳过空白后只判断是否到达输入末尾或 ]，不消费逗号，也不校验后续值。当前实现不使用 first。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 保留的首项状态参数；该实现不依此参数分支。
     * @return 仍有字节且当前字节不是 ] 时为 true。
     */
    public func hasRawArrayItem(first: Bool): Bool {
        skipSpaces()
        let _ = first
        hasMore() && peek() != b']'
    }

    /**
     * 按首项状态检查数组是否还有下一项。
     *
     * 跳过空白；首项判断当前字节是否不是 ]，后续项判断是否为逗号。结果不代表后续内容已通过语法校验，逗号仍由后续读取消费。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否还未消费该容器的第一项。
     * @return 当前位置符合对应首项或逗号条件时为 true。
     */
    public func hasRawArrayItemFast(first: Bool): Bool {
        if (!hasMore()) { return false }
        var current = data[index]
        if (isJsonSpace(current)) {
            skipSpaces()
            if (!hasMore()) { return false }
            current = data[index]
        }
        if (first) {
            current != b']'
        } else {
            current == b','
        }
    }

    func nextRawArrayItem(first: Bool): Bool {
        if (first) {
            if (hasMore()) {
                let current = peek()
                if (current == b']') {
                    return false
                }
                if (!isJsonSpace(current)) {
                    return true
                }
            }
        } else if (hasMore() && peek() == b',') {
            index++
            if (hasMore() && !isJsonSpace(peek())) {
                return true
            }
            skipSpaces()
            return true
        }
        skipSpaces()
        if (hasMore() && peek() == b']') {
            return false
        }
        if (!first) {
            expectByte(b',')
            skipSpaces()
        }
        true
    }

    func tryNextRawArrayItemCompact(first: Bool): Bool {
        if (!hasMore()) {
            return false
        }
        let current = peek()
        if (current == b' ' || current == b'\n' || current == b'\r' || current == b'\t' || current == b']') {
            return false
        }
        if (first) {
            return true
        }
        if (current != b',') {
            return false
        }
        index++
        true
    }

    /**
     * 消费数组元素之前的空白和必要逗号。
     *
     * 首项只跳过空白，后续项还必须消费逗号。不读取元素值，不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前数组的首元素。
     * @throws JsonException 非首项之前缺少逗号或输入结束，错误码为 parse_error。
     */
    public func beforeRawArrayItem(first: Bool): Unit {
        skipSpaces()
        if (!first) {
            expectByte(b',')
            skipSpaces()
        }
    }

    /**
     * 消费数组元素之前的空白和必要逗号。
     *
     * 首项只跳过空白，后续项还必须消费逗号。不读取元素值，不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为当前数组的首元素。
     * @throws JsonException 非首项之前缺少逗号或输入结束，错误码为 parse_error。
     */
    public func beforeRawArrayItemFast(first: Bool): Unit {
        if (!first) {
            // hasRawArrayItemFast has already checked the comma.  Consume it
            // after the same whitespace normalization used by the semantic
            // path so generated readers accept all valid JSON formatting.
            skipSpaces()
            expectByte(b',')
        }
        skipSpaces()
    }

    /**
     * 尝试消费当前位置的 null 字面量。
     *
     * 先跳过空白；下一非空白字节不是 n 时返回 false。以 n 开头时匹配 null 的各个字符，不额外检查 token 后的分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 已消费 null 时为 true，起始字节不匹配时为 false。
     * @throws JsonException 以 n 开头但不完整匹配 null，错误码为 parse_error。
     */
    public func tryReadRawNull(): Bool {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        if (!hasMore() || peek() != b'n') {
            return false
        }
        expectLiteral("null")
        true
    }

    /**
     * 消费一个布尔字面量。
     *
     * 跳过空白后读取 true 或 false。匹配字面量字符，不额外检查后续分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 字面量对应的布尔值。
     * @throws JsonException 不能读出 true 或 false，错误码为 parse_error。
     */
    public func readRawBool(): Bool {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        readRawBoolCompact()
    }

    /**
     * 消费一个布尔字面量。
     *
     * 跳过空白后读取 true 或 false。快速分支检查字面量后的分隔符；不匹配时回退到 readRawBool。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 字面量对应的布尔值。
     * @throws JsonException 不能读出 true 或 false，错误码为 parse_error。
     */
    public func readRawBoolFast(): Bool {
        let original = index
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        if (index + 4 <= size && data[index] == b't' &&
            data[index + 1] == b'r' && data[index + 2] == b'u' &&
            data[index + 3] == b'e' &&
            (index + 4 == size || isJsonValueDelimiter(data[index + 4]))) {
            index += 4
            return true
        }
        if (index + 5 <= size && data[index] == b'f' &&
            data[index + 1] == b'a' && data[index + 2] == b'l' &&
            data[index + 3] == b's' && data[index + 4] == b'e' &&
            (index + 5 == size || isJsonValueDelimiter(data[index + 5]))) {
            index += 5
            return false
        }
        index = original
        readRawBool()
    }

    func readRawBoolCompact(): Bool {
        if (peek() == b't') {
            expectLiteral("true")
            return true
        }
        expectLiteral("false")
        false
    }

    /**
     * 消费 JSON 字符串并解码转义。
     *
     * 跳过前导空白，按字符串输入模式处理 UTF-8；不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解码后的字符串。
     * @throws JsonException 字符串未闭合、转义或编码无效，或字符串预算超限。
     */
    public func readRawString(): String {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        readRawStringCompact()
    }

    // Generated compact codecs normally receive strings emitted by the
    // matching writer.  Scan the common unescaped ASCII form directly and
    // retain the checked parser for escaped or non-ASCII input.
    /**
     * 消费字符串，未转义内容使用直接扫描。
     *
     * 遇到转义、控制字符或未闭合内容时回退到 readRawString。未转义直接分支不执行字符串或值的字节预算检查；非 ASCII 内容仍交给相应 UTF-8 转换路径。此入口供匹配版本生成代码调用，不能替代完整字符串校验契约。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取并构造的字符串。
     * @throws JsonException 检查或回退路径发现字符串语法、编码或预算错误。
     */
    public func readRawStringFast(): String {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        let quoteStart = index
        if (!hasMore() || data[index] != b'"') {
            return readRawString()
        }
        index++
        let start = index
        var ascii = true
        while (index < size) {
            let current = data[index]
            if (current == b'"') {
                let end = index
                index++
                if (ascii) {
                    return asciiStringFromRange(start, end)
                }
                return stringFromUtf8Range(start, end)
            }
            if (current == b'\\') {
                index = quoteStart
                return readRawString()
            }
            if (current < 0x20) {
                index = quoteStart
                return readRawString()
            }
            if (current >= 0x80) {
                ascii = false
            }
            index++
        }
        index = quoteStart
        readRawString()
    }

    func readRawStringCompact(): String {
        parseString()
    }

    func tryReadRawAsciiStringToken(): Bool {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        tryReadRawAsciiStringTokenCompact()
    }

    func tryReadRawAsciiStringTokenSize2(firstSize: Int64, secondSize: Int64): Bool {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        tryReadRawAsciiStringTokenSize2Compact(firstSize, secondSize)
    }

    func tryReadRawAsciiStringTokenCompact(): Bool {
        let start = index
        if (!hasMore() || peek() != b'"') {
            return false
        }
        index++
        rawTokenStart = index
        while (index < size) {
            let current = data[index]
            if (current == b'"') {
                rawTokenEnd = index
                index++
                return true
            }
            if (current == b'\\' || current >= 0x80) {
                index = start
                return false
            }
            if (current < 0x20) {
                failAt("Unescaped control character in string literal", index)
            }
            index++
        }
        fail("Unterminated string literal")
    }

    func tryReadRawAsciiStringTokenSize2Compact(firstSize: Int64, secondSize: Int64): Bool {
        let start = index
        if (!hasMore() || peek() != b'"') {
            return false
        }
        let valueStart = index + 1
        var valueEnd: Int64 = -1
        if (valueStart + firstSize < size && data[valueStart + firstSize] == b'"') {
            valueEnd = valueStart + firstSize
        } else if (valueStart + secondSize < size && data[valueStart + secondSize] == b'"') {
            valueEnd = valueStart + secondSize
        } else {
            return false
        }

        var cursor = valueStart
        while (cursor < valueEnd) {
            let current = data[cursor]
            if (current == b'\\' || current >= 0x80) {
                index = start
                return false
            }
            if (current < 0x20) {
                failAt("Unescaped control character in string literal", cursor)
            }
            cursor++
        }
        rawTokenStart = valueStart
        rawTokenEnd = valueEnd
        index = valueEnd + 1
        true
    }

    /**
     * 校验并跳过一个 JSON 字符串。
     *
     * 跳过前导空白后扫描，不返回解码结果。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 字符串语法、编码或资源预算校验失败。
     */
    public func skipRawString(): Unit {
        skipSpaces()
        scanRawString()
    }

    /**
     * 消费一个 Int64 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Int64。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawInt64(): Int64 {
        parseInt64Literal()
    }

    /**
     * 消费生成代码整数路径中的 Int64 值。
     *
     * 先尝试直接累积数字，不适用时回退到 readRawInt64。直接分支不拒绝前导零，不能作为对任意外部数字文本的完整语法验证。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int64 值。
     * @throws JsonException 回退检查路径发现语法、类型或范围错误。
     */
    public func readRawInt64Fast(): Int64 {
        let original = index
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        if (!hasMore()) {
            index = original
            return readRawInt64()
        }
        var negative = false
        if (data[index] == b'-') {
            negative = true
            index++
        }
        if (!hasMore() || data[index] < b'0' || data[index] > b'9') {
            index = original
            return readRawInt64()
        }
        var magnitude = 0u64
        while (index < size) {
            let current = data[index]
            if (current < b'0' || current > b'9') {
                break
            }
            let digit = UInt64(current - b'0')
            if (magnitude > (UInt64.Max - digit) / 10u64) {
                index = original
                return readRawInt64()
            }
            magnitude = magnitude * 10u64 + digit
            index++
        }
        if (index < size && !isJsonValueDelimiter(data[index])) {
            index = original
            return readRawInt64()
        }
        if (negative) {
            if (magnitude > 9223372036854775808u64) {
                index = original
                return readRawInt64()
            }
            if (magnitude == 9223372036854775808u64) {
                return Int64.Min
            }
            return -Int64(magnitude)
        }
        if (magnitude > UInt64(Int64.Max)) {
            index = original
            return readRawInt64()
        }
        Int64(magnitude)
    }

    private func readRawInt64MapChecked(): HashMap<String, Int64> {
        startRawObject()
        let result = HashMap<String, Int64>(suggestRawObjectCapacity())
        var first = true
        while (hasRawObjectField(first)) {
            result[readRawName(first)] = readRawInt64()
            first = false
        }
        endRawObject()
        result
    }

    private func readRawInt64ArrayMapChecked(): HashMap<String, Array<Int64>> {
        startRawObject()
        let result = HashMap<String, Array<Int64>>(suggestRawObjectCapacity())
        var first = true
        while (hasRawObjectField(first)) {
            result[readRawName(first)] = readRawInt64ArrayChecked()
            first = false
        }
        endRawObject()
        result
    }

    private func readRawInt64ArrayChecked(): Array<Int64> {
        startRawArray()
        if (!hasRawArrayItem(true)) {
            endRawArray()
            return Array<Int64>()
        }
        let result = ArrayList<Int64>(suggestRawArrayCapacity())
        var first = true
        while (hasRawArrayItem(first)) {
            beforeRawArrayItem(first)
            result.add(readRawInt64())
            first = false
        }
        endRawArray()
        result.toArray()
    }

    // The generated writer emits compact object/array syntax.  Parse that
    // shape in one cursor loop and leave all other valid JSON spellings to the
    // checked readers below.  This is a syntax-based fast path: it does not
    // depend on field names, values, or benchmark data.
    private func tryReadRawInt64MapCompactBody(): Option<HashMap<String, Int64>> {
        if (!hasMore() || isJsonSpace(peek())) {
            return None<HashMap<String, Int64>>
        }
        let result = HashMap<String, Int64>(suggestRawObjectCapacity())
        if (peek() == b'}') {
            index++
            return Some(result)
        }
        if (peek() != b'"') {
            return None<HashMap<String, Int64>>
        }
        while (true) {
            index++
            let start = index
            var asciiName = true
            while (index < size) {
                let byte = data[index]
                if (byte == b'"') { break }
                if (byte == b'\\' || byte < 0x20) {
                    return None<HashMap<String, Int64>>
                }
                if (byte >= 0x80) { asciiName = false }
                index++
            }
            if (index >= size || data[index] != b'"') {
                return None<HashMap<String, Int64>>
            }
            let end = index
            index++
            if (index >= size || data[index] != b':') {
                return None<HashMap<String, Int64>>
            }
            index++
            let name = if (asciiName) {
                asciiStringFromRange(start, end)
            } else {
                stringFromUtf8Range(start, end)
            }
            result[name] = readRawInt64Fast()
            if (!hasMore()) {
                return None<HashMap<String, Int64>>
            }
            if (peek() == b'}') {
                index++
                return Some(result)
            }
            if (peek() != b',') {
                return None<HashMap<String, Int64>>
            }
            index++
            if (!hasMore() || peek() != b'"') {
                return None<HashMap<String, Int64>>
            }
        }
        None<HashMap<String, Int64>>
    }

    private func tryReadRawInt64ArrayCompactBody(): Option<Array<Int64>> {
        if (!hasMore() || isJsonSpace(peek())) {
            return None<Array<Int64>>
        }
        if (peek() == b']') {
            index++
            return Some(Array<Int64>())
        }
        let result = ArrayList<Int64>(suggestRawArrayCapacity())
        while (true) {
            if (!hasMore() || isJsonSpace(peek())) {
                return None<Array<Int64>>
            }
            result.add(readRawInt64Fast())
            if (!hasMore()) {
                return None<Array<Int64>>
            }
            if (peek() == b']') {
                index++
                return Some(result.toArray())
            }
            if (peek() != b',') {
                return None<Array<Int64>>
            }
            index++
        }
        None<Array<Int64>>
    }

    /**
     * 消费一个字符串到 Int64 的对象。
     *
     * 重名字段后值覆盖前值。构造新集合，但不自行进入或退出生成代码深度状态；调用方负责相关语义上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新构造的字符串到 Int64 的对象集合。
     * @throws JsonException 容器语法、成员类型或整数范围不符。
     */
    public func readRawInt64MapFast(): HashMap<String, Int64> {
        let original = index
        startRawObject()
        if (let Some(result) <- tryReadRawInt64MapCompactBody()) {
            return result
        }
        index = original
        readRawInt64MapChecked()
    }

    /**
     * 消费一个Int64 数组。
     *
     * 可使用已安装的 Native 整数数组路径；否则尝试紧凑路径并回退到通用数组读取。构造新集合，但不自行进入或退出生成代码深度状态；调用方负责相关语义上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新构造的Int64 数组集合。
     * @throws JsonException 容器语法、成员类型或整数范围不符。
     */
    public func readRawInt64ArrayFast(): Array<Int64> {
        if (let Some(result) <- tryReadNativeInt64ArrayList()) {
            return result.toArray()
        }
        let original = index
        startRawArray()
        if (let Some(result) <- tryReadRawInt64ArrayCompactBody()) {
            return result
        }
        index = original
        readRawInt64ArrayChecked()
    }

    private func tryReadRawInt64ArrayMapCompactBody(): Option<HashMap<String, Array<Int64>>> {
        if (!hasMore() || isJsonSpace(peek())) {
            return None<HashMap<String, Array<Int64>>>
        }
        let result = HashMap<String, Array<Int64>>(suggestRawObjectCapacity())
        if (peek() == b'}') {
            index++
            return Some(result)
        }
        if (peek() != b'"') {
            return None<HashMap<String, Array<Int64>>>
        }
        while (true) {
            index++
            let start = index
            var asciiName = true
            while (index < size) {
                let byte = data[index]
                if (byte == b'"') { break }
                if (byte == b'\\' || byte < 0x20) {
                    return None<HashMap<String, Array<Int64>>>
                }
                if (byte >= 0x80) { asciiName = false }
                index++
            }
            if (index >= size || data[index] != b'"') {
                return None<HashMap<String, Array<Int64>>>
            }
            let end = index
            index++
            if (index >= size || data[index] != b':') {
                return None<HashMap<String, Array<Int64>>>
            }
            index++
            let name = if (asciiName) {
                asciiStringFromRange(start, end)
            } else {
                stringFromUtf8Range(start, end)
            }
            if (!hasMore() || peek() != b'[') {
                return None<HashMap<String, Array<Int64>>>
            }
            index++
            let items = ArrayList<Int64>(suggestRawArrayCapacity())
            if (!hasMore() || isJsonSpace(peek())) {
                return None<HashMap<String, Array<Int64>>>
            }
            if (peek() == b']') {
                index++
            } else {
                while (true) {
                    items.add(readRawInt64Fast())
                    if (!hasMore()) {
                        return None<HashMap<String, Array<Int64>>>
                    }
                    if (peek() == b']') {
                        index++
                        break
                    }
                    if (peek() != b',') {
                        return None<HashMap<String, Array<Int64>>>
                    }
                    index++
                    if (!hasMore() || isJsonSpace(peek())) {
                        return None<HashMap<String, Array<Int64>>>
                    }
                }
            }
            result[name] = items.toArray()
            if (!hasMore()) {
                return None<HashMap<String, Array<Int64>>>
            }
            if (peek() == b'}') {
                index++
                return Some(result)
            }
            if (peek() != b',') {
                return None<HashMap<String, Array<Int64>>>
            }
            index++
            if (!hasMore() || peek() != b'"') {
                return None<HashMap<String, Array<Int64>>>
            }
        }
        None<HashMap<String, Array<Int64>>>
    }

    /**
     * 消费一个字符串到 Int64 数组的对象。
     *
     * 重名字段后值覆盖前值。构造新集合，但不自行进入或退出生成代码深度状态；调用方负责相关语义上下文。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新构造的字符串到 Int64 数组的对象集合。
     * @throws JsonException 容器语法、成员类型或整数范围不符。
     */
    public func readRawInt64ArrayMapFast(): HashMap<String, Array<Int64>> {
        let original = index
        startRawObject()
        if (let Some(result) <- tryReadRawInt64ArrayMapCompactBody()) {
            return result
        }
        index = original
        readRawInt64ArrayMapChecked()
    }

    /**
     * 消费生成代码整数路径中的 UInt64 值。
     *
     * 先尝试直接累积数字，不适用时回退到 readRawUInt64。直接分支不拒绝前导零，不能作为对任意外部数字文本的完整语法验证。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt64 值。
     * @throws JsonException 回退检查路径发现语法、类型或范围错误。
     */
    public func readRawUInt64Fast(): UInt64 {
        let original = index
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        if (!hasMore() || data[index] < b'0' || data[index] > b'9') {
            index = original
            return readRawUInt64()
        }
        var result = 0u64
        while (index < size) {
            let current = data[index]
            if (current < b'0' || current > b'9') {
                break
            }
            let digit = UInt64(current - b'0')
            if (result > (UInt64.Max - digit) / 10u64) {
                index = original
                return readRawUInt64()
            }
            result = result * 10u64 + digit
            index++
        }
        if (index < size && !isJsonValueDelimiter(data[index])) {
            index = original
            return readRawUInt64()
        }
        result
    }

    /**
     * 消费生成代码快速路径中的浮点数字内容。
     *
     * 无指数时用 Float64 逐位累积整数和小数；指数路径回退到 Float64.parse。手工分支不完整检查数字语法或尾随分隔符，也不保证等同于核心 Float64.parse 的舍入结果。生成代码通用浮点桥接使用 jsonFastReadFloat64。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 累积或解析得到的 Float64；此处不限制结果必须有限。
     * @throws JsonException 回退路径发现 JSON 数字语法错误。
     * @throws Exception 回退数值解析失败，或输入不足导致底层数组读取失败。
     */
    public func readRawFloat64Fast(): Float64 {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        let start = index
        var negative = false
        if (data[index] == b'-') {
            negative = true
            index++
        }
        var result: Float64 = 0.0
        var digits = false
        while (index < size) {
            let current = data[index]
            if (current < b'0' || current > b'9') {
                break
            }
            result = result * 10.0 + Float64(current - b'0')
            index++
            digits = true
        }
        if (hasMore() && data[index] == b'.') {
            index++
            var scale: Float64 = 0.1
            while (index < size) {
                let current = data[index]
                if (current < b'0' || current > b'9') {
                    break
                }
                result += Float64(current - b'0') * scale
                scale *= 0.1
                index++
                digits = true
            }
        }
        if (!digits || (hasMore() && (data[index] == b'e' || data[index] == b'E'))) {
            index = start
            return Float64.parse(readRawNumberLiteral())
        }
        if (negative) { -result } else { result }
    }

    /**
     * 消费一个 Int32 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Int32。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawInt32(): Int32 {
        let value = parseInt64Literal()
        int64ToInt32(value)
    }

    private func int64ToInt32(value: Int64): Int32 {
        if (value < -0x8000_0000 || value > 0x7FFF_FFFF) {
            failWithCode("Integer literal out of Int32 range", "number_out_of_range")
        }
        Int32(value)
    }

    /**
     * 消费一个 Int16 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Int16。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawInt16(): Int16 {
        let value = parseInt64Literal()
        int64ToInt16(value)
    }

    private func int64ToInt16(value: Int64): Int16 {
        if (value < -0x8000 || value > 0x7FFF) {
            failWithCode("Integer literal out of Int16 range", "number_out_of_range")
        }
        Int16(value)
    }

    /**
     * 消费一个 Int8 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Int8。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawInt8(): Int8 {
        let value = parseInt64Literal()
        int64ToInt8(value)
    }

    private func int64ToInt8(value: Int64): Int8 {
        if (value < -0x80 || value > 0x7F) {
            failWithCode("Integer literal out of Int8 range", "number_out_of_range")
        }
        Int8(value)
    }

    /**
     * 消费一个 UInt64 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。无符号类型拒绝负号。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 UInt64。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawUInt64(): UInt64 {
        parseUInt64Literal()
    }

    /**
     * 消费一个 UInt32 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。无符号类型拒绝负号。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 UInt32。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawUInt32(): UInt32 {
        let value = parseUInt64Literal()
        uint64ToUInt32(value)
    }

    private func uint64ToUInt32(value: UInt64): UInt32 {
        if (value > 0xFFFF_FFFFu64) {
            failWithCode("Integer literal out of UInt32 range", "number_out_of_range")
        }
        UInt32(value)
    }

    /**
     * 消费一个 UInt16 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。无符号类型拒绝负号。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 UInt16。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawUInt16(): UInt16 {
        let value = parseUInt64Literal()
        uint64ToUInt16(value)
    }

    private func uint64ToUInt16(value: UInt64): UInt16 {
        if (value > 0xFFFFu64) {
            failWithCode("Integer literal out of UInt16 range", "number_out_of_range")
        }
        UInt16(value)
    }

    /**
     * 消费一个 UInt8 范围内的 JSON 整数。
     *
     * 跳过空白；拒绝前导零、小数及指数形式。无符号类型拒绝负号。不更新生成代码路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 UInt8。
     * @throws JsonException 整数语法无效、小数或指数不适用（invalid_value），或超过目标范围（number_out_of_range）。
     */
    public func readRawUInt8(): UInt8 {
        let value = parseUInt64Literal()
        uint64ToUInt8(value)
    }

    private func uint64ToUInt8(value: UInt64): UInt8 {
        if (value > 0xFFu64) {
            failWithCode("Integer literal out of UInt8 range", "number_out_of_range")
        }
        UInt8(value)
    }

    /**
     * 消费数字文本并调用 BigInt.parse。
     *
     * 直接传播标准库数值解析异常，不使用将其包装为 invalid_value 的类型化桥接。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 BigInt 值。
     * @throws JsonException JSON 数字语法或数字字节预算校验失败。
     * @throws Exception 标准库 BigInt.parse 解析失败。
     */
    public func readRawBigInt(): BigInt {
        BigInt.parse(readRawNumberLiteral())
    }

    /**
     * 消费数字文本并调用 Decimal.parse。
     *
     * 直接传播标准库数值解析异常，不使用将其包装为 invalid_value 的类型化桥接。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Decimal 值。
     * @throws JsonException JSON 数字语法或数字字节预算校验失败。
     * @throws Exception 标准库 Decimal.parse 解析失败。
     */
    public func readRawDecimal(): Decimal {
        Decimal.parse(readRawNumberLiteral())
    }

    /**
     * 消费一个 JSON 数字并保留文本。
     *
     * 按数字语法读取整数、小数和指数部分；不检查其后的容器分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 已消费数字 token 的 ASCII 文本。
     * @throws JsonException JSON 数字语法不符或数字字节预算超限。
     */
    public func readRawNumberLiteral(): String {
        parseNumberLiteral()
    }

    func tryReadRawNumberToken(): Bool {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        tryReadRawNumberTokenCompact()
    }

    func tryReadRawNumberTokenCompact(): Bool {
        if (!hasMore() || !(peek() == b'-' || (peek() >= b'0' && peek() <= b'9'))) {
            return false
        }
        rawTokenStart = index
        scanRawNumberToken()
        rawTokenEnd = index
        true
    }

    func adoptRawNumberToken(start: Int64, end: Int64, magnitude: UInt64, flags: UInt64): Unit {
        rawTokenStart = start
        rawTokenEnd = end
        index = end
        rawTokenNumberNegative = (flags & 1u64) != 0u64
        rawTokenNumberHasExponent = (flags & 2u64) != 0u64
        rawTokenNumberSmallUnscaledValid = (flags & 4u64) != 0u64 && magnitude <= UInt64(Int64.Max)
        rawTokenNumberSmallUnscaled = if (rawTokenNumberSmallUnscaledValid) { Int64(magnitude) } else { 0 }
        rawTokenNumberScale = Int64((flags >> 8) & 0xFFFF_FFFFu64)
        rawTokenNumberDigitCount = 0
        rawTokenNumberHasNonZero = magnitude != 0u64
    }

    private func resetRawNumberTokenShape(): Unit {
        rawTokenNumberDigitCount = 0
        rawTokenNumberScale = 0
        rawTokenNumberSmallUnscaled = 0
        rawTokenNumberSmallUnscaledValid = true
        rawTokenNumberNegative = false
        rawTokenNumberHasExponent = false
        rawTokenNumberHasNonZero = false
    }

    private func recordRawNumberTokenDigit(digit: Int64): Unit {
        rawTokenNumberDigitCount++
        if (digit != 0) {
            rawTokenNumberHasNonZero = true
        }
        if (rawTokenNumberSmallUnscaledValid && rawTokenNumberDigitCount <= YJSON_RAW_NUMBER_SMALL_DIGITS) {
            rawTokenNumberSmallUnscaled = rawTokenNumberSmallUnscaled * 10 + digit
        } else {
            rawTokenNumberSmallUnscaledValid = false
        }
    }

    private func scanRawNumberTokenDigitsAfterRequiredFirst(): Unit {
        while (hasMore() && peek() >= b'0' && peek() <= b'9') {
            recordRawNumberTokenDigit(Int64(consume() - b'0'))
        }
    }

    private func scanRawNumberTokenIntegerDigits(): Unit {
        requireDigit("Expected digit")
        if (peek() == b'0') {
            index++
            recordRawNumberTokenDigit(0)
            rejectLeadingZero()
            return
        }
        scanRawNumberTokenDigitsAfterRequiredFirst()
    }

    private func scanRawNumberToken(): Unit {
        resetRawNumberTokenShape()
        if (hasMore() && peek() == b'-') {
            rawTokenNumberNegative = true
            index++
        }
        scanRawNumberTokenIntegerDigits()
        if (hasMore() && peek() == b'.') {
            index++
            requireDigit("Expected fractional digits")
            while (hasMore() && peek() >= b'0' && peek() <= b'9') {
                recordRawNumberTokenDigit(Int64(consume() - b'0'))
                rawTokenNumberScale++
            }
        }
        if (hasMore() && (peek() == b'e' || peek() == b'E')) {
            rawTokenNumberHasExponent = true
            index++
            if (hasMore() && (peek() == b'+' || peek() == b'-')) {
                index++
            }
            requireDigit("Expected exponent digits")
            consumeDigits()
        }
    }

    func currentRawTokenSize(): Int64 {
        rawTokenEnd - rawTokenStart
    }

    func currentRawTokenData(): Array<Byte> {
        data
    }

    func currentRawTokenStartOffset(): Int64 {
        rawTokenStart
    }

    func currentRawTokenByte(offset: Int64): Byte {
        data[rawTokenStart + offset]
    }

    func currentRawTokenDigit(offset: Int64): Int64 {
        let value = data[rawTokenStart + offset]
        if (value < b'0' || value > b'9') {
            return -1
        }
        Int64(value - b'0')
    }

    func currentRawTokenTwoDigits(offset: Int64): Int64 {
        let first = currentRawTokenDigit(offset)
        let second = currentRawTokenDigit(offset + 1)
        if (first < 0 || second < 0) {
            return -1
        }
        first * 10 + second
    }

    func currentRawTokenFourDigits(offset: Int64): Int64 {
        let first = currentRawTokenTwoDigits(offset)
        let second = currentRawTokenTwoDigits(offset + 2)
        if (first < 0 || second < 0) {
            return -1
        }
        first * 100 + second
    }

    func currentRawTokenAsciiString(): String {
        asciiStringFromRange(rawTokenStart, rawTokenEnd)
    }

    func currentRawDateTimeCache(epochSecond: Int64, offsetSeconds: Int64): Option<DateTime> {
        match (rawDateTimeCacheValue) {
            case Some(value) =>
                if (rawDateTimeCacheEpochSecond == epochSecond &&
                    rawDateTimeCacheOffsetSeconds == offsetSeconds) {
                    return Some(value)
                }
                None<DateTime>
            case None => None<DateTime>
        }
    }

    func setRawDateTimeCache(epochSecond: Int64, offsetSeconds: Int64, value: DateTime): Unit {
        rawDateTimeCacheEpochSecond = epochSecond
        rawDateTimeCacheOffsetSeconds = offsetSeconds
        rawDateTimeCacheValue = Some(value)
    }

    func currentRawTokenNumberDigitCount(): Int64 {
        rawTokenNumberDigitCount
    }

    func currentRawTokenNumberScale(): Int64 {
        rawTokenNumberScale
    }

    func currentRawTokenNumberSmallUnscaled(): Int64 {
        rawTokenNumberSmallUnscaled
    }

    func currentRawTokenNumberSmallUnscaledValid(): Bool {
        rawTokenNumberSmallUnscaledValid
    }

    func currentRawTokenNumberNegative(): Bool {
        rawTokenNumberNegative
    }

    func currentRawTokenNumberHasExponent(): Bool {
        rawTokenNumberHasExponent
    }

    func currentRawTokenNumberHasNonZero(): Bool {
        rawTokenNumberHasNonZero
    }

    /**
     * 按语法扫描并跳过一个完整值。
     *
     * 不设置额外容器深度上限；符合条件时可使用 Native 跳过原语。不执行跳过对象内的重复键策略。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 值语法、字符串或字节预算校验失败。
     */
    public func skipRaw(): Unit {
        skipRawValueBounded(0, -1)
    }

    /**
     * 在相对容器深度预算内按语法跳过一个值。
     *
     * 标量不消耗深度；不执行跳过对象中的重复键策略。有界路径不使用 Native 的无深度跳过原语。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxDepth 相对当前生成代码上下文的剩余容器层数；0 只允许标量，不能为负。
     * @throws IllegalArgumentException maxDepth 为负。
     * @throws JsonException 值语法或预算无效，或容器深度超限（max_depth）。
     */
    public func skipRawWithDepth(maxDepth: Int64): Unit {
        if (maxDepth < 0) { throw IllegalArgumentException("maxDepth must not be negative") }
        skipRawValueBounded(0, maxDepth)
    }

    /**
     * 按读取策略和深度预算跳过未知字段的值。
     *
     * 拒绝重复键时按解码后的名称逐层检查（duplicate_key）；不使用只扫描语法的 Native 跳过路径。标量不消耗容器深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxDepth 相对当前生成代码上下文的剩余容器层数；0 只允许标量，不能为负。
     * @throws IllegalArgumentException maxDepth 为负。
     * @throws JsonException 值语法、预算、深度（max_depth）或重复键策略（duplicate_key）校验失败。
     */
    public func skipValue(maxDepth: Int64): Unit {
        if (maxDepth < 0) { throw IllegalArgumentException("maxDepth must not be negative") }
        skipRawValuePolicyAware(0, maxDepth)
    }

    private func beforeRawFieldName(first: Bool): Unit {
        skipSpaces()
        if (!first) {
            expectByte(b',')
            skipSpaces()
        }
    }

    private func afterRawFieldName(): Unit {
        if (hasMore() && peek() == b':') {
            index++
            return
        }
        skipSpaces()
        expectByte(b':')
    }

    private func skipRawValueBounded(depth: Int64, maxDepth: Int64): Unit {
        if (!hasMore()) {
            fail("Unexpected end of input")
        }
        if (isJsonSpace(peek())) {
            skipSpaces()
        }
        if (!hasMore()) {
            fail("Unexpected end of input")
        }
        let current = peek()
        if (maxDepth < 0 && shouldUseNativeSkip(current)) {
            let nativeEnd = jsonNativeSkipValue(data, size, index, validateStrings)
            if (nativeEnd >= 0) {
                let skippedStart = index
                index = nativeEnd
                enforceValueByteBudget(skippedStart, nativeEnd)
                return
            }
        }
        let valueStart = index
        match {
            case current == b'n' => expectLiteral("null")
            case current == b't' => expectLiteral("true")
            case current == b'f' => expectLiteral("false")
            case current == b'"' =>
                scanRawString()
            case current == b'[' => skipRawArrayBounded(depth, maxDepth)
            case current == b'{' => skipRawObjectBounded(depth, maxDepth)
            case current == b'-' || (current >= b'0' && current <= b'9') =>
                skipRawNumber()
            case _ => fail("Unexpected token")
        }
        enforceValueByteBudget(valueStart, index)
    }

    private func shouldUseNativeSkip(current: Byte): Bool {
        (current == b'{' || current == b'[') && size - index >= YJSON_NATIVE_SKIP_MIN_REMAINING_BYTES
    }

    private func skipRawArrayBounded(depth: Int64, maxDepth: Int64): Unit {
        if (maxDepth >= 0 && depth >= maxDepth) {
            throw JsonException("Maximum JSON depth exceeded", code: "max_depth",
                location: Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
                    jsonColumnFromUtf8Bytes(data, index))))
        }
        expectByte(b'[')
        skipSpaces()
        if (hasMore() && peek() == b']') {
            index++
            return
        }
        while (true) {
            skipRawValueBounded(depth + 1, maxDepth)
            skipSpaces()
            if (hasMore() && peek() == b']') {
                index++
                return
            }
            expectByte(b',')
        }
    }

    private func skipRawObjectBounded(depth: Int64, maxDepth: Int64): Unit {
        if (maxDepth >= 0 && depth >= maxDepth) {
            throw JsonException("Maximum JSON depth exceeded", code: "max_depth",
                location: Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
                    jsonColumnFromUtf8Bytes(data, index))))
        }
        expectByte(b'{')
        skipSpaces()
        if (hasMore() && peek() == b'}') {
            index++
            return
        }
        while (true) {
            scanRawString()
            skipSpaces()
            expectByte(b':')
            skipRawValueBounded(depth + 1, maxDepth)
            skipSpaces()
            if (hasMore() && peek() == b'}') {
                index++
                return
            }
            expectByte(b',')
        }
    }

    private func skipRawValuePolicyAware(depth: Int64, maxDepth: Int64): Unit {
        if (!hasMore()) {
            fail("Unexpected end of input")
        }
        if (isJsonSpace(peek())) {
            skipSpaces()
        }
        if (!hasMore()) {
            fail("Unexpected end of input")
        }
        let current = peek()
        let valueStart = index
        match {
            case current == b'n' => expectLiteral("null")
            case current == b't' => expectLiteral("true")
            case current == b'f' => expectLiteral("false")
            case current == b'"' =>
                scanRawString()
            case current == b'[' => skipRawArrayPolicyAware(depth, maxDepth)
            case current == b'{' => skipRawObjectPolicyAware(depth, maxDepth)
            case current == b'-' || (current >= b'0' && current <= b'9') =>
                skipRawNumber()
            case _ => fail("Unexpected token")
        }
        enforceValueByteBudget(valueStart, index)
    }

    private func skipRawArrayPolicyAware(depth: Int64, maxDepth: Int64): Unit {
        if (maxDepth >= 0 && depth >= maxDepth) {
            throw JsonException("Maximum JSON depth exceeded", code: "max_depth",
                location: Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
                    jsonColumnFromUtf8Bytes(data, index))))
        }
        expectByte(b'[')
        skipSpaces()
        if (hasMore() && peek() == b']') {
            index++
            return
        }
        while (true) {
            skipRawValuePolicyAware(depth + 1, maxDepth)
            skipSpaces()
            if (hasMore() && peek() == b']') {
                index++
                return
            }
            expectByte(b',')
        }
    }

    private func skipRawObjectPolicyAware(depth: Int64, maxDepth: Int64): Unit {
        if (maxDepth >= 0 && depth >= maxDepth) {
            throw JsonException("Maximum JSON depth exceeded", code: "max_depth",
                location: Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
                    jsonColumnFromUtf8Bytes(data, index))))
        }
        expectByte(b'{')
        skipSpaces()
        if (hasMore() && peek() == b'}') {
            index++
            return
        }
        let seenBase = if (jsonReadOptionsRejectsDuplicateKeys(config)) {
            skipSeenCount
        } else {
            -1
        }
        while (true) {
            let name = parseString()
            if (seenBase >= 0) {
                var duplicate = false
                for (position in seenBase..skipSeenCount) {
                    if (skipSeenNames[position] == name) { duplicate = true; break }
                }
                if (duplicate) { policyFail("Duplicate object key '${name}'") }
                ensureSkipSeenCapacity()
                skipSeenNames[skipSeenCount] = name
                skipSeenCount++
            }
            skipSpaces()
            expectByte(b':')
            skipRawValuePolicyAware(depth + 1, maxDepth)
            skipSpaces()
            if (hasMore() && peek() == b'}') {
                index++
                if (seenBase >= 0) { skipSeenCount = seenBase }
                return
            }
            expectByte(b',')
        }
    }

    private func skipRawNumber(): Unit {
        if (hasMore() && peek() == b'-') {
            index++
        }
        consumeIntegerDigits()
        if (hasMore() && peek() == b'.') {
            index++
            requireDigit("Expected fractional digits")
            consumeDigits()
        }
        if (hasMore() && (peek() == b'e' || peek() == b'E')) {
            index++
            if (hasMore() && (peek() == b'+' || peek() == b'-')) {
                index++
            }
            requireDigit("Expected exponent digits")
            consumeDigits()
        }
    }

    private func parseNumberLiteral(): String {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        parseNumberLiteralNoSpace()
    }

    private func parseNumberLiteralNoSpace(): String {
        let start = index
        if (hasMore() && peek() == b'-') {
            index++
        }
        consumeIntegerDigits()
        if (hasMore() && peek() == b'.') {
            index++
            requireDigit("Expected fractional digits")
            consumeDigits()
        }
        if (hasMore() && (peek() == b'e' || peek() == b'E')) {
            index++
            if (hasMore() && (peek() == b'+' || peek() == b'-')) {
                index++
            }
            requireDigit("Expected exponent digits")
            consumeDigits()
        }
        enforceValueByteBudget(start, index)
        asciiStringFromRange(start, index)
    }

    private func parseInt64Literal(): Int64 {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        parseInt64LiteralNoSpace()
    }

    private func parseInt64LiteralNoSpace(): Int64 {
        if (!hasMore()) {
            fail("Expected integer")
        }
        if (peek() == b'-') {
            index++
            requireDigit("Expected digit")
            var result: Int64 = 0
            if (peek() == b'0') {
                index++
                rejectLeadingZero()
            } else {
                while (index < size && data[index] >= b'0' && data[index] <= b'9') {
                    let digit = Int64(data[index] - b'0')
                    index++
                    if (result < ((-0x8000_0000_0000_0000 + digit) / 10)) {
                        failWithCode("Integer literal out of Int64 range", "number_out_of_range")
                    }
                    result = result * 10 - digit
                }
            }
            rejectFractionalOrExponentForInteger()
            return result
        }
        requireDigit("Expected digit")
        var result: Int64 = 0
        if (peek() == b'0') {
            index++
            rejectLeadingZero()
        } else {
            while (index < size && data[index] >= b'0' && data[index] <= b'9') {
                let digit = Int64(data[index] - b'0')
                index++
                if (result > ((0x7FFF_FFFF_FFFF_FFFF - digit) / 10)) {
                    failWithCode("Integer literal out of Int64 range", "number_out_of_range")
                }
                result = result * 10 + digit
            }
        }
        rejectFractionalOrExponentForInteger()
        result
    }

    private func parseUInt64Literal(): UInt64 {
        if (!hasMore() || isJsonSpace(peek())) {
            skipSpaces()
        }
        parseUInt64LiteralNoSpace()
    }

    private func parseUInt64LiteralNoSpace(): UInt64 {
        if (!hasMore() || peek() == b'-') {
            fail("Expected unsigned integer")
        }
        requireDigit("Expected digit")
        var result: UInt64 = 0
        if (peek() == b'0') {
            index++
            rejectLeadingZero()
        } else {
            while (index < size && data[index] >= b'0' && data[index] <= b'9') {
                let digit = UInt64(data[index] - b'0')
                index++
                if (result > ((UInt64.Max - digit) / 10)) {
                    failWithCode("Integer literal out of UInt64 range", "number_out_of_range")
                }
                result = result * 10 + digit
            }
        }
        rejectFractionalOrExponentForInteger()
        result
    }

    private func rejectFractionalOrExponentForInteger(): Unit {
        if (hasMore() && (peek() == b'.' || peek() == b'e' || peek() == b'E')) {
            failWithCode("Expected integer", "invalid_value")
        }
    }

    private func consumeDigits(): Unit {
        requireDigit("Expected digit")
        while (index < size && data[index] >= b'0' && data[index] <= b'9') {
            index++
        }
    }

    private func consumeIntegerDigits(): Unit {
        requireDigit("Expected digit")
        if (peek() == b'0') {
            index++
            rejectLeadingZero()
            return
        }
        consumeDigits()
    }

    private func rejectLeadingZero(): Unit {
        if (hasMore() && peek() >= b'0' && peek() <= b'9') {
            fail("Leading zeroes are not allowed in JSON numbers")
        }
    }

    private func requireDigit(message: String): Unit {
        if (!hasMore() || peek() < b'0' || peek() > b'9') {
            fail(message)
        }
    }

    private func parseString(): String {
        expectByte(b'"')
        let start = index
        var decodedBytes: Int64 = 0
        while (index < size) {
            let current = data[index]
            if (current == b'"') {
                let end = index
                index++
                enforceDecodedStringBytes(start, decodedBytes)
                if (validateStrings) {
                    // Raw UTF-8 has already been validated by the loop.
                    return unsafe { String.fromUtf8Unchecked(data[start..end]) }
                }
                return stringFromUtf8Range(start, end)
            }
            if (current == b'\\') {
                return parseEscapedString(start)
            }
            if (current < 0x20) {
                failAt("Unescaped control character in string literal", index)
            }
            if (validateStrings && current >= 0x80) {
                let next = validateRawUtf8At(index)
                decodedBytes = enforceDecodedStringBytesIncrement(start, decodedBytes, next - index)
                index = next
                continue
            }
            decodedBytes++
            index++
        }
        fail("Unterminated string literal")
    }

    private func parseEscapedString(start: Int64): String {
        let quoteStart = start - 1
        if (!validateStrings) {
            return decodeEscapedStringToUtf8(start)
        } else {
            if (size - quoteStart >= YJSON_NATIVE_MIN_READER_DECODE_BYTES) {
                if (let Some(decoded) <- jsonNativeDecodeString(data, size, quoteStart, validateStrings)) {
                    enforceDecodedStringBytes(quoteStart, decoded.value.size)
                    index = decoded.end
                    return decoded.value
                }
            }
        }
        // The scalar decoder either returns a complete semantic string or
        // throws a normalized parse error. There is no third fallback state.
        decodeEscapedStringToUtf8(start)
    }

    private func decodeEscapedStringToUtf8(start: Int64): String {
        let output = Array<Byte>(escapedStringContentSize(start), repeat: 0)
        var read = start
        var segmentStart = start
        var written: Int64 = 0
        var decodedBytes: Int64 = 0
        while (read < size) {
            let current = data[read]
            if (current == b'"') {
                enforceDecodedStringBytes(start, decodedBytes)
                written = copyEscapedStringSegment(output, segmentStart, read, written)
                index = read + 1
                return unsafe { String.fromUtf8Unchecked(output[0..written]) }
            }
            if (current == b'\\') {
                written = copyEscapedStringSegment(output, segmentStart, read, written)
                read++
                if (read >= size) {
                    fail("Unexpected end of escape sequence")
                }
                let escaped = data[read]
                read++
                match (escaped) {
                    case b'"' => output[written] = b'"'
                    case b'\\' => output[written] = b'\\'
                    case b'/' => output[written] = b'/'
                    case b'b' => output[written] = b'\b'
                    case b'f' => output[written] = b'\f'
                    case b'n' => output[written] = b'\n'
                    case b'r' => output[written] = b'\r'
                    case b't' => output[written] = b'\t'
                    case b'u' =>
                        let escapeStart = read - 2
                        var value = unicodeEscapeValueAt(read, escapeStart)
                        read += 4
                        if (isJsonHighSurrogate(value)) {
                            if (read + 2 > size || data[read] != b'\\' || data[read + 1] != b'u') {
                                failAt("Invalid unicode surrogate pair", escapeStart)
                            }
                            read += 2
                            let low = unicodeEscapeValueAt(read, read)
                            if (!isJsonLowSurrogate(low)) {
                                failAt("Invalid unicode surrogate pair", escapeStart)
                            }
                            read += 4
                            value = Int64(combineJsonSurrogates(value, low))
                        } else if (isJsonLowSurrogate(value)) {
                            failAt("Invalid unicode surrogate pair", escapeStart)
                        }
                        written = appendUtf8CodePoint(output, written, value)
                        decodedBytes = enforceDecodedStringBytesIncrement(start, decodedBytes,
                            jsonUtf8ByteCount(value))
                        segmentStart = read
                        continue
                    case _ => failAt("Unsupported escape sequence", read - 2)
                }
                written++
                decodedBytes++
                segmentStart = read
                continue
            }
            if (current < 0x20) {
                failAt("Unescaped control character in string literal", read)
            }
            if (validateStrings && current >= 0x80) {
                let next = validateRawUtf8At(read)
                decodedBytes = enforceDecodedStringBytesIncrement(start, decodedBytes, next - read)
                read = next
                continue
            }
            read++
            decodedBytes++
        }
        fail("Unterminated string literal")
    }

    private func escapedStringContentSize(start: Int64): Int64 {
        var cursor = start
        while (cursor < size) {
            match (data[cursor]) {
                case b'"' => return cursor - start
                case b'\\' =>
                    cursor++
                    if (cursor >= size) {
                        fail("Unexpected end of escape sequence")
                    }
                    cursor++
                case _ => cursor++
            }
        }
        fail("Unterminated string literal")
    }

    private func validateRawUtf8At(start: Int64): Int64 {
        let first = data[start]
        if (first < 0xC2 || first > 0xF4) {
            failAt("Invalid UTF-8 byte sequence", start)
        }
        if (first < 0xE0) {
            requireUtf8Continuation(start, start + 1)
            return start + 2
        }
        if (first < 0xF0) {
            let second = requireUtf8Continuation(start, start + 1)
            if ((first == 0xE0 && second < 0xA0) || (first == 0xED && second >= 0xA0)) {
                failAt("Invalid UTF-8 byte sequence", start)
            }
            requireUtf8Continuation(start, start + 2)
            return start + 3
        }
        let second = requireUtf8Continuation(start, start + 1)
        if ((first == 0xF0 && second < 0x90) || (first == 0xF4 && second > 0x8F)) {
            failAt("Invalid UTF-8 byte sequence", start)
        }
        requireUtf8Continuation(start, start + 2)
        requireUtf8Continuation(start, start + 3)
        start + 4
    }

    private func requireUtf8Continuation(start: Int64, offset: Int64): Byte {
        if (offset >= size) {
            failAt("Invalid UTF-8 byte sequence", start)
        }
        let value = data[offset]
        if ((UInt8(value) & 0xC0u8) != 0x80u8) {
            failAt("Invalid UTF-8 byte sequence", start)
        }
        value
    }

    private func copyEscapedStringSegment(
        output: Array<Byte>,
        segmentStart: Int64,
        segmentEnd: Int64,
        written: Int64
    ): Int64 {
        let segmentSize = segmentEnd - segmentStart
        if (segmentSize <= 0) {
            return written
        }
        data.copyTo(output, segmentStart, written, segmentSize)
        written + segmentSize
    }

    private func appendUtf8CodePoint(output: Array<Byte>, written: Int64, code: Int64): Int64 {
        var cursor = written
        if (code <= 0x7F) {
            output[cursor] = UInt8(code)
            return cursor + 1
        }
        if (code <= 0x7FF) {
            output[cursor] = UInt8(0xC0 + code / 64)
            output[cursor + 1] = UInt8(0x80 + code % 64)
            return cursor + 2
        }
        if (code <= 0xFFFF) {
            output[cursor] = UInt8(0xE0 + code / 4096)
            output[cursor + 1] = UInt8(0x80 + (code / 64) % 64)
            output[cursor + 2] = UInt8(0x80 + code % 64)
            return cursor + 3
        }
        output[cursor] = UInt8(0xF0 + code / 262144)
        output[cursor + 1] = UInt8(0x80 + (code / 4096) % 64)
        output[cursor + 2] = UInt8(0x80 + (code / 64) % 64)
        output[cursor + 3] = UInt8(0x80 + code % 64)
        cursor + 4
    }

    private func unicodeEscapeValueAt(start: Int64, errorStart: Int64): Int64 {
        if (start + 4 > size) {
            failAt("Incomplete unicode escape", errorStart)
        }
        var value: Int64 = 0
        for (offset in 0..4) {
            value = value * 16 + hexValue(data[start + offset])
        }
        value
    }

    private func scanRawString(): Unit {
        if (size - index >= 64) {
            let nativeEnd = jsonNativeScanString(data, size, index, validateStrings)
            if (nativeEnd >= 0) {
                index = nativeEnd
                return
            }
        }
        expectByte(b'"')
        while (hasMore()) {
            let currentStart = index
            let current = consume()
            match (current) {
                case b'"' => return
                case b'\\' => skipEscapedStringItem(currentStart)
                case _ =>
                    if (current < 0x20) {
                        failAt("Unescaped control character in string literal", currentStart)
                    }
                    if (validateStrings && current >= 0x80) {
                        let _ = decodeUtf8Rune(current, currentStart)
                    }
            }
        }
        fail("Unterminated string literal")
    }

    private func skipEscapedStringItem(start: Int64): Unit {
        if (index >= size) {
            fail("Unexpected end of escape sequence")
        }
        let escaped = data[index]
        index++
        match (escaped) {
            case b'"' | b'\\' | b'/' | b'b' | b'f' | b'n' | b'r' | b't' => return
            case b'u' =>
                skipUnicodeEscape(start)
                return
            case _ => failAt("Unsupported escape sequence", start)
        }
    }

    private func skipUnicodeEscape(start: Int64): Unit {
        let value = parseUnicodeEscapeValueAtCurrent(start)
        if (isJsonHighSurrogate(value)) {
            if (index + 2 > size || data[index] != b'\\' || data[index + 1] != b'u') {
                failAt("Invalid unicode surrogate pair", start)
            }
            index += 2
            let low = parseUnicodeEscapeValueAtCurrent(start)
            if (!isJsonLowSurrogate(low)) {
                failAt("Invalid unicode surrogate pair", start)
            }
            return
        }
        if (isJsonLowSurrogate(value)) {
            failAt("Invalid unicode surrogate pair", start)
        }
    }

    private func stringFromUtf8Range(start: Int64, end: Int64): String {
        if (!validateStrings) {
            if (let Some(text) <- sourceText) {
                return text[start..end]
            }
            return unsafe {
                String.fromUtf8Unchecked(data[start..end])
            }
        }
        return try {
            String.fromUtf8(data[start..end])
        } catch (_: Exception) {
            failAt("Invalid UTF-8 byte sequence", start)
        }
    }

    // Validate one source-owned UTF-8 sequence in the key scanner itself, so
    // non-ASCII no-escape keys still require only one byte traversal.
    private func validatedUtf8WidthAt(start: Int64): Int64 {
        let first = UInt8(data[start])
        if (first >= 0xC2u8 && first <= 0xDFu8) {
            requireUtf8Continuation(start + 1, size, 0x80u8, 0xBFu8, start)
            return 2
        }
        if (first >= 0xE0u8 && first <= 0xEFu8) {
            let secondMin = if (first == 0xE0u8) { 0xA0u8 } else { 0x80u8 }
            let secondMax = if (first == 0xEDu8) { 0x9Fu8 } else { 0xBFu8 }
            requireUtf8Continuation(start + 1, size, secondMin, secondMax, start)
            requireUtf8Continuation(start + 2, size, 0x80u8, 0xBFu8, start)
            return 3
        }
        if (first >= 0xF0u8 && first <= 0xF4u8) {
            let secondMin = if (first == 0xF0u8) { 0x90u8 } else { 0x80u8 }
            let secondMax = if (first == 0xF4u8) { 0x8Fu8 } else { 0xBFu8 }
            requireUtf8Continuation(start + 1, size, secondMin, secondMax, start)
            requireUtf8Continuation(start + 2, size, 0x80u8, 0xBFu8, start)
            requireUtf8Continuation(start + 3, size, 0x80u8, 0xBFu8, start)
            return 4
        }
        failAt("Invalid UTF-8 byte sequence", start)
    }

    private func requireUtf8Continuation(position: Int64, end: Int64, minimum: UInt8,
        maximum: UInt8, errorPosition: Int64): Unit {
        if (position >= end) { failAt("Invalid UTF-8 byte sequence", errorPosition) }
        let value = UInt8(data[position])
        if (value < minimum || value > maximum) {
            failAt("Invalid UTF-8 byte sequence", errorPosition)
        }
    }

    private func asciiStringFromRange(start: Int64, end: Int64): String {
        unsafe {
            String.fromUtf8Unchecked(data[start..end])
        }
    }

    private func parseNameIdBytes(candidates: Array<Array<Byte>>): Int64 {
        if (candidates.size > 63 || !allCandidateBytesAscii(candidates)) {
            let name = parseString()
            for (candidateIndex in 0..candidates.size) {
                if (String.fromUtf8(candidates[candidateIndex]) == name) {
                    return candidateIndex
                }
            }
            return -1
        }
        expectByte(b'"')
        var active = initialNameMatchMask(candidates.size)
        var nameIndex: Int64 = 0
        while (index < size) {
            let current = data[index]
            index++
            if (current == b'"') {
                if (active == 0u64) {
                    return -1
                }
                for (candidateIndex in 0..candidates.size) {
                    if (((active & nameMatchBit(candidateIndex)) != 0u64) && candidates[candidateIndex].size == nameIndex) {
                        return candidateIndex
                    }
                }
                return -1
            }
            var code: Int64 = -1
            if (current == b'\\') {
                code = consumeEscapedAsciiForName()
            } else if (current < 0x80) {
                if (current < 0x20) {
                    failAt("Unescaped control character in string literal", index - 1)
                }
                code = Int64(current)
            } else if (validateStrings) {
                index += validatedUtf8WidthAt(index - 1) - 1
            }
            if (active != 0u64) {
                active = updateActiveNameByteCandidates(candidates, active, nameIndex, code)
            }
            nameIndex++
        }
        fail("Unterminated string literal")
    }

    private func tryParseSimpleNameId(candidates: Array<Array<Byte>>): Option<Int64> {
        let quotePosition = index
        expectByte(b'"')
        let nameStart = index
        while (index < size) {
            let current = data[index]
            if (current == b'"') {
                let nameEnd = index
                index++
                return Some(rawNameId(candidates, nameStart, nameEnd))
            }
            if (current == b'\\') {
                index = quotePosition
                return None<Int64>
            }
            if (current < 0x20) {
                failAt("Unescaped control character in string literal", index)
            }
            if (current >= 0x80) {
                index = quotePosition
                return None<Int64>
            }
            index++
        }
        fail("Unterminated string literal")
    }

    private func rawNameId(candidates: Array<Array<Byte>>, nameStart: Int64, nameEnd: Int64): Int64 {
        let nameSize = nameEnd - nameStart
        if (nameSize <= 0) {
            return -1
        }
        let first = data[nameStart]
        for (candidateIndex in 0..candidates.size) {
            let candidate = candidates[candidateIndex]
            if (candidate.size != nameSize || candidate[0] != first) {
                continue
            }
            var matched = true
            for (offset in 1..nameSize) {
                if (data[nameStart + offset] != candidate[offset]) {
                    matched = false
                    break
                }
            }
            if (matched) {
                return candidateIndex
            }
        }
        -1
    }

    private func allCandidateBytesAscii(candidates: Array<Array<Byte>>): Bool {
        for (candidate in candidates) {
            for (byte in candidate) {
                if (byte >= 0x80) {
                    return false
                }
            }
        }
        true
    }

    private func initialNameMatchMask(size: Int64): UInt64 {
        var mask = 0u64
        for (candidateIndex in 0..size) {
            mask |= nameMatchBit(candidateIndex)
        }
        mask
    }

    private func nameMatchBit(candidateIndex: Int64): UInt64 {
        1u64 << candidateIndex
    }

    private func updateActiveNameByteCandidates(
        candidates: Array<Array<Byte>>,
        active: UInt64,
        nameIndex: Int64,
        code: Int64
    ): UInt64 {
        if (code < 0 || code > 0x7F) {
            return 0u64
        }
        var next = 0u64
        let byte = UInt8(code)
        for (candidateIndex in 0..candidates.size) {
            let bit = nameMatchBit(candidateIndex)
            if ((active & bit) == 0u64) {
                continue
            }
            let candidate = candidates[candidateIndex]
            if (nameIndex < candidate.size && candidate[nameIndex] == byte) {
                next |= bit
            }
        }
        next
    }

    private func consumeEscapedAsciiForName(): Int64 {
        if (index >= size) {
            fail("Unexpected end of escape sequence")
        }
        let escaped = data[index]
        index++
        match (escaped) {
            case b'"' => return Int64(b'"')
            case b'\\' => return Int64(b'\\')
            case b'/' => return Int64(b'/')
            case b'b' => return Int64(b'\b')
            case b'f' => return Int64(b'\f')
            case b'n' => return Int64(b'\n')
            case b'r' => return Int64(b'\r')
            case b't' => return Int64(b'\t')
            case b'u' =>
                let r = parseUnicodeEscape()
                let code = UInt32(r)
                return if (code <= 0x7Fu32) {
                    Int64(code)
                } else {
                    -1
                }
            case _ => fail("Unsupported escape sequence")
        }
    }

    private func parseUnicodeEscape(): Rune {
        let start = index
        let value = parseUnicodeEscapeValue(start)
        if (isJsonHighSurrogate(value)) {
            if (index >= size || data[index] != b'\\') {
                failAt("Invalid unicode surrogate pair", start)
            }
            index++
            if (index >= size || data[index] != b'u') {
                failAt("Invalid unicode surrogate pair", start)
            }
            index++
            let lowStart = index
            let low = parseUnicodeEscapeValue(lowStart)
            if (!isJsonLowSurrogate(low)) {
                failAt("Invalid unicode surrogate pair", start)
            }
            return try {
                Rune(combineJsonSurrogates(value, low))
            } catch (_: Exception) {
                failAt("Invalid unicode escape", start)
            }
        }
        if (isJsonLowSurrogate(value)) {
            failAt("Invalid unicode surrogate pair", start)
        }
        return try {
            Rune(UInt32(value))
        } catch (_: Exception) {
            failAt("Invalid unicode escape", start)
        }
    }

    private func parseUnicodeEscapeValue(start: Int64): Int64 {
        parseUnicodeEscapeValueAtCurrent(start)
    }

    private func parseUnicodeEscapeValueAtCurrent(start: Int64): Int64 {
        let value = unicodeEscapeValueAt(index, start)
        index += 4
        value
    }

    private func hexValue(value: Byte): Int64 {
        match {
            case value >= b'0' && value <= b'9' => Int64(value - b'0')
            case value >= b'a' && value <= b'f' => Int64(value - b'a') + 10
            case value >= b'A' && value <= b'F' => Int64(value - b'A') + 10
            case _ => fail("Invalid unicode escape")
        }
    }

    private func decodeUtf8Rune(first: Byte, start: Int64): Rune {
        let width = utf8Width(first, start)
        let bytes = Array<UInt8>(width, repeat: 0u8)
        bytes[0] = UInt8(first)
        for (offset in 1..width) {
            if (!hasMore()) {
                failAt("Invalid UTF-8 byte sequence", start)
            }
            bytes[offset] = UInt8(consume())
        }
        return try {
            let (r, _) = Rune.fromUtf8(bytes, 0)
            r
        } catch (_: Exception) {
            failAt("Invalid UTF-8 byte sequence", start)
        }
    }

    private func utf8Width(first: Byte, start: Int64): Int64 {
        let unsigned = UInt8(first)
        if ((unsigned & 0xE0u8) == 0xC0u8) {
            return 2
        }
        if ((unsigned & 0xF0u8) == 0xE0u8) {
            return 3
        }
        if ((unsigned & 0xF8u8) == 0xF0u8) {
            return 4
        }
        failAt("Invalid UTF-8 byte sequence", start)
    }

    private func skipSpaces(): Unit {
        while (index < size) {
            if (isJsonSpace(data[index])) {
                index++
            } else {
                return
            }
        }
    }

    private func isJsonSpace(value: Byte): Bool {
        value == b' ' || value == b'\n' || value == b'\r' || value == b'\t'
    }

    private func isJsonValueDelimiter(value: Byte): Bool {
        isJsonSpace(value) || value == b',' || value == b']' || value == b'}'
    }

    private func suggestContainerCapacity(bytesPerEntry: Int64): Int64 {
        let remaining = size - index
        if (remaining <= bytesPerEntry) {
            return 4
        }
        let estimate = remaining / bytesPerEntry + 1
        match {
            case estimate < 4 => 4
            case estimate > 64 => 64
            case _ => estimate
        }
    }

    private func expectLiteral(literal: String): Unit {
        match (literal) {
            case "null" =>
                expectByte(b'n')
                expectByte(b'u')
                expectByte(b'l')
                expectByte(b'l')
                return
            case "true" =>
                expectByte(b't')
                expectByte(b'r')
                expectByte(b'u')
                expectByte(b'e')
                return
            case "false" =>
                expectByte(b'f')
                expectByte(b'a')
                expectByte(b'l')
                expectByte(b's')
                expectByte(b'e')
                return
            case _ => ()
        }
        for (byte in unsafe { literal.rawData() }) {
            if (!hasMore() || consume() != byte) {
                fail("Expected ${literal}")
            }
        }
    }

    private func expectByte(value: Byte): Unit {
        if (index >= size || data[index] != value) {
            fail("Unexpected token")
        }
        index++
    }

    private func hasMore(): Bool {
        index < size
    }

    private func peek(): Byte {
        data[index]
    }

    private func consume(): Byte {
        let value = data[index]
        index++
        value
    }

    private func fail(message: String): Nothing {
        failAt(message, index)
    }

    private func failWithCode(message: String, code: String): Nothing {
        throw JsonException(
            "${message} at byte ${index}",
            code: code,
            location: Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
                jsonColumnFromUtf8Bytes(data, index)))
        )
    }

    private func enforceValueByteBudget(valueStart: Int64, valueEnd: Int64): Unit {
        let limit = config.maxBufferedValueBytes
        if (limit > 0 && valueEnd - valueStart > limit) {
            throw jsonResourceLimitException(data,
                "JSON value exceeds ${limit} bytes",
                "buffered_value_too_large", valueStart + limit)
        }
    }

    private func enforceDecodedStringBytes(start: Int64, decodedBytes: Int64): Unit {
        let limit = config.maxStringBytes
        if (limit > 0 && decodedBytes > limit) {
            throw jsonResourceLimitException(data,
                "JSON string exceeds ${limit} decoded UTF-8 bytes",
                "string_too_large", start + limit)
        }
    }

    private func enforceDecodedStringBytesIncrement(start: Int64, decodedBytes: Int64,
        added: Int64): Int64 {
        let next = decodedBytes + added
        enforceDecodedStringBytes(start, next)
        next
    }

    private func policyFail(message: String): Nothing {
        throw JsonException(
            message,
            code: "duplicate_key",
            location: Some(JsonLocation(index, jsonLineFromUtf8Bytes(data, index),
                jsonColumnFromUtf8Bytes(data, index))))
    }

    private func failAt(message: String, offset: Int64): Nothing {
        throw JsonException(
            "${message} at byte ${offset}",
            code: "parse_error",
            location: Some(JsonLocation(offset, jsonLineFromUtf8Bytes(data, offset),
                jsonColumnFromUtf8Bytes(data, offset)))
        )
    }
}
