package yjson_codec_integration

import std.collection.*
import std.sync.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

// Issue15SplitLeaf and Issue15SplitTagged live in
// issue15_macro_models_test.cj. These models must compose them through the
// public typed protocol, which is the only seam available across source files.

@JsonCodec
class Issue15SplitHolder {
    public var leaf: Issue15SplitLeaf = Issue15SplitLeaf()
    public var tag: Issue15SplitTagged = Issue15SplitTagged(0)

    public init() {}
}

@JsonCodec
class Issue15SplitArrayHolder {
    public var leaves: Array<Issue15SplitLeaf> = []

    public init() {}
}

@JsonCodec
class Issue15ConcurrentHolder {
    public var leaf: Issue15SplitLeaf = Issue15SplitLeaf()
    public var tag: Issue15SplitTagged = Issue15SplitTagged(0)

    public init() {}
}

@JsonCodec
open class Issue15OpenSplitHolder {
    public var leaf: Issue15SplitLeaf = Issue15SplitLeaf()
    public var tag: Issue15SplitTagged = Issue15SplitTagged(0)

    public init() {}
}

@JsonCodec
open class Issue15InheritedBase {
    public var baseId: Int64
    public var baseLabel: String

    public init(baseId: Int64, baseLabel: String) {
        this.baseId = baseId
        this.baseLabel = baseLabel
    }
}

@JsonCodec
class Issue15InheritedChild <: Issue15InheritedBase {
    public var childLabel: String

    public init(baseId: Int64, baseLabel: String, childLabel: String) {
        super(baseId, baseLabel)
        this.childLabel = childLabel
    }
}

@JsonCodec
open class Issue15InheritedMiddle <: Issue15InheritedBase {
    public var childLabel: String

    public init(baseId: Int64, baseLabel: String, childLabel: String) {
        super(baseId, baseLabel)
        this.childLabel = childLabel
    }
}

@JsonCodec
class Issue15InheritedGrandChild <: Issue15InheritedMiddle {
    public var depth: Int64

    public init(baseId: Int64, baseLabel: String, childLabel: String, depth: Int64) {
        super(baseId, baseLabel, childLabel)
        this.depth = depth
    }
}

@JsonCodec
open class Issue15ImplicitBase {
    public var baseId: Int64 = 5
}

@JsonCodec
class Issue15ImplicitChild <: Issue15ImplicitBase {
    public var extra: String = ""

    public init() {}
}

private func issue15SplitRejects(code: String, action: () -> Unit): Unit {
    try {
        action()
        @Fail("expected JsonException with code ${code}")
    } catch (error: JsonException) {
        @Expect(error.code, code)
    }
}

// A real base class that was never annotated: previously a compile error, so
// silently dropping its fields would be a new defect. The generated protocol
// must reject both directions instead.
open class Issue15PlainBase {
    public var baseValue: Int64 = 0

    public init() {}
}

@JsonCodec
class Issue15PlainChild <: Issue15PlainBase {
    public var childValue: Int64 = 0

    public init() {}
}

// Base class first, then an interface, then a second interface. The source
// macro cannot classify these entries, so all of them must be handled.
interface Issue15MarkerInterface {}

@JsonCodec
open class Issue15MixedBase {
    public var mixedId: Int64

    public init(mixedId: Int64) { this.mixedId = mixedId }
}

@JsonCodec
class Issue15MixedChild <: Issue15MixedBase & ToString & Issue15MarkerInterface {
    public var mixedExtra: String

    public init(mixedId: Int64, mixedExtra: String) {
        super(mixedId)
        this.mixedExtra = mixedExtra
    }

    public func toString(): String { mixedId.toString() + mixedExtra }
}

@Test
class Issue15MacroSplitFileNestingTest {
    @TestCase
    func splitFileNestedModelsCompileAndRoundTrip(): Unit {
        let holder = Issue15SplitHolder()
        holder.leaf = Issue15SplitLeaf()
        holder.leaf.x = 4
        holder.tag = Issue15SplitTagged(9)
        let text = YJson.toJson(holder)
        @Expect(text, "{\"leaf\":{\"x\":4},\"tag\":{\"id\":9}}")
        let decoded = YJson.fromJson<Issue15SplitHolder>(text)
        @Expect(decoded.leaf.x, 4)
        @Expect(decoded.tag.id, 9)
        // The concrete and erased entry points must agree.
        @Expect(YJson.toJson(decoded, codec: Issue15SplitHolderJson), text)
        @Expect(YJson.toJson<Issue15SplitHolder>(decoded,
            codec: Issue15SplitHolderJson), text)
        @Expect(String.fromUtf8(YJson.toJsonBytes(decoded,
            codec: Issue15SplitHolderJson)), text)
        let erased: JsonCodec<Issue15SplitHolder> = Issue15SplitHolderJson
        @Expect(YJson.fromJson(text, codec: erased).leaf.x, 4)
        @Expect(YJson.fromJson(unsafe { text.rawData() },
            codec: Issue15SplitHolderJson).tag.id, 9)
    }

    @TestCase
    func openSplitFileModelUsesTheExplicitRuntimeOverload(): Unit {
        // Open models have no implicit provider or concrete YJson overload.
        let text = "{\"leaf\":{\"x\":3},\"tag\":{\"id\":8}}"
        let value = YJson.fromJson(text, codec: Issue15OpenSplitHolderJson)
        @Expect(value.leaf.x, 3)
        @Expect(value.tag.id, 8)
        @Expect(YJson.toJson(value, codec: Issue15OpenSplitHolderJson), text)
    }

    @TestCase
    func concurrentFirstUsePublishesCompleteFieldCodecs(): Unit {
        let start = Mutex()
        let jobs = ArrayList<Future<String>>()
        synchronized(start) {
            for (index in 0..8) {
                jobs.add(spawn { =>
                    synchronized(start) {}
                    let text = "{\"leaf\":{\"x\":${index}},\"tag\":{\"id\":${index + 1}}}"
                    var encoded = ""
                    for (_ in 0..64) {
                        let value = YJson.fromJson<Issue15ConcurrentHolder>(text)
                        if (value.leaf.x != index || value.tag.id != index + 1) {
                            throw Exception("concurrent decode returned another worker's values")
                        }
                        encoded = YJson.toJson(value)
                        if (encoded != text) {
                            throw Exception("concurrent encode did not preserve the nested fields")
                        }
                    }
                    encoded
                })
            }
        }
        for (index in 0..jobs.size) {
            @Expect(jobs[index].get(),
                "{\"leaf\":{\"x\":${index}},\"tag\":{\"id\":${index + 1}}}")
        }
    }

    @TestCase
    func splitFileNestedModelsInsideCollections(): Unit {
        let holder = Issue15SplitArrayHolder()
        let first = Issue15SplitLeaf()
        first.x = 1
        let second = Issue15SplitLeaf()
        second.x = 2
        holder.leaves = [first, second]
        let text = YJson.toJson(holder)
        @Expect(text, "{\"leaves\":[{\"x\":1},{\"x\":2}]}")
        let decoded = YJson.fromJson<Issue15SplitArrayHolder>(text)
        @Expect(decoded.leaves.size, 2)
        @Expect(decoded.leaves[1].x, 2)
    }

    @TestCase
    func splitFileNestingKeepsErrorPaths(): Unit {
        let error = @AssertThrows[JsonException](
            YJson.fromJson<Issue15SplitHolder>("{\"leaf\":{\"x\":1,\"\\u0078\":2}}"))
        @Expect(error.code, "duplicate_key")
        @Expect(error.path, "/leaf/x")
    }
}

@Test
class Issue15MacroInheritedFieldsTest {
    @TestCase
    func generatedChildComposesInheritedBaseFields(): Unit {
        let child = Issue15InheritedChild(3, "base", "child")
        let text = YJson.toJson(child)
        @Expect(text, "{\"baseId\":3,\"baseLabel\":\"base\",\"childLabel\":\"child\"}")
        let decoded = YJson.fromJson<Issue15InheritedChild>(text)
        @Expect(decoded.baseId, 3)
        @Expect(decoded.baseLabel, "base")
        @Expect(decoded.childLabel, "child")
        // Every entry point must produce the same document.
        @Expect(YJson.toJson(decoded, codec: Issue15InheritedChildJson), text)
        let erased: JsonCodec<Issue15InheritedChild> = Issue15InheritedChildJson
        @Expect(YJson.toJson(decoded, codec: erased), text)
        @Expect(YJson.fromJson(text, codec: erased).baseLabel, "base")
        @Expect(YJson.fromJson(unsafe { text.rawData() },
            codec: Issue15InheritedChildJson).childLabel, "child")
    }

    @TestCase
    func threeLevelInheritanceComposesEachLevelOnce(): Unit {
        let value = Issue15InheritedGrandChild(1, "b", "c", 2)
        let text = YJson.toJson(value)
        @Expect(text,
            "{\"baseId\":1,\"baseLabel\":\"b\",\"childLabel\":\"c\",\"depth\":2}")
        let decoded = YJson.fromJson<Issue15InheritedGrandChild>(text)
        @Expect(decoded.baseId, 1)
        @Expect(decoded.childLabel, "c")
        @Expect(decoded.depth, 2)
    }

    @TestCase
    func inheritedFieldsSurviveImplicitBaseConstructor(): Unit {
        let child = Issue15ImplicitChild()
        child.extra = "e"
        @Expect(YJson.toJson(child), "{\"baseId\":5,\"extra\":\"e\"}")
        let decoded = YJson.fromJson<Issue15ImplicitChild>("{\"extra\":\"e\"}")
        @Expect(decoded.baseId, 5)
        @Expect(decoded.extra, "e")
    }

    @TestCase
    func genericInterfaceModelInAnotherFileRoundTrips(): Unit {
        let text = YJson.toJson(Issue15GenericTagged<Int64>(4))
        @Expect(text, "{\"value\":4}")
        @Expect(YJson.fromJson<Issue15GenericTagged<Int64>>(text).value, 4)
    }

    @TestCase
    func unannotatedRealBaseIsRejectedInsteadOfLosingFields(): Unit {
        let child = Issue15PlainChild()
        child.baseValue = 1
        child.childValue = 2
        // Write and read must both refuse: dropping the base fields would be
        // silent data loss, and accepting them would emit fields the base
        // codec does not own.
        issue15SplitRejects("codec_contract", { =>
            let _ = YJson.toJson(child)
        })
        issue15SplitRejects("codec_contract", { =>
            let _ = YJson.toJson(child, codec: Issue15PlainChildJson)
        })
        issue15SplitRejects("codec_contract", { =>
            let _ = YJson.fromJson<Issue15PlainChild>(
                "{\"baseValue\":1,\"childValue\":2}")
        })
        issue15SplitRejects("codec_contract", { =>
            let _ = YJson.fromJson("{\"baseValue\":1,\"childValue\":2}",
                codec: Issue15PlainChildJson)
        })
    }

    @TestCase
    func classFollowedByInterfacesComposesOnlyTheBaseFields(): Unit {
        let child = Issue15MixedChild(11, "e")
        let text = YJson.toJson(child)
        @Expect(text, "{\"mixedId\":11,\"mixedExtra\":\"e\"}")
        let decoded = YJson.fromJson<Issue15MixedChild>(text)
        @Expect(decoded.mixedId, 11)
        @Expect(decoded.mixedExtra, "e")
        let base = Issue15MixedBase(12)
        @Expect(YJson.toJson(base, codec: Issue15MixedBaseJson), "{\"mixedId\":12}")
        @Expect(YJson.fromJson("{\"mixedId\":12}", codec: Issue15MixedBaseJson).mixedId, 12)
    }
}
