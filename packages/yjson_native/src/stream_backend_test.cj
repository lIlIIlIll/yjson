package yjson_native

import std.collection.*
import std.io.*
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*

private class NativeBackendTestOutput <: OutputStream {
    private let bytes = ArrayList<Byte>()
    public func write(value: Array<Byte>): Unit { bytes.add(all: value) }
    public func flush(): Unit {}
    func toBytes(): Array<Byte> { bytes.toArray() }
    func toString(): String { String.fromUtf8(toBytes()) }
}

private class NativeTargetFloat16Codec <: JsonCodec<Float16> {
    public func write(value: Float16, writer: JsonWriter): Unit { writer.writeFloat64(Float64(value)) }
    public func read(reader: JsonReader): Float16 { JsonCodecs.float16.read(reader) }
}

private class NativeTargetFloat32Codec <: JsonCodec<Float32> {
    public func write(value: Float32, writer: JsonWriter): Unit { writer.writeFloat64(Float64(value)) }
    public func read(reader: JsonReader): Float32 { JsonCodecs.float32.read(reader) }
}

private class NativeTargetFloatByteStream <: InputStream {
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

@Test
class NativeStreamBackendTest {
    @TestCase
    func float16And32ReadsPreserveNegativeZeroAndExactRounding(): Unit {
        let json = NativeBackends.customNative
        @Expect(json.fromJson("-0", codec: JsonCodecs.int64), 0)
        for (text in ["-0", "{\"zero\":-0}"]) {
            try (document = json.parseDocument(text)) {
                let zero = if (text == "-0") { document.root() }
                    else { document.root().member("zero").getOrThrow() }
                @Expect(zero.asNumberText(), "-0")
                @Expect(zero.asInt64(), 0)
                @Expect(zero.asUInt64(), 0u64)
                @Expect(zero.materialize().asUInt64(), 0u64)
                @Expect(zero.asFloat64().toBits(), 0x8000000000000000u64)
            }
        }
        for (options in [JsonReadOptions.defaults, JsonReadOptions(),
            JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins)]) {
            for ((text, bits) in [("1.0000000596046448", 0x3f800001u32),
                ("-1.0000000596046448", 0xbf800001u32),
                ("2048.0003662109375", 0x45000002u32),
                ("7.0064923216240854e-46", 1u32),
                ("340282356779733661637539395458142568447", 0x7f7fffffu32),
                ("340282356779733661637539395458142568448", 0x7f800000u32),
                ("-0", 0x80000000u32), ("-0.0", 0x80000000u32),
                ("-0e0", 0x80000000u32), ("-1e-1000", 0x80000000u32)]) {
                for (codec in [JsonCodecs.float32, NativeTargetFloat32Codec()]) {
                    @Expect(json.fromJson(text, codec: codec, options: options).toBits(), bits)
                    @Expect(json.fromJson(unsafe { text.rawData().clone() }, codec: codec,
                        options: options).toBits(), bits)
                    @Expect(json.fromJson(NativeTargetFloatByteStream(text), codec: codec,
                        options: options).toBits(), bits)
                }
            }
            for ((text, bits) in [("1.0004882812500001", 0x3c01u16),
                ("-1.0004882812500001", 0xbc01u16),
                ("2.98023223876953126e-8", 1u16),
                ("65519.99999999999999999999", 0x7bffu16), ("65520", 0x7c00u16),
                ("-0", 0x8000u16), ("-0.0", 0x8000u16),
                ("-0e0", 0x8000u16), ("-1e-1000", 0x8000u16)]) {
                for (codec in [JsonCodecs.float16, NativeTargetFloat16Codec()]) {
                    @Expect(json.fromJson(text, codec: codec, options: options).toBits(), bits)
                    @Expect(json.fromJson(unsafe { text.rawData().clone() }, codec: codec,
                        options: options).toBits(), bits)
                    @Expect(json.fromJson(NativeTargetFloatByteStream(text), codec: codec,
                        options: options).toBits(), bits)
                }
            }
        }
    }

    @TestCase
    func encodeIsByteIdenticalToPureForWriteConfigs(): Unit {
        let codec = JsonCodecs.stringMap(JsonCodecs.string)
        let value = HashMap<String, String>()
        value["<key>"] = "line\n仓颉"
        let json = NativeBackends.customNative
        for (config in [JsonWriteOptions.compact, JsonWriteOptions.pretty(),
            JsonWriteOptions(indent: "  ", htmlSafe: true)]) {
            let pure = NativeBackendTestOutput()
            let native = NativeBackendTestOutput()
            YJson.writeJson(value, pure, codec: codec, options: config)
            json.writeJson(value, native, codec: codec, options: config)
            @Expect(native.toString(), pure.toString())
        }
    }

    @TestCase
    func decodeUsesTypedCodecAndEnforcesInputLimit(): Unit {
        let codec = JsonCodecs.array(JsonCodecs.int64)
        let json = NativeBackends.customNative
        let value = json.fromJson(YJsonByteArrayInputStream("[1,2,3]"), codec: codec)
        @Expect(value.size, 3)
        @Expect(value[2], 3)
        let typeError = @AssertThrows[JsonException](json.fromJson(
            YJsonByteArrayInputStream("1.25"), codec: JsonCodecs.int64))
        @Expect(typeError.code, "parse_error")
        let error = @AssertThrows[JsonException](json.fromJson(
            YJsonByteArrayInputStream("[1,2,3]"), codec: codec,
            options: JsonReadOptions(maxInputBytes: 4)))
        @Expect(error.code, "document_too_large")
    }

    @TestCase
    func outputLimitFailsBeforeNativeWrites(): Unit {
        let output = NativeBackendTestOutput()
        let error = @AssertThrows[JsonException](NativeBackends.customNative.writeJson(
            "too long", output, codec: JsonCodecs.string,
            options: JsonWriteOptions(maxOutputBytes: 4)))
        @Expect(error.code, "output_too_large")
        @Expect(output.toBytes().size, 0)
    }
}
