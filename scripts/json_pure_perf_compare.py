#!/usr/bin/env python3
"""Run Pure baseline/candidate release or optimization qualification."""
from __future__ import annotations

import argparse
from collections.abc import Iterator
import hashlib
import json
import math
import os
import pathlib
import platform
import re
import shutil
import statistics
import subprocess

import benchmark_input_identity
import benchmark_pure_direct

CASES = (
    "yjsonStringEncodeLargeInt64Map",
    "yjsonStringDecodeLargeInt64Map",
    "yjsonBytesDecodeLargeInt64Map",
    "yjsonStringEncodeDeepNestedProfiles",
    "yjsonStringDecodeDeepNestedProfiles",
    "yjsonBytesDecodeDeepNestedProfiles",
    "yjsonStringEncodePerson",
    "yjsonStringDecodePerson",
    "yjsonStringEncodeLargeProfileArray",
    "yjsonStringDecodeLargeProfileArray",
    "parseStringRecords64k",
    "parseBytesRecords64k",
    "parseStringRecords1m",
    "parseBytesRecords1m",
    "yjsonStringEncodeProfileBundle",
    "yjsonStringDecodeProfileBundle",
    "yjsonBytesEncodeProfileBundle",
    "yjsonBytesDecodeProfileBundle",
    "yjsonStringEncodeEscapedUnicodeString",
    "yjsonBytesEncodeEscapedUnicodeString",
    "decodePersonChunk4k",
    "decodeRecords64kChunk4k",
    "encodePersonMemory",
    "encodeRecords64kMemory",
)
if tuple(benchmark_pure_direct.FROZEN_OPERATIONS) != CASES:
    raise RuntimeError("Pure direct frozen-work case inventory differs from CASES")
GATE_MODES = ("release", "optimization")
DEFAULT_TARGET_IMPROVEMENT_PERCENT = 5.0
RSS_RE = re.compile(
    r"^[ \t]*Maximum resident set size \(kbytes\):[ \t]*(\d+)[ \t]*$",
    re.MULTILINE,
)


def find_time_binary() -> str:
    path = shutil.which("time", path="/usr/bin:/bin")
    if path:
        return path
    raise SystemExit(
        "GNU time (/usr/bin/time) is required for RSS capture; install the 'time' package"
    )


def parse_max_rss(path: pathlib.Path) -> int:
    matches = RSS_RE.findall(path.read_text(encoding="utf-8", errors="replace"))
    if len(matches) != 1:
        raise ValueError(
            f"expected one GNU time RSS value in {path}, found {len(matches)}"
        )
    value = int(matches[0])
    if value <= 0:
        raise ValueError(f"GNU time RSS value must be positive in {path}")
    return value



def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True, type=pathlib.Path)
    parser.add_argument("--candidate", required=True, type=pathlib.Path)
    parser.add_argument("--corpus", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--rounds", type=int, default=11)
    parser.add_argument(
        "--cpu",
        type=int,
        default=None,
        help="use this logical CPU as the business-core anchor",
    )
    parser.add_argument("--idle-sample-seconds", type=int, default=30)
    parser.add_argument(
        "--cell-timeout-seconds",
        type=float,
        default=180.0,
        help="maximum wall time for each fresh direct-timing process",
    )
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="clean and rebuild both benchmark trees before measuring",
    )
    parser.add_argument(
        "--gate-mode",
        choices=GATE_MODES,
        default="release",
        help="release checks regressions; optimization also checks stability and targets",
    )
    parser.add_argument("--case", action="append", choices=CASES,
                        help="run only this case; repeat for a diagnostic subset")
    parser.add_argument(
        "--target-case",
        action="append",
        choices=CASES,
        help="optimization mode only; require this case to improve and win 5/11 rounds",
    )
    parser.add_argument(
        "--target-improvement-percent",
        type=float,
        default=None,
        help="minimum target improvement in optimization mode (default: 5.0)",
    )
    return parser.parse_args()




def binary(root: pathlib.Path) -> pathlib.Path:
    return root / "packages/benchmarks/target/release/unittest_bin/yjson_benchmarks"


def path_is_within(path: pathlib.Path, root: pathlib.Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def git_output(root: pathlib.Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args], check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    return completed.stdout.strip()


def source_identity(root: pathlib.Path) -> dict[str, object]:
    dirty = git_output(root, "status", "--porcelain=v1", "--untracked-files=all").splitlines()
    manifest = benchmark_input_identity.product_manifest(root)
    return {
        "commit": git_output(root, "rev-parse", "HEAD"),
        "tree": git_output(root, "rev-parse", "HEAD^{tree}"),
        "dirty": bool(dirty),
        "dirty_paths": dirty,
        "product_source_sha256": benchmark_input_identity.manifest_digest(manifest),
        "product_source_manifest": manifest,
    }


def verify_post_build_source_identity(
    name: str,
    before: dict[str, object],
    after: dict[str, object],
    enforce: bool,
) -> None:
    stable_keys = ("commit", "tree", "product_source_sha256", "product_source_manifest")
    changed = [key for key in stable_keys if before[key] != after[key]]
    if after["dirty"]:
        changed.append("dirty")
    if enforce and changed:
        raise SystemExit(
            f"--enforce detected post-build source drift for {name}: " + ", ".join(changed)
        )


def command_identity(command: str) -> dict[str, object]:
    resolved = shutil.which(command)
    if resolved is None:
        raise SystemExit(f"required build tool not found: {command}")
    path = pathlib.Path(resolved).resolve()
    completed = subprocess.run(
        [str(path), "--version"], check=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    return {
        "command": command,
        "path": str(path),
        "sha256": sha256_file(path),
        "version": completed.stdout.strip(),
    }


def toolchain_identity() -> dict[str, object]:
    cc = os.environ.get("CC", "clang")
    ar = os.environ.get("AR", "ar")
    return {
        "host": {"system": platform.system(), "machine": platform.machine()},
        "tools": {
            "cjc": command_identity("cjc"),
            "cjpm": command_identity("cjpm"),
            "cc": command_identity(cc),
            "ar": command_identity(ar),
        },
        "build_environment": {
            name: os.environ.get(name)
            for name in ("CC", "AR", "CANGJIE_HOME", "LD_LIBRARY_PATH")
        },
    }


def artifact_identity(root: pathlib.Path) -> dict[str, object]:
    path = binary(root)
    if path.is_symlink():
        raise SystemExit(f"benchmark binary must not be a symlink: {path}")
    if not path.is_file():
        raise SystemExit(f"benchmark binary not found: {path}")
    stat = path.stat()
    return {
        "path": str(path),
        "size_bytes": stat.st_size,
        "sha256": sha256_file(path),
    }


def rebuild_variant(name: str, root: pathlib.Path, output: pathlib.Path) -> None:
    package = root / "packages/benchmarks"
    log = output / f"build-{name}.log"
    with log.open("w", encoding="utf-8") as stream:
        subprocess.run(
            ["cjpm", "clean"], cwd=package, stdout=stream,
            stderr=subprocess.STDOUT, check=True,
        )
        subprocess.run(
            ["cjpm", "bench", "--no-color", "--no-run"],
            cwd=package, stdout=stream, stderr=subprocess.STDOUT, check=True,
        )


def verify_equal_harness(baseline: pathlib.Path, candidate: pathlib.Path) -> str:
    baseline_manifest = benchmark_input_identity.harness_manifest(baseline)
    candidate_manifest = benchmark_input_identity.harness_manifest(candidate)
    if baseline_manifest != candidate_manifest:
        names = sorted(set(baseline_manifest) | set(candidate_manifest))
        differences = [name for name in names
                       if baseline_manifest.get(name) != candidate_manifest.get(name)]
        raise SystemExit("baseline/candidate benchmark harness differs: " + ", ".join(differences))
    return benchmark_input_identity.manifest_digest(baseline_manifest)


def run_variant(
    name: str,
    root: pathlib.Path,
    corpus: pathlib.Path,
    output: pathlib.Path,
    selected_cpus: list[int],
    round_number: int,
    case: str,
    time_binary: str,
    timeout_seconds: float,
    qualification_phase: str = "sample",
) -> tuple[float, int, dict[str, object]]:
    if qualification_phase not in ("preflight", "sample"):
        raise ValueError(f"unknown qualification phase: {qualification_phase}")
    stem = (
        f"preflight-{case}-{name}"
        if qualification_phase == "preflight"
        else f"round-{round_number:02d}-{case}-{name}"
    )
    rss_path = output / f"{stem}.rss.txt"
    log = output / f"{stem}.log"
    sidecar = output / f"{stem}.direct.json"
    try:
        elapsed, max_rss_kb, evidence = benchmark_pure_direct.run_direct_cell(
            case=case,
            executable=binary(root),
            corpus=corpus,
            log_path=log,
            rss_path=rss_path,
            control=output / "control" / stem,
            time_binary=time_binary,
            selected_cpus=selected_cpus,
            timeout_seconds=timeout_seconds,
        )
    except benchmark_pure_direct.DirectCellFailure as error:
        evidence = {
            **error.evidence,
            "phase": qualification_phase,
            "qualification_phase": qualification_phase,
        }
        sidecar.write_text(
            json.dumps(evidence, indent=2) + "\n", encoding="utf-8"
        )
        raise
    evidence["phase"] = qualification_phase
    evidence["qualification_phase"] = qualification_phase
    sidecar.write_text(
        json.dumps(evidence, indent=2) + "\n", encoding="utf-8"
    )
    return elapsed, max_rss_kb, evidence



def qualification_schedule(
    cases: tuple[str, ...], rounds: int
) -> Iterator[tuple[str, int, str, str]]:
    for case in cases:
        for name in ("baseline", "candidate"):
            yield "preflight", 0, case, name
    for round_number in range(1, rounds + 1):
        order = (
            ("baseline", "candidate")
            if round_number % 2
            else ("candidate", "baseline")
        )
        for case in cases:
            for name in order:
                yield "sample", round_number, case, name


def summarize(
    samples: dict[str, list[float]],
    rss_samples: dict[str, list[int]],
) -> dict[str, dict[str, object]]:
    if set(samples) != set(rss_samples):
        raise ValueError("timing and RSS case inventories differ")
    result: dict[str, dict[str, object]] = {}
    for case, values in samples.items():
        rss_values = rss_samples[case]
        if len(values) != len(rss_values):
            raise ValueError(f"timing and RSS run counts differ for {case}")
        mean = statistics.mean(values)
        result[case] = {
            "median_ns": statistics.median(values),
            "mean_ns": mean,
            "cv_percent": 0.0 if mean == 0.0 else statistics.stdev(values) / mean * 100.0,
            "rss_kb": rss_values,
            "median_rss_kb": statistics.median(rss_values),
            "max_rss_kb": max(rss_values),
        }
    return result


def resolve_target_improvement_percent(
    gate_mode: str,
    target_cases: tuple[str, ...],
    requested: float | None,
) -> float | None:
    if gate_mode not in GATE_MODES:
        raise SystemExit(f"unknown gate mode: {gate_mode}")
    if gate_mode == "release":
        if target_cases:
            raise SystemExit("--target-case requires --gate-mode optimization")
        if requested is not None:
            raise SystemExit(
                "--target-improvement-percent requires --gate-mode optimization"
            )
        return None
    if not target_cases:
        raise SystemExit("--gate-mode optimization requires at least one --target-case")
    resolved = (
        DEFAULT_TARGET_IMPROVEMENT_PERCENT
        if requested is None
        else requested
    )
    if resolved < 0.0:
        raise SystemExit("--target-improvement-percent must be non-negative")
    return resolved


def evaluate_gates(
    cases: tuple[str, ...],
    comparisons: dict[str, dict[str, float | int]],
    baseline: dict[str, dict[str, float]],
    candidate: dict[str, dict[str, float]],
    gate_mode: str,
    target_cases: tuple[str, ...],
    target_improvement_percent: float | None,
) -> dict[str, object]:
    regression_passed = all(
        comparisons[case]["ratio"] <= 1.05 for case in cases
    )
    stability_passed = all(
        baseline[case]["cv_percent"] <= 5.0
        and candidate[case]["cv_percent"] <= 5.0
        for case in cases
    )
    stability_gate_required = gate_mode == "optimization"
    target_passed: bool | None = None
    if gate_mode == "optimization":
        if target_improvement_percent is None:
            raise ValueError("optimization gate requires a target threshold")
        target_passed = all(
            comparisons[case]["improvement_percent"] >= target_improvement_percent
            and comparisons[case]["candidate_wins"] >= 5
            for case in target_cases
        )
    return {
        "gate_mode": gate_mode,
        "all_ratios_at_most_1_05": regression_passed,
        "target_gate_required": gate_mode == "optimization",
        "stability_gate_required": stability_gate_required,
        "targets_meet_improvement_and_5_of_11_wins": target_passed,
        "both_cv_at_most_5_percent": stability_passed,
        "passed": (
            regression_passed
            and (not stability_gate_required or stability_passed)
            and target_passed is not False
        ),
    }


def write_markdown(summary: dict[str, object], path: pathlib.Path) -> None:
    baseline = summary["baseline"]
    candidate = summary["candidate"]
    comparisons = summary["comparisons"]
    lines = [
        f"Pure direct timing protocol: `{summary['direct_timing_protocol']}`",
        "",
        "| Case | Baseline median | Candidate median | C/B | Improvement | Wins | Baseline CV | Candidate CV | "
        "Baseline max RSS KB | Candidate max RSS KB |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for case in summary["cases"]:
        base = baseline[case]
        cand = candidate[case]
        item = comparisons[case]
        lines.append(
            f"| `{case}` | {base['median_ns'] / 1000.0:.3f} us | "
            f"{cand['median_ns'] / 1000.0:.3f} us | {item['ratio']:.3f}x | "
            f"{item['improvement_percent']:.1f}% | {item['candidate_wins']}/{summary['rounds']} | "
            f"{base['cv_percent']:.2f}% | {cand['cv_percent']:.2f}% | "
            f"{base['max_rss_kb']:.0f} | {cand['max_rss_kb']:.0f} |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    args.baseline = args.baseline.resolve()
    args.candidate = args.candidate.resolve()
    args.corpus = args.corpus.resolve()
    args.output = args.output.resolve()
    cases = tuple(args.case) if args.case else CASES
    target_cases = tuple(args.target_case) if args.target_case else ()
    target_improvement_percent = resolve_target_improvement_percent(
        args.gate_mode,
        target_cases,
        args.target_improvement_percent,
    )
    if args.rounds < 2:
        raise SystemExit("--rounds must be at least 2")
    if args.idle_sample_seconds <= 0:
        raise SystemExit("--idle-sample-seconds must be positive")
    if args.cell_timeout_seconds <= 0.0 or not math.isfinite(args.cell_timeout_seconds):
        raise SystemExit("--cell-timeout-seconds must be finite and positive")
    if args.enforce and cases != CASES:
        raise SystemExit("--enforce requires the complete 24-case inventory")
    if args.enforce and args.rounds != 11:
        raise SystemExit("--enforce requires --rounds 11")
    if args.enforce and not args.rebuild:
        raise SystemExit("--enforce requires --rebuild to bind binaries to source")
    missing_targets = [case for case in target_cases if case not in cases]
    if missing_targets:
        raise SystemExit("target cases are not selected: " + ", ".join(missing_targets))
    if args.baseline == args.candidate:
        raise SystemExit("baseline and candidate must be different source directories")
    for root in (args.baseline, args.candidate):
        if path_is_within(args.output, root):
            raise SystemExit("output directory must be outside both source directories")
    harness_digest = verify_equal_harness(args.baseline, args.candidate)
    sources = {
        "baseline": source_identity(args.baseline),
        "candidate": source_identity(args.candidate),
    }
    if args.enforce:
        dirty = [name for name, identity in sources.items() if identity["dirty"]]
        if dirty:
            raise SystemExit("--enforce requires clean source trees: " + ", ".join(dirty))
    corpus_paths = [args.corpus / name for name in (
        "person.json", "records-64k.json", "records-1m.json"
    )]
    corpus_manifest = benchmark_input_identity.files_manifest(args.corpus, corpus_paths)
    time_binary = find_time_binary()
    toolchain = toolchain_identity()
    args.output.mkdir(parents=True, exist_ok=False)
    if args.rebuild:
        rebuild_variant("baseline", args.baseline, args.output)
        rebuild_variant("candidate", args.candidate, args.output)
    post_build_sources = {
        "baseline": source_identity(args.baseline),
        "candidate": source_identity(args.candidate),
    }
    for name in ("baseline", "candidate"):
        verify_post_build_source_identity(
            name, sources[name], post_build_sources[name], args.enforce
        )
    artifacts = {
        "baseline": artifact_identity(args.baseline),
        "candidate": artifact_identity(args.candidate),
    }
    direct_parser = pathlib.Path(benchmark_pure_direct.__file__).resolve()
    fixed_work_source = pathlib.Path("packages/benchmarks/src/bench_fixed_work.cj")
    frozen_work = {
        case: {
            "batches": benchmark_pure_direct.FROZEN_BATCH_WORK[case][1],
            "batch_size": benchmark_pure_direct.FROZEN_BATCH_WORK[case][0],
            "operations": benchmark_pure_direct.FROZEN_OPERATIONS[case],
            "segments": benchmark_pure_direct.expected_segments(case),
            "minimum_warmup_ns": benchmark_pure_direct.expected_warmup_ns(case),
        }
        for case in cases
    }
    provenance = {
        "direct_timing": {
            "protocol_version": benchmark_pure_direct.PROTOCOL_VERSION,
            "marker": benchmark_pure_direct.MARKER,
            "source": {
                "path": str(fixed_work_source),
                "sha256": sha256_file(args.baseline / fixed_work_source),
            },
            "parser_runner": {
                "path": str(direct_parser),
                "sha256": sha256_file(direct_parser),
            },
            "frozen_work": frozen_work,
        },
        "time_binary": time_binary,
        "rss_unit": "kbytes",
        "runner": {
            "path": str(pathlib.Path(__file__).resolve()),
            "sha256": sha256_file(pathlib.Path(__file__).resolve()),
        },
        "harness_sha256": harness_digest,
        "sources": sources,
        "post_build_sources": post_build_sources,
        "toolchain": toolchain,
        "artifacts": artifacts,
        "corpus": {
            "path": str(args.corpus),
            "sha256": benchmark_input_identity.manifest_digest(corpus_manifest),
            "manifest": corpus_manifest,
        },
        "invocation": {
            "rounds": args.rounds,
            "cases": list(cases),
            "gate_mode": args.gate_mode,
            "target_cases": list(target_cases),
            "target_improvement_percent": target_improvement_percent,
            "cpu_business_anchor": args.cpu,
            "idle_sample_seconds": args.idle_sample_seconds,
            "cell_timeout_seconds": args.cell_timeout_seconds,
            "enforce": args.enforce,
            "rebuild": args.rebuild,
            "heap": "128MB",
            "cj_processor_num": 1,
        },
    }
    (args.output / "provenance.json").write_text(
        json.dumps(provenance, indent=2) + "\n", encoding="utf-8"
    )
    try:
        selection = benchmark_pure_direct.select_idle_cpu_triple(
            args.idle_sample_seconds, args.cpu
        )
    except benchmark_pure_direct.CpuSelectionError as error:
        (args.output / "cpu-selection.json").write_text(
            json.dumps(error.evidence, indent=2) + "\n", encoding="utf-8"
        )
        raise SystemExit(f"CPU triple selection failed: {error}") from error
    (args.output / "cpu-selection.json").write_text(
        json.dumps(selection, indent=2) + "\n", encoding="utf-8"
    )
    selected_cpus = [int(value) for value in selection["selected_cpus"]]
    monitor_path = args.output / "cpu-triple-monitor.csv"
    raw_rss = {
        name: {case: [] for case in cases}
        for name in ("baseline", "candidate")
    }
    raw = {
        name: {case: [] for case in cases}
        for name in ("baseline", "candidate")
    }
    preflight_cells: list[dict[str, object]] = []
    direct_cells: list[dict[str, object]] = []
    with benchmark_pure_direct.CpuMonitor(
        [int(value) for value in selection["monitored_cpus"]], monitor_path
    ) as cpu_monitor:
        for phase, round_number, case, name in qualification_schedule(
            cases, args.rounds
        ):
            cpu_monitor.ensure_healthy()
            root = args.baseline if name == "baseline" else args.candidate
            elapsed, max_rss_kb, evidence = run_variant(
                name, root, args.corpus, args.output, selected_cpus,
                round_number, case, time_binary, args.cell_timeout_seconds, phase,
            )
            cpu_monitor.ensure_healthy()
            stem = (
                f"preflight-{case}-{name}"
                if phase == "preflight"
                else f"round-{round_number:02d}-{case}-{name}"
            )
            cell: dict[str, object] = {
                "qualification_phase": phase,
                "variant": name,
                "case": case,
                "sidecar": f"{stem}.direct.json",
                "operations": evidence["operations"],
                "elapsed_ns": evidence["elapsed_ns"],
                "warmup_ns": evidence["warmup_ns"],
                "segments": evidence["segments"],
                "max_rss_kb": max_rss_kb,
                "role_placement": evidence["role_placement"],
            }
            if phase == "preflight":
                preflight_cells.append(cell)
            else:
                cell["round"] = round_number
                direct_cells.append(cell)
                raw[name][case].append(elapsed)
                raw_rss[name][case].append(max_rss_kb)
    baseline = summarize(raw["baseline"], raw_rss["baseline"])
    candidate = summarize(raw["candidate"], raw_rss["candidate"])
    comparisons: dict[str, dict[str, float | int]] = {}
    for case in cases:
        base = baseline[case]["median_ns"]
        cand = candidate[case]["median_ns"]
        comparisons[case] = {
            "ratio": cand / base,
            "improvement_percent": (1.0 - cand / base) * 100.0,
            "candidate_wins": sum(
                cand_value < base_value
                for base_value, cand_value in zip(raw["baseline"][case], raw["candidate"][case])
            ),
        }
    summary: dict[str, object] = {
        "rounds": args.rounds,
        "heap": "128MB",
        "cj_processor_num": 1,
        "harness_sha256": harness_digest,
        "direct_timing_protocol": benchmark_pure_direct.PROTOCOL_VERSION,
        "fixed_work": frozen_work,
        "provenance": provenance,
        "cpu": selection,
        "cases": list(cases),
        "gate_mode": args.gate_mode,
        "target_cases": list(target_cases),
        "target_improvement_percent": target_improvement_percent,
        "raw_median_ns": raw,
        "raw_max_rss_kb": raw_rss,
        "preflight_cells": preflight_cells,
        "direct_cells": direct_cells,
        "baseline": baseline,
        "candidate": candidate,
        "comparisons": comparisons,
    }
    summary["gates"] = evaluate_gates(
        cases,
        comparisons,
        baseline,
        candidate,
        args.gate_mode,
        target_cases,
        target_improvement_percent,
    )
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    write_markdown(summary, args.output / "summary.md")
    print((args.output / "summary.md").read_text(), end="")
    if args.enforce and not summary["gates"]["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
