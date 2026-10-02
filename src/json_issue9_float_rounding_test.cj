package yjson

import std.unittest.*
import std.unittest.testmacro.*

private class Issue9SemanticFloat32Codec <: JsonCodec<Float32> {
    public func write(value: Float32, writer: JsonWriter): Unit { writer.writeFloat64(Float64(value)) }
    public func read(reader: JsonReader): Float32 { JsonCodecs.float32.read(reader) }
}

private class Issue9SemanticFloat16Codec <: JsonCodec<Float16> {
    public func write(value: Float16, writer: JsonWriter): Unit { writer.writeFloat64(Float64(value)) }
    public func read(reader: JsonReader): Float16 { JsonCodecs.float16.read(reader) }
}

// Expected bits come from exact rational comparisons to IEEE-754 midpoints,
// independent of std.convert's Float16/Float32/Float64 decimal parsers.
private let issue9Float32Vectors: Array<(String, UInt32)> = [
    ("1.0000000596046447", 0x3f800000u32),
    ("1.000000059604644775390625", 0x3f800000u32),
    ("1.0000000596046448", 0x3f800001u32),
    ("1.0000001788139343", 0x3f800001u32),
    ("1.000000178813934326171875", 0x3f800002u32),
    ("1.0000001788139344", 0x3f800002u32),
    ("2048.0003662109375", 0x45000002u32),
    ("4095.9996337890625", 0x457ffffeu32),
    ("7.0064923216240853e-46", 0u32),
    ("7.00649232162408535461864791644958065640130970938257885878534141944895541342930300743319094181060791015625e-46", 0u32),
    ("7.0064923216240854e-46", 1u32),
    ("2.101947696487225606385594374934874196920392912814773657635602425834686624028790902229957282543182373046875e-45", 2u32),
    ("1.1754942807573642917278829910357665133228589927589904276829631184250030649651730385585324256680905818939208984375e-38", 0x00800000u32),
    ("340282356779733661637539395458142568447", 0x7f7fffffu32),
    ("340282356779733661637539395458142568448", 0x7f800000u32),
    ("340282356779733661637539395458142568449", 0x7f800000u32),
    ("0", 0u32),
    ("1e-100000000000000000000000000000000", 0u32),
    ("1e100000000000000000000000000000000", 0x7f800000u32)
]

private let issue9Float16Vectors: Array<(String, UInt16)> = [
    ("1.0004882812499999", 0x3c00u16),
    ("1.00048828125", 0x3c00u16),
    ("1.0004882812500001", 0x3c01u16),
    ("1.0014648437499999", 0x3c01u16),
    ("1.00146484375", 0x3c02u16),
    ("1.0014648437500001", 0x3c02u16),
    ("2.98023223876953124e-8", 0u16),
    ("2.98023223876953125e-8", 0u16),
    ("2.98023223876953126e-8", 1u16),
    ("8.94069671630859375e-8", 2u16),
    ("6.10053539276123046874e-5", 0x03ffu16),
    ("6.10053539276123046875e-5", 0x0400u16),
    ("6.10053539276123046876e-5", 0x0400u16),
    ("65519.99999999999999999999", 0x7bffu16),
    ("65520", 0x7c00u16),
    ("65520.00000000000000000001", 0x7c00u16),
    ("0", 0u16),
    ("1e-100000000000000000000000000000000", 0u16),
    ("1e100000000000000000000000000000000", 0x7c00u16)
]

@Test
class JsonIssue9FloatRoundingTest {
    @TestCase
    func negativeZeroMaterializationKeepsUnsignedConversion(): Unit {
        let zero = JsonNode.number("-0")
        @Expect(zero.asUInt64(), 0u64)
        @Expect(zero.asInt64(), 0)
        @Expect(zero.asNumberText(), "-0")
        @Expect(zero.asFloat64().toBits(), 0x8000000000000000u64)
        @Expect(JsonNode.number("0").asUInt64(), 0u64)
        @Expect(JsonNode.number("18446744073709551615").asUInt64(), UInt64.Max)
        for (literal in ["-1", "-0.0", "-0e0"]) {
            let error = @AssertThrows[JsonException](JsonNode.number(literal).asUInt64())
            @Expect(error.code, "number_out_of_range")
        }
        for (literal in ["-00", "x"]) {
            @AssertThrows[IllegalArgumentException](JsonNode.number(literal))
        }
        let error = @AssertThrows[JsonException](YJson.fromJson("-0", codec: JsonCodecs.uint64))
        @Expect(error.code, "parse_error")
    }

    @TestCase
    func exactRoundingSurvivesArbitrarilyWrongApproximateCandidates(): Unit {
        // The SDK-derived prefix is only a hint. Exercise both bounded-search
        // directions with deliberately distant candidates, independently of
        // whichever approximation the current SDK happens to return.
        for ((literal, expected) in issue9Float32Vectors) {
            for (candidate in [0u64, 1u64, 0x3f800000u64, 0x3f800002u64,
                0x7f7fffffu64, 0x7f800000u64]) {
                @Expect(jsonTargetFloatCorrectBits(JsonTargetFloatDecimal(literal),
                    candidate, 0x7f800000u64, 23, 127), UInt64(expected))
            }
        }
        for ((literal, expected) in issue9Float16Vectors) {
            for (candidate in [0u64, 1u64, 0x3c00u64, 0x3c02u64,
                0x7bffu64, 0x7c00u64]) {
                @Expect(jsonTargetFloatCorrectBits(JsonTargetFloatDecimal(literal),
                    candidate, 0x7c00u64, 10, 15), UInt64(expected))
            }
        }
    }

    @TestCase
    func malformedBackendTapeNumberCannotBypassLiteralGrammar(): Unit {
        for (literal in ["x", "", "1e", "NaN", "+1", "01", "."]) {
            let raw = unsafe { literal.rawData() }
            let tape = Array<Byte>(9 + raw.size, { _ => 0u8 })
            tape[0] = b'Y'; tape[1] = b'J'; tape[2] = b'T'; tape[3] = b'1'
            tape[4] = 3u8
            tape[5] = UInt8(raw.size)
            raw.copyTo(tape, 0, 9, raw.size)
            @Expect(@AssertThrows[JsonException](JsonCodecs.float32.read(
                BackendTapeReaderV1(tape))).code, "invalid_number")
            @Expect(@AssertThrows[JsonException](JsonCodecs.float16.read(
                BackendTapeReaderV1(tape))).code, "invalid_number")
        }
    }

    @TestCase
    func float32BuiltinAndHandwrittenCodecsRoundToTargetBits(): Unit {
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(maxInputBytes: 256, maxBufferedValueBytes: 256, maxDepth: 2)]) {
            for ((literal, positiveBits) in issue9Float32Vectors) {
                for (negative in [false, true]) {
                    let text = if (negative) { "-${literal}" } else { literal }
                    let expected = positiveBits | if (negative) { 0x80000000u32 } else { 0u32 }
                    for (codec in [JsonCodecs.float32, Issue9SemanticFloat32Codec()]) {
                        @Expect(YJson.fromJson(text, codec: codec, options: options).toBits(), expected)
                        @Expect(YJson.fromJson(unsafe { text.rawData().clone() }, codec: codec,
                            options: options).toBits(), expected)
                        @Expect(YJson.fromJson(FixedChunkInputStream(text, 1), codec: codec,
                            options: options).toBits(), expected)
                    }
                }
            }
        }
    }

    @TestCase
    func float16BuiltinAndHandwrittenCodecsRoundToTargetBits(): Unit {
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(maxInputBytes: 256, maxBufferedValueBytes: 256, maxDepth: 2)]) {
            for ((literal, positiveBits) in issue9Float16Vectors) {
                for (negative in [false, true]) {
                    let text = if (negative) { "-${literal}" } else { literal }
                    let expected = positiveBits | if (negative) { 0x8000u16 } else { 0u16 }
                    for (codec in [JsonCodecs.float16, Issue9SemanticFloat16Codec()]) {
                        @Expect(YJson.fromJson(text, codec: codec, options: options).toBits(), expected)
                        @Expect(YJson.fromJson(unsafe { text.rawData().clone() }, codec: codec,
                            options: options).toBits(), expected)
                        @Expect(YJson.fromJson(FixedChunkInputStream(text, 1), codec: codec,
                            options: options).toBits(), expected)
                    }
                }
            }
        }
    }

    @TestCase
    func longDecimalExponentCancellationAndEquivalentSpelling(): Unit {
        let text = StringBuilder("0.")
        for (_ in 0..10000) { text.append("0") }
        text.append("10000000596046448e10001")
        @Expect(YJson.fromJson<Float32>(text.toString()).toBits(), 0x3f800001u32)
        @Expect(YJson.fromJson<Float32>("10000000596046448e-16").toBits(), 0x3f800001u32)
        @Expect(YJson.fromJson<Float16>("10004882812500001e-16").toBits(), 0x3c01u16)
        @Expect(YJson.fromJson<Float32>("-0.0e99999999999999999999999").toBits(), 0x80000000u32)
        @Expect(YJson.fromJson<Float16>("-0.0e99999999999999999999999").toBits(), 0x8000u16)
    }
}
