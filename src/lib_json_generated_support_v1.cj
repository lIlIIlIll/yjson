package yjson

import std.collection.*
import std.math.numeric.*
import std.time.*

/**
 * 供宏生成 codec 使用的版本化 raw 读取接口。
 *
 * 实现由运行时提供。结构原语推进输入位置，生成 codec 负责配对调用以及所需的路径、深度和字段策略；接口本身不代表一个完整文档已通过校验。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedSupportV1Reader {
    /**
     * 跳过尾部空白并检查输入是否已经结束。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 仍有非空白输入，错误码为 parse_error。
     */
    func expectEnd(): Unit
    /**
     * 跳过空白并消费对象开始符 `{`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func startRawObject(): Unit
    /**
     * 跳过空白并消费对象结束符 `}`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func endRawObject(): Unit
    /**
     * 跳过空白并检查当前位置是否还有对象字段。
     *
     * 不消费逗号、字段名或结束符；当前实现不使用 first 来验证分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 当前调用是否针对第一个字段；当前运行时实现忽略此值。
     * @return 尚未到输入末尾且下一字节不是 `}` 时返回 true。
     */
    func hasRawObjectField(first: Bool): Bool
    /**
     * 检查生成对象循环是否还能读取下一个字段。
     *
     * 会跳过当前位置的空白，但不消费逗号或字段名；需要与读取字段名的方法配对。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 首字段在下一字节不是 `}` 时返回 true；后续字段在下一字节是逗号时返回 true。
     */
    func hasRawObjectFieldFast(first: Bool): Bool
    /**
     * 消费字段分隔符、JSON 字符串字段名和冒号。
     *
     * 字段名按 JSON 字符串规则解码；返回后输入位于字段值前。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 解码后的字段名。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func readRawName(first: Bool): String
    /**
     * 读取字段名及冒号，并查找匹配的 UTF-8 候选名。
     *
     * 比较解码后的字段名；未匹配也会消费完整字段名及冒号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @param candidates 候选字段名的 UTF-8 字节数组，按返回索引排序；候选字节应为合法 UTF-8。
     * @return 第一个匹配候选的从 0 开始的索引；没有匹配时为 -1。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func readRawNameIdBytes(first: Bool, candidates: Array<Array<Byte>>): Int64
    /**
     * 尝试消费精确匹配的紧凑字段名 token。
     *
     * 只匹配不含空白的 `"name":`，后续字段还必须有前导逗号；失败时保持输入位置不变，供一般字段分发路径继续读取。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @param nameBytes 字段名的原始字节，不含引号和冒号；生成方负责保证它可直接用于未转义的 JSON 字段名。
     * @return 匹配并消费 token 时为 true；不匹配或输入不足时为 false。
     */
    func tryReadRawCompactNameTokenBytes(first: Bool, nameBytes: Array<Byte>): Bool

    /**
     * 跳过空白并消费数组开始符 `[`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func startRawArray(): Unit
    /**
     * 跳过空白并消费数组结束符 `]`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func endRawArray(): Unit
    /**
     * 跳过空白并检查当前位置是否还有数组项。
     *
     * 不消费逗号、数组项或结束符；当前实现不使用 first 来验证分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 当前调用是否针对第一个数组项；当前运行时实现忽略此值。
     * @return 尚未到输入末尾且下一字节不是 `]` 时返回 true。
     */
    func hasRawArrayItem(first: Bool): Bool
    /**
     * 检查生成数组循环是否还能读取下一个数组项。
     *
     * 会跳过当前位置的空白，但不消费逗号或数组项；读取前还需调用 beforeRawArrayItemFast。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 首项在下一字节不是 `]` 时返回 true；后续项在下一字节是逗号时返回 true。
     */
    func hasRawArrayItemFast(first: Bool): Bool
    /**
     * 在读取数组项前消费必要的空白和逗号。
     *
     * 首项只跳过空白；后续项先消费逗号，再跳过空白。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func beforeRawArrayItem(first: Bool): Unit
    /**
     * 为 Fast 数组循环消费当前项前的分隔符。
     *
     * 与 hasRawArrayItemFast 配对；后续项消费逗号，首项和后续项都跳过空白。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func beforeRawArrayItemFast(first: Bool): Unit
    /**
     * 根据剩余输入估算生成集合的初始容量。
     *
     * 在已消费数组开始符的位置调用。较大的根数组可采样前 512 字节，其他位置使用保守估算；不推进输入位置，结果不是元素数保证。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 用于预分配的容量提示。
     */
    func suggestRawCollectionCapacity(): Int64
    /**
     * 根据剩余输入字节数估算数组初始容量。
     *
     * 不推进输入位置；当前估算按每项 32 字节计算，并限制在 4 到 64 之间。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 4 到 64 之间的容量提示，不表示实际数组长度。
     */
    func suggestRawArrayCapacity(): Int64
    /**
     * 根据剩余输入字节数估算对象映射初始容量。
     *
     * 不推进输入位置；当前估算按每项约 8 字节计算，并限制在 4 到 256 之间。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 4 到 256 之间的容量提示，不表示实际字段数。
     */
    func suggestRawObjectCapacity(): Int64

    /**
     * 尝试从当前位置读取 `null` 字面量。
     *
     * 会跳过前导空白；下一字节不是 `n` 时返回 false，已跳过的空白不会恢复。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 成功消费 `null` 时为 true；下一值不以 `n` 开始时为 false。
     * @throws JsonException 输入以 `n` 开始但后续不能组成 `null`，错误码为 parse_error。
     */
    func tryReadRawNull(): Bool
    /**
     * 跳过前导空白并读取布尔字面量。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return `true` 对应 true，`false` 对应 false。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    func readRawBool(): Bool
    /**
     * 读取并解码当前位置的 JSON 字符串。
     *
     * 处理 JSON 转义；字节输入的原始 UTF-8 会在读取时校验。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 不含外围引号的字符串值。
     * @throws JsonException 字符串语法、转义或 UTF-8 无效，或字符串及缓冲值字节预算超限。
     */
    func readRawString(): String
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int64。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int64 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawInt64(): Int64
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int32。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int32 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawInt32(): Int32
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int16。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int16 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawInt16(): Int16
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int8。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int8 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawInt8(): Int8
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt64。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt64 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawUInt64(): UInt64
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt32。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt32 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawUInt32(): UInt32
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt16。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt16 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawUInt16(): UInt16
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt8。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt8 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    func readRawUInt8(): UInt8
    /**
     * 跳过一个 JSON 值，并限制相对于当前上下文的容器深度。
     *
     * 标量不占用容器深度；只执行语法跳过，不检查被跳过对象的重复键策略，也不为子项建立路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxDepth 允许在本次跳过中进入的容器层数，必须非负；0 只允许标量。
     * @throws IllegalArgumentException maxDepth 为负数。
     * @throws JsonException 语法无效、容器深度超限，或被扫描值的字节预算超限。
     */
    func skipRawWithDepth(maxDepth: Int64): Unit
}

/**
 * 生成对象 codec 在解析具体读取器后复用的结构体读游标。
 *
 * 持有运行时 JsonFastReader 的引用；结构体包装本身不另建 parser，读出的字符串和集合仍可能分配。游标共享读取位置与生成读取状态。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public struct GeneratedSupportV1ReadCursor {
    private let reader: JsonFastReader

    init(reader: JsonFastReader) { this.reader = reader }
    /**
     * 返回此游标持有的具体快速读取器。
     *
     * 返回的是同一有状态读取器；通过任一入口读取都会推进共同的输入位置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 此游标引用的 JsonFastReader。
     */
    public func generatedReaderV1(): JsonFastReader { reader }

    /**
     * 跳过空白并消费对象开始符 `{`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func startRawObject(): Unit { reader.startRawObject() }
    /**
     * 跳过空白并消费对象结束符 `}`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func endRawObject(): Unit { reader.endRawObject() }
    /**
     * 跳过空白并检查当前位置是否还有对象字段。
     *
     * 不消费逗号、字段名或结束符；当前实现不使用 first 来验证分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 当前调用是否针对第一个字段；当前运行时实现忽略此值。
     * @return 尚未到输入末尾且下一字节不是 `}` 时返回 true。
     */
    public func hasRawObjectField(first: Bool): Bool { reader.hasRawObjectField(first) }
    /**
     * 检查生成对象循环是否还能读取下一个字段。
     *
     * 会跳过当前位置的空白，但不消费逗号或字段名；需要与读取字段名的方法配对。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 首字段在下一字节不是 `}` 时返回 true；后续字段在下一字节是逗号时返回 true。
     */
    public func hasRawObjectFieldFast(first: Bool): Bool { reader.hasRawObjectFieldFast(first) }
    /**
     * 消费字段分隔符、JSON 字符串字段名和冒号。
     *
     * 字段名按 JSON 字符串规则解码；返回后输入位于字段值前。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 解码后的字段名。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func readRawName(first: Bool): String { reader.readRawName(first) }
    /**
     * 按普通字段名读取规则消费字段名及其分隔符。
     *
     * 当前实现委托 readRawName，接受其处理的空白、转义和非 ASCII 字段名。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 解码后的字段名。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func readRawNameFast(first: Bool): String { reader.readRawNameFast(first) }
    /**
     * 读取字段名及冒号，并查找匹配的 UTF-8 候选名。
     *
     * 比较解码后的字段名；未匹配也会消费完整字段名及冒号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @param candidates 候选字段名的 UTF-8 字节数组，按返回索引排序；候选字节应为合法 UTF-8。
     * @return 第一个匹配候选的从 0 开始的索引；没有匹配时为 -1。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func readRawNameIdBytes(first: Bool, candidates: Array<Array<Byte>>): Int64 {
        reader.readRawNameIdBytes(first, candidates)
    }
    /**
     * 尝试消费精确匹配的紧凑字段名 token。
     *
     * 只匹配不含空白的 `"name":`，后续字段还必须有前导逗号；失败时保持输入位置不变，供一般字段分发路径继续读取。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @param nameBytes 字段名的原始字节，不含引号和冒号；生成方负责保证它可直接用于未转义的 JSON 字段名。
     * @return 匹配并消费 token 时为 true；不匹配或输入不足时为 false。
     */
    public func tryReadRawCompactNameTokenBytes(first: Bool, nameBytes: Array<Byte>): Bool {
        reader.tryReadRawCompactNameTokenBytes(first, nameBytes)
    }
    /**
     * 跳过空白并消费数组开始符 `[`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func startRawArray(): Unit { reader.startRawArray() }
    /**
     * 跳过空白并消费数组结束符 `]`。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func endRawArray(): Unit { reader.endRawArray() }
    /**
     * 跳过空白并检查当前位置是否还有数组项。
     *
     * 不消费逗号、数组项或结束符；当前实现不使用 first 来验证分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 当前调用是否针对第一个数组项；当前运行时实现忽略此值。
     * @return 尚未到输入末尾且下一字节不是 `]` 时返回 true。
     */
    public func hasRawArrayItem(first: Bool): Bool { reader.hasRawArrayItem(first) }
    /**
     * 检查生成数组循环是否还能读取下一个数组项。
     *
     * 会跳过当前位置的空白，但不消费逗号或数组项；读取前还需调用 beforeRawArrayItemFast。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @return 首项在下一字节不是 `]` 时返回 true；后续项在下一字节是逗号时返回 true。
     */
    public func hasRawArrayItemFast(first: Bool): Bool { reader.hasRawArrayItemFast(first) }
    /**
     * 在读取数组项前消费必要的空白和逗号。
     *
     * 首项只跳过空白；后续项先消费逗号，再跳过空白。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func beforeRawArrayItem(first: Bool): Unit { reader.beforeRawArrayItem(first) }
    /**
     * 为 Fast 数组循环消费当前项前的分隔符。
     *
     * 与 hasRawArrayItemFast 配对；后续项消费逗号，首项和后续项都跳过空白。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否读取当前容器的第一项；后续项需要消费前导逗号。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func beforeRawArrayItemFast(first: Bool): Unit { reader.beforeRawArrayItemFast(first) }
    /**
     * 根据剩余输入估算生成集合的初始容量。
     *
     * 在已消费数组开始符的位置调用。较大的根数组可采样前 512 字节，其他位置使用保守估算；不推进输入位置，结果不是元素数保证。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 用于预分配的容量提示。
     */
    public func suggestRawCollectionCapacity(): Int64 { reader.suggestRawCollectionCapacity() }
    /**
     * 根据剩余输入字节数估算数组初始容量。
     *
     * 不推进输入位置；当前估算按每项 32 字节计算，并限制在 4 到 64 之间。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 4 到 64 之间的容量提示，不表示实际数组长度。
     */
    public func suggestRawArrayCapacity(): Int64 { reader.suggestRawArrayCapacity() }
    /**
     * 根据剩余输入字节数估算对象映射初始容量。
     *
     * 不推进输入位置；当前估算按每项约 8 字节计算，并限制在 4 到 256 之间。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 4 到 256 之间的容量提示，不表示实际字段数。
     */
    public func suggestRawObjectCapacity(): Int64 { reader.suggestRawObjectCapacity() }
    /**
     * 尝试从当前位置读取 `null` 字面量。
     *
     * 会跳过前导空白；下一字节不是 `n` 时返回 false，已跳过的空白不会恢复。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 成功消费 `null` 时为 true；下一值不以 `n` 开始时为 false。
     * @throws JsonException 输入以 `n` 开始但后续不能组成 `null`，错误码为 parse_error。
     */
    public func tryReadRawNull(): Bool { reader.tryReadRawNull() }
    /**
     * 跳过前导空白并读取布尔字面量。
     *
     * raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return `true` 对应 true，`false` 对应 false。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func readRawBool(): Bool { reader.readRawBool() }
    /**
     * 优先直接匹配带值结束边界的布尔字面量。
     *
     * 直接匹配失败时恢复调用前的位置并委托 readRawBool；不增加路径或深度作用域。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的布尔值。
     * @throws JsonException 当前位置的输入不符合所需语法，错误码为 parse_error。
     */
    public func readRawBoolFast(): Bool { reader.readRawBoolFast() }
    /**
     * 读取并解码当前位置的 JSON 字符串。
     *
     * 处理 JSON 转义；字节输入的原始 UTF-8 会在读取时校验。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 不含外围引号的字符串值。
     * @throws JsonException 字符串语法、转义或 UTF-8 无效，或字符串及缓冲值字节预算超限。
     */
    public func readRawString(): String { reader.readRawString() }
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int64。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int64 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawInt64(): Int64 { reader.readRawInt64() }
    /**
     * 优先直接扫描可表示为 Int64 的整数字节。
     *
     * 检查整数结束边界和数值范围；直接路径不适用时恢复调用前的位置并委托 readRawInt64。该入口不增加路径或深度作用域。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 扫描得到的 Int64 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawInt64Fast(): Int64 { reader.readRawInt64Fast() }
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int32。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int32 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawInt32(): Int32 { reader.readRawInt32() }
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int16。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int16 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawInt16(): Int16 { reader.readRawInt16() }
    /**
     * 读取有符号 JSON 整数字面量并转换为 Int8。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 Int8 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawInt8(): Int8 { reader.readRawInt8() }
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt64。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt64 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawUInt64(): UInt64 { reader.readRawUInt64() }
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt32。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt32 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawUInt32(): UInt32 { reader.readRawUInt32() }
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt16。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt16 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawUInt16(): UInt16 { reader.readRawUInt16() }
    /**
     * 读取无符号 JSON 整数字面量并转换为 UInt8。
     *
     * 拒绝小数部分和指数，检查目标类型范围。raw 原语只推进输入位置；生成 codec 负责所需的路径和深度状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 读取的 UInt8 值。
     * @throws JsonException 整数语法无效、含小数或指数，或超出目标类型范围；对应错误码包括 parse_error、invalid_value 和 number_out_of_range。
     */
    public func readRawUInt8(): UInt8 { reader.readRawUInt8() }
    /**
     * 读取 JSON 数字并转换为 Float64。
     *
     * 先扫描 JSON 数字文本，再使用 Float64 数值解析；已安装的 Native 浮点解析能力不可用或未接受 token 时使用标准库解析。本入口不额外拒绝解析得到的非有限值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 按上述解析及转换规则得到的 Float64 值。
     * @throws JsonException 数字语法无效或缓冲值字节预算超限。
     * @throws Exception 标准库浮点解析失败；本入口原样传播解析异常。
     */
    public func readRawFloat64(): Float64 { jsonFastReadFloat64(reader) }
    /**
     * 读取 JSON 数字并转换为 Float32。
     *
     * 先扫描 JSON 数字文本，再使用 Float64 数值解析；已安装的 Native 浮点解析能力不可用或未接受 token 时使用标准库解析。随后转换为 Float32，转换不增加有限值检查。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 按上述解析及转换规则得到的 Float32 值。
     * @throws JsonException 数字语法无效或缓冲值字节预算超限。
     * @throws Exception 标准库浮点解析失败；本入口原样传播解析异常。
     */
    public func readRawFloat32(): Float32 { jsonFastReadFloat32(reader) }
    /**
     * 读取 JSON 数字并转换为 Float16。
     *
     * 先扫描 JSON 数字文本，再使用 Float64 数值解析；已安装的 Native 浮点解析能力不可用或未接受 token 时使用标准库解析。随后转换为 Float16，转换不增加有限值检查。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 按上述解析及转换规则得到的 Float16 值。
     * @throws JsonException 数字语法无效或缓冲值字节预算超限。
     * @throws Exception 标准库浮点解析失败；本入口原样传播解析异常。
     */
    public func readRawFloat16(): Float16 { jsonFastReadFloat16(reader) }
    /**
     * 读取 JSON 数字文本并交给 BigInt.parse。
     *
     * 这里直接调用标准库解析，不将数值转换异常改写为 JsonException。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 BigInt。
     * @throws JsonException 数字语法无效或缓冲值字节预算超限。
     * @throws Exception 数字文本不能由标准库解析为 BigInt；解析异常原样传播。
     */
    public func readRawBigInt(): BigInt { reader.readRawBigInt() }
    /**
     * 读取 JSON 数字文本并交给 Decimal.parse。
     *
     * 这里直接调用标准库解析，不将数值转换异常改写为 JsonException。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 解析得到的 Decimal。
     * @throws JsonException 数字语法无效或缓冲值字节预算超限。
     * @throws Exception 数字文本不能由标准库解析为 Decimal；解析异常原样传播。
     */
    public func readRawDecimal(): Decimal { reader.readRawDecimal() }
    /**
     * 扫描 JSON 数字并保留其原始文本。
     *
     * 保留原来的符号、小数和指数写法，不先转换为浮点数。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 本次数值 token 的文本。
     * @throws JsonException 数字语法无效或缓冲值字节预算超限。
     */
    public func readRawNumberLiteral(): String { reader.readRawNumberLiteral() }
    /**
     * 读取一个 JSON 字符串并将其解码为单个 Rune。
     *
     * 按 Unicode 标量个数判断，不按 UTF-8 字节数判断。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 字符串中唯一的 Unicode 标量。
     * @throws JsonException 字符串读取失败，或字符串的 Unicode 标量数不是 1；后者使用 invalid_value。
     */
    public func readRawRune(): Rune { decodeRuneText(reader.readRawString()) }
    /**
     * 读取 JSON 字符串并按 RFC 3339 解析日期时间。
     *
     * 常见日期时间形状使用专用解析，其余形状委托标准库 RFC3339 解析。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 包含解析所得日期、时间和时区偏移的 DateTime。
     * @throws JsonException 字符串读取失败，或文本不能按 RFC 3339 解析；日期时间解析失败使用 invalid_value。
     */
    public func readRawRfc3339DateTime(): DateTime {
        jsonFastParseRfc3339DateTime(reader.readRawString())
    }
    /**
     * 读取当前位置的 Array<Int64> 容器值。
     *
     * 读取期间进入一个生成读取深度作用域，并在成功或失败后离开该作用域。可先尝试已启用的 Native 整数数组解析，未命中时使用逐项读取。不为每个数组索引或映射键单独建立路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 Array<Int64>。
     * @throws JsonException 容器语法、元素类型或整数范围无效，或生成读取深度及适用的字符串预算超限。
     */
    public func readRawInt64Array(): Array<Int64> {
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            if (let Some(result) <- reader.tryReadNativeInt64ArrayList()) {
                return result.toArray()
            }
            reader.startRawArray()
            if (!reader.hasRawArrayItem(true)) {
                reader.endRawArray()
                return Array<Int64>()
            }
            let result = ArrayList<Int64>(reader.suggestRawArrayCapacity())
            var first = true
            while (reader.hasRawArrayItem(first)) {
                reader.beforeRawArrayItem(first)
                result.add(reader.readRawInt64())
                first = false
            }
            reader.endRawArray()
            result.toArray()
        } finally {
            context.leaveValue()
        }
    }
    /**
     * 读取当前位置的 Array<String> 容器值。
     *
     * 读取期间进入一个生成读取深度作用域，并在成功或失败后离开该作用域。不为每个数组索引或映射键单独建立路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 Array<String>。
     * @throws JsonException 容器或字符串语法无效、字符串 UTF-8 无效，或生成读取深度及字符串预算超限。
     */
    public func readRawStringArray(): Array<String> {
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawArray()
            let result = ArrayList<String>(reader.suggestRawArrayCapacity())
            var first = true
            while (reader.hasRawArrayItem(first)) {
                reader.beforeRawArrayItem(first)
                result.add(reader.readRawString())
                first = false
            }
            reader.endRawArray()
            result.toArray()
        } finally {
            context.leaveValue()
        }
    }
    /**
     * 读取当前位置的 HashMap<String, Int64> 容器值。
     *
     * 读取期间进入一个生成读取深度作用域，并在成功或失败后离开该作用域。同名键通过映射赋值覆盖先前值；本 helper 不单独执行重复键拒绝。不为每个数组索引或映射键单独建立路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 HashMap<String, Int64>。
     * @throws JsonException 容器语法、元素类型或整数范围无效，或生成读取深度及适用的字符串预算超限。
     */
    public func readRawInt64Map(): HashMap<String, Int64> {
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawObject()
            let result = HashMap<String, Int64>(reader.suggestRawObjectCapacity())
            var first = true
            while (reader.hasRawObjectField(first)) {
                result[reader.readRawName(first)] = reader.readRawInt64()
                first = false
            }
            reader.endRawObject()
            result
        } finally {
            context.leaveValue()
        }
    }
    /**
     * 读取当前位置的 HashMap<String, String> 容器值。
     *
     * 读取期间进入一个生成读取深度作用域，并在成功或失败后离开该作用域。同名键通过映射赋值覆盖先前值；本 helper 不单独执行重复键拒绝。不为每个数组索引或映射键单独建立路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 HashMap<String, String>。
     * @throws JsonException 容器或字符串语法无效、字符串 UTF-8 无效，或生成读取深度及字符串预算超限。
     */
    public func readRawStringMap(): HashMap<String, String> {
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawObject()
            let result = HashMap<String, String>(reader.suggestRawObjectCapacity())
            var first = true
            while (reader.hasRawObjectField(first)) {
                result[reader.readRawName(first)] = reader.readRawString()
                first = false
            }
            reader.endRawObject()
            result
        } finally {
            context.leaveValue()
        }
    }
    /**
     * 读取当前位置的 HashMap<String, Array<Int64>> 容器值。
     *
     * 读取期间进入一个生成读取深度作用域，并在成功或失败后离开该作用域。同名键通过映射赋值覆盖先前值；本 helper 不单独执行重复键拒绝。每个映射键的数组读取期间会压入该键的字段路径，并在结束后弹出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 HashMap<String, Array<Int64>>。
     * @throws JsonException 容器语法、元素类型或整数范围无效，或生成读取深度及适用的字符串预算超限。
     */
    public func readRawInt64ArrayMap(): HashMap<String, Array<Int64>> {
        let context = reader.generatedReadStateV1()
        context.enterValue()
        try {
            reader.startRawObject()
            let result = HashMap<String, Array<Int64>>(reader.suggestRawObjectCapacity())
            var first = true
            while (reader.hasRawObjectField(first)) {
                let name = reader.readRawName(first)
                context.pushField(name)
                try {
                    result[name] = readRawInt64Array()
                } finally {
                    context.popPath()
                }
                first = false
            }
            reader.endRawObject()
            result
        } finally {
            context.leaveValue()
        }
    }

    // Generated object codecs already push the owning field path around
    // direct container reads.  These allocation-free variants retain the
    // outer structural work while omitting per-element path bookkeeping on
    // the default fast path.
    /**
     * 按 Fast 容器路径读取 Array<Int64>。
     *
     * 先尝试 Native 整数数组解析，再使用 Fast 数组循环逐项读取。不进入生成读取深度作用域，也不维护容器子项的路径；生成 codec 负责本次调用所需的外层状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 Array<Int64>。
     * @throws JsonException 读取到的容器语法、元素类型或整数范围无效。
     */
    public func readRawInt64ArrayFast(): Array<Int64> {
        if (let Some(result) <- reader.tryReadNativeInt64ArrayList()) {
            return result.toArray()
        }
        reader.startRawArray()
        if (!reader.hasRawArrayItem(true)) {
            reader.endRawArray()
            return Array<Int64>()
        }
        let result = ArrayList<Int64>(reader.suggestRawArrayCapacity())
        var first = true
        while (reader.hasRawArrayItemFast(first)) {
            reader.beforeRawArrayItemFast(first)
            result.add(reader.readRawInt64Fast())
            first = false
        }
        reader.endRawArray()
        result.toArray()
    }

    /**
     * 按 Fast 容器路径读取 HashMap<String, Int64>。
     *
     * 优先使用紧凑对象扫描；该扫描不适用时恢复起始输入位置，再按普通 raw 容器规则读取。不进入生成读取深度作用域，也不维护容器子项的路径；生成 codec 负责本次调用所需的外层状态。同名映射键覆盖先前值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 HashMap<String, Int64>。
     * @throws JsonException 读取到的容器语法、元素类型或整数范围无效。
     */
    public func readRawInt64MapFast(): HashMap<String, Int64> {
        reader.readRawInt64MapFast()
    }

    /**
     * 按 Fast 容器路径读取 HashMap<String, Array<Int64>>。
     *
     * 优先使用紧凑对象扫描；该扫描不适用时恢复起始输入位置，再按普通 raw 容器规则读取。不进入生成读取深度作用域，也不维护容器子项的路径；生成 codec 负责本次调用所需的外层状态。同名映射键覆盖先前值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建并填充的 HashMap<String, Array<Int64>>。
     * @throws JsonException 读取到的容器语法、元素类型或整数范围无效。
     */
    public func readRawInt64ArrayMapFast(): HashMap<String, Array<Int64>> {
        reader.readRawInt64ArrayMapFast()
    }
    /**
     * 跳过一个 JSON 值，并限制相对于当前上下文的容器深度。
     *
     * 标量不占用容器深度；只执行语法跳过，不检查被跳过对象的重复键策略，也不为子项建立路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxDepth 允许在本次跳过中进入的容器层数，必须非负；0 只允许标量。
     * @throws IllegalArgumentException maxDepth 为负数。
     * @throws JsonException 语法无效、容器深度超限，或被扫描值的字节预算超限。
     */
    public func skipRawWithDepth(maxDepth: Int64): Unit { reader.skipRawWithDepth(maxDepth) }
    /**
     * 按重复键策略跳过当前 JSON 值，并限制容器深度。
     *
     * 被跳过的对象在 Reject 策略下按解码后的名字检查重复键；本路径不使用 Native 纯语法跳过。未知字段是否允许由生成 codec 在调用前决定，本方法不判断目标类型的字段集合。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param maxDepth 相对于当前生成代码上下文的剩余容器深度，必须非负；标量不占用深度。
     * @throws IllegalArgumentException maxDepth 为负数。
     * @throws JsonException 语法或 UTF-8 无效、出现被拒绝的重复键，或深度及字节预算超限。
     */
    public func skipValue(maxDepth: Int64): Unit { reader.skipValue(maxDepth) }
}
/**
 * 供生成 codec 使用的版本化写入接口。
 *
 * 扩展语义 JsonWriter、批量写入和生成写状态能力。raw 写入沿用核心 writer 的容器状态与输出目标；生成方负责字段分隔、平衡结构及需要的路径管理。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public interface GeneratedSupportV1Writer <: JsonWriter & GeneratedBulkWriterV1 & GeneratedWriteStateV1Owner {
    /**
     * 检查文档完成状态并取得字符串输出。
     *
     * 要求恰有一个完整根值、没有未结束的语义或 raw 容器，并在结束输出后检查字节预算；不关闭调用方流。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前字符串 writer 生成的完整 JSON 文本。
     * @throws JsonException 文档状态不完整、输出超出预算，或此 writer 的输出目标不是字符串。
     * @throws Exception 底层输出目标结束或刷新失败；已有输出不会回滚。
     */
    func finishString(): String
    /**
     * 取得引用当前具体 writer 的版本化写游标。
     *
     * 游标和 writer 共享输出、容器状态和预算，不复制已有输出。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 同一 writer 的 GeneratedSupportV1WriteCursor。
     */
    func generatedCursorV1(): GeneratedSupportV1WriteCursor
    /**
     * 尝试为生成 codec 开始一个紧凑 raw 值。
     *
     * 多行、分隔符后空格或 HTML 安全转义配置不适用时返回 false。成功时先完成语义值前缀处理，再登记等待 raw 内容的值位置；调用方随后负责输出完整值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 允许进入该紧凑路径时为 true；配置不适用时为 false。
     * @throws JsonException 配置适用，但当前 writer 状态不允许开始新值。
     */
    func tryBeginGeneratedCompactRawValue(): Bool
    /**
     * 开始一个 raw 对象并写入开始符。
     *
     * 生成方负责容器内部的名字、逗号和对应结束调用；此方法沿用 writer 的容器深度限制。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 容器深度超限，或当前 writer 不能开始新值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawBeginObject(): Unit
    /**
     * 结束一个 raw 对象并写入结束符。
     *
     * 必须与对象开始调用配对。普通 raw 路径检查容器种类；生成紧凑对象缓冲路径只检查 raw 深度为正，由生成方保证种类配对。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException raw 容器未开始，或当前受检查的容器种类与结束调用不符，错误码为 writer_state。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawEndObject(): Unit
    /**
     * 开始一个 raw 数组并写入开始符。
     *
     * 生成方负责容器内部的名字、逗号和对应结束调用；此方法沿用 writer 的容器深度限制。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 容器深度超限，或当前 writer 不能开始新值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawBeginArray(): Unit
    /**
     * 结束一个 raw 数组并写入结束符。
     *
     * 必须与当前 raw 容器结构配对；生成紧凑对象路径可能只记录容器深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException raw 容器未开始，或当前受检查的容器种类与结束调用不符，错误码为 writer_state。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawEndArray(): Unit
    /**
     * 向 raw 输出直接追加一个字节。
     *
     * 不检查该字节是否组成合法 JSON，也不更新容器种类；供生成代码写入已知分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 由生成代码确认合法的 JSON 语法字节。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawByte(value: Byte): Unit
    /**
     * 在当前 raw 值位置写入 `null`。
     *
     * 沿用 writer 的根值及嵌套值状态；不会增加语义字段或数组项路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawNull(): Unit
    /**
     * 写入对象字段名、冒号及必要的前导逗号。
     *
     * 字段名会按 writer 的字符串规则转义。不自动写入字段值或建立字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param value 要按 JSON 字符串规则转义的字段名。
     * @return false，供调用方将后续字段标记为非首字段。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawObjectEntryName(first: Bool, value: String): Bool
    /**
     * 写入字段名及其 String 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；字符串值按 JSON 规则转义。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 String。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawObjectEntryNameString(first: Bool, name: String, value: String): Bool
    /**
     * 写入字段名及其 Bool 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Bool。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawObjectEntryNameBool(first: Bool, name: String, value: Bool): Bool
    /**
     * 写入字段名及其 Int64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Int64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawObjectEntryNameInt64(first: Bool, name: String, value: Int64): Bool
    /**
     * 写入字段名及其 UInt64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 UInt64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawObjectEntryNameUInt64(first: Bool, name: String, value: UInt64): Bool
    /**
     * 写入字段名及其 Float64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Float64。
     * @return false，供下一字段使用。
     * @throws JsonException 字段值或数组元素包含 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    func writeRawObjectEntryNameFloat64(first: Bool, name: String, value: Float64): Bool
}

/**
 * 生成字段循环复用的版本化结构体写游标。
 *
 * 解析 writer 一次后保留同一 JsonDirectWriter 的引用，避免循环中反复解析接口。结构体包装不另建输出缓冲区；写入仍使用原 writer 的状态、配置及输出目标。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public struct GeneratedSupportV1WriteCursor {
    private let writer: JsonDirectWriter

    init(writer: JsonDirectWriter) { this.writer = writer }
    func generatedWriterV1(): JsonDirectWriter { writer }


    /**
     * 开始一个 raw 对象并写入开始符。
     *
     * 生成方负责容器内部的名字、逗号和对应结束调用；此方法沿用 writer 的容器深度限制。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 容器深度超限，或当前 writer 不能开始新值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawBeginObject(): Unit { writer.writeRawBeginObject() }
    /**
     * 结束一个 raw 对象并写入结束符。
     *
     * 必须与对象开始调用配对。普通 raw 路径检查容器种类；生成紧凑对象缓冲路径只检查 raw 深度为正，由生成方保证种类配对。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException raw 容器未开始，或当前受检查的容器种类与结束调用不符，错误码为 writer_state。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawEndObject(): Unit { writer.writeRawEndObject() }
    /**
     * 开始一个 raw 数组并写入开始符。
     *
     * 生成方负责容器内部的名字、逗号和对应结束调用；此方法沿用 writer 的容器深度限制。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 容器深度超限，或当前 writer 不能开始新值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawBeginArray(): Unit { writer.writeRawBeginArray() }
    /**
     * 结束一个 raw 数组并写入结束符。
     *
     * 必须与当前 raw 容器结构配对；生成紧凑对象路径可能只记录容器深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException raw 容器未开始，或当前受检查的容器种类与结束调用不符，错误码为 writer_state。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawEndArray(): Unit { writer.writeRawEndArray() }
    /**
     * 向 raw 输出直接追加一个字节。
     *
     * 不检查该字节是否组成合法 JSON，也不更新容器种类；供生成代码写入已知分隔符。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 由生成代码确认合法的 JSON 语法字节。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawByte(value: Byte): Unit { writer.writeRawByte(value) }
    /**
     * 在当前 raw 值位置写入 `null`。
     *
     * 沿用 writer 的根值及嵌套值状态；不会增加语义字段或数组项路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawNull(): Unit { writer.writeRawNull() }
    /**
     * 将字符串按 JSON 转义规则写入当前 raw 值位置。
     *
     * 输出包含 JSON 引号，按 writer 配置处理需要转义的字符。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 String 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawString(value: String): Unit { writer.writeRawString(value) }
    /**
     * 将布尔值写为当前 raw JSON 字面量。
     *
     * true 和 false 分别写为相应的小写 JSON 字面量。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Bool 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawBool(value: Bool): Unit { writer.writeRawBool(value) }
    /**
     * 将 Int64 值写为当前 raw JSON 数字。
     *
     * 输出整数十进制文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Int64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawInt64(value: Int64): Unit { writer.writeRawInt64(value) }
    /**
     * 将 Int32 值写为当前 raw JSON 数字。
     *
     * 先无损拓宽为 Int64，再写入数字文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Int32 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawInt32(value: Int32): Unit { writer.writeRawInt64(Int64(value)) }
    /**
     * 将 Int16 值写为当前 raw JSON 数字。
     *
     * 先无损拓宽为 Int64，再写入数字文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Int16 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawInt16(value: Int16): Unit { writer.writeRawInt64(Int64(value)) }
    /**
     * 将 Int8 值写为当前 raw JSON 数字。
     *
     * 先无损拓宽为 Int64，再写入数字文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Int8 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawInt8(value: Int8): Unit { writer.writeRawInt64(Int64(value)) }
    /**
     * 将 UInt64 值写为当前 raw JSON 数字。
     *
     * 输出整数十进制文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 UInt64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawUInt64(value: UInt64): Unit { writer.writeRawUInt64(value) }
    /**
     * 将 UInt32 值写为当前 raw JSON 数字。
     *
     * 先无损拓宽为 UInt64，再写入数字文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 UInt32 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawUInt32(value: UInt32): Unit { writer.writeRawUInt64(UInt64(value)) }
    /**
     * 将 UInt16 值写为当前 raw JSON 数字。
     *
     * 先无损拓宽为 UInt64，再写入数字文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 UInt16 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawUInt16(value: UInt16): Unit { writer.writeRawUInt64(UInt64(value)) }
    /**
     * 将 UInt8 值写为当前 raw JSON 数字。
     *
     * 先无损拓宽为 UInt64，再写入数字文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 UInt8 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawUInt8(value: UInt8): Unit { writer.writeRawUInt64(UInt64(value)) }
    /**
     * 将 Float64 值写为当前 raw JSON 数字。
     *
     * 写入前拒绝 NaN 和无穷大。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Float64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值，或值为 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawFloat64(value: Float64): Unit { writer.writeRawFloat64(value) }
    /**
     * 将 Float32 值写为当前 raw JSON 数字。
     *
     * 先转换为 Float64，再按 Float64 规则输出。写入前拒绝 NaN 和无穷大。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Float32 值。
     * @throws JsonException 当前 writer 状态不允许开始该值，或值为 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawFloat32(value: Float32): Unit { writer.writeRawFloat64(Float64(value)) }
    /**
     * 将 Float16 值写为当前 raw JSON 数字。
     *
     * 先转换为 Float64，再按 Float64 规则输出。写入前拒绝 NaN 和无穷大。沿用原 writer 的输出目标和状态，不自行建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Float16 值。
     * @throws JsonException 当前 writer 状态不允许开始该值，或值为 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawFloat16(value: Float16): Unit { writer.writeRawFloat64(Float64(value)) }
    /**
     * 将已准备的数字文本原样写入 raw 值位置。
     *
     * 本方法不校验 JSON 数字语法；生成方必须提供合法数字文本。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 已校验的 JSON 数字文本。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawNumberLiteral(value: String): Unit { writer.writeRawNumberValue(value) }
    /**
     * 将 Rune 转为字符串后写为 raw JSON 字符串。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Unicode 标量。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawRune(value: Rune): Unit { writer.writeRawString(value.toString()) }
    /**
     * 将 BigInt 的数字文本写入 raw 值位置。
     *
     * 先使用对应的数值格式化函数，再将结果作为数字文本输出，不加 JSON 字符串引号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 BigInt 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawBigInt(value: BigInt): Unit {
        writer.writeRawNumberValue(jsonFastFormatBigInt(value))
    }
    /**
     * 将 Decimal 的数字文本写入 raw 值位置。
     *
     * 先使用对应的数值格式化函数，再将结果作为数字文本输出，不加 JSON 字符串引号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的 Decimal 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawDecimal(value: Decimal): Unit {
        writer.writeRawNumberValue(jsonFastFormatDecimal(value))
    }
    /**
     * 将日期时间格式化为 RFC 3339 后写为 raw JSON 字符串。
     *
     * 常见形状使用专用格式化，其他形状委托 DateTime 的 RFC3339 格式化。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要按 RFC 3339 输出的日期时间。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawRfc3339DateTime(value: DateTime): Unit {
        writer.writeRawString(jsonFastFormatRfc3339DateTime(value))
    }
    /**
     * 为预计的集合输出预留目标容量。
     *
     * count 小于 4 时不操作；否则按 count × 64 + 2 估算字节量，并将容量提示限制为 4096。容量提示不写入 JSON，也不是集合大小或输出预算。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param count 生成代码估算的集合元素数。
     */
    public func reserveRawCollectionCapacity(count: Int64): Unit {
        writer.reserveRawCollectionCapacity(count)
    }
    /**
     * 写入对象字段名、冒号及必要的前导逗号。
     *
     * 字段名会按 writer 的字符串规则转义。不自动写入字段值或建立字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param value 要按 JSON 字符串规则转义的字段名。
     * @return false，供调用方将后续字段标记为非首字段。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryName(first: Bool, value: String): Bool {
        writer.writeRawObjectEntryName(first, value)
    }
    /**
     * 写入字段名及其 String 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；字符串值按 JSON 规则转义。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 String。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryNameString(first: Bool, name: String, value: String): Bool {
        writer.writeRawObjectEntryNameString(first, name, value)
    }
    /**
     * 写入字段名及其 Bool 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Bool。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryNameBool(first: Bool, name: String, value: Bool): Bool {
        writer.writeRawObjectEntryNameBool(first, name, value)
    }
    /**
     * 写入字段名及其 Int64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Int64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryNameInt64(first: Bool, name: String, value: Int64): Bool {
        writer.writeRawObjectEntryNameInt64(first, name, value)
    }
    /**
     * 写入字段名及其 UInt64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 UInt64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryNameUInt64(first: Bool, name: String, value: UInt64): Bool {
        writer.writeRawObjectEntryNameUInt64(first, name, value)
    }
    /**
     * 写入字段名及其 Float64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Float64。
     * @return false，供下一字段使用。
     * @throws JsonException 字段值或数组元素包含 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryNameFloat64(first: Bool, name: String, value: Float64): Bool {
        writer.writeRawObjectEntryNameFloat64(first, name, value)
    }
    /**
     * 写入对象字段名、冒号及必要的前导逗号。
     *
     * 字段名直接写入，不检查或补充 JSON 转义。不自动写入字段值或建立字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @return false，供调用方将后续字段标记为非首字段。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownName(first: Bool, name: String): Bool {
        writer.writeRawObjectEntryKnownName(first, name)
    }
    /**
     * 写入字段名及其 String 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；字符串值按 JSON 规则转义。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param value 作为字段值写入的 String。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameString(first: Bool, name: String, value: String): Bool {
        writer.writeRawObjectEntryKnownNameString(first, name, value)
    }
    /**
     * 写入字段名及其 Bool 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param value 作为字段值写入的 Bool。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameBool(first: Bool, name: String, value: Bool): Bool {
        writer.writeRawObjectEntryKnownNameBool(first, name, value)
    }
    /**
     * 写入字段名及其 Int64 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param value 作为字段值写入的 Int64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameInt64(first: Bool, name: String, value: Int64): Bool {
        writer.writeRawObjectEntryKnownNameInt64(first, name, value)
    }
    /**
     * 写入字段名及其 UInt64 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param value 作为字段值写入的 UInt64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameUInt64(first: Bool, name: String, value: UInt64): Bool {
        writer.writeRawObjectEntryKnownNameUInt64(first, name, value)
    }
    /**
     * 写入字段名及其 Float64 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param value 作为字段值写入的 Float64。
     * @return false，供下一字段使用。
     * @throws JsonException 字段值或数组元素包含 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameFloat64(first: Bool, name: String, value: Float64): Bool {
        writer.writeRawObjectEntryKnownNameFloat64(first, name, value)
    }
    /**
     * 写入字段名及其 Array<Int64> 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。写入前检查新增容器的深度；不为子项自动建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param values 作为字段值写入的 Array<Int64>。
     * @return false，供下一字段使用。
     * @throws JsonException 新增容器超过 writer 的深度上限，错误码为 max_depth。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameInt64Array(
        first: Bool, name: String, values: Array<Int64>
    ): Bool { writer.writeRawObjectEntryKnownNameInt64Array(first, name, values) }
    /**
     * 写入字段名及其 Array<Float64> 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。写入前检查新增容器的深度；不为子项自动建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param values 作为字段值写入的 Array<Float64>。
     * @return false，供下一字段使用。
     * @throws JsonException 字段值或数组元素包含 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws JsonException 新增容器超过 writer 的深度上限，错误码为 max_depth。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameFloat64Array(
        first: Bool, name: String, values: Array<Float64>
    ): Bool { writer.writeRawObjectEntryKnownNameFloat64Array(first, name, values) }
    /**
     * 写入字段名及其 Array<String> 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；字符串值按 JSON 规则转义。写入前检查新增容器的深度；不为子项自动建立语义路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param values 作为字段值写入的 Array<String>。
     * @return false，供下一字段使用。
     * @throws JsonException 新增容器超过 writer 的深度上限，错误码为 max_depth。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameStringArray(
        first: Bool, name: String, values: Array<String>
    ): Bool { writer.writeRawObjectEntryKnownNameStringArray(first, name, values) }
    /**
     * 写入字段名及其 HashMap<String, Int64> 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。写入前检查新增容器的深度；不为子项自动建立语义路径。映射按其迭代顺序输出，不进行排序。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param values 作为字段值写入的 HashMap<String, Int64>。
     * @return false，供下一字段使用。
     * @throws JsonException 新增容器超过 writer 的深度上限，错误码为 max_depth。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameInt64Map(
        first: Bool, name: String, values: HashMap<String, Int64>
    ): Bool { writer.writeRawObjectEntryKnownNameInt64Map(first, name, values) }
    /**
     * 写入字段名及其 HashMap<String, String> 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；字符串值按 JSON 规则转义。写入前检查新增容器的深度；不为子项自动建立语义路径。映射按其迭代顺序输出，不进行排序。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param values 作为字段值写入的 HashMap<String, String>。
     * @return false，供下一字段使用。
     * @throws JsonException 新增容器超过 writer 的深度上限，错误码为 max_depth。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameStringMap(
        first: Bool, name: String, values: HashMap<String, String>
    ): Bool { writer.writeRawObjectEntryKnownNameStringMap(first, name, values) }
    /**
     * 写入字段名及其 HashMap<String, Array<Int64>> 值，并处理字段前逗号。
     *
     * 字段名不经 JSON 转义；数字或布尔元素写为相应的 JSON 字面量。写入前检查新增容器的深度；不为子项自动建立语义路径。映射按其迭代顺序输出，不进行排序。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 无需 JSON 转义的已知字段名；生成方负责保证这一前提。
     * @param values 作为字段值写入的 HashMap<String, Array<Int64>>。
     * @return false，供下一字段使用。
     * @throws JsonException 新增容器超过 writer 的深度上限，错误码为 max_depth。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public func writeRawObjectEntryKnownNameInt64ArrayMap(
        first: Bool, name: String, values: HashMap<String, Array<Int64>>
    ): Bool { writer.writeRawObjectEntryKnownNameInt64ArrayMap(first, name, values) }
}

private class FastSemanticReadContext {
    let objectContext: Bool
    var first = true
    var expectingValue = false

    init(objectContext: Bool) {
        this.objectContext = objectContext
    }
}

// Ordinary/custom codecs reached from a generated fast path keep consuming
// the same runtime-owned cursor. This adapter is internal: it preserves the
// public generated_support.v1 surface while allowing nested capabilities to
// fall back without copying or reparsing the current JSON value.
class FastSemanticReaderAdapter <: JsonReader & GeneratedReadStateV1Owner {
    private let reader: JsonFastReader
    private let contexts = ArrayList<FastSemanticReadContext>()
    private var valuePrefixReady = false

    init(reader: JsonFastReader) {
        this.reader = reader
    }

    public func generatedReadStateV1(): GeneratedReadStateV1 {
        reader.generatedReadStateV1()
    }

    func readConfig(): JsonReadOptions { JsonReadOptions.defaults }

    public func path(): String { generatedReadStateV1().currentPath() }
    public func location(): Option<JsonLocation> { reader.semanticLocation() }
    public func error(message: String, code: String): JsonException {
        reader.semanticError(message, code)
    }

    private func beforeValue(): Unit {
        if (valuePrefixReady) {
            valuePrefixReady = false
            return
        }
        if (contexts.isEmpty()) { return }
        let context = contexts[contexts.size - 1]
        if (context.objectContext) {
            if (!context.expectingValue) {
                throw error("Expected an object field name", "parse_error")
            }
            context.expectingValue = false
        } else {
            reader.beforeRawArrayItem(context.first)
            context.first = false
        }
    }

    public func startObject(): Unit {
        beforeValue()
        reader.startRawObject()
        contexts.add(FastSemanticReadContext(true))
    }

    public func endObject(): Unit {
        if (contexts.isEmpty() || !contexts[contexts.size - 1].objectContext) {
            throw error("Not reading an object", "parse_error")
        }
        if (contexts[contexts.size - 1].expectingValue) {
            throw error("Expected object field value", "parse_error")
        }
        reader.endRawObject()
        contexts.remove(at: contexts.size - 1)
    }

    public func hasObjectField(): Bool {
        if (contexts.isEmpty() || !contexts[contexts.size - 1].objectContext) {
            throw error("Not reading an object", "parse_error")
        }
        let context = contexts[contexts.size - 1]
        if (context.expectingValue) {
            throw error("Expected object field value", "parse_error")
        }
        reader.hasRawObjectField(context.first)
    }

    public func readName(): String {
        if (contexts.isEmpty() || !contexts[contexts.size - 1].objectContext) {
            throw error("Not reading an object", "parse_error")
        }
        let context = contexts[contexts.size - 1]
        if (context.expectingValue) {
            throw error("Expected object field value", "parse_error")
        }
        let name = reader.readRawName(context.first)
        context.first = false
        context.expectingValue = true
        name
    }

    public func startArray(): Unit {
        beforeValue()
        reader.startRawArray()
        contexts.add(FastSemanticReadContext(false))
    }

    public func endArray(): Unit {
        if (contexts.isEmpty() || contexts[contexts.size - 1].objectContext) {
            throw error("Not reading an array", "parse_error")
        }
        reader.endRawArray()
        contexts.remove(at: contexts.size - 1)
    }

    public func hasArrayItem(): Bool {
        if (contexts.isEmpty() || contexts[contexts.size - 1].objectContext) {
            throw error("Not reading an array", "parse_error")
        }
        let context = contexts[contexts.size - 1]
        reader.hasRawArrayItem(context.first)
    }

    public func tryReadNull(): Bool {
        beforeValue()
        if (reader.tryReadRawNull()) { return true }
        valuePrefixReady = true
        false
    }

    public func readNull(): Unit {
        beforeValue()
        if (!reader.tryReadRawNull()) {
            throw error("Expected null", "parse_error")
        }
    }

    public func readBool(): Bool { beforeValue(); reader.readRawBool() }
    public func readString(): String { beforeValue(); reader.readRawString() }
    public func readInt64(): Int64 { beforeValue(); reader.readRawInt64() }
    public func readUInt64(): UInt64 { beforeValue(); reader.readRawUInt64() }
    public func readFloat64(): Float64 { beforeValue(); jsonFastReadFloat64(reader) }
    public func readBigInt(): BigInt { beforeValue(); reader.readRawBigInt() }
    public func readDecimal(): Decimal { beforeValue(); reader.readRawDecimal() }
    public func readNumberLiteral(): String { beforeValue(); reader.readRawNumberLiteral() }

    public func skipValue(): Unit {
        beforeValue()
        reader.skipValue(generatedReadStateV1().remainingDepth())
    }

    public func readNode(): JsonNode {
        match (reader.peekRawKind()) {
            case JsonKind.Null => readNull(); JsonNullValue()
            case JsonKind.Boolean => JsonBoolValue(readBool())
            case JsonKind.String => JsonStringValue(readString())
            case JsonKind.Number => JsonNumberLiteralValue.fromParsedLiteral(readNumberLiteral())
            case JsonKind.Array =>
                let items = ArrayList<JsonNode>()
                startArray()
                while (hasArrayItem()) { items.add(readNode()) }
                endArray()
                JsonArray(items)
            case JsonKind.Object =>
                let fields = HashMap<String, JsonNode>()
                startObject()
                while (hasObjectField()) {
                    let name = readName()
                    fields[name] = readNode()
                }
                endObject()
                JsonObject(fields)
        }
    }

    func readReplayValue(maxBytes: Int64): GeneratedReplayValueV1 {
        if (maxBytes < 0) { throw IllegalArgumentException("maxBytes must not be negative") }
        let start = reader.position()
        let value = readNode()
        if (maxBytes > 0 && reader.position() - start > maxBytes) {
            throw JsonException("Polymorphic JSON object exceeds ${maxBytes} bytes",
                code: "buffered_value_too_large", path: path(), location: location())
        }
        JsonNodeReplayValue(value, readConfig())
    }

    func expectEnd(): Unit { reader.expectEnd() }
}

/**
 * 连接生成 codec 与运行时的第 1 版支持入口。
 *
 * 集中提供协议检查、引擎冻结、reader 与 writer 创建、游标和状态访问，以及嵌套 codec 的能力选择。此版本号用于协议匹配，不承诺跨版本兼容。
 *
 * @group 20-generated-spi 生成代码 SPI
 */
public class GeneratedSupportV1 {
    /**
     * 返回当前生成代码支持协议编号。
     *
     * 该编号用于运行时匹配检查，不表示跨版本源码或二进制兼容承诺。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 当前实现为 1。
     */
    public static func protocolVersion(): Int64 { yJsonGeneratedProtocolVersion() }

    /**
     * 检查生成代码要求的协议是否与运行时一致。
     *
     * 此检查本身不冻结运行时引擎。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param expected 生成代码编译时要求的协议编号。
     * @throws JsonException expected 不等于当前协议编号，错误码为 generated_protocol_mismatch。
     */
    public static func requireProtocolVersion(expected: Int64): Unit {
        let actual = protocolVersion()
        if (actual != expected) {
            throw JsonException(
                "Generated codec protocol mismatch: expected ${expected}, runtime provides ${actual}",
                code: "generated_protocol_mismatch", path: "")
        }
    }

    /**
     * 为公开生成 codec 入口检查协议并冻结运行时引擎选择。
     *
     * 先检查协议 1，再调用运行时冻结逻辑。运行时尚未配置时冻结 Pure；若 Native 已激活则沿用已选引擎。其他线程正在初始化时等待，同线程初始化回调中递归调用会失败。精确 toJson、fromJson 重载及紧凑 raw provider 在访问运行时状态前调用本入口。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @throws JsonException 生成协议不匹配，或在加速初始化所属线程中递归使用 YJson；对应错误码为 generated_protocol_mismatch 或 acceleration_reentrant_use。
     */
    public static func enterGeneratedEntry(): Unit {
        requireProtocolVersion(1)
        freezeYJsonRuntime()
    }

    /**
     * 从 字符串创建默认快速读取器。
     *
     * 先冻结或沿用进程引擎选择；此工厂不检查生成协议编号。使用默认读取配置，创建时不消费值或执行完整 JSON 校验。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param text 要读取的 JSON 字符串。
     * @return 新建的 GeneratedSupportV1Reader。
     * @throws JsonException 在加速初始化所属线程中递归使用 YJson。
     */
    public static func newFastReader(text: String): GeneratedSupportV1Reader {
        freezeYJsonRuntime()
        JsonFastReader(text)
    }
    /**
     * 从 UTF-8 字节创建默认快速读取器。
     *
     * 先冻结或沿用进程引擎选择；此工厂不检查生成协议编号。使用默认读取配置，创建时不消费值或执行完整 JSON 校验。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param bytes 要读取的 UTF-8 JSON 字节；读取期间不得修改此数组。
     * @return 新建的 GeneratedSupportV1Reader。
     * @throws JsonException 在加速初始化所属线程中递归使用 YJson。
     */
    public static func newFastReader(bytes: Array<Byte>): GeneratedSupportV1Reader {
        freezeYJsonRuntime()
        JsonFastReader(bytes)
    }
    /**
     * 冻结运行时引擎选择并创建默认紧凑字符串 writer。
     *
     * 新 writer 使用 JsonWriteOptions.compact；此工厂不检查生成协议编号。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @return 新建的运行时 GeneratedSupportV1Writer。
     * @throws JsonException 在加速初始化所属线程中递归创建 writer，错误码为 acceleration_reentrant_use。
     */
    public static func newWriter(): GeneratedSupportV1Writer {
        freezeYJsonRuntime()
        JsonDirectWriter()
    }
    /**
     * 从版本化 writer 取得其具体写游标。
     *
     * 直接调用 writer.generatedCursorV1，不另建输出或复制状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 提供游标的生成代码 writer。
     * @return 引用同一 writer 的写游标。
     */
    public static func writeCursor(writer: GeneratedSupportV1Writer): GeneratedSupportV1WriteCursor {
        writer.generatedCursorV1()
    }

    /**
     * 将布尔值写为当前 raw JSON 字面量。
     *
     * true 和 false 分别写为相应的小写 JSON 字面量。沿用原 writer 的输出目标和状态，不自行建立语义路径。具体 JsonDirectWriter 直接写入，其他实现通过其版本化游标委托。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该 raw 值的生成代码 writer。
     * @param value 要写入的 Bool 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawBool(writer: GeneratedSupportV1Writer, value: Bool): Unit {
        match (writer) {
            case direct: JsonDirectWriter => direct.writeRawBool(value)
            case _ => writer.generatedCursorV1().writeRawBool(value)
        }
    }
    /**
     * 将 Int64 值写为当前 raw JSON 数字。
     *
     * 输出整数十进制文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。具体 JsonDirectWriter 直接写入，其他实现通过其版本化游标委托。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该 raw 值的生成代码 writer。
     * @param value 要写入的 Int64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawInt64(writer: GeneratedSupportV1Writer, value: Int64): Unit {
        match (writer) {
            case direct: JsonDirectWriter => direct.writeRawInt64(value)
            case _ => writer.generatedCursorV1().writeRawInt64(value)
        }
    }
    /**
     * 将 UInt64 值写为当前 raw JSON 数字。
     *
     * 输出整数十进制文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。具体 JsonDirectWriter 直接写入，其他实现通过其版本化游标委托。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该 raw 值的生成代码 writer。
     * @param value 要写入的 UInt64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawUInt64(writer: GeneratedSupportV1Writer, value: UInt64): Unit {
        match (writer) {
            case direct: JsonDirectWriter => direct.writeRawUInt64(value)
            case _ => writer.generatedCursorV1().writeRawUInt64(value)
        }
    }
    /**
     * 将 Float64 值写为当前 raw JSON 数字。
     *
     * 写入前拒绝 NaN 和无穷大。沿用原 writer 的输出目标和状态，不自行建立语义路径。具体 JsonDirectWriter 直接写入，其他实现通过其版本化游标委托。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该 raw 值的生成代码 writer。
     * @param value 要写入的 Float64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值，或值为 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawFloat64(writer: GeneratedSupportV1Writer, value: Float64): Unit {
        match (writer) {
            case direct: JsonDirectWriter => direct.writeRawFloat64(value)
            case _ => writer.generatedCursorV1().writeRawFloat64(value)
        }
    }
    /**
     * 将字符串按 JSON 转义规则写入当前 raw 值位置。
     *
     * 输出包含 JSON 引号，按 writer 配置处理需要转义的字符。沿用原 writer 的输出目标和状态，不自行建立语义路径。具体 JsonDirectWriter 直接写入，其他实现通过其版本化游标委托。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该 raw 值的生成代码 writer。
     * @param value 要写入的 String 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawString(writer: GeneratedSupportV1Writer, value: String): Unit {
        match (writer) {
            case direct: JsonDirectWriter => direct.writeRawString(value)
            case _ => writer.generatedCursorV1().writeRawString(value)
        }
    }

    /**
     * 将布尔值写为当前 raw JSON 字面量。
     *
     * true 和 false 分别写为相应的小写 JSON 字面量。沿用原 writer 的输出目标和状态，不自行建立语义路径。直接委托传入游标，不重新解析具体 writer。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param cursor 接收该 raw 值的既有写游标。
     * @param value 要写入的 Bool 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawBool(cursor: GeneratedSupportV1WriteCursor, value: Bool): Unit {
        cursor.writeRawBool(value)
    }
    /**
     * 将 Int64 值写为当前 raw JSON 数字。
     *
     * 输出整数十进制文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。直接委托传入游标，不重新解析具体 writer。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param cursor 接收该 raw 值的既有写游标。
     * @param value 要写入的 Int64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawInt64(cursor: GeneratedSupportV1WriteCursor, value: Int64): Unit {
        cursor.writeRawInt64(value)
    }
    /**
     * 将 UInt64 值写为当前 raw JSON 数字。
     *
     * 输出整数十进制文本。沿用原 writer 的输出目标和状态，不自行建立语义路径。直接委托传入游标，不重新解析具体 writer。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param cursor 接收该 raw 值的既有写游标。
     * @param value 要写入的 UInt64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawUInt64(cursor: GeneratedSupportV1WriteCursor, value: UInt64): Unit {
        cursor.writeRawUInt64(value)
    }
    /**
     * 将 Float64 值写为当前 raw JSON 数字。
     *
     * 写入前拒绝 NaN 和无穷大。沿用原 writer 的输出目标和状态，不自行建立语义路径。直接委托传入游标，不重新解析具体 writer。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param cursor 接收该 raw 值的既有写游标。
     * @param value 要写入的 Float64 值。
     * @throws JsonException 当前 writer 状态不允许开始该值，或值为 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawFloat64(cursor: GeneratedSupportV1WriteCursor, value: Float64): Unit {
        cursor.writeRawFloat64(value)
    }
    /**
     * 将字符串按 JSON 转义规则写入当前 raw 值位置。
     *
     * 输出包含 JSON 引号，按 writer 配置处理需要转义的字符。沿用原 writer 的输出目标和状态，不自行建立语义路径。直接委托传入游标，不重新解析具体 writer。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param cursor 接收该 raw 值的既有写游标。
     * @param value 要写入的 String 值。
     * @throws JsonException 当前 writer 状态不允许开始该值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeRawString(cursor: GeneratedSupportV1WriteCursor, value: String): Unit {
        cursor.writeRawString(value)
    }

    /**
     * 取得 writer 提供的生成写状态。
     *
     * 按 GeneratedWriteStateV1Owner 能力取得原状态，调用不会重置其路径或深度。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 实现 GeneratedWriteStateV1Owner 的 writer。
     * @return writer 持有的 GeneratedWriteStateV1。
     * @throws JsonException writer 未实现 GeneratedWriteStateV1Owner，错误码为 codec_contract。
     */
    public static func writeState(writer: JsonWriter): GeneratedWriteStateV1 {
        match (writer) {
            case owner: GeneratedWriteStateV1Owner => owner.generatedWriteStateV1()
            case _ => throw JsonException(
                "JsonWriter is not owned by the yjson runtime",
                code: "codec_contract"
            )
        }
    }

    /**
     * 取得读取器提供的生成读取状态。
     *
     * 返回已有路径及深度状态，不重置读取位置或创建独立遍历。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 提供生成读取状态的语义读取器。
     * @return reader 持有的 GeneratedReadStateV1。
     * @throws JsonException reader 未提供所需状态能力，错误码为 codec_contract。
     */
    public static func readState(reader: JsonReader): GeneratedReadStateV1 {
        match (reader) {
            case owner: GeneratedReadStateV1Owner => owner.generatedReadStateV1()
            case _ => throw JsonException(
                "JsonReader is not owned by the yjson runtime",
                code: "codec_contract"
            )
        }
    }

    /**
     * 取得读取器提供的生成读取状态。
     *
     * 返回已有路径及深度状态，不重置读取位置或创建独立遍历。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 提供生成读取状态的版本化读取器。
     * @return reader 持有的 GeneratedReadStateV1。
     * @throws JsonException reader 未提供所需状态能力，错误码为 generated_protocol_mismatch。
     */
    public static func readState(reader: GeneratedSupportV1Reader): GeneratedReadStateV1 {
        match (reader) {
            case fast: JsonFastReader => fast.generatedReadStateV1()
            case owner: GeneratedReadStateV1Owner => owner.generatedReadStateV1()
            case _ => throw JsonException(
                "Generated reader is not owned by the yjson runtime",
                code: "generated_protocol_mismatch"
            )
        }
    }

    /**
     * 取得受支持语义读取器使用的读取配置。
     *
     * 识别 JsonDirectReader、BackendTapeReaderV1 和快速语义适配器；快速适配器返回默认配置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 运行时支持的语义读取器。
     * @return 该读取器的 JsonReadOptions。
     * @throws JsonException reader 不是上述受支持的读取器，错误码为 codec_contract。
     */
    public static func readOptions(reader: JsonReader): JsonReadOptions {
        match (reader) {
            case direct: JsonDirectReader => direct.readConfig()
            case tape: BackendTapeReaderV1 => tape.readConfig()
            case fast: FastSemanticReaderAdapter => fast.readConfig()
            case _ => throw JsonException(
                "JsonReader is not owned by the yjson runtime",
                code: "codec_contract"
            )
        }
    }

    /**
     * 检查配置是否满足默认快速读取路径的完整条件。
     *
     * 要求未知字段策略为 Ignore、重复键策略为 Reject，并且深度、输入、字符串及捕获值字节上限都等于默认值。生成精确重载据此选择紧凑读取路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param options 要检查的读取配置。
     * @return 所有相关选项均为默认值时返回 true。
     */
    public static func usesDefaultFastReadOptions(options: JsonReadOptions): Bool {
        jsonReadOptionsUsesDefaultFastPath(options)
    }

    /**
     * 消费当前一个值并保存为生成代码可重放的资源。
     *
     * 普通文本读取器和快速语义适配器保存节点，tape 读取器保存捕获的 tape；具体预算按对应读取器的输入位置或 tape 范围计算，已经预校验预算的 tape 可跳过重复检查。结果用完后应关闭。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 支持生成代码重放的运行时语义读取器。
     * @param maxBytes 本次捕获的局部字节上限，必须非负；0 关闭该局部上限。
     * @return 保存当前值及读取配置的 GeneratedReplayValueV1。
     * @throws IllegalArgumentException 受支持的读取器收到负数 maxBytes。
     * @throws JsonException 读取器不支持重放、值读取失败，或捕获超限；对应错误码包括 codec_contract 和 buffered_value_too_large。
     */
    public static func captureValue(reader: JsonReader, maxBytes: Int64): GeneratedReplayValueV1 {
        match (reader) {
            case direct: JsonDirectReader => direct.readReplayValue(maxBytes)
            case tape: BackendTapeReaderV1 => tape.readReplayValue(maxBytes)
            case fast: FastSemanticReaderAdapter => fast.readReplayValue(maxBytes)
            case _ => throw JsonException(
                "JsonReader does not support generated replay",
                code: "codec_contract",
                path: reader.path(),
                location: reader.location()
            )
        }
    }

    /**
     * 要求受支持的语义读取器已经消费完整文档。
     *
     * 文本读取器检查尾部只剩空白，tape 读取器检查根值和容器已完成且数据耗尽；不关闭输入流。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 待检查的运行时语义读取器。
     * @throws JsonException 读取器不受支持，或仍有尾随数据及未完成状态；不支持的读取器使用 codec_contract。
     */
    public static func finishReader(reader: JsonReader): Unit {
        match (reader) {
            case direct: JsonDirectReader => direct.expectEnd()
            case tape: BackendTapeReaderV1 => tape.expectEnd()
            case fast: FastSemanticReaderAdapter => fast.expectEnd()
            case _ => throw JsonException(
                "JsonReader is not owned by the yjson runtime",
                code: "codec_contract"
            )
        }
    }
    /**
     * 从 字符串创建带配置的语义读取器。
     *
     * 先冻结或沿用进程引擎选择；此工厂不检查生成协议编号。创建 JsonDirectReader，并按 config 预检输入资源限制；不消费根值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param text 要读取的 JSON 字符串。
     * @param config 语义读取使用的字段策略及资源预算。
     * @return 新建的 JsonReader。
     * @throws JsonException 在加速初始化所属线程中递归使用 YJson，或输入资源限制预检失败。
     */
    public static func newSemanticReader(text: String, config: JsonReadOptions): JsonReader {
        freezeYJsonRuntime()
        JsonDirectReader(text, config: config)
    }
    /**
     * 从 UTF-8 字节创建带配置的语义读取器。
     *
     * 先冻结或沿用进程引擎选择；此工厂不检查生成协议编号。创建 JsonDirectReader，并按 config 预检输入资源限制；不消费根值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param bytes 要读取的 UTF-8 JSON 字节；读取期间不得修改此数组。
     * @param config 语义读取使用的字段策略及资源预算。
     * @return 新建的 JsonReader。
     * @throws JsonException 在加速初始化所属线程中递归使用 YJson，或输入资源限制预检失败。
     */
    public static func newSemanticReader(bytes: Array<Byte>, config: JsonReadOptions): JsonReader {
        freezeYJsonRuntime()
        JsonDirectReader(bytes, config: config)
    }

    /**
     * 使用指定 codec 在当前生成 writer 中写入嵌套值。
     *
     * codec 实现 GeneratedDirectWriteCodecV1 时调用 writeDirect，否则调用普通 write；本方法不结束文档。codec 和输出目标抛出的异常原样传播。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param codec 负责该嵌套类型的 codec。
     * @param value 要写入的值。
     * @param writer 承接当前嵌套值的生成代码 writer。
     * @throws Exception 所选 codec 或输出目标写入失败；本桥接原样传播异常。
     */
    public static func writeNested<T>(codec: JsonCodec<T>, value: T, writer: GeneratedSupportV1Writer): Unit {
        writeJsonDirectWith(codec, value, writer)
    }

    /**
     * 将节点树写入给定语义 writer。
     *
     * 递归按节点类型调用 writer，并检查循环节点引用。不结束文档；writer 和 codec 的异常继续向外传播。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的节点树。
     * @param writer 接收该值的语义 writer。
     * @throws JsonException 节点图包含循环引用，或节点值及 writer 状态不允许写入；循环引用使用 cyclic_json_node。
     * @throws Exception 目标 writer 或所选 codec 的写入失败；本桥接原样传播异常。
     */
    public static func writeValue(value: JsonNode, writer: JsonWriter): Unit {
        writeJsonNodeToCodecWriter(writer, value)
    }

    /**
     * 将生成 codec 支持的值写入给定语义 writer。
     *
     * 查询 T 的 GeneratedCodecProviderV1 codec，再直接调用其 write。不结束文档；writer 和 codec 的异常继续向外传播。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要写入的T 值。
     * @param writer 接收该值的语义 writer。
     * @throws Exception 目标 writer 或所选 codec 的写入失败；本桥接原样传播异常。
     */
    public static func writeValue<T>(value: T, writer: JsonWriter): Unit
        where T <: GeneratedCodecProviderV1<T> {
        generatedCodecV1Of<T>().write(value, writer)
    }

    /**
     * 原样返回现有 JSON 节点。
     *
     * 不复制节点；返回值与参数共享同一可变节点对象。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要原样返回的节点。
     * @return 传入的同一 JsonNode。
     */
    public static func nodeValue(value: JsonNode): JsonNode { value }
    /**
     * 将布尔值包装为 JSON 布尔节点。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要包装的布尔值。
     * @return 保存该值的新布尔节点。
     */
    public static func nodeValue(value: Bool): JsonNode { JsonBoolValue(value) }
    /**
     * 将 Int64 包装为 JSON 整数节点。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要包装的 Int64 值。
     * @return 保存该值的新整数节点。
     */
    public static func nodeValue(value: Int64): JsonNode { JsonIntValue(value) }
    /**
     * 将 Float64 包装为 JSON 浮点节点。
     *
     * 构造时不检查有限值；后续序列化仍会拒绝 NaN 和无穷大。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要包装的 Float64 值。
     * @return 保存该值的新浮点节点。
     */
    public static func nodeValue(value: Float64): JsonNode { JsonFloatValue(value) }
    /**
     * 将 Rune 转为字符串并包装为 JSON 字符串节点。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要包装的 Unicode 标量。
     * @return 保存该标量字符串的新节点。
     */
    public static func nodeValue(value: Rune): JsonNode { JsonStringValue(value.toString()) }
    /**
     * 将字符串包装为 JSON 字符串节点。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 要包装的字符串。
     * @return 保存该字符串的新节点。
     */
    public static func nodeValue(value: String): JsonNode { JsonStringValue(value) }
    /**
     * 将节点数组包装为 JSON 数组节点。
     *
     * 复制外层数组到可变列表，保留各子节点引用；不深复制子节点。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 按原顺序保存的子节点数组。
     * @return 新建的 JsonArray。
     */
    public static func nodeValue(value: Array<JsonNode>): JsonNode { JsonArray(value) }
    /**
     * 将生成 codec 支持的值转换为 JSON 节点树。
     *
     * 先用 YJson.toJson 序列化，再用 JsonNode.parse 解析为新树；不是引用包装。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param value 需要按生成 codec 序列化的 T 值。
     * @return 序列化结果解析得到的新节点树。
     * @throws JsonException 生成协议、运行时初始化、序列化、资源预算或随后解析失败。
     */
    public static func nodeValue<T>(value: T): JsonNode where T <: GeneratedCodecProviderV1<T> {
        JsonNode.parse(YJson.toJson(value))
    }

    /**
     * 按 codec 支持的读取能力从当前生成读取器解码值。
     *
     * 依次优先使用具体快速读取能力、GeneratedCodecV1 的 readFast；均不适用时，以共享同一输入位置的语义适配器调用普通 codec.read，不复制并重解析当前值。codec 异常原样传播。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param codec 负责结果类型的 codec。
     * @param reader 输入位置已经就绪的生成代码读取器。
     * @return codec 解码得到的 T 值。
     * @throws JsonException 需要具体快速读取器或语义适配器时，reader 不是 JsonFastReader，错误码为 generated_protocol_mismatch。
     * @throws Exception 所选 codec 的读取调用失败；本桥接原样传播 codec 异常。
     */
    public static func readWith<T>(codec: JsonCodec<T>, reader: GeneratedSupportV1Reader): T {
        readJsonNestedFastWith(codec, reader)
    }

    /**
     * 解析生成读取器的具体实现并取得读游标。
     *
     * 只接受 JsonFastReader；新游标共享其输入位置和生成读取状态。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 运行时的 JsonFastReader，以版本化读取接口传入。
     * @return 引用该读取器的 GeneratedSupportV1ReadCursor。
     * @throws JsonException reader 不是 JsonFastReader，错误码为 generated_protocol_mismatch。
     */
    public static func readCursor(reader: GeneratedSupportV1Reader): GeneratedSupportV1ReadCursor {
        GeneratedSupportV1ReadCursor(yJsonGeneratedReaderV1(reader))
    }

    /**
     * 将版本化生成读取接口解析为具体 JsonFastReader。
     *
     * 返回同一读取器，不创建新 parser 或重置输入位置。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param reader 要解析的生成代码读取器。
     * @return 传入的 JsonFastReader。
     * @throws JsonException reader 不是 JsonFastReader，错误码为 generated_protocol_mismatch。
     */
    public static func readFastReader(reader: GeneratedSupportV1Reader): JsonFastReader {
        yJsonGeneratedReaderV1(reader)
    }

    /**
     * 使用已经缓存的 codec 能力选择嵌套读取路径。
     *
     * fastCodec 为 Some 时优先使用其中的具体快速读取能力，否则调用其 readFast。fastCodec 为 None 时检查 codec 的游标读取能力，再回退到共享输入位置的语义适配器。codec 异常原样传播。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param fastCodec 预先解析的快速读取能力；None 表示继续检查普通 codec。
     * @param codec 游标能力检查及语义回退使用的 codec。
     * @param reader 当前值所在的运行时生成读取器。
     * @return 选定读取路径解码得到的 T 值。
     * @throws JsonException 所选路径需要具体读取器但 reader 不是 JsonFastReader，错误码为 generated_protocol_mismatch。
     * @throws Exception 所选 codec 的读取调用失败；本桥接原样传播 codec 异常。
     */
    public static func readWithCached<T>(fastCodec: Option<GeneratedCodecV1<T>>,
        codec: JsonCodec<T>, reader: GeneratedSupportV1Reader): T {
        match (fastCodec) {
            case Some(fast) =>
                match (fast) {
                    case direct: GeneratedDirectFastReadCodecV1<T> =>
                        direct.readFastDirect(yJsonGeneratedReaderV1(reader))
                    case _ => fast.readFast(reader)
                }
            case None =>
                match (codec) {
                    case cursor: GeneratedCursorReadCodecV1<T> =>
                        cursor.readFastWithCursor(reader, readCursor(reader))
                    case _ => codec.read(yJsonSemanticReaderV1(reader))
                }
        }
    }

    /**
     * 优先使用缓存的游标 codec 和已有读游标解码值。
     *
     * cursorCodec 为 Some 时直接调用 readFastWithCursor；为 None 时委托 readWithCached。调用方必须让 cursor 与 reader 来自同一读取器，本方法不检查二者的对应关系。codec 异常原样传播。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param cursorCodec 预先解析的游标读取能力。
     * @param fastCodec 没有游标能力时传给 readWithCached 的快速读取能力。
     * @param codec 能力回退使用的普通 codec。
     * @param reader 当前值所在的生成代码读取器。
     * @param cursor 从同一 reader 取得的读游标。
     * @return 选定 codec 解码得到的 T 值。
     * @throws JsonException 回退路径需要具体读取器但 reader 不是 JsonFastReader，错误码为 generated_protocol_mismatch。
     * @throws Exception 所选 codec 的读取调用失败；本桥接原样传播 codec 异常。
     */
    public static func readWithCursorCached<T>(cursorCodec: Option<GeneratedCursorReadCodecV1<T>>,
        fastCodec: Option<GeneratedCodecV1<T>>, codec: JsonCodec<T>,
        reader: GeneratedSupportV1Reader, cursor: GeneratedSupportV1ReadCursor): T {
        match (cursorCodec) {
            case Some(fast) => fast.readFastWithCursor(reader, cursor)
            case None => readWithCached(fastCodec, codec, reader)
        }
    }

    /**
     * 尝试为生成 codec 开始一个紧凑 raw 值。
     *
     * 多行、分隔符后空格或 HTML 安全转义配置不适用时返回 false。成功时先完成语义值前缀处理，再登记等待 raw 内容的值位置；调用方随后负责输出完整值。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 准备开始紧凑 raw 值的生成代码 writer。
     * @return 允许进入该紧凑路径时为 true；配置不适用时为 false。
     * @throws JsonException 配置适用，但当前 writer 状态不允许开始新值。
     */
    public static func tryBeginCompactValue(writer: GeneratedSupportV1Writer): Bool {
        jsonTryBeginGeneratedCompactRawValue(writer)
    }
    /**
     * 开始一个 raw 对象并写入开始符。
     *
     * 生成方负责容器内部的名字、逗号和对应结束调用；此方法沿用 writer 的容器深度限制。直接委托版本化 writer，不另行选择紧凑路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 承接已选定紧凑 raw 路径的生成代码 writer。
     * @throws JsonException 容器深度超限，或当前 writer 不能开始新值。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactObjectBegin(writer: GeneratedSupportV1Writer): Unit {
        jsonWriteGeneratedCompactObjectBegin(writer)
    }
    /**
     * 结束一个 raw 对象并写入结束符。
     *
     * 必须与对象开始调用配对。普通 raw 路径检查容器种类；生成紧凑对象缓冲路径只检查 raw 深度为正，由生成方保证种类配对。直接委托版本化 writer，不另行选择紧凑路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 承接已选定紧凑 raw 路径的生成代码 writer。
     * @throws JsonException raw 容器未开始，或当前受检查的容器种类与结束调用不符，错误码为 writer_state。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactObjectEnd(writer: GeneratedSupportV1Writer): Unit {
        jsonWriteGeneratedCompactObjectEnd(writer)
    }
    /**
     * 写入字段名及其 String 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；字符串值按 JSON 规则转义。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该紧凑对象字段的生成代码 writer。
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 String。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactEntryString(writer: GeneratedSupportV1Writer, first: Bool,
        name: String, value: String): Bool {
        jsonWriteGeneratedCompactObjectEntryString(writer, first, name, value)
    }
    /**
     * 写入字段名及其 Bool 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该紧凑对象字段的生成代码 writer。
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Bool。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactEntryBool(writer: GeneratedSupportV1Writer, first: Bool,
        name: String, value: Bool): Bool {
        jsonWriteGeneratedCompactObjectEntryBool(writer, first, name, value)
    }
    /**
     * 写入字段名及其 Int64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该紧凑对象字段的生成代码 writer。
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Int64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactEntryInt64(writer: GeneratedSupportV1Writer, first: Bool,
        name: String, value: Int64): Bool {
        jsonWriteGeneratedCompactObjectEntryInt64(writer, first, name, value)
    }
    /**
     * 写入字段名及其 UInt64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该紧凑对象字段的生成代码 writer。
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 UInt64。
     * @return false，供下一字段使用。
     * @throws JsonException 流输出目标超过字节预算，错误码为 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactEntryUInt64(writer: GeneratedSupportV1Writer, first: Bool,
        name: String, value: UInt64): Bool {
        jsonWriteGeneratedCompactObjectEntryUInt64(writer, first, name, value)
    }
    /**
     * 写入字段名及其 Float64 值，并处理字段前逗号。
     *
     * 字段名按 JSON 字符串规则转义；数字或布尔元素写为相应的 JSON 字面量。不自动维护字段路径。
     *
     * @group 20-generated-spi 生成代码 SPI
     * @param writer 接收该紧凑对象字段的生成代码 writer。
     * @param first 是否为对象首字段；false 时先写入逗号。
     * @param name 要按 JSON 字符串规则转义的字段名。
     * @param value 作为字段值写入的 Float64。
     * @return false，供下一字段使用。
     * @throws JsonException 字段值或数组元素包含 NaN 或无穷大。 流输出目标超过字节预算时也会使用 output_too_large。
     * @throws Exception 输出目标为流时，底层流写入异常原样传播；失败前可能已有部分输出。
     */
    public static func writeCompactEntryFloat64(writer: GeneratedSupportV1Writer, first: Bool,
        name: String, value: Float64): Bool {
        jsonWriteGeneratedCompactObjectEntryFloat64(writer, first, name, value)
    }
}

func yJsonGeneratedReaderV1(reader: GeneratedSupportV1Reader): JsonFastReader {
    match (reader) {
        case concrete: JsonFastReader => concrete
        case _ => throw JsonException("Unsupported generated reader implementation",
            code: "generated_protocol_mismatch", path: "")
    }
}

func yJsonSemanticReaderV1(reader: GeneratedSupportV1Reader): JsonReader {
    match (reader) {
        case concrete: JsonFastReader => FastSemanticReaderAdapter(concrete)
        case _ => throw JsonException("Unsupported generated reader implementation",
            code: "generated_protocol_mismatch", path: "")
    }
}

func yJsonTryReadNativeInt64ArrayListV1(
    reader: GeneratedSupportV1Reader
): Option<ArrayList<Int64>> {
    yJsonGeneratedReaderV1(reader).tryReadNativeInt64ArrayList()
}

func yJsonGeneratedWriterV1(writer: GeneratedSupportV1Writer): JsonDirectWriter {
    match (writer) {
        case concrete: JsonDirectWriter => concrete
        case _ => throw JsonException("Unsupported generated writer implementation",
            code: "generated_protocol_mismatch", path: "")
    }
}
