#!/usr/bin/env python3
"""Verify extracted evidence as data using only trusted checkout programs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile

p = argparse.ArgumentParser()
p.add_argument('--trusted', type=Path, required=True)
p.add_argument('--capsules', type=Path, required=True)
p.add_argument('--expected-main', required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.trusted = a.trusted.resolve()
a.capsules = a.capsules.resolve()
a.output = a.output.resolve()
sys.dont_write_bytecode = True
sys.path.insert(0, str(a.trusted / 'scripts'))
sys.path.insert(0, str(a.trusted / 'benchmarks/full-seven-library'))
import benchmark_input_identity as identity
import check_seven_library_evidence as checker
import run_full as runner
harness = a.capsules / 'seven-library-issue9-harness'
build = a.capsules / 'seven-library-issue9-build-audits/seven-build-audit'
receipt = json.loads((harness / 'provenance/production-export-receipt.json').read_text())
ready = json.loads((build / 'receipts/ready.json').read_text())
assert receipt['productionMain'] == ready['productionMain'] == a.expected_main
assert ready['status'] == 'PASS'
assert identity.product_manifest(a.trusted) == receipt['productManifest']
assert identity.harness_manifest(a.trusted) == receipt['harnessManifest']
for field, digest_field in [('productManifest', 'productSourceSha256'), ('harnessManifest', 'effectiveHarnessSha256')]:
    assert identity.manifest_digest(receipt[field]) == receipt[digest_field] == ready[digest_field]
    for relative, digest in receipt[field].items():
        assert runner.file_digest(harness / 'source-inputs/repo' / relative) == digest
for filename, source in [('run_full.py', a.trusted / 'benchmarks/full-seven-library/run_full.py'), ('summarize_full.py', a.trusted / 'benchmarks/full-seven-library/summarize_full.py'), ('benchmark_fixed_work.py', a.trusted / 'scripts/benchmark_fixed_work.py')]:
    assert (harness / filename).read_bytes() == source.read_bytes()
for name, digest in ready['sourceTreeDigests'].items():
    assert runner.source_digest(harness / 'source-inputs' / name) == digest
sdk = json.loads((build / 'receipts/sdk-manifest.json').read_text())
assert hashlib.sha256(json.dumps(sdk, sort_keys=True, indent=2).encode()).hexdigest() == ready['sdkManifestSha256']
trace = (build / 'yjson-build.execve.log').read_text()
assert '--fno-chir-function-inlining' not in trace
calls = []
for line in trace.splitlines():
    match = re.search(r'execve\(("(?:\\.|[^"\\])*")\s*,\s*(\[.*?\])', line)
    if not match:
        continue
    try:
        executable, argv = json.loads(match[1]), json.loads(match[2])
    except json.JSONDecodeError:
        continue
    if Path(executable).name not in ['cjc', 'cjc-frontend'] or '= -1 ' in line:
        continue
    if '--scan-dependency' in argv:
        role = 'dependency scan'
    elif any(x in argv for x in ['-v', '--version', '--help']):
        role = 'compiler introspection'
    elif '--compile-macro' in argv:
        role = 'compile-time macro'
    elif any(x.endswith('/build.cj') for x in argv):
        role = 'build helper'
    elif any(x.endswith('/testrunner.cj') for x in argv):
        role = 'unused test framework launcher'
    else:
        role = 'measured runtime or benchmark compilation'
    calls.append({'executable': executable, 'argv': argv, 'role': role})
assert {'status': 'PASS', 'calls': calls} == json.loads((build / 'receipts/yjson-compiler-argv.json').read_text())
argv_receipts = [calls]
for path in sorted((build / 'receipts').glob('api-groups-seven-batch-02-*-compiler-argv.json')):
    peer = json.loads(path.read_text())
    assert peer['status'] == 'PASS'
    argv_receipts.append(peer['calls'])
assert len(argv_receipts) == 4
for records in argv_receipts:
    measured = [call for call in records if call['role'] == 'measured runtime or benchmark compilation']
    assert measured and all('-O2' in call['argv'] and all(flag == '-O2' for flag in call['argv'] if flag.startswith('-O')) for call in measured)
marker = {'schema_version': 3, 'measured_commit': a.expected_main, 'product_source_sha256': receipt['productSourceSha256'], 'effective_harness_sha256': receipt['effectiveHarnessSha256']}
source_keys = {'yjson': 'repo', 'cangjieJSON_harness': 'harness/cjjson', 'json4cj_harness': 'harness/json4cj', 'cjfast_json': 'cjfast-json', 'java_harness': 'harness/java'}
artifact_keys = {'yjson': 'seven-yjson', 'stdx_json': 'seven-yjson', 'cangjieJSON': 'seven-cjjson', 'json4cj': 'seven-json4cj', 'cjfast_json': 'seven-cjfast'}
metadata_records = []
fixed_records = []
batch_records = []
with tempfile.TemporaryDirectory(prefix='seven-offline-', dir=a.output.parent) as temporary:
    tempfile.tempdir = temporary
    for number in [1, 2]:
        formal = a.capsules / f'seven-library-issue9-batch{number}'
        metadata, fixed = checker.read_metadata_and_validate(formal, marker)
        checker.regenerate_and_compare_summary(formal, a.trusted / 'benchmarks/full-seven-library/summarize_full.py', formal.name)
        assert metadata['source_sha256'] == {key: ready['sourceTreeDigests'][name] for key, name in source_keys.items()}
        assert metadata['versions']['json4cj_source_tree_sha256'] == ready['sourceTreeDigests']['json4cj']
        assert metadata['versions']['cangjieJSON_source_tree_sha256'] == ready['sourceTreeDigests']['cangjieJSON-upstream']
        for key, name in artifact_keys.items():
            assert metadata['cangjie_binaries'][key]['sha256'] == ready['artifacts'][name]['sha256']
            assert 'workspace/' + metadata['cangjie_binaries'][key]['path'] == ready['artifacts'][name]['path']
        qualification = json.loads((formal / 'qualification.json').read_text())
        assert qualification['status'] == 'PASS' and qualification['formalCells'] == qualification['positiveRssSidecars'] == 770
        assert qualification['yjsonFixedWorkProofs'] == 110 and qualification['sourceSdkArtifactIdentityUnchanged'] is True
        state = json.loads((formal / 'task-control/state.json').read_text())
        assert state['status'] == 'COMPLETE' and state['returnCode'] == 0 and state['retry'] is False and state['buildDuringTiming'] is False
        assert runner.file_digest(formal / 'task-control/driver.py') == state['driverSha256']
        metadata_records.append(metadata)
        fixed_records.append(fixed)
        batch_records.append({'batch': number, 'startedAtUtc': state['startedAtUtc'], 'finishedAtUtc': state['finishedAtUtc'], 'stableRows': qualification['stableRows'], 'noisyRows': qualification['noisyRows']})
assert fixed_records[0] == fixed_records[1]
for key in checker.STABLE_METADATA_KEYS:
    assert checker.stable_identity(metadata_records[0], key) == checker.stable_identity(metadata_records[1], key)
result = {'status': 'PASS', 'productionMain': a.expected_main, 'productionMacro': receipt['productionMacro'], 'productSourceSha256': receipt['productSourceSha256'], 'effectiveHarnessSha256': receipt['effectiveHarnessSha256'], 'formalCells': 1540, 'positiveRssCells': 1540, 'fixedWorkCells': 220, 'allSevenSourceDigestsRecomputed': True, 'completeProductAndHarnessPayloadsVerified': True, 'rawSummariesIndependentlyRegenerated': True, 'productionExecveRecomputed': True, 'productionAndReusedPeerCompilerArgvExplicitO2': True, 'sdkManifestSha256': ready['sdkManifestSha256'], 'batches': batch_records, 'archivedProgramsExecuted': False, 'verifierSha256': runner.file_digest(Path(__file__))}
a.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
