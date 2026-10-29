package yjson_algorithms

import yjson.*

import std.collection.*
import std.convert.Parsable

func jsonPointerError(message: String, pointer: String,
    code!: String = "invalid_json_pointer"): JsonException {
    let path = if (pointer.isEmpty() || pointer.startsWith("/")) { pointer } else { "" }
    JsonException(message, code: code, path: path)
}

/**
 * 不可变的 RFC 6901 JSON Pointer；空字符串表示根，令牌中的 `~0` 和 `~1` 分别表示 `~` 和 `/`。
 *
 * @group 10-application 应用 API
 */
public class JsonPointer <: ToString {
    private let source: String
    private let segments: Array<String>

    private init(source: String, segments: Array<String>) {
        this.source = source
        this.segments = segments
    }

    /**
     * 解析 JSON Pointer 字符串，不访问 JSON 文档。
     *
     * @param pointer 空字符串，或以 `/` 开头且转义合法的指针。
     * @return 保留原始指针文本的不可变指针。
     * @throws JsonException 指针格式或 `~` 转义无效，错误码为 `invalid_json_pointer`。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let pointer = JsonPointer.parse("/a~1b/0")
     * println(pointer.tokens()[0])
     * ```
     * ```output
     * a/b
     * ```
     * @group 10-application 应用 API
     */
    public static func parse(pointer: String): JsonPointer {
        JsonPointer(pointer, parseJsonPointerSegments(pointer))
    }

    /**
     * 解析以 `#` 开头的 URI 片段，先解码百分号转义，再解析 JSON Pointer。
     *
     * @param fragment 包含 `#` 前缀的 UTF-8 URI 片段。
     * @return 解码后的不可变指针。
     * @throws JsonException 缺少 `#`、百分号转义不合法、UTF-8 无效或指针格式无效。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let pointer = JsonPointer.parseUriFragment("#/a%20b")
     * println(pointer.tokens()[0])
     * ```
     * ```output
     * a b
     * ```
     * @group 10-application 应用 API
     */
    public static func parseUriFragment(fragment: String): JsonPointer {
        if (!fragment.startsWith("#")) {
            throw jsonPointerError("JSON Pointer URI fragment must start with '#'", fragment)
        }
        let decoded = decodeJsonPointerFragment(fragment[1..fragment.size], fragment)
        JsonPointer(decoded, parseJsonPointerSegments(decoded))
    }

    /**
     * 返回已经解码的路径令牌副本；修改返回数组不影响指针。
     *
     * @return 按从根到目标顺序排列的令牌，根指针返回空数组。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let tokens = JsonPointer.parse("/a~0b/c").tokens()
     * println(tokens[0])
     * println(tokens[1])
     * ```
     * ```output
     * a~b
     * c
     * ```
     * @group 10-application 应用 API
     */
    public func tokens(): Array<String> {
        let result = ArrayList<String>(segments.size)
        for (segment in segments) { result.add(segment) }
        result.toArray()
    }

    /**
     * 判断指针是否指向文档根。
     *
     * @return 指针没有路径令牌时为 `true`。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * println(JsonPointer.parse("").isRoot())
     * println(JsonPointer.parse("/").isRoot())
     * ```
     * ```output
     * true
     * false
     * ```
     * @group 10-application 应用 API
     */
    public func isRoot(): Bool { segments.isEmpty() }

    /**
     * 返回解析时的 JSON Pointer 文本；URI 片段输入返回解码后的文本。
     *
     * @return 不包含 URI 片段 `#` 前缀的指针。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * println(JsonPointer.parseUriFragment("#/a%20b").toString())
     * ```
     * ```output
     * /a b
     * ```
     * @group 10-application 应用 API
     */
    public func toString(): String { source }

    /**
     * 将指针编码为 URI 片段，保留 `/` 和 `~`，其余必要字节使用大写百分号转义。
     *
     * @return 以 `#` 开头的 UTF-8 URI 片段。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * println(JsonPointer.parse("/a b").toUriFragment())
     * ```
     * ```output
     * #/a%20b
     * ```
     * @group 10-application 应用 API
     */
    public func toUriFragment(): String {
        let bytes = unsafe { source.rawData() }
        let builder = StringBuilder()
        builder.append("#")
        for (value in bytes) {
            let unsigned = UInt8(value)
            if (jsonPointerUriByteIsUnreserved(unsigned) || value == b'/' || value == b'~') {
                builder.append(Rune(unsigned))
            } else {
                builder.append("%")
                builder.append(jsonPointerHexDigit(Int64(unsigned >> 4)))
                builder.append(jsonPointerHexDigit(Int64(unsigned & 0x0Fu8)))
            }
        }
        builder.toString()
    }

    /**
     * 查找目标；成员缺失、数组下标无效或中途遇到标量时返回 `None`。
     *
     * @param root 查询起点；结果视图仍引用该起点的底层存储。
     * @return 目标的只读视图；根指针返回输入根。
     *
     * @example 查询树和文档（profile: algorithms） {run}
     * ```cangjie
     * let pointer = JsonPointer.parse("/items/0")
     * let root = JsonNode.parse("{\"items\":[7]}")
     * let document = YJson.parseDocument("{\"items\":[7]}")
     * println(pointer.find(root).getOrThrow().asInt64())
     * println(pointer.find(document).getOrThrow().asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func find(root: JsonValueView): Option<JsonValueView> {
        var current: JsonValueView = root
        for (segment in segments) {
            match (current.kind()) {
                case JsonKind.Object =>
                    match (current.member(segment)) {
                        case Some(next) => current = next
                        case None => return None<JsonValueView>
                    }
                case JsonKind.Array =>
                    match (parseJsonPointerArrayIndex(segment, current.size(), false)) {
                        case Some(index) => current = current.element(index).getOrThrow()
                        case None => return None<JsonValueView>
                    }
                case _ => return None<JsonValueView>
            }
        }
        Some(current)
    }

    /**
     * 查找目标；成员缺失、数组下标无效或中途遇到标量时返回 `None`。
     *
     * @param document 提供查询根视图的托管文档。
     * @return 目标的只读视图；根指针返回输入根。
     *
     * @example 查询树和文档（profile: algorithms） {run}
     * ```cangjie
     * let pointer = JsonPointer.parse("/items/0")
     * let root = JsonNode.parse("{\"items\":[7]}")
     * let document = YJson.parseDocument("{\"items\":[7]}")
     * println(pointer.find(root).getOrThrow().asInt64())
     * println(pointer.find(document).getOrThrow().asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func find(document: JsonDocument): Option<JsonValueView> { find(document.root()) }

    /**
     * 取得指针目标，目标不存在时抛出带指针路径的异常。
     *
     * @param root 查询起点；返回视图保留该起点的存储依赖。
     * @return 目标的只读视图。
     * @throws JsonException 目标不存在，错误码为 `json_pointer_not_found`。
     *
     * @example 取得树和文档中的值（profile: algorithms） {run}
     * ```cangjie
     * let pointer = JsonPointer.parse("/items/0")
     * let root = JsonNode.parse("{\"items\":[7]}")
     * let document = YJson.parseDocument("{\"items\":[7]}")
     * println(pointer.evaluate(root).asInt64())
     * println(pointer.evaluate(document).asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func evaluate(root: JsonValueView): JsonValueView {
        find(root).getOrThrow({ =>
            jsonPointerError("JSON Pointer target does not exist: ${source}", source,
                code: "json_pointer_not_found")
        })
    }

    /**
     * 取得指针目标，目标不存在时抛出带指针路径的异常。
     *
     * @param document 提供查询根视图的托管文档。
     * @return 目标的只读视图。
     * @throws JsonException 目标不存在，错误码为 `json_pointer_not_found`。
     *
     * @example 取得树和文档中的值（profile: algorithms） {run}
     * ```cangjie
     * let pointer = JsonPointer.parse("/items/0")
     * let root = JsonNode.parse("{\"items\":[7]}")
     * let document = YJson.parseDocument("{\"items\":[7]}")
     * println(pointer.evaluate(root).asInt64())
     * println(pointer.evaluate(document).asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func evaluate(document: JsonDocument): JsonValueView { evaluate(document.root()) }

    func rawTokens(): Array<String> { segments }
}

private func parseJsonPointerSegments(pointer: String): Array<String> {
    if (pointer.isEmpty()) { return Array<String>() }
    if (!pointer.startsWith("/")) {
        throw jsonPointerError("JSON Pointer must be empty or start with '/'", pointer)
    }
    let result = ArrayList<String>()
    var start: Int64 = 1
    while (start <= pointer.size) {
        var end = start
        while (end < pointer.size && pointer[end] != b'/') { end++ }
        result.add(unescapeJsonPointerToken(pointer[start..end], pointer))
        start = end + 1
    }
    result.toArray()
}

private func unescapeJsonPointerToken(token: String, pointer: String): String {
    let builder = StringBuilder()
    var start: Int64 = 0
    var index: Int64 = 0
    while (index < token.size) {
        if (token[index] == b'~') {
            if (start < index) { builder.append(token[start..index]) }
            if (index + 1 >= token.size) {
                throw jsonPointerError("Incomplete '~' escape in JSON Pointer", pointer)
            }
            match (token[index + 1]) {
                case b'0' => builder.append("~")
                case b'1' => builder.append("/")
                case _ => throw jsonPointerError("Invalid '~' escape in JSON Pointer", pointer)
            }
            index += 2
            start = index
        } else {
            index++
        }
    }
    if (start < token.size) { builder.append(token[start..token.size]) }
    builder.toString()
}

private func decodeJsonPointerFragment(encoded: String, original: String): String {
    let result = ArrayList<Byte>()
    let bytes = unsafe { encoded.rawData() }
    var index: Int64 = 0
    while (index < bytes.size) {
        if (bytes[index] == b'%') {
            if (index + 2 >= bytes.size) {
                throw jsonPointerError("Incomplete percent escape in JSON Pointer URI fragment", original)
            }
            let high = jsonPointerHexValue(bytes[index + 1])
            let low = jsonPointerHexValue(bytes[index + 2])
            if (high < 0 || low < 0) {
                throw jsonPointerError("Invalid percent escape in JSON Pointer URI fragment", original)
            }
            result.add(UInt8(high * 16 + low))
            index += 3
        } else {
            result.add(bytes[index])
            index++
        }
    }
    try {
        String.fromUtf8(result.toArray())
    } catch (_: Exception) {
        throw jsonPointerError("JSON Pointer URI fragment is not valid UTF-8", original)
    }
}

private func jsonPointerHexValue(value: Byte): Int64 {
    match {
        case value >= b'0' && value <= b'9' => Int64(value - b'0')
        case value >= b'a' && value <= b'f' => Int64(value - b'a') + 10
        case value >= b'A' && value <= b'F' => Int64(value - b'A') + 10
        case _ => -1
    }
}

private func jsonPointerHexDigit(value: Int64): String {
    "0123456789ABCDEF"[value..value + 1]
}

private func jsonPointerUriByteIsUnreserved(value: UInt8): Bool {
    (value >= 0x41u8 && value <= 0x5Au8) ||
    (value >= 0x61u8 && value <= 0x7Au8) ||
    (value >= 0x30u8 && value <= 0x39u8) || value == 0x2Du8 || value == 0x2Eu8 ||
    value == 0x5Fu8 || value == 0x7Eu8
}

func parseJsonPointerArrayIndex(token: String, size: Int64, allowAppend: Bool): Option<Int64> {
    if (allowAppend && token == "-") { return Some(size) }
    if (token.isEmpty() || (token.size > 1 && token[0] == b'0')) { return None<Int64> }
    for (byte in unsafe { token.rawData() }) {
        if (byte < b'0' || byte > b'9') { return None<Int64> }
    }
    try {
        let index = Int64.parse(token)
        if (index < 0 || index >= size + (if (allowAppend) { 1 } else { 0 })) {
            None<Int64>
        } else {
            Some(index)
        }
    } catch (_: Exception) {
        None<Int64>
    }
}

func jsonPointerParent(root: JsonNode, pointer: JsonPointer): (JsonNode, String) {
    let segments = pointer.rawTokens()
    if (segments.isEmpty()) {
        throw jsonPointerError("Root JSON Pointer has no parent", pointer.toString(),
            code: "json_pointer_not_found")
    }
    var current = root
    for (index in 0..segments.size - 1) {
        let token = segments[index]
        match (current) {
            case objectValue: JsonObject =>
                current = objectValue.get(token).getOrThrow({ =>
                    jsonPointerError("JSON Pointer parent does not exist", pointer.toString(),
                        code: "json_pointer_not_found")
                })
            case arrayValue: JsonArray =>
                let childIndex = parseJsonPointerArrayIndex(token, arrayValue.size(), false).getOrThrow({ =>
                    jsonPointerError("Invalid JSON Pointer array index '${token}'", pointer.toString(),
                        code: "json_pointer_not_found")
                })
                current = arrayValue[childIndex]
            case _ => throw jsonPointerError("JSON Pointer parent is not a container", pointer.toString(),
                code: "json_pointer_not_found")
        }
    }
    (current, segments[segments.size - 1])
}
