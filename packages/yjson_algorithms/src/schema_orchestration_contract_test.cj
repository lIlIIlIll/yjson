package yjson_algorithms

import yjson.*

import std.unittest.*
import std.unittest.testmacro.*

func yJsonSchemaConstructionRejects(schemaText: String): Unit {
    let error = @AssertThrows[JsonException](JsonSchema.parse(schemaText))
    @Expect(error.code, "json_error")
}

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

    @TestCase
    func malformedSupportedKeywordsAreRejectedDuringConstruction(): Unit {
        for (schemaText in [
            "{\"minItems\":\"two\"}", "{\"maxItems\":-1}", "{\"minItems\":1.5}",
            "{\"maxItems\":9223372036854775808}",
            "{\"minProperties\":\"one\"}", "{\"maxProperties\":-2}",
            "{\"minContains\":\"one\"}", "{\"maxContains\":-1}",
            "{\"minLength\":\"two\"}", "{\"maxLength\":-1}",
            "{\"multipleOf\":0}", "{\"multipleOf\":-2}", "{\"multipleOf\":\"two\"}",
            "{\"exclusiveMinimum\":\"1\"}", "{\"exclusiveMaximum\":null}",
            "{\"minimum\":\"1\"}", "{\"maximum\":[]}", "{\"uniqueItems\":\"true\"}",
            "{\"required\":[\"a\",1]}", "{\"required\":\"a\"}", "{\"required\":[\"a\",\"a\"]}",
            "{\"dependentRequired\":{\"a\":[1]}}", "{\"dependentRequired\":[1]}",
            "{\"dependentRequired\":{\"a\":[\"b\",\"b\"]}}",
            "{\"enum\":{}}", "{\"format\":7}", "{\"pattern\":true}",
            "{\"type\":17}", "{\"type\":[]}", "{\"type\":[\"string\",\"string\"]}",
            "{\"type\":[\"string\",\"money\"]}", "{\"type\":[\"string\",17]}"
        ]) {
            yJsonSchemaConstructionRejects(schemaText)
        }
        for (keyword in ["$schema", "$id", "$anchor", "$dynamicAnchor", "$ref", "$dynamicRef"]) {
            yJsonSchemaConstructionRejects("{\"${keyword}\":17}")
        }
    }

    @TestCase
    func malformedUnusedSchemasAreRejectedThroughEveryChildLocation(): Unit {
        for (keyword in ["additionalProperties", "unevaluatedProperties", "unevaluatedItems",
            "propertyNames", "contains", "contentSchema", "items", "then", "else", "if", "not"]) {
            yJsonSchemaConstructionRejects("{\"${keyword}\":5}")
            yJsonSchemaConstructionRejects("{\"${keyword}\":{\"minItems\":\"two\"}}")
        }
        for (keyword in ["allOf", "anyOf", "oneOf", "prefixItems"]) {
            yJsonSchemaConstructionRejects("{\"${keyword}\":5}")
            yJsonSchemaConstructionRejects("{\"${keyword}\":[]}")
            yJsonSchemaConstructionRejects("{\"${keyword}\":[true,5]}")
            yJsonSchemaConstructionRejects("{\"${keyword}\":[true,{\"multipleOf\":0}]}")
        }
        for (keyword in ["$defs", "definitions", "dependentSchemas", "patternProperties", "properties"]) {
            yJsonSchemaConstructionRejects("{\"${keyword}\":5}")
            yJsonSchemaConstructionRejects("{\"${keyword}\":{\"unused\":5}}")
            yJsonSchemaConstructionRejects("{\"${keyword}\":{\"unused\":{\"uniqueItems\":\"yes\"}}}")
        }
        yJsonSchemaConstructionRejects(
            "{\"properties\":{\"a\":{\"allOf\":[{\"properties\":{\"b\":{\"maxItems\":-3}}}]}}}")
    }

    @TestCase
    func malformedResolvedSchemasAreRejectedBeforeValidation(): Unit {
        let registry = JsonSchemaRegistry()
        registry.register("urn:example:malformed", "{\"$defs\":{\"unused\":{\"multipleOf\":0}}}")
        let config = JsonSchemaConfig(resolver: Some<UriResolver>(registry))
        let error = @AssertThrows[JsonException](
            JsonSchema.parse("{\"$ref\":\"urn:example:malformed\"}", config: config))
        @Expect(error.code, "json_error")
    }

    @TestCase
    func exactIntegerBoundsAndValidEmptyArraysKeepTheirSemantics(): Unit {
        let maximum = JsonSchema.parse("{\"minItems\":0,\"maxItems\":9223372036854775807}")
        @Expect(maximum.isValid(JsonNode.parse("[]")), true)
        let precise = JsonSchema.parse("{\"maxItems\":9007199254740993}")
        @Expect(precise.isValid(JsonNode.parse("[1]")), true)
        let exponent = JsonSchema.parse("{\"minItems\":2.0,\"maxItems\":2e0}")
        @Expect(exponent.isValid(JsonNode.parse("[1,2]")), true)
        @Expect(exponent.isValid(JsonNode.parse("[1]")), false)
        @Expect(exponent.isValid(JsonNode.parse("[1,2,3]")), false)
        @Expect(JsonSchema.parse("{\"required\":[]}").isValid(JsonNode.parse("{}")), true)
        @Expect(JsonSchema.parse("{\"enum\":[]}").isValid(JsonNode.parse("null")), false)
    }

    @TestCase
    func unknownKeywordsAndAnnotationsDoNotBecomeSubschemas(): Unit {
        let schema = JsonSchema.parse(
            "{\"type\":\"object\",\"required\":[\"name\"]," +
            "\"dependencies\":{\"name\":{\"minItems\":\"two\"}}," +
            "\"$comment\":17,\"deprecated\":\"yes\",\"readOnly\":null," +
            "\"x-shared\":{\"s\":{\"pattern\":42}},\"x-list\":[{\"uniqueItems\":\"x\"}]}")
        @Expect(schema.isValid(JsonNode.parse("{\"name\":\"value\"}")), true)
        @Expect(schema.isValid(JsonNode.parse("{}")), false)
    }

    @TestCase
    func booleanSchemasAndDeclaredDialectBehaviorArePreserved(): Unit {
        @Expect(JsonSchema.parse("true").isValid(JsonNode.parse("{\"a\":1}")), true)
        @Expect(JsonSchema.parse("false").isValid(JsonNode.parse("null")), false)
        @Expect(JsonSchema.parse(
            "{\"$schema\":\"https://json-schema.org/draft/2020-12/schema#\",\"type\":\"integer\"}")
            .isValid(JsonNode.parse("7")), true)
        let dialectError = @AssertThrows[JsonException](JsonSchema.parse(
            "{\"$schema\":\"http://json-schema.org/draft-07/schema#\"}"))
        @Expect(dialectError.code, "unsupported_schema_dialect")
        let registry = JsonSchemaRegistry()
        registry.register("urn:example:without-validation",
            "{\"$vocabulary\":{\"https://json-schema.org/draft/2020-12/vocab/core\":true}}")
        let config = JsonSchemaConfig(resolver: Some<UriResolver>(registry))
        let schema = JsonSchema.parse(
            "{\"$schema\":\"urn:example:without-validation\",\"type\":\"string\",\"minimum\":10}",
            config: config)
        @Expect(schema.isValid(JsonNode.parse("1")), true)
    }

    @TestCase
    func constructionChecksPreserveSupportedConstraintEvaluation(): Unit {
        let arrays = JsonSchema.parse("{\"minItems\":2,\"maxItems\":3,\"uniqueItems\":true}")
        @Expect(arrays.isValid(JsonNode.parse("[1,2]")), true)
        @Expect(arrays.isValid(JsonNode.parse("[1,1]")), false)
        @Expect(arrays.isValid(JsonNode.parse("[1]")), false)
        @Expect(arrays.isValid(JsonNode.parse("[1,2,3,4]")), false)
        let numbers = JsonSchema.parse("{\"multipleOf\":0.5,\"exclusiveMinimum\":0,\"exclusiveMaximum\":10}")
        @Expect(numbers.isValid(JsonNode.parse("1.5")), true)
        @Expect(numbers.isValid(JsonNode.parse("0")), false)
        @Expect(numbers.isValid(JsonNode.parse("10")), false)
        @Expect(numbers.isValid(JsonNode.parse("1.2")), false)
        let objects = JsonSchema.parse("{\"minProperties\":1,\"maxProperties\":2}")
        @Expect(objects.isValid(JsonNode.parse("{\"a\":1}")), true)
        @Expect(objects.isValid(JsonNode.parse("{}")), false)
        @Expect(objects.isValid(JsonNode.parse("{\"a\":1,\"b\":2,\"c\":3}")), false)
        let dependencies = JsonSchema.parse("{\"dependentRequired\":{\"a\":[\"b\"]}}")
        @Expect(dependencies.isValid(JsonNode.parse("{\"a\":1,\"b\":2}")), true)
        @Expect(dependencies.isValid(JsonNode.parse("{\"a\":1}")), false)
    }
}
