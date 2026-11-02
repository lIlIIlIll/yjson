package yjson_native

import yjson.*
import yjson_backends.*
import std.collection.*
import std.sync.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class NativeDocumentBackendTest {
    @TestCase
    func namedFacadeUsesUnifiedReadOnlyView(): Unit {
        let bytes = unsafe { "{\"id\":42,\"items\":[1,2]}".rawData() }
        try (document = NativeBackends.customNative.parseDocument(bytes)) {
            @Expect(document.metadata().name, "custom-native")
            @Expect(document.metadata().version, "0.2.0")
            @Expect(document.root().size(), 2)
            @Expect(document.root().member("id").getOrThrow().asInt64(), 42)
            @Expect(document.root().member("missing").isNone())
            @Expect(document.materialize().asObject().get("items").getOrThrow().asArray().size(), 2)
        }
    }

    @TestCase
    func facadePreservesResourceLifecycle(): Unit {
        let document = NativeBackends.customNative.parseDocument("[1,2]")
        let root = document.root()
        document.close()
        document.close()
        @Expect(document.isClosed())
        let error = @AssertThrows[JsonException](root.size())
        @Expect(error.code, "resource_closed")
    }

    @TestCase
    func rootBulkPathsPreserveOptionsSubviewsAndBudgets(): Unit {
        let json = NativeBackends.customNative
        try (document = json.parseDocument("{\"html\":\"<tag>\",\"items\":[1,2]}")) {
            let root = document.root()
            let materialized = document.materialize()
            for (options in [JsonWriteOptions.defaults, JsonWriteOptions.pretty(),
                JsonWriteOptions(htmlSafe: true)]) {
                @Expect(json.toJson(root, options: options),
                    materialized.toJson(options: options))
            }
            @Expect(json.toJson(root.member("items").getOrThrow()), "[1,2]")
            @Expect(document.materialize(5).asObject()["items"].asArray().size(), 2)
            let budgetError = @AssertThrows[JsonException](document.materialize(4))
            @Expect(budgetError.code, "work_limit_exceeded")
            @AssertThrows[IllegalArgumentException](document.materialize(0))
            let outputError = @AssertThrows[JsonException](json.toJson(root,
                options: JsonWriteOptions(maxOutputBytes: 3)))
            @Expect(outputError.code, "output_too_large")
        }
    }

    @TestCase
    func mismatchedInlineScalarsRejectInsteadOfReadingNodeZero(): Unit {
        // Inline object scalars live in the object-entry store with node index
        // 0, so each mismatch used to answer from the first stored node
        // (1 -> asInt64 returned 1, true -> asBool returned true).
        try (document = NativeBackends.customNative.parseDocument(
            "{\"values\":[1],\"text\":\"x\",\"n\":5,\"ok\":false}")) {
            let root = document.root()
            @Expect(@AssertThrows[JsonException](
                root.member("text").getOrThrow().asInt64()).code, "type_mismatch")
            @Expect(@AssertThrows[JsonException](
                root.member("ok").getOrThrow().asInt64()).code, "type_mismatch")
            @Expect(root.member("n").getOrThrow().asInt64(), 5)
            @Expect(root.member("text").getOrThrow().asString(), "x")
            @Expect(root.member("values").getOrThrow().element(0).getOrThrow().asInt64(), 1)
        }
        try (document = NativeBackends.customNative.parseDocument(
            "{\"flags\":[true],\"n\":5,\"ok\":false}")) {
            let root = document.root()
            @Expect(@AssertThrows[JsonException](
                root.member("n").getOrThrow().asBool()).code, "type_mismatch")
            @Expect(root.member("ok").getOrThrow().asBool(), false)
            @Expect(root.member("n").getOrThrow().asInt64(), 5)
            @Expect(root.member("flags").getOrThrow().element(0).getOrThrow().asBool(), true)
        }
    }

    @TestCase
    func closedDocumentKeepsResourceClosedForInlineScalars(): Unit {
        // The resource check must stay ahead of the inline kind check so a
        // closed document reports resource_closed rather than a mismatch.
        let document = NativeBackends.customNative.parseDocument("{\"text\":\"x\",\"n\":5}")
        let root = document.root()
        let text = root.member("text").getOrThrow()
        let number = root.member("n").getOrThrow()
        document.close()
        @Expect(@AssertThrows[JsonException](text.asInt64()).code, "resource_closed")
        @Expect(@AssertThrows[JsonException](number.asBool()).code, "resource_closed")
        @Expect(@AssertThrows[JsonException](number.asInt64()).code, "resource_closed")
    }

    @TestCase
    func concurrentReadsAndCloseAreLinearizable(): Unit {
        let document = NativeBackends.customNative.parseDocument("{\"id\":42,\"items\":[1,2,3]}")
        let root = document.root()
        let readerCount: Int64 = 8
        let iterations: Int64 = 500
        let ready = AtomicInt64(0)
        let start = AtomicInt64(0)
        let readers = ArrayList<Future<Int64>>()
        for (_ in 0..readerCount) {
            readers.add(spawn {
                ready.fetchAdd(1)
                while (start.load() == 0) {}
                var completed: Int64 = 0
                try {
                    for (_ in 0..iterations) {
                        if (root.member("id").getOrThrow().asInt64() != 42) {
                            throw Exception("immutable native view changed during concurrent read")
                        }
                        completed++
                    }
                } catch (error: JsonException) {
                    if (error.code != "resource_closed") { throw error }
                }
                completed
            })
        }
        while (ready.load() != readerCount) {}
        start.store(1)
        document.close()
        for (reader in readers) {
            let completed = reader.get()
            @Expect(completed >= 0 && completed <= iterations)
        }
        let error = @AssertThrows[JsonException](root.kind())
        @Expect(error.code, "resource_closed")
    }
}
