package yjson_yyjson

import std.io.*
import yjson.*
import yjson_backends.*

private let YYJSON_METADATA = JsonBackendMetadata(
    "yyjson",
    "0.12.0",
    true,
    JsonStreamBufferingMode.WholeDocument,
    JsonStreamBufferingMode.WholeDocument
)

private let YYJSON_FALLBACK_METADATA = JsonBackendMetadata(
    "custom-native-fallback",
    "0.2.0",
    true,
    JsonStreamBufferingMode.WholeDocument,
    JsonStreamBufferingMode.WholeDocument
)

/**
 * yyjson 的命名 JSON 后端入口，提供类型化读写和显式资源文档。
 *
 * 通过 `YyjsonBackends.yyjson` 取得共享入口；入口本身不持有单份文档资源。
 * 解析返回的 `BackendJsonDocument` 必须关闭，文档和视图支持打开期间的并发只读访问。
 * 流解码读取到 EOF，流编码先缓存整份文档；输入输出流的所有权仍归调用方。
 * 该入口不会改变普通 `YJson` 的进程级加速状态。
 * @group 10-application 应用 API
 */
public class YyjsonBackendFacade {
    init() {}

    /**
     * 读取 yyjson 入口声明的引擎和流缓冲信息。
     *
     * 实际文档可能选择实现允许的回退；文档实际使用的引擎信息由其 `metadata()` 返回。
     *
     * @return 不可变后端元数据；`native` 为 `true`，编码与解码的缓冲方式均为 `WholeDocument`。
     *
     * @example 读取引擎元数据（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let metadata = json.metadata()
     * println(metadata.name)
     * println(metadata.native)
     * ```
     * ```output
     * yyjson
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func metadata(): JsonBackendMetadata { YYJSON_METADATA }

    /**
     * 把字符串解析为持有 yyjson 资源的不可变文档。
     *
     * 可用 `try (document = ...)` 管理资源。关闭后仍需保留可修改数据时，先调用 `materialize()`。
     * 文档支持并发只读访问；与关闭竞争的单次读取完整成功，或报告 `resource_closed`。
     *
     * @param text 待解析的完整 UTF-8 JSON 文本。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 持有原生资源的文档，使用后必须关闭；根和子视图的有效期不超过文档。
     * @throws JsonException JSON 语法或 UTF-8 无效，或者输入、深度、字符串等读取限制被触发。
     *
     * @example 从文本读取并关闭文档（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let text = "7"
     * try (document = json.parseDocument(text, options: JsonReadOptions.defaults)) {
     *     println(document.root().asInt64())
     * }
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func parseDocument(text: String,
        options!: JsonReadOptions = JsonReadOptions.defaults): BackendJsonDocument {
        parseDocument(unsafe { text.rawData() }, options: options)
    }

    /**
     * 把 UTF-8 字节解析为持有 yyjson 资源的不可变文档。
     *
     * 可用 `try (document = ...)` 管理资源。关闭后仍需保留可修改数据时，先调用 `materialize()`。
     * 文档支持并发只读访问；与关闭竞争的单次读取完整成功，或报告 `resource_closed`。
     *
     * @param bytes 待解析的完整 UTF-8 JSON 字节数组。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 持有原生资源的文档，使用后必须关闭；根和子视图的有效期不超过文档。
     * @throws JsonException JSON 语法或 UTF-8 无效，或者输入、深度、字符串等读取限制被触发。
     *
     * @example 从字节读取并关闭文档（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let bytes: Array<Byte> = [55]
     * try (document = json.parseDocument(bytes, options: JsonReadOptions.defaults)) {
     *     println(document.root().asInt64())
     * }
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func parseDocument(bytes: Array<Byte>,
        options!: JsonReadOptions = JsonReadOptions.defaults): BackendJsonDocument {
        YyjsonJsonDocument(YyjsonCompactJsonDocument.parse(bytes, config: options))
    }

    /**
     * 将只读视图通过 yyjson 编码为字符串。
     *
     * @param value 待写入的只读 JSON 视图；依赖后端资源的视图在调用期间必须保持打开。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @return 完整的 JSON 字符串，返回值不再依赖临时后端编码资源。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     *
     * @example 视图写入字符串（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: JsonValueView = JsonNode.parse("[1,2]")
     * println(json.toJson(value, options: JsonWriteOptions.defaults))
     * ```
     * ```output
     * [1,2]
     * ```
     * @group 10-application 应用 API
     */
    public func toJson(value: JsonValueView,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String {
        let output = YJsonMemoryOutputStream()
        encodeYyjsonView(value, output, options)
        output.toUtf8String()
    }

    /**
     * 将只读视图通过 yyjson 编码为UTF-8 字节数组。
     *
     * @param value 待写入的只读 JSON 视图；依赖后端资源的视图在调用期间必须保持打开。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @return 完整的 JSON UTF-8 字节数组，返回值不再依赖临时后端编码资源。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     *
     * @example 视图写入UTF-8 字节数组（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: JsonValueView = JsonNode.parse("[1,2]")
     * let bytes = json.toJsonBytes(value, options: JsonWriteOptions.defaults)
     * println(String.fromUtf8(bytes))
     * ```
     * ```output
     * [1,2]
     * ```
     * @group 10-application 应用 API
     */
    public func toJsonBytes(value: JsonValueView,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte> {
        let output = YJsonMemoryOutputStream()
        encodeYyjsonView(value, output, options)
        output.toByteArray()
    }

    /**
     * 将只读视图通过 yyjson 编码为输出流。
     *
     * 先缓存完整编码结果；编码或预算检查失败时不写入流。流自身写入失败仍可能留下部分输出。
     *
     * @param value 待写入的只读 JSON 视图；依赖后端资源的视图在调用期间必须保持打开。
     * @param output 调用方拥有的输出流；成功编码整份文档后写入并刷新，不关闭该流。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     * @throws Exception 输出流写入、刷新或自定义 codec 失败时，传播其异常。
     *
     * @example 视图写入输出流（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: JsonValueView = JsonNode.parse("[1,2]")
     * let output = YJsonMemoryOutputStream()
     * json.writeJson(value, output, options: JsonWriteOptions.defaults)
     * println(output.toUtf8String())
     * ```
     * ```output
     * [1,2]
     * ```
     * @group 10-application 应用 API
     */
    public func writeJson(value: JsonValueView, output: OutputStream,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit {
        encodeYyjsonView(value, output, options)
    }

    /**
     * 将具有生成 codec 提供方的值通过 yyjson 编码为字符串。
     *
     * 类型 `T` 必须提供匹配运行时的 `GeneratedCodecProviderV1<T>`；宏生成模型和受支持的内建类型可使用此重载。
     *
     * @param value 待写入的`T` 类型值。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @return 完整的 JSON 字符串，返回值不再依赖临时后端编码资源。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     *
     * @example 生成提供方写入字符串（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: Int64 = 7
     * println(json.toJson<Int64>(value, options: JsonWriteOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func toJson<T>(value: T,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String
        where T <: GeneratedCodecProviderV1<T> {
        toJson(value, codec: generatedCodecV1Of<T>(), options: options)
    }

    /**
     * 将显式 codec 指定的值通过 yyjson 编码为字符串。
     *
     * 按传入 codec 的写入契约生成 JSON，codec 抛出的异常原样传播。
     *
     * @param value 待写入的`T` 类型值。
     * @param codec 定义 `T` 的 JSON 表示方式的 codec；此入口调用其写入方法。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @return 完整的 JSON 字符串，返回值不再依赖临时后端编码资源。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     *
     * @example 显式 codec写入字符串（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: Int64 = 7
     * println(json.toJson<Int64>(value, codec: JsonCodecs.int64, options: JsonWriteOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func toJson<T>(value: T, codec!: JsonCodec<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): String {
        let output = YJsonMemoryOutputStream()
        encodeYyjsonBackend(codec, value, output, options)
        output.toUtf8String()
    }

    /**
     * 将具有生成 codec 提供方的值通过 yyjson 编码为UTF-8 字节数组。
     *
     * 类型 `T` 必须提供匹配运行时的 `GeneratedCodecProviderV1<T>`；宏生成模型和受支持的内建类型可使用此重载。
     *
     * @param value 待写入的`T` 类型值。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @return 完整的 JSON UTF-8 字节数组，返回值不再依赖临时后端编码资源。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     *
     * @example 生成提供方写入UTF-8 字节数组（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: Int64 = 7
     * let bytes = json.toJsonBytes<Int64>(value, options: JsonWriteOptions.defaults)
     * println(String.fromUtf8(bytes))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func toJsonBytes<T>(value: T,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte>
        where T <: GeneratedCodecProviderV1<T> {
        toJsonBytes(value, codec: generatedCodecV1Of<T>(), options: options)
    }

    /**
     * 将显式 codec 指定的值通过 yyjson 编码为UTF-8 字节数组。
     *
     * 按传入 codec 的写入契约生成 JSON，codec 抛出的异常原样传播。
     *
     * @param value 待写入的`T` 类型值。
     * @param codec 定义 `T` 的 JSON 表示方式的 codec；此入口调用其写入方法。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @return 完整的 JSON UTF-8 字节数组，返回值不再依赖临时后端编码资源。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     *
     * @example 显式 codec写入UTF-8 字节数组（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: Int64 = 7
     * let bytes = json.toJsonBytes<Int64>(value, codec: JsonCodecs.int64, options: JsonWriteOptions.defaults)
     * println(String.fromUtf8(bytes))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func toJsonBytes<T>(value: T, codec!: JsonCodec<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Array<Byte> {
        let output = YJsonMemoryOutputStream()
        encodeYyjsonBackend(codec, value, output, options)
        output.toByteArray()
    }

    /**
     * 将具有生成 codec 提供方的值通过 yyjson 编码为输出流。
     *
     * 类型 `T` 必须提供匹配运行时的 `GeneratedCodecProviderV1<T>`；宏生成模型和受支持的内建类型可使用此重载。
     * 先缓存完整编码结果；编码或预算检查失败时不写入流。流自身写入失败仍可能留下部分输出。
     *
     * @param value 待写入的`T` 类型值。
     * @param output 调用方拥有的输出流；成功编码整份文档后写入并刷新，不关闭该流。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     * @throws Exception 输出流写入、刷新或自定义 codec 失败时，传播其异常。
     *
     * @example 生成提供方写入输出流（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: Int64 = 7
     * let output = YJsonMemoryOutputStream()
     * json.writeJson<Int64>(value, output, options: JsonWriteOptions.defaults)
     * println(output.toUtf8String())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func writeJson<T>(value: T, output: OutputStream,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit
        where T <: GeneratedCodecProviderV1<T> {
        writeJson(value, output, codec: generatedCodecV1Of<T>(), options: options)
    }

    /**
     * 将显式 codec 指定的值通过 yyjson 编码为输出流。
     *
     * 按传入 codec 的写入契约生成 JSON，codec 抛出的异常原样传播。
     * 先缓存完整编码结果；编码或预算检查失败时不写入流。流自身写入失败仍可能留下部分输出。
     *
     * @param value 待写入的`T` 类型值。
     * @param output 调用方拥有的输出流；成功编码整份文档后写入并刷新，不关闭该流。
     * @param codec 定义 `T` 的 JSON 表示方式的 codec；此入口调用其写入方法。
     * @param options 写入选项；默认 `JsonWriteOptions.defaults`，控制布局、转义、深度和输出字节预算。
     * @throws JsonException 值或视图无法按 JSON 契约编码、视图资源已关闭，或者写入预算被触发。
     * @throws Exception 输出流写入、刷新或自定义 codec 失败时，传播其异常。
     *
     * @example 显式 codec写入输出流（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let value: Int64 = 7
     * let output = YJsonMemoryOutputStream()
     * json.writeJson<Int64>(value, output, codec: JsonCodecs.int64, options: JsonWriteOptions.defaults)
     * println(output.toUtf8String())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func writeJson<T>(value: T, output: OutputStream, codec!: JsonCodec<T>,
        options!: JsonWriteOptions = JsonWriteOptions.defaults): Unit {
        encodeYyjsonBackend(codec, value, output, options)
    }

    /**
     * 按类型 `T` 的生成提供方从JSON 字符串解码值。
     *
     * 类型 `T` 必须提供匹配运行时的 `GeneratedCodecProviderV1<T>`。
     *
     * @param text 完整 JSON 文本，必须只有一个根值。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 按 codec 规则解码的 `T` 类型值；临时原生文档在返回或异常离开前释放。
     * @throws JsonException JSON 无效、输入与目标类型不匹配、存在未消费内容，或者读取预算被触发。
     *
     * @example 生成提供方读取文本（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let text = "7"
     * println(json.fromJson<Int64>(text, options: JsonReadOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func fromJson<T>(text: String,
        options!: JsonReadOptions = JsonReadOptions.defaults): T
        where T <: GeneratedCodecProviderV1<T> {
        fromJson<T>(text, codec: generatedCodecV1Of<T>(), options: options)
    }

    /**
     * 按显式 codec从JSON 字符串解码值。
     *
     * 自定义 codec 的读取异常原样传播，不因 codec 失败切换到另一个后端。
     *
     * @param text 完整 JSON 文本，必须只有一个根值。
     * @param codec 定义 `T` 的读取规则的 codec；读完后仍校验整个输入已被消费。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 按 codec 规则解码的 `T` 类型值；临时原生文档在返回或异常离开前释放。
     * @throws JsonException JSON 无效、输入与目标类型不匹配、存在未消费内容，或者读取预算被触发。
     *
     * @example 显式 codec读取文本（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let text = "7"
     * println(json.fromJson<Int64>(text, codec: JsonCodecs.int64, options: JsonReadOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func fromJson<T>(text: String, codec!: JsonCodec<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeYyjsonBackend(codec, YJsonByteArrayInputStream(text), options)
    }

    /**
     * 按类型 `T` 的生成提供方从UTF-8 JSON 字节数组解码值。
     *
     * 类型 `T` 必须提供匹配运行时的 `GeneratedCodecProviderV1<T>`。
     *
     * @param bytes 完整 UTF-8 JSON 字节数组，必须只有一个根值。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 按 codec 规则解码的 `T` 类型值；临时原生文档在返回或异常离开前释放。
     * @throws JsonException JSON 无效、输入与目标类型不匹配、存在未消费内容，或者读取预算被触发。
     *
     * @example 生成提供方读取字节（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let bytes: Array<Byte> = [55]
     * println(json.fromJson<Int64>(bytes, options: JsonReadOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func fromJson<T>(bytes: Array<Byte>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T
        where T <: GeneratedCodecProviderV1<T> {
        fromJson<T>(bytes, codec: generatedCodecV1Of<T>(), options: options)
    }

    /**
     * 按显式 codec从UTF-8 JSON 字节数组解码值。
     *
     * 自定义 codec 的读取异常原样传播，不因 codec 失败切换到另一个后端。
     *
     * @param bytes 完整 UTF-8 JSON 字节数组，必须只有一个根值。
     * @param codec 定义 `T` 的读取规则的 codec；读完后仍校验整个输入已被消费。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 按 codec 规则解码的 `T` 类型值；临时原生文档在返回或异常离开前释放。
     * @throws JsonException JSON 无效、输入与目标类型不匹配、存在未消费内容，或者读取预算被触发。
     *
     * @example 显式 codec读取字节（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let bytes: Array<Byte> = [55]
     * println(json.fromJson<Int64>(bytes, codec: JsonCodecs.int64, options: JsonReadOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func fromJson<T>(bytes: Array<Byte>, codec!: JsonCodec<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeYyjsonBackend(codec, YJsonByteArrayInputStream(bytes), options)
    }

    /**
     * 按类型 `T` 的生成提供方从输入流中的整份 JSON 文档解码值。
     *
     * 类型 `T` 必须提供匹配运行时的 `GeneratedCodecProviderV1<T>`。
     * 先缓存输入到 EOF，再解析和解码；需要增量读取单份文档时，使用普通 `YJson` 流入口。
     *
     * @param input 调用方拥有的输入流；读取至 EOF，不关闭该流。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 按 codec 规则解码的 `T` 类型值；临时原生文档在返回或异常离开前释放。
     * @throws JsonException JSON 无效、输入与目标类型不匹配、存在未消费内容，或者读取预算被触发。
     * @throws Exception 输入流读取或自定义 codec 失败时，传播其异常。
     *
     * @example 生成提供方读取输入流（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let input = YJsonByteArrayInputStream("7")
     * println(json.fromJson<Int64>(input, options: JsonReadOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func fromJson<T>(input: InputStream,
        options!: JsonReadOptions = JsonReadOptions.defaults): T
        where T <: GeneratedCodecProviderV1<T> {
        fromJson<T>(input, codec: generatedCodecV1Of<T>(), options: options)
    }

    /**
     * 按显式 codec从输入流中的整份 JSON 文档解码值。
     *
     * 自定义 codec 的读取异常原样传播，不因 codec 失败切换到另一个后端。
     * 先缓存输入到 EOF，再解析和解码；需要增量读取单份文档时，使用普通 `YJson` 流入口。
     *
     * @param input 调用方拥有的输入流；读取至 EOF，不关闭该流。
     * @param codec 定义 `T` 的读取规则的 codec；读完后仍校验整个输入已被消费。
     * @param options 读取选项；默认 `JsonReadOptions.defaults`，包括重复键、数字和资源限制策略。
     * @return 按 codec 规则解码的 `T` 类型值；临时原生文档在返回或异常离开前释放。
     * @throws JsonException JSON 无效、输入与目标类型不匹配、存在未消费内容，或者读取预算被触发。
     * @throws Exception 输入流读取或自定义 codec 失败时，传播其异常。
     *
     * @example 显式 codec读取输入流（profile: yyjson） {run}
     * ```cangjie
     * let json = YyjsonBackends.yyjson
     * let input = YJsonByteArrayInputStream("7")
     * println(json.fromJson<Int64>(input, codec: JsonCodecs.int64, options: JsonReadOptions.defaults))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public func fromJson<T>(input: InputStream, codec!: JsonCodec<T>,
        options!: JsonReadOptions = JsonReadOptions.defaults): T {
        decodeYyjsonBackend(codec, input, options)
    }
}

/**
 * yyjson 共享命名入口的持有者。
 *
 * 通过静态属性取得已限定的后端入口，不能由此注册任意后端实现。
 * facade 不需要关闭，由它创建的资源文档仍由调用方关闭。
 * @group 10-application 应用 API
 */
public class YyjsonBackends {
    private static let qualified = YyjsonBackendFacade()

    private init() {}

    /**
     * 取得共享的 yyjson 后端入口。
     *
     * 取得入口不创建文档，也不改变普通 `YJson` 的加速配置。
     *
     * @return 共享的 `YyjsonBackendFacade`，用于类型化读写和显式资源文档解析。
     *
     * @example 取得命名入口（profile: yyjson） {run}
     * ```cangjie
     * println(YyjsonBackends.yyjson.metadata().name)
     * ```
     * ```output
     * yyjson
     * ```
     * @group 10-application 应用 API
     */
    public static prop yyjson: YyjsonBackendFacade {
        get() { qualified }
    }
}

private class YyjsonJsonDocument <: BackendJsonDocument {
    private let document: YyjsonCompactJsonDocument
    private let actualMetadata: JsonBackendMetadata

    init(document: YyjsonCompactJsonDocument) {
        this.document = document
        actualMetadata = if (document.storageStats().customFallback) {
            YYJSON_FALLBACK_METADATA
        } else {
            YYJSON_METADATA
        }
    }

    public func metadata(): JsonBackendMetadata { actualMetadata }
    public func isClosed(): Bool { document.isClosed() }
    public func close(): Unit { document.close() }
    public func root(): JsonValueView { document.root() }
    public func materialize(): JsonNode { document.materialize() }
    public func materialize(maxNodes: Int64): JsonNode {
        document.materialize(maxNodes)
    }
}
