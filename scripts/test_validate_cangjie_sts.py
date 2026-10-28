#!/usr/bin/env python3
"""Regression tests for the hosted-CI STS resolver."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import pathlib
import re
import tempfile
import unittest
from unittest import mock


SCRIPT = pathlib.Path(__file__).with_name("validate_cangjie_sts.py")
WORKFLOW = SCRIPT.parents[1] / ".github" / "workflows" / "ci.yml"
SPEC = importlib.util.spec_from_file_location("validate_cangjie_sts", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
STS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STS)

VERSION = "1.2.0"
CJC = "Cangjie Compiler: 1.2.0 (cjnative)\nTarget: x86_64-unknown-linux-gnu"
CJPM = "Cangjie Project Manager: 1.2.0"


class StsResolverTests(unittest.TestCase):
    def test_exact_pinned_version_validation(self) -> None:
        self.assertEqual(STS.pinned_sts_version(), VERSION)
        self.assertEqual(STS.validate_version(VERSION), VERSION)
        for invalid in (
            "",
            "sts",
            "1.1",
            "1.2.0 ",
            "1.1.0",
            "1.2.0-alpha.20260831010012",
            "1.2.0-beta.1",
            "1.2.0.1",
            "1.1.3",
            "1.1.2",
            "1.1.4",
        ):
            with self.subTest(version=invalid):
                with self.assertRaises(ValueError):
                    STS.validate_version(invalid)

    def test_validate_version_cli_is_network_free(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            status = STS.main(["--validate-version", VERSION])
        self.assertEqual(status, 0)
        self.assertEqual(stdout.getvalue(), VERSION + "\n")

    def test_installed_tools_reject_old_daily_and_mismatched_resolution(self) -> None:
        with mock.patch.dict(os.environ, {"YJSON_RESOLVED_CANGJIE": ""}):
            self.assertEqual(STS.validate_installed_outputs(CJC, CJPM), VERSION)
            for compiler, manager in (
                (CJC.replace("1.2.0", "1.1.3"), CJPM),
                (CJC.replace("1.2.0", "1.2.0-alpha.20261026040003"), CJPM),
                (CJC, CJPM.replace("1.2.0", "1.1.3")),
                (CJC, CJPM + "-alpha.20261026040003"),
                ("", CJPM), (CJC, ""),
            ):
                with self.subTest(cjc=compiler, cjpm=manager), self.assertRaises(ValueError):
                    STS.validate_installed_outputs(compiler, manager)
        with mock.patch.dict(os.environ, {"YJSON_RESOLVED_CANGJIE": "1.1.3"}):
            with self.assertRaises(ValueError):
                STS.validate_installed_outputs(CJC, CJPM)

    def test_installation_record_uses_real_cjv_receipts_without_local_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            binary = root / "bin/cjc"
            binary.parent.mkdir()
            binary.write_bytes(b"compiler")
            manager = root / "tools/bin/cjpm"
            manager.parent.mkdir(parents=True)
            manager.write_bytes(b"manager")
            receipt = root / ".cjv/toolchain.toml"
            receipt.parent.mkdir()
            receipt.write_text('release = "sts-1.2.0"\ntuple = "linux-x64"\nsha256 = "' + "a" * 64 + '"\n')
            component = root / ".cjv/components/manifest-stdx"
            component.parent.mkdir()
            component.write_text("dynamic/stdx/encoding.json.cjo\n")
            with mock.patch.object(STS.shutil, "which", side_effect=lambda name: str(binary if name == "cjc" else manager)):
                record = STS.installation_record(VERSION, CJC, CJPM)
                self.assertEqual(record["sdkArchiveSha256"], "a" * 64)
                self.assertEqual(set(record["binarySha256"]), {"cjc", "cjpm"})
                self.assertNotIn(str(root), str(record))
                receipt.write_text(receipt.read_text().replace("sts-1.2.0", "sts-1.1.3"))
                with self.assertRaisesRegex(ValueError, "pinned STS release"):
                    STS.installation_record(VERSION, CJC, CJPM)
                receipt.write_text(receipt.read_text().replace("sts-1.1.3", "sts-1.2.0"))
                component.unlink()
                with self.assertRaisesRegex(ValueError, "stdx installation manifest"):
                    STS.installation_record(VERSION, CJC, CJPM)
                receipt.unlink()
                with self.assertRaisesRegex(ValueError, "installation receipt"):
                    STS.installation_record(VERSION, CJC, CJPM)


class HostedWorkflowWiringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_sts_channel_and_pinned_version_are_explicit(self) -> None:
        self.assertIn("name: Cangjie STS (pinned)", self.workflow)
        self.assertIn("channel: sts", self.workflow)
        self.assertIn("--print-pinned-version", self.workflow)
        self.assertNotIn("latest_cangjie_nightly", self.workflow)
        self.assertNotIn("channel: nightly", self.workflow)

    def test_all_cangjie_jobs_consume_shared_sts_resolution(self) -> None:
        setup_count = self.workflow.count("uses: Zxilly/setup-cangjie@")
        self.assertGreater(setup_count, 0)
        self.assertEqual(
            self.workflow.count("version: ${{ needs.sts.outputs.version }}"),
            setup_count,
        )
        blocks = re.split(r"(?m)(?=^  [a-zA-Z0-9_-]+:\s*$)", self.workflow)
        setup_jobs = [block for block in blocks if "uses: Zxilly/setup-cangjie@" in block]
        self.assertEqual(len(setup_jobs), setup_count)
        for job in setup_jobs:
            with self.subTest(job=job.splitlines()[0]):
                dependency = re.search(r"(?m)^    needs: (.+)$", job)
                self.assertIsNotNone(dependency, "SDK job must depend on the shared STS resolver")
                dependencies = dependency.group(1).strip("[]").replace(",", " ").split()
                self.assertIn("sts", dependencies)
                self.assertIn("version: ${{ needs.sts.outputs.version }}", job)
        self.assertNotIn("archive-path:", self.workflow)
        self.assertEqual(self.workflow.count("components: stdx"), setup_count)
        self.assertEqual(self.workflow.count("cjv-version: v0.5.0"), setup_count)
        self.assertEqual(self.workflow.count("--record-installation"), setup_count)
        self.assertEqual(
            self.workflow.count(
                "resolved_cangjie_version=${{ needs.sts.outputs.version }}"
            ),
            setup_count,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
