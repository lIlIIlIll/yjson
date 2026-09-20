#include "yjson_compact.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint64_t parse(const char *json, uint32_t flags, uint32_t *root) {
    uint64_t handle = 0;
    uint32_t error = 0;
    int64_t offset = -1;
    int32_t status = YJ_Compact_Parse((const uint8_t *)json, (int64_t)strlen(json),
                                     flags, 256, &handle, root, &error, &offset);
    assert(status == YJ_COMPACT_OK);
    assert(error == YJ_COMPACT_OK);
    assert(handle != 0);
    return handle;
}

static void expect_rejected(const uint8_t *json, size_t length, uint32_t flags,
                            uint32_t expected) {
    uint64_t handle = 0;
    uint32_t root = 0, error = 0;
    int64_t offset = -1;
    int32_t status = YJ_Compact_Parse(json, (int64_t)length, flags, 256,
                                     &handle, &root, &error, &offset);
    assert(status == (int32_t)expected);
    assert(error == expected);
    assert(handle == 0);
    assert(offset >= 0 || expected == YJ_COMPACT_OUT_OF_MEMORY);
}

static void expect_limit(const char *json, int64_t max_bytes,
                         int64_t max_string_bytes, int64_t max_value_bytes,
                         uint32_t expected) {
    uint64_t handle = 0;
    uint32_t root = 0, error = 0;
    int64_t offset = -1;
    int32_t status = YJ_Compact_ParseWithLimits(
        (const uint8_t *)json, (int64_t)strlen(json), 0, 256,
        max_bytes, max_string_bytes, max_value_bytes,
        &handle, &root, &error, &offset);
    assert(status == (int32_t)expected);
    assert(error == expected);
    assert(handle == 0);
    assert(offset >= 0);
}

static void test_stats_abi_layout(void) {
    const uint32_t field_count = 2048u;
    const size_t json_capacity = 65536u;
    char *json = (char *)malloc(json_capacity);
    assert(json != NULL);
    size_t length = 0;
    json[length++] = '{';
    for (uint32_t i = 0; i < field_count; i++) {
        int written = snprintf(json + length, json_capacity - length,
                               "%s\"k%u\":%u", i == 0 ? "" : ",", i, i);
        assert(written > 0);
        assert((size_t)written < json_capacity - length);
        length += (size_t)written;
    }
    json[length++] = '}';
    json[length] = '\0';

    uint32_t root = 0;
    uint64_t handle = parse(json, YJ_COMPACT_DUPLICATE_STATS |
        YJ_COMPACT_DUPLICATE_PRESIZE, &root);

    uint64_t stats[12];
    for (uint32_t i = 0; i < 12u; i++) stats[i] = UINT64_MAX;
    assert(YJ_Compact_Stats(handle, stats, 11u) == YJ_COMPACT_BOUNDS_ERROR);
    for (uint32_t i = 0; i < 12u; i++) assert(stats[i] == UINT64_MAX);
    assert(YJ_Compact_Stats(handle, stats, 12u) == YJ_COMPACT_OK);
    /* Frozen public ABI positions, independent of implementation slot names. */
    assert(stats[0] == length);
    assert(stats[1] >= stats[3]);
    assert(stats[2] >= stats[1]);
    assert(stats[4] >= stats[3]);
    assert(stats[5] == 0u);
    assert(stats[6] >= stats[5]);
    assert(stats[7] > 0u);
    assert(stats[8] == 1u);
    assert(stats[9] == field_count);
    assert(stats[10] == 0u);
    assert(stats[11] == 0u);

    uint64_t duplicate_stats[16];
    for (uint32_t i = 0; i < 16u; i++) duplicate_stats[i] = UINT64_MAX;
    assert(YJ_Compact_DuplicateStats(handle, duplicate_stats, 15u) ==
           YJ_COMPACT_BOUNDS_ERROR);
    for (uint32_t i = 0; i < 16u; i++) assert(duplicate_stats[i] == UINT64_MAX);
    assert(YJ_Compact_DuplicateStats(handle, duplicate_stats, 16u) ==
           YJ_COMPACT_OK);
    assert(duplicate_stats[0] == field_count);
    assert(duplicate_stats[1] == field_count);
    assert(duplicate_stats[2] >= field_count);
    assert(duplicate_stats[3] == 0u);
    assert(duplicate_stats[4] > 0u);
    assert(duplicate_stats[5] > 0u);
    assert(duplicate_stats[6] >= field_count);
    assert(duplicate_stats[7] >= field_count);
    assert(duplicate_stats[8] >= duplicate_stats[7]);
    assert(duplicate_stats[9] > 0u && duplicate_stats[9] <= duplicate_stats[4]);
    assert(duplicate_stats[10] >= duplicate_stats[9] &&
           duplicate_stats[10] <= duplicate_stats[4]);
    assert(duplicate_stats[11] >= duplicate_stats[10] &&
           duplicate_stats[11] <= duplicate_stats[4]);
    assert(duplicate_stats[12] == field_count);
    assert(duplicate_stats[13] ==
           field_count * 1000000u / duplicate_stats[7]);
    assert(duplicate_stats[14] <= 1u);
    assert(duplicate_stats[15] == 0u);

    YJ_Compact_Free(handle);
    free(json);
}

int main(void) {
    test_stats_abi_layout();
    uint32_t root;
    uint64_t handle = parse(
        "{\"a\":1,\"b\":[true,null,\"x\",-9223372036854775808,1.5],"
        "\"unicode\":\"\xE4\xB8\xAD\xF0\x9F\x98\x80\"}", 0, &root);
    uint32_t kind;
    uint64_t size;
    assert(YJ_Compact_Kind(handle, root, &kind) == 0 && kind == YJ_COMPACT_OBJECT);
    assert(YJ_Compact_Size(handle, root, &size) == 0 && size == 3);
    uint32_t value_kind, found;
    uint64_t payload;
    assert(YJ_Compact_ObjectLookup(handle, root, (const uint8_t *)"a", 1,
                                  &value_kind, &payload, &found) == 0);
    assert(found == 1 && value_kind == YJ_COMPACT_INT && (int64_t)payload == 1);
    uint64_t written = 0;
    assert(YJ_Compact_Serialize(handle, NULL, 0, &written) == YJ_COMPACT_BOUNDS_ERROR);
    uint8_t *serialized = (uint8_t *)malloc((size_t)written);
    assert(YJ_Compact_Serialize(handle, serialized, written, &written) == 0);
    uint64_t roundtrip = 0;
    uint32_t roundtrip_root = 0, error = 0;
    int64_t offset = -1;
    assert(YJ_Compact_Parse(serialized, (int64_t)written, 0, 256,
                           &roundtrip, &roundtrip_root, &error, &offset) == 0);
    free(serialized);
    YJ_Compact_Free(roundtrip);
    YJ_Compact_Free(handle);

    handle = parse("{\"plain\":\"value\",\"number\":1.5,\"escaped\":\"a\\u0062\"}",
                   YJ_COMPACT_MATERIALIZE_SOURCE, &root);
    assert(YJ_Compact_ObjectLookup(handle, root, (const uint8_t *)"plain", 5,
                                  &value_kind, &payload, &found) == 0 && found == 1);
    uint64_t owned_buffer = 0, owned_size = 0;
    assert(YJ_Compact_SerializeAlloc(handle, &owned_buffer, &owned_size) == 0);
    serialized = (uint8_t *)malloc((size_t)owned_size);
    assert(YJ_Compact_CopyOwnedBuffer(owned_buffer, serialized, owned_size) == 0);
    YJ_Compact_FreeOwnedBuffer(owned_buffer);
    free(serialized);
    YJ_Compact_Free(handle);

    handle = parse("{\"a\":1,\"\\u0061\":2}", 0, &root);
    assert(YJ_Compact_Size(handle, root, &size) == 0 && size == 1);
    assert(YJ_Compact_ObjectLookup(handle, root, (const uint8_t *)"a", 1,
                                  &value_kind, &payload, &found) == 0);
    assert(found == 1 && value_kind == YJ_COMPACT_INT && (int64_t)payload == 2);
    YJ_Compact_Free(handle);

    const char *duplicate = "{\"a\":1,\"\\u0061\":2}";
    expect_rejected((const uint8_t *)duplicate, strlen(duplicate),
                    YJ_COMPACT_REJECT_DUPLICATES, YJ_COMPACT_DUPLICATE_KEY);
    expect_rejected((const uint8_t *)"[01]", 4, 0, YJ_COMPACT_PARSE_ERROR);
    expect_rejected((const uint8_t *)"[1.]", 4, 0, YJ_COMPACT_PARSE_ERROR);
    expect_rejected((const uint8_t *)"\"\\uD800\"", 8, 0, YJ_COMPACT_PARSE_ERROR);
    const uint8_t bad_utf8[] = {'"', 0xC0, 0xAF, '"'};
    expect_rejected(bad_utf8, sizeof(bad_utf8), 0, YJ_COMPACT_INVALID_UTF8);
    expect_limit("{\"a\":1}", 6, 0, 0, YJ_COMPACT_DOCUMENT_TOO_LARGE);
    expect_limit("\"\\u4E2D\"", 0, 2, 0, YJ_COMPACT_STRING_TOO_LARGE);
    expect_limit("{\"a\":[1,2]}", 0, 0, 10, YJ_COMPACT_VALUE_TOO_LARGE);
    return 0;
}
