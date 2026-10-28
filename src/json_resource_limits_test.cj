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
            let _ = CompactJsonDocument.parseBorrowed(unsafe { arrayJson.rawData().clone() })
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
            let _ = CompactJsonDocument.parseBorrowed(unsafe { text.rawData() },
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

@Test
class JsonResourcePreflightSemanticsTest {
    private func expectErrorAt(error: JsonException, code: String, offset: Int64,
        line: Int64, column: Int64): Unit {
        @Expect(error.code, code)
        let location = error.location.getOrThrow()
        @Expect(location.byteOffset, offset)
        @Expect(location.line, line)
        @Expect(location.column, column)
    }

    @TestCase
    func preflightAcceptsEachJsonWhitespaceAtEveryValueEntry(): Unit {
        let mapCodec = JsonCodecs.stringMap(JsonCodecs.int64)
        for (space in [" ", "\t", "\r", "\n"]) {
            let scalar = space + "7" + space
            @Expect(YJson.fromJson(scalar, codec: JsonCodecs.int64), 7)
            @Expect(YJson.fromJson(scalar.toArray(), codec: JsonCodecs.int64), 7)

            let array = "[" + space + "1," + space + "2]"
            @Expect(YJson.parseDocument(array).materialize().toJson(), "[1,2]")
            @Expect(YJson.parseDocument(array.toArray()).materialize().toJson(), "[1,2]")

            let object = space + "{\"a\":" + space + "1,\"b\":" + space + "2}" + space
            let fromString = YJson.fromJson(object, codec: mapCodec)
            @Expect(fromString.size, 2)
            @Expect(fromString["a"], 1)
            @Expect(fromString["b"], 2)
            let fromBytes = YJson.fromJson(object.toArray(), codec: mapCodec)
            @Expect(fromBytes.size, 2)
            @Expect(fromBytes["a"], 1)
            @Expect(fromBytes["b"], 2)

            let nested = "{\"a\":" + space + "[" + space + "1," + space +
                "{\"b\":" + space + "2}]}"
            @Expect(YJson.parseDocument(nested).materialize().toJson(), "{\"a\":[1,{\"b\":2}]}")
            @Expect(YJson.parseDocument(nested.toArray()).materialize().toJson(), "{\"a\":[1,{\"b\":2}]}")
        }
    }

    @TestCase
    func preflightValueEntryFailuresKeepExactByteLocations(): Unit {
        // Each pair ends at EOF or at '?', after the same four JSON spaces.
        // The last case puts a two-byte key before the newline to distinguish
        // the absolute byte offset from a character count.
        let inputs = [
            "\n\r\t ", "\n\r\t ?",
            "[\n\r\t ", "[\n\r\t ?]",
            "[0,\n\r\t ", "[0,\n\r\t ?]",
            "{\"a\":\n\r\t ", "{\"a\":\n\r\t ?}",
            "{\"a\":[0,\n\r\t ", "{\"a\":[0,\n\r\t ?]}",
            "{\"é\":1,\n  \"b\":?}"
        ]
        let offsets: Array<Int64> = [4, 4, 5, 5, 7, 7, 9, 9, 12, 12, 15]
        let columns: Array<Int64> = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 7]
        for (index in 0..inputs.size) {
            let text = inputs[index]
            let fromString = @AssertThrows[JsonException](YJson.parseDocument(text))
            expectErrorAt(fromString, "parse_error", offsets[index], 2, columns[index])
            let fromBytes = @AssertThrows[JsonException](YJson.parseDocument(text.toArray()))
            expectErrorAt(fromBytes, "parse_error", offsets[index], 2, columns[index])
        }
    }

    @TestCase
    func typedPreflightKeepsLateSyntaxAndUtf8ErrorsBeforeDuplicateKeys(): Unit {
        let codec = JsonCodecs.stringMap(JsonCodecs.int64)
        let malformed = "{\"a\":1,\"a\":2,\n \"b\":?}"
        let syntaxFromString = @AssertThrows[JsonException](YJson.fromJson(malformed, codec: codec))
        expectErrorAt(syntaxFromString, "parse_error", 19, 2, 6)
        let syntaxFromBytes = @AssertThrows[JsonException](YJson.fromJson(malformed.toArray(), codec: codec))
        expectErrorAt(syntaxFromBytes, "parse_error", 19, 2, 6)

        let invalidUtf8 = "{\"a\":1,\"a\":2,\n \"b\":\"x\"}".toArray()
        invalidUtf8[20] = 0x80u8
        let utf8Error = @AssertThrows[JsonException](YJson.fromJson(invalidUtf8, codec: codec))
        expectErrorAt(utf8Error, "parse_error", 20, 2, 7)
    }

    @TestCase
    func documentPreflightKeepsLateStringBudgetBeforeDuplicateKeys(): Unit {
        let config = JsonReadOptions(maxStringBytes: 1)
        let text = "{\"a\":1,\"a\":2,\n \"b\":\"xy\"}"
        let fromString = @AssertThrows[JsonException](YJson.parseDocument(text, config: config))
        expectErrorAt(fromString, "string_too_large", 21, 2, 8)
        let fromBytes = @AssertThrows[JsonException](YJson.parseDocument(text.toArray(), config: config))
        expectErrorAt(fromBytes, "string_too_large", 21, 2, 8)
    }
}
