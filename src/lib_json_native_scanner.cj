package yjson

import std.collection.*

const YJ_JSON_SCAN_OK: Int32 = 0
const YJ_JSON_SCAN_FALLBACK: Int32 = 1
const YJ_JSON_SCAN_CAPACITY: Int32 = 2
const YJ_JSON_SCAN_VALIDATE_STRINGS = 1u32
const YJSON_NATIVE_FLOAT_MAX_TOKEN_BYTES: Int64 = 256

const YJSON_NATIVE_MIN_SKIP_BYTES = 32
const YJSON_NATIVE_MIN_OBJECT_SCAN_BYTES = 1024
const YJSON_NATIVE_MIN_ARRAY_SCAN_BYTES = 240
const YJSON_NATIVE_MIN_DECODE_BYTES = 16
const YJSON_NATIVE_MIN_READER_DECODE_BYTES = 256
const YJSON_NATIVE_MIN_WRITER_ESCAPE_BYTES = 4096
const YJSON_NATIVE_MIN_WRITER_INT64_COUNT = 256
const YJSON_NATIVE_MIN_WRITER_FLOAT64_COUNT = 32
const YJSON_NATIVE_MIN_ARRAY_ELEMENT_COUNT = 16

// Cross-package seam used by the optional native package. The core package has
// no foreign declarations and continues to work when no backend is installed.
/**
 * 定义第一方 Native 结构及字符串扫描原语。
 *
 * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。状态码 0 为成功、1 为回退、2 为容量不足、-1 为失败；各原语只使用适用状态。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativeScannerBackend {
    /**
     * 查询已链接原生扫描器的能力位。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 能力位掩码；当前第一方实现位 0 表示基础能力，位 1 表示 AVX2。
     */
    func simdCaps(): UInt32
    /**
     * 从指定位置扫描一个完整 JSON 值。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param outEnd 成功时写入值后第一个字节的偏移。
     * @param outError 成功时为 -1；失败或回退时写入诊断偏移。
     * @return 扫描状态码：0 成功、1 要求回退、-1 失败。
     */
    func skipValue(input: CPointer<UInt8>, len: Int64, start: Int64, flags: UInt32, outEnd: CPointer<Int64>, outError: CPointer<Int64>): Int32
    /**
     * 扫描对象并记录直接字段的名称和值区间。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。每字段占五个 UInt64：名称起点、名称字节长度、名称哈希、值起点和值终点；字段名需走原语支持的未转义路径。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param fields 字段输出区，每字段五个 UInt64；可传空指针仅扫描。
     * @param fieldCap 最多容纳的字段数，不是 UInt64 数量。
     * @param outEnd 成功时写入对象结束后的输入偏移。
     * @param outError 成功时为字段数（空对象为 -1）；容量不足时为至少需要的字段数；其他状态为诊断偏移。
     * @return 0 成功、1 回退、2 字段容量不足、-1 失败。
     */
    func scanObjectFields(input: CPointer<UInt8>, len: Int64, start: Int64, flags: UInt32, fields: CPointer<UInt64>, fieldCap: Int64, outEnd: CPointer<Int64>, outError: CPointer<Int64>): Int32
    /**
     * 扫描数组并记录直接元素的值区间。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。每元素占两个 UInt64：值起点和值终点。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param elements 元素输出区，每元素两个 UInt64；可传空指针仅扫描。
     * @param elementCap 最多容纳的元素数，不是 UInt64 数量。
     * @param outEnd 成功时写入数组结束后的输入偏移。
     * @param outError 成功时为元素数（空数组为 -1）；容量不足时为至少需要的元素数；其他状态为诊断偏移。
     * @return 0 成功、1 回退、2 元素容量不足、-1 失败。
     */
    func scanArrayElements(input: CPointer<UInt8>, len: Int64, start: Int64, flags: UInt32, elements: CPointer<UInt64>, elementCap: Int64, outEnd: CPointer<Int64>, outError: CPointer<Int64>): Int32
    /**
     * 扫描一个带引号的 JSON 字符串 token。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param outEnd 成功时写入结束引号后的偏移。
     * @param outError 成功时为 -1；失败或回退时写入诊断偏移。
     * @return 扫描状态码：0 成功、1 要求回退、-1 失败。
     */
    func scanString(input: CPointer<UInt8>, len: Int64, start: Int64, flags: UInt32, outEnd: CPointer<Int64>, outError: CPointer<Int64>): Int32
    /**
     * 解码一个 JSON 字符串到调用方缓冲区。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。输出不含引号，也不追加终止字节。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param output 接收解码后 UTF-8 字节的缓冲区。
     * @param outputCap 输出区字节容量。
     * @param outEnd 成功时写入结束引号后的输入偏移。
     * @param outWritten 成功时写入已输出的 UTF-8 字节数。
     * @param outError 成功时为 -1；容量不足时为所需容量提示，失败时为诊断偏移。
     * @return 0 成功、1 回退、2 容量不足、-1 失败；非成功输出不能当作完整字符串。
     */
    func decodeString(input: CPointer<UInt8>, len: Int64, start: Int64, flags: UInt32, output: CPointer<UInt8>, outputCap: Int64, outEnd: CPointer<Int64>, outWritten: CPointer<Int64>, outError: CPointer<Int64>): Int32
}

// Separate additive seam for bulk numeric scanning. Keeping it independent
// avoids changing third-party implementations of the established scanner
// backend while allowing one FFI call to return many validated number tokens.
/**
 * 定义数字数组分块扫描及 Int64 数组转换原语。
 *
 * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。每个数字记录占四个 UInt64：起点、终点、小整数幅值、标志。位 0 表示负号、位 1 表示指数、位 2 表示小整数幅值有效，位 8 至 39 保存小数位数。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativeNumericScannerBackend {
    /**
     * 扫描数字数组的一个可续接片段。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。每个数字记录占四个 UInt64：起点、终点、小整数幅值、标志。位 0 表示负号、位 1 表示指数、位 2 表示小整数幅值有效，位 8 至 39 保存小数位数。调用方已消费数组开始符；返回位置越过已消费数字后面的逗号和空白。遇到非数字值时保留已完成记录并返回回退状态；形似数字但语法错误时失败。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 下一个数字或数组结束符的输入偏移，不指向数组开始符。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param tokens 调用方持有的四字记录输出区。
     * @param tokenCap 数字记录容量，必须为正；缓冲区至少包含四倍数量的 UInt64。
     * @param outNext 可继续扫描的位置；回退时指向未消费的非数字值。
     * @param outCount 成功或回退时已提交的记录数。
     * @param outDone 只有消费数组结束符时为 1，否则为 0。
     * @param outError 成功或回退时为 -1，失败时为诊断偏移。
     * @return 0 表示完成本块，1 表示须回退读取非数字值，-1 表示失败；缓冲区满可作为成功分块返回。
     */
    func scanNumericArrayChunk(input: CPointer<UInt8>, len: Int64, start: Int64,
        flags: UInt32, tokens: CPointer<UInt64>, tokenCap: Int64,
        outNext: CPointer<Int64>, outCount: CPointer<Int64>, outDone: CPointer<Int64>,
        outError: CPointer<Int64>): Int32
    /**
     * 校验并转换一个完整 Int64 JSON 数组。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。只有整个数组成功时 outEnd 和 outCount 才可用；回退或失败时可能已写入部分整数。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param values 接收连续 Int64 元素的输出区。
     * @param valueCap 输出区可容纳的 Int64 元素数。
     * @param outEnd 成功时写入数组结束后的输入偏移。
     * @param outCount 成功时写入解析出的元素数。
     * @param outError 成功时为 -1；容量不足时为至少需要的元素数，回退或失败时为诊断偏移。
     * @return 0 成功，1 表示语法或数值形态须回退处理，2 容量不足，-1 参数失败。
     */
    func parseInt64Array(input: CPointer<UInt8>, len: Int64, start: Int64,
        values: CPointer<Int64>, valueCap: Int64, outEnd: CPointer<Int64>,
        outCount: CPointer<Int64>, outError: CPointer<Int64>): Int32
}

/**
 * 定义有界输入页中的数字 token 预扫描原语。
 *
 * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。只提供数字位置和形状信息，不校验完整 JSON 结构，也不构造 DOM。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativeNumericTapeBackend {
    /**
     * 在一个输入页内预扫描数字 token。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。每个数字记录占四个 UInt64：起点、终点、小整数幅值、标志。位 0 表示负号、位 1 表示指数、位 2 表示小整数幅值有效，位 8 至 39 保存小数位数。扫描跳过带引号字符串，页边界截断的 token 留待后续处理；JSON 语法及 DOM 构造仍由调用方负责。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 从输入首地址起算的扫描起始偏移。
     * @param pageBytes 从 start 起最多扫描的字节窗口，必须为正。
     * @param flags 扫描标志；位 0 要求校验字符串 UTF-8。
     * @param tokens 调用方可复用的四字数字记录区。
     * @param tokenCap 最多写入的记录数，必须为正。
     * @param outNext 本页或记录区停止时的位置，可能指向未扫描完整的 token。
     * @param outCount 成功时写入的记录数。
     * @param outError 成功时为 -1，参数无效时为诊断偏移。
     * @return 0 表示本页扫描完成或停止，-1 表示参数失败；成功不代表整份 JSON 语法有效。
     */
    func scanNumericTape(input: CPointer<UInt8>, len: Int64, start: Int64, pageBytes: Int64,
        flags: UInt32, tokens: CPointer<UInt64>, tokenCap: Int64,
        outNext: CPointer<Int64>, outCount: CPointer<Int64>, outError: CPointer<Int64>): Int32
}

/**
 * 定义已验证数字 token 的可选 Float64 转换原语。
 *
 * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。NaN 表示拒绝 token，调用方须转用核心 Float64 解析。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativeFloatParserBackend {
    /**
     * 尝试转换一个已验证的 JSON 数字 token。
     *
     * 所有指针只在本次调用期间借用，不保留或释放调用方存储；输入区间及输出容量由调用方保证有效。扫描不维护 codec 路径、对象策略或生成代码深度。输入须已通过 JSON 数字语法校验。NaN 是请求调用方使用语义解析器的信号。当前第一方实现还拒绝超过 16 字节的 token。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间有效的输入字节首地址。
     * @param len 输入区间总字节数。
     * @param start 数字 token 的输入起点。
     * @param tokenLength 数字 token 的字节长度。
     * @return 转换得到的 Float64，或表示拒绝 token 的 NaN；调用方处理非有限结果及语义回退。
     */
    func parseFloat64(input: CPointer<UInt8>, len: Int64, start: Int64, tokenLength: Int64): Float64
}

/**
 * 定义无状态的原生字符串转义和数字写出原语。
 *
 * 指针只在调用期间借用。调用方管理分隔符、路径、单根状态和资源预算；这些原语只生成单个 token 或紧凑数组。失败或容量不足时输出可能已部分写入。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativeWriterBackend {
    /**
     * 将 UTF-8 字符串转义为完整 JSON 字符串 token。
     *
     * 输入是已接受的字符串字节，不含引号；输出包含双引号，不追加终止字节。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param input 调用期间借用的字符串 UTF-8 字节地址。
     * @param len 输入字节数。
     * @param htmlSafe 是否额外转义小于号、大于号、与号、等号和单引号。
     * @param output 接收带引号 token 的输出区。
     * @param outputCap 输出区字节容量。
     * @param outWritten 仅成功时写入完整 token 的字节数。
     * @return 0 成功、2 容量不足、-1 参数失败；非成功输出不能当作完整 token。
     */
    func escapeString(input: CPointer<UInt8>, len: Int64, htmlSafe: Bool,
        output: CPointer<UInt8>, outputCap: Int64, outWritten: CPointer<Int64>): Int32
    /**
     * 将连续 Int64 值写为紧凑 JSON 数组。
     *
     * 输出包含方括号和逗号，不追加终止字节。存储由调用方持有。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param values 调用期间借用的连续 Int64 元素地址。
     * @param count 输入元素个数，不能为负。
     * @param output 接收数组文本的输出区首地址。
     * @param outputCap 整个输出区的字节容量。
     * @param outputOffset 从输出区首地址起算的写入偏移。
     * @param outWritten 成功时写入本次数组文本的字节数，不含 outputOffset。
     * @return 0 成功、2 容量不足、-1 参数失败。
     */
    func formatInt64Array(values: CPointer<Int64>, count: Int64,
        output: CPointer<UInt8>, outputCap: Int64, outputOffset: Int64,
        outWritten: CPointer<Int64>): Int32
    /**
     * 将连续 Float64 值写为紧凑 JSON 数组。
     *
     * 输出包含方括号和逗号，不追加终止字节。NaN 或无穷大使原语失败。存储由调用方持有。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param values 调用期间借用的连续 Float64 元素地址。
     * @param count 输入元素个数，不能为负。
     * @param output 接收数组文本的输出区首地址。
     * @param outputCap 整个输出区的字节容量。
     * @param outputOffset 从输出区首地址起算的写入偏移。
     * @param outWritten 成功时写入本次数组文本的字节数，不含 outputOffset。
     * @return 0 成功、2 容量不足、-1 参数失败或遇到非有限浮点数。
     */
    func formatFloat64Array(values: CPointer<Float64>, count: Int64,
        output: CPointer<UInt8>, outputCap: Int64, outputOffset: Int64,
        outWritten: CPointer<Int64>): Int32
    /**
     * 将一个有限 Float64 写入指定输出位置。
     *
     * 不写分隔符或终止字节；当前原语要求偏移后至少有 40 字节容量。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @param value 待格式化的有限 Float64。
     * @param output 调用期间借用的输出区首地址。
     * @param outputCap 整个输出区的字节容量。
     * @param outputOffset 从输出区首地址起算的写入偏移。
     * @return 成功时为本次写入字节数；参数无效、容量不足或值非有限时为 -1。
     */
    func formatFloat64(value: Float64, output: CPointer<UInt8>, outputCap: Int64,
        outputOffset: Int64): Int64
}

/**
 * 聚合第一方 Native 加速所需的 V1 原语集合。
 *
 * 同时提供结构、字符串和数字扫描、浮点转换及写出原语；运行时在 provider 激活成功后一次安装。供第一方包之间调用。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativeAccelerationPrimitivesV1 <: JsonNativeScannerBackend &
    JsonNativeNumericScannerBackend & JsonNativeNumericTapeBackend & JsonNativeFloatParserBackend &
    JsonNativeWriterBackend {}

// Published once while the runtime initialization lock is held. Keeping the
// complete primitive table in one slot prevents partial installation and makes
// every hot-path lookup observe either Pure or the full Native bundle.
private var jsonNativeAccelerationPrimitives: Option<JsonNativeAccelerationPrimitivesV1> =
    None<JsonNativeAccelerationPrimitivesV1>

func jsonNativeFormatFloat64Into(value: Float64, output: Array<Byte>,
    outputOffset: Int64): Option<Int64> {
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(item) => item
        case None => return None<Int64>
    }
    if (outputOffset < 0 || outputOffset > output.size ||
        output.size - outputOffset < 40) {
        return None<Int64>
    }
    unsafe {
        let outputHandle = acquireArrayRawData(output)
        let written = try {
            backend.formatFloat64(value, outputHandle.pointer, output.size,
                outputOffset)
        } finally {
            releaseArrayRawData(outputHandle)
        }
        if (written <= 0 || written > 40 || written > output.size - outputOffset) {
            throw JsonException("Native JSON float formatting failed",
                code: "acceleration_writer_failure")
        }
        Some(written)
    }
}

func jsonNativeFormatInt64ArrayInto(values: ArrayList<Int64>, output: Array<Byte>,
    outputOffset: Int64): Option<Int64> {
    if (values.size < YJSON_NATIVE_MIN_WRITER_INT64_COUNT) {
        return None<Int64>
    }
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(item) => item
        case None => return None<Int64>
    }
    if (values.size > (Int64.Max - 1) / 21) {
        throw JsonException("JSON integer array is too large for native formatting",
            code: "acceleration_writer_failure")
    }
    let contiguous = values.toArray()
    if (outputOffset < 0 || outputOffset > output.size ||
        output.size - outputOffset < 2) {
        throw JsonException("Native JSON integer output buffer is too small",
            code: "acceleration_writer_failure")
    }
    let written = Array<Int64>(1, repeat: 0)
    unsafe {
        let valuesHandle = acquireArrayRawData(contiguous)
        let outputHandle = acquireArrayRawData(output)
        let writtenHandle = acquireArrayRawData(written)
        let status = try {
            backend.formatInt64Array(valuesHandle.pointer, contiguous.size,
                outputHandle.pointer, output.size, outputOffset, writtenHandle.pointer)
        } finally {
            releaseArrayRawData(writtenHandle)
            releaseArrayRawData(outputHandle)
            releaseArrayRawData(valuesHandle)
        }
        if (status == YJ_JSON_SCAN_CAPACITY) {
            return None<Int64>
        }
        if (status != YJ_JSON_SCAN_OK || written[0] < 2 || written[0] > output.size) {
            throw JsonException("Native JSON integer formatting failed",
                code: "acceleration_writer_failure")
        }
    }
    Some(written[0])
}

func jsonNativeFormatInt64ArrayInto(values: Array<Int64>, output: Array<Byte>,
    outputOffset: Int64): Option<Int64> {
    if (values.size < YJSON_NATIVE_MIN_WRITER_INT64_COUNT) {
        return None<Int64>
    }
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(item) => item
        case None => return None<Int64>
    }
    if (values.size > (Int64.Max - 1) / 21) {
        throw JsonException("JSON integer array is too large for native formatting",
            code: "acceleration_writer_failure")
    }
    if (outputOffset < 0 || outputOffset > output.size ||
        output.size - outputOffset < 2) {
        throw JsonException("Native JSON integer output buffer is too small",
            code: "acceleration_writer_failure")
    }
    let written = Array<Int64>(1, repeat: 0)
    unsafe {
        let valuesHandle = acquireArrayRawData(values)
        let outputHandle = acquireArrayRawData(output)
        let writtenHandle = acquireArrayRawData(written)
        let status = try {
            backend.formatInt64Array(valuesHandle.pointer, values.size,
                outputHandle.pointer, output.size, outputOffset, writtenHandle.pointer)
        } finally {
            releaseArrayRawData(writtenHandle)
            releaseArrayRawData(outputHandle)
            releaseArrayRawData(valuesHandle)
        }
        if (status == YJ_JSON_SCAN_CAPACITY) {
            return None<Int64>
        }
        if (status != YJ_JSON_SCAN_OK || written[0] < 2 || written[0] > output.size) {
            throw JsonException("Native JSON integer formatting failed",
                code: "acceleration_writer_failure")
        }
    }
    Some(written[0])
}

func jsonNativeFormatFloat64ArrayInto(values: Array<Float64>, output: Array<Byte>,
    outputOffset: Int64): Option<Int64> {
    if (values.size < YJSON_NATIVE_MIN_WRITER_FLOAT64_COUNT) {
        return None<Int64>
    }
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(item) => item
        case None => return None<Int64>
    }
    if (values.size > (Int64.Max - 2) / 42) {
        throw JsonException("JSON float array is too large for native formatting",
            code: "acceleration_writer_failure")
    }
    if (outputOffset < 0 || outputOffset > output.size ||
        output.size - outputOffset < 2) {
        throw JsonException("Native JSON float output buffer is too small",
            code: "acceleration_writer_failure")
    }
    let written = Array<Int64>(1, repeat: 0)
    unsafe {
        let valuesHandle = acquireArrayRawData(values)
        let outputHandle = acquireArrayRawData(output)
        let writtenHandle = acquireArrayRawData(written)
        let status = try {
            backend.formatFloat64Array(valuesHandle.pointer, values.size,
                outputHandle.pointer, output.size, outputOffset, writtenHandle.pointer)
        } finally {
            releaseArrayRawData(writtenHandle)
            releaseArrayRawData(outputHandle)
            releaseArrayRawData(valuesHandle)
        }
        if (status == YJ_JSON_SCAN_CAPACITY) {
            return None<Int64>
        }
        if (status != YJ_JSON_SCAN_OK || written[0] < 2 || written[0] > output.size) {
            throw JsonException("Native JSON float formatting failed",
                code: "acceleration_writer_failure")
        }
    }
    Some(written[0])
}

/**
 * Installs the complete v1 primitive bundle atomically during runtime freeze.
 * Called by the runtime initialization path while holding the runtime lock.
 * Not part of the public surface: external code cannot install a bundle
 * without passing provider validation.
 */
internal func installJsonNativePrimitivesLocked(backend: JsonNativeAccelerationPrimitivesV1): Unit {
    if (jsonNativeAccelerationPrimitives.isSome()) {
        throw IllegalStateException("JSON native acceleration is already installed")
    }
    jsonNativeAccelerationPrimitives = Some(backend)
}

func jsonNativeEscapedStringSize(value: String, htmlSafe: Bool): Option<Int64> {
    if (value.size < YJSON_NATIVE_MIN_WRITER_ESCAPE_BYTES) {
        return None<Int64>
    }
    if (jsonNativeAccelerationPrimitives.isNone()) {
        return None<Int64>
    }
    if (value.size > (Int64.Max - 2) / 6) {
        throw JsonException("JSON string is too large for native escaping",
            code: "acceleration_writer_failure")
    }
    Some(jsonEscapedStringLiteralSize(value, htmlSafe))
}

func jsonEscapedStringLiteralSize(value: String, htmlSafe: Bool): Int64 {
    var required: Int64 = 2
    unsafe {
        let bytes = value.rawData()
        for (byte in bytes) {
            if (byte >= 0x20u8 && byte != b'"' && byte != b'\\' &&
                (!htmlSafe || !jsonNativeWriterNeedsHtmlEscape(byte))) {
                required++
            } else if (byte == b'"' || byte == b'\\' || byte == b'\b' || byte == b'\f' ||
                byte == b'\n' || byte == b'\r' || byte == b'\t') {
                required += 2
            } else {
                required += 6
            }
        }
    }
    required
}

private func jsonNativeWriterNeedsHtmlEscape(value: Byte): Bool {
    value == b'<' || value == b'>' || value == b'&' || value == b'=' || value == b'\''
}

func jsonNativeEscapeString(value: String, htmlSafe: Bool,
    required: Int64): Option<Array<Byte>> {
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(item) => item
        case None => return None<Array<Byte>>
    }
    let output = Array<Byte>(required, repeat: 0)
    let written = Array<Int64>(1, repeat: 0)
    unsafe {
        let input = value.rawData()
        let inputHandle = acquireArrayRawData(input)
        let outputHandle = acquireArrayRawData(output)
        let writtenHandle = acquireArrayRawData(written)
        let status = try {
            backend.escapeString(inputHandle.pointer, input.size, htmlSafe,
                outputHandle.pointer, output.size, writtenHandle.pointer)
        } finally {
            releaseArrayRawData(writtenHandle)
            releaseArrayRawData(outputHandle)
            releaseArrayRawData(inputHandle)
        }
        if (status != YJ_JSON_SCAN_OK || written[0] != output.size) {
            throw JsonException("Native JSON string escaping failed",
                code: "acceleration_writer_failure")
        }
    }
    Some(output[0..written[0]])
}

func jsonNativeFloatParserAvailable(): Bool {
    jsonNativeAccelerationPrimitives.isSome()
}

func jsonNativeParseFloat64(reader: JsonFastReader): Option<Float64> {
    let tokenLength = reader.currentRawTokenSize()
    if (tokenLength <= 0 || tokenLength > YJSON_NATIVE_FLOAT_MAX_TOKEN_BYTES) {
        return None<Float64>
    }
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(value) => value
        case None => return None<Float64>
    }
    let data = reader.currentRawTokenData()
    var result = Float64.NaN
    unsafe {
        let dataHandle = acquireArrayRawData(data)
        result = try {
            backend.parseFloat64(dataHandle.pointer, data.size,
                reader.currentRawTokenStartOffset(), tokenLength)
        } finally {
            releaseArrayRawData(dataHandle)
        }
    }
    if (result.isNaN()) { None<Float64> } else { Some(result) }
}

class JsonNativeNumericTape {
    private let words: Array<UInt64>
    private let next = Array<Int64>(1, repeat: 0)
    private let count = Array<Int64>(1, repeat: 0)
    private let error = Array<Int64>(1, repeat: -1)
    private var cursor: Int64 = 0
    private var filled: Int64 = 0
    private var scannedTo: Int64 = 0
    var calls: Int64 = 0
    var classifiedBytes: Int64 = 0
    var events: Int64 = 0
    var refillsBeforeExhaustion: Int64 = 0

    init(capacity: Int64) { words = Array<UInt64>(capacity * 4, repeat: 0u64) }

    func tokenAt(data: Array<Byte>, position: Int64, pageBytes: Int64): Option<(Int64, Int64, UInt64, UInt64)> {
        while (cursor < filled && Int64(words[cursor * 4]) < position) { cursor++ }
        if (cursor >= filled || Int64(words[cursor * 4]) != position) {
            if (cursor < filled) { refillsBeforeExhaustion++ }
            let backend = match (jsonNativeAccelerationPrimitives) {
                case Some(value) => value
                case None => return None<(Int64, Int64, UInt64, UInt64)>
            }
            let start = if (position > scannedTo) { position } else { scannedTo }
            unsafe {
                let dataHandle = acquireArrayRawData(data)
                let wordsHandle = acquireArrayRawData(words)
                let nextHandle = acquireArrayRawData(next)
                let countHandle = acquireArrayRawData(count)
                let errorHandle = acquireArrayRawData(error)
                let status = try {
                    backend.scanNumericTape(dataHandle.pointer, data.size, start, pageBytes,
                        YJ_JSON_SCAN_VALIDATE_STRINGS, wordsHandle.pointer, words.size / 4,
                        nextHandle.pointer, countHandle.pointer, errorHandle.pointer)
                } finally {
                    releaseArrayRawData(errorHandle); releaseArrayRawData(countHandle)
                    releaseArrayRawData(nextHandle); releaseArrayRawData(wordsHandle); releaseArrayRawData(dataHandle)
                }
                if (status != YJ_JSON_SCAN_OK) {
                    throw JsonException("Native numeric tape error at byte ${error[0]}", code: "parse_error")
                }
            }
            calls++; classifiedBytes += next[0] - start; events += count[0]
            scannedTo = next[0]; cursor = 0; filled = count[0]
            while (cursor < filled && Int64(words[cursor * 4]) < position) { cursor++ }
        }
        if (cursor < filled && Int64(words[cursor * 4]) == position) {
            let base = cursor * 4; cursor++
            return Some((Int64(words[base]), Int64(words[base + 1]), words[base + 2], words[base + 3]))
        }
        None<(Int64, Int64, UInt64, UInt64)>
    }

    func callCount(): Int64 { calls }
    func classifiedByteCount(): Int64 { classifiedBytes }
    func eventCount(): Int64 { events }
    func earlyRefillCount(): Int64 { refillsBeforeExhaustion }
}


class JsonNativeNumericChunk {
    let words: Array<UInt64>
    let count: Int64
    let next: Int64
    let done: Bool
    let fallback: Bool

    init(words: Array<UInt64>, count: Int64, next: Int64, done: Bool, fallback: Bool) {
        this.words = words; this.count = count; this.next = next
        this.done = done; this.fallback = fallback
    }
    func tokenStart(index: Int64): Int64 { Int64(words[index * 4]) }
    func tokenEnd(index: Int64): Int64 { Int64(words[index * 4 + 1]) }
    func magnitude(index: Int64): Int64 { Int64(words[index * 4 + 2]) }
    func flags(index: Int64): UInt64 { words[index * 4 + 3] }
}

class JsonNativeInt64Array {
    let values: Array<Int64>
    let count: Int64
    let end: Int64

    init(values: Array<Int64>, count: Int64, end: Int64) {
        this.values = values; this.count = count; this.end = end
    }
}

func jsonNativeParseInt64Array(data: Array<Byte>, start: Int64): Option<JsonNativeInt64Array> {
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(value) => value
        case None => return None<JsonNativeInt64Array>
    }
    let capacity = (data.size - start + 1) / 2
    let values = Array<Int64>(capacity, repeat: 0)
    let end = Array<Int64>(1, repeat: 0)
    let count = Array<Int64>(1, repeat: 0)
    let error = Array<Int64>(1, repeat: -1)
    unsafe {
        let dataHandle = acquireArrayRawData(data)
        let valuesHandle = acquireArrayRawData(values)
        let endHandle = acquireArrayRawData(end)
        let countHandle = acquireArrayRawData(count)
        let errorHandle = acquireArrayRawData(error)
        let status = try {
            backend.parseInt64Array(dataHandle.pointer, data.size, start,
                valuesHandle.pointer, values.size, endHandle.pointer, countHandle.pointer,
                errorHandle.pointer)
        } finally {
            releaseArrayRawData(errorHandle); releaseArrayRawData(countHandle)
            releaseArrayRawData(endHandle); releaseArrayRawData(valuesHandle)
            releaseArrayRawData(dataHandle)
        }
        if (status == YJ_JSON_SCAN_OK && count[0] >= 0 && count[0] <= values.size) {
            return Some(JsonNativeInt64Array(values, count[0], end[0]))
        }
        if (status == YJ_JSON_SCAN_FALLBACK) { return None<JsonNativeInt64Array> }
        throw JsonException("Native JSON Int64 array conversion failed",
            code: "acceleration_reader_failure")
    }
}

func jsonNativeScanNumericArrayChunk(data: Array<Byte>, start: Int64,
    validateStrings: Bool, tokenCap: Int64): Option<JsonNativeNumericChunk> {
    let backend = match (jsonNativeAccelerationPrimitives) {
        case Some(value) => value
        case None => return None<JsonNativeNumericChunk>
    }
    let words = Array<UInt64>(tokenCap * 4, repeat: 0u64)
    let next = Array<Int64>(1, repeat: 0)
    let count = Array<Int64>(1, repeat: 0)
    let done = Array<Int64>(1, repeat: 0)
    let error = Array<Int64>(1, repeat: -1)
    unsafe {
        let dataHandle = acquireArrayRawData(data)
        let wordsHandle = acquireArrayRawData(words)
        let nextHandle = acquireArrayRawData(next)
        let countHandle = acquireArrayRawData(count)
        let doneHandle = acquireArrayRawData(done)
        let errorHandle = acquireArrayRawData(error)
        let status = try {
            backend.scanNumericArrayChunk(dataHandle.pointer, data.size, start,
                nativeJsonScannerFlags(validateStrings), wordsHandle.pointer, tokenCap,
                nextHandle.pointer, countHandle.pointer, doneHandle.pointer, errorHandle.pointer)
        } finally {
            releaseArrayRawData(errorHandle); releaseArrayRawData(doneHandle)
            releaseArrayRawData(countHandle); releaseArrayRawData(nextHandle)
            releaseArrayRawData(wordsHandle); releaseArrayRawData(dataHandle)
        }
        if (status == YJ_JSON_SCAN_OK || status == YJ_JSON_SCAN_FALLBACK) {
            return Some(JsonNativeNumericChunk(words, count[0], next[0], done[0] != 0,
                status == YJ_JSON_SCAN_FALLBACK))
        }
        throw JsonException("Native numeric scanner error at byte ${error[0]}", code: "parse_error")
    }
}

private func YJ_JSON_SimdCaps(): UInt32 {
    match (jsonNativeAccelerationPrimitives) {
        case Some(backend) => backend.simdCaps()
        case None => 0u32
    }
}

private func YJ_JSON_SkipValue(
    input: CPointer<UInt8>,
    len: Int64,
    start: Int64,
    flags: UInt32,
    outEnd: CPointer<Int64>,
    outError: CPointer<Int64>
): Int32 {
    match (jsonNativeAccelerationPrimitives) {
        case Some(backend) => backend.skipValue(input, len, start, flags, outEnd, outError)
        case None => YJ_JSON_SCAN_FALLBACK
    }
}

private func YJ_JSON_ScanString(
    input: CPointer<UInt8>,
    len: Int64,
    start: Int64,
    flags: UInt32,
    outEnd: CPointer<Int64>,
    outError: CPointer<Int64>
): Int32 {
    match (jsonNativeAccelerationPrimitives) {
        case Some(backend) => backend.scanString(input, len, start, flags, outEnd, outError)
        case None => YJ_JSON_SCAN_FALLBACK
    }
}

private func YJ_JSON_DecodeString(
    input: CPointer<UInt8>,
    len: Int64,
    start: Int64,
    flags: UInt32,
    output: CPointer<UInt8>,
    outputCap: Int64,
    outEnd: CPointer<Int64>,
    outWritten: CPointer<Int64>,
    outError: CPointer<Int64>
): Int32 {
    match (jsonNativeAccelerationPrimitives) {
        case Some(backend) => backend.decodeString(input, len, start, flags, output, outputCap, outEnd, outWritten, outError)
        case None => YJ_JSON_SCAN_FALLBACK
    }
}

private func nativeJsonScannerFlags(validateStrings: Bool): UInt32 {
    if (validateStrings) {
        return YJ_JSON_SCAN_VALIDATE_STRINGS
    }
    0u32
}

private func nativeJsonScannerAvailable(): Bool {
    unsafe {
        (YJ_JSON_SimdCaps() & 1u32) != 0u32
    }
}

class JsonNativeDecodedString {
    let value: String
    let end: Int64

    init(value: String, end: Int64) {
        this.value = value
        this.end = end
    }
}

func jsonNativeScanString(
    data: Array<Byte>,
    size: Int64,
    start: Int64,
    validateStrings: Bool
): Int64 {
    if (!nativeJsonScannerAvailable()) {
        return -1
    }
    let end = Array<Int64>(1, repeat: 0)
    let error = Array<Int64>(1, repeat: 0)
    unsafe {
        let dataHandle = acquireArrayRawData(data)
        let endHandle = acquireArrayRawData(end)
        let errorHandle = acquireArrayRawData(error)
        let status = try {
            YJ_JSON_ScanString(
                dataHandle.pointer,
                size,
                start,
                nativeJsonScannerFlags(validateStrings),
                endHandle.pointer,
                errorHandle.pointer
            )
        } finally {
            releaseArrayRawData(errorHandle)
            releaseArrayRawData(endHandle)
            releaseArrayRawData(dataHandle)
        }
        if (status == YJ_JSON_SCAN_OK) {
            return end[0]
        }
        if (status == YJ_JSON_SCAN_FALLBACK) {
            return -1
        }
        throw JsonException("Native JSON scanner error at byte ${error[0]}",
            code: "parse_error",
            location: Some(JsonLocation(error[0], jsonLineFromUtf8Bytes(data, error[0]),
                jsonColumnFromUtf8Bytes(data, error[0]))))
    }
}

func jsonNativeDecodeString(
    data: Array<Byte>,
    size: Int64,
    start: Int64,
    validateStrings: Bool
): Option<JsonNativeDecodedString> {
    if (!nativeJsonScannerAvailable() || size - start < YJSON_NATIVE_MIN_DECODE_BYTES) {
        return None<JsonNativeDecodedString>
    }
    let stringEnd = jsonNativeScanString(data, size, start, validateStrings)
    if (stringEnd <= start) {
        return None<JsonNativeDecodedString>
    }
    let output = Array<Byte>(stringEnd - start - 1, repeat: 0)
    let end = Array<Int64>(1, repeat: 0)
    let written = Array<Int64>(1, repeat: 0)
    let error = Array<Int64>(1, repeat: 0)
    unsafe {
        let dataHandle = acquireArrayRawData(data)
        let outputHandle = acquireArrayRawData(output)
        let endHandle = acquireArrayRawData(end)
        let writtenHandle = acquireArrayRawData(written)
        let errorHandle = acquireArrayRawData(error)
        let status = try {
            YJ_JSON_DecodeString(
                dataHandle.pointer,
                size,
                start,
                nativeJsonScannerFlags(validateStrings),
                outputHandle.pointer,
                output.size,
                endHandle.pointer,
                writtenHandle.pointer,
                errorHandle.pointer
            )
        } finally {
            releaseArrayRawData(errorHandle)
            releaseArrayRawData(writtenHandle)
            releaseArrayRawData(endHandle)
            releaseArrayRawData(outputHandle)
            releaseArrayRawData(dataHandle)
        }
        if (status == YJ_JSON_SCAN_OK) {
            return Some(JsonNativeDecodedString(String.fromUtf8Unchecked(output[0..written[0]]), end[0]))
        }
        if (status == YJ_JSON_SCAN_FALLBACK || status == YJ_JSON_SCAN_CAPACITY) {
            return None<JsonNativeDecodedString>
        }
        throw JsonException("Native JSON scanner error at byte ${error[0]}",
            code: "parse_error",
            location: Some(JsonLocation(error[0], jsonLineFromUtf8Bytes(data, error[0]),
                jsonColumnFromUtf8Bytes(data, error[0]))))
    }
}

func jsonNativeSkipValue(
    data: Array<Byte>,
    size: Int64,
    start: Int64,
    validateStrings: Bool
): Int64 {
    if (!nativeJsonScannerAvailable()) {
        return -1
    }
    let end = Array<Int64>(1, repeat: 0)
    let error = Array<Int64>(1, repeat: 0)
    unsafe {
        let dataHandle = acquireArrayRawData(data)
        let endHandle = acquireArrayRawData(end)
        let errorHandle = acquireArrayRawData(error)
        let status = try {
            YJ_JSON_SkipValue(
                dataHandle.pointer,
                size,
                start,
                nativeJsonScannerFlags(validateStrings),
                endHandle.pointer,
                errorHandle.pointer
            )
        } finally {
            releaseArrayRawData(errorHandle)
            releaseArrayRawData(endHandle)
            releaseArrayRawData(dataHandle)
        }
        if (status == YJ_JSON_SCAN_OK) {
            return end[0]
        }
        if (status == YJ_JSON_SCAN_FALLBACK) {
            return -1
        }
        throw JsonException("Native JSON scanner error at byte ${error[0]}",
            code: "parse_error",
            location: Some(JsonLocation(error[0], jsonLineFromUtf8Bytes(data, error[0]),
                jsonColumnFromUtf8Bytes(data, error[0]))))
    }
}
