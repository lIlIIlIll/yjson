#!/usr/bin/env python3
"""Validate the exact Cangjie STS version used by hosted CI."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tomllib


VERSION_PATTERN = r"\d+\.\d+\.\d+"
VERSION_RE = re.compile(rf"^{VERSION_PATTERN}$")
ROOT = pathlib.Path(__file__).resolve().parents[1]
QUALIFICATION_CONFIG = ROOT / "release" / "cjdoc-tool.toml"
CJC_STS = re.compile(rf"Cangjie Compiler: ({VERSION_PATTERN}) \(cjnative\)")
CJPM_STS = re.compile(rf"Cangjie Project Manager: ({VERSION_PATTERN})")


def pinned_sts_version() -> str:
    """Read the single STS version accepted by release qualification."""

    try:
        config = tomllib.loads(QUALIFICATION_CONFIG.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise ValueError(f"cannot read STS qualification pin: {error}") from error
    version = config.get("cjc_version")
    if not isinstance(version, str) or VERSION_RE.fullmatch(version) is None:
        raise ValueError("STS qualification pin must be a complete semantic version")
    return version


def validate_version(version: str) -> str:
    """Return the exact STS version accepted by release qualification."""

    if VERSION_RE.fullmatch(version) is None:
        raise ValueError("STS version must match <major>.<minor>.<patch>")
    expected = pinned_sts_version()
    if version != expected:
        raise ValueError(f"STS version is pinned to {expected}")
    return version


def validate_installed_outputs(cjc_output: str, cjpm_output: str) -> str:
    """Reject nightly builds and stale tools even outside hosted CI."""
    cjc_lines = [line.strip() for line in cjc_output.splitlines() if line.strip()]
    cjpm_lines = [line.strip() for line in cjpm_output.splitlines() if line.strip()]
    compiler = CJC_STS.fullmatch(cjc_lines[0] if cjc_lines else "")
    if compiler is None:
        raise ValueError("current cjc is not a complete STS version")
    version = validate_version(compiler.group(1))
    manager = CJPM_STS.fullmatch(cjpm_lines[0] if len(cjpm_lines) == 1 else "")
    if manager is None:
        raise ValueError("current cjpm is not a complete STS version")
    validate_version(manager.group(1))
    resolved = os.environ.get("YJSON_RESOLVED_CANGJIE", "").strip()
    if resolved:
        validate_version(resolved)
    return version


def check_installed() -> tuple[str, str, str]:
    outputs = []
    for command in (["cjc", "-v"], ["cjpm", "--version"]):
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=30, check=False)
        if result.returncode != 0:
            raise ValueError(f"cannot query {command[0]}: exit {result.returncode}")
        outputs.append(result.stdout.strip())
    return validate_installed_outputs(*outputs), *outputs


def installation_record(version: str, cjc_output: str, cjpm_output: str) -> dict:
    """Record cjv's real archive receipt and installed executables, without paths."""
    binaries = {}
    compiler_path = None
    for command in ("cjc", "cjpm"):
        resolved = shutil.which(command)
        if resolved is None:
            raise ValueError(f"{command} is unavailable")
        path = pathlib.Path(resolved).resolve()
        if command == "cjc":
            compiler_path = path
        binaries[command] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert compiler_path is not None
    candidates = [parent / ".cjv/toolchain.toml" for parent in compiler_path.parents]
    receipt = next((path for path in candidates if path.is_file()), None)
    if receipt is None:
        raise ValueError("cjv SDK installation receipt is missing")
    raw_receipt = receipt.read_bytes()
    metadata = tomllib.loads(raw_receipt.decode("utf-8"))
    release = metadata.get("release", "")
    if not isinstance(release, str) or re.fullmatch(
        rf"sts-{re.escape(version)}(?:-[A-Za-z0-9_]+)*", release
    ) is None:
        raise ValueError("cjv SDK receipt does not identify the pinned STS release")
    archive_sha = metadata.get("sha256", "")
    if not isinstance(archive_sha, str) or re.fullmatch(r"[0-9a-f]{64}", archive_sha) is None:
        raise ValueError("cjv SDK receipt has no valid archive SHA-256")
    component = receipt.parent / "components/manifest-stdx"
    if not component.is_file() or not component.read_bytes().strip():
        raise ValueError("cjv stdx installation manifest is missing or empty")
    return {
        "schemaVersion": "yjson.cangjie-installation/1",
        "version": version,
        "cjcVersion": cjc_output,
        "cjpmVersion": cjpm_output,
        "sdkRelease": release,
        "sdkTuple": metadata.get("tuple"),
        "sdkArchiveSha256": archive_sha,
        "sdkReceiptSha256": hashlib.sha256(raw_receipt).hexdigest(),
        "stdxManifestSha256": hashlib.sha256(component.read_bytes()).hexdigest(),
        "binarySha256": binaries,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument(
        "--validate-version",
        metavar="VERSION",
        help="validate one exact STS version without network access",
    )
    action.add_argument("--print-pinned-version", action="store_true")
    action.add_argument("--check-installed", action="store_true")
    parser.add_argument("--record-installation", type=pathlib.Path,
                        help="write a path-free cjv SDK installation record")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        if args.record_installation and not args.check_installed:
            raise ValueError("--record-installation requires --check-installed")
        if args.check_installed:
            version, cjc_output, cjpm_output = check_installed()
            if args.record_installation:
                record = installation_record(version, cjc_output, cjpm_output)
                args.record_installation.parent.mkdir(parents=True, exist_ok=True)
                args.record_installation.write_text(
                    json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(version)
        elif args.print_pinned_version:
            print(pinned_sts_version())
        else:
            print(validate_version(args.validate_version))
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"yjson: invalid Cangjie STS version: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
