package yjson_benchmarks

private func fixedBenchWork(caseName: String): (Int64, Int64) {
    let (batchSize, batches) = match (caseName) {
        case "yjsonStringEncodeLargeInt64Map" => (4_096, 200)
        case "yjsonStringDecodeLargeInt64Map" => (1_024, 200)
        case "yjsonBytesDecodeLargeInt64Map" => (1_024, 200)
        case "yjsonStringEncodeDeepNestedProfiles" => (512, 200)
        case "yjsonStringDecodeDeepNestedProfiles" => (64, 200)
        case "yjsonBytesDecodeDeepNestedProfiles" => (64, 200)
        case "yjsonStringEncodePerson" => (16_384, 200)
        case "yjsonStringDecodePerson" => (2_048, 200)
        case "yjsonStringEncodeLargeProfileArray" => (1_024, 200)
        case "yjsonStringDecodeLargeProfileArray" => (256, 200)
        case "parseStringRecords64k" => (8, 200)
        case "parseBytesRecords64k" => (8, 200)
        case "parseStringRecords1m" => (1, 200)
        case "parseBytesRecords1m" => (1, 200)
        case "yjsonStringEncodeProfileBundle" => (4_096, 200)
        case "yjsonStringDecodeProfileBundle" => (1_024, 200)
        case "yjsonBytesEncodeProfileBundle" => (2_048, 200)
        case "yjsonBytesDecodeProfileBundle" => (1_024, 200)
        case "yjsonStringEncodeEscapedUnicodeString" => (16_384, 200)
        case "yjsonBytesEncodeEscapedUnicodeString" => (16_384, 200)
        case "decodePersonChunk4k" => (1, 65_536)
        case "decodeRecords64kChunk4k" => (1, 512)
        case "encodePersonMemory" => (1, 524_288)
        case "encodeRecords64kMemory" => (1, 4_096)
        case "yjsonStringEncodeAddress" => (16_384, 200)
        case "yjsonStringDecodeAddress" => (16_384, 200)
        case _ => throw IllegalArgumentException("unknown fixed benchmark case: ${caseName}")
    }
    // Bound the runner's reserved sample buffer. SDK bootstrap has a separate
    // sample limit, so this cap alone does not guarantee that statistics fit.
    let boundedBatches = if (batches > 65_536) { 65_536 } else { batches }
    (batchSize, boundedBatches)
}

func fixedBenchBatchSize(caseName: String): Int64 {
    let (batchSize, batches) = fixedBenchWork(caseName)
    println("YJSON_FIXED_WORK_V1 case=${caseName} batches=${batches} batch_size=${batchSize}")
    batchSize
}

func fixedBenchBatchCount(caseName: String): Int64 {
    let (_, batches) = fixedBenchWork(caseName)
    batches
}

func fixedBenchOperations(caseName: String): Int64 {
    let (batchSize, batches) = fixedBenchWork(caseName)
    batchSize * batches
}
