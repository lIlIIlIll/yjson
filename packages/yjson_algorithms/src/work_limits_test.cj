package yjson_algorithms

import yjson.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class JsonAlgorithmWorkLimitsTest {
    @TestCase
    func pathAcceptsNAndRejectsNPlusOne(): Unit {
        let root = JsonNode.parse("{\"a\":1,\"b\":2}")
        @Expect(JsonPath.parse("$.a").collect(root,
            limits: JsonPathLimits(maxVisitedNodes: 1, maxMatches: 1)).size, 1)
        let error = @AssertThrows[JsonException](JsonPath.parse("$.*").collect(root,
            limits: JsonPathLimits(maxMatches: 1)))
        @Expect(error.code, "work_limit_exceeded")
    }

    @TestCase
    func pathChargesEnumeratedChildrenAndFilterSubqueries(): Unit {
        let root = JsonNode.parse("[{\"nested\":{\"value\":1}}]")
        @AssertThrows[JsonException](JsonPath.parse("$[*]").collect(root,
            limits: JsonPathLimits(maxVisitedNodes: 1)))
        @AssertThrows[JsonException](JsonPath.parse("$[?count(@..*) > 0]").collect(root,
            limits: JsonPathLimits(maxVisitedNodes: 2)))
    }

    @TestCase
    func patchAcceptsNAndRejectsNPlusOne(): Unit {
        let target = JsonNode.parse("{\"a\":1}")
        let one = JsonPatch.parse("[{\"op\":\"replace\",\"path\":\"/a\",\"value\":2}]")
        @Expect(one.apply(target, limits: JsonPatchLimits(maxOperations: 1))["a"].asInt64(), 2)
        let two = JsonPatch.parse("[{\"op\":\"replace\",\"path\":\"/a\",\"value\":2}," +
            "{\"op\":\"replace\",\"path\":\"/a\",\"value\":3}]")
        @AssertThrows[JsonException](two.apply(target,
            limits: JsonPatchLimits(maxOperations: 1)))
    }

    @TestCase
    func patchChargesValuesAndEachDynamicCopyBeforeAllocation(): Unit {
        let target = JsonNode.parse("{\"source\":[1,2],\"copies\":[]}")
        let oneCopy = JsonPatch.parse(
            "[{\"op\":\"copy\",\"from\":\"/source\",\"path\":\"/copies/-\"}]")
        let oneCopyResult = oneCopy.apply(target, limits: JsonPatchLimits(maxCopiedNodes: 8))
        @Expect(oneCopyResult["copies"].asArray().size(), 1)

        let twoCopies = JsonPatch.parse(
            "[{\"op\":\"copy\",\"from\":\"/source\",\"path\":\"/copies/-\"}," +
            "{\"op\":\"copy\",\"from\":\"/source\",\"path\":\"/copies/-\"}]")
        @AssertThrows[JsonException](twoCopies.apply(target,
            limits: JsonPatchLimits(maxCopiedNodes: 10)))

        let tested = JsonPatch.parse(
            "[{\"op\":\"test\",\"path\":\"/source\",\"value\":[1,2]}]")
        @AssertThrows[JsonException](tested.apply(target,
            limits: JsonPatchLimits(maxCopiedNodes: 7)))
    }

    @TestCase
    func schemaAcceptsNAndRejectsNPlusOne(): Unit {
        let one = JsonSchema.fromValue(JsonNode.boolean(true),
            config: JsonSchemaConfig(limits: JsonSchemaLimits(maxEvaluations: 1)))
        @Expect(one.validate(JsonNode.nullValue).isEmpty())
        let nested = JsonSchema.parse("{\"properties\":{\"a\":true}}",
            config: JsonSchemaConfig(limits: JsonSchemaLimits(maxEvaluations: 1)))
        let error = @AssertThrows[JsonException](nested.validate(JsonNode.parse("{\"a\":1}")))
        @Expect(error.code, "work_limit_exceeded")
    }

    @TestCase
    func schemaChargesUniqueComparisonsAndTracksRecursiveDepth(): Unit {
        let exact = JsonSchema.parse("{\"uniqueItems\":true}",
            config: JsonSchemaConfig(limits: JsonSchemaLimits(maxEvaluations: 2)))
        @Expect(exact.validate(JsonNode.parse("[1,2]")).isEmpty())
        let comparisonOverflow = JsonSchema.parse("{\"uniqueItems\":true}",
            config: JsonSchemaConfig(limits: JsonSchemaLimits(maxEvaluations: 1)))
        @AssertThrows[JsonException](comparisonOverflow.validate(JsonNode.parse("[1,2]")))

        let registry = JsonSchemaRegistry()
        registry.register("https://example.com/a/very/long/schema/path", "true")
        let shallow = JsonSchemaConfig(resolver: Some<UriResolver>(registry),
            limits: JsonSchemaLimits(maxDepth: 1))
        @Expect(JsonSchema.parse(
            "{\"$ref\":\"https://example.com/a/very/long/schema/path\"}", config: shallow)
            .validate(JsonNode.nullValue).isEmpty())

        registry.register("https://example.com/nested", "{\"properties\":{\"a\":true}}")
        let nested = JsonSchema.parse("{\"$ref\":\"https://example.com/nested\"}", config: shallow)
        @AssertThrows[JsonException](nested.validate(JsonNode.parse("{\"a\":1}")))
    }

    @TestCase
    func schemaErrorLimitCountsProducedErrorsOnly(): Unit {
        let exact = JsonSchema.parse("{\"allOf\":[false,true]}",
            config: JsonSchemaConfig(limits: JsonSchemaLimits(maxErrors: 1)))
        @Expect(exact.validate(JsonNode.nullValue).size, 1)

        let overflow = JsonSchema.parse("{\"allOf\":[false,false]}",
            config: JsonSchemaConfig(limits: JsonSchemaLimits(maxErrors: 1)))
        let error = @AssertThrows[JsonException](overflow.validate(JsonNode.nullValue))
        @Expect(error.code, "work_limit_exceeded")
    }

    @TestCase
    func patchTraversalStopsAtTheNodeBudget(): Unit {
        let patch = JsonPatch([])
        let probe = PatchTraversalProbe()
        let target = PatchProbeView(16, probe)
        @Expect(@AssertThrows[JsonException](patch.apply(target,
            limits: JsonPatchLimits(maxCopiedNodes: 8))).code, "work_limit_exceeded")
        @Expect(probe.childReads, 7)
        @Expect(probe.materializations, 0)

        let mergeProbe = PatchTraversalProbe()
        let mergeTargetProbe = PatchTraversalProbe()
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(PatchProbeView(0, mergeTargetProbe),
            PatchProbeView(16, mergeProbe), limits: JsonPatchLimits(maxCopiedNodes: 8)))
            .code, "work_limit_exceeded")
        @Expect(mergeProbe.childReads, 6)
        @Expect(mergeProbe.materializations, 0)
        @Expect(mergeTargetProbe.materializations, 0)
    }

    @TestCase
    func patchAndMergeRejectAncestorCycles(): Unit {
        let cycle = JsonArray()
        cycle.add(cycle)
        @Expect(@AssertThrows[JsonException](JsonPatch([]).apply(cycle)).code,
            "cyclic_json_node")
        @Expect(@AssertThrows[JsonException](JsonPatch([]).apply(cycle,
            limits: JsonPatchLimits.unlimited)).code, "cyclic_json_node")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(cycle, JsonNode.nullValue)).code,
            "cyclic_json_node")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(JsonNode.nullValue, cycle)).code,
            "cyclic_json_node")
        @Expect(cycle.size(), 1)
        @Expect(refEq(cycle[0], cycle))

        let objectCycle = JsonObject()
        objectCycle.put("self", objectCycle)
        @Expect(@AssertThrows[JsonException](JsonPatch([]).applyInPlace(objectCycle)).code,
            "cyclic_json_node")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.applyInPlace(objectCycle,
            JsonNode.object())).code, "cyclic_json_node")
        @Expect(objectCycle.size(), 1)
        @Expect(refEq(objectCycle["self"], objectCycle))
    }

    @TestCase
    func mergePatchRejectsCyclicTargetBeforeCopying(): Unit {
        let cycle = JsonArray()
        cycle.add(cycle)
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(cycle, JsonNode.nullValue)).code,
            "cyclic_json_node")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(cycle, JsonNode.nullValue,
            limits: JsonPatchLimits.unlimited)).code, "cyclic_json_node")
        @Expect(refEq(cycle[0], cycle))
    }

    @TestCase
    func mergePatchRejectsCyclicPatchBeforeCopying(): Unit {
        let cycle = JsonArray()
        cycle.add(cycle)
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(JsonNode.nullValue, cycle)).code,
            "cyclic_json_node")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(JsonNode.nullValue, cycle,
            limits: JsonPatchLimits.unlimited)).code, "cyclic_json_node")
        @Expect(refEq(cycle[0], cycle))
    }

    @TestCase
    func patchAndMergeHonorMaterializationDepthBoundary(): Unit {
        var accepted: JsonNode = JsonNode.int64(7)
        for (_ in 0..256) { accepted = JsonNode.array([accepted]) }
        let patch = JsonPatch([])
        @Expect(patch.apply(accepted, limits: JsonPatchLimits(maxCopiedNodes: 257)).kind(),
            JsonKind.Array)
        @Expect(JsonMergePatch.apply(accepted, JsonNode.nullValue,
            limits: JsonPatchLimits(maxCopiedNodes: 258)).isNull)
        let tooDeep = JsonNode.array([accepted])
        @Expect(@AssertThrows[JsonException](patch.apply(tooDeep)).code, "max_depth")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(tooDeep,
            JsonNode.nullValue)).code, "max_depth")
        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(JsonNode.nullValue,
            tooDeep)).code, "max_depth")
    }

    @TestCase
    func patchChargesSharedSubtreesForEveryDetachedOccurrence(): Unit {
        let shared = JsonNode.array([JsonNode.int64(1)])
        let target = JsonNode.array([shared, shared])
        let patch = JsonPatch([])
        @Expect(@AssertThrows[JsonException](patch.applyInPlace(target,
            limits: JsonPatchLimits(maxCopiedNodes: 4))).code, "work_limit_exceeded")
        @Expect(target.size(), 2)
        @Expect(refEq(target[0], target[1]))
        let result = patch.apply(target, limits: JsonPatchLimits(maxCopiedNodes: 5)).asArray()
        result[0].asArray().set(0, JsonNode.int64(2))
        @Expect(result[1][0].asInt64(), 1)
        @Expect(shared[0].asInt64(), 1)

        @Expect(@AssertThrows[JsonException](JsonMergePatch.apply(JsonNode.nullValue, target,
            limits: JsonPatchLimits(maxCopiedNodes: 5))).code, "work_limit_exceeded")
        let merged = JsonMergePatch.apply(JsonNode.nullValue, target,
            limits: JsonPatchLimits(maxCopiedNodes: 6)).asArray()
        merged[0].asArray().set(0, JsonNode.int64(3))
        @Expect(merged[1][0].asInt64(), 1)
        @Expect(shared[0].asInt64(), 1)
    }

}


private class PatchTraversalProbe {
    var childReads: Int64 = 0
    var materializations: Int64 = 0
}

// A compact view expands to a large binary tree. Its counters verify that
// rejecting a small budget never walks the whole graph or materializes it.
private class PatchProbeView <: JsonValueView {
    private let depth: Int64
    private let probe: PatchTraversalProbe
    init(depth: Int64, probe: PatchTraversalProbe) {
        this.depth = depth
        this.probe = probe
    }
    public func kind(): JsonKind { if (depth == 0) { JsonKind.Null } else { JsonKind.Array } }
    public func size(): Int64 { if (depth == 0) { 0 } else { 2 } }
    public func element(index: Int64): Option<JsonValueView> {
        probe.childReads++
        Some<JsonValueView>(PatchProbeView(depth - 1, probe))
    }
    public func member(name: String): Option<JsonValueView> { None<JsonValueView> }
    public func memberName(index: Int64): String { "" }
    public func memberValue(index: Int64): JsonValueView { JsonNode.nullValue }
    public func asBool(): Bool { false }
    public func asString(): String { "" }
    public func asInt64(): Int64 { 0 }
    public func asUInt64(): UInt64 { 0 }
    public func asFloat64(): Float64 { 0.0 }
    public func asNumberText(): String { "0" }
    public func materialize(): JsonNode {
        probe.materializations++
        JsonNode.nullValue
    }
    public func materialize(maxNodes: Int64): JsonNode { materialize() }
}
