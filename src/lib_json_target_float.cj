package yjson

import std.convert.Parsable
import std.math.numeric.*

// The midpoint after positive `low` has exact value (2*significand+1)*2^exponent.
// Its decimal integer uses at most 150 powers of five, regardless of input length.
// The final finite midpoint also represents the round-to-nearest overflow cutoff.
private func jsonTargetFloatMidpointDecimal(low: UInt64, fractionBits: Int64, bias: Int64): (String, Int64) {
    let exponentField = Int64(low >> fractionBits)
    let fractionMask = (1u64 << fractionBits) - 1u64
    let significand = (low & fractionMask) + if (exponentField == 0) { 0u64 } else { 1u64 << fractionBits }
    let exponent = (if (exponentField == 0) { 1 - bias } else { exponentField - bias }) - fractionBits - 1
    var integer = BigInt(Int64(significand * 2u64 + 1u64))
    var power = if (exponent < 0) { -exponent } else { exponent }
    var factor = BigInt(if (exponent < 0) { 5 } else { 2 })
    while (power > 0) {
        if (power % 2 != 0) { integer *= factor }
        power /= 2
        if (power > 0) { factor *= factor }
    }
    let digits = integer.toString()
    (digits, digits.size - 1 + if (exponent < 0) { exponent } else { 0 })
}

// A validated JSON number remains a byte view. Only 17 significant digits are
// collected for a bounded approximate candidate; all original digits participate
// in the exact midpoint comparison, including arbitrarily long nonzero tails.
class JsonTargetFloatDecimal {
    let data: Array<Byte>
    let mantissaEnd: Int64
    let firstDigit: Int64
    let exponent: Int64
    let coefficient: UInt64
    let prefixDigits: Int64
    let negative: Bool

    init(text: String) {
        data = unsafe { text.rawData() }
        negative = data[0] == b'-'
        var offset: Int64 = if (negative) { 1 } else { 0 }
        var integerDigits: Int64 = 0
        var leadingZeros: Int64 = 0
        var first: Int64 = -1
        var fraction = false
        var prefix: UInt64 = 0u64
        var count: Int64 = 0
        while (offset < data.size && data[offset] != b'e' && data[offset] != b'E') {
            let digit = data[offset]
            if (digit == b'.') { fraction = true } else {
                if (!fraction) { integerDigits++ }
                if (first < 0) {
                    if (digit == b'0') { leadingZeros++ } else { first = offset }
                }
                if (first >= 0 && count < 17) {
                    prefix = prefix * 10u64 + UInt64(digit - b'0')
                    count++
                }
            }
            offset++
        }
        mantissaEnd = offset
        firstDigit = first
        coefficient = prefix
        prefixDigits = count
        var decimalExponent: Int64 = 0
        if (offset < data.size) {
            offset++
            var exponentNegative = false
            if (data[offset] == b'-' || data[offset] == b'+') {
                exponentNegative = data[offset] == b'-'
                offset++
            }
            // Beyond this cap, mantissa length cannot cancel the exponent
            // into the Float16/Float32 finite or subnormal ranges.
            let cap = data.size + 512
            while (offset < data.size) {
                let digit = Int64(data[offset] - b'0')
                if (decimalExponent > (cap - digit) / 10) { decimalExponent = cap }
                else { decimalExponent = min(cap, decimalExponent * 10 + digit) }
                offset++
            }
            if (exponentNegative) { decimalExponent = -decimalExponent }
        }
        exponent = decimalExponent + integerDigits - leadingZeros - 1
    }

    func compareMidpoint(low: UInt64, fractionBits: Int64, bias: Int64): Int64 {
        if (firstDigit < 0) { return -1 }
        let (midpoint, midpointExponent) = jsonTargetFloatMidpointDecimal(low, fractionBits, bias)
        if (exponent != midpointExponent) { return if (exponent < midpointExponent) { -1 } else { 1 } }
        let midpointDigits = unsafe { midpoint.rawData() }
        var sourceOffset = firstDigit
        var midpointOffset: Int64 = 0
        while (sourceOffset < mantissaEnd || midpointOffset < midpointDigits.size) {
            if (sourceOffset < mantissaEnd && data[sourceOffset] == b'.') { sourceOffset++ }
            let sourceDigit = if (sourceOffset < mantissaEnd) { data[sourceOffset] } else { b'0' }
            let midpointDigit = if (midpointOffset < midpointDigits.size) { midpointDigits[midpointOffset] } else { b'0' }
            if (sourceDigit != midpointDigit) { return if (sourceDigit < midpointDigit) { -1 } else { 1 } }
            sourceOffset++
            midpointOffset++
        }
        0
    }
}

// A bad approximate candidate can never determine the result: this fallback
// proves the result in at most 31 comparisons for Float32, 15 for Float16.
private func jsonTargetFloatSearchBits(number: JsonTargetFloatDecimal, lower: UInt64, upper: UInt64, fractionBits: Int64, bias: Int64): UInt64 {
    var lo = lower
    var hi = upper
    while (lo < hi) {
        let middle = lo + (hi - lo) / 2u64
        let comparison = number.compareMidpoint(middle, fractionBits, bias)
        if (comparison < 0 || (comparison == 0 && middle % 2u64 == 0u64)) { hi = middle } else { lo = middle + 1u64 }
    }
    lo
}

// Check both exact rounding boundaries, including tie parity. Usually the
// candidate or its immediate neighbor is correct. No SDK rounding assumption
// is needed for the bounded search if the approximation is farther away.
func jsonTargetFloatCorrectBits(number: JsonTargetFloatDecimal, candidate: UInt64, infinity: UInt64, fractionBits: Int64, bias: Int64): UInt64 {
    if (candidate > 0u64) {
        let lower = number.compareMidpoint(candidate - 1u64, fractionBits, bias)
        if (lower < 0 || (lower == 0 && candidate % 2u64 != 0u64)) {
            let previous = candidate - 1u64
            if (previous == 0u64) { return previous }
            let previousLower = number.compareMidpoint(previous - 1u64, fractionBits, bias)
            if (previousLower > 0 || (previousLower == 0 && previous % 2u64 == 0u64)) { return previous }
            return jsonTargetFloatSearchBits(number, 0u64, previous - 1u64, fractionBits, bias)
        }
    }
    if (candidate < infinity) {
        let upper = number.compareMidpoint(candidate, fractionBits, bias)
        if (upper > 0 || (upper == 0 && candidate % 2u64 != 0u64)) {
            let next = candidate + 1u64
            if (next == infinity) { return next }
            let nextUpper = number.compareMidpoint(next, fractionBits, bias)
            if (nextUpper < 0 || (nextUpper == 0 && next % 2u64 == 0u64)) { return next }
            return jsonTargetFloatSearchBits(number, next + 1u64, infinity, fractionBits, bias)
        }
    }
    candidate
}

// These internal entry points consume grammar-validated literals. Huge and tiny
// exponents are classified before asking the SDK to parse a bounded prefix.
// The Float64 prefix is only a search hint, never an intermediate final rounding.
func jsonParseFloat32Literal(text: String): Float32 {
    let number = JsonTargetFloatDecimal(text)
    let sign = if (number.negative) { 0x80000000u32 } else { 0u32 }
    if (number.firstDigit < 0 || number.exponent < -46) { return Float32.fromBits(sign) }
    if (number.exponent > 38) { return Float32.fromBits(sign | 0x7f800000u32) }
    let approximate = Float64.parse("${number.coefficient}e${number.exponent - number.prefixDigits + 1}")
    let candidate = UInt64(Float32(approximate).toBits())
    let corrected = jsonTargetFloatCorrectBits(number, candidate, 0x7f800000u64, 23, 127)
    Float32.fromBits(UInt32(corrected) | sign)
}

func jsonParseFloat16Literal(text: String): Float16 {
    let number = JsonTargetFloatDecimal(text)
    let sign = if (number.negative) { 0x8000u16 } else { 0u16 }
    if (number.firstDigit < 0 || number.exponent < -8) { return Float16.fromBits(sign) }
    if (number.exponent > 4) { return Float16.fromBits(sign | 0x7c00u16) }
    let approximate = Float64.parse("${number.coefficient}e${number.exponent - number.prefixDigits + 1}")
    let candidate = UInt64(Float16(approximate).toBits())
    let corrected = jsonTargetFloatCorrectBits(number, candidate, 0x7c00u64, 10, 15)
    Float16.fromBits(UInt16(corrected) | sign)
}
