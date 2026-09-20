#!/usr/bin/env python3
"""Validate fixed-work declarations emitted by Cangjie benchmarks."""
from __future__ import annotations

import re


PROTOCOL_VERSION = 1
MARKER = "YJSON_FIXED_WORK_V1"

_MARKER_RE = re.compile(
    rf"{MARKER} case=(\S+) batches=([0-9]+) batch_size=([0-9]+)"
)
_MEASUREMENT_RE = re.compile(
    r"Starting measurements of ([0-9]+) batches\. Measuring Duration\."
)
_BATCH_SIZE_RE = re.compile(
    r"Max batch size: ([0-9]+), estimated execution time: [^\r\n]+\."
)
_BENCHMARK_RE = re.compile(r"Starting the benchmark `([^`]+)`\.")
_RESULT_RE = re.compile(
    r"Summary: TOTAL: [0-9]+\s+"
    r"PASSED: ([0-9]+), SKIPPED: [0-9]+, ERROR: ([0-9]+)\s+"
    r"FAILED: ([0-9]+)",
)


def _full_line_matches(
    pattern: re.Pattern[str], text: str, label: str, needle: str
) -> list[tuple[str, ...]]:
    candidates = [line.strip() for line in text.splitlines() if needle in line]
    matches: list[tuple[str, ...]] = []
    for line in candidates:
        match = pattern.fullmatch(line)
        if match is None:
            raise ValueError(f"malformed {label}: {line!r}")
        matches.append(match.groups())
    return matches


def parse_fixed_work(text: str, case: str) -> dict[str, int]:
    """Return validated fixed work for one successful selected benchmark run."""
    if not case or any(character.isspace() for character in case):
        raise ValueError("benchmark case must be a non-empty token")

    declarations = _full_line_matches(
        _MARKER_RE, text, "fixed-work declaration", MARKER
    )
    selected_declarations = [
        declaration for declaration in declarations if declaration[0] == case
    ]
    if not selected_declarations:
        raise ValueError(f"missing {MARKER} declaration for {case}")
    if len(set(selected_declarations)) != 1:
        raise ValueError(f"conflicting fixed-work declarations for {case}")
    _, batches_text, batch_size_text = selected_declarations[0]
    batches, batch_size = int(batches_text), int(batch_size_text)
    if batches <= 0 or batch_size <= 0:
        raise ValueError(f"fixed-work counts must be positive for {case}")

    measurement_matches = _full_line_matches(
        _MEASUREMENT_RE, text, "SDK measurement-count header",
        "Starting measurements of",
    )
    if len(measurement_matches) != 1:
        raise ValueError(
            f"expected one SDK measurement-count header for {case}, found {len(measurement_matches)}"
        )
    measured_batches = int(measurement_matches[0][0])

    batch_size_matches = _full_line_matches(
        _BATCH_SIZE_RE, text, "SDK max-batch-size header", "Max batch size:"
    )
    if len(batch_size_matches) != 1:
        raise ValueError(
            f"expected one SDK max-batch-size header for {case}, found {len(batch_size_matches)}"
        )
    measured_batch_size = int(batch_size_matches[0][0])
    if measured_batches <= 0 or measured_batch_size <= 0:
        raise ValueError(f"SDK measurement counts must be positive for {case}")
    if (measured_batches, measured_batch_size) != (batches, batch_size):
        raise ValueError(
            f"SDK work for {case} is {measured_batches}x{measured_batch_size}, "
            f"declaration is {batches}x{batch_size}"
        )

    benchmark_matches = _full_line_matches(
        _BENCHMARK_RE, text, "benchmark start", "Starting the benchmark"
    )
    if len(benchmark_matches) != 1:
        raise ValueError(
            f"expected one selected benchmark start for {case}, found {len(benchmark_matches)}"
        )
    qualified_benchmark = benchmark_matches[0][0]
    method = qualified_benchmark.rsplit(".", 1)[-1]
    if method != f"{case}()":
        raise ValueError(
            f"started benchmark {qualified_benchmark!r} does not match selected case {case!r}"
        )

    results = _RESULT_RE.findall(text)
    if len(results) != 1:
        raise ValueError(
            f"expected one benchmark result summary for {case}, found {len(results)}"
        )
    passed, errors, failed = (int(value) for value in results[0])
    if (passed, errors, failed) != (1, 0, 0):
        raise ValueError(
            f"benchmark result for {case} must be PASSED 1, ERROR 0, FAILED 0; "
            f"found PASSED {passed}, ERROR {errors}, FAILED {failed}"
        )

    return {
        "batches": batches,
        "batch_size": batch_size,
        "operations": batches * batch_size,
    }
