package yjson_codec_integration

import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class ApiDocumentationRecord {
    @JsonName["user_id"]
    @JsonAlias["legacy_id"]
    public let id: Int64

    @JsonIncludeNull
    public let nickname: Option<String>

    @JsonIgnore
    public var cacheKey: String = "local"

    public init(id: Int64, nickname: Option<String>) {
        this.id = id
        this.nickname = nickname
    }
}

private class ApiDocumentationPairCodec <: JsonCodec<ApiDocumentationRecord> {
    public func write(value: ApiDocumentationRecord, writer: JsonWriter): Unit {
        writer.startArray()
        writer.writeInt64(value.id)
        match (value.nickname) {
            case Some(name) => writer.writeString(name)
            case None => writer.writeNull()
        }
        writer.endArray()
    }

    public func read(reader: JsonReader): ApiDocumentationRecord {
        reader.startArray()
        if (!reader.hasArrayItem()) { throw reader.error("missing id", "pair_shape") }
        let id = reader.readInt64()
        if (!reader.hasArrayItem()) { throw reader.error("missing nickname", "pair_shape") }
        let nickname = if (reader.tryReadNull()) { None<String> } else { Some(reader.readString()) }
        reader.endArray()
        ApiDocumentationRecord(id, nickname)
    }
}

@Test
class ApiDocumentationContractConsumerTest {
    @TestCase
    func generatedWritesApplyUtf8OutputBudgetsAcrossTargets(): Unit {
        let value = ApiDocumentationRecord(7, Some("中\n"))
        let expected = "{\"user_id\":7,\"nickname\":\"中\\n\"}"
        let expectedBytes = unsafe { expected.rawData() }
        let byteCount = expectedBytes.size
        let exact = JsonWriteOptions(maxOutputBytes: byteCount)
        let tooSmall = JsonWriteOptions(maxOutputBytes: byteCount - 1)

        @Expect(YJson.toJson(value, options: exact), expected)
        @Expect(String.fromUtf8(YJson.toJsonBytes(value, options: exact)), expected)
        let output = YJsonMemoryOutputStream()
        YJson.writeJson(value, output, options: exact)
        @Expect(output.toUtf8String(), expected)

        let stringError = @AssertThrows[JsonException](YJson.toJson(value, options: tooSmall))
        @Expect(stringError.code, "output_too_large")
        let bytesError = @AssertThrows[JsonException](YJson.toJsonBytes(value, options: tooSmall))
        @Expect(bytesError.code, "output_too_large")
        let streamError = @AssertThrows[JsonException](
            YJson.writeJson(value, YJsonMemoryOutputStream(), options: tooSmall))
        @Expect(streamError.code, "output_too_large")

        @Expect(YJson.toJson(value, options: exact), expected)
    }

    @TestCase
    func handwrittenCodecUsesTheSameUtf8ContractForStringBytesAndStream(): Unit {
        let codec = ApiDocumentationPairCodec()
        let input = "[7,\"\\u4E2D\"]"
        let fromString = YJson.fromJson(input, codec: codec)
        let fromBytes = YJson.fromJson(unsafe { input.rawData() }, codec: codec)
        let fromStream = YJson.fromJson(YJsonByteArrayInputStream(input), codec: codec)
        for (value in [fromString, fromBytes, fromStream]) {
            @Expect(value.id, 7)
            @Expect(value.nickname.getOrThrow(), "中")
            @Expect(YJson.toJson(value, codec: codec), "[7,\"中\"]")
        }
    }

    @TestCase
    func handwrittenCodecPreservesNullAndDecodedStringByteBudgets(): Unit {
        let codec = ApiDocumentationPairCodec()
        let value = YJson.fromJson("[8,null]", codec: codec)
        @Expect(value.id, 8)
        @Expect(value.nickname.isNone(), true)
        @Expect(YJson.toJson(value, codec: codec), "[8,null]")
        for (input in ["[7,\"中\"]", "[7,\"\\u4E2D\"]"]) {
            @Expect(YJson.fromJson(input, codec: codec,
                options: JsonReadOptions(maxStringBytes: 3)).nickname.getOrThrow(), "中")
            let error = @AssertThrows[JsonException](YJson.fromJson(input, codec: codec,
                options: JsonReadOptions(maxStringBytes: 2)))
            @Expect(error.code, "string_too_large")
            @Expect(error.location.isSome(), true)
        }
    }

    @TestCase
    func explicitCodecRoundTripsUtf8Bytes(): Unit {
        let value = "仓颉 JSON"
        let bytes = YJson.toJsonBytes(value, codec: JsonCodecs.string)
        @Expect(YJson.fromJson(bytes, codec: JsonCodecs.string), value)
        @Expect(YJson.fromJson(YJson.toJson(value, codec: JsonCodecs.string),
            codec: JsonCodecs.string), value)
    }

    @TestCase
    func fieldAnnotationsPreserveTheirDocumentedWireContract(): Unit {
        let value = YJson.fromJson<ApiDocumentationRecord>(
            "{\"legacy_id\":7,\"nickname\":null,\"unknown\":true}")
        @Expect(value.id, 7)
        @Expect(value.nickname.isNone(), true)
        @Expect(value.cacheKey, "local")
        let document = YJson.parseDocument(YJson.toJson(value))
        let root = document.root()
        @Expect(root.member("user_id").getOrThrow().asInt64(), 7)
        @Expect(root.member("legacy_id").isNone(), true)
        @Expect(root.member("cacheKey").isNone(), true)
        @Expect(root.member("nickname").getOrThrow().kind(), JsonKind.Null)
    }

    @TestCase
    func defaultTypedReadsRejectDuplicateKeys(): Unit {
        var rejected = false
        try {
            let _ = YJson.fromJson<ApiDocumentationRecord>(
                "{\"user_id\":1,\"user_id\":2,\"nickname\":null}")
        } catch (error: JsonException) {
            rejected = error.code == "duplicate_key"
        }
        @Expect(rejected, true)
    }

    @TestCase
    func completeDocumentReadsRejectTrailingNonWhitespace(): Unit {
        var rejected = false
        try {
            let _ = YJson.fromJson("1 2", codec: JsonCodecs.int64)
        } catch (error: JsonException) {
            rejected = !error.code.isEmpty()
        }
        @Expect(rejected, true)
    }

    @TestCase
    func streamStringBudgetPrecedesLaterSyntaxErrors(): Unit {
        for (body in ["x中", "x\\u4E2D"]) {
            @Expect(YJson.fromJson(YJsonByteArrayInputStream("\"${body}\""),
                codec: JsonCodecs.string, options: JsonReadOptions(maxStringBytes: 4)), "x中")
            let error = @AssertThrows[JsonException](
                YJson.fromJson(YJsonByteArrayInputStream("\"${body}\\q\""),
                    codec: JsonCodecs.string, options: JsonReadOptions(maxStringBytes: 3)))
            @Expect(error.code, "string_too_large")
            @Expect(error.location.getOrThrow().byteOffset, 2)
        }
    }

    @TestCase
    func materializeMustNotShareMutableStorage(): Unit {
        let document = YJson.parseDocument("{\"active\":false}")
        let copy = document.materialize().asObject()
        copy.put("active", JsonNode.boolean(true))
        @Expect(document.root().member("active").getOrThrow().asBool(), false)
        @Expect(YJson.fromJson(copy.get("active").getOrThrow().toJson(),
            codec: JsonCodecs.bool), true)
    }
}
