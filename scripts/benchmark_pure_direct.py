#!/usr/bin/env python3
"""Validate and run the formal Pure direct-timing benchmark protocol."""
from __future__ import annotations

import csv
import math
import os
import pathlib
import re
import signal
import subprocess
import threading
import time
from types import MappingProxyType
from typing import Mapping


PROTOCOL_VERSION = 1
MARKER = "YJSON_PURE_DIRECT_V1"
EXPECTED_THREAD_ROLES = (
    "yjson_benchmark",
    "gc-main-thread",
    "gc-pool-t1",
    "gc-helper",
    "schmon",
)
ROLE_CORE_INDEX = MappingProxyType({
    "yjson_benchmark": 0,
    "gc-main-thread": 1,
    "gc-helper": 1,
    "gc-pool-t1": 2,
    "schmon": 2,
})
STREAM_CASES = frozenset({
    "decodePersonChunk4k",
    "decodeRecords64kChunk4k",
    "encodePersonMemory",
    "encodeRecords64kMemory",
})
DOCUMENT_CASES = frozenset({
    "parseStringRecords64k",
    "parseBytesRecords64k",
    "parseStringRecords1m",
    "parseBytesRecords1m",
})
# (batch size, bounded batches), frozen from bench_fixed_work.cj.
FROZEN_BATCH_WORK: Mapping[str, tuple[int, int]] = MappingProxyType({
    "yjsonStringEncodeLargeInt64Map": (4_096, 200),
    "yjsonStringDecodeLargeInt64Map": (1_024, 200),
    "yjsonBytesDecodeLargeInt64Map": (1_024, 200),
    "yjsonStringEncodeDeepNestedProfiles": (512, 200),
    "yjsonStringDecodeDeepNestedProfiles": (64, 200),
    "yjsonBytesDecodeDeepNestedProfiles": (64, 200),
    "yjsonStringEncodePerson": (16_384, 200),
    "yjsonStringDecodePerson": (2_048, 200),
    "yjsonStringEncodeLargeProfileArray": (1_024, 200),
    "yjsonStringDecodeLargeProfileArray": (256, 200),
    "parseStringRecords64k": (8, 200),
    "parseBytesRecords64k": (8, 200),
    "parseStringRecords1m": (1, 200),
    "parseBytesRecords1m": (1, 200),
    "yjsonStringEncodeProfileBundle": (4_096, 200),
    "yjsonStringDecodeProfileBundle": (1_024, 200),
    "yjsonBytesEncodeProfileBundle": (2_048, 200),
    "yjsonBytesDecodeProfileBundle": (1_024, 200),
    "yjsonStringEncodeEscapedUnicodeString": (16_384, 200),
    "yjsonBytesEncodeEscapedUnicodeString": (16_384, 200),
    "decodePersonChunk4k": (1, 65_536),
    "decodeRecords64kChunk4k": (1, 512),
    "encodePersonMemory": (1, 65_536),
    "encodeRecords64kMemory": (1, 4_096),
})
FROZEN_OPERATIONS: Mapping[str, int] = MappingProxyType({
    case: batch_size * batches
    for case, (batch_size, batches) in FROZEN_BATCH_WORK.items()
})
_MARKER_RE = re.compile(
    rf"{MARKER} case=(\S+) operations=([0-9]+) elapsed_ns=([0-9]+) "
    r"warmup_ns=([0-9]+) segments=([0-9]+)"
)
_RESULT_RE = re.compile(
    r"Summary: TOTAL: ([0-9]+)\s+"
    r"PASSED: ([0-9]+), SKIPPED: ([0-9]+), ERROR: ([0-9]+)\s+"
    r"FAILED: ([0-9]+)",
)


class CpuSelectionError(RuntimeError):
    def __init__(self, message: str, evidence: dict[str, object]):
        super().__init__(message)
        self.evidence = evidence


def expected_warmup_ns(case: str) -> int:
    if case not in FROZEN_OPERATIONS:
        raise ValueError(f"unknown Pure direct case: {case}")
    return 500_000_000 if case in DOCUMENT_CASES or case in STREAM_CASES else 200_000_000


def expected_segments(case: str) -> int:
    if case not in FROZEN_OPERATIONS:
        raise ValueError(f"unknown Pure direct case: {case}")
    return FROZEN_OPERATIONS[case] if case in STREAM_CASES else 1


def direct_entry_point(case: str) -> str:
    if case not in FROZEN_OPERATIONS:
        raise ValueError(f"unknown Pure direct case: {case}")
    if case in STREAM_CASES:
        return "pureFixedStream"
    if case in DOCUMENT_CASES:
        return "pureFixedDocument"
    return "pureFixedComprehensive"


def parse_direct_result(text: str, case: str) -> dict[str, int | float]:
    """Parse one successful direct-timing unittest run, failing closed."""
    if case not in FROZEN_OPERATIONS:
        raise ValueError(f"unknown Pure direct case: {case}")
    candidate_lines = [line for line in text.splitlines() if MARKER in line]
    matches: list[tuple[str, str, str, str, str]] = []
    for line in candidate_lines:
        match = _MARKER_RE.fullmatch(line)
        if match is None:
            raise ValueError(f"malformed {MARKER} marker: {line!r}")
        matches.append(match.groups())
    if len(matches) != 1:
        raise ValueError(f"expected one {MARKER} marker for {case}, found {len(matches)}")
    marker_case, operations_text, elapsed_text, warmup_text, segments_text = matches[0]
    if marker_case not in FROZEN_OPERATIONS:
        raise ValueError(f"unknown Pure direct marker case: {marker_case}")
    if marker_case != case:
        raise ValueError(f"Pure direct marker case {marker_case!r} does not match {case!r}")
    operations = int(operations_text)
    elapsed_ns = int(elapsed_text)
    warmup_ns = int(warmup_text)
    segments = int(segments_text)
    expected_operations = FROZEN_OPERATIONS[case]
    if operations != expected_operations:
        raise ValueError(
            f"Pure direct operations for {case} must be {expected_operations}, found {operations}"
        )
    wanted_segments = expected_segments(case)
    if segments != wanted_segments:
        raise ValueError(
            f"Pure direct segments for {case} must be {wanted_segments}, found {segments}"
        )
    if elapsed_ns <= 0:
        raise ValueError(f"Pure direct elapsed_ns for {case} must be positive")
    minimum_warmup = expected_warmup_ns(case)
    if warmup_ns < minimum_warmup:
        raise ValueError(
            f"Pure direct warmup_ns for {case} must be at least {minimum_warmup}, found {warmup_ns}"
        )
    try:
        ns_per_operation = elapsed_ns / operations
    except OverflowError as error:
        raise ValueError(
            f"Pure direct duration for {case} must be finite and positive"
        ) from error
    if not math.isfinite(ns_per_operation) or ns_per_operation <= 0.0:
        raise ValueError(f"Pure direct duration for {case} must be finite and positive")

    results = _RESULT_RE.findall(text)
    if len(results) != 1:
        raise ValueError(
            f"expected one unittest result summary for {case}, found {len(results)}"
        )
    total, passed, skipped, errors, failed = (int(value) for value in results[0])
    if total != passed + skipped + errors + failed:
        raise ValueError(f"inconsistent unittest result summary for {case}")
    if (passed, errors, failed) != (1, 0, 0):
        raise ValueError(
            f"unittest result for {case} must be PASSED 1, ERROR 0, FAILED 0; "
            f"found PASSED {passed}, ERROR {errors}, FAILED {failed}"
        )
    return {
        "operations": operations,
        "elapsed_ns": elapsed_ns,
        "warmup_ns": warmup_ns,
        "segments": segments,
        "ns_per_operation": ns_per_operation,
        "unittest_total": total,
        "unittest_passed": passed,
        "unittest_skipped": skipped,
        "unittest_errors": errors,
        "unittest_failed": failed,
    }


def read_cpu_times() -> dict[int, tuple[int, int]]:
    result: dict[int, tuple[int, int]] = {}
    for line in pathlib.Path("/proc/stat").read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if not fields or not fields[0].startswith("cpu") or not fields[0][3:].isdigit():
            continue
        values = [int(value) for value in fields[1:]]
        if len(values) < 5:
            raise RuntimeError(f"malformed /proc/stat CPU line: {line!r}")
        result[int(fields[0][3:])] = (sum(values), values[3] + values[4])
    if not result:
        raise RuntimeError("/proc/stat contains no logical CPU counters")
    return result


def _parse_cpu_list(text: str) -> list[int]:
    cpus: list[int] = []
    for part in text.strip().split(","):
        if not part:
            continue
        if "-" in part:
            start, end = (int(value) for value in part.split("-", 1))
            if end < start:
                raise ValueError(f"invalid CPU range: {part}")
            cpus.extend(range(start, end + 1))
        else:
            cpus.append(int(part))
    return sorted(set(cpus))


def cpu_topology(cpu: int) -> dict[str, object]:
    root = pathlib.Path(f"/sys/devices/system/cpu/cpu{cpu}")
    topology_root = root / "topology"
    node_names = sorted(
        path.name for path in root.glob("node[0-9]*") if path.name[4:].isdigit()
    )
    if len(node_names) != 1:
        raise RuntimeError(f"logical CPU {cpu} must belong to exactly one NUMA node")
    siblings = _parse_cpu_list((topology_root / "thread_siblings_list").read_text())
    if cpu not in siblings:
        raise RuntimeError(f"logical CPU {cpu} is absent from its SMT sibling list")
    return {
        "cpu": cpu,
        "numa_node": int(node_names[0][4:]),
        "socket": int((topology_root / "physical_package_id").read_text()),
        "core": int((topology_root / "core_id").read_text()),
        "siblings": siblings,
    }


def _utilization(
    before: Mapping[int, tuple[int, int]], after: Mapping[int, tuple[int, int]]
) -> dict[int, float]:
    if set(before) != set(after):
        raise RuntimeError("logical CPU inventory changed during idle sampling")
    result: dict[int, float] = {}
    for cpu, (total_after, idle_after) in after.items():
        total_before, idle_before = before[cpu]
        delta_total = total_after - total_before
        delta_idle = idle_after - idle_before
        if delta_total <= 0 or delta_idle < 0 or delta_idle > delta_total:
            raise RuntimeError(f"invalid /proc/stat delta for logical CPU {cpu}")
        result[cpu] = 100.0 * (delta_total - delta_idle) / delta_total
    return result


def select_idle_cpu_triple(seconds: int, business_cpu: int | None = None) -> dict[str, object]:
    """Select three idle same-NUMA physical cores and retain the full sample window."""
    if seconds <= 0:
        raise ValueError("idle sample duration must be positive")
    allowed = sorted(os.sched_getaffinity(0))
    before = read_cpu_times()
    time.sleep(seconds)
    after = read_cpu_times()
    evidence: dict[str, object] = {
        "sample_seconds": seconds,
        "requested_business_cpu": business_cpu,
        "allowed_cpus": allowed,
        "proc_stat_window": {
            "before": {str(cpu): list(values) for cpu, values in sorted(before.items())},
            "after": {str(cpu): list(values) for cpu, values in sorted(after.items())},
        },
    }
    try:
        utilization = _utilization(before, after)
        evidence["proc_stat_window"]["utilization_percent"] = {
            str(cpu): value for cpu, value in sorted(utilization.items())
        }
        topologies = {cpu: cpu_topology(cpu) for cpu in allowed}
        if business_cpu is not None and business_cpu not in topologies:
            raise RuntimeError(
                f"requested business CPU {business_cpu} is not in this process's allowed CPU set"
            )
        groups: dict[tuple[int, int, int], dict[str, object]] = {}
        for item in topologies.values():
            key = (int(item["numa_node"]), int(item["socket"]), int(item["core"]))
            current = groups.setdefault(key, item.copy())
            current["eligible_cpus"] = sorted(
                set(current.get("eligible_cpus", [])) | {int(item["cpu"])}
            )
        for item in groups.values():
            sibling_values = [utilization[cpu] for cpu in item["siblings"] if cpu in utilization]
            if len(sibling_values) != len(item["siblings"]):
                raise RuntimeError("SMT sibling is absent from the /proc/stat sample")
            item["utilization_percent"] = {
                str(cpu): utilization[cpu] for cpu in item["siblings"]
            }
            item["maximum_utilization_percent"] = max(sibling_values)
            item["sum_utilization_percent"] = sum(sibling_values)
            item["acceptable_all_threads_below_1_percent"] = max(sibling_values) < 1.0

        if business_cpu is not None:
            anchor_topology = topologies[business_cpu]
            anchor_key = (
                int(anchor_topology["numa_node"]),
                int(anchor_topology["socket"]),
                int(anchor_topology["core"]),
            )
            pool = [
                (key, item) for key, item in groups.items()
                if key[0] == anchor_key[0] and key != anchor_key
            ]
            ranked = sorted(pool, key=lambda entry: (
                entry[1]["maximum_utilization_percent"],
                entry[1]["sum_utilization_percent"],
                entry[0],
            ))
            chosen = [(anchor_key, groups[anchor_key]), *ranked[:2]]
        else:
            by_node: dict[int, list[tuple[tuple[int, int, int], dict[str, object]]]] = {}
            for key, item in groups.items():
                by_node.setdefault(key[0], []).append((key, item))
            triples: list[list[tuple[tuple[int, int, int], dict[str, object]]]] = []
            for entries in by_node.values():
                ranked = sorted(entries, key=lambda entry: (
                    entry[1]["maximum_utilization_percent"],
                    entry[1]["sum_utilization_percent"],
                    entry[0],
                ))
                if len(ranked) >= 3:
                    triples.append(ranked[:3])
            if not triples:
                raise RuntimeError("no NUMA node has three eligible physical cores")
            chosen = min(triples, key=lambda entries: (
                max(item["maximum_utilization_percent"] for _, item in entries),
                sum(item["sum_utilization_percent"] for _, item in entries),
                entries[0][0][0],
            ))

        if len(chosen) != 3:
            raise RuntimeError("the business core's NUMA node has fewer than three eligible physical cores")
        roles = ("business", "gc_main_helper", "gc_pool_schmon")
        physical_cores: list[dict[str, object]] = []
        for index, ((node, socket, core), item) in enumerate(chosen):
            cpu = business_cpu if index == 0 and business_cpu is not None else min(item["eligible_cpus"])
            physical_cores.append({
                "role": roles[index],
                "cpu": cpu,
                "numa_node": node,
                "socket": socket,
                "core": core,
                "siblings": item["siblings"],
                "utilization_percent": item["utilization_percent"],
                "acceptable_all_threads_below_1_percent": item["acceptable_all_threads_below_1_percent"],
            })
        evidence.update({
            "numa_node": physical_cores[0]["numa_node"],
            "physical_cores": physical_cores,
            "selected_cpus": [item["cpu"] for item in physical_cores],
            "monitored_cpus": sorted({
                cpu for item in physical_cores for cpu in item["siblings"]
            }),
            "acceptable_all_threads_below_1_percent": all(
                item["acceptable_all_threads_below_1_percent"] for item in physical_cores
            ),
        })
        if not evidence["acceptable_all_threads_below_1_percent"]:
            raise RuntimeError("selected physical cores or their SMT siblings exceeded 1% utilization")
        return evidence
    except Exception as error:
        if isinstance(error, CpuSelectionError):
            raise
        raise CpuSelectionError(str(error), evidence) from error


class CpuMonitor:
    def __init__(self, cpus: list[int], output: pathlib.Path, interval: float = 1.0):
        self.cpus = tuple(sorted(set(cpus)))
        self.output = output
        self.interval = interval
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.error: BaseException | None = None

    def __enter__(self) -> "CpuMonitor":
        if not self.cpus:
            raise ValueError("CPU monitor requires at least one logical CPU")
        self._thread = threading.Thread(target=self._run, name="pure-cpu-monitor", daemon=True)
        self._thread.start()
        return self

    def ensure_healthy(self) -> None:
        if self.error is not None:
            raise RuntimeError("CPU monitor failed") from self.error

    def __exit__(self, exc_type, exc, traceback) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=max(5.0, self.interval * 2.0))
            if self._thread.is_alive():
                raise RuntimeError("CPU monitor did not stop")
        if self.error is not None and exc is None:
            raise RuntimeError("CPU monitor failed") from self.error

    def _run(self) -> None:
        try:
            with self.output.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.writer(stream)
                writer.writerow(["unix_time", "cpu", "utilization_percent"])
                before = read_cpu_times()
                while not self._stop.wait(self.interval):
                    after = read_cpu_times()
                    utilization = _utilization(before, after)
                    now = time.time()
                    for cpu in self.cpus:
                        writer.writerow([f"{now:.3f}", cpu, f"{utilization[cpu]:.3f}"])
                    stream.flush()
                    before = after
        except BaseException as error:
            self.error = error
            self._stop.set()


def _child_pids(pid: int, proc_root: pathlib.Path = pathlib.Path("/proc")) -> list[int]:
    children_path = proc_root / str(pid) / "task" / str(pid) / "children"
    try:
        text = children_path.read_text(encoding="ascii").strip()
    except FileNotFoundError:
        pass
    else:
        return [int(value) for value in text.split()] if text else []

    children: list[int] = []
    for process_path in proc_root.iterdir():
        if not process_path.name.isdecimal():
            continue
        try:
            status = (process_path / "status").read_bytes()
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        for line in status.splitlines():
            if not line.startswith(b"PPid:"):
                continue
            try:
                parent_pid = int(line.removeprefix(b"PPid:").strip())
            except ValueError:
                break
            if parent_pid == pid:
                children.append(int(process_path.name))
            break
    return sorted(children)


def wait_for_target_child(process: subprocess.Popen[object], deadline: float) -> int:
    while time.monotonic() < deadline:
        children = _child_pids(process.pid)
        if len(children) == 1:
            return children[0]
        if len(children) > 1:
            raise RuntimeError(f"GNU time has multiple target children: {children}")
        return_code = process.poll()
        if return_code is not None:
            raise RuntimeError(f"benchmark exited before target PID discovery with status {return_code}")
        time.sleep(0.01)
    raise TimeoutError("timed out discovering GNU time target child PID")


def wait_for_ready(
    process: subprocess.Popen[object], ready: pathlib.Path, expected: bytes, deadline: float
) -> None:
    while time.monotonic() < deadline:
        try:
            observed = ready.read_bytes()
        except FileNotFoundError:
            observed = None
        if observed is not None:
            if observed != expected:
                raise RuntimeError(
                    f"direct control ready file must contain {expected!r}, found {observed!r}"
                )
            return
        return_code = process.poll()
        if return_code is not None:
            raise RuntimeError(f"benchmark exited before ready with status {return_code}")
        time.sleep(0.01)
    raise TimeoutError("timed out waiting for direct benchmark ready file")


def discover_thread_roles(pid: int, deadline: float) -> dict[str, int]:
    expected = set(EXPECTED_THREAD_ROLES)
    last_observed: dict[str, list[int]] = {}
    while time.monotonic() < deadline:
        observed: dict[str, list[int]] = {}
        task_root = pathlib.Path(f"/proc/{pid}/task")
        try:
            task_paths = list(task_root.iterdir())
        except FileNotFoundError:
            task_paths = []
        raced = False
        for path in task_paths:
            try:
                name = (path / "comm").read_text(encoding="utf-8").strip()
            except FileNotFoundError:
                raced = True
                break
            observed.setdefault(name, []).append(int(path.name))
        if raced:
            time.sleep(0.01)
            continue
        last_observed = observed
        if set(observed) == expected and all(len(observed[name]) == 1 for name in expected):
            return {name: observed[name][0] for name in EXPECTED_THREAD_ROLES}
        time.sleep(0.01)
    formatted = {name: tids for name, tids in sorted(last_observed.items())}
    raise RuntimeError(f"benchmark thread set did not become exact: {formatted}")


def pin_and_verify_roles(
    roles: Mapping[str, int], selected_cpus: list[int]
) -> dict[str, dict[str, object]]:
    if len(selected_cpus) != 3 or len(set(selected_cpus)) != 3:
        raise ValueError("role placement requires three distinct logical CPUs")
    placement: dict[str, dict[str, object]] = {}
    for role in EXPECTED_THREAD_ROLES:
        tid = roles[role]
        cpu = selected_cpus[ROLE_CORE_INDEX[role]]
        try:
            os.sched_setaffinity(tid, {cpu})
            mask = sorted(os.sched_getaffinity(tid))
        except ProcessLookupError as error:
            raise RuntimeError(f"benchmark thread {role} disappeared during affinity placement") from error
        if mask != [cpu]:
            raise RuntimeError(
                f"benchmark thread {role} affinity verification failed: expected {[cpu]}, found {mask}"
            )
        placement[role] = {"tid": tid, "cpu": cpu, "mask": mask}
    return placement


def _write_control_file(path: pathlib.Path, payload: bytes) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(payload)
    os.replace(temporary, path)


def _process_group_exists(process_group: int) -> bool:
    try:
        os.killpg(process_group, 0)
        return True
    except ProcessLookupError:
        return False


def _descendant_pids(pid: int) -> list[int]:
    result: list[int] = []
    pending = _child_pids(pid)
    while pending:
        child = pending.pop()
        result.append(child)
        pending.extend(_child_pids(child))
    return result


def terminate_process_tree(process: subprocess.Popen[object]) -> None:
    descendants = _descendant_pids(process.pid)
    for pid in reversed(descendants):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 2.0
    while any(pathlib.Path(f"/proc/{pid}").exists() for pid in descendants):
        if time.monotonic() >= deadline:
            break
        time.sleep(0.01)
    for pid in reversed(descendants):
        if pathlib.Path(f"/proc/{pid}").exists():
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    try:
        process.wait(timeout=2.0)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=2.0)
    if _process_group_exists(process.pid):
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


class DirectCellFailure(RuntimeError):
    def __init__(self, message: str, evidence: dict[str, object]):
        super().__init__(message)
        self.evidence = evidence


def run_direct_cell(
    *,
    case: str,
    executable: pathlib.Path,
    corpus: pathlib.Path,
    log_path: pathlib.Path,
    rss_path: pathlib.Path,
    control: pathlib.Path,
    time_binary: str,
    selected_cpus: list[int],
    timeout_seconds: float,
) -> tuple[float, int, dict[str, object]]:
    """Run one fresh direct-timing process and return ns/op, RSS, and evidence."""
    if case not in FROZEN_OPERATIONS:
        raise ValueError(f"unknown Pure direct case: {case}")
    if timeout_seconds <= 0.0 or not math.isfinite(timeout_seconds):
        raise ValueError("cell timeout must be finite and positive")
    control = control.resolve()
    control.mkdir(parents=True, exist_ok=False)
    ready = control / "ready"
    continuation = control / "continue"
    payload = (case + "\n").encode("utf-8")
    environment = os.environ.copy()
    environment.update({
        "cjHeapSize": "128MB",
        "cjProcessorNum": "1",
        "YJSON_CROSSLANG_CORPUS_DIR": str(corpus),
        "YJSON_PURE_DIRECT_CASE": case,
        "YJSON_PURE_DIRECT_CONTROL": str(control),
        "LC_ALL": "C",
    })
    command = [
        str(executable), "--no-color", "--no-progress", f"--filter=*.{direct_entry_point(case)}"
    ]
    process: subprocess.Popen[object] | None = None
    target_pid: int | None = None
    placement: dict[str, dict[str, object]] | None = None
    stage = "launch"
    evidence: dict[str, object] = {
        "protocol_version": PROTOCOL_VERSION,
        "marker": MARKER,
        "status": "running",
        "stage": stage,
        "case": case,
        "command": command,
        "time_pid": None,
        "target_pid": None,
        "selected_cpus": selected_cpus,
        "control": {
            "directory": str(control),
            "ready": ready.name,
            "continue": continuation.name,
        },
    }
    started = time.monotonic()
    try:
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                [time_binary, "-v", "-o", str(rss_path), *command],
                env=environment,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            evidence["time_pid"] = process.pid
            deadline = started + timeout_seconds
            stage = "target_discovery"
            target_pid = wait_for_target_child(process, deadline)
            evidence["target_pid"] = target_pid
            stage = "ready_handshake"
            wait_for_ready(process, ready, payload, deadline)
            stage = "target_verification"
            try:
                target_executable = pathlib.Path(
                    os.readlink(f"/proc/{target_pid}/exe")
                ).resolve()
            except FileNotFoundError as error:
                raise RuntimeError("benchmark target disappeared before placement") from error
            if target_executable != executable.resolve():
                raise RuntimeError(
                    f"GNU time target {target_executable} is not benchmark {executable.resolve()}"
                )
            stage = "thread_discovery"
            roles = discover_thread_roles(target_pid, deadline)
            evidence["discovered_thread_roles"] = roles
            stage = "affinity_placement"
            placement = pin_and_verify_roles(roles, selected_cpus)
            evidence["role_placement"] = placement
            evidence["verified_before_release"] = True
            stage = "release"
            _write_control_file(continuation, payload)
            stage = "execution"
            remaining = deadline - time.monotonic()
            if remaining <= 0.0:
                raise TimeoutError("direct benchmark cell timed out before release")
            try:
                return_code = process.wait(timeout=remaining)
            except subprocess.TimeoutExpired as error:
                raise TimeoutError(
                    f"direct benchmark cell exceeded {timeout_seconds:g} seconds"
                ) from error
            if return_code != 0:
                raise RuntimeError(f"direct benchmark exited with status {return_code}")
        stage = "result_validation"
        text = log_path.read_text(encoding="utf-8", errors="replace")
        result = parse_direct_result(text, case)
        rss_text = rss_path.read_text(encoding="utf-8", errors="replace")
        rss_matches = re.findall(
            r"^[ \t]*Maximum resident set size \(kbytes\):[ \t]*(\d+)[ \t]*$",
            rss_text,
            re.MULTILINE,
        )
        if len(rss_matches) != 1 or int(rss_matches[0]) <= 0:
            raise ValueError(
                "GNU time output must contain one positive maximum RSS value"
            )
        max_rss_kb = int(rss_matches[0])
    except Exception as error:
        if process is not None:
            terminate_process_tree(process)
        evidence.update({
            "status": "failed",
            "stage": stage,
            "error_type": type(error).__name__,
            "error": str(error),
        })
        raise DirectCellFailure(str(error), evidence) from error
    except BaseException:
        if process is not None:
            terminate_process_tree(process)
        raise
    evidence.update({
        "status": "passed",
        "stage": "complete",
        **result,
        "role_placement": placement,
        "max_rss_kb": max_rss_kb,
    })
    return float(result["ns_per_operation"]), max_rss_kb, evidence
