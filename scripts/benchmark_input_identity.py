#!/usr/bin/env python3
"""Compute canonical source identities for benchmark inputs."""

from __future__ import annotations

import hashlib
import os
import pathlib


STANDALONE_MACRO_GIT = (
    'git = "https://github.com/lIlIIlIll/yjson_macros.git", '
    'commitId = "5961c2f448f989fb23a9731265ce025aad8bffaf"'
)
PREVIOUS_STANDALONE_MACRO_GIT = (
    'git = "https://github.com/lIlIIlIll/yjson_macros.git", '
    'commitId = "fec0adce41f73d037d876cbac7a28aee8108bb5c"'
)
LEGACY_STANDALONE_MACRO_GIT = (
    'git = "https://github.com/lIlIIlIll/yjson_macros.git", '
    'commitId = "30c3def793054c4b5ba25be2e22598e141923a51"'
)
STANDALONE_MACRO_GITS = (
    STANDALONE_MACRO_GIT,
    (
        'git = "https://github.com/lIlIIlIll/yjson_macros.git", '
        'commitId = "eb94e226b9d6d5c54c8418bfdaf515dcc819e5a9"'
    ),
    (
        'git = "https://github.com/lIlIIlIll/yjson_macros.git", '
        'commitId = "3fbdb063ffc6978be01294d3bbb0b03941fe1f02"'
    ),
    PREVIOUS_STANDALONE_MACRO_GIT,
    LEGACY_STANDALONE_MACRO_GIT,
)
STANDALONE_MACRO_DESCRIPTION = 'description = "AST codec and JSON literal macros for yjson"'

HISTORICAL_MACRO_MANIFEST = """[package]
  cjc-version = "1.1.0"
  name = "yjson_macros"
  organization = ""
  description = "AST codec macros for yjson"
  version = "0.1.0"
  target-dir = ""
  script-dir = ""
  output-type = "static"
  compile-option = ""
  override-compile-option = ""
  link-option = ""
  package-configuration = {}

[dependencies]
# Generated code is coupled to the matching versioned yjson runtime contract.
yjson = { path = "../.." }
""".encode("utf-8")
HISTORICAL_MACRO_RELEASE_MANIFEST = """[package]
cjc-version = "1.1.0"
name = "yjson_macros"
description = "AST codec macros for yjson"
version = "0.1.0"
output-type = "static"

[dependencies]
# Generated code is coupled to the matching versioned yjson runtime contract.
yjson = "0.1.0"
""".encode("utf-8")


def manifest_digest(manifest: dict[str, str]) -> str:
    digest = hashlib.sha256()
    for name, value in sorted(manifest.items()):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(value.encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def contains_standalone_macro_git(text: str) -> bool:
    return any(marker in text for marker in STANDALONE_MACRO_GITS)


def canonical_benchmark_input_bytes(
    root: pathlib.Path, relative: str, data: bytes
) -> bytes:
    """Normalize the standalone macro move without hiding benchmark code drift."""
    if relative == "packages/yjson_macros/src/json_literal.cj":
        raise ValueError("JSON literal macro is outside the typed-codec benchmark closure")

    if relative == "packages/yjson_macros/cjpm.toml" and (
        STANDALONE_MACRO_DESCRIPTION in data.decode()
    ):
        return HISTORICAL_MACRO_MANIFEST
    if relative == "release/package-manifests/yjson_macros.toml" and (
        STANDALONE_MACRO_DESCRIPTION in data.decode()
    ):
        return HISTORICAL_MACRO_RELEASE_MANIFEST

    text = data.decode("utf-8")
    if relative.endswith(".lock"):
        text = "\n".join(
            line
            for line in text.splitlines()
            if not contains_standalone_macro_git(line)
        ) + "\n"
    elif contains_standalone_macro_git(text):
        dependency_path = os.path.relpath(
            root / "packages/yjson_macros", (root / relative).parent
        )
        normalized_lines: list[str] = []
        for line in text.splitlines():
            if "yjson_macros" not in line or not contains_standalone_macro_git(line):
                normalized_lines.append(line)
                continue
            opening = line.find("{")
            closing = line.rfind("}")
            if opening < 0 or closing <= opening:
                normalized_lines.append(line)
                continue
            body = line[opening + 1 : closing]
            output_type = (
                ', output-type = "static"'
                if 'output-type = "static"' in body
                else ""
            )
            normalized_lines.append(
                line[: opening + 1]
                + f' path = "{dependency_path}"{output_type} '
                + line[closing:]
            )
        text = "\n".join(normalized_lines) + "\n"

    if relative == "release/release-graph.toml":
        macro_manifest = root / "packages/yjson_macros/cjpm.toml"
        standalone_macro = contains_standalone_macro_git(
            (root / "cjpm.toml").read_text(encoding="utf-8")
        ) or (
            macro_manifest.is_file()
            and STANDALONE_MACRO_DESCRIPTION in macro_manifest.read_text(encoding="utf-8")
        )
        if standalone_macro:
            text = text.replace(
                'name = "yjson_macros"\n'
                'role = "macros"\n'
                'development_manifest = "packages/yjson_macros/cjpm.toml"\n'
                'release_manifest = "release/package-manifests/yjson_macros.toml"\n'
                'source_root = "packages/yjson_macros/src"\n'
                'stage_kind = "package"\n'
                "stability = \"stable\"\n"
                "leaf_bundle = false\n"
                "dependencies = []",
                'name = "yjson_macros"\n'
                'role = "macros"\n'
                'development_manifest = "packages/yjson_macros/cjpm.toml"\n'
                'release_manifest = "release/package-manifests/yjson_macros.toml"\n'
                'source_root = "packages/yjson_macros/src"\n'
                'stage_kind = "package"\n'
                "stability = \"stable\"\n"
                "leaf_bundle = false\n"
                'dependencies = ["yjson"]',
            )
    return text.encode("utf-8")


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
    paths = [
        root / "cjpm.toml",
        root / "cjpm.lock",
        package / "cjpm.toml",
        package / "cjpm.lock",
        package / "build.cj",
        root / "packages/yjson_macros/cjpm.toml",
        root / "packages/yjson_macros/cjpm.lock",
        root / "scripts/build_native_scanner.py",
        root / "scripts/benchmark_fixed_work.py",
        root / "scripts/benchmark_pure_direct.py",
        root / "scripts/json_pure_perf_compare.py",
        root / "benchmarks/full-seven-library/run_full.py",
        root / "native/yjson_scanner.c",
        root / "native/yjson_writer_format.c",
        root / "native/yjson_scanner.h",
        root / "native/yjson_compact.c",
        root / "native/yjson_compact.h",
        *sorted((package / "src").rglob("*.cj")),
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
