#!/usr/bin/env python3
"""Exercise source-build routing, observed flags, SDK binding, and cache reuse.

The archived source and build process below are deterministic fixtures. The
release qualification separately builds the real pinned upstream archive.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import os
import shutil
import subprocess
import tarfile
import tempfile
import tomllib
import unittest
from unittest import mock
import sys

from check_cjdoc_qualification import (
    CjdocQualificationError, SOURCE_BUILD_COMMAND, toolchain_binary_sha256,
)
from prepare_cjdoc import CjdocPrepareError, prepare, source_build_environment
import test_check_cjdoc_qualification as qualification_fixture


class PrepareCjdocTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.fixture = qualification_fixture.CjdocQualificationTest()
        self.config_path, _ = self.fixture.qualified_fixture(self.root)
        self.config = tomllib.loads(self.config_path.read_text(encoding="utf-8"))
        source = self.root / self.config["source_directory"]
        source.mkdir()
        self.original_manifest = '[package]\nname = "cjdoc"\noverride-compile-option = ""\n'
        (source / "cjpm.toml").write_text(self.original_manifest, encoding="utf-8")
        (source / "scripts").mkdir()
        (source / "scripts/sts_compile_override.py").write_bytes(self.fixture.POLICY_SOURCE)
        (source / "scripts/with_sts_cjpm.sh").write_bytes(self.fixture.WRAPPER_SOURCE)
        self.archive = self.root / "source.tar.gz"
        with tarfile.open(self.archive, "w:gz") as archive:
            archive.add(source, arcname=source.name)
        text = self.config_path.read_text(encoding="utf-8").replace(
            self.config["source_archive_sha256"], hashlib.sha256(self.archive.read_bytes()).hexdigest())
        self.config_path.write_text(text, encoding="utf-8")
        self.cache = self.root / "cache"
        self.build_count = 0
        self.source_option = " ".join(self.fixture.COMPILE_OPTIONS)
        self.stdx_digest = "d" * 64
        self.build_option = self.source_option
        self.build_status = 0
        self.record_build = True
        self.mutate_build_source = False
        patches = (
            mock.patch("prepare_cjdoc.command_output", side_effect=self.command_output),
            mock.patch("prepare_cjdoc.subprocess.run", side_effect=self.run_command),
            mock.patch("prepare_cjdoc.toolchain_binary_sha256", return_value=self.fixture.BINARY_SHA256),
            mock.patch("check_cjdoc_qualification.toolchain_binary_sha256", return_value=self.fixture.BINARY_SHA256),
            mock.patch("prepare_cjdoc.shutil.which", return_value=str(self.root / "sdk/bin/cjc")),
        )
        for patcher in patches:
            patcher.start()
            self.addCleanup(patcher.stop)

    def command_output(self, argv: list[str], **_: object) -> str:
        if argv == ["cjc", "-v"]:
            return self.fixture.CJC_VERSION
        if argv == ["cjpm", "--version"]:
            return self.fixture.CJPM_VERSION
        if "scripts/sts_compile_override.py" in argv:
            return self.source_option
        if "scripts/with_stdx.py" in argv:
            return "CJDOC_STDX_VARIANT=static\nCJDOC_STDX_DIGEST=" + self.stdx_digest
        return "cjdoc 0.7.5"

    def run_command(self, argv: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        if argv != SOURCE_BUILD_COMMAND:
            return subprocess.CompletedProcess(argv, 0, stdout=self.command_output(argv))
        self.build_count += 1
        source = pathlib.Path(kwargs["cwd"])
        environment = kwargs["env"]
        # yjson must leave the manifest alone and invoke the upstream wrapper.
        self.assertEqual((source / "cjpm.toml").read_text(encoding="utf-8"), self.original_manifest)
        self.assertEqual(environment["CJDOC_PYTHON"], sys.executable)
        self.assertNotIn("CJDOC_STS_WRAPPER_CJPM", environment)
        self.assertNotIn("CANGJIE_STDX_PATH", environment)
        binary = source / "target/release/bin/main"
        binary.parent.mkdir(parents=True)
        binary.write_text("#!/bin/sh\necho 'cjdoc 0.7.5'\n", encoding="utf-8")
        binary.chmod(0o755)
        if self.mutate_build_source:
            (source / "scripts/sts_compile_override.py").write_text("# changed policy\n", encoding="utf-8")
        if self.record_build:
            record = {
                "schemaVersion": "cjdoc.sts-invocation/1", "package": "cjdoc",
                "option": self.build_option, "phase": "product-build",
                "reason": "release-product-optimization", "exitCode": self.build_status,
                "argv": ["build", "--jobs", "1"], "workspace": str(source), "platform": "Linux",
                "policySha256": self.fixture.POLICY_SHA256, "wrapperSha256": self.fixture.WRAPPER_SHA256,
                "binary": {"sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
                           "size": binary.stat().st_size},
            }
            pathlib.Path(environment["CJDOC_STS_INVOCATION_LOG"]).write_text(
                json.dumps(record) + "\n", encoding="utf-8")
        return subprocess.CompletedProcess(argv, self.build_status, stdout="")

    def build(self) -> pathlib.Path:
        return prepare(self.config_path, self.cache, self.archive)

    def test_source_launcher_receipt_and_unchanged_cache_reuse(self) -> None:
        with mock.patch.dict("os.environ", {"CJDOC_STS_WRAPPER_CJPM": "inherited-wrapper",
                                            "CANGJIE_STDX_PATH": "dynamic-sidecar"}):
            binary = self.build()
        receipt_text = (binary.parent / "qualification.json").read_text(encoding="utf-8")
        receipt = json.loads(receipt_text)
        self.assertEqual(receipt["compileOptions"], self.fixture.COMPILE_OPTIONS)
        self.assertEqual(receipt["stdxVariant"], "static")
        self.assertNotIn(str(self.root), receipt_text)
        self.assertNotIn("workspace", receipt["productInvocation"])
        self.assertEqual(self.build(), binary)
        self.assertEqual(self.build_count, 1)

    def test_rejects_source_policy_drift_before_build(self) -> None:
        self.source_option = "-O1"
        with self.assertRaisesRegex(CjdocPrepareError, "source compile policy"):
            self.build()
        self.assertEqual(self.build_count, 0)

    def test_rejects_archive_build_source_drift_before_execution(self) -> None:
        self.config_path.write_text(self.config_path.read_text(encoding="utf-8").replace(
            self.fixture.POLICY_SHA256, "f" * 64), encoding="utf-8")
        with self.assertRaisesRegex(CjdocPrepareError, "build source checksum mismatch"):
            self.build()
        self.assertEqual(self.build_count, 0)

    def test_rejects_build_source_changed_during_compilation(self) -> None:
        self.mutate_build_source = True
        with self.assertRaisesRegex(CjdocPrepareError, "build source checksum mismatch"):
            self.build()
        self.assertEqual(self.build_count, 1)

    def test_rejects_unexpected_static_stdx_before_build(self) -> None:
        self.stdx_digest = "e" * 64
        with self.assertRaisesRegex(CjdocPrepareError, "static stdx SHA-256"):
            self.build()
        self.assertEqual(self.build_count, 0)

    def test_rejects_observed_compile_options_drift(self) -> None:
        self.build_option = "-O1"
        with self.assertRaisesRegex(CjdocQualificationError, "compileOptions mismatch"):
            self.build()

    def test_rejects_build_without_invocation_receipt(self) -> None:
        self.record_build = False
        with self.assertRaisesRegex(CjdocPrepareError, "did not record"):
            self.build()

    def test_preserves_failure_without_retry(self) -> None:
        self.build_status = 13
        with self.assertRaisesRegex(CjdocPrepareError, "build failed with exit 13"):
            self.build()
        self.assertEqual(self.build_count, 1)

    def test_rejects_same_version_different_sdk_before_cache_reuse(self) -> None:
        self.build()
        with mock.patch("prepare_cjdoc.toolchain_binary_sha256",
                        return_value={"cjc": "e" * 64, "cjpm": "c" * 64}):
            with self.assertRaisesRegex(CjdocPrepareError, "toolchain binary SHA-256"):
                self.build()
        self.assertEqual(self.build_count, 1)


class ToolchainEnvironmentTest(unittest.TestCase):
    def test_unwraps_real_inherited_launcher_without_mutating_parent_environment(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            compiler = root / "sdk/bin/cjc"
            manager = root / "sdk/tools/bin/cjpm"
            wrapper = root / "old-wrapper/cjpm"
            for path, output in ((compiler, "compiler"), (manager, "manager"), (wrapper, "old-wrapper")):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("#!/bin/sh\nprintf '%s\\n' '" + output + "'\n", encoding="utf-8")
                path.chmod(0o755)
            original_path = os.pathsep.join((str(wrapper.parent), str(compiler.parent), os.environ.get("PATH", "")))
            with mock.patch.dict("os.environ", {
                "PATH": original_path, "CJDOC_STS_WRAPPER_CJPM": str(wrapper),
                "CJDOC_REAL_CJPM": "stale-manager", "CANGJIE_STDX_PATH": "dynamic-sidecar",
            }):
                self.assertEqual(shutil.which("cjpm"), str(wrapper))
                selected = source_build_environment(root / "source", root)
                self.assertEqual(shutil.which("cjpm", path=selected["PATH"]), str(manager))
                self.assertEqual(subprocess.check_output(["cjpm"], env=selected, text=True).strip(), "manager")
                self.assertNotIn(str(wrapper.parent), selected["PATH"].split(os.pathsep))
                self.assertNotIn("CJDOC_STS_WRAPPER_CJPM", selected)
                self.assertNotIn("CJDOC_REAL_CJPM", selected)
                self.assertNotIn("CANGJIE_STDX_PATH", selected)
                self.assertEqual(toolchain_binary_sha256(environment=selected), {
                    "cjc": hashlib.sha256(compiler.read_bytes()).hexdigest(),
                    "cjpm": hashlib.sha256(manager.read_bytes()).hexdigest(),
                })
                self.assertEqual(os.environ["PATH"], original_path)
                self.assertEqual(shutil.which("cjpm"), str(wrapper))


if __name__ == "__main__":
    unittest.main()
