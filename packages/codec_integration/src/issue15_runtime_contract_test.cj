package yjson_codec_integration

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

private class Issue15NodeCodec <: JsonCodec<JsonNode> {
    public func write(value: JsonNode, writer: JsonWriter): Unit {
        GeneratedSupportV1.writeValue(value, writer)
    }

    public func read(reader: JsonReader): JsonNode { reader.readNode() }
}

private class Issue15SemanticMapCodec <: JsonCodec<HashMap<String, Int64>> {
    public func write(value: HashMap<String, Int64>, writer: JsonWriter): Unit {
        JsonCodecs.stringMap(JsonCodecs.int64).write(value, writer)
    }

    public func read(reader: JsonReader): HashMap<String, Int64> {
        let values = HashMap<String, Int64>()
        reader.startObject()
        while (reader.hasObjectField()) {
            let name = reader.readName()
            values[name] = reader.readInt64()
        }
        reader.endObject()
        values
    }
}

@JsonCodec
class Issue15RuntimeLeaf {
    public var x: Int64 = 1
    public init() {}
}

@JsonCodec
class Issue15ArrayMapEnvelope {
    public let entries: HashMap<String, Array<Int64>>
    public init(entries: HashMap<String, Array<Int64>>) { this.entries = entries }
}

@JsonCodec
class Issue15IntMapEnvelope {
    public let entries: HashMap<String, Int64>
    public init(entries: HashMap<String, Int64>) { this.entries = entries }
}

private class Issue15WrappedLeafCodec <: JsonCodec<Issue15RuntimeLeaf> {
    public func write(value: Issue15RuntimeLeaf, writer: JsonWriter): Unit {
        writer.startArray()
        Issue15RuntimeLeafJson.write(value, writer)
        writer.endArray()
    }

    public func read(reader: JsonReader): Issue15RuntimeLeaf {
        reader.startArray()
        let value = Issue15RuntimeLeafJson.read(reader)
        reader.endArray()
        value
    }
}

private func issue15WriteArrayMapEntry(mode: Int64, depth: Int64,
    values: HashMap<String, Array<Int64>>): String {
    let writer = JsonDirectWriter(JsonWriteOptions(maxDepth: depth))
    writer.writeRawBeginObject()
    match (mode) {
        case 0 => writer.writeRawObjectEntryKnownNameInt64ArrayMapBuffer(true, "entries", values)
        case 1 => writer.writeRawObjectEntryKnownNameInt64ArrayMapKnownAsciiBuffer(true, "entries", values)
        case _ => writer.writeRawObjectEntryKnownNameInt64ArrayMap(true, "entries", values)
    }
    writer.writeRawEndObject()
    writer.finishString()
}

@Test
class Issue15RuntimeContractTest {
    @TestCase
    func nestedNodeReaderConsumesEveryArraySeparator(): Unit {
        let codec = JsonCodecs.array(Issue15NodeCodec())
        let text = "[[1,2],[null,true,\"x\",{\"k\":[3,4]}]]"
        let values = YJson.fromJson(text, codec: codec)
        @Assert(values.size, 2)
        @Expect(values[0].toJson(), "[1,2]")
        @Expect(values[1].toJson(), "[null,true,\"x\",{\"k\":[3,4]}]")
        let bytes = YJson.fromJson(unsafe { text.rawData() }, codec: codec)
        @Expect(bytes[1].toJson(), values[1].toJson())
        for (invalid in ["[[1,]]", "[[1 2]]"]) {
            let error = @AssertThrows[JsonException](YJson.fromJson(invalid, codec: codec))
            @Expect(error.code, "parse_error")
        }
    }

    @TestCase
    func nullableNodeReaderDoesNotConsumeAPreparedPrefixTwice(): Unit {
        let codec = JsonCodecs.array(JsonCodecs.option(Issue15NodeCodec()))
        let values = YJson.fromJson("[null,[1,2],{\"k\":3}]", codec: codec)
        @Assert(values.size, 3)
        @Expect(values[0].isNone())
        @Expect(values[1].getOrThrow().toJson(), "[1,2]")
        @Expect(values[2].getOrThrow()["k"].asInt64(), 3)
    }

    @TestCase
    func nestedSemanticReadersRejectDecodedDuplicateNames(): Unit {
        let text = "[{\"a\":1,\"\\u0061\":2}]"
        let nodes = JsonCodecs.array(Issue15NodeCodec())
        let nodeError = @AssertThrows[JsonException](YJson.fromJson(text, codec: nodes))
        @Expect(nodeError.code, "duplicate_key")
        @Expect(nodeError.path, "/0")

        let maps = JsonCodecs.array(Issue15SemanticMapCodec())
        let mapError = @AssertThrows[JsonException](YJson.fromJson(text, codec: maps))
        @Expect(mapError.code, "duplicate_key")
        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        @Expect(YJson.fromJson(text, codec: maps, options: lastWins)[0]["a"], 2)
        @Expect(YJson.fromJson(text, codec: nodes, options: lastWins)[0]["a"].asInt64(), 2)
        @Expect(YJson.fromJson("[{\"a\":1},{\"a\":2}]", codec: maps)[1]["a"], 2)
    }

    @TestCase
    func bulkArrayMapsCountTheInnerArrayForEveryOutputTarget(): Unit {
        let codec = JsonCodecs.stringMap(JsonCodecs.array(JsonCodecs.int64))
        let values = HashMap<String, Array<Int64>>()
        values["x"] = [1]
        let limited = JsonWriteOptions(maxDepth: 1)
        let textError = @AssertThrows[JsonException](YJson.toJson(values, codec: codec, options: limited))
        @Expect(textError.code, "max_depth")
        let bytesError = @AssertThrows[JsonException](YJson.toJsonBytes(values, codec: codec, options: limited))
        @Expect(bytesError.code, "max_depth")
        let output = YJsonMemoryOutputStream()
        let streamError = @AssertThrows[JsonException](YJson.writeJson(values, output, codec: codec, options: limited))
        @Expect(streamError.code, "max_depth")

        let accepted = JsonWriteOptions(maxDepth: 2)
        @Expect(YJson.toJson(values, codec: codec, options: accepted), "{\"x\":[1]}")
        @Expect(String.fromUtf8(YJson.toJsonBytes(values, codec: codec, options: accepted)), "{\"x\":[1]}")
        let acceptedOutput = YJsonMemoryOutputStream()
        YJson.writeJson(values, acceptedOutput, codec: codec, options: accepted)
        @Expect(acceptedOutput.toUtf8String(), "{\"x\":[1]}")
        @Expect(YJson.toJson(HashMap<String, Array<Int64>>(), codec: codec, options: limited), "{}")
        values["x"] = []
        let emptyArrayError = @AssertThrows[JsonException](YJson.toJson(values, codec: codec, options: limited))
        @Expect(emptyArrayError.code, "max_depth")
    }

    @TestCase
    func generatedArrayMapFieldsIncludeBothContainerLevels(): Unit {
        let values = HashMap<String, Array<Int64>>()
        values["x"] = [1]
        let value = Issue15ArrayMapEnvelope(values)
        let limited = JsonWriteOptions(maxDepth: 2)
        let exactError = @AssertThrows[JsonException](YJson.toJson(value,
            codec: Issue15ArrayMapEnvelopeJson, options: limited))
        @Expect(exactError.code, "max_depth")
        let bytesError = @AssertThrows[JsonException](YJson.toJsonBytes(value,
            codec: Issue15ArrayMapEnvelopeJson, options: limited))
        @Expect(bytesError.code, "max_depth")
        let output = YJsonMemoryOutputStream()
        let streamError = @AssertThrows[JsonException](YJson.writeJson(value, output, options: limited))
        @Expect(streamError.code, "max_depth")
        let accepted = YJson.toJson(value, codec: Issue15ArrayMapEnvelopeJson,
            options: JsonWriteOptions(maxDepth: 3))
        @Expect(accepted, "{\"entries\":{\"x\":[1]}}")
        @Expect(YJson.toJson(Issue15ArrayMapEnvelope(HashMap<String, Array<Int64>>()),
            options: limited), "{\"entries\":{}}")
    }

    @TestCase
    func rawArrayMapEntryVariantsHonorTheirDocumentedDepthBudget(): Unit {
        let values = HashMap<String, Array<Int64>>()
        values["x"] = [1]
        for (mode in 0..3) {
            let error = @AssertThrows[JsonException](issue15WriteArrayMapEntry(mode, 2, values))
            @Expect(error.code, "max_depth")
            @Expect(issue15WriteArrayMapEntry(mode, 3, values), "{\"entries\":{\"x\":[1]}}")
            @Expect(issue15WriteArrayMapEntry(mode, 2, HashMap<String, Array<Int64>>()),
                "{\"entries\":{}}")
        }
    }

    @TestCase
    func generatedRawObjectsCountTheirSemanticParent(): Unit {
        let codec = Issue15WrappedLeafCodec()
        let value = Issue15RuntimeLeaf()
        let limited = JsonWriteOptions(maxDepth: 1)
        let compactError = @AssertThrows[JsonException](YJson.toJson(value, codec: codec, options: limited))
        @Expect(compactError.code, "max_depth")
        let bytesError = @AssertThrows[JsonException](YJson.toJsonBytes(value, codec: codec, options: limited))
        @Expect(bytesError.code, "max_depth")
        let prettyError = @AssertThrows[JsonException](YJson.toJson(value, codec: codec,
            options: JsonWriteOptions(indent: " ", maxDepth: 1)))
        @Expect(prettyError.code, "max_depth")
        let accepted = YJson.toJson(value, codec: codec, options: JsonWriteOptions(maxDepth: 2))
        @Expect(accepted, "[{\"x\":1}]")
        @Expect(YJson.fromJson(accepted, codec: codec).x, 1)
    }

    @TestCase
    func fastMapErrorsRetainTheParentArrayIndex(): Unit {
        let codec = JsonCodecs.array(JsonCodecs.stringMap(JsonCodecs.int64))
        let error = @AssertThrows[JsonException](YJson.fromJson(
            "[{}, {\"a/b\":1,\"a/b\":2}]", codec: codec))
        @Expect(error.code, "duplicate_key")
        @Expect(error.path, "/1/a~1b")
        let values = YJson.fromJson("[{\"first\":1},{\"second\":2}]", codec: codec)
        @Expect(values[0]["first"], 1)
        @Expect(values[1]["second"], 2)
    }

    @TestCase
    func generatedMapHelperRetainsAllParentSegments(): Unit {
        let error = @AssertThrows[JsonException](YJson.fromJson<Array<Issue15IntMapEnvelope>>(
            "[{\"entries\":{\"a/b\":1,\"a/b\":2}}]"))
        @Expect(error.code, "duplicate_key")
        @Expect(error.path, "/0/entries/a~1b")
    }
}
