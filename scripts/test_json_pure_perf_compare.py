#!/usr/bin/env python3

import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import benchmark_input_identity as identity

SCRIPT = pathlib.Path(__file__).with_name("json_pure_perf_compare.py")
SPEC = importlib.util.spec_from_file_location("json_pure_perf_compare", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RssCaptureTest(unittest.TestCase):
    def test_gnu_time_rss_sidecar_is_parsed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "time-rss.txt"
            path.write_text(
                "\tMaximum resident set size (kbytes): 456\n",
                encoding="utf-8",
            )
            self.assertEqual(MODULE.parse_max_rss(path), 456)

    def test_duplicate_gnu_time_rss_values_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "time-rss.txt"
            path.write_text(
                "Maximum resident set size (kbytes): 456\n"
                "Maximum resident set size (kbytes): 457\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "expected one GNU time RSS"):
                MODULE.parse_max_rss(path)

    def test_summary_preserves_rss_inventory_and_peak(self) -> None:
        result = MODULE.summarize(
            {"case": [10.0, 12.0, 11.0]},
            {"case": [100, 140, 120]},
        )
        self.assertEqual(result["case"]["rss_kb"], [100, 140, 120])
        self.assertEqual(result["case"]["median_rss_kb"], 120)
        self.assertEqual(result["case"]["max_rss_kb"], 140)


class DirectCellFailureSidecarTest(unittest.TestCase):

    def test_failure_sidecar_retains_phase_stage_and_target_pid(self) -> None:
        case = MODULE.CASES[0]
        failure = MODULE.benchmark_pure_direct.DirectCellFailure(
            "affinity refused",
            {
                "status": "failed",
                "stage": "affinity_placement",
                "case": case,
                "time_pid": 100,
                "target_pid": 101,
                "error_type": "RuntimeError",
                "error": "affinity refused",
            },
        )
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            output = root / "output"
            output.mkdir()
            with mock.patch.object(
                MODULE.benchmark_pure_direct, "run_direct_cell", side_effect=failure
            ):
                with self.assertRaises(MODULE.benchmark_pure_direct.DirectCellFailure):
                    MODULE.run_variant(
                        "candidate", root, root / "corpus", output, [2, 4, 6],
                        0, case, "/usr/bin/time", 180.0, "preflight",
                    )
            sidecar = output / f"preflight-{case}-candidate.direct.json"
            retained = json.loads(sidecar.read_text(encoding="utf-8"))
        self.assertEqual(retained["phase"], "preflight")
        self.assertEqual(retained["qualification_phase"], "preflight")
        self.assertEqual(retained["stage"], "affinity_placement")
        self.assertEqual(retained["target_pid"], 101)


class QualificationScheduleTest(unittest.TestCase):
    def test_all_variant_case_preflights_precede_every_sample(self) -> None:
        schedule = list(MODULE.qualification_schedule(("caseA", "caseB"), 2))
        self.assertEqual(
            schedule[:4],
            [
                ("preflight", 0, "caseA", "baseline"),
                ("preflight", 0, "caseA", "candidate"),
                ("preflight", 0, "caseB", "baseline"),
                ("preflight", 0, "caseB", "candidate"),
            ],
        )
        self.assertTrue(all(item[0] == "sample" for item in schedule[4:]))
        self.assertEqual(schedule[4:8], [
            ("sample", 1, "caseA", "baseline"),
            ("sample", 1, "caseA", "candidate"),
            ("sample", 1, "caseB", "baseline"),
            ("sample", 1, "caseB", "candidate"),
        ])


class PurePerfProvenanceTest(unittest.TestCase):
    def make_tree(self, root: pathlib.Path) -> None:
        files = {
            "cjpm.toml": "root manifest\n",
            "cjpm.lock": "root lock\n",
            "packages/benchmarks/cjpm.toml": "benchmark manifest\n",
            "packages/benchmarks/cjpm.lock": "benchmark lock\n",
            "packages/benchmarks/build.cj": "main() {}\n",
            "packages/benchmarks/src/bench.cj": "package bench\n",
            "packages/yjson_macros/src/json_codec.cj": "macro codec\n",
            "packages/yjson_macros/src/json_literal.cj": "macro literal\n",
            "packages/yjson_macros/cjpm.toml": "macro manifest\n",
            "scripts/benchmark_fixed_work.py": "def parse_fixed_work(text, case): pass\n",
            "scripts/benchmark_pure_direct.py": "def parse_direct_result(text, case): pass\n",
            "scripts/json_pure_perf_compare.py": "def main(): pass\n",
            "benchmarks/full-seven-library/run_full.py": "def main(): pass\n",
            "packages/yjson_macros/cjpm.lock": "macro lock\n",
            "scripts/build_native_scanner.py": "pass\n",
            "native/yjson_scanner.c": "void scanner(void) {}\n",
            "native/yjson_writer_format.c": "void writer(void) {}\n",
            "native/yjson_scanner.h": "void scanner(void);\n",
            "native/yjson_compact.c": "void compact(void) {}\n",
            "native/yjson_compact.h": "void compact(void);\n",
        }
        for relative, content in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def test_harness_digest_changes_for_every_declared_build_input(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.make_tree(root)
            initial = identity.manifest_digest(identity.harness_manifest(root))
            for relative in (
                "cjpm.toml",
                "cjpm.lock",
                "packages/benchmarks/cjpm.toml",
                "packages/benchmarks/cjpm.lock",
                "packages/benchmarks/build.cj",
                "scripts/benchmark_fixed_work.py",
                "scripts/benchmark_pure_direct.py",
                "scripts/json_pure_perf_compare.py",
                "benchmarks/full-seven-library/run_full.py",
                "scripts/build_native_scanner.py",
                "native/yjson_scanner.c",
                "native/yjson_writer_format.c",
            ):
                path = root / relative
                original = path.read_text(encoding="utf-8")
                path.write_text(original + "changed\n", encoding="utf-8")
                self.assertNotEqual(
                    identity.manifest_digest(identity.harness_manifest(root)), initial,
                    relative,
                )
                path.write_text(original, encoding="utf-8")

    def test_product_digest_ignores_unmeasured_literal_macro(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.make_tree(root)
            initial = identity.manifest_digest(identity.product_manifest(root))
            literal = root / "packages/yjson_macros/src/json_literal.cj"
            literal.write_text("changed literal\n", encoding="utf-8")
            self.assertEqual(
                identity.manifest_digest(identity.product_manifest(root)), initial
            )
            for name in ("json_codec.cj", "codec_decode_plan.cj"):
                codec = root / "packages/yjson_macros/src" / name
                original = codec.read_bytes() if codec.exists() else None
                codec.write_text("changed codec\n", encoding="utf-8")
                self.assertNotEqual(
                    identity.manifest_digest(identity.product_manifest(root)), initial, name
                )
                if original is None:
                    codec.unlink()
                else:
                    codec.write_bytes(original)

    def test_standalone_macro_dependency_is_canonicalized(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            data = (
                "[dependencies]\n"
                f'yjson_macros = {{ {identity.STANDALONE_MACRO_GIT} }}\n'
            ).encode("utf-8")
            normalized = identity.canonical_benchmark_input_bytes(
                root, "packages/benchmarks/cjpm.toml", data
            ).decode("utf-8")
            self.assertIn('yjson_macros = { path = "../yjson_macros" }', normalized)
            self.assertNotIn("commitId", normalized)

    def test_previous_standalone_macro_dependency_is_canonicalized(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            data = (
                "[dependencies]\n"
                'yjson_macros = { git = "https://github.com/lIlIIlIll/yjson_macros.git", '
                'commitId = "fec0adce41f73d037d876cbac7a28aee8108bb5c" }\n'
            ).encode("utf-8")
            normalized = identity.canonical_benchmark_input_bytes(
                root, "packages/benchmarks/cjpm.toml", data
            ).decode("utf-8")
            self.assertIn('yjson_macros = { path = "../yjson_macros" }', normalized)
            self.assertNotIn("commitId", normalized)

    def test_legacy_standalone_macro_dependency_is_canonicalized(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            data = (
                "[dependencies]\n"
                f'yjson_macros = {{ {identity.LEGACY_STANDALONE_MACRO_GIT} }}\n'
            ).encode("utf-8")
            normalized = identity.canonical_benchmark_input_bytes(
                root, "packages/benchmarks/cjpm.toml", data
            ).decode("utf-8")
            self.assertIn('yjson_macros = { path = "../yjson_macros" }', normalized)
            self.assertNotIn("commitId", normalized)

    def test_local_macro_binding_preserves_release_graph_identity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            macro_manifest = root / "packages/yjson_macros/cjpm.toml"
            macro_manifest.parent.mkdir(parents=True)
            macro_manifest.write_text(
                '[package]\nname = "yjson_macros"\n'
                'description = "AST codec and JSON literal macros for yjson"\n',
                encoding="utf-8",
            )
            graph = (
                'name = "yjson_macros"\nrole = "macros"\n'
                'development_manifest = "packages/yjson_macros/cjpm.toml"\n'
                'release_manifest = "release/package-manifests/yjson_macros.toml"\n'
                'source_root = "packages/yjson_macros/src"\n'
                'stage_kind = "package"\nstability = "stable"\n'
                'leaf_bundle = false\ndependencies = []\n'
            ).encode("utf-8")
            root_manifest = root / "cjpm.toml"
            root_manifest.write_text(
                f'[test-dependencies]\nyjson_macros = {{ {identity.STANDALONE_MACRO_GIT} }}\n',
                encoding="utf-8",
            )
            git_graph = identity.canonical_benchmark_input_bytes(
                root, "release/release-graph.toml", graph
            )
            root_manifest.write_text(
                '[test-dependencies]\nyjson_macros = { path = "packages/yjson_macros" }\n',
                encoding="utf-8",
            )
            local_graph = identity.canonical_benchmark_input_bytes(
                root, "release/release-graph.toml", graph
            )
            self.assertEqual(local_graph, git_graph)

    def test_artifact_identity_rejects_symlink_and_hashes_regular_binary(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            path = MODULE.binary(root)
            path.parent.mkdir(parents=True)
            path.write_bytes(b"benchmark-binary")
            identity = MODULE.artifact_identity(root)
            self.assertEqual(identity["size_bytes"], 16)
            self.assertEqual(identity["sha256"], MODULE.sha256_file(path))
            path.unlink()
            target = root / "replacement"
            target.write_bytes(b"replacement")
            path.symlink_to(target)
            with self.assertRaises(SystemExit):
                MODULE.artifact_identity(root)

    def test_enforce_rejects_tracked_build_time_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.make_tree(root)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Fixture"], check=True)
            subprocess.run(
                ["git", "-C", str(root), "config", "user.email", "fixture@example.invalid"],
                check=True,
            )
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(
                ["git", "-C", str(root), "-c", "core.hooksPath=/dev/null", "commit", "-q",
                 "-m", "test(provenance): create fixture"],
                check=True,
            )
            before = MODULE.source_identity(root)
            (root / "cjpm.toml").write_text("mutated during build\n", encoding="utf-8")
            after = MODULE.source_identity(root)
            with self.assertRaisesRegex(SystemExit, "post-build source drift"):
                MODULE.verify_post_build_source_identity("candidate", before, after, True)


class PurePerfGatePolicyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.cases = ("target", "ordinary")
        self.comparisons = {
            "target": {
                "ratio": 0.99,
                "improvement_percent": 1.0,
                "candidate_wins": 1,
            },
            "ordinary": {
                "ratio": 1.0,
                "improvement_percent": 0.0,
                "candidate_wins": 5,
            },
        }
        self.baseline = {case: {"cv_percent": 1.0} for case in self.cases}
        self.candidate = {case: {"cv_percent": 1.0} for case in self.cases}

    def test_release_mode_does_not_require_target_improvement(self) -> None:
        gates = MODULE.evaluate_gates(
            self.cases,
            self.comparisons,
            self.baseline,
            self.candidate,
            "release",
            (),
            None,
        )
        self.assertFalse(gates["target_gate_required"])
        self.assertIsNone(gates["targets_meet_improvement_and_5_of_11_wins"])
        self.assertTrue(gates["passed"])

    def test_release_mode_does_not_require_stability(self) -> None:
        self.baseline["target"]["cv_percent"] = 20.0
        self.candidate["ordinary"]["cv_percent"] = 30.0
        gates = MODULE.evaluate_gates(
            self.cases,
            self.comparisons,
            self.baseline,
            self.candidate,
            "release",
            (),
            None,
        )
        self.assertFalse(gates["stability_gate_required"])
        self.assertFalse(gates["both_cv_at_most_5_percent"])
        self.assertTrue(gates["passed"])

    def test_optimization_mode_still_requires_stability(self) -> None:
        self.comparisons["target"].update({
            "improvement_percent": 5.0,
            "candidate_wins": 5,
        })
        self.baseline["target"]["cv_percent"] = 6.0
        self.candidate["target"]["cv_percent"] = 6.0
        gates = MODULE.evaluate_gates(
            self.cases,
            self.comparisons,
            self.baseline,
            self.candidate,
            "optimization",
            ("target",),
            5.0,
        )
        self.assertTrue(gates["stability_gate_required"])
        self.assertFalse(gates["both_cv_at_most_5_percent"])
        self.assertFalse(gates["passed"])


    def test_optimization_mode_requires_target_improvement(self) -> None:
        gates = MODULE.evaluate_gates(
            self.cases,
            self.comparisons,
            self.baseline,
            self.candidate,
            "optimization",
            ("target",),
            5.0,
        )
        self.assertTrue(gates["target_gate_required"])
        self.assertFalse(gates["targets_meet_improvement_and_5_of_11_wins"])
        self.assertFalse(gates["passed"])

    def test_release_mode_still_rejects_regression(self) -> None:
        self.comparisons["ordinary"]["ratio"] = 1.06
        gates = MODULE.evaluate_gates(
            self.cases,
            self.comparisons,
            self.baseline,
            self.candidate,
            "release",
            (),
            None,
        )
        self.assertFalse(gates["passed"])

    def test_target_options_require_optimization_mode(self) -> None:
        with self.assertRaisesRegex(
            SystemExit, "--target-case requires --gate-mode optimization"
        ):
            MODULE.resolve_target_improvement_percent("release", ("target",), None)
        with self.assertRaisesRegex(
            SystemExit, "optimization requires at least one --target-case"
        ):
            MODULE.resolve_target_improvement_percent("optimization", (), None)

    def test_rebuild_option_is_parsed(self) -> None:
        argv = [
            "json_pure_perf_compare.py",
            "--baseline", "/tmp/baseline",
            "--candidate", "/tmp/candidate",
            "--corpus", "/tmp/corpus",
            "--output", "/tmp/output",
            "--rebuild",
            "--cpu", "2",
        ]
        with mock.patch.object(sys, "argv", argv):
            args = MODULE.parse_args()
        self.assertTrue(args.rebuild)
        self.assertEqual(args.cpu, 2)


if __name__ == "__main__":
    unittest.main()
