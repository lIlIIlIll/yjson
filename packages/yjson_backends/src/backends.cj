package yjson_backends

import yjson.*

/**
 * 后端在输入与输出时采用的缓冲方式；该信息描述实现行为，不改变流的所有权。
 *
 */
public enum JsonStreamBufferingMode {
    /**
     * 可以分批处理输入或输出，无需先缓存整个文档。
     *
     */
    | Incremental
    /**
     * 先缓存整个文档，再完成解析或序列化。
     *
     */
    | WholeDocument
}

/**
 * 实际持有后端文档的引擎元数据；各字段在构造后不可变。
 *
 */
public class JsonBackendMetadata {
    /**
     * 引擎名称，例如 `custom-native`。
     *
     */
    public let name: String
    /**
     * 引擎版本；不能由此推断跨版本兼容性。
     *
     */
    public let version: String
    /**
     * 引擎是否使用原生实现。
     *
     */
    public let native: Bool
    /**
     * 解码时实际采用的缓冲方式。
     *
     */
    public let decodeBuffering: JsonStreamBufferingMode
    /**
     * 编码时实际采用的缓冲方式。
     *
     */
    public let encodeBuffering: JsonStreamBufferingMode

    /**
     * 构造一份后端能力描述；构造过程不创建或验证后端引擎。
     *
     * @param name 引擎名称，例如 `custom-native`。
     * @param version 引擎版本；不能由此推断跨版本兼容性。
     * @param native 引擎是否使用原生实现。
     * @param decodeBuffering 解码时实际采用的缓冲方式。
     * @param encodeBuffering 编码时实际采用的缓冲方式。
     *
     * @example 用法（profile: backends） {run}
     * ```cangjie
     * let metadata = JsonBackendMetadata("example-engine", "0.2.0", false,
     *     JsonStreamBufferingMode.Incremental, JsonStreamBufferingMode.WholeDocument)
     * println(metadata.name)
     * println(metadata.native)
     * ```
     * ```output
     * example-engine
     * false
     * ```
     */
    public init(name: String, version: String, native: Bool,
        decodeBuffering: JsonStreamBufferingMode,
        encodeBuffering: JsonStreamBufferingMode) {
        this.name = name
        this.version = version
        this.native = native
        this.decodeBuffering = decodeBuffering
        this.encodeBuffering = encodeBuffering
    }
}

/**
 * 显式拥有后端资源的 JSON 文档。使用结束后调用 `close`；根视图依赖文档资源，关闭后不再可读。需要在关闭后保留数据时，先调用 `materialize` 取得独立副本。
 *
 */
public interface BackendJsonDocument <: Resource {
    /**
     * 读取实际拥有文档的引擎描述。
     *
     * @return 文档所属引擎的不可变元数据。
     *
     * @example 用法（profile: backends-native） {run}
     * ```cangjie
     * let document = NativeBackends.customNative.parseDocument("null")
     * try { println(document.metadata().native) } finally { document.close() }
     * ```
     * ```output
     * true
     * ```
     */
    func metadata(): JsonBackendMetadata
    /**
     * 查询文档资源是否已经关闭。
     *
     * @return 关闭后为 `true`；重复关闭不改变此结果。
     *
     * @example 用法（profile: backends-native） {run}
     * ```cangjie
     * let document = NativeBackends.customNative.parseDocument("null")
     * println(document.isClosed())
     * document.close()
     * println(document.isClosed())
     * ```
     * ```output
     * false
     * true
     * ```
     */
    func isClosed(): Bool
    /**
     * 释放文档拥有的资源；重复调用不重复释放。已取得的视图随之失效。
     *
     *
     * @example 用法（profile: backends-native） {run}
     * ```cangjie
     * let document = NativeBackends.customNative.parseDocument("null")
     * document.close()
     * document.close()
     * println(document.isClosed())
     * ```
     * ```output
     * true
     * ```
     */
    func close(): Unit
    /**
     * 取得依赖文档生命周期的根视图；不会复制整个文档。
     *
     * @return 只读根视图，读取期间文档必须保持打开。
     * @throws JsonException 文档已关闭，错误码为 `resource_closed`。
     *
     * @example 用法（profile: backends-native） {run}
     * ```cangjie
     * let document = NativeBackends.customNative.parseDocument("[7]")
     * try { println(document.root().element(0).getOrThrow().asInt64()) }
     * finally { document.close() }
     * ```
     * ```output
     * 7
     * ```
     */
    func root(): JsonValueView
    /**
     * 复制整个文档为独立的可变树。默认最多复制 100,000 个节点。
     *
     * @return 与文档资源分离的可变树，文档关闭后仍可使用。
     * @throws JsonException 文档已关闭，或复制超过节点预算。
     *
     * @example 用法（profile: backends-native） {run}
     * ```cangjie
     * let document = NativeBackends.customNative.parseDocument("[7]")
     * let first = document.materialize()
     * let second = document.materialize(2)
     * document.close()
     * println(first[0].asInt64())
     * println(second[0].asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     */
    func materialize(): JsonNode
    /**
     * 复制整个文档为独立的可变树。
     *
     * @param maxNodes 允许复制的最大节点数，必须为正数。
     * @return 与文档资源分离的可变树，文档关闭后仍可使用。
     * @throws JsonException 文档已关闭，或复制超过节点预算。
     * @throws IllegalArgumentException `maxNodes` 不为正数。
     *
     * @example 用法（profile: backends-native） {run}
     * ```cangjie
     * let document = NativeBackends.customNative.parseDocument("[7]")
     * let first = document.materialize()
     * let second = document.materialize(2)
     * document.close()
     * println(first[0].asInt64())
     * println(second[0].asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     */
    func materialize(maxNodes: Int64): JsonNode
}
