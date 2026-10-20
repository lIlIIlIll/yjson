#!/usr/bin/env python3
"""Check public Float16/Float32 reads against an exact rational IEEE-754 oracle.

Requires cjc/cjpm in the current environment. The temporary consumer uses the
repository's release optimization (-O2) and the process's ordinary stack limit.
Pass --native to install the native scanner before exercising the same vectors.
"""

from __future__ import annotations

import argparse
import json
from decimal import Decimal, localcontext
from fractions import Fraction
from pathlib import Path
import random
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def midpoint(low: int, fraction_bits: int, bias: int) -> Fraction:
    exponent_field = low >> fraction_bits
    significand = low & ((1 << fraction_bits) - 1)
    if exponent_field:
        significand += 1 << fraction_bits
    exponent = (exponent_field - bias if exponent_field else 1 - bias) - fraction_bits - 1
    return Fraction(2 * significand + 1) * Fraction(2) ** exponent


def round_bits(value: Fraction, fraction_bits: int, bias: int, infinity: int) -> int:
    sign = (1 << infinity.bit_length()) if value < 0 else 0
    value = abs(value)
    low, high = 0, infinity
    while low < high:
        middle = (low + high) // 2
        edge = midpoint(middle, fraction_bits, bias)
        if value < edge or (value == edge and middle % 2 == 0):
            high = middle
        else:
            low = middle + 1
    return sign | low


def decimal_text(value: Fraction) -> str:
    # All generated denominators contain only powers of two/five. The bound
    # exceeds the longest exact representation, so this conversion is exact.
    with localcontext() as context:
        context.prec = 1200
        return format(Decimal(value.numerator) / Decimal(value.denominator), "f")


def oracle_vectors() -> list[tuple[str, int, int]]:
    rows: list[tuple[str, int, int]] = []

    def append(value: Fraction, literal: str | None = None) -> None:
        rows.append((literal if literal is not None else decimal_text(value),
            round_bits(value, 10, 15, 0x7C00),
            round_bits(value, 23, 127, 0x7F800000)))

    # All exponent fields, both significand parities, binade transitions,
    # zero/subnormal and subnormal/normal edges, and the overflow midpoint.
    for fraction_bits, bias, last_exponent in [(10, 15, 30), (23, 127, 254)]:
        for exponent_field in range(last_exponent + 1):
            for fraction in [0, 1, (1 << fraction_bits) - 2, (1 << fraction_bits) - 1]:
                low = (exponent_field << fraction_bits) + fraction
                edge = midpoint(low, fraction_bits, bias)
                fractional_digits = len(decimal_text(edge).partition(".")[2])
                epsilon = Fraction(1, 10 ** (max(fractional_digits, 17) + 20))
                for value in [edge - epsilon, edge, edge + epsilon]:
                    append(value)
                    append(-value)

    randomizer = random.Random(20261002)
    for _ in range(1000):
        coefficient = randomizer.randrange(-10**30, 10**30)
        exponent = randomizer.randrange(-80, 60)
        append(Fraction(coefficient) * Fraction(10) ** exponent,
            f"{coefficient}e{exponent}")

    rows.extend([
        ("1e100000000000000000000000000000000", 0x7C00, 0x7F800000),
        ("-1e-100000000000000000000000000000000", 0x8000, 0x80000000),
        ("0." + "0" * 10000 + "1e10000", 0x2E66, 0x3DCCCCCD),
        ("-0", 0x8000, 0x80000000),
        ("-0.0e99999999999999999999999", 0x8000, 0x80000000),
    ])
    return rows


CONSUMER = r'''package yjson_target_float_oracle

import std.convert.Parsable
import std.fs.*
import yjson.*
__NATIVE_IMPORT__

main(): Int64 {
    __NATIVE_INITIALIZE__
    let lines = String.fromUtf8(File.readFrom("vectors.tsv")).split("\n")
    var cases: Int64 = 0
    var failures: Int64 = 0
    for (line in lines) {
        if (line.isEmpty()) { continue }
        let row = line.split("\t")
        let actual16 = YJson.fromJson<Float16>(row[0]).toBits()
        let actual32 = YJson.fromJson<Float32>(row[0]).toBits()
        if (actual16 != UInt16.parse(row[1]) || actual32 != UInt32.parse(row[2])) {
            failures++
            println("mismatch ${row[0]} expected=${row[1]},${row[2]} actual=${actual16},${actual32}")
        }
        cases++
    }
    println("target-float oracle: cases=${cases} mismatches=${failures}")
    if (failures > 0) { return 1 }
    0
}
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="install native primitives before parsing")
    args = parser.parse_args()
    rows = oracle_vectors()
    with tempfile.TemporaryDirectory(prefix="yjson-target-float-") as temporary:
        consumer = Path(temporary)
        (consumer / "src").mkdir()
        dependencies = f"yjson = {{ path = {json.dumps(str(ROOT))} }}\n"
        if args.native:
            dependencies += "yjson_native_primitives = { path = " + json.dumps(
                str(ROOT / "packages" / "yjson_native_primitives")) + " }\n"
        native_link = 'link-option = "-L target/native -lyjson_scanner"\n' if args.native else ""
        (consumer / "cjpm.toml").write_text(
            '[package]\ncjc-version = "1.1.0"\nname = "yjson_target_float_oracle"\n'
            'version = "0.1.0"\noutput-type = "executable"\ncompile-option = "-O2"\n'
            + native_link + "\n[dependencies]\n" + dependencies, encoding="utf-8")
        (consumer / "vectors.tsv").write_text(
            "".join(f"{literal}\t{half}\t{single}\n" for literal, half, single in rows),
            encoding="utf-8")
        source = CONSUMER.replace("__NATIVE_IMPORT__",
            "import yjson_native_primitives.*" if args.native else "")
        source = source.replace("__NATIVE_INITIALIZE__",
            "initializeYJsonNativePrimitivesV1()" if args.native else "")
        (consumer / "src" / "main.cj").write_text(source, encoding="utf-8")
        subprocess.run(["cjpm", "run"], cwd=consumer, check=True)


if __name__ == "__main__":
    main()
