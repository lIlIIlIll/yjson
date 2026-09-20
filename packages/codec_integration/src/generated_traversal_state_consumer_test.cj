package yjson_codec_integration

import std.unittest.*
import std.unittest.testmacro.*
import yjson.*
import yjson_macros.*

@JsonCodec
class TraversalStateLeafConsumer {
    public let values: Array<Int64>

    public init(values: Array<Int64>) {
        this.values = values
    }
}

@JsonCodec
class TraversalStateEnvelopeConsumer {
    @JsonName["items/~"]
    public let items: Array<TraversalStateLeafConsumer>

    public init(items: Array<TraversalStateLeafConsumer>) {
        this.items = items
    }
}

@Test
class GeneratedTraversalStateConsumerTest {
    @TestCase
    func escapedFieldAndNestedValueRoundTrip(): Unit {
        let value = TraversalStateEnvelopeConsumer([
            TraversalStateLeafConsumer([7])
        ])

        let encoded = YJson.toJson(value)
        @Assert(encoded, "{\"items/~\":[{\"values\":[7]}]}")
        let decoded = YJson.fromJson<TraversalStateEnvelopeConsumer>(encoded)
        @Assert(decoded.items.size, 1)
        @Assert(decoded.items[0].values.size, 1)
        @Expect(decoded.items[0].values[0], 7)
    }

    @TestCase
    func depthErrorsPreserveCodesAndSemanticWritePath(): Unit {
        let value = TraversalStateEnvelopeConsumer([
            TraversalStateLeafConsumer([7])
        ])
        let writeError = @AssertThrows[JsonException](
            YJson.toJson(value, options: JsonWriteOptions(maxDepth: 2)))
        @Expect(writeError.code, "max_depth")

        let semanticWriteError = @AssertThrows[JsonException](
            YJson.toJson(value,
                options: JsonWriteOptions(indent: "  ", maxDepth: 2)))
        @Expect(semanticWriteError.code, "max_depth")
        @Expect(semanticWriteError.path, "/items~1~0/0")

        let readError = @AssertThrows[JsonException](
            YJson.fromJson<TraversalStateEnvelopeConsumer>(
                "{\"items/~\":[{\"values\":[7]}]}",
                options: JsonReadOptions(maxDepth: 2)))
        @Expect(readError.code, "max_depth")
    }

    @TestCase
    func duplicateEscapedFieldReportsItsPath(): Unit {
        let error = @AssertThrows[JsonException](
            YJson.fromJson<TraversalStateEnvelopeConsumer>(
                "{\"items/~\":[],\"items/~\":[]}"))
        @Expect(error.code, "duplicate_key")
        @Expect(error.path, "/items~1~0")
    }

    @TestCase
    func unknownNestedValueConsumesRemainingDepth(): Unit {
        let text = "{\"items/~\":[],\"ignored\":[[]]}"
        let error = @AssertThrows[JsonException](
            YJson.fromJson<TraversalStateEnvelopeConsumer>(text,
                options: JsonReadOptions(maxDepth: 2)))
        @Expect(error.code, "max_depth")

        let decoded = YJson.fromJson<TraversalStateEnvelopeConsumer>(text,
            options: JsonReadOptions(maxDepth: 3))
        @Expect(decoded.items.size, 0)
    }
}
