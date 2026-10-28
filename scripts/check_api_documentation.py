#!/usr/bin/env python3
"""Check the complete classified application surface in the generated Doc IR."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import pathlib
import re
import sys
import zipfile

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_CONTRACT = ROOT / 'release/api-documentation-required.json'
CATEGORIES = frozenset(('application', 'generated-spi', 'first-party-internal', 'c-abi'))
ENTRY_KINDS = frozenset(('function', 'constructor', 'macro', 'property'))
CHINESE = re.compile(r'[\u3400-\u9fff]')


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def declaration_key(declaration: dict) -> str:
    """Use source signatures rather than workspace-dependent cjdoc module IDs."""
    return '|'.join((str(declaration.get('qualifiedName', '')), str(declaration.get('kind', '')),
                     ' '.join(str(declaration.get('headerSpelling', '')).split())))


def doc_ir_digest(document: dict) -> str:
    return hashlib.sha256(json.dumps(document, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':')).encode()).hexdigest()


def visible_declarations(document: dict) -> list[dict]:
    declarations = document.get('declarations')
    if not isinstance(declarations, list) or not all(isinstance(d, dict) for d in declarations):
        raise ValueError('declarations must be an array of objects')
    by_id = {d.get('id'): d for d in declarations}
    if len(by_id) != len(declarations) or None in by_id:
        raise ValueError('declaration IDs must be present and unique')
    def visible(d: dict, ancestors: set[str]) -> bool:
        if d.get('id') in ancestors:
            raise ValueError('cyclic declaration owner chain')
        if d.get('visibility') not in ('public', 'protected'):
            return False
        owner = d.get('ownerId')
        if owner is None:
            return True
        if owner not in by_id:
            raise ValueError('declaration owner is missing')
        return visible(by_id[owner], ancestors | {d['id']})
    return [d for d in declarations if visible(d, set())]


def example_tags(declaration: dict) -> list[dict]:
    return [t for t in (declaration.get('documentation') or {}).get('tags', [])
            if isinstance(t, dict) and t.get('name') == 'example']


def is_entry(declaration: dict) -> bool:
    return (declaration.get('kind') in ENTRY_KINDS
            or declaration.get('kind') == 'enumCase' and bool(declaration.get('parameters')))


def has_bound_parameter_documentation(declaration: dict, parameter: dict) -> bool:
    if nonempty(parameter.get('documentation')):
        return True
    return any(t.get('name') == 'param' and t.get('subject') == parameter.get('name')
               and nonempty(t.get('description'))
               for t in (declaration.get('documentation') or {}).get('tags', []) if isinstance(t, dict))


def validate(document: dict, contract: dict, execution: dict | None = None, *,
             expected_source_sha256: str | None = None, expected_sdk: dict | None = None,
             expected_contract_sha256: str | None = None,
             require_examples: bool = True, quality: dict | None = None) -> dict:
    if document.get('schemaVersion') != 'cjdoc.doc-ir/16':
        raise ValueError('documentation gate requires cjdoc Doc IR v16')
    if contract.get('schemaVersion') != 2 or not contract.get('declarations'):
        raise ValueError('required documentation contract must be nonempty schema 2')
    if document.get('unsupportedDeclarations') != []:
        raise ValueError('unknown unsupported declaration is forbidden')
    failures: list[str] = []
    legacy_selected: list[dict] = []
    entries = contract['declarations']
    if not isinstance(entries, dict) or any(not isinstance(e, dict) or e.get('category') not in CATEGORIES for e in entries.values()):
        raise ValueError('every public declaration must have an explicit classification')
    declarations = visible_declarations(document)
    actual = {declaration_key(d): d for d in declarations}
    if len(actual) != len(declarations):
        raise ValueError('duplicate source declaration signature')
    for key in sorted(actual.keys() - entries.keys()):
        failures.append(f'{key}: unclassified public declaration')
    for key in sorted(entries.keys() - actual.keys()):
        failures.append(f'{key}: required declaration missing from Doc IR')
    packages = Counter(p.get('name') for p in document.get('packages', []))
    if packages != Counter(contract.get('packages', [])):
        failures.append('documented package set does not match the nine-package contract')
    # Retain the earlier reviewed owner/minimum-overload checks in addition to full inventory.
    for name, expected in contract.get('requiredOwners', {}).items():
        owners = [d for d in declarations if d.get('qualifiedName') == f'yjson.{name}' and d.get('ownerId') is None]
        if len(owners) != 1:
            failures.append(f'{name}: expected exactly one public type, found {len(owners)}')
            continue
        members = [d for d in declarations if d.get('ownerId') == owners[0]['id']]
        counts = Counter(d.get('name') for d in members)
        for member, count in expected.items():
            if counts[member] < count:
                failures.append(f'{name}.{member}: expected at least {count} overload(s), found {counts[member]}')
        for declaration in [owners[0], *members]:
            legacy_selected.append(declaration)
            if not nonempty((declaration.get('documentation') or {}).get('summary')):
                failures.append(f'{declaration_key(declaration)}: missing bound documentation summary')
    for declaration in legacy_selected:
        key = declaration_key(declaration)
        for parameter in declaration.get('parameters', []):
            if not has_bound_parameter_documentation(declaration, parameter):
                failures.append(f'{key}: missing bound @param {parameter.get("name")}')
        result = declaration.get('returnType')
        if declaration.get('kind') == 'function' and isinstance(result, dict) and result.get('spelling', '').strip() != 'Unit':
            if not any(t.get('name') == 'return' and nonempty(t.get('description'))
                       for t in (declaration.get('documentation') or {}).get('tags', [])):
                failures.append(f'{key}: missing @return description')
    selected = [d for key, d in actual.items() if entries.get(key, {}).get('category') == 'application']
    selected_ids = {declaration['id'] for declaration in selected}
    quality_findings = None
    if quality is not None:
        if quality.get('schemaVersion') != 'cjdoc.documentation-quality/1' or quality.get('audience') != 'external':
            raise ValueError('documentation quality report has an unexpected schema or audience')
        quality_findings = [finding for finding in quality.get('findings', []) if finding.get('symbolId') in selected_ids]
        for finding in quality_findings:
            failures.append(f'{finding["symbolId"]}: cjdoc documentation quality finding {finding.get("code")}')
    parameter_count = return_count = entry_count = 0
    for declaration in selected:
        key = declaration_key(declaration)
        doc = declaration.get('documentation') or {}
        summary = doc.get('summary')
        if not nonempty(summary) or not CHINESE.search(summary):
            failures.append(f'{key}: missing bound Chinese documentation summary')
        for parameter in declaration.get('parameters', []):
            parameter_count += 1
            if not has_bound_parameter_documentation(declaration, parameter):
                failures.append(f'{key}: missing bound @param {parameter.get("name")}')
        result = declaration.get('returnType')
        if declaration.get('kind') in ('function', 'macro') and (not isinstance(result, dict) or not nonempty(result.get('spelling'))):
            failures.append(f'{key}: missing collected return type')
        if declaration.get('kind') in ('function', 'macro') and isinstance(result, dict) and result.get('spelling', '').strip() != 'Unit':
            return_count += 1
            if not any(t.get('name') == 'return' and nonempty(t.get('description')) for t in doc.get('tags', [])):
                failures.append(f'{key}: missing @return description')
        if is_entry(declaration):
            entry_count += 1
            if not nonempty(entries[key].get('profile')):
                failures.append(f'{key}: missing explicit consumer profile')
            if not example_tags(declaration):
                failures.append(f'{key}: missing bound executable @example')
    executed = 0
    if require_examples:
        if not isinstance(execution, dict) or execution.get('schemaVersion') != 'yjson.api-doc-examples/1':
            failures.append('Doc IR examples have not been executed')
        else:
            if execution.get('qualificationStatus') != 'qualified':
                failures.append('development-only examples cannot satisfy qualified documentation acceptance')
            if (execution.get('status') != 'complete' or execution.get('failures') != 0
                    or execution.get('partialProfileSelection') is not None):
                failures.append('example execution is incomplete, failed, or restricted to selected profiles')
            if execution.get('docIrSha256') != doc_ir_digest(document):
                failures.append('example execution belongs to different Doc IR')
            if expected_source_sha256 is not None and execution.get('sourceSha256') != expected_source_sha256:
                failures.append('example execution belongs to different product source')
            if expected_contract_sha256 is not None and execution.get('contractSha256') != expected_contract_sha256:
                failures.append('example execution belongs to different declaration contract')
            sdk = execution.get('sdk', {})
            if sdk.get('cjcVersion') != contract.get('cjcVersion') or not nonempty(sdk.get('cjcSha256')):
                failures.append('example execution SDK identity mismatch')
            if expected_sdk is not None and sdk.get('installation') != expected_sdk:
                failures.append('example execution SDK installation identity mismatch')
            if execution.get('platform') not in ('linux', 'windows', 'darwin'):
                failures.append('example execution platform is missing or unsupported')
            import subprocess
            from run_api_doc_examples import extract_example, check_run_result, consumer_source, load_profile, UNHANDLED
            records = execution.get('examples', [])
            profiles = {}
            by_binding = {(r.get('declaration'), r.get('exampleIndex')): r for r in records}
            if len(by_binding) != len(records):
                failures.append('duplicate example execution binding')
            for declaration in selected:
                key = declaration_key(declaration)
                positive = False
                applicable = True
                for index, tag in enumerate(example_tags(declaration)):
                    try:
                        example = extract_example(tag)
                    except ValueError as error:
                        failures.append(f'{key}: {error}')
                        continue
                    record = by_binding.get((key, index))
                    if record is None:
                        failures.append(f'{key}: example {index} was not executed')
                        continue
                    if record.get('profile') != entries[key].get('profile') or record.get('codeSha256') != example['sha256']:
                        failures.append(f'{key}: example binding or code hash mismatch')
                    name = entries[key]['profile']
                    if name not in profiles:
                        profile, prelude = load_profile(name)
                        profile_sha = hashlib.sha256((ROOT / 'tests/doc_examples' / name / 'profile.json').read_bytes()).hexdigest()
                        profiles[name] = profile, prelude, profile_sha
                    profile, prelude, profile_sha = profiles[name]
                    identity = hashlib.sha256((key + ':' + str(index)).encode()).hexdigest()
                    marker = 'YJSON_DOC_' + identity[:24]
                    consumer_sha = hashlib.sha256(consumer_source(profile, prelude, example['code'], marker).encode()).hexdigest()
                    if (record.get('profileSha256') != profile_sha
                            or record.get('preludeSha256') != hashlib.sha256(prelude.encode()).hexdigest()
                            or record.get('consumerSha256') != consumer_sha
                            or record.get('mode') != example['mode']):
                        failures.append(f'{key}: complete consumer or profile hash mismatch')
                    if expected_source_sha256 is not None and record.get('frozenSourceSha256') != expected_source_sha256:
                        failures.append(f'{key}: frozen dependency source hash mismatch')
                    if record.get('status') == 'not-applicable':
                        if execution.get('platform') not in profile['platforms']:
                            applicable = False
                            continue
                    if record.get('status') != 'passed':
                        failures.append(f'{key}: example {index} did not pass')
                    elif example['mode'] == 'run':
                        if (record.get('buildExitCode') != 0
                                or UNHANDLED.search(record.get('buildStdout', '') + record.get('buildStderr', ''))
                                or not re.fullmatch(r'[0-9a-f]{64}', record.get('executableSha256', ''))
                                or not record.get('dependencyArtifacts')):
                            failures.append(f'{key}: successful build and actual artifact identities are missing')
                        passed, reason = check_run_result(subprocess.CompletedProcess(
                            record.get('command', []), record.get('exitCode'),
                            record.get('stdout', ''), record.get('stderr', '')),
                            example, marker)
                        if not passed:
                            failures.append(f'{key}: recorded execution is invalid: {reason}')
                        else:
                            positive = True
                            executed += 1
                if is_entry(declaration) and applicable and not positive:
                    failures.append(f'{key}: no executed successful-path example')
    if failures:
        raise ValueError('API documentation contract failed:\n' + '\n'.join(failures))
    categories = Counter(e['category'] for e in entries.values())
    return {'schemaVersion': 'yjson.documentation-coverage/2', 'categories': dict(sorted(categories.items())),
            'packages': sorted(packages), 'publicDeclarations': len(declarations),
            'requiredTypes': len(contract.get('requiredOwners', {})), 'requiredDeclarations': len(selected),
            'documentedRequiredParameters': parameter_count, 'documentedRequiredReturns': return_count,
            'applicationEntries': entry_count, 'executedPositiveExamples': executed,
            'applicationQualityFindings': len(quality_findings) if quality_findings is not None else None,
            'status': 'accepted' if require_examples else 'bindings-only',
            'coveragePercent': {'summaries': 100, 'parameters': 100, 'returns': 100,
                                'examples': 100 if require_examples else None},
            'scope': 'All classified public/protected application declarations in eight release packages; excluded categories remain inventoried.'}


def verify_agent_reading(site: pathlib.Path, manifest: dict, document: dict) -> dict:
    """Recheck recorded reader executions and the exact pack; never rerun a reader."""
    import subprocess
    from generate_api_docs import (file_inventory_digest, html_pack_files, regular_input_path,
                                   sha256_file, validate_agent_result)
    receipt_path = regular_input_path(site, 'agent-reading-check.json')
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    if (receipt.get('schemaVersion') != 'yjson.agent-reading-check/3' or receipt.get('status') != 'passed'
            or receipt.get('error') or receipt.get('failures', 0) != 0
            or receipt.get('allPackInputsUnchanged') is not True or receipt.get('binaryUnchanged') is not True):
        raise ValueError('Agent reader receipt is missing, old, failed, or incomplete')
    files = html_pack_files(site)
    inventory_sha = file_inventory_digest(files)
    if (receipt.get('packFiles') != files or receipt.get('packFilesSha256') != inventory_sha
            or receipt.get('packFilesAfterSha256') != inventory_sha):
        raise ValueError('final HTML/Agent pack differs from the exact reader input inventory')
    snapshot_path = regular_input_path(site, 'html/agent/manifest.json')
    snapshot_sha = sha256_file(snapshot_path)
    snapshot_id = json.loads(snapshot_path.read_text(encoding='utf-8')).get('snapshotId')
    binary_sha = manifest.get('generator', {}).get('binarySha256')
    if (not isinstance(binary_sha, str) or re.fullmatch(r'[0-9a-f]{64}', binary_sha) is None
            or receipt.get('binarySha256') != binary_sha or receipt.get('binarySha256After') != binary_sha
            or receipt.get('snapshotSha256') != snapshot_sha or not nonempty(snapshot_id)):
        raise ValueError('Agent reader binary or snapshot identity mismatch')
    resources = receipt.get('resources', {})
    soft, hard = resources.get('stackSoftBytes'), resources.get('stackHardBytes')
    if (resources.get('cjHeapSize') != '2GB' or type(soft) is not int or type(hard) is not int
            or soft != -1 and soft < 131072 * 1024
            or hard != -1 and (soft == -1 or hard < soft)):
        raise ValueError('Agent reader resource requirements mismatch')
    guide = manifest.get('sourceGuide', {})
    metadata = guide.get('pages')
    if guide.get('schemaVersion') != 'yjson.api-doc-source-guide/2' or not isinstance(metadata, list) or not metadata:
        raise ValueError('Agent source guide page inventory is missing')
    expected_pages = {}
    for page in metadata:
        source = page.get('source', '')
        path = pathlib.PurePosixPath(source)
        if (not source.startswith('docs/api-source-') or path.suffix != '.md' or '..' in path.parts
                or '\\' in source or path.as_posix() != source):
            raise ValueError('Agent source guide path is invalid')
        matches = [item for item in document.get('pages', []) if item.get('source') == source]
        page_id = path.stem
        if len(matches) != 1 or matches[0].get('id') != page_id or page_id in expected_pages:
            raise ValueError('Agent source guide page identities are missing or duplicated')
        text = matches[0].get('text')
        if (not isinstance(text, str) or not text or type(page.get('bytes')) is not int
                or len(text.encode('utf-8')) != page['bytes']
                or hashlib.sha256(text.encode('utf-8')).hexdigest() != page.get('sha256')):
            raise ValueError('Agent source guide UTF-8 length or digest differs from Doc IR')
        expected_pages[page_id] = page
    actual_sources = [page.get('source') for page in document.get('pages', [])
                      if str(page.get('source', '')).startswith('docs/api-source-')]
    if Counter(actual_sources) != Counter(page['source'] for page in metadata):
        raise ValueError('Agent source guide metadata does not cover every native source guide page')
    page_ids = list(expected_pages)
    if receipt.get('sourceGuidePages') != page_ids:
        raise ValueError('Agent reader did not cover the exact source guide page inventory')
    summary = {key: receipt.get(key) for key in ('queryStatus', 'stdioMcpStatus', 'snapshotSha256', 'binarySha256',
                                                'packFilesSha256', 'resources', 'sourceGuidePages')}
    summary.update(report='agent-reading-check.json', receiptSha256=sha256_file(receipt_path))
    if manifest.get('agentReading') != summary:
        raise ValueError('manifest Agent reader evidence or receipt digest mismatch')
    checks = receipt.get('checks')
    expected_names = ['query-search', *('query-' + page_id for page_id in page_ids), 'stdio-mcp']
    if (not isinstance(checks, list) or any(not isinstance(item, dict) for item in checks)
            or Counter(item.get('name') for item in checks) != Counter(expected_names)):
        raise ValueError('Agent reader executions are missing, extra, or duplicated')
    by_name = {item['name']: item for item in checks}
    query_command = ['<cjdoc>', 'query', '--snapshot', '<site>/html/agent/manifest.json', '--request', '-']
    mcp_command = ['<cjdoc>', 'mcp', '--snapshot', '<site>/html/agent/manifest.json']
    search_request = {'operation': 'search', 'query': 'yjson.YJson', 'limit': 2}
    def execution(name, command):
        item = by_name[name]
        if (item.get('command') != command or type(item.get('exitCode')) is not int or item['exitCode'] != 0
                or item.get('timedOut') or not isinstance(item.get('stdout'), str) or not isinstance(item.get('stderr'), str)
                or re.search(r'(?im)^\s*(?:An exception has occurred:|Unhandled(?: exception| error)|Fatal error:)',
                             item['stdout'] + '\n' + item['stderr'])):
            raise ValueError('Agent reader execution failed or reported an exception: ' + name)
        return subprocess.CompletedProcess(command, item['exitCode'], item['stdout'], item['stderr'])
    def response_scope(response, request, page_id=None):
        scope = response.get('scope', {})
        snapshots = scope.get('snapshots', [])
        if (response.get('status') != 'ok' or response.get('error') is not None
                or response.get('operation') != request['operation'] or scope.get('requested') != request
                or len(snapshots) != 1 or snapshots[0].get('snapshotId') != snapshot_id
                or snapshots[0].get('sourceSnapshotId') != snapshot_id
                or snapshots[0].get('sourceKind') != 'machine-manifest'):
            raise ValueError('Agent reader response status, request, or snapshot scope mismatch')
        if page_id is None:
            return  # The explicit limit=2 search smoke is intentionally paginated.
        items = response.get('result', {}).get('items', [])
        completeness = response.get('completeness', {})
        if (len(items) != 1 or items[0].get('identity', {}).get('pageId') != page_id
                or completeness.get('query', {}).get('complete') is not True
                or completeness.get('content', {}).get('complete') is not True):
            raise ValueError('Agent source guide response has a wrong page or is incomplete')
        descriptions = [section.get('value', {}) for section in items[0].get('sections', []) if section.get('name') == 'description']
        text = descriptions[0].get('text') if len(descriptions) == 1 else None
        expected = expected_pages[page_id]
        if (not isinstance(text, str) or len(text.encode('utf-8')) != expected['bytes']
                or hashlib.sha256(text.encode('utf-8')).hexdigest() != expected['sha256']):
            raise ValueError('Agent source guide response UTF-8 length or digest is missing, changed, or truncated')
    expected_requests = {'query-search': search_request}
    for page_id in page_ids:
        expected_requests['query-' + page_id] = {'operation': 'get_symbol', 'pageId': page_id,
                                                'sections': ['description'], 'maxBytes': 2097152}
    for name, request in expected_requests.items():
        if json.loads(by_name[name].get('stdin', '')) != request:
            raise ValueError('Agent reader query request mismatch: ' + name)
        response_scope(validate_agent_result(execution(name, query_command)), request, request.get('pageId'))
    mcp = execution('stdio-mcp', mcp_command)
    requests = [json.loads(line) for line in by_name['stdio-mcp'].get('stdin', '').splitlines() if line.strip()]
    initialize = {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
        'protocolVersion': '2025-11-25', 'capabilities': {}, 'clientInfo': {'name': 'yjson-doc-check', 'version': '0.2.0'}}}
    expected_messages = [initialize, {'jsonrpc': '2.0', 'method': 'notifications/initialized'}]
    for request_id, request in enumerate(expected_requests.values(), 2):
        arguments = {key: value for key, value in request.items() if key != 'operation'}
        expected_messages.append({'jsonrpc': '2.0', 'id': request_id, 'method': 'tools/call',
                                  'params': {'name': request['operation'], 'arguments': arguments}})
    if requests != expected_messages:
        raise ValueError('Agent stdio MCP requests do not cover the exact source guide pages')
    responses = [json.loads(line) for line in mcp.stdout.splitlines() if line.strip()]
    ids = [item.get('id') for item in responses if isinstance(item, dict)]
    if (len(ids) != len(responses) or Counter(ids) != Counter(range(1, len(expected_requests) + 2))
            or any(item.get('jsonrpc') != '2.0' or item.get('error') is not None
                   or not isinstance(item.get('result'), dict) or item['result'].get('isError') for item in responses)):
        raise ValueError('Agent stdio MCP responses are failed, missing, extra, or duplicated')
    for request_id, request in enumerate(expected_requests.values(), 2):
        response_scope(validate_agent_result(mcp, mcp=True, request_id=request_id), request, request.get('pageId'))
    if receipt.get('queryStatus') != 'ok' or receipt.get('stdioMcpStatus') != 'ok':
        raise ValueError('Agent reader aggregate status is incomplete')
    return {'status': 'accepted', 'packFiles': len(files), 'sourceGuidePages': len(page_ids),
            'queryExecutions': len(expected_requests), 'stdioMcpPageResponses': len(page_ids)}


def write_offline_archive(site: pathlib.Path) -> pathlib.Path:
    """Keep every original cjdoc projection, resource, source, and example receipt."""
    downloads = site / 'downloads'
    downloads.mkdir(exist_ok=True)
    destination = downloads / 'yjson-api-docs-offline.zip'
    files = sorted(path for path in site.rglob('*') if path.is_file()
                   and downloads not in path.parents and not path.name.endswith('.pending'))
    if any(path.is_symlink() for path in files):
        raise ValueError('offline documentation cannot include linked files')
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            entry = zipfile.ZipInfo(path.relative_to(site).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, path.read_bytes())
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    (downloads / 'yjson-api-docs-offline.zip.sha256').write_text(digest + '  ' + destination.name + '\n', encoding='utf-8')
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None or archive.namelist() != [path.relative_to(site).as_posix() for path in files]:
            raise ValueError('offline documentation archive failed its content validation')
    return destination


def verify_consumer_exports(site: pathlib.Path, manifest: dict, document: dict,
                            contract: dict, execution: dict) -> dict:
    """Bind the exact downloadable source bytes to the accepted execution records."""
    from generate_api_docs import regular_input_path, sha256_file, verify_frozen_sources
    from run_api_doc_examples import consumer_manifest, consumer_source, extract_example, load_profile
    if manifest.get('consumerSources') != 'consumer-sources':
        raise ValueError('qualified artifact is missing its canonical frozen consumer sources')
    frozen = regular_input_path(site, 'consumer-sources')
    if not frozen.is_dir():
        raise ValueError('frozen consumer sources directory is missing')
    files = manifest['source']['files']
    if not isinstance(files, dict) or not files:
        raise ValueError('frozen consumer source inventory is missing')
    actual = set()
    for path in frozen.rglob('*'):
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError('downloadable frozen sources contain linked or nonregular inputs')
        if path.is_file():
            actual.add(path.relative_to(frozen).as_posix())
    if actual != set(files):
        raise ValueError('downloadable frozen source file inventory is missing or has extra inputs')
    verify_frozen_sources(frozen, manifest['source'])
    entries = contract['declarations']
    expected = {(declaration_key(declaration), index): (entries[declaration_key(declaration)]['profile'], tag)
                for declaration in visible_declarations(document)
                if entries.get(declaration_key(declaration), {}).get('category') == 'application'
                for index, tag in enumerate(example_tags(declaration))}
    records = execution['examples']
    if (any(type(record.get('exampleIndex')) is not int for record in records)
            or Counter((record.get('declaration'), record.get('exampleIndex')) for record in records) != Counter(expected.keys())):
        raise ValueError('downloadable examples do not match the exact declaration binding inventory')
    exports = regular_input_path(site, 'examples')
    if not exports.is_dir():
        raise ValueError('downloadable examples directory is missing')
    expected_exports = {'index.html'}
    for key, index in expected:
        identifier = hashlib.sha256((key + ':' + str(index)).encode()).hexdigest()
        expected_exports.update((identifier + '.cj', identifier + '.toml'))
    actual_exports = set()
    for path in exports.rglob('*'):
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError('downloadable examples contain linked or nonregular inputs')
        if path.is_file():
            actual_exports.add(path.relative_to(exports).as_posix())
    if actual_exports != expected_exports:
        raise ValueError('downloadable example file inventory is missing or has extra inputs')
    profiles = {}
    for record in records:
        key, index = record['declaration'], record['exampleIndex']
        name, tag = expected[key, index]
        if name not in profiles:
            profiles[name] = load_profile(name)
        profile, prelude = profiles[name]
        example = extract_example(tag)
        override = record.get('overrideCompileOption')
        if override not in ('-O0', '-O1', '-O2'):
            raise ValueError('recorded dependency optimization override is invalid')
        if (record.get('compileOption') != profile.get('compileOption', '-O2')
                or 'overrideCompileOption' in profile and override != profile['overrideCompileOption']):
            raise ValueError('recorded consumer optimization differs from its profile')
        if record['compileOption'] != '-O2' or override != '-O2':
            raise ValueError('qualified consumer exports require the production O2 policy')
        identifier = hashlib.sha256((key + ':' + str(index)).encode()).hexdigest()
        source_name, manifest_name = 'examples/' + identifier + '.cj', 'examples/' + identifier + '.toml'
        if record.get('source') != source_name or record.get('manifest') != manifest_name:
            raise ValueError('downloadable consumer paths are not canonical for their declaration binding')
        source = regular_input_path(site, source_name)
        portable_path = regular_input_path(site, manifest_name)
        if not source.is_file() or not portable_path.is_file():
            raise ValueError('downloadable consumer source and manifest must be regular files')
        source_bytes = consumer_source(profile, prelude, example['code'], 'YJSON_DOC_' + identifier[:24]).encode('utf-8')
        if source.read_bytes() != source_bytes or sha256_file(source) != record.get('consumerSha256'):
            raise ValueError('downloadable consumer source bytes differ from the executed source')
        portable = consumer_manifest(profile, example, override_compile_option=override).encode('utf-8')
        if portable_path.read_bytes() != portable:
            raise ValueError('downloadable consumer manifest bytes differ from its execution inputs')
    return {'status': 'accepted', 'frozenSourceFiles': len(files), 'consumerSources': len(records),
            'consumerManifests': len(records)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('site', type=pathlib.Path)
    parser.add_argument('--contract', type=pathlib.Path, default=DEFAULT_CONTRACT)
    args = parser.parse_args()
    try:
        document = json.loads((args.site / 'docs.json').read_text(encoding='utf-8'))
        manifest = json.loads((args.site / 'api-docs.json').read_text(encoding='utf-8'))
        if manifest.get('qualificationStatus') != 'qualified':
            raise ValueError('development-only documentation cannot satisfy qualified acceptance')
        from generate_api_docs import source_identity, sha256_file, verify_standard_quality
        if source_identity() != manifest.get('source'):
            raise ValueError('generated documentation belongs to different current source inputs')
        if sha256_file(args.site / 'docs.json') != manifest.get('docIrSha256'):
            raise ValueError('generated Doc IR digest mismatch')
        if sha256_file(args.contract) != manifest['source']['files']['release/api-documentation-required.json']:
            raise ValueError('declaration contract differs from the frozen source inventory')
        quality = verify_standard_quality(args.site, manifest['source']['sha256'], manifest.get('standardQuality'))
        if json.loads((args.site / 'standard-quality-evidence.json').read_text(encoding='utf-8')) != manifest['standardQuality']:
            raise ValueError('standard quality evidence receipt mismatch')
        reading = verify_agent_reading(args.site, manifest, document)
        execution_path = args.site / 'example-execution.json'
        execution = json.loads(execution_path.read_text(encoding='utf-8')) if execution_path.exists() else None
        contract = json.loads(args.contract.read_text(encoding='utf-8'))
        report = validate(document, contract, execution,
                          expected_source_sha256=manifest['source']['sha256'], expected_sdk=manifest['sdk'],
                          expected_contract_sha256=manifest['source']['files']['release/api-documentation-required.json'],
                          quality=quality)
        report['consumerExports'] = verify_consumer_exports(
            args.site, manifest, document, contract, execution)
        report['agentReading'] = reading
        (args.site / 'documentation-coverage.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        write_offline_archive(args.site)
    except (OSError, ValueError, TypeError, AttributeError, KeyError) as error:
        print(f'API documentation error: {error}', file=sys.stderr)
        return 1
    print(f'API documentation contract passed: {report["requiredDeclarations"]} declarations, '
          f'{report["executedPositiveExamples"]} successful examples; all application coverage thresholds 100%')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
