package yjson_algorithms

import yjson.*

import std.collection.*
import std.deriving.Derive

private func jsonPatchError(message: String, operationIndex!: Int64 = -1,
    code!: String = "invalid_json_patch", path!: String = ""): JsonException {
    let resolvedPath = if (!path.isEmpty() || operationIndex < 0) { path }
        else { "/${operationIndex}" }
    JsonException(message, code: code, path: resolvedPath)
}

/**
 * RFC 6902 JSON Patch 操作类型；字符串形式采用标准小写操作名。
 *
 */
@Derive[Equatable]
public enum JsonPatchOperationKind <: ToString {
    /**
     * 向对象写入成员或向数组插入值；数组 `-` 表示追加。
     *
     */
    | Add
    /**
     * 删除已经存在的对象成员或数组元素；不允许删除整个根文档。
     *
     */
    | Remove
    /**
     * 替换已经存在的目标，根指针可以替换整个文档。
     *
     */
    | Replace
    /**
     * 先从来源删除值，再将同一个值添加到目标；不允许移动到来源的后代。
     *
     */
    | Move
    /**
     * 复制来源值并添加到目标。
     *
     */
    | Copy
    /**
     * 按 JSON 值等价语义测试目标值；失败使整次 Patch 失败。
     *
     */
    | Test

    /**
     * 返回 JSON Patch 文档使用的小写操作名。
     *
     * @return `add`、`remove`、`replace`、`move`、`copy` 或 `test`。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * println(JsonPatchOperationKind.Replace.toString())
     * ```
     * ```output
     * replace
     * ```
     */
    public func toString(): String {
        match (this) {
            case Add => "add"
            case Remove => "remove"
            case Replace => "replace"
            case Move => "move"
            case Copy => "copy"
            case Test => "test"
        }
    }
}

/**
 * 一个经过必要字段检查的 JSON Patch 操作；构造时复制 `value`，路径对象本身不可变。
 *
 */
public class JsonPatchOperation {
    /**
     * 操作类型，决定 `source` 和 `value` 哪些字段必需。
     *
     */
    public let kind: JsonPatchOperationKind
    /**
     * 写入或测试的目标 JSON Pointer。
     *
     */
    public let path: JsonPointer
    /**
     * Move、Copy 操作的来源指针；其他操作不使用此字段。
     *
     */
    public let source: Option<JsonPointer>
    /**
     * Add、Replace、Test 操作持有的值副本；构造后仍可通过可变 JsonNode 修改其内容。
     *
     */
    public let value: Option<JsonNode>

    /**
     * 创建操作并验证必需字段；`value` 会被深复制。
     *
     * @param kind 标准 Patch 操作类型。
     * @param path 操作目标指针。
     * @param source Move、Copy 所需的来源指针，默认无来源。
     * @param value Add、Replace、Test 所需的值，默认无值。
     * @throws JsonException 必需的来源或值缺失，错误码为 `invalid_json_patch`。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let operation = JsonPatchOperation(JsonPatchOperationKind.Add, JsonPointer.parse("/x"),
     *     value: Some(JsonNode.int64(7)))
     * let patch = JsonPatch([operation])
     * println(patch.apply(JsonNode.parse("{}"))["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     */
    public init(kind: JsonPatchOperationKind, path: JsonPointer,
        source!: Option<JsonPointer> = None<JsonPointer>,
        value!: Option<JsonNode> = None<JsonNode>) {
        this.kind = kind
        this.path = path
        this.source = source
        this.value = match (value) {
            case Some(node) => Some(node.deepCopy())
            case None => None<JsonNode>
        }
        validateJsonPatchOperation(this, -1)
    }
}

/**
 * 可复用的 RFC 6902 操作序列；应用时先处理独立副本，失败不会把部分操作写入输入树。
 *
 */
public class JsonPatch {
    private let patchOperations: Array<JsonPatchOperation>

    /**
     * 复制操作序列及其中的值，防止调用者随后修改原始操作值影响此 Patch。
     *
     * @param operations 按顺序执行的操作数组，空数组表示不做修改。
     * @throws JsonException 任一操作缺少必需字段。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let operation = JsonPatchOperation(JsonPatchOperationKind.Replace, JsonPointer.parse("/x"),
     *     value: Some(JsonNode.int64(7)))
     * let patch = JsonPatch([operation])
     * println(patch.apply(JsonNode.parse("{\"x\":1}"))["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     */
    public init(operations: Array<JsonPatchOperation>) {
        let copied = ArrayList<JsonPatchOperation>(operations.size)
        for (operation in operations) {
            copied.add(JsonPatchOperation(operation.kind, operation.path,
                source: operation.source, value: operation.value))
        }
        patchOperations = copied.toArray()
    }

    /**
     * 解析 JSON Patch 文本；默认拒绝重复对象成员名。
     *
     * @param text 包含操作对象数组的完整 JSON 文本。
     * @param config JSON 文本解析策略；默认的重复键策略为 Reject。
     * @return 已复制并验证必要字段的操作序列。
     * @throws JsonException JSON 无效、操作结构无效或指针不合法。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let patch = JsonPatch.parse("[{\"op\":\"replace\",\"path\":\"/x\",\"value\":7}]")
     * println(patch.apply(JsonNode.parse("{\"x\":1}"))["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     */
    public static func parse(text: String,
        config!: JsonReadOptions = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.Reject)): JsonPatch {
        fromValue(JsonNode.parse(text, config: config))
    }

    /**
     * 从值视图读取 JSON Patch 数组并复制操作；不保留来源文档的生命周期依赖。
     *
     * @param value 包含标准操作对象的数组视图。
     * @return 与来源存储分离的 Patch。
     * @throws JsonException 输入不是数组、操作无效、指针不合法或视图读取失败。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let source = JsonNode.parse("[{\"op\":\"add\",\"path\":\"/x\",\"value\":7}]")
     * let patch = JsonPatch.fromValue(source)
     * println(patch.apply(JsonNode.parse("{}"))["x"].asInt64())
     * ```
     * ```output
     * 7
     * ```
     */
    public static func fromValue(value: JsonValueView): JsonPatch {
        if (value.kind() != JsonKind.Array) {
            throw JsonException("JSON Patch document must be an array", code: "invalid_json_patch")
        }
        let operations = ArrayList<JsonPatchOperation>(value.size())
        for (index in 0..value.size()) {
            operations.add(parseJsonPatchOperation(value.element(index).getOrThrow().materialize(), index))
        }
        JsonPatch(operations.toArray())
    }

    /**
     * 返回操作序列副本；其中的值再次深复制，修改返回内容不影响此 Patch。
     *
     * @return 按执行顺序排列的独立操作数组。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let patch = JsonPatch.parse("[{\"op\":\"remove\",\"path\":\"/x\"}]")
     * let operations = patch.operations()
     * println(operations.size)
     * println(operations[0].kind.toString())
     * ```
     * ```output
     * 1
     * remove
     * ```
     */
    public func operations(): Array<JsonPatchOperation> {
        let result = ArrayList<JsonPatchOperation>(patchOperations.size)
        for (operation in patchOperations) {
            result.add(JsonPatchOperation(operation.kind, operation.path,
                source: operation.source, value: operation.value))
        }
        result.toArray()
    }

    /**
     * 按顺序将操作应用到输入的独立副本；输入不变，失败丢弃部分结果。
     *
     * @param target 要应用 Patch 的只读视图。
     * @param limits 操作数、指针令牌数与累计复制节点预算。
     * @return 应用全部操作后的独立可变根节点。
     * @throws JsonException 路径不存在、操作失败、test 不匹配或超过工作预算；预算错误码为 `work_limit_exceeded`。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let target = JsonNode.parse("{\"x\":1}")
     * let patch = JsonPatch.parse("[{\"op\":\"replace\",\"path\":\"/x\",\"value\":7}]")
     * let result = patch.apply(target)
     * println(target["x"].asInt64())
     * println(result["x"].asInt64())
     * ```
     * ```output
     * 1
     * 7
     * ```
     */
    public func apply(target: JsonValueView, limits!: JsonPatchLimits = JsonPatchLimits.defaults): JsonNode {
        enforceWorkLimit(patchOperations.size, limits.maxOperations, "patch operations")
        for (operation in patchOperations) {
            enforceWorkLimit(operation.path.rawTokens().size, limits.maxPointerSegments, "pointer segments")
            if (let Some(source) <- operation.source) {
                enforceWorkLimit(source.rawTokens().size, limits.maxPointerSegments, "pointer segments")
            }
        }
        let copyWork = JsonPatchCopyWork(limits.maxCopiedNodes)
        copyWork.charge(target)
        applyJsonPatchOperations(target.materialize(), patchOperations, copyWork)
    }

    /**
     * 先在副本上完成全部操作，再在根容器类型未改变时写回输入容器；调用者必须使用返回的根。
     *
     * @param target 可变输入树，操作阶段失败时保持原内容。
     * @param limits 操作数、指针令牌数与累计复制节点预算。
     * @return 最终根节点；根类型改变时返回新节点，原根不能表示该结果。
     * @throws JsonException 路径、test、操作或工作预算失败，输入尚未被写回。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let target = JsonNode.parse("{\"x\":1}")
     * let patch = JsonPatch.parse("[{\"op\":\"replace\",\"path\":\"/x\",\"value\":7}]")
     * let result = patch.applyInPlace(target)
     * println(target["x"].asInt64())
     * println(result["x"].asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     */
    public func applyInPlace(target: JsonNode,
        limits!: JsonPatchLimits = JsonPatchLimits.defaults): JsonNode {
        let result = apply(target, limits: limits)
        commitJsonRoot(target, result)
    }
}

/**
 * RFC 7396 Merge Patch：对象递归合并，值为 null 的成员被删除，非对象 Patch 替换整个目标。
 *
 */
public class JsonMergePatch {
    /**
     * 合并输入副本；不会修改目标或 Patch。
     *
     * @param target 要合并的只读目标视图。
     * @param patch Merge Patch 视图，非对象值替换整个目标。
     * @param limits 使用 maxCopiedNodes 校验输入节点合计及最终结果节点数；其他维度不适用。
     * @return 合并后的独立可变根。
     * @throws JsonException 复制节点预算不足，错误码为 `work_limit_exceeded`，或读取视图失败。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let target = JsonNode.parse("{\"x\":1,\"old\":true}")
     * let patch = JsonNode.parse("{\"x\":7,\"old\":null}")
     * let result = JsonMergePatch.apply(target, patch)
     * println(result["x"].asInt64())
     * println(result.asObject().contains("old"))
     * println(target.asObject().contains("old"))
     * ```
     * ```output
     * 7
     * false
     * true
     * ```
     */
    public static func apply(target: JsonValueView, patch: JsonValueView,
        limits!: JsonPatchLimits = JsonPatchLimits.defaults): JsonNode {
        enforceWorkLimit(jsonPatchNodeCount(target) + jsonPatchNodeCount(patch),
            limits.maxCopiedNodes, "copied nodes")
        let result = applyJsonMergePatch(target.materialize(), patch.materialize())
        enforceWorkLimit(jsonPatchNodeCount(result), limits.maxCopiedNodes, "copied nodes")
        result
    }

    /**
     * 先计算合并结果，再在根容器类型一致时写回；必须使用返回的根。
     *
     * @param target 要更新的可变目标树。
     * @param patch Merge Patch 树，不会修改该树。
     * @param limits 使用 maxCopiedNodes 校验输入与结果节点数。
     * @return 最终根节点，根类型改变时为新节点。
     * @throws JsonException 工作预算或合并失败；结果写回前不会改变目标。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let target = JsonNode.parse("{\"x\":1}")
     * let result = JsonMergePatch.applyInPlace(target, JsonNode.parse("{\"x\":7}"))
     * println(target["x"].asInt64())
     * println(result["x"].asInt64())
     * ```
     * ```output
     * 7
     * 7
     * ```
     */
    public static func applyInPlace(target: JsonNode, patch: JsonNode,
        limits!: JsonPatchLimits = JsonPatchLimits.defaults): JsonNode {
        commitJsonRoot(target, apply(target, patch, limits: limits))
    }
}

private func jsonPatchNodeCount(value: JsonValueView): Int64 {
    match (value.kind()) {
        case JsonKind.Array =>
            var total: Int64 = 1
            for (index in 0..value.size()) {
                total += jsonPatchNodeCount(value.element(index).getOrThrow())
            }
            total
        case JsonKind.Object =>
            var total: Int64 = 1
            for (index in 0..value.size()) { total += jsonPatchNodeCount(value.memberValue(index)) }
            total
        case _ => 1
    }
}

private class JsonPatchCopyWork {
    private let limit: Int64
    private var copiedNodes: Int64 = 0

    init(limit: Int64) { this.limit = limit }

    func charge(value: JsonValueView): Unit {
        let count = jsonPatchNodeCount(value)
        if (limit > 0 && (count > limit || copiedNodes > limit - count)) {
            throw JsonException(
                "JSON algorithm copied nodes budget exceeded: limit=${limit}, consumed=${copiedNodes + count}",
                code: "work_limit_exceeded")
        }
        copiedNodes += count
    }
}

private func parseJsonPatchOperation(value: JsonNode, index: Int64): JsonPatchOperation {
    let objectValue = value.asObject()
    let opText = requireJsonPatchString(objectValue, "op", index)
    let pathText = requireJsonPatchString(objectValue, "path", index)
    let kind = match (opText) {
        case "add" => JsonPatchOperationKind.Add
        case "remove" => JsonPatchOperationKind.Remove
        case "replace" => JsonPatchOperationKind.Replace
        case "move" => JsonPatchOperationKind.Move
        case "copy" => JsonPatchOperationKind.Copy
        case "test" => JsonPatchOperationKind.Test
        case _ => throw jsonPatchError("Unknown JSON Patch operation '${opText}'", operationIndex: index)
    }
    let source = match (objectValue.get("from")) {
        case Some(fromValue) => Some(JsonPointer.parse(fromValue.asString()))
        case None => None<JsonPointer>
    }
    let patchValue = match (objectValue.get("value")) {
        case Some(node) => Some(node)
        case None => None<JsonNode>
    }
    let operation = JsonPatchOperation(kind, JsonPointer.parse(pathText), source: source, value: patchValue)
    validateJsonPatchOperation(operation, index)
    operation
}

private func requireJsonPatchString(objectValue: JsonObject, name: String, index: Int64): String {
    objectValue.get(name).getOrThrow({ =>
        jsonPatchError("JSON Patch operation ${index} is missing '${name}'", operationIndex: index)
    }).asString()
}

private func validateJsonPatchOperation(operation: JsonPatchOperation, index: Int64): Unit {
    match (operation.kind) {
        case Add | Replace | Test =>
            if (operation.value.isNone()) {
                throw jsonPatchError("JSON Patch '${operation.kind}' requires 'value'", operationIndex: index)
            }
        case Move | Copy =>
            if (operation.source.isNone()) {
                throw jsonPatchError("JSON Patch '${operation.kind}' requires 'from'", operationIndex: index)
            }
        case Remove => ()
    }
}

private func applyJsonPatchOperations(initial: JsonNode, operations: Array<JsonPatchOperation>,
    copyWork: JsonPatchCopyWork): JsonNode {
    var root = initial
    for (index in 0..operations.size) {
        try {
            root = applyJsonPatchOperation(root, operations[index], copyWork)
        } catch (error: JsonException) {
            if (error.code == "work_limit_exceeded") { throw error }
            let code = if (error.code.startsWith("json_patch")) { error.code } else { "json_patch_path" }
            throw jsonPatchError(error.message, operationIndex: index,
                code: code, path: error.path)
        }
    }
    root
}

private func applyJsonPatchOperation(root: JsonNode, operation: JsonPatchOperation,
    copyWork: JsonPatchCopyWork): JsonNode {
    match (operation.kind) {
        case Add =>
            let value = operation.value.getOrThrow()
            copyWork.charge(value)
            jsonPatchAdd(root, operation.path, value.deepCopy())
        case Remove =>
            let (nextRoot, _) = jsonPatchRemove(root, operation.path)
            nextRoot
        case Replace =>
            let value = operation.value.getOrThrow()
            copyWork.charge(value)
            jsonPatchReplace(root, operation.path, value.deepCopy())
        case Copy =>
            let sourceValue = operation.source.getOrThrow().evaluate(root)
            let copied = sourceValue.materialize()
            copyWork.charge(copied)
            jsonPatchAdd(root, operation.path, copied)
        case Move => jsonPatchMove(root, operation.source.getOrThrow(), operation.path)
        case Test =>
            let expected = operation.value.getOrThrow()
            copyWork.charge(expected)
            let actual = operation.path.evaluate(root)
            if (!jsonNodesEquivalent(actual, expected)) {
                throw jsonPatchError("JSON Patch test operation failed", code: "json_patch_test_failed",
                    path: operation.path.toString())
            }
            root
    }
}

private func jsonPatchAdd(root: JsonNode, pointer: JsonPointer, value: JsonNode): JsonNode {
    if (pointer.isRoot()) { return value }
    let (parent, token) = jsonPointerParent(root, pointer)
    match (parent) {
        case objectValue: JsonObject => objectValue.put(token, value); root
        case arrayValue: JsonArray =>
            let index = parseJsonPointerArrayIndex(token, arrayValue.size(), true).getOrThrow({ =>
                jsonPointerError("Invalid JSON Patch add array index '${token}'", pointer.toString(),
                    code: "json_pointer_not_found")
            })
            arrayValue.insert(index, value)
            root
        case _ => throw jsonPointerError("JSON Patch add parent is not a container", pointer.toString(),
            code: "json_pointer_not_found")
    }
}

private func jsonPatchRemove(root: JsonNode, pointer: JsonPointer): (JsonNode, JsonNode) {
    if (pointer.isRoot()) {
        throw jsonPatchError("Removing the complete JSON document has no JsonNode result",
            code: "json_patch_path", path: pointer.toString())
    }
    let (parent, token) = jsonPointerParent(root, pointer)
    match (parent) {
        case objectValue: JsonObject =>
            let removed = objectValue.remove(token).getOrThrow({ =>
                jsonPointerError("JSON Patch remove target does not exist", pointer.toString(),
                    code: "json_pointer_not_found")
            })
            (root, removed)
        case arrayValue: JsonArray =>
            let index = parseJsonPointerArrayIndex(token, arrayValue.size(), false).getOrThrow({ =>
                jsonPointerError("Invalid JSON Patch remove array index '${token}'", pointer.toString(),
                    code: "json_pointer_not_found")
            })
            (root, arrayValue.removeAt(index))
        case _ => throw jsonPointerError("JSON Patch remove parent is not a container", pointer.toString(),
            code: "json_pointer_not_found")
    }
}

private func jsonPatchReplace(root: JsonNode, pointer: JsonPointer, value: JsonNode): JsonNode {
    if (pointer.isRoot()) { return value }
    let _ = pointer.evaluate(root)
    let (parent, token) = jsonPointerParent(root, pointer)
    match (parent) {
        case objectValue: JsonObject => objectValue.put(token, value); root
        case arrayValue: JsonArray =>
            let index = parseJsonPointerArrayIndex(token, arrayValue.size(), false).getOrThrow({ =>
                jsonPointerError("Invalid JSON Patch replace array index '${token}'", pointer.toString(),
                    code: "json_pointer_not_found")
            })
            arrayValue.set(index, value)
            root
        case _ => throw jsonPointerError("JSON Patch replace parent is not a container", pointer.toString(),
            code: "json_pointer_not_found")
    }
}

private func jsonPatchMove(root: JsonNode, source: JsonPointer, destination: JsonPointer): JsonNode {
    if (source.toString() == destination.toString()) { return root }
    if (!source.isRoot() && destination.toString().startsWith(source.toString() + "/")) {
        throw jsonPatchError("JSON Patch move destination is inside the source", code: "json_patch_path",
            path: destination.toString())
    }
    if (source.isRoot()) {
        if (destination.isRoot()) { return root }
        throw jsonPatchError("Cannot move the document root into one of its descendants",
            code: "json_patch_path", path: destination.toString())
    }
    let (withoutSource, moved) = jsonPatchRemove(root, source)
    jsonPatchAdd(withoutSource, destination, moved)
}

private func applyJsonMergePatch(target: JsonNode, patch: JsonNode): JsonNode {
    match (patch) {
        case patchObject: JsonObject =>
            let targetObject = match (target) {
                case objectValue: JsonObject => objectValue
                case _ => JsonObject()
            }
            for (index in 0..patchObject.size()) {
                let name = patchObject.nameAt(index)
                let patchValue = patchObject.valueAt(index)
                if (patchValue.isNull) {
                    let _ = targetObject.remove(name)
                } else {
                    let current = match (targetObject.get(name)) {
                        case Some(value) => value
                        case None => JsonNode.nullValue
                    }
                    targetObject.put(name, applyJsonMergePatch(current, patchValue))
                }
            }
            targetObject
        case _ => patch.deepCopy()
    }
}

private func commitJsonRoot(target: JsonNode, result: JsonNode): JsonNode {
    match ((target, result)) {
        case (targetObject: JsonObject, resultObject: JsonObject) =>
            while (targetObject.size() > 0) {
                let _ = targetObject.remove(targetObject.nameAt(targetObject.size() - 1))
            }
            for (index in 0..resultObject.size()) {
                targetObject.put(resultObject.nameAt(index), resultObject.valueAt(index))
            }
            targetObject
        case (targetArray: JsonArray, resultArray: JsonArray) =>
            while (targetArray.size() > 0) { let _ = targetArray.removeAt(targetArray.size() - 1) }
            for (index in 0..resultArray.size()) { targetArray.add(resultArray[index]) }
            targetArray
        case _ => result
    }
}

func deepCopyJsonNode(value: JsonNode): JsonNode {
    value.materialize()
}

