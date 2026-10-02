package yjson_codec_integration

import std.io.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class Issue9ExternalSkipRecord {
    public let result: Int64
    public init(result: Int64) { this.result = result }
}

private class Issue9ExternalChunkStream <: InputStream {
    private let bytes: Array<Byte>
    private var index: Int64 = 0
    public init(text: String) { this.bytes = unsafe { text.rawData().clone() } }
    public func read(buffer: Array<Byte>): Int64 {
        if (index == bytes.size || buffer.isEmpty()) { return 0 }
        buffer[0] = bytes[index]
        index++
        1
    }
}

@Test
class Issue9ExternalUnknownSkipTest {
    @TestCase
    func generatedUnknownObjectSkipsAcceptJsonWhitespaceAcrossChunks(): Unit {
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(maxInputBytes: 128, maxStringBytes: 32,
                maxBufferedValueBytes: 96, maxDepth: 4),
            JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)]) {
            for (space in [" ", "\t", "\r", "\n", " \t\r\n"]) {
                let text = "{\"unknown\":[{\"a\":1,${space}\"b\":2}],\"result\":9}"
                @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(text, options: options).result, 9)
                @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(unsafe { text.rawData().clone() },
                    options: options).result, 9)
                @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(Issue9ExternalChunkStream(text),
                    options: options).result, 9)
            }
        }
    }

    @TestCase
    func generatedSkippedNamesPreserveRejectLastWinsAndNestedScopes(): Unit {
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(maxInputBytes: 128, maxStringBytes: 32,
                maxBufferedValueBytes: 96, maxDepth: 4)]) {
            let bad = "{\"unknown\":{\"a\":1,\"\\u0061\":2},\"result\":9}"
            @Expect(@AssertThrows[JsonException](YJson.fromJson<Issue9ExternalSkipRecord>(bad,
                options: options)).code, "duplicate_key")
            @Expect(@AssertThrows[JsonException](YJson.fromJson<Issue9ExternalSkipRecord>(
                unsafe { bad.rawData().clone() }, options: options)).code, "duplicate_key")
            @Expect(@AssertThrows[JsonException](YJson.fromJson<Issue9ExternalSkipRecord>(
                Issue9ExternalChunkStream(bad), options: options)).code, "duplicate_key")
            let scoped = "{\"unknown\":{\"a\":{\"a\":1},\"b\":{\"a\":2}},\"result\":9}"
            @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(scoped, options: options).result, 9)
            @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(unsafe { scoped.rawData().clone() },
                options: options).result, 9)
            @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(Issue9ExternalChunkStream(scoped),
                options: options).result, 9)
        }
        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        let repeated = "{\"unknown\":{\"a\":1, \"\\u0061\":2},\"result\":9}"
        @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(repeated, options: lastWins).result, 9)
        @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(unsafe { repeated.rawData().clone() },
            options: lastWins).result, 9)
        @Expect(YJson.fromJson<Issue9ExternalSkipRecord>(Issue9ExternalChunkStream(repeated),
            options: lastWins).result, 9)
        let trailing = "{\"unknown\":{\"a\":1, \n},\"result\":9}"
        @Expect(@AssertThrows[JsonException](YJson.fromJson<Issue9ExternalSkipRecord>(trailing)).code,
            "parse_error")
        @Expect(@AssertThrows[JsonException](YJson.fromJson<Issue9ExternalSkipRecord>(
            unsafe { trailing.rawData().clone() })).code, "parse_error")
        @Expect(@AssertThrows[JsonException](YJson.fromJson<Issue9ExternalSkipRecord>(
            Issue9ExternalChunkStream(trailing))).code, "parse_error")
    }
}
