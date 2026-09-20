#include "yjson_scanner.h"

#include <stddef.h>

static int yj_json_writer_needs_html_escape(uint8_t value) {
    return value == '<' || value == '>' || value == '&' || value == '=' || value == '\'';
}

int32_t YJ_JSON_EscapeString(const uint8_t* input, int64_t len, uint8_t htmlSafe,
    uint8_t* output, int64_t outputCap, int64_t* outWritten) {
    static const uint8_t hex[] = "0123456789abcdef";
    int64_t written = 0;
    if (input == NULL || output == NULL || outWritten == NULL || len < 0 || outputCap < 2) {
        return YJ_JSON_SCAN_ERROR;
    }
#define YJ_WRITE_BYTE(byteValue) do { \
        if (written >= outputCap) return YJ_JSON_SCAN_CAPACITY; \
        output[written++] = (uint8_t)(byteValue); \
    } while (0)
    YJ_WRITE_BYTE('"');
    for (int64_t index = 0; index < len; ++index) {
        uint8_t value = input[index];
        if (value >= 0x20 && value != '"' && value != '\\' &&
            (!htmlSafe || !yj_json_writer_needs_html_escape(value))) {
            YJ_WRITE_BYTE(value);
            continue;
        }
        YJ_WRITE_BYTE('\\');
        switch (value) {
            case '"': YJ_WRITE_BYTE('"'); break;
            case '\\': YJ_WRITE_BYTE('\\'); break;
            case '\b': YJ_WRITE_BYTE('b'); break;
            case '\f': YJ_WRITE_BYTE('f'); break;
            case '\n': YJ_WRITE_BYTE('n'); break;
            case '\r': YJ_WRITE_BYTE('r'); break;
            case '\t': YJ_WRITE_BYTE('t'); break;
            default:
                YJ_WRITE_BYTE('u'); YJ_WRITE_BYTE('0'); YJ_WRITE_BYTE('0');
                YJ_WRITE_BYTE(hex[value >> 4]); YJ_WRITE_BYTE(hex[value & 0x0f]);
                break;
        }
    }
    YJ_WRITE_BYTE('"');
#undef YJ_WRITE_BYTE
    *outWritten = written;
    return YJ_JSON_SCAN_OK;
}

static const char yj_json_digits100[] =
    "00010203040506070809"
    "10111213141516171819"
    "20212223242526272829"
    "30313233343536373839"
    "40414243444546474849"
    "50515253545556575859"
    "60616263646566676869"
    "70717273747576777879"
    "80818283848586878889"
    "90919293949596979899";

static int32_t yj_json_uint64_length(uint64_t value)
{
    uint64_t product = 10u;
    for (int32_t length = 1; length < 19; ++length) {
        if (value < product) return length;
        product *= 10u;
    }
    return value >= UINT64_C(10000000000000000000) ? 20 : 19;
}

static int32_t yj_json_write_uint64(uint8_t* output, uint64_t value)
{
    if (value < 10u) {
        output[0] = (uint8_t)('0' + value);
        return 1;
    }
    if (value < 100u) {
        const uint64_t pair = value * 2u;
        output[0] = (uint8_t)yj_json_digits100[pair];
        output[1] = (uint8_t)yj_json_digits100[pair + 1u];
        return 2;
    }
    if (value < 10000u) {
        const uint64_t high = value / 100u;
        const uint64_t low = value - high * 100u;
        if (high < 10u) {
            output[0] = (uint8_t)('0' + high);
            output[1] = (uint8_t)yj_json_digits100[low * 2u];
            output[2] = (uint8_t)yj_json_digits100[low * 2u + 1u];
            return 3;
        }
        output[0] = (uint8_t)yj_json_digits100[high * 2u];
        output[1] = (uint8_t)yj_json_digits100[high * 2u + 1u];
        output[2] = (uint8_t)yj_json_digits100[low * 2u];
        output[3] = (uint8_t)yj_json_digits100[low * 2u + 1u];
        return 4;
    }
    const int32_t length = yj_json_uint64_length(value);
    uint8_t* next = output + length;
    while (value >= 100u) {
        const uint64_t high = value / 100u;
        const uint64_t low = value - high * 100u;
        next -= 2;
        next[0] = (uint8_t)yj_json_digits100[low * 2u];
        next[1] = (uint8_t)yj_json_digits100[low * 2u + 1u];
        value = high;
    }
    if (value < 10u) {
        output[0] = (uint8_t)('0' + value);
    } else {
        output[0] = (uint8_t)yj_json_digits100[value * 2u];
        output[1] = (uint8_t)yj_json_digits100[value * 2u + 1u];
    }
    return length;
}

static int32_t yj_json_write_int64(uint8_t* output, int64_t outputCap,
    int64_t* written, int64_t value)
{
    if (value >= 0 && value < 10000) {
        if (*written > outputCap - 4) return YJ_JSON_SCAN_CAPACITY;
        *written += yj_json_write_uint64(output + *written, (uint64_t)value);
        return YJ_JSON_SCAN_OK;
    }
    uint64_t magnitude;
    if (value < 0) {
        if (*written >= outputCap) return YJ_JSON_SCAN_CAPACITY;
        output[(*written)++] = '-';
        magnitude = (uint64_t)(-(value + 1)) + 1u;
    } else {
        magnitude = (uint64_t)value;
    }
    const int32_t count = yj_json_uint64_length(magnitude);
    if (*written > outputCap - count) return YJ_JSON_SCAN_CAPACITY;
    *written += yj_json_write_uint64(output + *written, magnitude);
    return YJ_JSON_SCAN_OK;
}

int32_t YJ_JSON_FormatInt64Array(const int64_t* values, int64_t count,
    uint8_t* output, int64_t outputCap, int64_t outputOffset,
    int64_t* outWritten)
{
    if (values == NULL || output == NULL || outWritten == NULL || count < 0 ||
        outputOffset < 0 || outputOffset > outputCap ||
        outputCap - outputOffset < 2) return YJ_JSON_SCAN_ERROR;
    output += outputOffset;
    outputCap -= outputOffset;
    int64_t written = 0;
    output[written++] = '[';
    for (int64_t index = 0; index < count; ++index) {
        if (index > 0) {
            if (written >= outputCap) return YJ_JSON_SCAN_CAPACITY;
            output[written++] = ',';
        }
        int32_t status = yj_json_write_int64(output, outputCap, &written, values[index]);
        if (status != YJ_JSON_SCAN_OK) return status;
    }
    if (written >= outputCap) return YJ_JSON_SCAN_CAPACITY;
    output[written++] = ']';
    *outWritten = written;
    return YJ_JSON_SCAN_OK;
}
