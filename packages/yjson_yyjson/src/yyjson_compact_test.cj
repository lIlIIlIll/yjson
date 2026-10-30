package yjson_yyjson

import yjson.*
import yjson_backends.*
import std.unittest.*
import std.unittest.testmacro.*

private func yyjsonBytes(text: String): Array<Byte> { unsafe { text.rawData() } }

@Test
class YyjsonCompactTests {
    @TestCase
    func directAndTranscodePreserveSemanticProjection(): Unit {
        let text = "{\"i\":-9223372036854775808,\"n\":1.2300,\"s\":\"普通😀\",\"a\":[true,null]}"
        for (mode in [YyjsonCompactMode.Direct, YyjsonCompactMode.Transcode]) {
            let document = YyjsonCompactJsonDocument.parse(yyjsonBytes(text),
                config: JsonReadOptions(), mode: mode)
            try {
                let root = document.root()
                @Expect(root.size(), 4)
                @Expect(root.member("i").getOrThrow().asInt64(), Int64.Min)
                @Expect(root.member("n").getOrThrow().asNumberText(), "1.2300")
                @Expect(root.member("s").getOrThrow().asString(), "普通😀")
                @Expect(root.member("a").getOrThrow().element(0).getOrThrow().asBool())
                let parsed = JsonNode.parse(document.toBytes()).asObject()
                @Expect(parsed.get("n").getOrThrow().asNumberText(), "1.2300")
                @Expect(parsed.get("s").getOrThrow().asString(), "普通😀")
            } finally { document.close() }
        }
    }

    @TestCase
    func escapedEquivalentDuplicateUsesLastWinsOrRejects(): Unit {
        let bytes = yyjsonBytes("{\"a\":1,\"\\u0061\":2}")
        let document = YyjsonCompactJsonDocument.parse(bytes,
            config: JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins))
        try {
            @Expect(document.root().member("a").getOrThrow().asInt64(), 2)
            @Expect(document.storageStats().customFallback, true)
        } finally { document.close() }
        let error = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(bytes,
            config: JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.Reject)))
        @Expect(error.code, "duplicate_key")
    }

    @TestCase
    func fallbackInlineMembersRejectMismatchedBooleanAccess(): Unit {
        // Escaped-equivalent duplicate names under LastWins route the document
        // to the custom-native fallback, where object scalars stay inline with
        // no node index. asBool must reject non-boolean inline values instead
        // of answering from node 0.
        let text = "{\"a\":1,\"\\u0061\":2,\"flags\":[true],\"text\":\"x\",\"ok\":false}"
        let options = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        try (document = YyjsonBackends.yyjson.parseDocument(text, options: options)) {
            @Expect(document.metadata().name, "custom-native-fallback")
            let root = document.root()
            @Expect(@AssertThrows[JsonException](
                root.member("text").getOrThrow().asBool()).code, "type_mismatch")
            @Expect(@AssertThrows[JsonException](
                root.member("a").getOrThrow().asBool()).code, "type_mismatch")
            @Expect(root.member("ok").getOrThrow().asBool(), false)
            @Expect(root.member("a").getOrThrow().asInt64(), 2)
            @Expect(root.member("text").getOrThrow().asString(), "x")
        }
    }

    @TestCase
    func directViewsRejectMismatchedBooleanAccess(): Unit {
        try (document = YyjsonBackends.yyjson.parseDocument(
            "{\"flags\":[true],\"text\":\"x\",\"ok\":false}")) {
            @Expect(document.metadata().name, "yyjson")
            let root = document.root()
            @Expect(@AssertThrows[JsonException](
                root.member("text").getOrThrow().asBool()).code, "type_mismatch")
            @Expect(root.member("ok").getOrThrow().asBool(), false)
            @Expect(root.member("flags").getOrThrow().element(0).getOrThrow().asBool(), true)
        }
    }

    @TestCase
    func closedFallbackInlineMembersReportResourceClosed(): Unit {
        // The resource check stays ahead of the inline kind check, so closing
        // keeps reporting resource_closed rather than a type mismatch.
        let options = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        let document = YyjsonBackends.yyjson.parseDocument(
            "{\"a\":1,\"\\u0061\":2,\"text\":\"x\"}", options: options)
        let text = document.root().member("text").getOrThrow()
        document.close()
        @Expect(@AssertThrows[JsonException](text.asBool()).code, "resource_closed")
        @Expect(@AssertThrows[JsonException](text.asInt64()).code, "resource_closed")
    }

    @TestCase
    func closeIsIdempotentAndGuardsLaterAccess(): Unit {
        let document = YyjsonCompactJsonDocument.parse(yyjsonBytes("[1,2]"))
        let root = document.root()
        document.close()
        document.close()
        let error = @AssertThrows[JsonException](root.size())
        @Expect(error.code, "resource_closed")
    }

    @TestCase
    func selectiveNumbersAvoidRawStorageForExactInt64(): Unit {
        let integers = YyjsonCompactJsonDocument.parse(yyjsonBytes("[0,-1,9223372036854775807]"),
            numberStrategy: YyjsonNumberStrategy.SelectiveSource)
        try {
            let stats = integers.storageStats()
            @Expect(stats.safeIntNumbers, 3u64)
            @Expect(stats.rawRequiredNumbers, 0u64)
            @Expect(stats.literalEntries, 0u64)
            @Expect(stats.sourceCopyBytes, 0u64)
        } finally { integers.close() }

        let mixed = YyjsonCompactJsonDocument.parse(yyjsonBytes(
            "[9223372036854775808,1.2300,1E-3]"),
            numberStrategy: YyjsonNumberStrategy.SelectiveSource)
        try {
            let stats = mixed.storageStats()
            @Expect(stats.rawRequiredNumbers, 3u64)
            @Expect(stats.literalEntries, 3u64)
            let text = mixed.toString()
            @Expect(text.contains("9223372036854775808"))
            @Expect(text.contains("1.2300"))
            @Expect(text.contains("1E-3"))
        } finally { mixed.close() }

        let hugeExponent = YyjsonCompactJsonDocument.parse(yyjsonBytes("1844674e07370"),
            numberStrategy: YyjsonNumberStrategy.SelectiveSource)
        try { @Expect(hugeExponent.toString(), "1844674e07370") }
        finally { hugeExponent.close() }
    }

    @TestCase
    func retainedAndLazyRootIndexesKeepLookupSemantics(): Unit {
        var text = "{"
        for (index in 0..300) {
            if (index != 0) { text += "," }
            text += "\"k${index}\":${index}"
        }
        text += "}"
        let retained = YyjsonCompactJsonDocument.parse(yyjsonBytes(text),
            lookupIndexMode: YyjsonLookupIndexMode.Retained)
        try {
            @Expect(retained.storageStats().rootIndexBuilds, 1u64)
            @Expect(retained.root().member("k299").getOrThrow().asInt64(), 299)
        } finally { retained.close() }
        let lazy = YyjsonCompactJsonDocument.parse(yyjsonBytes(text),
            lookupIndexMode: YyjsonLookupIndexMode.Lazy)
        try {
            @Expect(lazy.storageStats().rootIndexBuilds, 0u64)
            @Expect(lazy.root().member("k150").getOrThrow().asInt64(), 150)
            @Expect(lazy.storageStats().rootIndexBuilds, 1u64)
        } finally { lazy.close() }
    }

    @TestCase
    func invalidSemanticVectorsMatchPureErrorClasses(): Unit {
        // Mirrors src/json_semantic_vectors_test.cj invalid vectors. The
        // yyjson backend must classify failures with the same stable codes
        // and a concrete byte location as the portable path.
        let vectors = [
            "\"unterminated",
            "\"bad\\xescape\"",
            "\"\\uD83Dvalue\"",
            "01",
            "[1,]",
            "{\"a\" 1}",
            "{\"a\":true} trailing"
        ]
        for (text in vectors) {
            let pureError = try {
                let _ = JsonNode.parse(text)
                throw Exception("expected pure parse failure")
            } catch (error: JsonException) {
                error
            }
            let nativeError = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
                yyjsonBytes(text)))
            @Expect(nativeError.code, pureError.code)
            @Expect(nativeError.location.isSome())
            @Expect(nativeError.location.getOrThrow().byteOffset >= 0)
        }
    }

    @TestCase
    func invalidUtf8VectorsMatchPureErrorClass(): Unit {
        // Invalid UTF-8 inside a string is rejected with the same class as
        // the portable path.
        let bytes: Array<Byte> = [b'"', 0xF0, 0x28, 0x8C, 0x28, b'"']
        let pureError = try {
            let _ = JsonNode.parse(bytes)
            throw Exception("expected pure UTF-8 failure")
        } catch (error: JsonException) {
            error
        }
        let nativeError = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(bytes))
        @Expect(nativeError.code, pureError.code)
        @Expect(nativeError.location.isSome())
        @Expect(nativeError.location.getOrThrow().byteOffset >= 0)
    }

    @TestCase
    func locatedErrorsKeepExactSourceLocations(): Unit {
        for ((text, offset, line, column) in [
            ("{\n  \"a\" 1}", 8, 2, 7),
            ("{\"a\":true} trailing", 11, 1, 12),
            // yyjson points at the prohibited comma, not the closing bracket.
            ("[1,\n 2,]", 6, 2, 3)
        ]) {
            let error = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
                yyjsonBytes(text)))
            @Expect(error.code, "parse_error")
            let location = error.location.getOrThrow()
            @Expect(location.byteOffset, offset)
            @Expect(location.line, line)
            @Expect(location.column, column)
        }
    }

    @TestCase
    func duplicateKeyVectorsMatchPureErrorClass(): Unit {
        let vectors = ["{\"a\":1,\"a\":2}", "{\"a\":1,\"\\u0061\":2}"]
        for (text in vectors) {
            let pureError = try {
                let _ = JsonNode.parse(text)
                throw Exception("expected pure duplicate failure")
            } catch (error: JsonException) {
                error
            }
            let nativeError = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
                yyjsonBytes(text),
                config: JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.Reject)))
            @Expect(nativeError.code, pureError.code)
        }
    }

    @TestCase
    func resourceLimitsMatchPortableBackend(): Unit {
        let documentError = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
            yyjsonBytes("{\"a\":1}"), config: JsonReadOptions(maxInputBytes: 6)))
        @Expect(documentError.code, "document_too_large")
        let stringError = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
            yyjsonBytes("\"\\u4E2D\""), config: JsonReadOptions(maxStringBytes: 2)))
        @Expect(stringError.code, "string_too_large")
        let valueError = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
            yyjsonBytes("{\"a\":[1,2]}"),
            config: JsonReadOptions(maxBufferedValueBytes: 10)))
        @Expect(valueError.code, "buffered_value_too_large")
        let hiddenLocation = @AssertThrows[JsonException](YyjsonCompactJsonDocument.parse(
            yyjsonBytes("\"abc\""),
            config: JsonReadOptions(maxStringBytes: 2)))
        @Expect(hiddenLocation.code, "string_too_large")
        @Expect(hiddenLocation.location.isSome())
    }
}
