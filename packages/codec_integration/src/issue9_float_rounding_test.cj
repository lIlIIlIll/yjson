package yjson_codec_integration

import std.io.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class Issue9GeneratedTargetFloatRecord {
    public let half: Float16
    public let single: Float32
    public init(half: Float16, single: Float32) {
        this.half = half
        this.single = single
    }
}

private class Issue9FloatChunkStream <: InputStream {
    private let bytes: Array<Byte>
    private var offset: Int64 = 0
    public init(text: String) { bytes = unsafe { text.rawData().clone() } }
    public func read(buffer: Array<Byte>): Int64 {
        if (offset == bytes.size || buffer.isEmpty()) { return 0 }
        buffer[0] = bytes[offset]
        offset++
        1
    }
}

private func issue9AssertGeneratedFloatBits(text: String, half: UInt16, single: UInt32): Unit {
    for (options in [JsonReadOptions.defaults, JsonReadOptions(),
        JsonReadOptions(maxInputBytes: 256, maxBufferedValueBytes: 256, maxDepth: 3),
        JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)]) {
        let stringValue = YJson.fromJson<Issue9GeneratedTargetFloatRecord>(text, options: options)
        let bytesValue = YJson.fromJson<Issue9GeneratedTargetFloatRecord>(
            unsafe { text.rawData().clone() }, options: options)
        let streamValue = YJson.fromJson<Issue9GeneratedTargetFloatRecord>(
            Issue9FloatChunkStream(text), options: options)
        for (value in [stringValue, bytesValue, streamValue]) {
            @Expect(value.half.toBits(), half)
            @Expect(value.single.toBits(), single)
        }
    }
}

@Test
class Issue9ExternalFloatRoundingTest {
    @TestCase
    func generatedScalarFastSemanticAndCursorReadsUseTargetPrecision(): Unit {
        issue9AssertGeneratedFloatBits("{\"half\":1.0004882812500001,\"single\":1.0000000596046448}",
            0x3c01u16, 0x3f800001u32)
        issue9AssertGeneratedFloatBits("{\"single\":-1.0000000596046448,\"half\":-1.0004882812500001}",
            0xbc01u16, 0xbf800001u32)
        issue9AssertGeneratedFloatBits("{\"half\":2.98023223876953126e-8,\"single\":7.0064923216240854e-46}",
            1u16, 1u32)
        issue9AssertGeneratedFloatBits("{\"single\":340282356779733661637539395458142568447,\"half\":65519.99999999999999999999}",
            0x7bffu16, 0x7f7fffffu32)
        issue9AssertGeneratedFloatBits("{\"half\":-0.0,\"single\":-0}", 0x8000u16, 0x80000000u32)
    }
}
