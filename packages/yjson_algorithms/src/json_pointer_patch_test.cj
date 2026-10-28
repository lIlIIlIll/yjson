package yjson_algorithms

import yjson.*

import std.unittest.*
import std.unittest.testmacro.*

@Test
class YJsonPointerPatchTest {
    @TestCase
    func pointerRfcEscapesAndRoot(): Unit {
        let root = JsonNode.parse("{\"\":0,\"a/b\":1,\"m~n\":2,\"items\":[\"x\",\"y\"]}")
        @Expect(jsonNodesEquivalent(JsonPointer.parse("").evaluate(root), root))
        @Expect(JsonPointer.parse("/").evaluate(root).asInt64(), 0)
        @Expect(JsonPointer.parse("/a~1b").evaluate(root).asInt64(), 1)
        @Expect(JsonPointer.parse("/m~0n").evaluate(root).asInt64(), 2)
        @Expect(JsonPointer.parse("/items/1").evaluate(root).asString(), "y")
        @Expect(JsonPointer.parseUriFragment("#/a~1b").evaluate(root).asInt64(), 1)
        @Expect(@AssertThrows[JsonException](JsonPointer.parse("a")).code,
            "invalid_json_pointer")
        @Expect(@AssertThrows[JsonException](JsonPointer.parse("/~2")).code,
            "invalid_json_pointer")
    }

    @TestCase
    func patchSupportsAllRfcOperations(): Unit {
        let patch = JsonPatch.parse("""
        [
          {"op":"add","path":"/items/1","value":"b"},
          {"op":"replace","path":"/name","value":"Bob"},
          {"op":"copy","from":"/items/0","path":"/copy"},
          {"op":"move","from":"/items/2","path":"/moved"},
          {"op":"test","path":"/copy","value":"a"},
          {"op":"remove","path":"/drop"}
        ]
        """)
        let original = JsonNode.parse("{\"name\":\"Alice\",\"items\":[\"a\",\"c\"],\"drop\":true}")
        let result = patch.apply(original)
        @Expect(result.equivalentTo(JsonNode.parse(
            "{\"copy\":\"a\",\"moved\":\"c\",\"name\":\"Bob\",\"items\":[\"a\",\"b\"]}"
        )))
        @Expect(original["name"].asString(), "Alice")
    }

    @TestCase
    func patchFailureIsAtomicForCopyAndInPlace(): Unit {
        let patch = JsonPatch.parse("""
        [{"op":"replace","path":"/a","value":2},{"op":"remove","path":"/missing"}]
        """)
        let target = JsonNode.parse("{\"a\":1}")
        @Expect(@AssertThrows[JsonException](patch.applyInPlace(target)).code, "json_patch_path")
        @Expect(target["a"].asInt64(), 1)
    }

    @TestCase
    func mergePatchFollowsRfcObjectAndRootRules(): Unit {
        let target = JsonNode.parse("{\"a\":\"b\",\"c\":{\"d\":\"e\",\"f\":\"g\"}}")
        let patch = JsonNode.parse("{\"a\":\"z\",\"c\":{\"f\":null}}");
        let result = JsonMergePatch.apply(target, patch)
        @Expect((result).toJson(), "{\"a\":\"z\",\"c\":{\"d\":\"e\"}}")
        @Expect(JsonMergePatch.apply(target, JsonNode.string("root")).asString(), "root")
    }

    @TestCase
    func exactNumericEqualityIsUsedByTest(): Unit {
        let patch = JsonPatch.parse("[{\"op\":\"test\",\"path\":\"/n\",\"value\":1.00}]")
        let result = patch.apply(JsonNode.parse("{\"n\":1e0}"))
        @Expect(result["n"].asNumberText(), "1e0")
    }
}


@Test
class JsonPointerUriFragmentTest {
    @TestCase
    func fragmentEncodesWhitespaceAsPercentOctets(): Unit {
        let pointer = JsonPointer.parse("/a b\t\n\r")
        let expected = "#/a%20b%09%0A%0D"
        @Expect(pointer.toUriFragment(), expected)
        @Expect(JsonPointer.parseUriFragment(expected).toString(), pointer.toString())
    }

    @TestCase
    func fragmentEncodesEachUtf8Byte(): Unit {
        let pointer = JsonPointer.parse("/中文/🙂")
        let expected = "#/%E4%B8%AD%E6%96%87/%F0%9F%99%82"
        @Expect(pointer.toUriFragment(), expected)
        @Expect(JsonPointer.parseUriFragment(expected).toString(), pointer.toString())
    }

    @TestCase
    func fragmentPreservesRootUnreservedAndPointerEscapes(): Unit {
        @Expect(JsonPointer.parse("").toUriFragment(), "#")
        let source = "/AZaz09-._~0~1/a~1b/m~0n"
        let expected = "#" + source
        @Expect(JsonPointer.parse(source).toUriFragment(), expected)
        @Expect(JsonPointer.parseUriFragment(expected).toString(), source)
    }

    @TestCase
    func fragmentUsesOneUppercaseHexCharacterPerNibble(): Unit {
        let source = "/\u{0000}\u{0001}\u{0002}\u{0003}\u{0004}\u{0005}\u{0006}\u{0007}" +
            "\u{0008}\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{000E}\u{000F}"
        let expected = "#/%00%01%02%03%04%05%06%07%08%09%0A%0B%0C%0D%0E%0F"
        @Expect(JsonPointer.parse(source).toUriFragment(), expected)
        @Expect(JsonPointer.parseUriFragment(expected).toString(), source)
    }
}
