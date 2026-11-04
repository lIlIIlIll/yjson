#!/usr/bin/env python3
"""Recompute immutable paired evidence with trusted checkout code only."""
import argparse
import collections
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import statistics
import sys
from offline_compiler_audit import verify_compiler_audit

parser = argparse.ArgumentParser()
parser.add_argument('--trusted', required=True, type=Path)
parser.add_argument('--results', required=True, type=Path)
parser.add_argument('--sources', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
sys.dont_write_bytecode = True
sys.path.insert(0, str(args.trusted / 'scripts'))
import benchmark_input_identity as identity
import benchmark_pure_direct as direct
import json_pure_perf_compare as compare
receipt = json.loads((args.sources / 'provenance/pure-snapshot-receipt.json').read_text())
qualified = json.loads((args.results / 'task-control/pure-qualified.json').read_text())
assert qualified['status'] == 'PASS'
assert receipt['productionMain'] == qualified['productionMain']
assert receipt['productionMacro'] == qualified['productionMacro']
corpus = json.loads((args.sources / 'provenance/corpus-manifest.json').read_text())
assert len(corpus['manifest']) == 3
assert identity.manifest_digest(corpus['manifest']) == corpus['sha256'] == 'db9b0242e01fb4cfa2468245f8be5329a0967052412b7340f12c468c6202a70f'
for relative, value in corpus['manifest'].items():
    assert hashlib.sha256((args.sources / 'corpus' / relative).read_bytes()).hexdigest() == value

for name, expected in receipt['snapshots'].items():
    snapshot = args.sources / 'snapshots' / name
    assert identity.product_manifest(snapshot) == expected['productManifest'], name
    assert identity.harness_manifest(snapshot) == expected['harnessManifest'], name
    assert identity.manifest_digest(expected['harnessManifest']) == receipt['commonHarnessSha256']
    macro = snapshot / 'packages/yjson_macros'
    for relative, value in expected['macroSourceManifest'].items():
        assert hashlib.sha256((macro / relative).read_bytes()).hexdigest() == value, (name, relative)
        assert expected['macroOriginManifest'][relative] == value
    required = {relative for relative in expected['macroOriginManifest'] if (relative.startswith('src/') and relative.endswith('.cj')) or relative in ('cjpm.toml', 'cjpm.lock', 'build.cj')}
    assert required <= set(expected['macroSourceManifest'])
    actual_sources = {path.relative_to(macro).as_posix() for path in (macro / 'src').rglob('*.cj')}
    assert actual_sources == {relative for relative in required if relative.startswith('src/')}
    for relative, value in expected['macroOriginManifest'].items():
        origin = args.sources / 'macro-origins' / expected['macroSourceCommit'] / relative
        assert hashlib.sha256(origin.read_bytes()).hexdigest() == value, (name, relative)
    if expected['macroSourceCommit'] == receipt['productionMacro']:
        for relative in required:
            assert hashlib.sha256((args.trusted / 'packages/yjson_macros' / relative).read_bytes()).hexdigest() == expected['macroOriginManifest'][relative]
assert identity.product_manifest(args.trusted) == receipt['snapshots']['pure-candidate']['productManifest']

records = {}
required_runs = {Path(qualified['releaseOutput']).name, Path(qualified['headDeepOutput']).name}
assert len(required_runs) == 2
folders = sorted((args.results / 'results').iterdir())
assert {folder.name for folder in folders} == required_runs
assert all(folder.is_dir() for folder in folders)
for folder in folders:
    summary = json.loads((folder / 'summary.json').read_text())
    provenance = json.loads((folder / 'provenance.json').read_text())
    assert provenance['corpus'] == corpus
    state = json.loads((args.results / 'logs' / (folder.name + '.json')).read_text())
    assert state['status'] == 'PASS' and state['returnCode'] == 0
    assert state['productionMain'] == receipt['productionMain']
    assert summary['provenance'] == provenance
    release = 'pure-release-' in folder.name
    cases = list(compare.CASES) if release else ['yjsonStringDecodeDeepNestedProfiles', 'yjsonBytesDecodeDeepNestedProfiles']
    assert summary['cases'] == cases
    assert summary['rounds'] == 11 and summary['heap'] == '128MB' and summary['cj_processor_num'] == 1
    assert summary['gate_mode'] == 'release' and summary['target_cases'] == []
    assert provenance['invocation']['rebuild'] is True
    assert provenance['invocation']['enforce'] is release
    assert provenance['harness_sha256'] == receipt['commonHarnessSha256']
    baseline_name = 'pure-baseline' if release else 'pure-head'
    for variant, snapshot_name in [('baseline', baseline_name), ('candidate', 'pure-candidate')]:
        expected = receipt['snapshots'][snapshot_name]
        before, after = provenance['sources'][variant], provenance['post_build_sources'][variant]
        assert before == after
        assert before['commit'] == expected['commit'] and before['tree'] == expected['tree']
        assert before['dirty'] is False and before['dirty_paths'] == []
        assert before['product_source_manifest'] == expected['productManifest']
        assert before['product_source_sha256'] == expected['productSourceSha256']
    assert summary['cpu']['acceptable_all_threads_below_1_percent'] is True
    cpus = summary['cpu']['selected_cpus']
    assert len(cpus) == len(set(cpus)) == 3
    for core in summary['cpu']['physical_cores']:
        assert all(value < 1 for value in core['utilization_percent'].values())
    samples = {variant: {case: [] for case in cases} for variant in ('baseline', 'candidate')}
    rss_samples = {variant: {case: [] for case in cases} for variant in ('baseline', 'candidate')}
    observed = []
    cells = summary['preflight_cells'] + summary['direct_cells']
    assert len(summary['preflight_cells']) == len(cases) * 2
    assert len(summary['direct_cells']) == len(cases) * 22
    for cell in cells:
        case, variant = cell['case'], cell['variant']
        sidecar_path = folder / cell['sidecar']
        sidecar = json.loads(sidecar_path.read_text())
        assert sidecar['status'] == 'passed' and sidecar['stage'] == 'complete'
        assert sidecar['qualification_phase'] == cell['qualification_phase']
        log_path = sidecar_path.with_name(sidecar_path.name.removesuffix('.direct.json') + '.log')
        rss_path = sidecar_path.with_name(sidecar_path.name.removesuffix('.direct.json') + '.rss.txt')
        parsed = direct.parse_direct_result(log_path.read_text(), case)
        rss = compare.parse_max_rss(rss_path)
        for field in ('operations', 'elapsed_ns', 'warmup_ns', 'segments'):
            assert parsed[field] == sidecar[field] == cell[field], (case, field)
        assert rss == sidecar['max_rss_kb'] == cell['max_rss_kb']
        assert sidecar['role_placement'] == cell['role_placement']
        assert set(sidecar['role_placement']) == set(direct.EXPECTED_THREAD_ROLES)
        for role, placement in sidecar['role_placement'].items():
            expected_cpu = cpus[direct.ROLE_CORE_INDEX[role]]
            assert placement['cpu'] == expected_cpu and placement['mask'] == [expected_cpu]
        phase = cell['qualification_phase']
        number = cell.get('round', 0)
        observed.append((phase, number, case, variant))
        if phase == 'sample':
            samples[variant][case].append(parsed['ns_per_operation'])
            rss_samples[variant][case].append(rss)
    assert observed == list(compare.qualification_schedule(tuple(cases), 11))
    assert samples == summary['raw_median_ns']
    assert rss_samples == summary['raw_max_rss_kb']
    comparisons = {}
    for case in cases:
        statistics_by_variant = {}
        for variant in ('baseline', 'candidate'):
            values = samples[variant][case]
            assert len(values) == 11
            median = statistics.median(values)
            mean = statistics.mean(values)
            cv = statistics.stdev(values) / mean * 100
            recorded = summary[variant][case]
            for field, actual in [('median_ns', median), ('mean_ns', mean), ('cv_percent', cv)]:
                assert math.isclose(actual, recorded[field], rel_tol=1e-12, abs_tol=1e-12), (case, variant, field)
            assert recorded['rss_kb'] == rss_samples[variant][case]
            assert recorded['median_rss_kb'] == statistics.median(rss_samples[variant][case])
            assert recorded['max_rss_kb'] == max(rss_samples[variant][case])
            statistics_by_variant[variant] = median
        ratio = statistics_by_variant['candidate'] / statistics_by_variant['baseline']
        wins = sum(candidate < baseline for baseline, candidate in zip(samples['baseline'][case], samples['candidate'][case]))
        recorded = summary['comparisons'][case]
        assert math.isclose(ratio, recorded['ratio'], rel_tol=1e-12)
        assert math.isclose((1 - ratio) * 100, recorded['improvement_percent'], rel_tol=1e-12, abs_tol=1e-12)
        assert wins == recorded['candidate_wins'] and ratio <= 1.05
        comparisons[case] = recorded
    gates = compare.evaluate_gates(tuple(cases), comparisons, summary['baseline'], summary['candidate'], 'release', (), None)
    assert gates == summary['gates'] and gates['passed'] is True
    compiler_replay = verify_compiler_audit(folder, baseline_name, args.output.parent)
    records[folder.name] = {'status': 'PASS', 'cases': len(cases), 'rounds': 11, 'directCells': len(summary['direct_cells']), 'preflightCells': len(summary['preflight_cells']), 'sourceIdentityAndPostBuildCleanliness': True, 'rawSidecarTimingFieldsMatched': True, 'threadAffinityAndFrozenWorkValidated': True, 'independentMedianCvRatioAndPairedWins': True, 'allRatiosAtMost1_05': True}
    records[folder.name]['compilerAuditReplay'] = compiler_replay
result = {'status': 'PASS', 'productionMain': receipt['productionMain'], 'productionMacro': receipt['productionMacro'], 'qualifiedRuns': records, 'scope': 'Independent arithmetic, retained raw log/RSS/sidecar and affinity replay plus source closure verification using trusted checkout code only. No archived program executed.'}
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
