#!/usr/bin/env python3
"""Compute canonical source identities for benchmark inputs."""

from __future__ import annotations

import hashlib
import pathlib


def manifest_digest(manifest: dict[str, str]) -> str:
    digest = hashlib.sha256()
    for name, value in sorted(manifest.items()):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(value.encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def canonical_benchmark_input_bytes(
    root: pathlib.Path, relative: str, data: bytes
) -> bytes:
    """Bind the actual input bytes, including SDK, version, and dependency pins.

    Historical standalone-macro migration mappings are intentionally retired.
    An isolated Pure comparison must stage identical dependency declarations
    explicitly; the production candidate retains its real Git pin and lock.
    """
    if relative == "packages/yjson_macros/src/json_literal.cj":
        raise ValueError("JSON literal macro is outside the typed-codec benchmark closure")
    data.decode("utf-8")
    return data


def files_manifest(
    root: pathlib.Path, paths: list[pathlib.Path]
) -> dict[str, str]:
    result: dict[str, str] = {}
    for path in sorted(set(paths)):
        if not path.is_file():
            raise SystemExit(f"benchmark input file not found: {path}")
        relative = str(path.relative_to(root))
        try:
            data = canonical_benchmark_input_bytes(root, relative, path.read_bytes())
        except (UnicodeDecodeError, ValueError) as error:
            raise SystemExit(f"invalid benchmark input file: {path}: {error}") from error
        result[relative] = hashlib.sha256(data).hexdigest()
    return result


def harness_manifest(root: pathlib.Path) -> dict[str, str]:
    package = root / "packages/benchmarks"
    algorithms = root / "packages/yjson_algorithms"
    paths = [
        root / "cjpm.toml",
        root / "cjpm.lock",
        package / "cjpm.toml",
        package / "cjpm.lock",
        package / "build.cj",
        root / "packages/yjson_macros/cjpm.toml",
        root / "packages/yjson_macros/cjpm.lock",
        algorithms / "cjpm.toml",
        algorithms / "cjpm.lock",
        root / "scripts/build_native_scanner.py",
        root / "scripts/benchmark_input_identity.py",
        root / "scripts/benchmark_fixed_work.py",
        root / "scripts/benchmark_pure_direct.py",
        root / "scripts/json_pure_perf_compare.py",
        root / "benchmarks/full-seven-library/run_full.py",
        root / "benchmarks/full-seven-library/summarize_full.py",
        root / "native/yjson_scanner.c",
        root / "native/yjson_writer_format.c",
        root / "native/yjson_float_format.c",
        root / "native/vendor/yyjson/yyjson.c",
        root / "native/vendor/yyjson/yyjson.h",
        root / "native/yjson_scanner.h",
        root / "native/yjson_compact.c",
        root / "native/yjson_compact.h",
        *sorted((package / "src").rglob("*.cj")),
        *sorted((algorithms / "src").rglob("*.cj")),
    ]
    return files_manifest(root, paths)


def product_manifest(root: pathlib.Path) -> dict[str, str]:
    # The seven-library matrix exercises generated typed codecs, not the
    # independent JSON literal macro. Keep this evidence scoped to its input
    # closure so adding that API does not invalidate unrelated measurements.
    paths = [
        *sorted((root / "src").rglob("*.cj")),
        *sorted(
            path
            for path in (root / "packages/yjson_macros/src").rglob("*.cj")
            if path.name != "json_literal.cj"
        ),
    ]
    return files_manifest(root, paths)
