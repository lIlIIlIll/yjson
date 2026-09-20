#!/usr/bin/env python3

import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import benchmark_pure_direct as direct


class DirectResultParserTest(unittest.TestCase):
    def valid_log(self, case: str) -> str:
        operations = direct.FROZEN_OPERATIONS[case]
        return (
            f"YJSON_PURE_DIRECT_V1 case={case} operations={operations} "
            f"elapsed_ns={operations * 10} "
            f"warmup_ns={direct.expected_warmup_ns(case)} "
            f"segments={direct.expected_segments(case)}\n"
            "Summary: TOTAL: 3\n"
            "    PASSED: 1, SKIPPED: 2, ERROR: 0\n"
            "    FAILED: 0\n"
        )

    def test_inventory_and_all_case_classes_are_accepted(self) -> None:
        self.assertEqual(len(direct.FROZEN_OPERATIONS), 24)
        cases = (
            "yjsonStringEncodeLargeInt64Map",
            "parseStringRecords64k",
            "decodePersonChunk4k",
        )
        for case in cases:
            with self.subTest(case=case):
                result = direct.parse_direct_result(self.valid_log(case), case)
                self.assertEqual(result["ns_per_operation"], 10.0)
                self.assertEqual(result["operations"], direct.FROZEN_OPERATIONS[case])

    def test_entrypoint_matches_case_class(self) -> None:
        self.assertEqual(
            direct.direct_entry_point("yjsonStringEncodeLargeInt64Map"),
            "pureFixedComprehensive",
        )
        self.assertEqual(
            direct.direct_entry_point("parseStringRecords64k"),
            "pureFixedDocument",
        )
        self.assertEqual(
            direct.direct_entry_point("decodePersonChunk4k"),
            "pureFixedStream",
        )

    def test_malformed_duplicate_unknown_and_wrong_case_markers_are_refused(self) -> None:
        case = "yjsonStringEncodeLargeInt64Map"
        valid = self.valid_log(case)
        marker = valid.splitlines()[0]
        invalid = {
            "malformed": valid.replace("elapsed_ns=8192000", "elapsed_ns=nan"),
            "leading whitespace": " " + valid,
            "duplicate": marker + "\n" + valid,
            "unknown": valid.replace(f"case={case}", "case=notACase", 1),
            "wrong selected case": valid.replace(
                f"case={case}", "case=yjsonStringDecodeLargeInt64Map", 1
            ),
        }
        for label, text in invalid.items():
            with self.subTest(label=label):
                with self.assertRaises(ValueError):
                    direct.parse_direct_result(text, case)

    def test_work_warmup_segments_duration_and_summary_are_refused_when_invalid(self) -> None:
        comprehensive = "yjsonStringEncodeLargeInt64Map"
        stream = "decodeRecords64kChunk4k"
        comprehensive_log = self.valid_log(comprehensive)
        stream_log = self.valid_log(stream)
        invalid = {
            "wrong operations": comprehensive_log.replace(
                f"operations={direct.FROZEN_OPERATIONS[comprehensive]}", "operations=1"
            ),
            "zero elapsed": comprehensive_log.replace("elapsed_ns=8192000", "elapsed_ns=0"),
            "overflow duration": comprehensive_log.replace(
                "elapsed_ns=8192000", "elapsed_ns=" + "9" * 400
            ),
            "short warmup": comprehensive_log.replace(
                "warmup_ns=200000000", "warmup_ns=199999999"
            ),
            "wrong nonstream segments": comprehensive_log.replace("segments=1", "segments=2"),
            "wrong stream segments": stream_log.replace(
                f"segments={direct.FROZEN_OPERATIONS[stream]}", "segments=1"
            ),
            "missing summary": comprehensive_log.split("Summary:", 1)[0],
            "failed summary": comprehensive_log.replace("FAILED: 0", "FAILED: 1"),
            "inconsistent summary": comprehensive_log.replace("TOTAL: 3", "TOTAL: 4"),
        }
        for label, text in invalid.items():
            case = stream if label == "wrong stream segments" else comprehensive
            with self.subTest(label=label):
                with self.assertRaises(ValueError):
                    direct.parse_direct_result(text, case)


class CpuTripleSelectionTest(unittest.TestCase):
    @staticmethod
    def topology(cpu: int) -> dict[str, object]:
        siblings = {
            0: [0, 1], 2: [2, 3], 4: [4, 5], 6: [6, 7]
        }[cpu]
        return {
            "cpu": cpu,
            "numa_node": 0 if cpu != 6 else 1,
            "socket": 0,
            "core": cpu // 2,
            "siblings": siblings,
        }

    def test_cpu_option_is_anchor_for_three_same_node_physical_cores(self) -> None:
        before = {cpu: (1_000, 900) for cpu in range(8)}
        after = {cpu: (2_000, 1_899) for cpu in range(8)}
        with mock.patch.object(direct.os, "sched_getaffinity", return_value={0, 2, 4, 6}), \
             mock.patch.object(direct, "read_cpu_times", side_effect=[before, after]), \
             mock.patch.object(direct.time, "sleep"), \
             mock.patch.object(direct, "cpu_topology", side_effect=self.topology):
            selected = direct.select_idle_cpu_triple(30, 2)
        self.assertEqual(selected["selected_cpus"], [2, 0, 4])
        self.assertEqual(selected["numa_node"], 0)
        self.assertEqual(selected["monitored_cpus"], [0, 1, 2, 3, 4, 5])
        self.assertTrue(selected["acceptable_all_threads_below_1_percent"])

    def test_selection_failure_retains_complete_proc_stat_window(self) -> None:
        before = {cpu: (1_000, 900) for cpu in range(6)}
        after = {cpu: (2_000, 1_899) for cpu in range(6)}
        topologies = {
            0: {"cpu": 0, "numa_node": 0, "socket": 0, "core": 0, "siblings": [0, 1]},
            2: {"cpu": 2, "numa_node": 0, "socket": 0, "core": 1, "siblings": [2, 3]},
        }
        with mock.patch.object(direct.os, "sched_getaffinity", return_value={0, 2}), \
             mock.patch.object(direct, "read_cpu_times", side_effect=[before, after]), \
             mock.patch.object(direct.time, "sleep"), \
             mock.patch.object(direct, "cpu_topology", side_effect=topologies.__getitem__):
            with self.assertRaises(direct.CpuSelectionError) as raised:
                direct.select_idle_cpu_triple(30)
        window = raised.exception.evidence["proc_stat_window"]
        self.assertEqual(set(window["before"]), {str(cpu) for cpu in range(6)})
        self.assertEqual(set(window["after"]), {str(cpu) for cpu in range(6)})


class RolePlacementTest(unittest.TestCase):
    def test_role_masks_are_verified_on_three_distinct_cores(self) -> None:
        roles = {name: index + 100 for index, name in enumerate(direct.EXPECTED_THREAD_ROLES)}
        masks: dict[int, set[int]] = {}

        def set_mask(tid: int, mask: set[int]) -> None:
            masks[tid] = mask

        with mock.patch.object(direct.os, "sched_setaffinity", side_effect=set_mask), \
             mock.patch.object(direct.os, "sched_getaffinity", side_effect=lambda tid: masks[tid]):
            placement = direct.pin_and_verify_roles(roles, [2, 4, 6])
        self.assertEqual(placement["yjson_benchmark"]["mask"], [2])
        self.assertEqual(placement["gc-main-thread"]["mask"], [4])
        self.assertEqual(placement["gc-helper"]["mask"], [4])
        self.assertEqual(placement["gc-pool-t1"]["mask"], [6])
        self.assertEqual(placement["schmon"]["mask"], [6])

    def test_affinity_verification_refuses_wider_mask(self) -> None:
        roles = {name: index + 100 for index, name in enumerate(direct.EXPECTED_THREAD_ROLES)}
        with mock.patch.object(direct.os, "sched_setaffinity"), \
             mock.patch.object(direct.os, "sched_getaffinity", return_value={2, 4}):
            with self.assertRaisesRegex(RuntimeError, "affinity verification failed"):
                direct.pin_and_verify_roles(roles, [2, 4, 6])


class ProcessDiscoveryTest(unittest.TestCase):
    def test_fallback_discovers_real_child_when_children_file_is_unavailable(self) -> None:
        process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        children_path = pathlib.Path(
            f"/proc/{os.getpid()}/task/{os.getpid()}/children"
        )
        original_read_text = pathlib.Path.read_text

        def read_text_without_children(
            path: pathlib.Path, *args: object, **kwargs: object
        ) -> str:
            if path == children_path:
                raise FileNotFoundError(path)
            return original_read_text(path, *args, **kwargs)

        try:
            with mock.patch.object(
                pathlib.Path, "read_text", autospec=True, side_effect=read_text_without_children
            ):
                self.assertIn(process.pid, direct._child_pids(os.getpid()))
        finally:
            process.terminate()
            process.wait(timeout=5.0)

    def test_fallback_ignores_processes_that_exit_during_proc_scan(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            proc_root = pathlib.Path(directory)
            parent_pid = 100
            (proc_root / str(parent_pid) / "task" / str(parent_pid)).mkdir(parents=True)
            (proc_root / "200").mkdir()
            (proc_root / "200" / "status").write_text(
                "Name:\tchild\nPPid:\t100\n", encoding="ascii"
            )
            (proc_root / "201").mkdir()

            self.assertEqual(direct._child_pids(parent_pid, proc_root), [200])

    def test_fallback_multiple_children_are_rejected(self) -> None:
        children = [
            subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
            for _ in range(2)
        ]
        children_path = pathlib.Path(f"/proc/{os.getpid()}/task/{os.getpid()}/children")
        original_read_text = pathlib.Path.read_text

        def read_text_without_children(path, *args, **kwargs):
            if path == children_path:
                raise FileNotFoundError(path)
            return original_read_text(path, *args, **kwargs)

        try:
            with mock.patch.object(
                pathlib.Path, "read_text", autospec=True, side_effect=read_text_without_children
            ):
                with self.assertRaisesRegex(RuntimeError, "multiple target children"):
                    direct.wait_for_target_child(
                        mock.Mock(pid=os.getpid()), direct.time.monotonic() + 1.0
                    )
        finally:
            for child in children:
                child.terminate()
                child.wait(timeout=5.0)


class LaunchFailureEvidenceTest(unittest.TestCase):
    def test_launch_failure_reports_stage_without_fabricated_target_pid(self) -> None:
        case = "yjsonStringEncodePerson"
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            with mock.patch.object(direct.subprocess, "Popen", side_effect=OSError("launch refused")):
                with self.assertRaises(direct.DirectCellFailure) as raised:
                    direct.run_direct_cell(
                        case=case,
                        executable=root / "benchmark",
                        corpus=root / "corpus",
                        log_path=root / "cell.log",
                        rss_path=root / "cell.rss",
                        control=root / "control",
                        time_binary="/usr/bin/time",
                        selected_cpus=[2, 4, 6],
                        timeout_seconds=1.0,
                    )
        evidence = raised.exception.evidence
        self.assertEqual(evidence["status"], "failed")
        self.assertEqual(evidence["stage"], "launch")
        self.assertIsNone(evidence["target_pid"])
        self.assertEqual(evidence["error"], "launch refused")

    def test_malformed_ready_file_kills_owned_target_process(self) -> None:
        case = "yjsonStringEncodePerson"
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            time_binary = root / "time"
            time_binary.write_text(
                "#!/bin/sh\n"
                "shift 3\n"
                "\"$@\" &\n"
                "wait $!\n",
                encoding="utf-8",
            )
            time_binary.chmod(0o755)
            executable = root / "fake-benchmark"
            executable.write_text(
                "#!/usr/bin/env python3\n"
                "import os, pathlib, signal, time\n"
                "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                "control = pathlib.Path(os.environ['YJSON_PURE_DIRECT_CONTROL'])\n"
                "(control / 'ready').write_bytes(b'wrong\\n')\n"
                "time.sleep(60)\n",
                encoding="utf-8",
            )
            executable.chmod(0o755)
            with self.assertRaises(direct.DirectCellFailure) as raised:
                direct.run_direct_cell(
                    case=case,
                    executable=executable,
                    corpus=root / "corpus",
                    log_path=root / "cell.log",
                    rss_path=root / "cell.rss",
                    control=root / "control",
                    time_binary=str(time_binary),
                    selected_cpus=[2, 4, 6],
                    timeout_seconds=5.0,
                )
            evidence = raised.exception.evidence
            self.assertEqual(evidence["stage"], "ready_handshake")
            target_pid = evidence["target_pid"]
            self.assertIsInstance(target_pid, int)
            self.assertFalse(pathlib.Path(f"/proc/{target_pid}").exists())

if __name__ == "__main__":
    unittest.main()
