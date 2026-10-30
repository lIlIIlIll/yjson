package yjson_schema_formats

import yjson_algorithms.*

import std.unittest.*
import std.unittest.testmacro.*
import yjson.*

private func formatAccepts(name: String, value: String): Bool {
    let formats = JsonSchemaFormatRegistry.withCoreFormats()
    formats.install(StandardInternationalFormats())
    let config = JsonSchemaConfig(formatMode: JsonSchemaFormatMode.Assertion, formats: formats)
    JsonSchema.parse("{\"format\":\"${name}\"}", config: config)
        .validator().isValid(JsonNode.string(value))
}

@Test
class InternationalSchemaFormatsTest {
    @TestCase
    func idnaUsesContextAndBidiRules(): Unit {
        @Expect(formatAccepts("idn-hostname", "실례.테스트"))
        @Expect(formatAccepts("hostname", "xn--9n2bp8q.xn--9t4b11yi5a"))
        @Expect(!formatAccepts("idn-hostname", "a·l"))
        @Expect(!formatAccepts("idn-hostname", "0a.א"))
    }

    @TestCase
    func uriIriAndTemplateAreRegistered(): Unit {
        @Expect(formatAccepts("uri", "https://example.com/a?b=c#d"))
        @Expect(formatAccepts("iri", "https://例え.テスト/路径"))
        @Expect(formatAccepts("uri-template", "https://example.com{/segments*}{?query}"))
        @Expect(!formatAccepts("uri", "https://[@example.org/test.txt"))
    }

    @TestCase
    func uriTemplateRejectsNonAsciiVariablesWithoutThrowing(): Unit {
        // Reject non-ASCII variable syntax without slicing a partial UTF-8 character.
        for (invalid in ["{中}", "{+中}", "{?q,中}"]) {
            @Expect(formatAccepts("uri-template", invalid), false)
        }
    }

    @TestCase
    func uriTemplateKeepsUnicodeLiteralBytesAndAsciiControls(): Unit {
        // Literal UTF-8 text must survive the template scan, so an IRI host
        // plus an ASCII variable name stays valid.
        @Expect(formatAccepts("uri-template", "https://例え.テスト/{name}"))
        @Expect(formatAccepts("uri-template", "https://例え.テスト/路径/{name}"))
        @Expect(formatAccepts("uri-template", "{name}"))
        @Expect(formatAccepts("uri-template", "https://example.test/a?b={x}#{y}"))
        for (expression in ["{+path}", "{#frag}", "{.ext}", "{/seg*}", "{;p}", "{?q,lang}",
            "{&x}", "{name:3}", "{a,b}"]) {
            @Expect(formatAccepts("uri-template", "https://example.test/${expression}"), true)
        }
        // ASCII control characters stay rejected in literals and expressions.
        @Expect(!formatAccepts("uri-template", "https://example.test/a\u{0001}{x}"))
        @Expect(!formatAccepts("uri-template", "https://example.test/a\t{x}"))
        @Expect(!formatAccepts("uri-template", "https://example.test/{na\u{0001}me}"))
        // Structural template errors still fail.
        @Expect(!formatAccepts("uri-template", "https://example.test/{unclosed"))
        @Expect(!formatAccepts("uri-template", "https://example.test/}{x}"))
        @Expect(!formatAccepts("uri-template", "https://example.test/{}"))
        @Expect(!formatAccepts("uri-template", "https://example.test/{na me}"))
        @Expect(!formatAccepts("uri-template", "https://example.test/{name:}"))
        @Expect(!formatAccepts("uri-template", "https://example.test/{name:12345}"))
    }
}
