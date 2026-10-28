#!/usr/bin/env python3
"""Tests for the fail-closed cjdoc qualification record."""

from __future__ import annotations

import hashlib
import json
import pathlib
import subprocess
import tempfile
import textwrap
import unittest
from unittest import mock

from check_cjdoc_qualification import (
    CjdocQualificationError, SOURCE_BUILD_COMMAND, validate_qualification,
)


class CjdocQualificationTest(unittest.TestCase):
    BINARY_SHA256 = {"cjc": "b" * 64, "cjpm": "c" * 64}
    COMPILE_OPTIONS = ["-O2", "--fno-chir-function-inlining"]
    POLICY_SOURCE = b"# fixture compile policy\n"
    WRAPPER_SOURCE = b"# fixture source wrapper\n"
    POLICY_SHA256 = hashlib.sha256(POLICY_SOURCE).hexdigest()
    WRAPPER_SHA256 = hashlib.sha256(WRAPPER_SOURCE).hexdigest()
    CJC_VERSION = (
        "Cangjie Compiler: 1.2.0 (cjnative)\n"
        "Target: x86_64-unknown-linux-gnu"
    )
    CJPM_VERSION = "Cangjie Project Manager: 1.2.0"

    def setUp(self) -> None:
        patcher = mock.patch("check_cjdoc_qualification.toolchain_binary_sha256",
                             return_value=self.BINARY_SHA256)
        patcher.start()
        self.addCleanup(patcher.stop)

    def qualified_fixture(self, root: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path]:
        binary = root / ".ci" / "tools" / "cjdoc"
        binary.parent.mkdir(parents=True)
        binary.write_text(
            "#!/bin/sh\nprintf '%s\\n' 'cjdoc 0.7.5'\n",
            encoding="utf-8",
        )
        binary.chmod(0o755)
        revision = "0123456789abcdef0123456789abcdef01234567"
        archive_digest = "a" * 64
        config = root / "cjdoc-tool.toml"
        config.write_text(textwrap.dedent(f'''
            schema_version = 4
            status = "qualified"
            distribution = "source"
            platform = "linux-x86_64"

            version = "0.7.5"
            version_output = "cjdoc 0.7.5"
            version_args = ["--version"]

            source_url = "https://example.invalid/cjdoc/tree/{revision}"
            source_archive_url = "https://example.invalid/cjdoc/archive/{revision}.tar.gz"
            source_archive_sha256 = "{archive_digest}"
            source_revision = "{revision}"
            source_directory = "cjdoc-{revision}"
            binary_path = "target/release/bin/main"
            build_command = {json.dumps(SOURCE_BUILD_COMMAND)}
            compile_options = {json.dumps(self.COMPILE_OPTIONS)}
            stdx_variant = "static"
            stdx_sha256 = "{'d' * 64}"
            cjc_sha256 = "{self.BINARY_SHA256['cjc']}"
            cjpm_sha256 = "{self.BINARY_SHA256['cjpm']}"
            build_policy_sha256 = "{self.POLICY_SHA256}"
            build_wrapper_sha256 = "{self.WRAPPER_SHA256}"

            cjc_channel = "sts"
            cjc_version = "1.2.0"

            license_spdx = "MIT"
            license_url = "https://example.invalid/cjdoc/blob/{revision}/LICENSE"
            manual_url = "https://example.invalid/cjdoc/blob/{revision}/README.md"
        '''), encoding="utf-8")
        evidence = {
            "schemaVersion": "yjson.cjdoc-build/2",
            "configSha256": hashlib.sha256(config.read_bytes()).hexdigest(),
            "sourceRevision": revision,
            "sourceArchiveSha256": archive_digest,
            "binarySha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
            "cjcVersion": self.CJC_VERSION,
            "cjpmVersion": self.CJPM_VERSION,
            "buildCommand": SOURCE_BUILD_COMMAND,
            "compileOptions": self.COMPILE_OPTIONS,
            "toolchainBinarySha256": self.BINARY_SHA256,
            "stdxVariant": "static",
            "stdxSha256": "d" * 64,
            "buildPolicySha256": self.POLICY_SHA256,
            "buildWrapperSha256": self.WRAPPER_SHA256,
            "productInvocation": {
                "schemaVersion": "cjdoc.sts-invocation/1", "package": "cjdoc",
                "option": " ".join(self.COMPILE_OPTIONS), "phase": "product-build",
                "reason": "release-product-optimization", "exitCode": 0, "argv": ["build", "--jobs", "1"],
                "policySha256": self.POLICY_SHA256, "wrapperSha256": self.WRAPPER_SHA256,
                "binary": {"sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
                           "size": binary.stat().st_size},
            },
        }
        (binary.parent / "qualification.json").write_text(
            json.dumps(evidence), encoding="utf-8")
        return config, binary

    def qualified_commands(
        self, arguments: list[str], **_: object
    ) -> subprocess.CompletedProcess[str]:
        if arguments[0] == "cjc":
            output = self.CJC_VERSION
        elif arguments[0] == "cjpm":
            output = self.CJPM_VERSION
        else:
            output = "cjdoc 0.7.5"
        return subprocess.CompletedProcess(arguments, 0, stdout=output)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_accepts_pinned_executable(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            actual_binary, digest = validate_qualification(
                config, root=root, binary_override=binary)
            self.assertEqual(actual_binary, binary)
            self.assertEqual(digest, hashlib.sha256(binary.read_bytes()).hexdigest())

    def test_rejects_unqualified_record(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = pathlib.Path(directory) / "cjdoc-tool.toml"
            config.write_text(
                'schema_version = 4\nstatus = "unqualified"\nreason = "missing tool"\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(CjdocQualificationError, "missing tool"):
                validate_qualification(config, root=pathlib.Path(directory))

    def test_rejects_checksum_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            binary.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            binary.chmod(0o755)
            with self.assertRaisesRegex(CjdocQualificationError, "binarySha256 mismatch"):
                validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_build_command_evidence_drift(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            evidence_path = binary.parent / "qualification.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["buildCommand"] = ["cjpm", "test"]
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            with self.assertRaisesRegex(CjdocQualificationError, "buildCommand mismatch"):
                validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_compile_option_evidence_drift(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            evidence_path = binary.parent / "qualification.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["compileOptions"] = ["-O1"]
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            with self.assertRaisesRegex(CjdocQualificationError, "compileOptions mismatch"):
                validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_product_invocation_drift(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        for update, message in (
            ({"phase": "unit-test"}, "invocation"),
            ({"argv": ["test"]}, "invocation"),
            ({"exitCode": 1}, "invocation"),
            ({"option": "-O1"}, "compileOptions mismatch"),
            ({"policySha256": "e" * 64}, "policySha256 mismatch"),
            ({"wrapperSha256": "e" * 64}, "wrapperSha256 mismatch"),
            ({"binary": {"sha256": "f" * 64, "size": 1}}, "binary mismatch"),
        ):
            with self.subTest(update=update), tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                config, binary = self.qualified_fixture(root)
                evidence_path = binary.parent / "qualification.json"
                evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
                evidence["productInvocation"].update(update)
                evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
                with self.assertRaisesRegex(CjdocQualificationError, message):
                    validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_same_version_different_compiler_binary(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            with mock.patch("check_cjdoc_qualification.toolchain_binary_sha256",
                            return_value={"cjc": "e" * 64, "cjpm": "c" * 64}):
                with self.assertRaisesRegex(CjdocQualificationError, "toolchain binary"):
                    validate_qualification(config, root=root, binary_override=binary)

    def test_rejects_legacy_build_evidence_schema(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            evidence_path = binary.parent / "qualification.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["schemaVersion"] = "yjson.cjdoc-build/1"
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            with self.assertRaisesRegex(CjdocQualificationError, "schemaVersion mismatch"):
                validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_different_sts_version(self, run: mock.Mock) -> None:
        self.CJC_VERSION = (
            "Cangjie Compiler: 1.1.1 (cjnative)\n"
            "Target: x86_64-unknown-linux-gnu"
        )
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            with self.assertRaisesRegex(CjdocQualificationError, "pinned STS version"):
                validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_resolved_version_mismatch(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            with mock.patch.dict(
                "os.environ", {"YJSON_RESOLVED_CANGJIE": "1.1.1"}
            ):
                with self.assertRaisesRegex(CjdocQualificationError, "pinned STS version"):
                    validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_non_sts_compiler(self, run: mock.Mock) -> None:
        self.CJC_VERSION = "Cangjie Compiler: 1.2.0-alpha.20260829040003 (cjnative)"
        run.side_effect = self.qualified_commands
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, binary = self.qualified_fixture(root)
            with self.assertRaisesRegex(CjdocQualificationError, "complete STS version"):
                validate_qualification(config, root=root, binary_override=binary)

    @mock.patch("check_cjdoc_qualification.subprocess.run")
    def test_rejects_old_or_daily_project_manager(self, run: mock.Mock) -> None:
        run.side_effect = self.qualified_commands
        for version in ("1.1.3", "1.2.0-alpha.20261026040003"):
            with self.subTest(version=version), tempfile.TemporaryDirectory() as directory:
                self.CJPM_VERSION = "Cangjie Project Manager: " + version
                root = pathlib.Path(directory)
                config, binary = self.qualified_fixture(root)
                with self.assertRaises(CjdocQualificationError):
                    validate_qualification(config, root=root, binary_override=binary)



if __name__ == "__main__":
    unittest.main()
