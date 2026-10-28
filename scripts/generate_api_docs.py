#!/usr/bin/env python3
"""Build one source-qualified, nine-package cjdoc documentation workspace."""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict
import hashlib
import html
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib

sys.dont_write_bytecode = True

from check_cjdoc_qualification import validate_qualification
from release_graph import ROOT, load_release_graph
from validate_cangjie_sts import check_installed
from api_doc_source_guide import SourceRepository, render_source_guide
from api_doc_repository_links import (RepositoryLink, markdown_sources, repository_link_catalog,
                                      rewrite_repository_links, validate_html_file_links)

DEFAULT_CONFIG = ROOT / 'release/cjdoc-tool.toml'
DEFAULT_POLICY = ROOT / 'release/cjdoc-policy.toml'
DEFAULT_OUTPUT = ROOT / 'target/api-docs'
DOC_IR_SCHEMA = 'cjdoc.doc-ir/16'


class ApiDocsError(ValueError):
    pass


def sha256_file(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_inventory_digest(files: dict[str, str]) -> str:
    return hashlib.sha256(json.dumps(files, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def html_pack_files(site: pathlib.Path) -> dict[str, str]:
    directory = site / 'html'
    if not directory.is_dir() or directory.is_symlink():
        raise ApiDocsError('Agent pack must have a regular HTML directory')
    files = {}
    for path in sorted(directory.rglob('*')):
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise ApiDocsError('Agent pack cannot contain linked or nonregular resources')
        if path.is_file():
            relative = path.relative_to(site).as_posix()
            files[relative] = sha256_file(regular_input_path(site, relative))
    if not files:
        raise ApiDocsError('Agent pack HTML inventory is empty')
    return files


def sdk_identity() -> dict:
    """Fingerprint the selected compiler and actual stdx, regardless of installer."""
    version, compiler, manager = check_installed()
    binaries = {}
    compiler_path = None
    for command in ('cjc', 'cjpm'):
        resolved = shutil.which(command)
        if resolved is None:
            raise ApiDocsError(command + ' is unavailable')
        path = pathlib.Path(resolved).resolve()
        binaries[command] = sha256_file(path)
        if command == 'cjc':
            compiler_path = path
    stdx = pathlib.Path(os.environ.get('CANGJIE_STDX_PATH', ''))
    if not os.environ.get('CANGJIE_STDX_PATH') or not stdx.is_dir():
        raise ApiDocsError('selected CANGJIE_STDX_PATH does not identify an installed stdx directory')
    files = {path.relative_to(stdx).as_posix(): sha256_file(path)
             for path in sorted(stdx.rglob('*')) if path.is_file()}
    if not files:
        raise ApiDocsError('selected stdx directory is empty')
    stdx_digest = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    record = {'schemaVersion': 'yjson.api-doc-toolchain/1', 'version': version,
              'cjcVersion': compiler, 'cjpmVersion': manager, 'binarySha256': binaries,
              'stdxSha256': stdx_digest, 'stdxFiles': files}
    assert compiler_path is not None
    for parent in compiler_path.parents:
        receipt = parent / '.cjv/toolchain.toml'
        if receipt.is_file():
            record['installerReceiptSha256'] = sha256_file(receipt)
            break
    return record


def source_identity(root: pathlib.Path = ROOT) -> dict:
    """Hash actual inputs, including dirty contents, without exposing local paths."""
    graph = load_release_graph(root / 'release/release-graph.toml')
    revisions = source_revisions(root)
    sources = markdown_sources(root)
    policy = tomllib.loads((root / 'release/cjdoc-policy.toml').read_text(encoding='utf-8'))
    macro_prefix = next(package.development_manifest.parent.as_posix()
                        for package in graph.packages if package.name == 'yjson_macros')
    candidate_files = None
    if 'candidateProvenanceSha256' in revisions:
        from release_temp_tree import manifest_paths
        candidate_files = frozenset(path.as_posix() for path in manifest_paths(root / 'release/release-files.txt'))
    catalog = repository_link_catalog(root, sources,
        {'.': (policy['repository_url'], revisions['revision']),
         macro_prefix: (policy['macro_repository_url'], revisions['macroRevision'])}, candidate_files=candidate_files)
    paths = {root / 'release/release-graph.toml', root / 'release/api-documentation-required.json',
             root / 'release/cjdoc-policy.toml', root / 'release/cjdoc-tool.toml',
             root / 'release/public-api-inventory.toml', root / 'release/public-api-snapshot.txt'}
    paths.update(root / relative for relative in (
        'LICENSE', 'THIRD_PARTY_NOTICES.md', 'native/vendor/yyjson/LICENSE',
        'packages/yjson_macros/LICENSE'))
    for package in graph.packages:
        paths.add(root / package.development_manifest)
        paths.add((root / package.development_manifest).parent / 'cjpm.lock')
        paths.add((root / package.development_manifest).parent / 'build.cj')
        paths.add((root / package.development_manifest).parent / 'LICENSE')
        paths.update(p for p in (root / package.source_root).rglob('*.cj')
                     if not p.name.endswith('_test.cj'))
    for directory in [root / 'native', *((root / p.development_manifest).parent for p in graph.packages if p.name != 'yjson')]:
        paths.update(path for path in directory.rglob('*')
                     if path.is_file() and path.suffix in ('.c', '.h', '.cc', '.cpp', '.hpp')
                     and not {'target', 'build-script-cache', '.git'}.intersection(path.relative_to(root).parts))
    paths.update((root / 'tests/doc_examples').rglob('*.json'))
    paths.update((root / 'tests/doc_examples').rglob('*.cj'))
    paths.update(root / relative for relative in sources)
    paths.update(root / 'scripts' / name for name in (
        'generate_api_docs.py', 'check_api_documentation.py', 'run_api_doc_examples.py',
        'release_graph.py', 'run_cjpm_executable.sh', 'api_doc_source_guide.py', 'api_doc_repository_links.py',
        'build_native_scanner.py', 'release_registry_rehearsal.py', 'release_temp_tree.py',
        'stage_source_tree.py', 'check_cjdoc_qualification.py', 'validate_cangjie_sts.py'))
    files = {p.relative_to(root).as_posix(): sha256_file(p) for p in sorted(paths) if p.is_file()}
    digest = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {**revisions, 'sha256': digest, 'files': files,
            'repositoryLinks': [asdict(entry) for entry in catalog]}


def pinned_macro_revision(root: pathlib.Path) -> str:
    manifest = tomllib.loads((root / 'cjpm.toml').read_text(encoding='utf-8'))
    lock = tomllib.loads((root / 'cjpm.lock').read_text(encoding='utf-8'))
    dependency = manifest.get('test-dependencies', {}).get('yjson_macros')
    locked = lock.get('requires', {}).get('yjson_macros')
    if (not isinstance(dependency, dict) or not isinstance(locked, dict)
            or dependency.get('git') != 'https://github.com/lIlIIlIll/yjson_macros.git'
            or locked.get('git') != dependency.get('git')
            or locked.get('commitId') != dependency.get('commitId')
            or re.fullmatch(r'[0-9a-f]{40}', str(dependency.get('commitId', ''))) is None):
        raise ApiDocsError('documentation source requires a matching immutable macro Git pin in manifest and lock')
    return dependency['commitId']


def source_revisions(root: pathlib.Path) -> dict:
    macro_pin = pinned_macro_revision(root)
    if not (root / '.git').exists():
        from release_registry_rehearsal import validate_candidate_tree
        try:
            validate_candidate_tree(root, require_clean=True)
        except (RuntimeError, ValueError) as error:
            raise ApiDocsError('unverified source-only candidate: ' + str(error)) from error
        provenance_path = root / 'release/candidate-provenance.json'
        provenance = json.loads(provenance_path.read_text(encoding='utf-8'))
        return {'revision': provenance['commit'], 'tree': provenance['tree'],
                'macroRevision': macro_pin, 'candidateProvenanceSha256': sha256_file(provenance_path)}
    def revision(directory: pathlib.Path) -> str:
        result = subprocess.run(['git', '-C', str(directory), 'rev-parse', 'HEAD'],
                                capture_output=True, text=True, check=False)
        if result.returncode or re.fullmatch(r'[0-9a-f]{40}', result.stdout.strip()) is None:
            raise ApiDocsError('cannot identify documentation source revision')
        return result.stdout.strip()
    macro_revision = revision(root / 'packages/yjson_macros')
    if macro_revision != macro_pin:
        raise ApiDocsError('macro checkout revision differs from the immutable dependency pin')
    return {'revision': revision(root), 'macroRevision': macro_revision}


def regular_input_path(root: pathlib.Path, relative: str) -> pathlib.Path:
    path = pathlib.PurePosixPath(relative)
    if (not relative or path.is_absolute() or '..' in path.parts or '\\' in relative
            or ':' in relative or path.as_posix() != relative
            or any(ord(character) < 32 for character in relative)):
        raise ApiDocsError('unsafe source inventory path')
    if root.is_symlink() or any(root.joinpath(*path.parts[:index]).is_symlink()
                               for index in range(1, len(path.parts) + 1)):
        raise ApiDocsError('source input must be a regular file without linked ancestors')
    return root.joinpath(*path.parts)


def freeze_sources(root: pathlib.Path, destination: pathlib.Path, identity: dict) -> None:
    destination.mkdir()
    for relative, expected in identity['files'].items():
        path = pathlib.PurePosixPath(relative)
        source = regular_input_path(root, relative)
        if not source.is_file() or sha256_file(source) != expected:
            raise ApiDocsError('source input changed before snapshot: ' + relative)
        target = destination.joinpath(*path.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def verify_frozen_sources(root: pathlib.Path, identity: dict) -> None:
    for relative, expected in identity['files'].items():
        path = regular_input_path(root, relative)
        if not path.is_file() or sha256_file(path) != expected:
            raise ApiDocsError('frozen source input digest mismatch: ' + relative)


def run_generator(command: list[str], environment: dict, log: pathlib.Path) -> None:
    result = subprocess.run(command, capture_output=True, text=True, env=environment, timeout=2400, check=False)
    log.write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode or 'An exception has occurred:' in result.stdout + result.stderr:
        raise ApiDocsError(f'cjdoc generation failed (exit {result.returncode}): '
                           + (result.stdout + result.stderr)[-12000:])


def create_workspace(destination: pathlib.Path, *, root: pathlib.Path = ROOT,
                     revisions: dict | None = None) -> dict[str, str]:
    """Copy source only, preserving repository paths; never rewrite product manifests."""
    graph = load_release_graph(root / 'release/release-graph.toml')
    destination.mkdir()
    locations = {p.name: p.development_manifest.parent.as_posix() for p in graph.packages}
    locations['yjson'] = '.'
    for package in graph.packages:
        project = destination / locations[package.name]
        project.mkdir(parents=True, exist_ok=True)
        (project / 'src').mkdir()
        original = root / package.source_root
        for source in sorted(original.rglob('*.cj')):
            if source.name.endswith('_test.cj'):
                continue
            target = project / 'src' / source.relative_to(original)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        manifest = (f'[package]\nname = {json.dumps(package.name)}\n'
                    f'version = {json.dumps(graph.version)}\ncjc-version = "1.2.0"\n'
                    'output-type = "static"\n\n[dependencies]\n')
        for dependency in package.dependencies:
            relative = pathlib.Path(os.path.relpath(destination / locations[dependency], project)).as_posix()
            manifest += f'{dependency} = {{ path = {json.dumps(relative)} }}\n'
        (project / 'cjpm.toml').write_text(manifest, encoding='utf-8')
    root_manifest = destination / 'cjpm.toml'
    with root_manifest.open('a', encoding='utf-8') as stream:
        stream.write('\n[workspace]\nmembers = ' + json.dumps(
            [locations[p.name] for p in graph.packages if p.name != 'yjson']) + '\n')
    # Resolve only supplementary repository links, before either producer runs.
    # Registered pages and API links retain cjdoc's normal bindings.
    revisions = source_identity(root) if revisions is None else revisions
    catalog = tuple(RepositoryLink(**entry) for entry in revisions['repositoryLinks'])
    sources = markdown_sources(root)
    (destination / 'README.md').write_bytes(rewrite_repository_links(
        root, 'README.md', sources, catalog).encode('utf-8'))
    (destination / 'docs').mkdir()
    pages = sorted((root / 'docs').glob('*.md'))
    configuration = '[docs]\nindex = "README.md"\n'
    for page in pages:
        (destination / 'docs' / page.name).write_bytes(rewrite_repository_links(
            root, 'docs/' + page.name, sources, catalog).encode('utf-8'))
        configuration += (f'\n[[docs.pages]]\nsource = "docs/{page.name}"\n'
                          f'route = "concepts/guides/{page.stem}"\nid = {json.dumps(page.stem)}\n'
                          'kind = "guide"\n')
    (destination / 'cjdoc.toml').write_text(configuration, encoding='utf-8')
    return locations


def validate_doc_ir(docs_path: pathlib.Path, *, package_names: tuple[str, ...],
                    generator_version: str, expected_macros: tuple[str, ...]) -> dict:
    document = json.loads(docs_path.read_text(encoding='utf-8'))
    if not isinstance(document, dict) or document.get('schemaVersion') != DOC_IR_SCHEMA:
        raise ApiDocsError('cjdoc must emit Doc IR v16')
    generator = document.get('generator', {})
    if generator.get('name') != 'cjdoc' or generator.get('version') != generator_version:
        raise ApiDocsError('docs.json generator identity mismatch')
    if document.get('configuration', {}).get('audience') != 'external':
        raise ApiDocsError('docs.json audience must be external')
    if document.get('project', {}).get('repository') is not None:
        raise ApiDocsError('Doc IR v16 must leave the machine repository URL unavailable for this multi-repository workspace')
    packages = document.get('packages')
    if not isinstance(packages, list) or Counter(p.get('name') for p in packages) != Counter(package_names):
        raise ApiDocsError('docs.json must contain exactly the release package graph')
    declarations = document.get('declarations')
    if not isinstance(declarations, list) or not declarations:
        raise ApiDocsError('docs.json has no declarations')
    if document.get('unsupportedDeclarations') != []:
        raise ApiDocsError('unsupported declarations are forbidden in the current documentation candidate')
    diagnostics = document.get('diagnostics')
    if not isinstance(diagnostics, list):
        raise ApiDocsError('docs.json diagnostics must be an array')
    errors = [d for d in diagnostics if d.get('severity') == 'error']
    if errors:
        raise ApiDocsError('cjdoc reported errors: ' + ', '.join(d['code'] for d in errors))
    macros = [d['name'] for d in declarations if d.get('packageName') == 'yjson_macros'
              and d.get('kind') == 'macro' and d.get('visibility') == 'public']
    if Counter(macros) != Counter(expected_macros):
        raise ApiDocsError('public macro declarations do not match the four-macro contract')
    expected_derive = {('yjson', 'JsonKind'), ('yjson_algorithms', 'JsonPatchOperationKind')}
    for package, name in expected_derive:
        if not any(d.get('packageName') == package and d.get('name') == name
                   and d.get('kind') == 'enum' for d in declarations):
            raise ApiDocsError(f'{package}.{name}: macro-wrapped source declaration is missing')
    invocations = document.get('macroInvocations', [])
    if Counter(i.get('name') for i in invocations) != Counter({'Derive': 2}):
        raise ApiDocsError('macro invocation metadata must retain the two unexpanded Derive inputs')
    for package in package_names:
        if not any(d.get('packageName') == package and d.get('visibility') == 'public' for d in declarations):
            raise ApiDocsError(f'{package}: no public declaration collected')
    return {'status': document.get('status'), 'declarations': len(declarations),
            'warningCodes': dict(Counter(d.get('code') for d in diagnostics if d.get('severity') == 'warning')),
            'unsupported': [], 'macros': sorted(macros), 'unexpandedMacroInvocations': len(invocations)}


def validate_module_dependencies(document: dict, graph) -> None:
    modules = document.get('modules', [])
    by_id = {module.get('id'): module for module in modules}
    if len(by_id) != len(modules) or {module.get('name') for module in modules} != set(graph.names):
        raise ApiDocsError('Doc IR module graph does not match the release graph')
    expected = {package.name: set(package.dependencies) for package in graph.packages}
    for module in modules:
        try:
            actual = {by_id[identity]['name'] for identity in module.get('dependencyIds', [])}
        except KeyError as error:
            raise ApiDocsError('Doc IR module graph contains an unknown dependency') from error
        if actual != expected[module['name']]:
            raise ApiDocsError('Doc IR module dependency edges do not match the release graph: ' + module['name'])


def quality_declaration_digest(document: dict) -> tuple[str, int]:
    """Compare every declaration field; only optional syntax coloring is display data."""
    def without_highlights(value):
        if isinstance(value, list):
            return [without_highlights(item) for item in value]
        if isinstance(value, dict):
            result = {key: without_highlights(item) for key, item in value.items()
                      if key not in ('codeHighlight', 'signatureHighlight')}
            if result.get('metadata') == {}:
                result['metadata'] = None
            return result
        return value
    declarations = document.get('declarations', [])
    by_id = {item['id']: without_highlights(item) for item in declarations}
    if not by_id or len(by_id) != len(declarations):
        raise ApiDocsError('quality evidence requires nonempty unique declaration identities')
    digest = hashlib.sha256(json.dumps(by_id, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return digest, len(by_id)


def bind_standard_quality(standard: pathlib.Path, site: pathlib.Path, source_sha: str) -> dict:
    """Bind two untouched producer outputs to exactly the same API declarations."""
    original = json.loads((standard / 'docs.json').read_text(encoding='utf-8'))
    final = json.loads((site / 'docs.json').read_text(encoding='utf-8'))
    if (original.get('configuration', {}).get('lintProfile') != 'standard'
            or final.get('configuration', {}).get('lintProfile') != 'standard'):
        raise ApiDocsError('quality evidence requires two standard lint producers with normal binding')
    configurations = {}
    for name in ('standard', 'full'):
        path = site / 'quality-inputs' / (name + '-cjdoc.toml')
        configurations[name] = tomllib.loads(path.read_text(encoding='utf-8'))
    if configurations['standard'].get('lint') or configurations['full'].get('lint') != {'severity': 'off'}:
        raise ApiDocsError('quality evidence requires default standard severity and explicitly suppressed display diagnostics')
    before, count = quality_declaration_digest(original)
    after, final_count = quality_declaration_digest(final)
    if (before, count) != (after, final_count):
        raise ApiDocsError('standard quality and full site API declarations differ')
    from check_api_documentation import visible_declarations
    quality = json.loads((standard / 'coverage/quality.json').read_text(encoding='utf-8'))
    visible = visible_declarations(original)
    if (quality.get('schemaVersion') != 'cjdoc.documentation-quality/1' or quality.get('audience') != 'external'
            or quality.get('assessment') != 'conservative-placeholder-heuristic'
            or not isinstance(quality.get('findings'), list)):
        raise ApiDocsError('standard producer quality report schema is incomplete')
    # Match cjdoc's native quality denominator; our application contract separately
    # requires every collected parameter, including underscore-prefixed names.
    parameters = sum(not parameter['name'].startswith('_') for item in visible for parameter in item.get('parameters', []))
    for metric, total in (('symbols', len(visible)), ('parameters', parameters)):
        statistics = quality.get(metric, {})
        meaningful = statistics.get('meaningful')
        if (statistics.get('total') != total or type(meaningful) is not int or not 0 <= meaningful <= total
                or statistics.get('percent') != (meaningful * 100 // total if total else 100)):
            raise ApiDocsError('standard producer quality report counts are inconsistent: ' + metric)
    return {'schemaVersion': 'yjson.standard-quality-evidence/1', 'sourceSha256': source_sha,
            'declarationSha256': before, 'declarations': count, 'publicDeclarations': len(visible),
            'standardDocIrSha256': sha256_file(standard / 'docs.json'), 'fullDocIrSha256': sha256_file(site / 'docs.json'),
            'standardFiles': {path.relative_to(standard).as_posix(): sha256_file(path)
                              for path in sorted(standard.rglob('*')) if path.is_file()},
            'quality': 'quality-standard/coverage/quality.json',
            'standardLint': {'profile': 'standard', 'severity': 'default-warning'},
            'displayLint': {'profile': 'standard', 'severity': 'off'},
            'configurationFiles': {name + '-cjdoc.toml': sha256_file(site / 'quality-inputs' / (name + '-cjdoc.toml'))
                                   for name in ('standard', 'full')},
            'standardDiagnostics': dict(sorted(Counter(item['code'] for item in original['diagnostics']).items())),
            'qualityCounts': {key: quality[key] for key in ('symbols', 'parameters')}}


def verify_standard_quality(site: pathlib.Path, source_sha: str, expected: dict) -> dict:
    actual = bind_standard_quality(site / 'quality-standard', site, source_sha)
    if actual != expected:
        raise ApiDocsError('standard quality evidence is missing, changed, or belongs to different inputs')
    return json.loads((site / actual['quality']).read_text(encoding='utf-8'))


def write_maintainer_inventory(site: pathlib.Path) -> dict:
    destination = site / 'maintainer-interfaces'
    destination.mkdir()
    snapshot = ROOT / 'release/public-api-snapshot.txt'
    inventory = ROOT / 'release/public-api-inventory.toml'
    shutil.copyfile(snapshot, destination / snapshot.name)
    shutil.copyfile(inventory, destination / inventory.name)
    rows = [line.split('|', 3) for line in snapshot.read_text(encoding='utf-8').splitlines()
            if line.startswith('c-abi|')]
    listing = ''.join('<tr><td><code>' + html.escape(parts[1]) + '</code></td><td><code>'
                      + html.escape(parts[3]) + '</code></td></tr>' for parts in rows)
    (destination / 'index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
        '<title>维护者接口分类</title><h1>维护者接口分类</h1>'
        '<p>生成代码 SPI 与第一方内部仓颉声明保留在统一 API 站点和覆盖报告中。C ABI 按当前机器清单展示，'
        '不计入八个应用包的中文注释分母，不提供跨版本兼容保证。</p>'
        '<p><a href="public-api-snapshot.txt">完整声明快照</a> · '
        '<a href="public-api-inventory.toml">API 分类清单</a></p>'
        '<table><thead><tr><th>来源</th><th>C ABI 声明</th></tr></thead><tbody>' + listing
        + '</tbody></table></html>\n', encoding='utf-8')
    return {'cAbiDeclarations': len(rows), 'snapshotSha256': sha256_file(snapshot),
            'inventorySha256': sha256_file(inventory), 'html': 'maintainer-interfaces/index.html'}


def validate_agent_result(result: subprocess.CompletedProcess, *, mcp: bool = False, request_id: int = 2) -> dict:
    if result.returncode or 'An exception has occurred:' in result.stdout + result.stderr:
        raise ApiDocsError(f'actual Agent snapshot reader failed (exit {result.returncode}): '
                           + result.stderr[-12000:])
    if mcp:
        responses = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
        response = next((item for item in responses if item.get('id') == request_id), None)
        if not isinstance(response, dict) or response.get('error'):
            raise ApiDocsError('stdio MCP did not return the requested tool response')
        response = response.get('result', {})
        if response.get('isError'):
            raise ApiDocsError('stdio MCP returned a domain error')
        response = response.get('structuredContent', {})
    else:
        response = json.loads(result.stdout)
    if (response.get('schemaVersion') != 'cjdoc.query-result/1'
            or response.get('status') not in ('ok', 'ambiguous', 'source_incomplete')
            or not response.get('result', {}).get('items')):
        raise ApiDocsError('actual Agent snapshot reader did not return documentation matches')
    return response


def validate_agent_page(response: dict, page_id: str, expected_text: str) -> None:
    items = response.get('result', {}).get('items', [])
    if len(items) != 1 or items[0].get('identity', {}).get('pageId') != page_id:
        raise ApiDocsError('Agent reader did not return the requested source guide')
    descriptions = [section.get('value', {}) for section in items[0].get('sections', []) if section.get('name') == 'description']
    if len(descriptions) != 1 or descriptions[0].get('text') != expected_text:
        raise ApiDocsError('Agent source guide description is missing, changed, or truncated')


def documentation_stack() -> dict:
    import resource
    soft, hard = resource.getrlimit(resource.RLIMIT_STACK)
    required_stack = 131072 * 1024
    if soft != resource.RLIM_INFINITY and soft < required_stack:
        if hard != resource.RLIM_INFINITY and hard < required_stack:
            raise ApiDocsError('qualified Agent reading requires a 131072 KiB stack limit')
        resource.setrlimit(resource.RLIMIT_STACK, (required_stack, hard))
    return {'stackSoftBytes': resource.getrlimit(resource.RLIMIT_STACK)[0], 'stackHardBytes': hard}


def validate_agent_reading(binary: pathlib.Path, site: pathlib.Path, environment: dict,
                           guide_pages: list[dict]) -> dict:
    """Consume this complete pack; a small tool fixture cannot substitute for it."""
    snapshot = site / 'html/agent/manifest.json'
    stack = documentation_stack()
    reader_environment = {**environment, 'cjHeapSize': '2GB'}
    binary_sha = sha256_file(binary)
    original_files = html_pack_files(site)
    report = {'schemaVersion': 'yjson.agent-reading-check/3', 'status': 'running',
              'binarySha256': binary_sha, 'snapshotSha256': sha256_file(snapshot),
              'packFiles': original_files, 'packFilesSha256': file_inventory_digest(original_files),
              'resources': {'cjHeapSize': '2GB', **stack}, 'checks': [], 'sourceGuidePages': []}
    def portable(value):
        return str(value).replace(str(site), '<site>').replace(str(binary), '<cjdoc>').replace(str(pathlib.Path.home()), '$HOME')
    def save():
        (site / 'agent-reading-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    def execute(name, argv, data):
        record = {'name': name, 'command': [portable(argument) for argument in argv], 'stdin': data}
        report['checks'].append(record); save()
        started = time.monotonic()
        try:
            result = subprocess.run(argv, input=data, capture_output=True, text=True,
                                    env=reader_environment, timeout=600, check=False)
        except subprocess.TimeoutExpired as error:
            record.update(exitCode=None, stdout=portable(error.stdout or ''), stderr=portable(error.stderr or ''), timedOut=True)
            save()
            raise ApiDocsError('actual Agent reader timed out: ' + name) from error
        record.update(exitCode=result.returncode, stdout=portable(result.stdout), stderr=portable(result.stderr),
                      elapsedSeconds=round(time.monotonic() - started, 3))
        save()
        return result
    request = {'operation': 'search', 'query': 'yjson.YJson', 'limit': 2}
    messages = [{'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
                    'protocolVersion': '2025-11-25', 'capabilities': {},
                    'clientInfo': {'name': 'yjson-doc-check', 'version': '0.2.0'}}},
                {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
                {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/call',
                 'params': {'name': 'search', 'arguments': {'query': 'yjson.YJson', 'limit': 2}}}]
    try:
        query_response = validate_agent_result(execute('query-search',
            [str(binary), 'query', '--snapshot', str(snapshot), '--request', '-'], json.dumps(request)))
        for number, page in enumerate(guide_pages, 3):
            page_id = pathlib.Path(page['source']).stem
            arguments = {'pageId': page_id, 'sections': ['description'], 'maxBytes': 2097152}
            response = validate_agent_result(execute('query-' + page_id,
                [str(binary), 'query', '--snapshot', str(snapshot), '--request', '-'],
                json.dumps({'operation': 'get_symbol', **arguments})))
            validate_agent_page(response, page_id, page['markdown'])
            report['sourceGuidePages'].append(page_id); save()
            messages.append({'jsonrpc': '2.0', 'id': number, 'method': 'tools/call',
                             'params': {'name': 'get_symbol', 'arguments': arguments}})
            print('Agent source guide read: ' + page_id, flush=True)
        mcp = execute('stdio-mcp', [str(binary), 'mcp', '--snapshot', str(snapshot)],
                      ''.join(json.dumps(message) + '\n' for message in messages))
        mcp_response = validate_agent_result(mcp, mcp=True)
        for number, page in enumerate(guide_pages, 3):
            validate_agent_page(validate_agent_result(mcp, mcp=True, request_id=number),
                                pathlib.Path(page['source']).stem, page['markdown'])
        final_files = html_pack_files(site)
        report.update(binarySha256After=sha256_file(binary), packFilesAfterSha256=file_inventory_digest(final_files))
        save()
        if report['binarySha256After'] != binary_sha or final_files != original_files:
            raise ApiDocsError('Agent reading changed its binary or complete pack inputs')
    except Exception as error:
        report.update(status='failed', error=portable(error)); save()
        raise
    report.update(status='passed', queryStatus=query_response['status'], stdioMcpStatus=mcp_response['status'],
                  allPackInputsUnchanged=True, binaryUnchanged=True)
    save()
    (site / 'offline-search-request.json').write_text(json.dumps(request, indent=2) + '\n', encoding='utf-8')
    (site / 'offline-usage.txt').write_text(
        '从解压后的完整目录运行以下命令（使用本候选资格记录中的 cjdoc 版本）：\n'
        'export cjHeapSize=2GB\n'
        'ulimit -s 131072\n'
        'cjdoc query --snapshot html/agent/manifest.json --request offline-search-request.json\n'
        'cjdoc mcp --snapshot html/agent/manifest.json\n'
        '浏览器入口：html/index.html；完整消费方：examples/index.html。\n'
        '未注册为站点页面的仓库补充材料使用固定提交的联网链接，不属于离线页面；'
        'API、已注册指南、源码与示例可离线使用。\n', encoding='utf-8')
    return {**{key: report[key] for key in ('queryStatus', 'stdioMcpStatus', 'snapshotSha256', 'binarySha256',
                                          'packFilesSha256', 'resources', 'sourceGuidePages')},
            'report': 'agent-reading-check.json', 'receiptSha256': sha256_file(site / 'agent-reading-check.json')}


def generate(*, cjdoc_binary: pathlib.Path, output: pathlib.Path,
             config_path: pathlib.Path = DEFAULT_CONFIG, policy_path: pathlib.Path = DEFAULT_POLICY) -> pathlib.Path:
    # All production paths validate qualification. There is deliberately no skip flag.
    binary, binary_sha = validate_qualification(config_path, binary_override=cjdoc_binary)
    config = tomllib.loads(config_path.read_text(encoding='utf-8'))
    policy = tomllib.loads(policy_path.read_text(encoding='utf-8'))
    if (policy.get('schema_version') != 2 or policy.get('doc_ir_schema') != DOC_IR_SCHEMA
            or policy.get('audience') != 'external' or policy.get('allowed_unsupported') != []):
        raise ApiDocsError('cjdoc policy must require external Doc IR v16 with no unsupported declarations')
    graph = load_release_graph()
    output = output.resolve()
    if output.exists() or output.is_symlink():
        raise ApiDocsError('API documentation output already exists')
    output.parent.mkdir(parents=True, exist_ok=True)
    before = source_identity()
    sdk = sdk_identity()
    temporary = tempfile.mkdtemp(prefix='yjson-api-docs-')
    work = pathlib.Path(temporary)
    try:
        frozen = work / 'consumer-sources'
        freeze_sources(ROOT, frozen, before)
        workspace = work / 'workspace'
        create_workspace(workspace, root=frozen, revisions=before)
        standard_configuration = work / 'standard-cjdoc.toml'
        shutil.copyfile(workspace / 'cjdoc.toml', standard_configuration)
        environment = os.environ.copy()
        environment['cjHeapSize'] = '2GB'
        documentation_stack()
        base_command = [str(binary), 'generate', '--project', str(workspace),
                        '--audience', 'external', '--include-path-dependencies', '--jobs', '1', '--no-cache']
        # IR16 has one project repository. A normal source guide records the two
        # actual repositories without inventing machine source URLs or changing digests.
        preliminary = work / 'quality-standard'
        run_generator(base_command + ['--format', 'json', '--format', 'coverage',
                                      '--lint-profile', 'standard',
                                      '--output', str(preliminary)], environment, work / 'preliminary.log')
        validate_doc_ir(preliminary / 'docs.json', package_names=graph.names,
                        generator_version=config['version'], expected_macros=tuple(policy['public_macros']))
        preliminary_document = json.loads((preliminary / 'docs.json').read_text(encoding='utf-8'))
        validate_module_dependencies(preliminary_document, graph)
        from check_api_documentation import validate as validate_application_documentation
        application_bindings = validate_application_documentation(
            preliminary_document,
            json.loads((frozen / 'release/api-documentation-required.json').read_text(encoding='utf-8')),
            require_examples=False,
            quality=json.loads((preliminary / 'coverage/quality.json').read_text(encoding='utf-8')))
        repositories = {package.name: SourceRepository(
            source_root=package.source_root.as_posix(),
            repository_prefix=package.development_manifest.parent.as_posix() if package.name == 'yjson_macros' else '.',
            repository_url=policy['macro_repository_url'] if package.name == 'yjson_macros' else policy['repository_url'],
            revision=before['macroRevision'] if package.name == 'yjson_macros' else before['revision'])
            for package in graph.packages}
        guide_pages, source_guide = render_source_guide(
            preliminary_document, workspace, repositories)
        with (workspace / 'cjdoc.toml').open('a', encoding='utf-8') as stream:
            for page in guide_pages:
                (workspace / page['source']).write_text(page['markdown'], encoding='utf-8')
                stream.write('\n[[docs.pages]]\nsource = ' + json.dumps(page['source']) + '\n'
                             'route = ' + json.dumps(page['route']) + '\nid = '
                             + json.dumps(pathlib.Path(page['source']).stem) + '\nkind = "guide"\n')
            stream.write('\n[lint]\nseverity = "off"\n')
        site = work / 'site'
        command = base_command + ['--format', 'json', '--format', 'html', '--format', 'markdown',
            '--format', 'coverage', '--agent-full', '--doc-version', graph.version,
            '--lint-profile', 'standard', '--output', str(site)]
        run_generator(command, environment, work / 'generation.log')
        report = validate_doc_ir(site / 'docs.json', package_names=graph.names,
                                generator_version=config['version'], expected_macros=tuple(policy['public_macros']))
        validate_module_dependencies(json.loads((site / 'docs.json').read_text(encoding='utf-8')), graph)
        (site / 'quality-inputs').mkdir()
        shutil.copyfile(standard_configuration, site / 'quality-inputs/standard-cjdoc.toml')
        shutil.copyfile(workspace / 'cjdoc.toml', site / 'quality-inputs/full-cjdoc.toml')
        quality_evidence = bind_standard_quality(preliminary, site, before['sha256'])
        shutil.copytree(preliminary, site / 'quality-standard')
        (site / 'standard-quality-evidence.json').write_text(
            json.dumps(quality_evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        required = ('html/index.html', 'html/agent/manifest.json', 'html/agent/docs.json',
                    'html/agent-full-index.json', 'html/llms-full.txt', 'html/search-index.json',
                    'html/navigation-index.json', 'html/concepts/guides/api-source-index.html',
                    'markdown/index.md', 'coverage/quality.json', '.cjdoc-output.json')
        for path in required:
            if not (site / path).is_file() or (site / path).is_symlink():
                raise ApiDocsError('cjdoc did not produce required artifact: ' + path)
        file_links = validate_html_file_links(site)
        agent_reading = validate_agent_reading(binary, site, environment, guide_pages)
        interface_inventory = write_maintainer_inventory(site)
        # Add our own entry and downloads without modifying any cjdoc-owned projection.
        (site / 'index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
            '<title>yjson API</title><h1>yjson API 文档</h1>'
            '<p><a href="html/index.html">统一 API 参考与指南</a></p>'
            '<p><a href="html/concepts/guides/api-source-index.html">精确版本源码索引</a></p>'
            '<p><a href="examples/index.html">完整消费方示例</a></p>'
            '<p><a href="maintainer-interfaces/index.html">维护者接口分类</a></p>'
            '<p><a href="quality-standard/docs.json">完整 standard lint 诊断</a> · '
            '<a href="quality-standard/coverage/quality.json">原生质量报告</a> · '
            '<a href="standard-quality-evidence.json">同源码质量绑定收据</a></p>'
            '<p><a href="downloads/yjson-api-docs-offline.zip">完整离线包</a></p></html>\n', encoding='utf-8')
        if source_identity() != before:
            raise ApiDocsError('documentation inputs changed during generation; rerun from one frozen candidate')
        manifest = {'schemaVersion': 'yjson.api-docs/2', 'qualificationStatus': 'qualified', 'releaseVersion': graph.version,
                    'source': before, 'sdk': sdk, 'generator': {'name': 'cjdoc', 'version': config['version'],
                    'sourceRevision': config['source_revision'], 'binarySha256': binary_sha,
                    'qualification': {
                        'configSha256': sha256_file(config_path),
                        'buildReceiptSha256': sha256_file(binary.parent / 'qualification.json'),
                        'sourceArchiveSha256': config['source_archive_sha256'],
                        'compileOptions': config['compile_options'], 'buildCommand': config['build_command'],
                        'stdxVariant': config['stdx_variant'], 'stdxSha256': config['stdx_sha256'],
                        'toolchainBinarySha256': {'cjc': config['cjc_sha256'], 'cjpm': config['cjpm_sha256']},
                        'buildPolicySha256': config['build_policy_sha256'],
                        'buildWrapperSha256': config['build_wrapper_sha256']}},
                    'packages': [{'name': p.name, 'role': p.role, 'stability': p.stability} for p in graph.packages],
                    'maintainerInterfaces': interface_inventory, 'sourceGuide': source_guide,
                    'standardQuality': quality_evidence, 'htmlFileLinks': file_links,
                    'applicationBindings': application_bindings,
                    'sourceUrlPolicy': 'Doc IR16 machine source URL unavailable; exact repository links are an ordinary source guide',
                    'agentReading': agent_reading, 'consumerSources': 'consumer-sources',
                    'exampleChecking': {
                        'builtinCompiler': 'not-run: per-example consumer profiles and more than 256 examples require the external runner',
                        'runner': 'scripts/run_api_doc_examples.py', 'bodySource': 'Doc IR documentation.tags[name=example].description'},
                    'docIr': 'docs.json', 'docIrSha256': sha256_file(site / 'docs.json'),
                    'html': 'html/index.html', 'report': report}
        shutil.copytree(frozen, site / 'consumer-sources')
        (site / 'api-docs.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        shutil.copytree(site, output)
    except Exception:
        print('API documentation failure evidence retained: ' + str(work), file=sys.stderr)
        raise
    else:
        shutil.rmtree(work)

    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cjdoc', type=pathlib.Path)
    parser.add_argument('--config', type=pathlib.Path, default=DEFAULT_CONFIG)
    parser.add_argument('--policy', type=pathlib.Path, default=DEFAULT_POLICY)
    parser.add_argument('--output', type=pathlib.Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    binary = args.cjdoc or (pathlib.Path(os.environ['YJSON_CJDOC_BINARY']) if os.environ.get('YJSON_CJDOC_BINARY') else None)
    try:
        if binary is None:
            raise ApiDocsError('--cjdoc or YJSON_CJDOC_BINARY is required')
        output = generate(cjdoc_binary=binary.resolve(), output=args.output,
                          config_path=args.config.resolve(), policy_path=args.policy.resolve())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f'API docs error: {error}', file=sys.stderr)
        return 1
    print(f'API documentation generated: {output}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
