package yjson_algorithms

import yjson.*

import std.unittest.*
import std.unittest.testmacro.*

@Test
class SchemaOrchestrationContractTest {
    @TestCase
    func refAndSiblingKeywordsPreserveOrderAndTargetPaths(): Unit {
        let schema = JsonSchema.parse(
            "{\"$defs\":{\"positive\":{\"minimum\":1}}," +
            "\"$ref\":\"#/$defs/positive\",\"maximum\":-1}")
        let instance = JsonNode.parse("0")
        let result = schema.validate(instance)

        @Expect(result.valid, false)
        @Expect(schema.isValid(instance), false)
        @Assert(result.size, 2)
        @Expect(result[0].instancePath, "")
        @Expect(result[0].schemaPath, "#/$defs/positive/minimum")
        @Expect(result[0].code, "schema_validation")
        @Expect(result[1].instancePath, "")
        @Expect(result[1].schemaPath, "#/maximum")
        @Expect(result[1].code, "schema_validation")
    }

    @TestCase
    func nestedResourceScopeResolvesRelativeRefAndReportsAbsoluteTarget(): Unit {
        let schema = JsonSchema.parse(
            "{\"$id\":\"https://example.com/root.json\",\"$defs\":{\"inner\":{" +
            "\"$id\":\"inner.json\",\"$defs\":{\"positive\":{\"type\":\"integer\"," +
            "\"minimum\":1}},\"$ref\":\"#/$defs/positive\"}}," +
            "\"properties\":{\"id\":{\"$ref\":\"inner.json\"}}}")
        let invalid = schema.validate(JsonNode.parse("{\"id\":0}"))

        @Expect(invalid.valid, false)
        @Assert(invalid.size, 1)
        @Expect(invalid[0].instancePath, "/id")
        @Expect(invalid[0].schemaPath,
            "https://example.com/inner.json#/$defs/positive/minimum")
        @Expect(invalid[0].code, "schema_validation")
        @Expect(schema.validate(JsonNode.parse("{\"id\":1}")).valid, true)
    }

    @TestCase
    func malformedUnusedChildSchemasAreRejectedDuringConstruction(): Unit {
        @AssertThrows[JsonException](JsonSchema.parse(
            "{\"properties\":{\"unused\":{\"required\":[1]}}}"))
        @AssertThrows[JsonException](JsonSchema.parse(
            "{\"$defs\":{\"unused\":{\"type\":17}}}"))
        @AssertThrows[JsonException](JsonSchema.parse(
            "{\"definitions\":{\"unused\":{\"allOf\":[17]}}}"))
    }

    @TestCase
    func booleanChildSchemasRemainValidSchemas(): Unit {
        let schema = JsonSchema.parse(
            "{\"properties\":{\"items/~\":false}," +
            "\"$defs\":{\"unused\":false},\"definitions\":{\"unused\":true}}")
        @Expect(schema.isValid(JsonNode.parse("{}")), true)
        @Expect(schema.isValid(JsonNode.parse("{\"items/~\":1}")), false)
    }

    @TestCase
    func objectKeywordFamiliesPreserveViolationOrderAndEscapedPaths(): Unit {
        let schema = JsonSchema.parse(
            "{\"required\":[\"missing\"],\"properties\":{\"a/~\":{\"type\":\"integer\"}}," +
            "\"minProperties\":3,\"patternProperties\":{\"^a\":{\"minimum\":2}}," +
            "\"propertyNames\":{\"minLength\":4},\"dependentRequired\":{\"a/~\":[\"other\"]}," +
            "\"dependentSchemas\":{\"a/~\":{\"required\":[\"dep\"]}},\"additionalProperties\":false}")
        let instance = JsonNode.parse("{\"a/~\":0,\"extra\":true}")
        let result = schema.validate(instance)
        @Expect(schema.isValid(instance), false)
        @Assert(result.size, 7)
        let schemaPaths = ["#/required/0", "#/minProperties", "#/patternProperties/^a/minimum",
            "#/propertyNames/minLength", "#/dependentRequired/a~1~0",
            "#/dependentSchemas/a~1~0/required/0", "#/additionalProperties"]
        let instancePaths = ["", "", "/a~1~0", "/a~1~0", "", "", "/extra"]
        for (index in 0..result.size) {
            @Expect(result[index].schemaPath, schemaPaths[index])
            @Expect(result[index].instancePath, instancePaths[index])
            @Expect(result[index].code, "schema_validation")
        }
    }

    @TestCase
    func explicitAndPatternPropertiesAreNotAdditionalProperties(): Unit {
        let schema = JsonSchema.parse(
            "{\"properties\":{\"fixed\":true},\"patternProperties\":{\"^x\":true}," +
            "\"additionalProperties\":false}")
        @Expect(schema.isValid(JsonNode.parse("{\"fixed\":1,\"x-one\":2}")), true)
        let result = schema.validate(JsonNode.parse("{\"fixed\":1,\"x-one\":2,\"other/~\":3}"))
        @Assert(result.size, 1)
        @Expect(result[0].schemaPath, "#/additionalProperties")
        @Expect(result[0].instancePath, "/other~1~0")
    }
}
