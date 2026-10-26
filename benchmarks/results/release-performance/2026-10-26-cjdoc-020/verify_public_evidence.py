#!/usr/bin/env python3
"""Verify the published Pure review layer using Python's standard library only.

This checks retained records and hashes; it does not rerun benchmarks or restore Git history.
"""
import argparse
import hashlib
import io
import ipaddress
import json
import math
import re
import statistics
import tarfile
from pathlib import Path, PurePosixPath


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_archive(data):
    if not __debug__:
        raise RuntimeError('Verification requires Python assertions; do not use -O or PYTHONOPTIMIZE')
    assert data[:3] == b'\x1f\x8b\x08' and data[3] == 0 and data[4:8] == b'\0' * 4, 'gzip metadata'
    result = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        names = []
        for entry in archive:
            path = PurePosixPath(entry.name)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in entry.name
            assert '.git' not in path.parts and entry.isfile(), ('not a source-only regular member', entry.name)
            assert entry.name not in result, ('duplicate member', entry.name)
            assert (entry.uid, entry.gid, entry.uname, entry.gname, entry.mtime) == (0, 0, '', '', 0)
            assert entry.mode in (0o644, 0o755) and not entry.pax_headers
            content = archive.extractfile(entry).read()
            assert not content.startswith((b'\x7fELF', b'!<arch>\n', b'MZ'))
            assert content[:4] not in [bytes.fromhex(x) for x in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe')]
            result[entry.name] = content
            names.append(entry.name)
        assert names == sorted(names)
    return result


def check_text(data, name):
    text = data.decode('utf-8')
    for pattern in (
        r'/(?:home|Users)/[A-Za-z0-9_.-]+/', r'/(?:mnt)/', r'/run/user/\d+',
        r'(?:ghp_|github_pat_|AKIA)[A-Za-z0-9_]{12,}',
        r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----',
        r'\b(?:root|user)@[^\s:]+',
    ):
        assert not re.search(pattern, text), ('private environment or credential', name)
    if name.endswith('.json'):
        def reject_git_objects(value):
            if isinstance(value, dict):
                assert not {'tree', 'parents', 'author', 'committer', 'message'} <= set(value), ('Git commit object', name)
                for child in value.values():
                    reject_git_objects(child)
            elif isinstance(value, list):
                for child in value:
                    reject_git_objects(child)
        reject_git_objects(json.loads(text))
    for token in re.findall(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])', text):
        try:
            address = ipaddress.ip_address(token)
        except ValueError:
            continue
        # The sole version-like token is the recorded stdx 1.2.0.1 version.
        assert not address.is_private or token in ('1.2.0.1', '0.0.0.0', '127.0.0.1') or token.startswith(('192.0.2.', '198.51.100.', '203.0.113.')), ('private address', name)


def close(actual, expected):
    assert math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-10), (actual, expected)


def verify_batch(directory, label, record):
    blob = (directory / record['public_archive']).read_bytes()
    assert digest(blob) == record['public_archive_sha256']
    entries = load_archive(blob)
    assert len(entries) == record['public_regular_files']
    expected_members = {row['public_member'] for row in record['files'].values() if row['public_member'] is not None}
    assert set(entries) == expected_members | {'public-layer/source-and-binary-receipt.json'}
    nested_sources = {}
    for original, row in record['files'].items():
        name = row['public_member']
        if name is None:
            assert row['disposition'] == 'excluded-compiled-binary'
            continue
        data = entries[name]
        assert digest(data) == row['public_sha256'] and len(data) == row['public_size_bytes']
        if row['disposition'] == 'byte-identical':
            assert row['public_sha256'] == row['original_sha256'] and not row['replacements']
        if name.endswith('.tar.gz'):
            source_manifest = json.loads((directory / row['source_manifest']).read_text())
            assert digest(data) == source_manifest['public_archive_sha256']
            assert source_manifest['original_capsule_sha256'] == row['original_sha256']
            source_entries = load_archive(data)
            assert len(source_entries) == source_manifest['source_files'] and set(source_entries) == set(source_manifest['files'])
            for source_name, content in source_entries.items():
                check_text(content, source_name)
                receipt = source_manifest['files'][source_name]
                assert digest(content) == receipt['original_sha256'] == receipt['public_sha256']
                assert len(content) == receipt['size_bytes'] and receipt['replacements'] == {}
                git_blob = b'blob ' + str(len(content)).encode() + b'\0' + content
                assert hashlib.sha1(git_blob).hexdigest() == receipt['matches_original_git_blob']
            root = source_manifest['role']
            body = ''.join(f'{digest(content)}  {name[len(root) + 1:]}\n' for name, content in sorted(source_entries.items())).encode()
            assert digest(body) == source_manifest['source_file_sha256_manifest_digest']
            nested_sources[root] = {name[len(root) + 1:]: data for name, data in source_entries.items()}
        else:
            check_text(data, name)
    root = next(name.rsplit('/', 1)[0] for name in entries if name.endswith('/summary.json'))
    summary = json.loads(entries[root + '/summary.json'])
    provenance = json.loads(entries[root + '/provenance.json'])
    assert len(summary['cases']) == 24 and len(set(summary['cases'])) == 24 and summary['rounds'] == 11
    assert summary['gate_mode'] == 'release' and summary['heap'] == '128MB' and summary['cj_processor_num'] == 1
    assert summary['direct_timing_protocol'] == 1 and summary['harness_sha256'] == provenance['harness_sha256']
    assert len(summary['preflight_cells']) == 48 and len(summary['direct_cells']) == 528
    assert provenance['toolchain']['tools']['cjc']['sha256'] == '023be1bb2ded1078906fc91919b3c1175ad14436ad88d23d505f7b8dcd0d7118'
    assert provenance['toolchain']['tools']['cjpm']['sha256'] == 'a565d86540656c62340aacf6ac89c175b50c1f4d9ba4f69cee6a0fdacdee412d'
    for variant in ('baseline', 'candidate'):
        original_source = provenance['sources'][variant]
        role = 'pure-baseline' if variant == 'baseline' else 'pure-candidate-' + label
        source_receipt = next(x for x in record['source_trees'] if x['manifest'] == role + '-source-manifest.json')
        assert source_receipt['original_commit'] == original_source['commit'] and source_receipt['original_tree'] == original_source['tree']
        for relative, sha in original_source['product_source_manifest'].items():
            assert digest(nested_sources[role][relative]) == sha, ('source provenance mismatch', role, relative)
        artifact = provenance['artifacts'][variant]
        assert any(artifact['sha256'] == x['sha256'] and artifact['size_bytes'] == x['size_bytes'] for x in record['compiled_binary_omissions'])
    samples = {(variant, case): [] for variant in ('baseline', 'candidate') for case in summary['cases']}
    rss_samples = {key: [] for key in samples}
    seen = set()
    preflight_seen = set()
    for cell in summary['preflight_cells'] + summary['direct_cells']:
        case, variant = cell['case'], cell['variant']
        sidecar = cell['sidecar']
        stamp = sidecar.removesuffix('.direct.json')
        direct = json.loads(entries[root + '/' + sidecar])
        log = entries[root + '/' + stamp + '.log'].decode()
        rss = entries[root + '/' + stamp + '.rss.txt'].decode()
        assert direct['status'] == 'passed' and direct['stage'] == 'complete' and direct['verified_before_release']
        assert direct['case'] == case and direct['protocol_version'] == 1 and direct['marker'] == 'YJSON_PURE_DIRECT_V1'
        assert (direct['unittest_passed'], direct['unittest_errors'], direct['unittest_failed']) == (1, 0, 0)
        selected_test = 'pureFixedDocument' if case.startswith('parse') else 'pureFixedStream' if case.startswith(('decode', 'encode')) else 'pureFixedComprehensive'
        assert direct['command'] == [provenance['artifacts'][variant]['path'], '--no-color', '--no-progress', '--filter=*.' + selected_test]
        assert '[ PASSED ] CASE: ' + selected_test + ' ' in log and 'FAILED: 0' in log and 'ERROR: 0' in log
        marker = re.findall(r'^YJSON_PURE_DIRECT_V1 case=(\S+) operations=(\d+) elapsed_ns=(\d+) warmup_ns=(\d+) segments=(\d+)$', log, re.M)
        assert len(marker) == 1
        raw_case, operations, elapsed, warmup, segments = marker[0]
        assert raw_case == case
        for key, value in (('operations', operations), ('elapsed_ns', elapsed), ('warmup_ns', warmup), ('segments', segments)):
            assert int(value) == direct[key] == cell[key]
        fixed = summary['fixed_work'][case]
        assert int(operations) == fixed['operations'] == fixed['batches'] * fixed['batch_size']
        assert int(warmup) >= fixed['minimum_warmup_ns'] and int(segments) == fixed['segments']
        assert f'YJSON_FIXED_WORK_V1 case={case} batches={fixed["batches"]} batch_size={fixed["batch_size"]}' in log
        rss_match = re.search(r'Maximum resident set size \(kbytes\):\s*(\d+)', rss)
        assert rss_match and int(rss_match[1]) == direct['max_rss_kb'] == cell['max_rss_kb']
        assert re.search(r'Exit status:\s*0(?:\n|$)', rss)
        cpus = direct['selected_cpus']
        assert cpus == summary['cpu']['selected_cpus'] and len(set(cpus)) == 3
        roles = direct['role_placement']
        assert roles == cell['role_placement'] and set(roles) == set(direct['discovered_thread_roles'])
        assert all(placement['tid'] == direct['discovered_thread_roles'][role] for role, placement in roles.items())
        for role, cpu in (('yjson_benchmark', cpus[0]), ('gc-main-thread', cpus[1]), ('gc-helper', cpus[1]), ('gc-pool-t1', cpus[2]), ('schmon', cpus[2])):
            assert roles[role]['cpu'] == cpu and roles[role]['mask'] == [cpu]
        assert entries[root + '/control/' + stamp + '/continue'] == (case + '\n').encode()
        assert entries[root + '/control/' + stamp + '/ready'] == (case + '\n').encode()
        if cell['qualification_phase'] == 'sample':
            round_number = cell['round']
            assert stamp == f'round-{round_number:02d}-{case}-{variant}' and 1 <= round_number <= 11
            identity = (variant, case, round_number)
            assert identity not in seen
            seen.add(identity)
            samples[variant, case].append((round_number, int(elapsed) / int(operations)))
            rss_samples[variant, case].append((round_number, int(rss_match[1])))
        else:
            assert stamp == f'preflight-{case}-{variant}'
            assert (variant, case) not in preflight_seen
            preflight_seen.add((variant, case))
    assert len(seen) == 528 and len(preflight_seen) == 48
    rows = []
    for case in summary['cases']:
        row = {'case': case}
        values = {}
        for variant in ('baseline', 'candidate'):
            ns = [n for _, n in sorted(samples[variant, case])]
            rss = [n for _, n in sorted(rss_samples[variant, case])]
            assert len(ns) == 11 and ns == summary['raw_median_ns'][variant][case] and rss == summary['raw_max_rss_kb'][variant][case]
            mean = statistics.mean(ns)
            stats = {'median_ns': statistics.median(ns), 'mean_ns': mean, 'cv_percent': statistics.stdev(ns) / mean * 100, 'median_rss_kb': statistics.median(rss), 'max_rss_kb': max(rss)}
            for key, value in stats.items():
                close(value, summary[variant][case][key])
            values[variant] = ns
            row[variant] = stats
        ratio = row['candidate']['median_ns'] / row['baseline']['median_ns']
        wins = sum(c < b for b, c in zip(values['baseline'], values['candidate']))
        close(ratio, summary['comparisons'][case]['ratio'])
        close((1 - ratio) * 100, summary['comparisons'][case]['improvement_percent'])
        assert wins == summary['comparisons'][case]['candidate_wins']
        row.update(ratio=ratio, candidate_wins=wins)
        rows.append(row)
    maximum_ratio = max(r['ratio'] for r in rows)
    maximum_cv = max(r[v]['cv_percent'] for r in rows for v in ('baseline', 'candidate'))
    passed = maximum_ratio <= 1.05 and maximum_cv <= 5
    assert summary['gates']['passed'] == passed == (label == 'b')
    assert summary['gates']['all_ratios_at_most_1_05'] == (maximum_ratio <= 1.05)
    assert summary['gates']['both_cv_at_most_5_percent'] == (maximum_cv <= 5)
    return {'publication_validation': 'PASS', 'measurement_result': 'PASS' if passed else 'FAIL', 'archive_sha256': digest(blob), 'regular_files': len(entries), 'source_tree_files_verified': sum(len(s) for s in nested_sources.values()), 'cases': 24, 'rounds_per_case_side': 11, 'preflight_processes': 48, 'timed_processes': 528, 'all_raw_stdout_sidecars_control_pairs_verified': True, 'medians_sample_cv_ratios_wins_recomputed_from_raw_stdout': True, 'maximum_ratio': maximum_ratio, 'maximum_cv_percent': maximum_cv, 'failed_cases': [r['case'] for r in rows if r['ratio'] > 1.05], 'rows': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    normalization = json.loads((args.directory / 'path-normalization.json').read_text())
    for path in args.directory.iterdir():
        if path.is_file() and not path.name.endswith('.tar.gz'):
            check_text(path.read_bytes(), path.name)
    report = {'schema_version': 1, 'status': 'PASS', 'verifier_sha256': digest(Path(__file__).read_bytes()), 'path_normalization_sha256': digest((args.directory / 'path-normalization.json').read_bytes()), 'scope': 'Published review artifacts; no benchmark rerun or Git-history reconstruction', 'batches': {label: verify_batch(args.directory, label, normalization['batches'][label]) for label in ('a', 'b')}}
    data = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + '\n'
    if args.report:
        args.report.write_text(data)
    print(json.dumps({'status': report['status'], 'batches': {k: {key: v[key] for key in ('publication_validation', 'measurement_result', 'regular_files', 'source_tree_files_verified', 'timed_processes', 'preflight_processes', 'maximum_ratio', 'maximum_cv_percent', 'failed_cases')} for k, v in report['batches'].items()}}, indent=2))


if __name__ == '__main__':
    main()
