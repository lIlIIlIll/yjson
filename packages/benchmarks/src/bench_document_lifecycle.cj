package yjson_benchmarks

import std.env.*
import std.fs.*
import std.io.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*

private var documentLifecycleSink: Option<JsonDocument> = None<JsonDocument>

private func readDocumentCorpus(name: String): Array<Byte> {
    let directory = getVariable("YJSON_CROSSLANG_CORPUS_DIR").getOrThrow({ =>
        Exception("YJSON_CROSSLANG_CORPUS_DIR is required")
    })
    var result: Option<Array<Byte>> = None<Array<Byte>>
    try (file = File("${directory}/${name}.json", OpenMode.Read)) {
        result = Some(readToEnd(file))
    }
    result.getOrThrow({ => Exception("failed to read corpus ${name}") })
}

private func assertDocumentCorpus(document: JsonDocument, expectedSize: Int64, label: String): Unit {
    let root = document.root()
    assertJson(root.size() == expectedSize, label + " record count")
    assertJson(root.element(0).getOrThrow().member("profile_id").getOrThrow().asInt64() == 10_000,
        label + " first record")
    assertJson(root.element(expectedSize - 1).getOrThrow().member("profile_id").getOrThrow().asInt64() ==
        10_000 + expectedSize - 1, label + " last record")
}

@Test
@Configure[
    warmup: Duration.millisecond * 500,
    minDuration: Duration.second,
    minBatches: 12
]
class DocumentLifecycleBenchmarks {
    private let records64kBytes = readDocumentCorpus("records-64k")
    private let records1mBytes = readDocumentCorpus("records-1m")
    private let records64kText = String.fromUtf8(records64kBytes)
    private let records1mText = String.fromUtf8(records1mBytes)

    public init() {
        assertDocumentCorpus(YJson.parseDocument(records64kText), 1_024, "records-64k string")
        assertDocumentCorpus(YJson.parseDocument(records64kBytes), 1_024, "records-64k bytes")
        assertDocumentCorpus(YJson.parseDocument(records1mText), 16_384, "records-1m string")
        assertDocumentCorpus(YJson.parseDocument(records1mBytes), 16_384, "records-1m bytes")
    }

    private func validatePureDirectDocument(caseName: String): Unit {
        let expectedSize = match (caseName) {
            case "parseStringRecords64k" | "parseBytesRecords64k" => 1_024
            case "parseStringRecords1m" | "parseBytesRecords1m" => 16_384
            case _ => throw Exception("unsupported Pure direct document case")
        }
        let document = documentLifecycleSink.getOrThrow({ =>
            Exception("Pure direct document case produced no document")
        })
        assertDocumentCorpus(document, expectedSize, "Pure direct " + caseName)
    }

    @TestCase
    func pureFixedDocument(): Unit {
        let caseName = pureDirectCaseName()
        match (caseName) {
            case "parseStringRecords64k" => runPureDirectContinuous(caseName, 500_000_000,
                { => parseStringRecords64k() }, { => validatePureDirectDocument(caseName) })
            case "parseBytesRecords64k" => runPureDirectContinuous(caseName, 500_000_000,
                { => parseBytesRecords64k() }, { => validatePureDirectDocument(caseName) })
            case "parseStringRecords1m" => runPureDirectContinuous(caseName, 500_000_000,
                { => parseStringRecords1m() }, { => validatePureDirectDocument(caseName) })
            case "parseBytesRecords1m" => runPureDirectContinuous(caseName, 500_000_000,
                { => parseBytesRecords1m() }, { => validatePureDirectDocument(caseName) })
            case _ => throw Exception("unsupported Pure direct document case")
        }
    }

    @Configure[
        batchSize: fixedBenchBatchSize("parseStringRecords64k"),
        minDuration: Duration.second * 0,
        minBatches: fixedBenchBatchCount("parseStringRecords64k")
    ]
    @Bench
    func parseStringRecords64k(): Unit {
        documentLifecycleSink = Some(YJson.parseDocument(records64kText))
    }

    @Configure[
        batchSize: fixedBenchBatchSize("parseBytesRecords64k"),
        minDuration: Duration.second * 0,
        minBatches: fixedBenchBatchCount("parseBytesRecords64k")
    ]
    @Bench
    func parseBytesRecords64k(): Unit {
        documentLifecycleSink = Some(YJson.parseDocument(records64kBytes))
    }

    @Configure[
        batchSize: fixedBenchBatchSize("parseStringRecords1m"),
        minDuration: Duration.second * 0,
        minBatches: fixedBenchBatchCount("parseStringRecords1m")
    ]
    @Bench
    func parseStringRecords1m(): Unit {
        documentLifecycleSink = Some(YJson.parseDocument(records1mText))
    }

    @Configure[
        batchSize: fixedBenchBatchSize("parseBytesRecords1m"),
        minDuration: Duration.second * 0,
        minBatches: fixedBenchBatchCount("parseBytesRecords1m")
    ]
    @Bench
    func parseBytesRecords1m(): Unit {
        documentLifecycleSink = Some(YJson.parseDocument(records1mBytes))
    }
}
