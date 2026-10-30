package yjson_codec_integration

import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

// Issue #15 R07/R15 external-consumer regressions: generated codecs must use
// the reader paths for skipped unknown members and boolean fields.

private func issue15ReaderBytes(text: String): Array<Byte> {
    unsafe { text.rawData().clone() }
}

private func issue15ReaderErrorCode(action: () -> Unit): String {
    try {
        action()
        ""
    } catch (error: JsonException) {
        error.code
    }
}

@JsonCodec
class Issue15ReaderKnown {
    public var value: Int64 = 0

    public init() {}
}

@JsonCodec
class Issue15ReaderFlag {
    public var flag: Bool = false

    public init() {}
}

@Test
class Issue15ReaderGeneratedConsumerTest {
    @TestCase
    func generatedCodecsSkipSpacedUnknownObjects(): Unit {
        let text = "{\"value\":7,\"extra\":{\"a\":1, \"b\":2, \"c\":[1, 2, {\"d\":3}]}}"
        // Default options use the generated fast path.
        @Expect(YJson.fromJson<Issue15ReaderKnown>(text).value, 7)
        @Expect(YJson.fromJson<Issue15ReaderKnown>(issue15ReaderBytes(text)).value, 7)
        // Non-default options use the semantic/direct path.
        let semantic = JsonReadOptions(maxDepth: 257)
        @Expect(YJson.fromJson<Issue15ReaderKnown>(text, options: semantic).value, 7)
        @Expect(YJson.fromJson<Issue15ReaderKnown>(issue15ReaderBytes(text),
            options: semantic).value, 7)
        @Expect(YJson.fromJson<Issue15ReaderKnown>(YJsonByteArrayInputStream(text)).value, 7)
    }

    @TestCase
    func generatedCodecsStillRejectMalformedSkippedObjects(): Unit {
        let malformed = "{\"value\":7,\"extra\":{\"a\":1, \"b\":2,}}"
        let fast = { => let _ = YJson.fromJson<Issue15ReaderKnown>(malformed) }
        @Expect(issue15ReaderErrorCode(fast), "parse_error")
        let semantic = JsonReadOptions(maxDepth: 257)
        let direct = { => let _ = YJson.fromJson<Issue15ReaderKnown>(malformed,
            options: semantic) }
        @Expect(issue15ReaderErrorCode(direct), "parse_error")
    }

    @TestCase
    func generatedBoolFieldTruncationReturnsParseError(): Unit {
        let truncated = "{\"flag\":"
        let codecAction: () -> Unit = { =>
            let _ = YJson.fromJson(truncated, codec: Issue15ReaderFlagJson)
        }
        @Expect(issue15ReaderErrorCode(codecAction), "parse_error")
        let textAction: () -> Unit = { =>
            let _ = YJson.fromJson<Issue15ReaderFlag>(truncated)
        }
        @Expect(issue15ReaderErrorCode(textAction), "parse_error")
        let semantic = JsonReadOptions(maxDepth: 257)
        let semanticAction: () -> Unit = { =>
            let _ = YJson.fromJson<Issue15ReaderFlag>(truncated, options: semantic)
        }
        @Expect(issue15ReaderErrorCode(semanticAction), "parse_error")
        let bytesAction: () -> Unit = { =>
            let _ = YJson.fromJson<Issue15ReaderFlag>(issue15ReaderBytes(truncated))
        }
        @Expect(issue15ReaderErrorCode(bytesAction), "parse_error")
        let streamAction: () -> Unit = { =>
            let _ = YJson.fromJson<Issue15ReaderFlag>(YJsonByteArrayInputStream(truncated))
        }
        @Expect(issue15ReaderErrorCode(streamAction), "parse_error")
    }

    @TestCase
    func generatedBoolFieldCompleteLiteralsStillDecode(): Unit {
        @Expect(YJson.fromJson<Issue15ReaderFlag>("{\"flag\":true}").flag, true)
        @Expect(YJson.fromJson<Issue15ReaderFlag>("{\"flag\":false}").flag, false)
        let encodedTrue = YJson.fromJson("{\"flag\":true}", codec: Issue15ReaderFlagJson)
        @Expect(encodedTrue.flag, true)
        let encodedFalse = YJson.fromJson("{\"flag\":false}", codec: Issue15ReaderFlagJson)
        @Expect(encodedFalse.flag, false)
        let roundTrip = YJson.fromJson(YJson.toJson(encodedTrue, codec: Issue15ReaderFlagJson),
            codec: Issue15ReaderFlagJson)
        @Expect(roundTrip.flag, true)
    }
}
