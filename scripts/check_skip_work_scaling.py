#!/usr/bin/env python3
"""Measure actual skipped-object key work in an isolated -O2 Cangjie build.

Only the diagnostic copy changes: its decoded skip keys are wrapped to count
String hash/equality calls. The parser and its Array/HashSet algorithm are not
reimplemented. Unknown source shapes fail rather than being reported as PASS.
Run after sourcing the selected SDK; --source-ref reproduces an older Git tree.
This Unix-only check uses fixed small keys, not a collision-resistance proof.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
try:
    import resource
except ImportError:  # Native stack control is a Unix-only diagnostic.
    resource = None
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
READERS = ("lib_json_direct_reader.cj", "lib_json_fast_reader.cj")
SIZES = (128, 256, 512)
KINDS = ("direct-string", "direct-bytes", "direct-stream", "fast-string", "fast-bytes")
KEY = "SkipWorkMeasuredName"
COUNTERS = "SkipWorkCounters"

MEASURED_KEY = '''package yjson

class SkipWorkCounters {
    public static var hashes: Int64 = 0
    public static var equals: Int64 = 0
    public static func reset(): Unit { hashes = 0; equals = 0 }
}

// Preserve the decoded String's hash, equality and diagnostic spelling.
struct SkipWorkMeasuredName <: Hashable & Equatable<SkipWorkMeasuredName> & ToString {
    private let value: String
    public init(value: String) { this.value = value }
    public func hashCode(): Int64 { SkipWorkCounters.hashes++; value.hashCode() }
    public operator func ==(other: SkipWorkMeasuredName): Bool {
        SkipWorkCounters.equals++
        value == other.value
    }
    public func toString(): String { value }
}
'''

PROBE = r'''package yjson

import std.io.*
import std.unittest.*
import std.unittest.testmacro.*

private class SkipWorkChunkStream <: InputStream {
    private let data: Array<Byte>
    private var offset: Int64 = 0
    public init(text: String) { data = unsafe { text.rawData().clone() } }
    public func read(output: Array<Byte>): Int64 {
        if (offset == data.size || output.size == 0) { return 0 }
        var count: Int64 = 7
        if (count > output.size) { count = output.size }
        if (count > data.size - offset) { count = data.size - offset }
        data.copyTo(output, offset, 0, count)
        offset += count
        count
    }
}

private func skipWorkWideObject(count: Int64): String {
    let text = StringBuilder("{")
    for (index in 0..count) {
        if (index > 0) { text.append(",") }
        text.append("\"field_${index}\":${index}")
    }
    text.append("}")
    text.toString()
}

private func skipWorkReport(kind: String, count: Int64): Unit {
    println("YJSON_SKIP_WORK|${kind}|${count}|${SkipWorkCounters.hashes}|${SkipWorkCounters.equals}")
}

@Test
class SkipWorkScalingProbe {
    @TestCase
    func uniqueDecodedKeysAndPolicySemantics(): Unit {
        for (count in [128, 256, 512]) {
            let text = skipWorkWideObject(count)
            SkipWorkCounters.reset()
            let directString = JsonDirectReader(text)
            directString.skipValue(); directString.expectEnd()
            skipWorkReport("direct-string", count)
            SkipWorkCounters.reset()
            let directBytes = JsonDirectReader(unsafe { text.rawData().clone() })
            directBytes.skipValue(); directBytes.expectEnd()
            skipWorkReport("direct-bytes", count)
            SkipWorkCounters.reset()
            let stream = JsonDirectReader(SkipWorkChunkStream(text))
            stream.skipValue(); stream.expectEnd()
            skipWorkReport("direct-stream", count)
            SkipWorkCounters.reset()
            let fastString = JsonFastReader(text)
            fastString.skipValue(256); fastString.expectEnd()
            skipWorkReport("fast-string", count)
            SkipWorkCounters.reset()
            let fastBytes = JsonFastReader(unsafe { text.rawData().clone() })
            fastBytes.skipValue(256); fastBytes.expectEnd()
            skipWorkReport("fast-bytes", count)
        }
        for (text in ["{\"a\":1,\"a\":2}", "{\"a\":1,\"\\u0061\":2}"]) {
            let direct = JsonDirectReader(text)
            @Expect(@AssertThrows[JsonException](direct.skipValue()).code, "duplicate_key")
            let fast = JsonFastReader(text)
            @Expect(@AssertThrows[JsonException](fast.skipValue(256)).code, "duplicate_key")
            let lastWins = JsonDirectReader(text,
                config: JsonReadOptions(duplicateKeyPolicy: JsonDuplicateKeyPolicy.LastWins))
            SkipWorkCounters.reset()
            lastWins.skipValue(); lastWins.expectEnd()
            @Expect(SkipWorkCounters.hashes, 0)
            @Expect(SkipWorkCounters.equals, 0)
        }
        let nested = "{\"a\":{\"a\":1},\"b\":[{\"a\":2},{\"a\":3}]}"
        let direct = JsonDirectReader(nested)
        direct.skipValue(); direct.expectEnd()
        let fast = JsonFastReader(nested)
        fast.skipValue(256); fast.expectEnd()
    }
}
'''

MANIFEST = '''[package]
cjc-version = "1.1.0"
name = "yjson"
version = "0.1.1"
output-type = "static"
compile-option = "-O2"
'''


def git_output(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True)


def sources(root: Path, source_ref: str | None) -> dict[str, str]:
    if source_ref:
        names = git_output(root, "ls-tree", "-r", "--name-only", source_ref, "src").splitlines()
        return {Path(name).name: git_output(root, "show", f"{source_ref}:{name}")
                for name in names if Path(name).name.startswith("lib_") and name.endswith(".cj")}
    return {path.name: path.read_text(encoding="utf-8")
            for path in sorted((root / "src").glob("lib_*.cj"))}


def function_span(source: str, name: str) -> tuple[int, int]:
    # Exact class-method indentation avoids treating byte/string braces as
    # syntax. If this convention changes, review the injection before running.
    matches = list(re.finditer(rf"(?ms)^    private func {re.escape(name)}\([^\n]*\): Unit \{{\n.*?^    \}}", source))
    if len(matches) != 1:
        raise ValueError(f"expected exactly one supported {name} method, got {len(matches)}")
    return matches[0].span()


def instrument(source: str, filename: str) -> tuple[str, str]:
    start, end = function_span(source, "skipRawObjectPolicyAware")
    body = source[start:end]
    parse = "let name = parseString()"
    if body.count(parse) != 1:
        raise ValueError(f"{filename}: expected one decoded skip name")
    old = "skipSeenNames[position] == name" in body
    new = "HashSet<String>" in body and "names.add(name)" in body
    if old == new:
        raise ValueError(f"{filename}: unsupported or ambiguous duplicate tracking; review this probe")
    body = body.replace(parse, f"let name = {KEY}(parseString())")
    if new:
        body = body.replace("HashSet<String>", f"HashSet<{KEY}>")
        if "String>" in body or "skipSeenNames" in body:
            raise ValueError(f"{filename}: uninstrumented skipped-name storage")
    source = source[:start] + body + source[end:]
    if old:
        declaration = 'private var skipSeenNames: Array<String> = Array<String>(16, repeat: "")'
        replacement = f'private var skipSeenNames: Array<{KEY}> = Array<{KEY}>(16, repeat: {KEY}(""))'
        if source.count(declaration) != 1:
            raise ValueError(f"{filename}: unsupported old name-storage declaration")
        source = source.replace(declaration, replacement)
        start, end = function_span(source, "ensureSkipSeenCapacity")
        growth = source[start:end]
        old_growth = 'Array<String>(skipSeenNames.size * 2, repeat: "")'
        if growth.count(old_growth) != 1:
            raise ValueError(f"{filename}: unsupported old name-storage growth")
        growth = growth.replace(old_growth, f'Array<{KEY}>(skipSeenNames.size * 2, repeat: {KEY}(""))')
        source = source[:start] + growth + source[end:]
    return source, "array-scan" if old else "hash-set"


def default_stack() -> None:
    # Set only child native stack to 8 MiB. The runtime's own managed stack
    # remains at its SDK default (cjStackSize is removed from its environment).
    assert resource is not None
    _, hard = resource.getrlimit(resource.RLIMIT_STACK)
    desired = 8192 * 1024
    if hard != resource.RLIM_INFINITY and hard < desired:
        raise RuntimeError("native stack hard limit is below the probe's 8192 KiB requirement")
    resource.setrlimit(resource.RLIMIT_STACK, (desired, hard))


def run(command: list[str], root: Path, log: Path, env: dict[str, str], timeout: int) -> int:
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout, preexec_fn=default_stack)
    return result.returncode


def parse_counts(output: str) -> list[dict[str, int | str]]:
    rows = []
    for kind, size, hashes, equals in re.findall(r"^YJSON_SKIP_WORK\|([^|\n]+)\|(\d+)\|(\d+)\|(\d+)$", output, re.M):
        rows.append({"reader": kind, "keys": int(size), "hashes": int(hashes), "equals": int(equals)})
    expected = {(kind, size) for kind in KINDS for size in SIZES}
    actual = {(row["reader"], row["keys"]) for row in rows}
    if actual != expected or len(rows) != len(expected):
        raise ValueError("probe must execute every reader/size once; incomplete or duplicated runtime rows")
    return rows


def check_counts(rows: list[dict[str, int | str]]) -> list[str]:
    errors = []
    for row in rows:
        # Includes real String hash calls and String comparisons, including
        # HashSet rehash/collision work. This is a deterministic small-input
        # work bound, not a millisecond performance threshold or baseline edit.
        size = int(row["keys"])
        work = int(row["hashes"]) + int(row["equals"])
        if work <= 0 or work > size * 12:
            errors.append(f'{row["reader"]}: {size} keys performed {work} hash/equality operations; limit {size * 12}')
    for kind in KINDS:
        work = [int(row["hashes"]) + int(row["equals"])
                for size in SIZES for row in rows if row["reader"] == kind and row["keys"] == size]
        if any(larger > smaller * 3 for smaller, larger in zip(work, work[1:])):
            errors.append(f"{kind}: doubling keys exceeded 3x measured work: {work}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository with product sources")
    parser.add_argument("--source-ref", help="read product files from this local Git ref instead of the worktree")
    parser.add_argument("--work-dir", type=Path, help="new diagnostic directory to retain source, logs and report")
    parser.add_argument("--timeout", type=int, default=600, help="per build/run timeout in seconds")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if resource is None:
        parser.error("this diagnostic requires Unix native stack control; Windows is not supported")
    if shutil.which("cjc") is None or shutil.which("cjpm") is None:
        parser.error("source a Cangjie SDK environment providing cjc and cjpm first")
    temporary = False
    passed = False
    if args.work_dir:
        root = args.work_dir.resolve()
        root.mkdir(parents=True, exist_ok=False)
    else:
        temporary = True
        root = Path(tempfile.mkdtemp(prefix="yjson-skip-work-"))
    try:
        product = sources(args.root.resolve(), args.source_ref)
        strategies = {}
        for reader in READERS:
            product[reader], strategies[reader] = instrument(product[reader], reader)
        source_dir = root / "src"
        source_dir.mkdir()
        for name, text in product.items():
            (source_dir / name).write_text(text, encoding="utf-8")
        (source_dir / "lib_skip_work_probe.cj").write_text(MEASURED_KEY, encoding="utf-8")
        (source_dir / "skip_work_probe_test.cj").write_text(PROBE, encoding="utf-8")
        (root / "cjpm.toml").write_text(MANIFEST, encoding="utf-8")
        env = dict(os.environ)
        env.pop("cjStackSize", None)
        version = subprocess.check_output(["cjc", "--version"], env=env, text=True).strip()
        build_status = run(["cjpm", "test", "--no-run", "--no-color"], root, root / "build.log", env, args.timeout)
        if build_status:
            raise RuntimeError(f"instrumented -O2 build failed ({build_status}); see {root / 'build.log'}")
        binary = root / "target/release/unittest_bin/yjson"
        run_status = run([str(binary), "--no-color", "--no-progress", "--show-all-output"], root,
                         root / "run.log", env, args.timeout)
        output = (root / "run.log").read_text(encoding="utf-8", errors="replace")
        if run_status or "PASSED: 1, SKIPPED: 0, ERROR: 0" not in output or "FAILED: 0" not in output:
            raise RuntimeError(f"runtime policy checks failed ({run_status}); see {root / 'run.log'}")
        rows = parse_counts(output)
        errors = check_counts(rows)
        report = {"compiler": version, "optimization": "-O2", "native_stack_kib": 8192,
                  "managed_stack": "SDK default", "source_ref": args.source_ref or "worktree",
                  "strategies": strategies, "measurements": rows, "errors": errors,
                  "result": "FAIL" if errors else "PASS"}
        (root / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        passed = not errors
        if args.work_dir:
            print(f"diagnostic sources and logs: {root}")
        return 1 if errors else 0
    finally:
        if temporary and passed:
            shutil.rmtree(root)
        elif temporary:
            print(f"failed diagnostic sources and logs retained: {root}", file=sys.stderr)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, ValueError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"skip work scaling check failed: {error}", file=sys.stderr)
        raise SystemExit(2)
