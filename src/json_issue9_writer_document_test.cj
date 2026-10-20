package yjson

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import std.runtime.*

private func issue9OwnedBytes(text: String): Array<Byte> {
    unsafe { text.rawData().clone() }
}

@Test
class Issue9WriterDocumentTest {
    // Run this case under an external timeout when checking the old source:
    // the zero-capacity doubling loop does not terminate on that source.
    @TestCase
    func zeroCapacityWriterMakesProgress(): Unit {
        let writer = DirectBufferWriterTarget(capacity: 0)
        writer.writeByte(b'a')
        writer.writeText("bc")
        @Expect(writer.buildString(), "abc")
        @Expect(writer.bytesWritten(), 3)
    }

    @TestCase
    func negativeWriterCapacityIsRejected(): Unit {
        @AssertThrows[IllegalArgumentException](DirectBufferWriterTarget(capacity: -1))
    }

    @TestCase
    func oneAndDefaultCapacityGrowAcrossBoundaries(): Unit {
        for (capacity in [1, 128]) {
            let writer = DirectBufferWriterTarget(capacity: capacity)
            for (_ in 0..257) { writer.writeByte(b'x') }
            let bytes = writer.buildBytes()
            @Expect(bytes.size, 257)
            for (byte in bytes) { @Expect(byte, b'x') }
            writer.reset()
            writer.writeText("reset")
            @Expect(writer.buildString(), "reset")
        }
        let defaultWriter = DirectBufferWriterTarget()
        defaultWriter.writeText("default")
        @Expect(defaultWriter.buildString(), "default")
    }

    @TestCase
    func writerRejectsRequiredSizeOverflowBeforeAllocation(): Unit {
        let writer = DirectBufferWriterTarget(capacity: 1)
        writer.writeByte(b'x')
        let error = @AssertThrows[JsonException](writer.reserveCapacity(Int64.Max))
        @Expect(error.code, "output_too_large")
        @Expect(writer.buildString(), "x")
    }

    @TestCase
    func writerRejectsScaledSizeOverflowBeforeAllocation(): Unit {
        let writer = DirectBufferWriterTarget(capacity: 1)
        let error = @AssertThrows[JsonException](writer.writeNewlineAndIndent("\n", "  ", Int64.Max))
        @Expect(error.code, "output_too_large")
        @Expect(writer.bytesWritten(), 0)
    }

    @TestCase
    func bufferGrowthArithmeticTerminatesAtInt64Boundary(): Unit {
        @Expect(jsonDirectBufferGrowthCapacity(0, 1), 1)
        @Expect(jsonDirectBufferGrowthCapacity(1, 2), 2)
        @Expect(jsonDirectBufferGrowthCapacity(128, 129), 256)
        @Expect(jsonDirectBufferGrowthCapacity(128, 256), 256)
        @Expect(jsonDirectBufferGrowthCapacity(128, 257), 512)
        @Expect(jsonDirectBufferGrowthCapacity(Int64.Max / 2, Int64.Max - 1), Int64.Max - 1)
        @Expect(jsonDirectBufferGrowthCapacity(Int64.Max / 2 + 1, Int64.Max), Int64.Max)
        @Expect(jsonDirectBufferGrowthCapacity(Int64.Max, Int64.Max), Int64.Max)
    }

    @TestCase
    func negativeSizeHintsAndDepthFailBeforeWriting(): Unit {
        let writer = DirectBufferWriterTarget(capacity: 0)
        @AssertThrows[IllegalArgumentException](writer.writeTextStringArrayListNoEscape(
            "", ArrayList<String>(), -1))
        @AssertThrows[IllegalArgumentException](writer.writeNewlineAndIndent("\n", "  ", -1))
        @AssertThrows[IllegalArgumentException](jsonDirectBufferGrowthCapacity(-1, 1))
        @AssertThrows[IllegalArgumentException](jsonDirectBufferGrowthCapacity(1, -1))
        @Expect(writer.bytesWritten(), 0)

        // A zero nesting level emits only the newline, including when the
        // indent is nonempty. The checked multiplication must accept zero.
        writer.writeNewlineAndIndent("\n", "  ", 0)
        @Expect(writer.buildString(), "\n")
    }

    @TestCase
    func combinedStringArrayReservationRejectsOverflowBeforeWriting(): Unit {
        let writer = DirectBufferWriterTarget(capacity: 1)
        let values = ArrayList<String>()
        values.add("x")
        @Expect(@AssertThrows[JsonException](writer.writeTextStringArrayListNoEscape(
            "", values, Int64.Max)).code, "output_too_large")
        @Expect(writer.bytesWritten(), 0)
    }

    @TestCase
    func scalarAndArrayEntryOverloadsGrowFromOneByte(): Unit {
        let writer = DirectBufferWriterTarget(capacity: 1)
        writer.writeByte(b'{')
        writer.writeStringLiteralNoEscapeName(issue9OwnedBytes("nameBytes"))
        writer.writeInt64Text(3)
        var first = false
        first = writer.writeObjectEntryNameInt64NoEscape(first, issue9OwnedBytes("signed"), Int64.Min)
        first = writer.writeObjectEntryNameStringNoEscape(first, issue9OwnedBytes("string"), "value")
        first = writer.writeObjectEntryNameBoolNoEscape(first, "falseValue", false)
        first = writer.writeObjectEntryNameBoolNoEscape(first, issue9OwnedBytes("trueValue"), true)
        first = writer.writeObjectEntryNameUInt64NoEscape(first, issue9OwnedBytes("unsigned"), UInt64.Max)
        first = writer.writeObjectEntryNameFloat64NoEscape(first, "floatStringName", 1.25)
        first = writer.writeObjectEntryNameFloat64NoEscape(first, issue9OwnedBytes("floatBytesName"), -1.25)
        let large = Array<Int64>(256, repeat: Int64.Max)
        first = writer.writeObjectEntryNameInt64ArrayNoEscape(first, "largeStringName", large)
        first = writer.writeObjectEntryNameInt64ArrayNoEscape(first, issue9OwnedBytes("largeBytesName"), large)
        first = writer.writeObjectEntryNameInt64ArrayNoEscape(first, issue9OwnedBytes("smallBytesName"),
            [Int64.Min, 0, Int64.Max])
        writer.writeByte(b'}')

        let result = JsonNode.parse(writer.buildString())
        @Expect(result["nameBytes"].asInt64(), 3)
        @Expect(result["signed"].asInt64(), Int64.Min)
        @Expect(result["string"].asString(), "value")
        @Expect(result["falseValue"].asBool(), false)
        @Expect(result["trueValue"].asBool(), true)
        @Expect(result["unsigned"].asUInt64(), UInt64.Max)
        @Expect(result["floatStringName"].asFloat64(), 1.25)
        @Expect(result["floatBytesName"].asFloat64(), -1.25)
        for (name in ["largeStringName", "largeBytesName"]) {
            @Expect(result[name].size(), large.size)
            @Expect(result[name][0].asInt64(), Int64.Max)
            @Expect(result[name][large.size - 1].asInt64(), Int64.Max)
        }
        @Expect(result["smallBytesName"].size(), 3)
        @Expect(result["smallBytesName"][0].asInt64(), Int64.Min)
        @Expect(result["smallBytesName"][2].asInt64(), Int64.Max)
    }

    @TestCase
    func mapEntryOverloadsReserveDetachedValidOutput(): Unit {
        let scalarValues = HashMap<String, Int64>()
        scalarValues.add("low", Int64.Min)
        scalarValues.add("high", Int64.Max)
        let nestedValues = HashMap<String, Array<Int64>>()
        nestedValues.add("small", [Int64.Min, 0, Int64.Max])
        nestedValues.add("large", Array<Int64>(256, repeat: Int64.Max))
        nestedValues.add("empty", [])
        let writer = DirectBufferWriterTarget(capacity: 0)
        writer.writeByte(b'{')
        var first = true
        first = writer.writeObjectEntryNameInt64MapKnownAsciiKeys(first, "scalarStringName", scalarValues)
        first = writer.writeObjectEntryNameInt64MapKnownAsciiKeys(first,
            issue9OwnedBytes("scalarBytesName"), scalarValues)
        first = writer.writeObjectEntryNameInt64ArrayMapNoEscape(first, "generalNested", nestedValues)
        first = writer.writeObjectEntryNameInt64ArrayMapKnownAsciiKeys(first, "nestedStringName", nestedValues)
        first = writer.writeObjectEntryNameInt64ArrayMapKnownAsciiKeys(first,
            issue9OwnedBytes("nestedBytesName"), nestedValues)
        writer.writeByte(b'}')

        let result = JsonNode.parse(writer.buildString())
        for (name in ["scalarStringName", "scalarBytesName"]) {
            @Expect(result[name].size(), 2)
            @Expect(result[name]["low"].asInt64(), Int64.Min)
            @Expect(result[name]["high"].asInt64(), Int64.Max)
        }
        for (name in ["generalNested", "nestedStringName", "nestedBytesName"]) {
            @Expect(result[name].size(), 3)
            @Expect(result[name]["small"][0].asInt64(), Int64.Min)
            @Expect(result[name]["small"][2].asInt64(), Int64.Max)
            @Expect(result[name]["large"].size(), 256)
            @Expect(result[name]["large"][255].asInt64(), Int64.Max)
            @Expect(result[name]["empty"].size(), 0)
        }
    }

    @TestCase
    func ownedDocumentInputLimitBoundaries(): Unit {
        let limit: Int64 = 8
        let options = JsonReadOptions(maxInputBytes: limit)
        for (text in ["null   ", "null    "]) {
            @Expect(YJson.parseDocument(issue9OwnedBytes(text), config: options).root().kind(), JsonKind.Null)
            @Expect(CompactJsonDocument.parseOwned(issue9OwnedBytes(text), config: options).sourceSize(), text.size)
        }
        let rejected = @AssertThrows[JsonException](YJson.parseDocument(issue9OwnedBytes("null     "), config: options))
        @Expect(rejected.code, "document_too_large")
        @Expect(rejected.location.getOrThrow().byteOffset, limit)
    }

    @TestCase
    func acceptedOwnedDocumentKeepsDetachedStringsAndKeys(): Unit {
        let bytes = issue9OwnedBytes("{\"name\":\"Alice\"}")
        let document = YJson.parseDocument(bytes, config: JsonReadOptions(maxInputBytes: bytes.size))
        for (index in 0..bytes.size) { bytes[index] = b' ' }
        @Expect(document.root().member("name").getOrThrow().asString(), "Alice")
        @Expect(document.toString(), "{\"name\":\"Alice\"}")
    }

    @TestCase
    func oversizedRejectionAvoidsInputSizedOwnedAllocation(): Unit {
        let input = Array<Byte>(8 * 1024 * 1024, repeat: b' ')
        let options = JsonReadOptions(maxInputBytes: 64)
        // Warm the facade and exception path before measuring. Heap metrics
        // cover this process; freed bytes account for any GC in the interval.
        @AssertThrows[JsonException](YJson.parseDocument([b' ', b' '],
            config: JsonReadOptions(maxInputBytes: 1)))
        let before = getAllocatedHeapSize()
        let freedBefore = getGCFreedSize()
        let gcBefore = getGCCount()
        let error = @AssertThrows[JsonException](YJson.parseDocument(input, config: options))
        let after = getAllocatedHeapSize()
        let freedAfter = getGCFreedSize()
        let gcAfter = getGCCount()
        let allocated = Int64(after) - Int64(before) + Int64(freedAfter) - Int64(freedBefore)
        println("owned-input rejection: input=${input.size}, allocated=${allocated}, gc=${gcAfter-gcBefore}")
        @Expect(error.code, "document_too_large")
        @Expect(allocated < 1024 * 1024)
    }
}
