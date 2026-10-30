package yjson_codec_integration

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class Issue15MacroEscapedPair {
    public var a: String
    public var b: String

    public init(a: String, b: String) {
        this.a = a
        this.b = b
    }
}

@JsonCodec
class Issue15MacroBudgetPayload {
    public var text: String = ""

    public init() {}
}

private func issue15MacroBudgetError(code: String, action: () -> Unit): Unit {
    try {
        action()
        @Fail("expected JsonException with code ${code}")
    } catch (error: JsonException) {
        @Expect(error.code, code)
    }
}

@Test
class Issue15MacroCompactCapacityTest {
    @TestCase
    func escapedStringValuesKeepFollowingFieldsWritable(): Unit {
        // 40 U+0001 values expand sixfold while escaping; the 100-byte second
        // field then still needs its own capacity. Output must match the
        // implicit and semantic entry points byte for byte.
        let pair = Issue15MacroEscapedPair(
            String.fromUtf8(Array<Byte>(40, repeat: 1)),
            String.fromUtf8(Array<Byte>(100, repeat: b'x')))
        let expected = YJson.toJson(pair)
        @Expect(YJson.toJson(pair, codec: Issue15MacroEscapedPairJson), expected)
        let erased: JsonCodec<Issue15MacroEscapedPair> = Issue15MacroEscapedPairJson
        @Expect(YJson.toJson(pair, codec: erased), expected)
        @Expect(String.fromUtf8(YJson.toJsonBytes(pair, codec: Issue15MacroEscapedPairJson)),
            expected)
        let decoded = YJson.fromJson<Issue15MacroEscapedPair>(
            YJson.toJson(pair, codec: Issue15MacroEscapedPairJson))
        @Expect(decoded.a, pair.a)
        @Expect(decoded.b, pair.b)
        // A pretty-printed escape keeps the same value.
        let pretty = YJson.toJson(pair, options: JsonWriteOptions(indent: " "))
        let node = JsonNode.parse(pretty)
        @Expect(node["a"].asString(), pair.a)
        @Expect(node["b"].asString(), pair.b)
    }

    @TestCase
    func escapeHeavyTrailingFieldsRemainWritable(): Unit {
        // Escapes in the trailing field must not depend on the earlier bound.
        let pair = Issue15MacroEscapedPair(
            String.fromUtf8(Array<Byte>(1, repeat: b'x')),
            String.fromUtf8(Array<Byte>(64, repeat: 0x22)))
        let expected = YJson.toJson(pair)
        @Expect(YJson.toJson(pair, codec: Issue15MacroEscapedPairJson), expected)
        @Expect(String.fromUtf8(YJson.toJsonBytes(pair, codec: Issue15MacroEscapedPairJson)),
            expected)
        let decoded = YJson.fromJson(expected, codec: Issue15MacroEscapedPairJson)
        @Expect(decoded.b, pair.b)
    }
}

@Test
class Issue15MacroDefaultBudgetTest {
    private func deepDocument(): String {
        var nested = "0"
        for (_ in 0..JsonReadOptions.defaults.maxDepth) { nested = "[" + nested + "]" }
        "{\"unknown\":" + nested + "}"
    }

    @TestCase
    func concreteStringEntryUsesDefaultDepthBudget(): Unit {
        let text = deepDocument()
        let erased: JsonCodec<Issue15MacroBudgetPayload> = Issue15MacroBudgetPayloadJson
        issue15MacroBudgetError("max_depth", { =>
            let _ = YJson.fromJson(text, codec: Issue15MacroBudgetPayloadJson)
        })
        issue15MacroBudgetError("max_depth", { =>
            let _ = YJson.fromJson(text, codec: erased)
        })
        issue15MacroBudgetError("max_depth", { =>
            let _ = YJson.fromJson(unsafe { text.rawData() },
                codec: Issue15MacroBudgetPayloadJson)
        })
        // A document inside the budget still decodes through every entry.
        var legal = "0"
        for (_ in 0..(JsonReadOptions.defaults.maxDepth - 2)) { legal = "[" + legal + "]" }
        let accepted = "{\"text\":\"ok\",\"unknown\":" + legal + "}"
        @Expect(YJson.fromJson(accepted, codec: Issue15MacroBudgetPayloadJson).text, "ok")
        @Expect(YJson.fromJson(accepted, codec: erased).text, "ok")
        @Expect(YJson.fromJson(unsafe { accepted.rawData() },
            codec: Issue15MacroBudgetPayloadJson).text, "ok")
    }

    @TestCase
    func concreteStringEntryUsesDefaultBufferedValueBudget(): Unit {
        let big = String.fromUtf8(Array<Byte>(
            JsonReadOptions.defaults.maxBufferedValueBytes + 1, repeat: b'x'))
        let document = "{\"text\":\"" + big + "\"}"
        let erased: JsonCodec<Issue15MacroBudgetPayload> = Issue15MacroBudgetPayloadJson
        issue15MacroBudgetError("buffered_value_too_large", { =>
            let _ = YJson.fromJson(document, codec: Issue15MacroBudgetPayloadJson)
        })
        issue15MacroBudgetError("buffered_value_too_large", { =>
            let _ = YJson.fromJson(document, codec: erased)
        })
        issue15MacroBudgetError("buffered_value_too_large", { =>
            let _ = YJson.fromJson(unsafe { document.rawData() },
                codec: Issue15MacroBudgetPayloadJson)
        })
        // The exact budget boundary stays legal: the whole document span is
        // exactly the default limit.
        let boundarySize = JsonReadOptions.defaults.maxBufferedValueBytes -
            "{\"text\":\"\"}".size
        let boundary = String.fromUtf8(Array<Byte>(boundarySize, repeat: b'y'))
        let boundaryDocument = "{\"text\":\"" + boundary + "\"}"
        @Expect(YJson.fromJson(boundaryDocument,
            codec: Issue15MacroBudgetPayloadJson).text.size, boundary.size)
        @Expect(YJson.fromJson(unsafe { boundaryDocument.rawData() },
            codec: Issue15MacroBudgetPayloadJson).text.size, boundary.size)
    }

    @TestCase
    func smallInputsStillRejectMalformedValuesAndTrailingData(): Unit {
        let erased: JsonCodec<Issue15MacroBudgetPayload> = Issue15MacroBudgetPayloadJson
        for (text in [
            "{\"text\":\"\\uD800\"}",
            "{\"text\":\"\\q\"}",
            "{\"unknown\":[true,]}",
            "{\"text\":\"ok\"}false"
        ]) {
            issue15MacroBudgetError("parse_error", { =>
                let _ = YJson.fromJson<Issue15MacroBudgetPayload>(text)
            })
            issue15MacroBudgetError("parse_error", { =>
                let _ = YJson.fromJson(text, codec: Issue15MacroBudgetPayloadJson)
            })
            issue15MacroBudgetError("parse_error", { =>
                let _ = YJson.fromJson(text, codec: erased)
            })
            issue15MacroBudgetError("parse_error", { =>
                let _ = YJson.fromJson(unsafe { text.rawData() },
                    codec: Issue15MacroBudgetPayloadJson)
            })
        }
    }
}
