package yjson_algorithms

import yjson.*

/**
 * JSONPath 编译与单次执行的工作预算；各维度为 `0` 时不限制，负值无效。
 *
 * @group 10-application 应用 API
 */
public class JsonPathLimits {
    /**
     * 单次执行允许访问的候选节点数，包含遍历和过滤子查询。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxVisitedNodes: Int64
    /**
     * 单次执行允许进行的过滤候选求值次数。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxFilterSteps: Int64
    /**
     * 单次执行中正则编译与匹配共用的步骤预算。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxRegexSteps: Int64
    /**
     * 单次执行允许输出的匹配数，重复匹配也计数。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxMatches: Int64
    /**
     * 遍历候选节点允许达到的深度。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxDepth: Int64
    /**
     * 编译单个过滤表达式允许的 UTF-8 字节数。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxFilterExpressionBytes: Int64
    /**
     * 编译单个过滤表达式允许的逻辑运算符数量。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxFilterOperators: Int64
    /**
     * 编译单个过滤表达式允许的逻辑嵌套深度。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxFilterDepth: Int64
    /**
     * 单次执行允许实际求值的逻辑运算次数。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxFilterOperations: Int64
    /**
     * 创建独立预算配置；构造时校验所有维度非负。
     *
     * @param maxVisitedNodes 单次执行允许访问的候选节点数，包含遍历和过滤子查询。 默认值见签名；`0` 表示不限制。
     * @param maxFilterSteps 单次执行允许进行的过滤候选求值次数。 默认值见签名；`0` 表示不限制。
     * @param maxRegexSteps 单次执行中正则编译与匹配共用的步骤预算。 默认值见签名；`0` 表示不限制。
     * @param maxMatches 单次执行允许输出的匹配数，重复匹配也计数。 默认值见签名；`0` 表示不限制。
     * @param maxDepth 遍历候选节点允许达到的深度。 默认值见签名；`0` 表示不限制。
     * @param maxFilterExpressionBytes 编译单个过滤表达式允许的 UTF-8 字节数。 默认值见签名；`0` 表示不限制。
     * @param maxFilterOperators 编译单个过滤表达式允许的逻辑运算符数量。 默认值见签名；`0` 表示不限制。
     * @param maxFilterDepth 编译单个过滤表达式允许的逻辑嵌套深度。 默认值见签名；`0` 表示不限制。
     * @param maxFilterOperations 单次执行允许实际求值的逻辑运算次数。 默认值见签名；`0` 表示不限制。
     * @throws IllegalArgumentException 任一预算为负数。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let limits = JsonPathLimits(maxMatches: 1)
     * println(JsonPath.parse("$[0]").collect(JsonNode.parse("[7]"), limits: limits).size)
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public init(maxVisitedNodes!: Int64 = 100000, maxFilterSteps!: Int64 = 100000,
        maxRegexSteps!: Int64 = 100000, maxMatches!: Int64 = 10000, maxDepth!: Int64 = 256,
        maxFilterExpressionBytes!: Int64 = 4096, maxFilterOperators!: Int64 = 256,
        maxFilterDepth!: Int64 = 64, maxFilterOperations!: Int64 = 200000) {
        requireWorkLimit(maxVisitedNodes, "maxVisitedNodes"); requireWorkLimit(maxFilterSteps, "maxFilterSteps")
        requireWorkLimit(maxRegexSteps, "maxRegexSteps"); requireWorkLimit(maxMatches, "maxMatches")
        requireWorkLimit(maxDepth, "maxDepth")
        requireWorkLimit(maxFilterExpressionBytes, "maxFilterExpressionBytes")
        requireWorkLimit(maxFilterOperators, "maxFilterOperators")
        requireWorkLimit(maxFilterDepth, "maxFilterDepth")
        requireWorkLimit(maxFilterOperations, "maxFilterOperations")
        this.maxVisitedNodes = maxVisitedNodes; this.maxFilterSteps = maxFilterSteps
        this.maxRegexSteps = maxRegexSteps; this.maxMatches = maxMatches; this.maxDepth = maxDepth
        this.maxFilterExpressionBytes = maxFilterExpressionBytes
        this.maxFilterOperators = maxFilterOperators
        this.maxFilterDepth = maxFilterDepth
        this.maxFilterOperations = maxFilterOperations
    }
    /**
     * 带签名所列有限预算的默认配置。
     *
     * @group 10-application 应用 API
     */
    public static let defaults = JsonPathLimits()
    /**
     * 关闭全部预算的配置；仅适用于输入与工作量受信任的场景。
     *
     * @group 10-application 应用 API
     */
    public static let unlimited = JsonPathLimits(maxVisitedNodes: 0, maxFilterSteps: 0,
        maxRegexSteps: 0, maxMatches: 0, maxDepth: 0, maxFilterExpressionBytes: 0,
        maxFilterOperators: 0, maxFilterDepth: 0, maxFilterOperations: 0)
}

/**
 * JSON Patch 和 Merge Patch 的工作预算；各维度为 `0` 时不限制，负值无效。
 *
 * @group 10-application 应用 API
 */
public class JsonPatchLimits {
    /**
     * JSON Patch 允许执行的操作数，Merge Patch 不使用此维度。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxOperations: Int64
    /**
     * JSON Patch 每个目标指针及来源指针允许的令牌数。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxPointerSegments: Int64
    /**
     * 允许复制的节点预算；JSON Patch 累计初始副本和操作值等复制，Merge Patch 检查输入合计与结果节点数。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxCopiedNodes: Int64
    /**
     * 创建独立预算配置；构造时校验所有维度非负。
     *
     * @param maxOperations JSON Patch 允许执行的操作数，Merge Patch 不使用此维度。 默认值见签名；`0` 表示不限制。
     * @param maxPointerSegments JSON Patch 每个目标指针及来源指针允许的令牌数。 默认值见签名；`0` 表示不限制。
     * @param maxCopiedNodes 允许复制的节点预算；JSON Patch 累计初始副本和操作值等复制，Merge Patch 检查输入合计与结果节点数。 默认值见签名；`0` 表示不限制。
     * @throws IllegalArgumentException 任一预算为负数。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let limits = JsonPatchLimits(maxOperations: 1)
     * let patch = JsonPatch.parse("[{\"op\":\"add\",\"path\":\"/x\",\"value\":1}]")
     * println(patch.apply(JsonNode.parse("{}"), limits: limits)["x"].asInt64())
     * ```
     * ```output
     * 1
     * ```
     * @group 10-application 应用 API
     */
    public init(maxOperations!: Int64 = 10000, maxPointerSegments!: Int64 = 256,
        maxCopiedNodes!: Int64 = 100000) {
        requireWorkLimit(maxOperations, "maxOperations"); requireWorkLimit(maxPointerSegments, "maxPointerSegments")
        requireWorkLimit(maxCopiedNodes, "maxCopiedNodes")
        this.maxOperations = maxOperations; this.maxPointerSegments = maxPointerSegments
        this.maxCopiedNodes = maxCopiedNodes
    }
    /**
     * 带签名所列有限预算的默认配置。
     *
     * @group 10-application 应用 API
     */
    public static let defaults = JsonPatchLimits()
    /**
     * 关闭全部预算的配置；仅适用于输入与工作量受信任的场景。
     *
     * @group 10-application 应用 API
     */
    public static let unlimited = JsonPatchLimits(maxOperations: 0, maxPointerSegments: 0, maxCopiedNodes: 0)
}

/**
 * JSON Schema 编译与单次验证的工作预算；各维度为 `0` 时不限制，负值无效。
 *
 * @group 10-application 应用 API
 */
public class JsonSchemaLimits {
    /**
     * 单次验证允许的模式求值与额外比较工作量。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxEvaluations: Int64
    /**
     * 模式编译和验证允许的引用解析预算。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxRefResolutions: Int64
    /**
     * 正则编译或单次验证中共用的正则步骤预算。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxRegexSteps: Int64
    /**
     * 一次完整验证允许产生的错误条目数，超出预算会抛出异常。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxErrors: Int64
    /**
     * 验证实例时允许的递归深度。 `0` 表示不限制。
     *
     * @group 10-application 应用 API
     */
    public let maxDepth: Int64
    /**
     * 创建独立预算配置；构造时校验所有维度非负。
     *
     * @param maxEvaluations 单次验证允许的模式求值与额外比较工作量。 默认值见签名；`0` 表示不限制。
     * @param maxRefResolutions 模式编译和验证允许的引用解析预算。 默认值见签名；`0` 表示不限制。
     * @param maxRegexSteps 正则编译或单次验证中共用的正则步骤预算。 默认值见签名；`0` 表示不限制。
     * @param maxErrors 一次完整验证允许产生的错误条目数，超出预算会抛出异常。 默认值见签名；`0` 表示不限制。
     * @param maxDepth 验证实例时允许的递归深度。 默认值见签名；`0` 表示不限制。
     * @throws IllegalArgumentException 任一预算为负数。
     *
     * @example 用法（profile: algorithms） {run}
     * ```cangjie
     * let limits = JsonSchemaLimits(maxEvaluations: 1)
     * let schema = JsonSchema.parse("true", config: JsonSchemaConfig(limits: limits))
     * println(schema.isValid(JsonNode.nullValue))
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public init(maxEvaluations!: Int64 = 100000, maxRefResolutions!: Int64 = 1000,
        maxRegexSteps!: Int64 = 100000, maxErrors!: Int64 = 100, maxDepth!: Int64 = 256) {
        requireWorkLimit(maxEvaluations, "maxEvaluations"); requireWorkLimit(maxRefResolutions, "maxRefResolutions")
        requireWorkLimit(maxRegexSteps, "maxRegexSteps"); requireWorkLimit(maxErrors, "maxErrors")
        requireWorkLimit(maxDepth, "maxDepth")
        this.maxEvaluations = maxEvaluations; this.maxRefResolutions = maxRefResolutions
        this.maxRegexSteps = maxRegexSteps; this.maxErrors = maxErrors; this.maxDepth = maxDepth
    }
    /**
     * 带签名所列有限预算的默认配置。
     *
     * @group 10-application 应用 API
     */
    public static let defaults = JsonSchemaLimits()
    /**
     * 关闭全部预算的配置；仅适用于输入与工作量受信任的场景。
     *
     * @group 10-application 应用 API
     */
    public static let unlimited = JsonSchemaLimits(maxEvaluations: 0, maxRefResolutions: 0,
        maxRegexSteps: 0, maxErrors: 0, maxDepth: 0)
}

private func requireWorkLimit(value: Int64, name: String): Unit {
    if (value < 0) { throw IllegalArgumentException("${name} must not be negative") }
}

func enforceWorkLimit(value: Int64, limit: Int64, dimension: String): Unit {
    if (limit > 0 && value > limit) {
        throw JsonException(
            "JSON algorithm ${dimension} budget exceeded: limit=${limit}, consumed=${value}",
            code: "work_limit_exceeded")
    }
}
