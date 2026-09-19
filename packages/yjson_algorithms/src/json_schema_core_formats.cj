package yjson_algorithms

import std.collection.*
import std.convert.Parsable

private func jsonSchemaAsciiNumber(value: String, start: Int64, length: Int64): Option<Int64> {
    if (start < 0 || start + length > value.size) { return None<Int64> }
    var result: Int64 = 0
    for (index in start..start + length) {
        let byte = value[index]
        if (byte < b'0' || byte > b'9') { return None<Int64> }
        result = result * 10 + Int64(byte - b'0')
    }
    Some(result)
}

class CoreJsonSchemaFormat <: JsonSchemaFormat {
    private let name: String

    public init(name: String) { this.name = name }

    public func validate(value: String): Bool {
        validateWithBudget(value, LinearRegexBudget(JsonSchemaLimits.defaults.maxRegexSteps,
            "JSON Schema format regex steps"))
    }

    func validateWithBudget(value: String, budget: LinearRegexBudget): Bool {
        match (name) {
            case "date" => jsonSchemaIsDate(value)
            case "time" => jsonSchemaIsTime(value)
            case "date-time" => jsonSchemaIsDateTime(value)
            case "duration" => jsonSchemaIsDuration(value)
            case "email" => jsonSchemaIsEmail(value, false)
            case "ipv4" => jsonSchemaIsIpv4(value)
            case "ipv6" => jsonSchemaIsIpv6(value)
            case "uuid" => jsonSchemaIsUuid(value)
            case "regex" => jsonSchemaIsEcmaRegex(value, budget)
            case "json-pointer" => try { let _ = JsonPointer.parse(value); true } catch (_: Exception) { false }
            case "relative-json-pointer" => jsonSchemaIsRelativePointer(value)
            case _ => false
        }
    }
}

private func jsonSchemaIsUuid(value: String): Bool {
    if (value.size != 36) { return false }
    for (index in 0..value.size) {
        if (index == 8 || index == 13 || index == 18 || index == 23) {
            if (value[index] != b'-') { return false }
        } else {
            let byte = value[index]
            if (!((byte >= b'0' && byte <= b'9') || (byte >= b'A' && byte <= b'F') ||
                (byte >= b'a' && byte <= b'f'))) { return false }
        }
    }
    true
}

private func jsonSchemaIsDate(value: String): Bool {
    if (value.size != 10 || value[4] != b'-' || value[7] != b'-') { return false }
    let year = jsonSchemaAsciiNumber(value, 0, 4)
    let month = jsonSchemaAsciiNumber(value, 5, 2)
    let day = jsonSchemaAsciiNumber(value, 8, 2)
    if (year.isNone() || month.isNone() || day.isNone()) { return false }
    let y = year.getOrThrow(); let m = month.getOrThrow(); let d = day.getOrThrow()
    if (m < 1 || m > 12 || d < 1) { return false }
    let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
    let maximum = if (m == 2) { if (leap) { 29 } else { 28 } }
        else if (m == 4 || m == 6 || m == 9 || m == 11) { 30 } else { 31 }
    d <= maximum
}

private func jsonSchemaIsTime(value: String): Bool {
    if (value.size < 9 || value[2] != b':' || value[5] != b':') { return false }
    let hour = jsonSchemaAsciiNumber(value, 0, 2)
    let minute = jsonSchemaAsciiNumber(value, 3, 2)
    let second = jsonSchemaAsciiNumber(value, 6, 2)
    if (hour.isNone() || minute.isNone() || second.isNone()) { return false }
    let h = hour.getOrThrow(); let m = minute.getOrThrow(); let s = second.getOrThrow()
    if (h > 23 || m > 59 || s > 60) { return false }
    var index: Int64 = 8
    if (index < value.size && value[index] == b'.') {
        index++
        let start = index
        while (index < value.size && value[index] >= b'0' && value[index] <= b'9') { index++ }
        if (index == start) { return false }
    }
    if (index >= value.size) { return false }
    if (value[index] == b'Z' || value[index] == b'z') {
        return index + 1 == value.size && (s != 60 || (h == 23 && m == 59))
    }
    if (value[index] != b'+' && value[index] != b'-') { return false }
    if (index + 6 != value.size || value[index + 3] != b':') { return false }
    let offsetHour = jsonSchemaAsciiNumber(value, index + 1, 2)
    let offsetMinute = jsonSchemaAsciiNumber(value, index + 4, 2)
    if (offsetHour.isNone() || offsetMinute.isNone() || offsetHour.getOrThrow() > 23 ||
        offsetMinute.getOrThrow() > 59) { return false }
    if (s == 60) {
        let offset = offsetHour.getOrThrow() * 60 + offsetMinute.getOrThrow()
        var utcMinute = h * 60 + m + if (value[index] == b'+') { -offset } else { offset }
        while (utcMinute < 0) { utcMinute += 1440 }; while (utcMinute >= 1440) { utcMinute -= 1440 }
        return utcMinute == 1439
    }
    true
}

private func jsonSchemaIsDateTime(value: String): Bool {
    if (value.size < 20) { return false }
    var separator: Int64 = -1
    for (index in 0..value.size) { if (value[index] == b'T' || value[index] == b't') {
        if (separator >= 0) { return false }; separator = index
    } }
    separator == 10 && jsonSchemaIsDate(value[0..separator]) && jsonSchemaIsTime(value[separator + 1..value.size])
}

private func jsonSchemaIsDuration(value: String): Bool {
    if (value.size < 2 || value[0] != b'P') { return false }
    var index: Int64 = 1
    var saw = false
    var inTime = false
    var lastRank: Int64 = 0
    var weekOnly = false
    var dateMask: Int64 = 0
    var timeMask: Int64 = 0
    while (index < value.size) {
        if (value[index] == b'T') {
            if (inTime || weekOnly) { return false }
            inTime = true; index++; lastRank = 0
            if (index == value.size) { return false }
            continue
        }
        let start = index
        while (index < value.size && value[index] >= b'0' && value[index] <= b'9') { index++ }
        if (index == start || index >= value.size) { return false }
        let unit = value[index]; index++
        var rank: Int64 = 0
        if (!inTime) {
            rank = if (unit == b'Y') { 1 } else if (unit == b'M') { 2 } else if (unit == b'D') { 3 }
                else if (unit == b'W') { 4 } else { return false }
            if (unit == b'W') { if (saw || index != value.size) { return false }; weekOnly = true }
        } else {
            rank = if (unit == b'H') { 1 } else if (unit == b'M') { 2 } else if (unit == b'S') { 3 } else { return false }
        }
        if (rank <= lastRank) { return false }
        if (!inTime) { dateMask |= 1 << rank } else { timeMask |= 1 << rank }
        lastRank = rank; saw = true
    }
    saw && !((dateMask & (1 << 1)) != 0 && (dateMask & (1 << 3)) != 0 && (dateMask & (1 << 2)) == 0) &&
        !((timeMask & (1 << 1)) != 0 && (timeMask & (1 << 3)) != 0 && (timeMask & (1 << 2)) == 0)
}

private func jsonSchemaIsHostname(value: String, international: Bool): Bool {
    if (value.isEmpty() || value.size > 253 || value.startsWith(".") || value.endsWith(".")) { return false }
    for (label in splitJsonSchemaAscii(value, b'.')) {
        if (label.isEmpty() || label.size > 63 || label.startsWith("-") || label.endsWith("-")) { return false }
        for (byte in unsafe { label.rawData() }) {
            if (byte >= 0x80u8) { if (!international) { return false } }
            else if (!((byte >= b'A' && byte <= b'Z') || (byte >= b'a' && byte <= b'z') ||
                (byte >= b'0' && byte <= b'9') || byte == b'-')) { return false }
        }
    }
    true
}

private func jsonSchemaIsEmail(value: String, international: Bool): Bool {
    if (value.isEmpty() || value.contains("\r") || value.contains("\n") || value.contains("\t") ||
        value.startsWith(" ") || value.endsWith(" ")) { return false }
    var at: Int64 = -1; var quoted = false; var escaped = false
    for (index in 0..value.size) {
        let byte = value[index]
        if (quoted) {
            if (!escaped && byte == b'\"') { quoted = false }
            if (!escaped && byte == b'\\') { escaped = true } else { escaped = false }
        } else if (byte == b'\"') { quoted = true
        } else if (byte == b'@') { if (at >= 0) { return false }; at = index }
    }
    if (quoted || at <= 0 || at >= value.size - 1) { return false }
    let local = value[0..at]; let domain = value[at + 1..value.size]
    if (local.startsWith("\"") != local.endsWith("\"")) { return false }
    if (!local.startsWith("\"") && (local.startsWith(".") || local.endsWith(".") || local.contains("..") ||
        local.contains(" ") || local.contains("\\") || local.contains("\"") ||
        local.contains(",") || local.contains(";") || local.contains(":") ||
        local.contains("(") || local.contains(")") || local.contains("["))) { return false }
    if (!international) { for (byte in unsafe { local.rawData() }) { if (byte >= 0x80u8 || byte == 0x7Fu8) { return false } } }
    if (domain.startsWith("[") && domain.endsWith("]")) {
        let address = domain[1..domain.size - 1]
        if (address.startsWith("IPv6:") || address.startsWith("ipv6:")) {
            return jsonSchemaIsIpv6(address[5..address.size])
        }
        return jsonSchemaIsIpv4(address)
    }
    jsonSchemaIsHostname(domain, international)
}

private func jsonSchemaIsHex(value: Byte): Bool {
    (value >= b'0' && value <= b'9') || (value >= b'a' && value <= b'f') ||
        (value >= b'A' && value <= b'F')
}

private func jsonSchemaIsIpv4(value: String): Bool {
    let parts = splitJsonSchemaAscii(value, b'.')
    if (parts.size != 4) { return false }
    for (part in parts) {
        if (part.isEmpty() || (part.size > 1 && part.startsWith("0"))) { return false }
        try {
            let number = Int64.parse(part)
            if (number < 0 || number > 255) { return false }
        } catch (_: Exception) { return false }
    }
    true
}

private func jsonSchemaIsIpv6(value: String): Bool {
    if (value.isEmpty() || value.contains(":::")) { return false }
    let compression = value.indexOf("::")
    if (compression.isSome() && value[compression.getOrThrow() + 2..value.size].contains("::")) { return false }
    let left = if (compression.isSome()) { value[0..compression.getOrThrow()] } else { value }
    let right = if (compression.isSome()) { value[compression.getOrThrow() + 2..value.size] } else { "" }
    let leftCount = jsonSchemaIpv6Units(left, right.isEmpty())
    if (leftCount < 0) { return false }
    let rightCount = if (compression.isSome()) { jsonSchemaIpv6Units(right, true) } else { 0 }
    if (rightCount < 0) { return false }
    if (compression.isSome()) { leftCount + rightCount < 8 } else { leftCount == 8 }
}

private func jsonSchemaIpv6Units(value: String, allowIpv4: Bool): Int64 {
    if (value.isEmpty()) { return 0 }
    let parts = splitJsonSchemaAscii(value, b':')
    var units: Int64 = 0
    for (index in 0..parts.size) {
        let part = parts[index]
        if (part.isEmpty()) { return -1 }
        if (part.contains(".")) {
            if (!allowIpv4 || index != parts.size - 1 || !jsonSchemaIsIpv4(part)) { return -1 }
            units += 2
        } else {
            if (part.size > 4) { return -1 }
            for (byte in unsafe { part.rawData() }) { if (!jsonSchemaIsHex(byte)) { return -1 } }
            units++
        }
    }
    units
}

private func jsonSchemaIsRelativePointer(value: String): Bool {
    if (value.isEmpty()) { return false }
    var index: Int64 = 0
    while (index < value.size && value[index] >= b'0' && value[index] <= b'9') { index++ }
    if (index == 0 || (index > 1 && value[0] == b'0')) { return false }
    if (index == value.size) { return true }
    if (value[index..value.size] == "#") { return true }
    try { let _ = JsonPointer.parse(value[index..value.size]); true } catch (_: Exception) { false }
}


private func jsonSchemaIsEcmaRegex(value: String, budget: LinearRegexBudget): Bool {
    LinearRegex.validateEcmaSyntax(value, budget)
}
