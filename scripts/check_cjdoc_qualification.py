#!/usr/bin/env python3
"""Fail closed unless the configured cjdoc executable is fully qualified."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tomllib


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "release" / "cjdoc-tool.toml"
SHA256 = re.compile(r"[0-9a-f]{64}")
REVISION = re.compile(r"[0-9a-f]{40}")
CJC_VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
CJC_STS = re.compile(
    r"Cangjie Compiler: ([0-9]+\.[0-9]+\.[0-9]+) \(cjnative\)"
)
CJPM_VERSION = re.compile(
    r"Cangjie Project Manager: ([0-9]+\.[0-9]+\.[0-9]+)"
)
QUALIFICATION_SCHEMA = 4
BUILD_EVIDENCE_SCHEMA = "yjson.cjdoc-build/2"
# The pinned source owns the actual compile policy. Invoke its authenticated
# static-stdx launcher and STS wrapper instead of patching its manifest here.
SOURCE_BUILD_COMMAND = [
    "python3", "scripts/with_stdx.py", "--variant", "static", "--",
    "bash", "-c", "source scripts/with_sts_cjpm.sh; ulimit -s 131072; cjpm build --jobs 1",
]


class CjdocQualificationError(ValueError):
    pass


def _required_string(config: dict, name: str) -> str:
    value = config.get(name)
    if not isinstance(value, str) or not value.strip():
        raise CjdocQualificationError(f"qualified cjdoc is missing {name}")
    return value.strip()


def _required_string_array(config: dict, name: str) -> list[str]:
    value = config.get(name)
    if not isinstance(value, list) or not value or not all(
        isinstance(item, str) and item for item in value
    ):
        raise CjdocQualificationError(f"qualified cjdoc is missing {name}")
    return value


def _safe_relative(config: dict, name: str) -> pathlib.PurePosixPath:
    relative = pathlib.PurePosixPath(_required_string(config, name))
    if relative.is_absolute() or ".." in relative.parts or not relative.parts:
        raise CjdocQualificationError(f"{name} must be a safe relative path")
    return relative


def validate_toolchain_policy(config: dict, cjc_output: str, cjpm_output: str) -> str:
    """Validate one exact installed toolchain against the STS policy."""
    if config.get("cjc_channel") != "sts":
        raise CjdocQualificationError("qualified cjdoc must use the STS Cangjie channel")
    expected_cjc_version = config.get("cjc_version")
    if (
        not isinstance(expected_cjc_version, str)
        or CJC_VERSION.fullmatch(expected_cjc_version) is None
    ):
        raise CjdocQualificationError(
            "qualified cjdoc is missing a pinned STS compiler version"
        )
    cjc_lines = [line.strip() for line in cjc_output.splitlines() if line.strip()]
    cjpm_lines = [line.strip() for line in cjpm_output.splitlines() if line.strip()]
    cjc_match = CJC_STS.fullmatch(cjc_lines[0] if cjc_lines else "")
    if cjc_match is None:
        raise CjdocQualificationError("current cjc is not a complete STS version")
    if cjc_match.group(1) != expected_cjc_version:
        raise CjdocQualificationError(
            f"current cjc version {cjc_match.group(1)} does not match "
            f"the pinned STS version {expected_cjc_version}"
        )
    cjpm_match = CJPM_VERSION.fullmatch(cjpm_lines[0] if len(cjpm_lines) == 1 else "")
    if cjpm_match is None:
        raise CjdocQualificationError("current cjpm version output is invalid")
    if cjpm_match.group(1) != expected_cjc_version:
        raise CjdocQualificationError("current cjpm does not match the pinned STS version")
    resolved_version = os.environ.get("YJSON_RESOLVED_CANGJIE", "").strip()
    if resolved_version and resolved_version != expected_cjc_version:
        raise CjdocQualificationError(
            f"resolved Cangjie version {resolved_version} does not match "
            f"the pinned STS version {expected_cjc_version}"
        )
    return cjc_match.group(1)


def validate_source_config(config: dict) -> None:
    """Validate the source and build policy before downloading or executing it."""
    if config.get("schema_version") != QUALIFICATION_SCHEMA:
        raise CjdocQualificationError("unsupported cjdoc qualification schema_version")
    if config.get("status") != "qualified":
        reason = config.get("reason", "qualification record is not complete")
        raise CjdocQualificationError(f"cjdoc is not qualified: {reason}")
    if config.get("distribution") != "source":
        raise CjdocQualificationError("qualified cjdoc distribution must be source")

    platform = _required_string(config, "platform")
    if platform != "linux-x86_64":
        raise CjdocQualificationError("canonical cjdoc platform must be linux-x86_64")
    for field in ("source_url", "source_archive_url", "license_url", "manual_url"):
        if not _required_string(config, field).startswith("https://"):
            raise CjdocQualificationError(f"{field} must use https")
    revision = _required_string(config, "source_revision")
    if REVISION.fullmatch(revision) is None:
        raise CjdocQualificationError("source_revision must be a lowercase Git commit")
    for field in ("source_url", "source_archive_url", "license_url", "manual_url"):
        if revision not in _required_string(config, field):
            raise CjdocQualificationError(f"{field} must pin source_revision")
    if _required_string(config, "source_directory") != f"cjdoc-{revision}":
        raise CjdocQualificationError("source_directory must identify the pinned archive root")
    _safe_relative(config, "binary_path")
    build_command = _required_string_array(config, "build_command")
    if build_command != SOURCE_BUILD_COMMAND:
        raise CjdocQualificationError("build_command must use the source STS/static-stdx launcher")
    options = _required_string_array(config, "compile_options")
    if any(any(character.isspace() for character in option) for option in options):
        raise CjdocQualificationError("compile_options must contain individual argument tokens")
    if config.get("stdx_variant") != "static":
        raise CjdocQualificationError("qualified cjdoc must use static stdx")
    for field in ("cjc_sha256", "cjpm_sha256", "stdx_sha256", "build_policy_sha256", "build_wrapper_sha256"):
        if SHA256.fullmatch(_required_string(config, field)) is None:
            raise CjdocQualificationError(f"{field} must be a lowercase SHA-256 digest")
    _required_string(config, "license_spdx")
    _required_string(config, "version")
    _required_string(config, "version_output")
    _required_string_array(config, "version_args")
    expected_archive_sha = _required_string(config, "source_archive_sha256")
    if SHA256.fullmatch(expected_archive_sha) is None:
        raise CjdocQualificationError(
            "source_archive_sha256 must be a lowercase SHA-256 digest")
    if config.get("cjc_channel") != "sts":
        raise CjdocQualificationError("qualified cjdoc must use the STS Cangjie channel")


def installed_toolchain_environment() -> dict[str, str]:
    """Unwrap an inherited cjdoc launcher using the SDK selected by cjc."""
    environment = os.environ.copy()
    wrapper = environment.get("CJDOC_STS_WRAPPER_CJPM")
    located = shutil.which("cjpm") if wrapper else None
    if not located or pathlib.Path(located).resolve() != pathlib.Path(wrapper).resolve():
        return environment
    compiler = shutil.which("cjc")
    if compiler is None:
        raise CjdocQualificationError("cannot locate current cjc")
    compiler_path = pathlib.Path(compiler).resolve()
    sdk_root = compiler_path.parent.parent
    manager = next((path for path in (sdk_root / "tools/bin/cjpm", sdk_root / "bin/cjpm")
                    if path.is_file() and os.access(path, os.X_OK)), None)
    if manager is None:
        raise CjdocQualificationError("selected cjc SDK has no executable cjpm")
    wrapper_directory = pathlib.Path(located).resolve().parent
    remaining = [entry for entry in environment.get("PATH", "").split(os.pathsep)
                 if pathlib.Path(entry or ".").resolve() != wrapper_directory]
    environment["PATH"] = os.pathsep.join([str(compiler_path.parent), str(manager.parent), *remaining])
    return environment


def toolchain_binary_sha256(*, environment: dict[str, str] | None = None) -> dict[str, str]:
    """Hash the actual executables on PATH; equal version strings are insufficient."""
    result = {}
    for command in ("cjc", "cjpm"):
        executable = shutil.which(command, path=None if environment is None else environment.get("PATH"))
        if executable is None:
            raise CjdocQualificationError(f"cannot locate current {command}")
        result[command] = hashlib.sha256(pathlib.Path(executable).read_bytes()).hexdigest()
    return result


def validate_product_invocation(record: object, config: dict, binary: pathlib.Path) -> None:
    """Accept only the successful root product build recorded by the source wrapper."""
    if not isinstance(record, dict) or (
        record.get("schemaVersion") != "cjdoc.sts-invocation/1"
        or record.get("package") != "cjdoc"
        or record.get("phase") != "product-build"
        or record.get("argv") != ["build", "--jobs", "1"]
        or record.get("exitCode") != 0
        or not isinstance(record.get("reason"), str)
        or not record["reason"]
    ):
        raise CjdocQualificationError("cjdoc product build invocation is missing or invalid")
    try:
        actual_options = shlex.split(record.get("option", ""))
    except (TypeError, ValueError) as error:
        raise CjdocQualificationError("cjdoc product compile options are invalid") from error
    if actual_options != config["compile_options"]:
        raise CjdocQualificationError("cjdoc product compileOptions mismatch")
    for field, expected in (("policySha256", config["build_policy_sha256"]),
                            ("wrapperSha256", config["build_wrapper_sha256"])):
        if record.get(field) != expected:
            raise CjdocQualificationError(f"cjdoc product {field} mismatch")
    expected_binary = {
        "sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "size": binary.stat().st_size,
    }
    if record.get("binary") != expected_binary:
        raise CjdocQualificationError("cjdoc product build binary mismatch")


def validate_qualification(
    config_path: pathlib.Path = DEFAULT_CONFIG,
    *,
    root: pathlib.Path = ROOT,
    binary_override: pathlib.Path | None = None,
) -> tuple[pathlib.Path, str]:
    config_bytes = config_path.read_bytes()
    config = tomllib.loads(config_bytes.decode("utf-8"))
    validate_source_config(config)
    revision = config["source_revision"]
    expected_archive_sha = config["source_archive_sha256"]
    expected_version = config["version_output"]
    if binary_override is None:
        environment_binary = os.environ.get("YJSON_CJDOC_BINARY", "").strip()
        if not environment_binary:
            raise CjdocQualificationError(
                "source-qualified cjdoc requires --binary or YJSON_CJDOC_BINARY")
        binary = pathlib.Path(environment_binary).resolve()
    else:
        binary = binary_override.resolve()
    if binary.is_symlink() or not binary.is_file():
        raise CjdocQualificationError(f"qualified cjdoc binary is missing: {binary}")
    if not os.access(binary, os.X_OK):
        raise CjdocQualificationError(f"qualified cjdoc binary is not executable: {binary}")
    actual_sha = hashlib.sha256(binary.read_bytes()).hexdigest()
    evidence_path = binary.parent / "qualification.json"
    if evidence_path.is_symlink() or not evidence_path.is_file():
        raise CjdocQualificationError(
            f"cjdoc build evidence is missing: {evidence_path}")
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    expected_config_sha = hashlib.sha256(config_bytes).hexdigest()
    expected_evidence = {
        "schemaVersion": BUILD_EVIDENCE_SCHEMA,
        "configSha256": expected_config_sha,
        "sourceRevision": revision,
        "sourceArchiveSha256": expected_archive_sha,
        "binarySha256": actual_sha,
        "buildCommand": config["build_command"],
        "compileOptions": config["compile_options"],
        "toolchainBinarySha256": {
            "cjc": config["cjc_sha256"], "cjpm": config["cjpm_sha256"],
        },
        "stdxVariant": config["stdx_variant"],
        "stdxSha256": config["stdx_sha256"],
        "buildPolicySha256": config["build_policy_sha256"],
        "buildWrapperSha256": config["build_wrapper_sha256"],
    }
    for name, expected in expected_evidence.items():
        if evidence.get(name) != expected:
            raise CjdocQualificationError(
                f"cjdoc build evidence {name} mismatch")
    validate_product_invocation(evidence.get("productInvocation"), config, binary)
    evidence_cjc = str(evidence.get("cjcVersion", ""))
    evidence_cjpm = str(evidence.get("cjpmVersion", ""))
    validate_toolchain_policy(config, evidence_cjc, evidence_cjpm)

    environment = installed_toolchain_environment()
    current_cjc = subprocess.run(
        ["cjc", "-v"], text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=30, check=False, env=environment)
    current_cjpm = subprocess.run(
        ["cjpm", "--version"], text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=30, check=False, env=environment)
    if current_cjc.returncode != 0 or current_cjpm.returncode != 0:
        raise CjdocQualificationError("cannot query the current Cangjie toolchain")
    validate_toolchain_policy(config, current_cjc.stdout.strip(), current_cjpm.stdout.strip())
    if evidence.get("cjcVersion") != current_cjc.stdout.strip():
        raise CjdocQualificationError("cjdoc was built with a different cjc")
    if evidence.get("cjpmVersion") != current_cjpm.stdout.strip():
        raise CjdocQualificationError(
            "cjdoc was built with a different cjpm")
    if toolchain_binary_sha256(environment=environment) != expected_evidence["toolchainBinarySha256"]:
        raise CjdocQualificationError("current Cangjie toolchain binary SHA-256 mismatch")

    version_args = _required_string_array(config, "version_args")
    result = subprocess.run(
        [str(binary), *version_args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=30,
        check=False,
    )
    output = result.stdout.strip()
    if result.returncode != 0:
        raise CjdocQualificationError(
            f"cjdoc version command failed with exit {result.returncode}: {output}")
    if expected_version not in output:
        raise CjdocQualificationError(
            f"cjdoc version mismatch: expected output containing {expected_version!r}")
    return binary, actual_sha


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=pathlib.Path, default=DEFAULT_CONFIG)
    parser.add_argument("--binary", type=pathlib.Path)
    args = parser.parse_args()
    try:
        binary, digest = validate_qualification(
            args.config.resolve(),
            binary_override=args.binary.resolve() if args.binary else None,
        )
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"cjdoc qualification error: {error}", file=sys.stderr)
        return 1
    print(f"cjdoc qualification passed binary={binary} sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
