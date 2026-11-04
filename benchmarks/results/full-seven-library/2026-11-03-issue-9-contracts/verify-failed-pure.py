#!/usr/bin/env python3
"""Verify a retained complete failed batch, without turning failure into success."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys
from offline_compiler_audit import verify_compiler_audit

parser = argparse.ArgumentParser()
parser.add_argument('--trusted', type=Path, required=True)
parser.add_argument('--capsule', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--expected-main', required=True)
parser.add_argument('--expected-product', required=True)
parser.add_argument('--expected-overruns', type=int, required=True)
args = parser.parse_args()
sys.dont_write_bytecode = True
sys.path.insert(0, str(args.trusted / 'scripts'))
import benchmark_input_identity as identity
import benchmark_pure_direct as direct
import json_pure_perf_compare as compare

root = args.capsule
receipt = json.loads((root / 'task-control/pure-snapshot-receipt.json').read_text())
folder = root / 'results/pure-release-issue9-batch1'
summary = json.loads((folder / 'summary.json').read_text())
provenance = json.loads((folder / 'provenance.json').read_text())
state = json.loads((root / 'task-control/pure-release-issue9-batch1.json').read_text())
assert state['status'] == 'FAIL' and state['returnCode'] != 0
assert state['productionMain'] == receipt['productionMain']
assert receipt['productionMain'] == args.expected_main
assert receipt['snapshots']['pure-candidate']['productSourceSha256'] == args.expected_product
for helper in ['scripts/benchmark_input_identity.py', 'scripts/benchmark_pure_direct.py', 'scripts/json_pure_perf_compare.py']:
    assert hashlib.sha256((args.trusted / helper).read_bytes()).hexdigest() == receipt['snapshots']['pure-candidate']['harnessManifest'][helper]
for name, expected in receipt['snapshots'].items():
    snapshot = root / 'source-inputs' / name
    assert identity.product_manifest(snapshot) == expected['productManifest']
    assert identity.manifest_digest(expected['productManifest']) == expected['productSourceSha256']
    assert identity.harness_manifest(snapshot) == expected['harnessManifest']
    assert identity.manifest_digest(expected['harnessManifest']) == receipt['commonHarnessSha256']
assert summary['provenance'] == provenance
assert summary['cases'] == list(compare.CASES) and summary['rounds'] == 11
assert summary['heap'] == '128MB' and summary['cj_processor_num'] == 1
assert summary['gate_mode'] == 'release' and summary['target_cases'] == []
assert provenance['invocation']['rebuild'] is True and provenance['invocation']['enforce'] is True
assert provenance['harness_sha256'] == receipt['commonHarnessSha256']
for variant, name in [('baseline', 'pure-baseline'), ('candidate', 'pure-candidate')]:
    expected = receipt['snapshots'][name]
    before, after = provenance['sources'][variant], provenance['post_build_sources'][variant]
    assert before == after and before['dirty'] is False and before['dirty_paths'] == []
    assert before['commit'] == expected['commit'] and before['tree'] == expected['tree']
    assert before['product_source_manifest'] == expected['productManifest']
    assert before['product_source_sha256'] == expected['productSourceSha256']
cpus = summary['cpu']['selected_cpus']
assert len(cpus) == len(set(cpus)) == 3
assert summary['cpu']['acceptable_all_threads_below_1_percent'] is True
for core in summary['cpu']['physical_cores']:
    assert all(value < 1 for value in core['utilization_percent'].values())
cases = list(compare.CASES)
samples = {variant: {case: [] for case in cases} for variant in ('baseline', 'candidate')}
rss_samples = {variant: {case: [] for case in cases} for variant in ('baseline', 'candidate')}
observed = []
assert len(summary['preflight_cells']) == 48 and len(summary['direct_cells']) == 528
for cell in summary['preflight_cells'] + summary['direct_cells']:
    case, variant = cell['case'], cell['variant']
    sidecar_path = folder / cell['sidecar']
    sidecar = json.loads(sidecar_path.read_text())
    assert sidecar['status'] == 'passed' and sidecar['stage'] == 'complete'
    log_path = sidecar_path.with_name(sidecar_path.name.removesuffix('.direct.json') + '.log')
    rss_path = sidecar_path.with_name(sidecar_path.name.removesuffix('.direct.json') + '.rss.txt')
    parsed = direct.parse_direct_result(log_path.read_text(), case)
    rss = compare.parse_max_rss(rss_path)
    for field in ('operations', 'elapsed_ns', 'warmup_ns', 'segments'):
        assert parsed[field] == sidecar[field] == cell[field]
    assert rss == sidecar['max_rss_kb'] == cell['max_rss_kb'] and rss > 0
    assert sidecar['qualification_phase'] == cell['qualification_phase']
    assert sidecar['role_placement'] == cell['role_placement']
    assert set(sidecar['role_placement']) == set(direct.EXPECTED_THREAD_ROLES)
    for role, placement in sidecar['role_placement'].items():
        expected_cpu = cpus[direct.ROLE_CORE_INDEX[role]]
        assert placement['cpu'] == expected_cpu and placement['mask'] == [expected_cpu]
    observed.append((cell['qualification_phase'], cell.get('round', 0), case, variant))
    if cell['qualification_phase'] == 'sample':
        samples[variant][case].append(parsed['ns_per_operation'])
        rss_samples[variant][case].append(rss)
assert observed == list(compare.qualification_schedule(tuple(cases), 11))
assert samples == summary['raw_median_ns'] and rss_samples == summary['raw_max_rss_kb']
comparisons = {}
all_stable = True
for case in cases:
    medians = {}
    for variant in ('baseline', 'candidate'):
        values = samples[variant][case]
        median = statistics.median(values)
        mean = statistics.mean(values)
        cv = statistics.stdev(values) / mean * 100
        recorded = summary[variant][case]
        for field, actual in [('median_ns', median), ('mean_ns', mean), ('cv_percent', cv)]:
            assert math.isclose(actual, recorded[field], rel_tol=1e-12, abs_tol=1e-12)
        assert recorded['rss_kb'] == rss_samples[variant][case]
        assert recorded['median_rss_kb'] == statistics.median(rss_samples[variant][case])
        assert recorded['max_rss_kb'] == max(rss_samples[variant][case])
        medians[variant] = median
        all_stable = all_stable and cv <= 5
    ratio = medians['candidate'] / medians['baseline']
    recorded = summary['comparisons'][case]
    assert math.isclose(ratio, recorded['ratio'], rel_tol=1e-12)
    assert math.isclose((1-ratio)*100, recorded['improvement_percent'], rel_tol=1e-12, abs_tol=1e-12)
    assert sum(c < b for b, c in zip(samples['baseline'][case], samples['candidate'][case])) == recorded['candidate_wins']
    comparisons[case] = recorded
actual_gates = compare.evaluate_gates(tuple(cases), comparisons, summary['baseline'], summary['candidate'], 'release', (), None)
assert actual_gates == summary['gates'] and actual_gates['passed'] is False
assert all_stable
compiler_replay = verify_compiler_audit(folder, 'pure-baseline', args.output.parent)
overruns = {case:value for case,value in comparisons.items() if value['ratio'] > 1.05}
assert len(overruns) == args.expected_overruns
result = {'status':'PASS', 'measurementStatus':'FAIL', 'productionMain':receipt['productionMain'], 'productionMacro':receipt['productionMacro'], 'cases':24, 'rounds':11, 'directCells':528, 'preflightCells':48, 'allRowsStable':all_stable, 'overruns':overruns, 'sourceIdentityAndPostBuildCleanliness':True, 'rawLogRssSidecarAndAffinityReplay':True, 'independentMedianCvRatioAndPairedWins':True, 'archivedProgramsExecuted':False, 'scope':'Trusted-checkout parsing and independent arithmetic reproduce the retained complete stable regression. PASS describes verification only; qualification remains FAIL.'}
result['verifierSha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
result['compilerAuditReplay'] = compiler_replay
args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps(result,indent=2))
