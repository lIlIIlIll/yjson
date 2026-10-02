package yjson

import std.unittest.*
import std.unittest.testmacro.*

private func resourceLimitErrorCode(action: () -> Unit): String {
    try {
        action()
        ""
    } catch (error: JsonException) {
        error.code
    }
}

private func rejectsResourceConfig(action: () -> Unit): Bool {
    try {
        action()
        false
    } catch (_: IllegalArgumentException) {
        true
    }
}

private func deepNestedArrayJson(depth: Int64): String {
    let builder = StringBuilder()
    for (_ in 0..depth) { builder.append("[") }
    builder.append("1")
    for (_ in 0..depth) { builder.append("]") }
    builder.toString()
}

private func deepNestedObjectJson(depth: Int64): String {
    let builder = StringBuilder()
    for (index in 0..depth) {
        builder.append("{\"k${index}\":")
    }
    builder.append("1")
    for (_ in 0..depth) { builder.append("}") }
    builder.toString()
}

private func buildNestedNode(depth: Int64): JsonNode {
    var value: JsonNode = JsonIntValue(1)
    for (_ in 0..depth) {
        let array = JsonArray()
        array.add(value)
        value = array
    }
    value
}

@Test
class JsonResourceLimitsTest {
    @TestCase
    func defaultReadAndWriteOptionsLockTheDocumentedBudgets(): Unit {
        let read = JsonReadOptions.defaults
        @Expect(read.maxInputBytes, 64 * 1024 * 1024)
        @Expect(read.maxStringBytes, 16 * 1024 * 1024)
        @Expect(read.maxBufferedValueBytes, 8 * 1024 * 1024)
        @Expect(read.maxDepth, 256)
        @Expect(match (read.unknownFieldPolicy) {
            case JsonUnknownFieldPolicy.Ignore => true
            case _ => false
        })
        @Expect(match (read.duplicateKeyPolicy) {
            case JsonDuplicateKeyPolicy.Reject => true
            case _ => false
        })

        let write = JsonWriteOptions.defaults
        @Expect(write.maxOutputBytes, 0)
        @Expect(write.maxDepth, 256)
        @Expect(write.indent, "")
        @Expect(write.htmlSafe, false)
    }

    @TestCase
    func defaultDepth256RoundTripsExactly256ContainerLevels(): Unit {
        let depth: Int64 = 256
        let arrayJson = deepNestedArrayJson(depth)
        @Expect(JsonNode.parse(arrayJson).asArray().size(), 1)
        @Expect(YJson.parseDocument(arrayJson).materialize().toString(), arrayJson)

        let objectJson = deepNestedObjectJson(depth)
        @Expect(JsonNode.parse(objectJson).toString(), objectJson)
        @Expect(YJson.parseDocument(objectJson).materialize().toString(), objectJson)

    }

    @TestCase
    func defaultDepth257RejectsWithMaxDepthForReadAndWrite(): Unit {
        let depth: Int64 = 257
        let arrayJson = deepNestedArrayJson(depth)
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse(arrayJson)
        }), "max_depth")
        @Expect(resourceLimitErrorCode({ =>
            let _ = CompactJsonDocument.parse(unsafe { arrayJson.rawData().clone() })
        }), "max_depth")
        @Expect(resourceLimitErrorCode({ =>
            let _ = YJson.fromJson(deepNestedArrayJson(depth), codec: JsonCodecs.int64)
        }), "max_depth")

        // Write-side budget: 256 container levels write fine under the default
        // budget; a 256-level write budget rejects the 257th container level.
        let writerDepth: Int64 = 256
        @Expect(buildNestedNode(writerDepth).toJson().size > 0, true)
        let rejectWritten = @AssertThrows[JsonException](
            buildNestedNode(writerDepth + 1).toJson(options: JsonWriteOptions(maxDepth: writerDepth)))
        @Expect(rejectWritten.code, "max_depth")
    }

    @TestCase
    func readLimitsMustBePositive(): Unit {
        @Expect(rejectsResourceConfig({ => let _ = JsonReadOptions(maxInputBytes: 0) }))
        @Expect(rejectsResourceConfig({ => let _ = JsonReadOptions(maxStringBytes: 0) }))
        @Expect(rejectsResourceConfig({ => let _ = JsonReadOptions(maxBufferedValueBytes: 0) }))
        @Expect(rejectsResourceConfig({ => let _ = JsonReadOptions(maxInputBytes: -1) }))
        @Expect(rejectsResourceConfig({ => let _ = JsonReadOptions(maxStringBytes: -1) }))
        @Expect(rejectsResourceConfig({ => let _ = JsonReadOptions(maxBufferedValueBytes: -1) }))
        @Expect(rejectsResourceConfig({ =>
            let _ = JsonDirectReader("null").readBoundedValue(-1)
        }))
    }

    @TestCase
    func documentLimitUsesExactInputBytes(): Unit {
        let text = "{\"a\":1}"
        @Expect(JsonNode.parse(text, config: JsonReadOptions(maxInputBytes: 7)).asObject().size(), 1)
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse(text, config: JsonReadOptions(maxInputBytes: 6))
        }), "document_too_large")
        @Expect(resourceLimitErrorCode({ =>
            let _ = CompactJsonDocument.parse(unsafe { text.rawData() },
                config: JsonReadOptions(maxInputBytes: 6))
        }), "document_too_large")
    }

    @TestCase
    func stringLimitCountsDecodedUtf8BytesForValuesAndKeys(): Unit {
        @Expect(JsonNode.parse("\"abc\"", config: JsonReadOptions(maxStringBytes: 3)).asString(),
            "abc")
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse("\"abc\"", config: JsonReadOptions(maxStringBytes: 2))
        }), "string_too_large")

        @Expect(JsonNode.parse("\"\\u4E2D\"", config: JsonReadOptions(maxStringBytes: 3)).asString(),
            "中")
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse("\"\\u4E2D\"", config: JsonReadOptions(maxStringBytes: 2))
        }), "string_too_large")
        @Expect(JsonNode.parse("\"🙂\"", config: JsonReadOptions(maxStringBytes: 4)).asString(),
            "🙂")
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse("{\"\\u4E2D\":1}", config: JsonReadOptions(maxStringBytes: 2))
        }), "string_too_large")
        @Expect(JsonNode.parse("\"\\uD83D\\uDE42\"",
            config: JsonReadOptions(maxStringBytes: 4)).asString(), "🙂")
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse("\"\\uD83D\\uDE42\"",
                config: JsonReadOptions(maxStringBytes: 3))
        }), "string_too_large")
    }

    @TestCase
    func byteStringBudgetCountsUtf8BytesOnce(): Unit {
        let payload = String.fromUtf8(Array<Byte>(9 * 1024 * 1024, repeat: b'a')) + "é中\u{10000}"
        let text = "\"" + payload + "\""
        @Expect(YJson.fromJson(unsafe { text.rawData() }, codec: JsonCodecs.string), payload)
    }

    @TestCase
    func escapedByteStringBudgetCountsUtf8BytesOnce(): Unit {
        let payload = String.fromUtf8(Array<Byte>(9 * 1024 * 1024, repeat: b'a')) + "é中\u{10000}"
        let text = "\"\\n" + payload + "\""
        @Expect(YJson.fromJson(unsafe { text.rawData() }, codec: JsonCodecs.string), "\n" + payload)
    }

    @TestCase
    func compactHomogeneousArraysHonorMaterializeNodeBudget(): Unit {
        for (text in ["[1,2,3]", "[\"a\",\"b\",\"c\"]", "[1.5,2.5,3.5]"]) {
            let document = YJson.parseDocument(text)
            let error = @AssertThrows[JsonException](document.materialize(2))
            @Expect(error.code, "work_limit_exceeded")
            @Expect(document.materialize(4).toString(), text)
        }
    }

    @TestCase
    func rootContainerLimitIncludesNestedContentButNotTrailingWhitespace(): Unit {
        let text = "{\"a\":[1,2]}"
        @Expect(JsonNode.parse(text + "   ",
            config: JsonReadOptions(maxBufferedValueBytes: text.size)).asObject().size(), 1)
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse(text,
                config: JsonReadOptions(maxBufferedValueBytes: text.size - 1))
        }), "buffered_value_too_large")
    }

    @TestCase
    func chunkedStreamEnforcesAllLimitsDuringTypedDecode(): Unit {
        @Expect(YJson.fromJson(FixedChunkInputStream("\"中\"", 1), codec: JsonCodecs.string, options: JsonReadOptions(maxInputBytes: 5, maxStringBytes: 3)), "中")
        @Expect(resourceLimitErrorCode({ =>
            let _ = YJson.fromJson(FixedChunkInputStream("\"中\"", 1), codec: JsonCodecs.string, options: JsonReadOptions(maxStringBytes: 2))
        }), "string_too_large")
        @Expect(resourceLimitErrorCode({ =>
            let _ = YJson.fromJson(FixedChunkInputStream("\"abc\"", 1), codec: JsonCodecs.string, options: JsonReadOptions(maxInputBytes: 4))
        }), "document_too_large")
        @Expect(resourceLimitErrorCode({ =>
            let _ = YJson.fromJson(FixedChunkInputStream("[1,2]", 1), codec: JsonCodecs.array(JsonCodecs.int64), options: JsonReadOptions(maxBufferedValueBytes: 4))
        }), "buffered_value_too_large")
        @Expect(resourceLimitErrorCode({ =>
            let _ = YJson.fromJson(FixedChunkInputStream("[    ", 1), codec: JsonCodecs.array(JsonCodecs.int64), options: JsonReadOptions(maxBufferedValueBytes: 4))
        }), "buffered_value_too_large")
    }

    @TestCase
    func resourceErrorsAlwaysCarryLocations(): Unit {
        let error = @AssertThrows[JsonException](JsonNode.parse("\"abc\"",
            config: JsonReadOptions(maxStringBytes: 2)))
        @Expect(error.code, "string_too_large")
        @Expect(error.location.isSome())
    }

    @TestCase
    func streamResourceLocationsMatchUtf8ByteCoordinates(): Unit {
        let cases = [
            ("\"ab\"", JsonReadOptions(maxStringBytes: 1), "string_too_large", 2, 1, 3),
            ("\n\"ab\"", JsonReadOptions(maxStringBytes: 1), "string_too_large", 3, 2, 3),
            ("\r\n\"ab\"", JsonReadOptions(maxStringBytes: 1), "string_too_large", 4, 2, 3),
            ("\n\"中a\"", JsonReadOptions(maxStringBytes: 3), "string_too_large", 5, 2, 5),
            ("\n[\n[]]", JsonReadOptions(maxDepth: 1), "max_depth", 3, 3, 1),
            ("\n[\n1]", JsonReadOptions(maxBufferedValueBytes: 3), "buffered_value_too_large", 4, 3, 2),
            ("\n\"ab\"", JsonReadOptions(maxInputBytes: 3), "document_too_large", 3, 2, 3),
            ("\r\n\"ab\"", JsonReadOptions(maxInputBytes: 4), "document_too_large", 4, 2, 3),
            ("\n\"中a\"", JsonReadOptions(maxInputBytes: 5), "document_too_large", 5, 2, 5)
        ]
        for ((text, options, code, offset, line, column) in cases) {
            let bytes = unsafe { text.rawData() }
            let fromText = @AssertThrows[JsonException](JsonNode.parse(text, config: options))
            let fromBytes = @AssertThrows[JsonException](JsonNode.parse(bytes, config: options))
            @Expect(fromText.code, code)
            @Expect(fromBytes.code, code)
            @Expect(fromText.location.getOrThrow().byteOffset, offset)
            @Expect(fromText.location.getOrThrow().line, line)
            @Expect(fromText.location.getOrThrow().column, column)
            @Expect(fromBytes.location.getOrThrow().byteOffset, offset)
            @Expect(fromBytes.location.getOrThrow().line, line)
            @Expect(fromBytes.location.getOrThrow().column, column)
            for (chunk in 1..=text.size) {
                let fromStream = @AssertThrows[JsonException](parseJsonValueFromStream(
                    FixedChunkInputStream(text, chunk), config: options))
                @Expect(fromStream.code, code)
                @Expect(fromStream.location.getOrThrow().byteOffset, offset)
                @Expect(fromStream.location.getOrThrow().line, line)
                @Expect(fromStream.location.getOrThrow().column, column)
                let skipped = @AssertThrows[JsonException](
                    JsonDirectReader(FixedChunkInputStream(text, chunk), config: options).skipValue())
                @Expect(skipped.code, code)
                @Expect(skipped.location.getOrThrow().byteOffset, offset)
                @Expect(skipped.location.getOrThrow().line, line)
                @Expect(skipped.location.getOrThrow().column, column)
            }
        }
    }

    @TestCase
    func streamTypedStringResourceLocationsMatchAcrossEveryChunk(): Unit {
        for (text in ["\n\"ab\"", "\r\n\"ab\""]) {
            for (chunk in 1..=text.size) {
                let error = @AssertThrows[JsonException](YJson.fromJson(
                    FixedChunkInputStream(text, chunk), codec: JsonCodecs.string,
                    options: JsonReadOptions(maxStringBytes: 1)))
                @Expect(error.code, "string_too_large")
                @Expect(error.location.getOrThrow().byteOffset, text.size - 2)
                @Expect(error.location.getOrThrow().line, 2)
                @Expect(error.location.getOrThrow().column, 3)
            }
        }
    }

    @TestCase
    func unavailableStreamLocationKeepsTheResourceError(): Unit {
        let cursor = StreamInputCursor(FixedChunkInputStream("null", 1))
        let error = jsonResourceLimitException(cursor, "Input limit", "document_too_large", 9)
        @Expect(error.code, "document_too_large")
        @Expect(error.location.isNone())
        @Expect(cursor.hasMore())
        @Expect(cursor.lineAt(9), -1)
        @Expect(cursor.columnAt(9), -1)
        @Expect(jsonResourceLimitException(cursor, "Unknown", "max_depth", -1).location.isNone())
    }

    @TestCase
    func streamLookaheadCoordinatesRemainStableAcrossConsumedNewlines(): Unit {
        // Locations use UTF-8 byte columns. An LF belongs to the preceding
        // line, and CRLF contributes only one line transition.
        let text = "a\r\nb\n中z"
        let coordinates = [
            (0, 1, 1), (1, 1, 2), (2, 1, 3), (3, 2, 1),
            (4, 2, 2), (5, 3, 1), (8, 3, 4), (9, 3, 5)
        ]
        let cursor = StreamInputCursor(FixedChunkInputStream(text, text.size))
        @Expect(cursor.hasMore())
        for ((offset, line, column) in coordinates) {
            @Expect(cursor.lineAt(offset), line)
            @Expect(cursor.columnAt(offset), column)
        }
        @Expect(cursor.position(), 0)
        @Expect(cursor.lineAt(10), -1)
        @Expect(cursor.columnAt(10), -1)

        @Expect(cursor.consume(), b'a')
        @Expect(cursor.consume(), b'\r')
        @Expect(cursor.consume(), b'\n')
        // Past locations now use recorded newlines, while future locations
        // combine that history with the LF still in the unconsumed window.
        for ((offset, line, column) in coordinates) {
            @Expect(cursor.lineAt(offset), line)
            @Expect(cursor.columnAt(offset), column)
        }
        @Expect(cursor.position(), 3)
        @Expect(cursor.lineAt(10), -1)
        @Expect(cursor.columnAt(10), -1)
    }

    @TestCase
    func directContainerDepthErrorsPointAtTheRejectedOpeningToken(): Unit {
        let text = "\r\n{\n \"child\": \r\n {}}"
        let options = JsonReadOptions(maxDepth: 1)
        // String and byte readers validate resource limits at construction.
        // Stream readers enforce the same boundary as tokens are consumed.
        let errors = [@AssertThrows[JsonException](JsonDirectReader(text, config: options)),
            @AssertThrows[JsonException](JsonDirectReader(
                unsafe { text.rawData().clone() }, config: options))]
        for (error in errors) {
            @Expect(error.code, "max_depth")
            @Expect(error.location.getOrThrow().byteOffset, 17)
            @Expect(error.location.getOrThrow().line, 4)
            @Expect(error.location.getOrThrow().column, 2)
        }
        for (chunk in 1..=text.size) {
            let reader = JsonDirectReader(FixedChunkInputStream(text, chunk), config: options)
            reader.startObject()
            @Expect(reader.readName(), "child")
            let error = @AssertThrows[JsonException](reader.startObject())
            @Expect(error.code, "max_depth")
            @Expect(error.location.getOrThrow().byteOffset, 17)
            @Expect(error.location.getOrThrow().line, 4)
            @Expect(error.location.getOrThrow().column, 2)
        }
    }

    @TestCase
    func astDepthCountsContainersOnlyForStringAndBytes(): Unit {
        let one = JsonReadOptions(maxDepth: 1)
        @Expect(JsonNode.parse("{\"name\":\"alice\"}", config: one).asObject().size(), 1)
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse("{\"child\":{}}", config: one)
        }), "max_depth")
        let nestedBytes = unsafe { "[[]]".rawData().clone() }
        @Expect(resourceLimitErrorCode({ =>
            let _ = JsonNode.parse(nestedBytes, config: one)
        }), "max_depth")
        @Expect(resourceLimitErrorCode({ =>
            let _ = parseJsonValueFromStream(FixedChunkInputStream("[[]]", 1), config: one)
        }), "max_depth")
    }

    @TestCase
    func boundedReplayDoesNotChargeScalarChildrenAsDepth(): Unit {
        let reader = JsonDirectReader("{\"name\":\"alice\"}", config: JsonReadOptions(maxDepth: 1))
        @Expect(reader.readBoundedValue(0).asObject()["name"].asString(), "alice")
    }

    @TestCase
    func skippedUnknownSubtreeUsesRemainingDepth(): Unit {
        let direct = JsonDirectReader("{\"unknown\":[[]]}", config: JsonReadOptions(maxDepth: 3))
        direct.startObject()
        @Expect(direct.readName(), "unknown")
        @Expect(resourceLimitErrorCode({ => direct.skipValueWithDepth(1) }), "max_depth")

        let fast = JsonFastReader("[[[]]]")
        @Expect(resourceLimitErrorCode({ => fast.skipRawWithDepth(2) }), "max_depth")
    }

    @TestCase
    func policyAndStreamErrorsCarryStableCodesAndLocations(): Unit {
        let duplicateConfig = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.Reject)
        let astDuplicate = @AssertThrows[JsonException](
            JsonNode.parse("{\"a\":1,\"a\":2}", config: duplicateConfig))
        @Expect(astDuplicate.code, "duplicate_key")

        let direct = JsonDirectReader("{\"a\":1,\"a\":2}", config: duplicateConfig)
        direct.startObject(); @Expect(direct.readName(), "a"); @Expect(direct.readInt64(), 1)
        let directDuplicate = @AssertThrows[JsonException](direct.readName())
        @Expect(directDuplicate.code, "duplicate_key")

        let streamError = @AssertThrows[JsonException](parseJsonValueFromStream(
            FixedChunkInputStream("{\n  \"a\": }", 1)))
        @Expect(streamError.code, "parse_error")
        @Expect(streamError.location.getOrThrow().byteOffset >= 0)
        @Expect(streamError.location.getOrThrow().line, 2)
        @Expect(streamError.location.getOrThrow().column > 0)

        let parserNewlineError = @AssertThrows[JsonException](parseJsonValueFromStream(
            FixedChunkInputStream("\"abc\ndef\"", 1)))
        @Expect(parserNewlineError.location.getOrThrow().byteOffset, 4)
        @Expect(parserNewlineError.location.getOrThrow().line, 1)
        @Expect(parserNewlineError.location.getOrThrow().column, 5)

        let directStream = JsonDirectReader(FixedChunkInputStream("\"abc\ndef\"", 1))
        let directNewlineError = @AssertThrows[JsonException](directStream.readString())
        @Expect(directNewlineError.location.getOrThrow().byteOffset, 4)
        @Expect(directNewlineError.location.getOrThrow().line, 1)
        @Expect(directNewlineError.location.getOrThrow().column, 5)
    }
}
