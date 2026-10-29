package yjson

/**
 * 由 GC 管理的不可变 JSON 文档。
 *
 * 不需要 close。root 返回的视图保留底层存储；materialize 生成不共享可变节点的副本。默认复制上限为 100,000 个节点和 256 层。
 * @group 10-application 应用 API
 */
public interface JsonDocument {
    /**
     * 读取文档根值的只读视图。
     *
     * @return 保留文档存储的根视图；不复制整份文档。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let document = YJson.parseDocument("{\"id\":7}")
     * println(document.root().member("id").getOrThrow().asInt64())
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    func root(): JsonValueView
    /**
     * 在默认预算内复制出独立的可修改树。
     *
     * @return 与当前文档隔离的 JsonNode 树。
     * @throws JsonException 超过 100,000 个节点或 256 层复制预算。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let document = YJson.parseDocument("{\"id\":1}")
     * let copy = document.materialize()
     * copy["id"] = 2
     * println(document.root().member("id").getOrThrow().asInt64() == 1 && copy["id"].asInt64() == 2)
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    func materialize(): JsonNode
    /**
     * 在指定节点预算内复制出独立的可修改树。
     *
     * @param maxNodes 正数节点访问上限，包含根节点；深度上限仍为 256。
     * @return 与文档存储隔离的 JsonNode 树。
     * @throws IllegalArgumentException maxNodes 非正。
     * @throws JsonException 节点或深度预算耗尽。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let document = YJson.parseDocument("[1]")
     * println(document.materialize(2).toJson())
     * ```
     * ```output
     * [1]
     * ```
     *
     * @example 检查拒绝路径 {run}
     * ```cangjie
     * let document = YJson.parseDocument("[1]")
     * var code = ""
     * try { let _ = document.materialize(1) } catch (error: JsonException) { code = error.code }
     * println(code)
     * ```
     * ```output
     * work_limit_exceeded
     * ```
     * @group 10-application 应用 API
     */
    func materialize(maxNodes: Int64): JsonNode
    /**
     * 将文档重新序列化为紧凑 JSON 文本。
     *
     * @return 表示同一 JSON 数据的文本；不保证保留输入空白和数字拼写。
     * @throws JsonException 超过默认写出深度限制。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * println(YJson.parseDocument(" [ 1 ] ").toString())
     * ```
     * ```output
     * [1]
     * ```
     * @group 10-application 应用 API
     */
    func toString(): String
}

private class PureCompactJsonDocument <: JsonDocument {
    private let document: CompactJsonDocument

    init(document: CompactJsonDocument) {
        this.document = document
    }

    public func root(): JsonValueView { document.root() }

    public func materialize(): JsonNode { document.root().materialize() }

    public func materialize(maxNodes: Int64): JsonNode {
        document.root().materialize(maxNodes)
    }

    public func toString(): String {
        document.toString()
    }
}

func parseManagedJsonDocument(text: String, config: JsonReadOptions): JsonDocument {
    let compact = unsafe {
        CompactJsonDocument.parseBorrowed(text.rawData(), config, Some(text))
    }
    PureCompactJsonDocument(compact)
}

func parseManagedJsonDocument(bytes: Array<Byte>, config: JsonReadOptions): JsonDocument {
    PureCompactJsonDocument(CompactJsonDocument.parseOwned(bytes, config: config))
}
