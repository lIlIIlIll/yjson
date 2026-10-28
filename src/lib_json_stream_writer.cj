package yjson

import std.io.*

/**
 * 不可变的 JSON 格式与输出资源限制。
 *
 * 默认紧凑输出。缩进只能包含空格和制表符，空串表示紧凑格式；maxOutputBytes 为 0 表示不限制，maxDepth 始终必须为正数。
 */
public class JsonWriteOptions {
    /**
     * 每层缩进；空串表示紧凑格式。
     */
    public let indent: String
    /**
     * 是否额外转义 HTML 敏感字符。
     */
    public let htmlSafe: Bool
    /**
     * 本次输出的 UTF-8 字节上限；0 表示不限制。
     */
    public let maxOutputBytes: Int64
    /**
     * 允许写出的数组和对象嵌套层数上限。
     */
    public let maxDepth: Int64
    let newline: String
    let useSpaceAfterSeparators: Bool

    /**
     * 创建可共享的不可变写出配置。
     *
     * @param indent 每层缩进，只含空格和制表符；默认空串。
     * @param htmlSafe 是否额外转义 HTML 敏感字符，默认 false。
     * @param maxOutputBytes 输出字节上限，默认 0 不限制；不允许负数。
     * @param maxDepth 正数容器深度上限，默认 256。
     * @throws IllegalArgumentException 缩进含其他字符、字节上限为负或深度非正。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let options = JsonWriteOptions(indent: " ", htmlSafe: true, maxOutputBytes: 64, maxDepth: 2)
     * let json = JsonNode.array([JsonNode.int64(1)]).toJson(options: options)
     * println(json.contains("\n") && options.htmlSafe && options.maxDepth == 2)
     * ```
     * ```output
     * true
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * var rejected = false
     * try { let _ = JsonWriteOptions(indent: "-") } catch (_: IllegalArgumentException) { rejected = true }
     * println(rejected)
     * ```
     * ```output
     * true
     * ```
     */
    public init(
        indent!: String = "",
        htmlSafe!: Bool = false,
        maxOutputBytes!: Int64 = 0,
        maxDepth!: Int64 = 256
    ) {
        if (maxDepth <= 0) { throw IllegalArgumentException("maxDepth must be positive") }
        if (maxOutputBytes < 0) { throw IllegalArgumentException("maxOutputBytes must not be negative") }
        validateJsonIndent(indent)
        this.indent = indent
        this.htmlSafe = htmlSafe
        this.maxOutputBytes = maxOutputBytes
        this.maxDepth = maxDepth
        this.newline = if (indent.isEmpty()) { "" } else { "\n" }
        this.useSpaceAfterSeparators = !indent.isEmpty()
    }

    /**
     * 共享的默认紧凑格式配置，深度上限 256，输出字节数不设上限。
     */
    public static let defaults: JsonWriteOptions = JsonWriteOptions()
    /**
     * 紧凑格式预设；与 defaults 使用相同的格式和资源默认值。
     */
    public static let compact: JsonWriteOptions = JsonWriteOptions()

    /**
     * 创建指定缩进的写出配置，其他选项使用默认值。
     *
     * @param indent 只含空格和制表符的缩进，默认两个空格；空串表示紧凑格式。
     * @return 不启用 HTML 转义、输出字节不限、深度上限 256 的配置。
     * @throws IllegalArgumentException indent 含其他字符。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let node = JsonNode.array([JsonNode.int64(1)])
     * println(node.toJson(options: JsonWriteOptions.pretty(indent: " ")).contains("\n"))
     * ```
     * ```output
     * true
     * ```
     */
    public static func pretty(indent!: String = "  "): JsonWriteOptions {
        JsonWriteOptions(indent: indent)
    }

    /**
     * 启用 HTML 敏感字符转义的紧凑格式预设。
     */
    public static let htmlSafePreset: JsonWriteOptions = JsonWriteOptions(htmlSafe: true)
}

private func validateJsonIndent(indent: String): Unit {
    for (value in indent.toRuneArray()) {
        if (value != r' ' && value != r'\t') {
            throw IllegalArgumentException("indent may contain only spaces or tabs")
        }
    }
}

func writeJsonValueToString(value: JsonNode, options: JsonWriteOptions): String {
    freezeYJsonRuntime()
    let writer = JsonDirectWriter(options)
    writeJsonNodeToCodecWriter(writer, value)
    writer.finishString()
}

func writeJsonValueToStream(value: JsonNode, out: OutputStream, options: JsonWriteOptions): Unit {
    freezeYJsonRuntime()
    let writer = JsonDirectWriter(out, config: options)
    writeJsonNodeToCodecWriter(writer, value)
    writer.finish()
}
