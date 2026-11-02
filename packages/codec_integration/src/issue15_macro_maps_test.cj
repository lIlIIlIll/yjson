package yjson_codec_integration

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class Issue15MacroIntMap {
    public let entries: HashMap<String, Int64>

    public init(entries: HashMap<String, Int64>) { this.entries = entries }
}

@JsonCodec
class Issue15MacroArrayMap {
    public let entries: HashMap<String, Array<Int64>>

    public init(entries: HashMap<String, Array<Int64>>) { this.entries = entries }
}

@JsonCodec
class Issue15MacroSkipItem {
    public let x: Int64

    public init(x: Int64) { this.x = x }
}

private func issue15MacroRejects(code: String, action: () -> Unit): Unit {
    try {
        action()
        @Fail("expected JsonException with code ${code}")
    } catch (error: JsonException) {
        @Expect(error.code, code)
    }
}

@Test
class Issue15MacroMapPolicyTest {
    @TestCase
    func generatedIntMapRejectsDuplicateNamesUnlessLastWins(): Unit {
        let duplicate = "{\"entries\":{\"x\":1,\"x\":2}}"
        let escapedDuplicate = "{\"entries\":{\"x\":1,\"\\u0078\":2}}"
        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        let erased: JsonCodec<Issue15MacroIntMap> = Issue15MacroIntMapJson
        for (text in [duplicate, escapedDuplicate]) {
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson<Issue15MacroIntMap>(text)
            })
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(text, codec: Issue15MacroIntMapJson)
            })
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(text, codec: erased)
            })
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(unsafe { text.rawData() },
                    codec: Issue15MacroIntMapJson)
            })
            // Non-default budgets also keep the default duplicate policy.
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(text, codec: Issue15MacroIntMapJson,
                    options: JsonReadOptions(maxDepth: 257))
            })
            @Expect(YJson.fromJson<Issue15MacroIntMap>(text, options: lastWins).entries["x"], 2)
            @Expect(YJson.fromJson(text, codec: Issue15MacroIntMapJson,
                options: lastWins).entries["x"], 2)
            @Expect(YJson.fromJson(text, codec: erased, options: lastWins).entries["x"], 2)
            @Expect(YJson.fromJson(unsafe { text.rawData() },
                codec: Issue15MacroIntMapJson, options: lastWins).entries["x"], 2)
        }
    }

    @TestCase
    func generatedArrayMapRejectsDuplicateNamesUnlessLastWins(): Unit {
        let duplicate = "{\"entries\":{\"x\":[1],\"x\":[2]}}"
        let escapedDuplicate = "{\"entries\":{\"x\":[1],\"\\u0078\":[2]}}"
        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        let erased: JsonCodec<Issue15MacroArrayMap> = Issue15MacroArrayMapJson
        for (text in [duplicate, escapedDuplicate]) {
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson<Issue15MacroArrayMap>(text)
            })
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(text, codec: Issue15MacroArrayMapJson)
            })
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(text, codec: erased)
            })
            issue15MacroRejects("duplicate_key", { =>
                let _ = YJson.fromJson(unsafe { text.rawData() },
                    codec: Issue15MacroArrayMapJson)
            })
            @Expect(YJson.fromJson<Issue15MacroArrayMap>(text, options: lastWins).entries["x"][0], 2)
            @Expect(YJson.fromJson(text, codec: Issue15MacroArrayMapJson,
                options: lastWins).entries["x"][0], 2)
            @Expect(YJson.fromJson(text, codec: erased, options: lastWins).entries["x"][0], 2)
        }
        // Distinct names still decode every entry.
        let distinct = YJson.fromJson<Issue15MacroArrayMap>(
            "{\"entries\":{\"x\":[1],\"y\":[2,3]}}")
        @Expect(distinct.entries["x"][0], 1)
        @Expect(distinct.entries["y"][1], 3)
    }

    @TestCase
    func generatedMapLastWinsKeepsLastWrittenValue(): Unit {
        // LastWins must stay observable through the concrete writer as well:
        // decoding keeps the last value and re-encoding never resurrects the
        // first one.
        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        let values = YJson.fromJson<Issue15MacroIntMap>(
            "{\"entries\":{\"x\":1,\"x\":2,\"y\":3}}", options: lastWins)
        @Expect(values.entries.size, 2)
        @Expect(values.entries["x"], 2)
        let encoded = JsonNode.parse(YJson.toJson(values))
        @Expect(encoded["entries"].asObject().size(), 2)
        @Expect(encoded["entries"]["x"].asInt64(), 2)
        @Expect(encoded["entries"]["y"].asInt64(), 3)
    }
}

@Test
class Issue15MacroUnknownFieldPolicyTest {
    private func itemText(): String {
        "{\"x\":1,\"junk\":{\"a\":1,\"a\":2}}"
    }

    @TestCase
    func arrayElementsApplyDuplicatePolicyWhileSkippingUnknownFields(): Unit {
        let text = itemText()
        let codec = JsonCodecs.array<Issue15MacroSkipItem>(Issue15MacroSkipItemJson)
        issue15MacroRejects("duplicate_key", { =>
            let _ = YJson.fromJson<Issue15MacroSkipItem>(text)
        })
        issue15MacroRejects("duplicate_key", { =>
            let _ = YJson.fromJson("[" + text + "]", codec: codec)
        })
        issue15MacroRejects("duplicate_key", { =>
            let _ = YJson.fromJson(unsafe { ("[" + text + "]").rawData() }, codec: codec)
        })

        let lastWins = JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)
        @Expect(YJson.fromJson("[" + text + "]", codec: codec, options: lastWins)[0].x, 1)
        @Expect(YJson.fromJson<Issue15MacroSkipItem>(text, options: lastWins).x, 1)
    }

    @TestCase
    func skippedUnknownValuesKeepDepthAndSyntaxChecks(): Unit {
        let codec = JsonCodecs.array<Issue15MacroSkipItem>(Issue15MacroSkipItemJson)
        var nested = "0"
        for (_ in 0..JsonReadOptions.defaults.maxDepth) { nested = "[" + nested + "]" }
        let deep = "{\"x\":1,\"junk\":" + nested + "}"
        issue15MacroRejects("max_depth", { =>
            let _ = YJson.fromJson<Issue15MacroSkipItem>(deep)
        })
        issue15MacroRejects("max_depth", { =>
            let _ = YJson.fromJson("[" + deep + "]", codec: codec)
        })
        for (broken in ["{\"x\":1,\"junk\":}", "{\"x\":1,\"junk\":[1,]}",
                        "{\"x\":1,\"junk\":tru}"]) {
            issue15MacroRejects("parse_error", { =>
                let _ = YJson.fromJson<Issue15MacroSkipItem>(broken)
            })
            issue15MacroRejects("parse_error", { =>
                let _ = YJson.fromJson("[" + broken + "]", codec: codec)
            })
        }
    }
}
