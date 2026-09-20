package yjson_codec_integration

import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class CodecRenderPlanExternalRecord {
    @JsonName["record_id"]
    @JsonAlias["legacy_id"]
    public let id: Int64
    public let label: String
    public let note: Option<String>
    public var active: Bool = true

    public init(id: Int64, label: String, note: Option<String>) {
        this.id = id
        this.label = label
        this.note = note
    }
}

@Test
class CodecRenderPlanExternalConsumerTest {
    @TestCase
    func compactEncodingPreservesNameOrderAndDefaultedMutableField(): Unit {
        let value = CodecRenderPlanExternalRecord(7, "Ada", None<String>)

        @Expect(YJson.toJson(value),
            "{\"record_id\":7,\"label\":\"Ada\",\"active\":true}")
    }

    @TestCase
    func prettyEncodingRoundTripsWithoutFixingWhitespaceLayout(): Unit {
        let value = CodecRenderPlanExternalRecord(7, "Ada", Some("memo"))
        value.active = false

        let text = YJson.toJson(value, options: JsonWriteOptions.pretty())
        let decoded = YJson.fromJson<CodecRenderPlanExternalRecord>(text)

        @Expect(decoded.id, 7)
        @Expect(decoded.label, "Ada")
        @Expect(decoded.note.getOrThrow(), "memo")
        @Expect(decoded.active, false)
    }

    @TestCase
    func aliasDecodingPreservesOptionalAndMutableFields(): Unit {
        let decoded = YJson.fromJson<CodecRenderPlanExternalRecord>(
            "{\"legacy_id\":8,\"label\":\"Grace\",\"note\":\"memo\",\"active\":false}")

        @Expect(decoded.id, 8)
        @Expect(decoded.label, "Grace")
        @Expect(decoded.note.getOrThrow(), "memo")
        @Expect(decoded.active, false)
    }

    @TestCase
    func rejectingUnknownFieldsStillAppliesMissingFieldDefaults(): Unit {
        let decoded = YJson.fromJson<CodecRenderPlanExternalRecord>(
            "{\"record_id\":9,\"label\":\"Lin\"}",
            options: JsonReadOptions(unknownFieldPolicy: JsonUnknownFieldPolicy.Reject))

        @Expect(decoded.id, 9)
        @Expect(decoded.label, "Lin")
        @Expect(decoded.note.isNone(), true)
        @Expect(decoded.active, true)
    }
}
