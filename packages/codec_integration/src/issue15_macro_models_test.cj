package yjson_codec_integration

import std.collection.*
import std.sync.AtomicBool
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

// Declared in this source file, referenced by models in
// issue15_macro_split_nested_test.cj. The generated concrete codec global is
// file-private, so the cross-file reference must not use it by name.
@JsonCodec
class Issue15SplitLeaf {
    public var x: Int64 = 0

    public init() {}
}

@JsonCodec
class Issue15SplitTagged <: ToString {
    public let id: Int64

    public init(id: Int64) { this.id = id }

    public func toString(): String { id.toString() }
}

@JsonCodec
class Issue15SplitSelfReferential {
    @JsonIncludeNull
    public var child: Option<Issue15SplitSelfReferential> = None<Issue15SplitSelfReferential>
    public var value: Int64 = 0

    public init() {}
}

@JsonCodec
class Issue15GenericTagged<T> <: ToString {
    public let value: T

    public init(value: T) { this.value = value }
    public func toString(): String { "tagged" }
}

@Test
class Issue15MacroInterfaceOnlyModelTest {
    @TestCase
    func interfaceOnlyModelRoundTripsThroughEveryEntry(): Unit {
        let text = YJson.toJson(Issue15SplitTagged(7))
        @Expect(text, "{\"id\":7}")
        @Expect(YJson.fromJson<Issue15SplitTagged>(text).id, 7)
        let erased: JsonCodec<Issue15SplitTagged> = Issue15SplitTaggedJson
        @Expect(YJson.fromJson(text, codec: Issue15SplitTaggedJson).id, 7)
        @Expect(YJson.fromJson(text, codec: erased).id, 7)
        @Expect(YJson.fromJson(unsafe { text.rawData() },
            codec: Issue15SplitTaggedJson).id, 7)
        @Expect(YJson.toJson(Issue15SplitTagged(7),
            codec: Issue15SplitTaggedJson), "{\"id\":7}")
    }
}

@Test
class Issue15MacroSelfReferenceTest {
    @TestCase
    func optionalSelfReferenceUsesTheTypedProtocol(): Unit {
        let text = "{\"child\":{\"child\":null,\"value\":2},\"value\":1}"
        let value = YJson.fromJson<Issue15SplitSelfReferential>(text)
        @Expect(value.value, 1)
        @Expect(value.child.getOrThrow().value, 2)
        @Expect(value.child.getOrThrow().child.isNone())
        @Expect(YJson.toJson(value), text)
    }

    @TestCase
    func recursiveValuesRespectDepthAndDoNotPoisonLaterWrites(): Unit {
        let cycle = Issue15SplitSelfReferential()
        cycle.child = Some(cycle)
        let error = @AssertThrows[JsonException](
            YJson.toJson(cycle, options: JsonWriteOptions(maxDepth: 3)))
        @Expect(error.code, "max_depth")
        let value = Issue15SplitSelfReferential()
        value.value = 7
        @Expect(YJson.toJson(value), "{\"child\":null,\"value\":7}")
    }
}

private class Issue15DynamicCompactCodec <: JsonCodec<Issue15DynamicCompactValue> &
    GeneratedCursorWriteCodecV1<Issue15DynamicCompactValue> {
    private let enabled = AtomicBool(true)

    public func setEnabled(value: Bool): Unit { enabled.store(value) }
    public func supportsCompactCursorWrite(): Bool { enabled.load() }

    public func write(value: Issue15DynamicCompactValue, writer: JsonWriter): Unit {
        writer.writeInt64(value.value)
    }

    public func read(reader: JsonReader): Issue15DynamicCompactValue {
        Issue15DynamicCompactValue(reader.readInt64())
    }

    public func writeCompactWithCursor(value: Issue15DynamicCompactValue,
        writer: GeneratedSupportV1Writer, cursor: GeneratedSupportV1WriteCursor): Unit {
        let _ = writer
        if (!enabled.load()) {
            throw JsonException("The compact capability has been revoked", code: "codec_contract")
        }
        cursor.writeRawInt64(value.value)
    }
}

private let issue15DynamicCompactCodec = Issue15DynamicCompactCodec()

class Issue15DynamicCompactValue <: GeneratedCodecProviderV1<Issue15DynamicCompactValue> {
    public let value: Int64
    public init(value: Int64) { this.value = value }

    public static func generatedCodecV1(
        _: GeneratedCodecTokenV1<Issue15DynamicCompactValue>
    ): JsonCodec<Issue15DynamicCompactValue> {
        issue15DynamicCompactCodec
    }
}

@JsonCodec
class Issue15DynamicCompactEnvelope {
    public let items: HashMap<String, ArrayList<Option<Issue15DynamicCompactValue>>>
    public let others: Array<Issue15DynamicCompactValue>

    public init(items: HashMap<String, ArrayList<Option<Issue15DynamicCompactValue>>>,
        others: Array<Issue15DynamicCompactValue>) {
        this.items = items
        this.others = others
    }
}

@Test
class Issue15DynamicCompactCapabilityTest {
    @TestCase
    func revokingAndRestoringNestedCustomCapabilityPreservesEveryEntry(): Unit {
        let items = HashMap<String, ArrayList<Option<Issue15DynamicCompactValue>>>()
        items.add("group", ArrayList<Option<Issue15DynamicCompactValue>>([
            Some(Issue15DynamicCompactValue(7)), None]))
        let value = Issue15DynamicCompactEnvelope(items, [Issue15DynamicCompactValue(9)])
        let expected = "{\"items\":{\"group\":[7,null]},\"others\":[9]}"
        let erased: JsonCodec<Issue15DynamicCompactEnvelope> = Issue15DynamicCompactEnvelopeJson
        let compact = (erased as GeneratedCursorWriteCodecV1<Issue15DynamicCompactEnvelope>).getOrThrow()
        try {
            for (enabled in [true, false, true]) {
                issue15DynamicCompactCodec.setEnabled(enabled)
                @Expect(compact.supportsCompactCursorWrite(), enabled)
                @Expect(YJson.toJson(value), expected)
                @Expect(YJson.toJson(value, codec: Issue15DynamicCompactEnvelopeJson), expected)
                @Expect(YJson.toJson(value, codec: erased), expected)
                @Expect(String.fromUtf8(YJson.toJsonBytes(value)), expected)
                let output = YJsonMemoryOutputStream()
                YJson.writeJson(value, output)
                @Expect(output.toUtf8String(), expected)
                let decoded = YJson.fromJson<Issue15DynamicCompactEnvelope>(expected)
                @Expect(decoded.items["group"][0].getOrThrow().value, 7)
                @Expect(decoded.items["group"][1].isNone())
                @Expect(decoded.others[0].value, 9)
            }
        } finally {
            issue15DynamicCompactCodec.setEnabled(true)
        }
    }
}
