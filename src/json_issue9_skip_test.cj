package yjson

import std.unittest.*
import std.unittest.testmacro.*

// A handwritten codec forces the semantic skip path, including default reads
// from String and bytes. AST parsing would not exercise this behavior.
private class Issue9SkipRootCodec <: JsonCodec<Int64> {
    public func write(value: Int64, writer: JsonWriter): Unit { writer.writeInt64(value) }
    public func read(reader: JsonReader): Int64 { reader.skipValue(); 7 }
}

private class Issue9SkipEnvelopeCodec <: JsonCodec<Int64> {
    public func write(value: Int64, writer: JsonWriter): Unit { writer.writeInt64(value) }
    public func read(reader: JsonReader): Int64 {
        var result: Int64 = -1
        reader.startObject()
        while (reader.hasObjectField()) {
            if (reader.readName() == "result") { result = reader.readInt64() }
            else { reader.skipValue() }
        }
        reader.endObject()
        result
    }
}

private func issue9AssertSkipInputs(text: String, codec: JsonCodec<Int64>,
    expected: Int64, options: JsonReadOptions): Unit {
    @Expect(YJson.fromJson(text, codec: codec, options: options), expected)
    let bytes = unsafe { text.rawData().clone() }
    @Expect(YJson.fromJson(bytes, codec: codec, options: options), expected)
    @Expect(YJson.fromJson(FixedChunkInputStream(text, 1), codec: codec, options: options), expected)
    for (split in 0..bytes.size) {
        @Expect(YJson.fromJson(SplitPointInputStream(bytes, split), codec: codec, options: options), expected)
    }
}

private func issue9AssertSkipErrors(text: String, options: JsonReadOptions,
    expectedCode: String): Unit {
    let codec = Issue9SkipRootCodec()
    @Expect(@AssertThrows[JsonException](YJson.fromJson(text, codec: codec,
        options: options)).code, expectedCode)
    let bytes = unsafe { text.rawData().clone() }
    @Expect(@AssertThrows[JsonException](YJson.fromJson(bytes, codec: codec,
        options: options)).code, expectedCode)
    for (split in 0..bytes.size) {
        @Expect(@AssertThrows[JsonException](YJson.fromJson(SplitPointInputStream(bytes, split),
            codec: codec, options: options)).code, expectedCode)
    }
}

private func issue9WideSkippedObject(count: Int64): String {
    let result = StringBuilder("{")
    for (index in 0..count) {
        if (index > 0) { result.append(",") }
        result.append("\"field_${index}\":${index}")
    }
    result.append("}")
    result.toString()
}

@Test
class JsonIssue9SkipTest {
    @TestCase
    func objectCommaWhitespaceAndNestedUnknownFields(): Unit {
        let rootCodec = Issue9SkipRootCodec()
        let envelopeCodec = Issue9SkipEnvelopeCodec()
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(maxInputBytes: 256, maxStringBytes: 32,
                maxBufferedValueBytes: 128, maxDepth: 4),
            JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)]) {
            for (space in [" ", "\t", "\r", "\n", " \t\r\n"]) {
                issue9AssertSkipInputs("{\"a\":1,${space}\"b\":2}", rootCodec, 7, options)
                issue9AssertSkipInputs("{\"unknown\":[{\"a\":1,${space}\"b\":2}],\"result\":9}",
                    envelopeCodec, 9, options)
            }
        }
    }

    @TestCase
    func duplicateNamesUseDecodedKeysAndObjectScopes(): Unit {
        let codec = Issue9SkipRootCodec()
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(maxInputBytes: 128, maxStringBytes: 32,
                maxBufferedValueBytes: 96, maxDepth: 4)]) {
            issue9AssertSkipErrors("{\"a\":1,\"a\":2}", options, "duplicate_key")
            issue9AssertSkipErrors("{\"a\":1,\"\\u0061\":2}", options, "duplicate_key")
            issue9AssertSkipErrors("{\"a\":{\"b\":1,\"\\u0062\":2}}", options, "duplicate_key")
            issue9AssertSkipInputs("{\"a\":{\"a\":1},\"b\":[{\"a\":2},{\"a\":3}]}", codec, 7, options)
        }
        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        issue9AssertSkipInputs("{\"a\":1, \"\\u0061\":2}", codec, 7, lastWins)
        issue9AssertSkipInputs("{\"a\":{\"b\":1, \"\\u0062\":2}}", codec, 7, lastWins)
    }

    @TestCase
    func whitespaceDoesNotPermitTrailingCommaOrMissingSeparator(): Unit {
        for (options in [JsonReadOptions.defaults,
            JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)]) {
            for (text in ["{\"a\":1,}", "{\"a\":1, \t\r\n}",
                "{\"a\":1 \"b\":2}", "{\"a\":1,\u{00a0}\"b\":2}", "[1, ]"]) {
                issue9AssertSkipErrors(text, options, "parse_error")
            }
        }
    }

    @TestCase
    func skippedWideObjectsRetainDuplicateAndScopeChecks(): Unit {
        // Bounded sizes are also used by the isolated work-count experiment.
        // No wall-clock threshold or large attack sample is required by CI.
        for (count in [128, 256, 512]) {
            let text = issue9WideSkippedObject(count)
            let codec = Issue9SkipRootCodec()
            @Expect(YJson.fromJson(text, codec: codec), 7)
            @Expect(YJson.fromJson(unsafe { text.rawData().clone() }, codec: codec), 7)
            @Expect(YJson.fromJson(FixedChunkInputStream(text, 7), codec: codec), 7)
            let fast = JsonFastReader(text)
            fast.skipValue(256)
            fast.expectEnd()
            let repeated = text[..text.size - 1] + ",\"field_0\":0}"
            @Expect(@AssertThrows[JsonException](YJson.fromJson(repeated, codec: codec)).code,
                "duplicate_key")
            let duplicateFast = JsonFastReader(repeated)
            @Expect(@AssertThrows[JsonException](duplicateFast.skipValue(256)).code, "duplicate_key")
        }
    }

    @TestCase
    func fastRawSkippedObjectsConsumeCommaWhitespace(): Unit {
        for (space in [" ", "\t", "\r", "\n", " \t\r\n"]) {
            let text = "{\"a\":1,${space}\"b\":{\"a\":1,${space}\"b\":2}}"
            let bounded = JsonFastReader(text)
            bounded.skipRawWithDepth(4)
            bounded.expectEnd()
            let raw = JsonFastReader(unsafe { text.rawData().clone() })
            raw.skipRaw()
            raw.expectEnd()
        }
        for (text in ["{\"a\":1,}", "{\"a\":1, \t\r\n}", "{\"a\":1 \"b\":2}"]) {
            let bounded = JsonFastReader(text)
            @Expect(@AssertThrows[JsonException](bounded.skipRawWithDepth(4)).code, "parse_error")
        }
    }

    @TestCase
    func zeroRemainingDepthSkipsScalarsAndRejectsObjectsAtTheirOpeningToken(): Unit {
        let options = JsonReadOptions(maxDepth: 1)
        let codec = Issue9SkipEnvelopeCodec()
        for (scalar in ["null", "true", "1", "\"中\""]) {
            issue9AssertSkipInputs("{\"unknown\":${scalar},\"result\":9}", codec, 9, options)
            // A caller-supplied zero remaining budget also allows scalars.
            let direct = JsonDirectReader(scalar)
            direct.skipValueWithDepth(0)
            direct.expectEnd()
        }

        let text = "\r\n{\n \"unknown\": \r\n {}}"
        let errors = [@AssertThrows[JsonException](JsonDirectReader(text, config: options)),
            @AssertThrows[JsonException](JsonDirectReader(
                unsafe { text.rawData().clone() }, config: options))]
        for (error in errors) {
            @Expect(error.code, "max_depth")
            @Expect(error.location.getOrThrow().byteOffset, 19)
            @Expect(error.location.getOrThrow().line, 4)
            @Expect(error.location.getOrThrow().column, 2)
        }
        for (chunk in 1..=text.size) {
            let reader = JsonDirectReader(FixedChunkInputStream(text, chunk), config: options)
            reader.startObject()
            @Expect(reader.readName(), "unknown")
            let error = @AssertThrows[JsonException](reader.skipValue())
            @Expect(error.code, "max_depth")
            @Expect(error.location.getOrThrow().byteOffset, 19)
            @Expect(error.location.getOrThrow().line, 4)
            @Expect(error.location.getOrThrow().column, 2)
        }
    }
}
