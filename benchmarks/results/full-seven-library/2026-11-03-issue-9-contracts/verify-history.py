#!/usr/bin/env python3
"""Read data only; independently replay diagnostic statistics and source hashes."""
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import statistics
import tarfile
import sys

p = argparse.ArgumentParser()
p.add_argument('--packet', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--trusted', type=Path, required=True)
a = p.parse_args()
sys.dont_write_bytecode = True
sys.path.insert(0, str(a.trusted / 'scripts'))
import benchmark_pure_direct as direct
with tarfile.open(a.packet, 'r:gz') as package:
    members = package.getmembers()
    assert len(members) == 1638
    files = {}
    for member in members:
        assert member.isfile() and not member.name.startswith('/') and '..' not in PurePosixPath(member.name).parts
        assert member.name not in files
        files[member.name] = package.extractfile(member).read()
root = 'issue-9-diagnostic-history/'
receipt = json.loads(files[root + 'source-receipt.json'])
assert receipt['measurementStatus'] == 'DIAGNOSTIC_ONLY'
source_records = receipt['sources']
assert [x['name'] for x in source_records] == ['pure-candidate', 'capacity-fit', 'capacity-fit-pair', 'capacity-fit-limit']
def digest_manifest(manifest):
    return hashlib.sha256(b''.join(name.encode() + b'\0' + value.encode() + b'\n' for name, value in sorted(manifest.items()))).hexdigest()
for source in source_records:
    prefix = root + 'source-inputs/' + source['name'] + '/'
    expected = source['productManifest'] | source['harnessManifest'] | source['macroSourceManifest']
    assert {name[len(prefix):] for name in files if name.startswith(prefix)} == set(expected)
    for name, digest in expected.items():
        assert hashlib.sha256(files[prefix + name]).hexdigest() == digest
    assert digest_manifest(source['productManifest']) == source['productSourceSha256']
    assert digest_manifest(source['harnessManifest']) == source['effectiveHarnessSha256']
assert len({x['effectiveHarnessSha256'] for x in source_records}) == 1
for left, right in zip(source_records, source_records[1:]):
    assert left['harnessManifest'] == right['harnessManifest']
    assert left['macroSourceManifest'] == right['macroSourceManifest']
    changed = {name for name in left['productManifest'].keys() | right['productManifest'].keys() if left['productManifest'].get(name) != right['productManifest'].get(name)}
    assert changed == {'src/lib_json_direct_writer.cj'}
def same(x, y):
    assert math.isclose(x, y, rel_tol=1e-12, abs_tol=1e-10), (x, y)
matrices = []
timed = preflight = 0
for name, data in sorted(files.items()):
    if PurePosixPath(name).name != 'summary.json':
        continue
    summary = json.loads(data)
    assert summary['rounds'] == 3
    cases = summary['cases']
    directory = str(PurePosixPath(name).parent) + '/'
    expected_cells = {(variant, case, round_) for variant in ['baseline', 'candidate'] for case in cases for round_ in range(1, 4)}
    observed = set()
    for phase, cells in [('sample', summary['direct_cells']), ('preflight', summary['preflight_cells'])]:
        assert len(cells) == len(cases) * 2 * (3 if phase == 'sample' else 1)
        for cell in cells:
            sidecar = json.loads(files[directory + cell['sidecar']])
            assert sidecar['status'] == 'passed' and sidecar['verified_before_release']
            assert sidecar['unittest_failed'] == sidecar['unittest_errors'] == 0
            assert sidecar['unittest_passed'] == 1 and sidecar['qualification_phase'] == phase
            for key in ['case', 'operations', 'elapsed_ns', 'warmup_ns', 'segments', 'max_rss_kb', 'role_placement']:
                assert cell[key] == sidecar[key]
            assert cell['operations'] > 0 and cell['elapsed_ns'] > 0 and cell['max_rss_kb'] > 0
            cpus = summary['cpu']['selected_cpus']
            assert sidecar['selected_cpus'] == cpus
            assert set(sidecar['role_placement']) == set(direct.EXPECTED_THREAD_ROLES)
            for role, placement in sidecar['role_placement'].items():
                expected_cpu = cpus[direct.ROLE_CORE_INDEX[role]]
                assert placement['cpu'] == expected_cpu and placement['mask'] == [expected_cpu]
            base = cell['sidecar'].removesuffix('.direct.json')
            parsed = direct.parse_direct_result(files[directory + base + '.log'].decode(), cell['case'])
            for field in ['operations', 'elapsed_ns', 'warmup_ns', 'segments']:
                assert parsed[field] == cell[field]
            same(parsed['ns_per_operation'], cell['elapsed_ns'] / cell['operations'])
            rss = re.findall(r'Maximum resident set size \(kbytes\):\s*(\d+)', files[directory + base + '.rss.txt'].decode())
            assert rss == [str(cell['max_rss_kb'])]
            if phase == 'sample':
                key = (cell['variant'], cell['case'], cell['round'])
                assert key not in observed
                observed.add(key)
                same(cell['elapsed_ns'] / cell['operations'], summary['raw_median_ns'][cell['variant']][cell['case']][cell['round'] - 1])
                assert cell['max_rss_kb'] == summary['raw_max_rss_kb'][cell['variant']][cell['case']][cell['round'] - 1]
                timed += 1
            else:
                preflight += 1
    assert observed == expected_cells
    for case in cases:
        for variant in ['baseline', 'candidate']:
            values = summary['raw_median_ns'][variant][case]
            rss = summary['raw_max_rss_kb'][variant][case]
            stats = summary[variant][case]
            same(statistics.median(values), stats['median_ns'])
            same(statistics.mean(values), stats['mean_ns'])
            same(statistics.stdev(values) / statistics.mean(values) * 100, stats['cv_percent'])
            assert rss == stats['rss_kb'] and max(rss) == stats['max_rss_kb']
            same(statistics.median(rss), stats['median_rss_kb'])
        comparison = summary['comparisons'][case]
        ratio = statistics.median(summary['raw_median_ns']['candidate'][case]) / statistics.median(summary['raw_median_ns']['baseline'][case])
        same(ratio, comparison['ratio'])
        same((1 - ratio) * 100, comparison['improvement_percent'])
        assert comparison['candidate_wins'] == sum(c < b for c, b in zip(summary['raw_median_ns']['candidate'][case], summary['raw_median_ns']['baseline'][case]))
    matrices.append({'summary': name, 'rounds': 3, 'cases': len(cases), 'originalGates': summary['gates']})
assert len(matrices) == 8 and timed == 150 and preflight == 50
result = {'status': 'PASS', 'measurementStatus': 'DIAGNOSTIC_ONLY', 'archiveSha256': hashlib.sha256(a.packet.read_bytes()).hexdigest(), 'verifierSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'archivedProgramsExecuted': False, 'sourceVariants': 4, 'adjacentChangesWriterOnly': True, 'pairedMatrices': matrices, 'timedCells': timed, 'preflightCells': preflight, 'rawTimingSidecarsRssAffinityAndStatisticsRecomputed': True, 'intrusiveStackLogs': 'Retained verbatim, not treated as timings or causal proof.', 'qualification': 'No formal qualification inferred from these diagnostics; original gates retained.'}
a.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: result[key] for key in ['status', 'measurementStatus', 'sourceVariants', 'timedCells', 'preflightCells']}, indent=2))
