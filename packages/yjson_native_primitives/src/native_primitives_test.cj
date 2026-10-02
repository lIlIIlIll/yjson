package yjson_native_primitives

import std.convert.Parsable
import std.unittest.*
import std.unittest.testmacro.*
import yjson.*

private func primitiveBytes(text: String): Array<Byte> {
    unsafe { text.rawData() }
}

@Test
class NativePrimitivesIntegrationTest {
    @BeforeAll
    func installNativeScanner(): Unit {
        initializeYJsonNativePrimitivesV1()
    }

    @TestCase
    func linkedScannerIsInstalledAndDecodesLongEscapedString(): Unit {
        @Expect((nativeScannerCapabilitiesForTesting() & 1u32) != 0u32)
        let builder = StringBuilder()
        builder.append("\"")
        for (_ in 0..32) {
            builder.append("prefix\\n\\t\\\"\\\\")
        }
        builder.append("\\u4ed3\\u9889\\uD834\\uDD1E\"")
        let expected = StringBuilder()
        for (_ in 0..32) {
            expected.append("prefix\n\t\"\\")
        }
        expected.append("仓颉\u{1D11E}")
        @Expect(YJson.fromJson(primitiveBytes(builder.toString()), codec: JsonCodecs.string),
            expected.toString())
    }

    private func assertNativeFloatMatchesStdlib(text: String): Unit {
        let reader = GeneratedSupportV1.newFastReader(text)
        let actual = jsonFastReadFloat64(reader)
        reader.expectEnd()
        @Expect(actual.toBits(), Float64.parse(text).toBits())
    }

    @TestCase
    func nativeFloatParserKeepsStdlibBitsAndLongTokenFallback(): Unit {
        for (text in ["0", "-0.0", "1.5", "-12.75", "1e308", "1e309",
            "1e-323", "1e-324", "-1e309", "-1e-324",
            "0.12345678901234567", "3.141592653589793"]) {
            assertNativeFloatMatchesStdlib(text)
        }
        var longToken = "0."
        for (_ in 0..300) { longToken += "1" }
        assertNativeFloatMatchesStdlib(longToken)
    }

    @TestCase
    func nativeEnabledFloat16And32UseExactTargetRounding(): Unit {
        for (options in [JsonReadOptions.defaults, JsonReadOptions()]) {
            for ((text, bits) in [("1.0000000596046448", 0x3f800001u32),
                ("-1.0000000596046448", 0xbf800001u32),
                ("7.0064923216240854e-46", 1u32),
                ("340282356779733661637539395458142568447", 0x7f7fffffu32),
                ("-0", 0x80000000u32)]) {
                @Expect(YJson.fromJson<Float32>(text, options: options).toBits(), bits)
                @Expect(YJson.fromJson<Float32>(primitiveBytes(text), options: options).toBits(), bits)
                @Expect(YJson.fromJson<Float32>(YJsonByteArrayInputStream(text), options: options).toBits(), bits)
                let reader = GeneratedSupportV1.newFastReader(text)
                @Expect(jsonFastReadFloat32(reader).toBits(), bits)
                reader.expectEnd()
            }
            for ((text, bits) in [("1.0004882812500001", 0x3c01u16),
                ("-1.0004882812500001", 0xbc01u16),
                ("2.98023223876953126e-8", 1u16),
                ("65519.99999999999999999999", 0x7bffu16),
                ("-0", 0x8000u16)]) {
                @Expect(YJson.fromJson<Float16>(text, options: options).toBits(), bits)
                @Expect(YJson.fromJson<Float16>(primitiveBytes(text), options: options).toBits(), bits)
                @Expect(YJson.fromJson<Float16>(YJsonByteArrayInputStream(text), options: options).toBits(), bits)
                let reader = GeneratedSupportV1.newFastReader(text)
                @Expect(jsonFastReadFloat16(reader).toBits(), bits)
                reader.expectEnd()
            }
        }
    }
}
