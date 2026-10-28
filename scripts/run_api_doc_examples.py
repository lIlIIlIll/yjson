#!/usr/bin/env python3
"""Execute Doc IR examples as source-external, profile-bound cjpm consumers."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True

from check_api_documentation import ROOT, declaration_key, doc_ir_digest, example_tags, visible_declarations
from release_graph import load_release_graph
from generate_api_docs import sdk_identity, source_identity, freeze_sources, verify_frozen_sources, sha256_file

FENCE_OPEN = re.compile(r'^ {0,3}(`{3,}|~{3,})([^\n]*)$')
UNHANDLED = re.compile(r'(?im)^\s*(?:An exception has occurred:|Unhandled(?: exception| error)|Fatal error:)')
SAFE_FLAGS = frozenset(('-O0', '-O1', '-O2', '--int-overflow', 'wrapping', 'throwing'))


def extract_example(tag: dict) -> dict:
    """Use only cjdoc-bound tag prose. Titles cannot select profiles or commands."""
    body = tag.get('description')
    if not isinstance(body, str):
        raise ValueError('example description must be text')
    blocks = []
    fence = language = None
    contents = []
    for line in body.splitlines(keepends=True):
        text = line.removesuffix('\n').removesuffix('\r')
        if fence is None:
            opening = FENCE_OPEN.fullmatch(text)
            if opening:
                fence = opening[1]
                language = opening[2].strip().split()[0] if opening[2].strip() else ''
                contents = []
        elif re.fullmatch(r' {0,3}' + re.escape(fence[0]) + '{' + str(len(fence)) + r',}\s*', text):
            blocks.append((language, ''.join(contents).removesuffix('\n')))
            fence = language = None
        else:
            contents.append(line)
    if fence is not None:
        raise ValueError('example has an unclosed code fence')
    code = '\n'.join(text for language, text in blocks if language.lower() in ('cangjie', 'cj'))
    outputs = [text for language, text in blocks if language.lower() == 'output']
    if not code.strip():
        raise ValueError('example has no cangjie code fence')
    if len(outputs) > 1:
        raise ValueError('example must have at most one expected output fence')
    directives = tag.get('directives', '')
    if not isinstance(directives, str) or not directives.startswith('{') or not directives.endswith('}'):
        raise ValueError('executable example requires explicit run/must-fail directives')
    values: dict[str, str | bool] = {}
    for token in shlex.split(directives[1:-1]):
        name, separator, value = token.partition('=')
        if name not in ('run', 'must-pass', 'must-fail', 'error', 'flags') or name in values:
            raise ValueError('unknown or duplicate example directive: ' + name)
        if name in ('error', 'flags') and (not separator or not value):
            raise ValueError('example directive requires a value: ' + name)
        if name in ('run', 'must-pass', 'must-fail') and separator:
            raise ValueError('boolean example directive cannot have a value: ' + name)
        values[name] = value if separator else True
    if not any(values.get(mode) for mode in ('run', 'must-pass', 'must-fail')):
        raise ValueError('executable example requires an explicit execution mode')
    if values.get('must-fail') and (values.get('run') or values.get('must-pass')):
        raise ValueError('must-fail conflicts with successful execution')
    if values.get('error') and not values.get('must-fail'):
        raise ValueError('error directive requires must-fail')
    flags = shlex.split(str(values.get('flags', '')))
    if any(flag not in SAFE_FLAGS for flag in flags):
        raise ValueError('example compiler flag is outside the whitelist')
    mode = 'must-fail' if values.get('must-fail') else ('run' if values.get('run') else 'must-pass')
    if mode == 'run' and not outputs:
        raise ValueError('run example requires an output fence, including for empty output')
    return {'code': code, 'expected': outputs[0] if outputs else '', 'mode': mode,
            'flags': flags, 'error': values.get('error', ''),
            'sha256': hashlib.sha256(code.encode()).hexdigest()}


def load_profile(name: str, root: pathlib.Path = ROOT) -> tuple[dict, str]:
    if not re.fullmatch(r'[a-z][a-z0-9-]*', name):
        raise ValueError('unsafe consumer profile name')
    directory = root / 'tests/doc_examples' / name
    profile = json.loads((directory / 'profile.json').read_text(encoding='utf-8'))
    if profile.get('schemaVersion') != 1:
        raise ValueError('unsupported consumer profile schema')
    graph = load_release_graph(root / 'release/release-graph.toml')
    if not isinstance(profile.get('dependencies'), list) or not profile['dependencies'] or set(profile['dependencies']) - set(graph.names):
        raise ValueError('consumer profile must list release-graph dependencies')
    if not isinstance(profile.get('imports'), list) or any(not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.]*(?:\.\*)?', item) for item in profile['imports']):
        raise ValueError('consumer imports must be Cangjie import names')
    if not isinstance(profile.get('platforms'), list) or set(profile['platforms']) - {'linux', 'windows', 'darwin'}:
        raise ValueError('consumer platforms must be explicit')
    if not isinstance(profile.get('linkNativeScanner', False), bool):
        raise ValueError('linkNativeScanner must be boolean')
    libraries = profile.get('nativeLibraries', [])
    if (not isinstance(libraries, list) or len(set(libraries)) != len(libraries)
            or set(libraries) - {'yjson_schema_formats', 'idn2'}):
        raise ValueError('native consumer libraries are outside the whitelist')
    for field in ('compileOption', 'overrideCompileOption'):
        if field in profile and profile[field] not in ('-O0', '-O1', '-O2'):
            raise ValueError('consumer optimization option is outside the whitelist')
    prelude_path = directory / 'prelude.cj'
    prelude = prelude_path.read_text(encoding='utf-8') if prelude_path.exists() else ''
    if re.search(r'^\s*(?:package|import|main\s*\()', prelude, re.MULTILINE):
        raise ValueError('consumer prelude must contain only top-level declarations')
    return profile, prelude


def consumer_source(profile: dict, prelude: str, code: str, marker: str) -> str:
    if re.search(r'^\s*(?:package|import|main\s*\()', code, re.MULTILINE):
        raise ValueError('example code must be a body; dependencies and top-level declarations belong to its explicit profile')
    return ('package yjson_doc_example\n' + ''.join('import ' + name + '\n' for name in profile['imports'])
            + '\n' + prelude + '\nmain(): Unit {\n'
            + f'    println("{marker}_BEGIN")\n' + code + '\n'
            + f'    println("{marker}_END")\n' + '}\n')


def consumer_manifest(profile: dict, example: dict, *, override_compile_option: str) -> str:
    """Render the portable manifest with an explicitly resolved actual override."""
    if override_compile_option not in ('-O0', '-O1', '-O2'):
        raise ValueError('unsupported dependency optimization override')
    dependencies = ''.join(f'{dependency} = {{ path = "<modules>/{dependency}" }}\n'
                           for dependency in profile['dependencies'])
    compile_option = profile.get('compileOption', '-O2')
    flags = ' '.join(example['flags'])
    package = ('[package]\nname = "yjson_doc_example"\nversion = "0.0.0"\ncjc-version = "1.2.0"\n'
               'output-type = "executable"\n' + f'compile-option = "{compile_option} {flags}"\n'
               + f'override-compile-option = "{override_compile_option}"\n')
    libraries = (['yjson_scanner'] if profile.get('linkNativeScanner') else []) + profile.get('nativeLibraries', [])
    if libraries:
        package += 'link-option = "-L <project>/target/native ' + ' '.join('-l' + library for library in libraries) + '"\n'
    return package + '\n[dependencies]\n' + dependencies


def check_run_result(result: subprocess.CompletedProcess, example: dict, marker: str) -> tuple[bool, str]:
    output = result.stdout + result.stderr
    if UNHANDLED.search(output):
        return False, 'unhandled exception in consumer output'
    if result.returncode != 0:
        return False, f'consumer exited {result.returncode}'
    start, end = marker + '_BEGIN\n', marker + '_END'
    normalized = result.stdout.replace('\r\n', '\n')
    if normalized.count(start) != 1 or normalized.count(end) != 1:
        return False, 'consumer output markers missing or duplicated'
    observed = normalized.split(start, 1)[1].split(end, 1)[0].removesuffix('\n')
    if observed != example['expected'].replace('\r\n', '\n'):
        return False, 'consumer stdout does not match the Doc IR output fence'
    return True, observed


def sanitize(text: str, paths: dict[str, str]) -> str:
    replacements = {}
    for old, new in paths.items():
        for spelling in (old, old.replace('\\', '/'), old.replace('/', '\\')):
            replacements.setdefault(spelling, new)
    home = str(pathlib.Path.home())
    for spelling in (home, home.replace('\\', '/'), home.replace('/', '\\')):
        replacements.setdefault(spelling, '$HOME')
    for old, new in sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True):
        text = text.replace(old, new)
    return text


def write_if_changed(path: pathlib.Path, contents: str) -> None:
    if not path.exists() or path.read_text(encoding='utf-8') != contents:
        path.write_text(contents, encoding='utf-8', newline='\n')


def set_consumer_stack() -> dict:
    if sys.platform == 'win32':
        return {'mode': 'platform-default'}
    import resource
    soft, hard = resource.getrlimit(resource.RLIMIT_STACK)
    if sys.platform == 'darwin':
        os.environ.setdefault('cjStackSize', '8MB')
        return {'mode': 'platform-default', 'softBytes': soft, 'hardBytes': hard,
                'runtimeThreadStack': os.environ['cjStackSize']}
    required = 131072 * 1024
    if hard != resource.RLIM_INFINITY and hard < required:
        raise ValueError('consumer compiler requires a 131072 KiB stack limit')
    if soft != resource.RLIM_INFINITY and soft < required:
        resource.setrlimit(resource.RLIMIT_STACK, (required, hard))
    return {'softBytes': resource.getrlimit(resource.RLIMIT_STACK)[0], 'hardBytes': hard,
            'targetBytes': required, 'runtimeThreadStack': os.environ.get('cjStackSize', 'default')}


def dependency_artifacts(project: pathlib.Path) -> dict:
    return {path.relative_to(project).as_posix(): sha256_file(path)
            for path in sorted((project / 'target').rglob('*'))
            if path.is_file() and path.suffix in ('.a', '.cjo', '.so', '.dylib', '.dll')}


def build_and_run(project: pathlib.Path, example: dict) -> tuple[subprocess.CompletedProcess, subprocess.CompletedProcess | None]:
    # Same real cjpm build/executable boundary as run_cjpm_executable.sh, with
    # separated build output and portable Windows executable/library discovery.
    build = subprocess.run(['cjpm', 'build', '--verbose'], cwd=project,
                           capture_output=True, text=True, encoding='utf-8', errors='strict', check=False, timeout=300)
    if build.returncode or UNHANDLED.search(build.stdout + build.stderr) or example['mode'] in ('must-fail', 'must-pass'):
        return build, None
    candidates = (project / 'target/release/bin/main', project / 'target/release/bin/main.exe')
    binary = next((path for path in candidates if path.is_file()), None)
    if binary is None:
        raise ValueError('cjpm did not produce its executable')
    environment = os.environ.copy()
    directories = sorted({str(path.parent) for path in (project / 'target/release').rglob('*')
                          if path.is_file() and path.suffix in ('.so', '.dylib', '.dll')})
    if directories:
        for variable in ('PATH',) if sys.platform == 'win32' else ('LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH'):
            environment[variable] = os.pathsep.join(directories + ([environment[variable]] if environment.get(variable) else []))
    run = subprocess.run([str(binary)], cwd=project, env=environment, capture_output=True,
                         text=True, encoding='utf-8', errors='strict', check=False, timeout=60)
    return build, run


def run_examples(site: pathlib.Path, *, contract_path: pathlib.Path | None = None,
                 root: pathlib.Path = ROOT, only_profiles: set[str] | None = None) -> dict:
    report = {'schemaVersion': 'yjson.api-doc-examples/1', 'platform': 'windows' if sys.platform == 'win32' else sys.platform,
              'examples': [], 'failures': 0, 'executedBindings': 0, 'notApplicableBindings': 0,
              'status': 'running', 'stage': 'input',
              'partialProfileSelection': sorted(only_profiles) if only_profiles else None}
    mapping = {'schemaVersion': 'yjson.api-doc-example-mapping/1', 'platform': report['platform'],
               'status': 'running', 'groups': {}}
    try:
        save_json_atomic(site / 'example-execution.json', report)
        save_json_atomic(site / 'example-mapping.json', mapping)
        return _run_examples(site, contract_path=contract_path, root=root, only_profiles=only_profiles, report=report)
    except Exception as error:
        report.update(status='failed', failureStage=report['stage'], failures=max(1, report['failures']),
                      executedBindings=sum(record.get('status') in ('passed', 'failed') for record in report['examples']),
                      notApplicableBindings=sum(record.get('status') == 'not-applicable' for record in report['examples']),
                      error=sanitize(str(error), {str(site): '<site>', str(root): '<repo>',
                                                 tempfile.gettempdir(): '<temporary>'}))
        save_json_atomic(site / 'example-execution.json', report)
        mapping['status'] = 'failed'
        save_json_atomic(site / 'example-mapping.json', mapping)
        raise


def save_json_atomic(path: pathlib.Path, document: dict) -> None:
    pending = path.with_name('.' + path.name + '.pending')
    pending.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    os.replace(pending, path)


def _run_examples(site: pathlib.Path, *, contract_path: pathlib.Path | None,
                  root: pathlib.Path, only_profiles: set[str] | None, report: dict) -> dict:
    document = json.loads((site / 'docs.json').read_text(encoding='utf-8'))
    manifest = json.loads((site / 'api-docs.json').read_text(encoding='utf-8'))
    if manifest.get('docIrSha256') is not None and sha256_file(site / 'docs.json') != manifest['docIrSha256']:
        raise ValueError('example Doc IR differs from the generated artifact')
    frozen_contract = site / 'consumer-sources/release/api-documentation-required.json'
    if contract_path is None:
        contract_path = frozen_contract if manifest.get('consumerSources') else root / 'release/api-documentation-required.json'
    contract_sha = sha256_file(contract_path)
    if manifest.get('qualificationStatus') == 'qualified':
        if contract_sha != manifest.get('source', {}).get('files', {}).get('release/api-documentation-required.json'):
            raise ValueError('example contract differs from the frozen source inventory')
    contract = json.loads(contract_path.read_text(encoding='utf-8'))
    entries = contract['declarations']
    known_profiles = {entry['profile'] for entry in entries.values() if entry.get('category') == 'application'}
    if only_profiles is not None and (not only_profiles or only_profiles - known_profiles):
        raise ValueError('selected example profile is absent from the declaration contract')
    report.update(qualificationStatus=manifest.get('qualificationStatus', 'development-only'),
                  docIrSha256=doc_ir_digest(document), sourceSha256=manifest['source']['sha256'],
                  contractSha256=contract_sha, stage='sdk')
    installed = sdk_identity()
    sdk = {'cjcVersion': installed['version'], 'cjcOutput': installed['cjcVersion'],
           'cjpmOutput': installed['cjpmVersion'], 'cjcSha256': installed['binarySha256']['cjc'],
           'installation': installed}
    report.update(sdk=sdk, stage='stack')
    report['stack'] = set_consumer_stack()
    platform = report['platform']
    exports = site / 'examples'
    exports.mkdir(exist_ok=True)
    records = report['examples']
    def save_report() -> None:
        save_json_atomic(site / 'example-execution.json', report)
    report['stage'] = 'sources'
    save_report()
    with tempfile.TemporaryDirectory(prefix='yjson-doc-examples-') as temporary:
        work = pathlib.Path(temporary)
        if manifest.get('consumerSources'):
            if manifest['consumerSources'] != 'consumer-sources':
                raise ValueError('unsafe frozen consumer source directory')
            selected_root = site / manifest['consumerSources']
            identity = manifest['source']
            verify_frozen_sources(selected_root, identity)
        else:
            if manifest.get('qualificationStatus') == 'qualified':
                raise ValueError('qualified documentation is missing its frozen consumer sources')
            selected_root = root
            identity = source_identity(root)
        frozen = work / 'sources'
        freeze_sources(selected_root, frozen, identity)
        graph = load_release_graph(frozen / 'release/release-graph.toml')
        modules = {p.name: (frozen / p.development_manifest).parent for p in graph.packages}
        path_replacements = {str(work): '<examples>', str(root): '<repo>', str(frozen): '<sources>'}
        profiles: dict[str, tuple[dict, str]] = {}
        report['stage'] = 'examples'
        for declaration in visible_declarations(document):
            key = declaration_key(declaration)
            entry = entries.get(key)
            if not entry or entry.get('category') != 'application':
                continue
            name = entry.get('profile')
            if not name or only_profiles is not None and name not in only_profiles:
                continue
            if name not in profiles:
                profiles[name] = load_profile(name, frozen)
            profile, prelude = profiles[name]
            project = work / name
            (project / 'src').mkdir(parents=True, exist_ok=True)
            profile_sha = sha256_file(frozen / 'tests/doc_examples' / name / 'profile.json')
            prelude_sha = hashlib.sha256(prelude.encode()).hexdigest()
            for index, tag in enumerate(example_tags(declaration)):
                example = extract_example(tag)
                identifier = hashlib.sha256((key + ':' + str(index)).encode()).hexdigest()
                marker = 'YJSON_DOC_' + identifier[:24]
                source = consumer_source(profile, prelude, example['code'], marker)
                source_path = exports / (identifier + '.cj')
                source_path.write_text(source, encoding='utf-8', newline='\n')
                compile_option = profile.get('compileOption', '-O2')
                override = profile.get('overrideCompileOption', os.environ.get('YJSON_CI_DEPENDENCY_OVERRIDE') or '-O2')
                portable = consumer_manifest(profile, example, override_compile_option=override)
                (exports / (identifier + '.toml')).write_text(portable, encoding='utf-8', newline='\n')
                record = {'declaration': key, 'exampleIndex': index, 'profile': name,
                          'codeSha256': example['sha256'], 'consumerSha256': hashlib.sha256(source.encode()).hexdigest(),
                          'profileSha256': profile_sha, 'preludeSha256': prelude_sha,
                          'frozenSourceSha256': identity['sha256'], 'source': 'examples/' + source_path.name,
                          'manifest': 'examples/' + identifier + '.toml', 'mode': example['mode'],
                          'platforms': profile['platforms'], 'expectedStdout': example['expected'],
                          'compileOption': compile_option, 'overrideCompileOption': override}
                records.append(record)
                if platform not in profile['platforms']:
                    record.update(status='not-applicable', reason='profile does not target this platform')
                    save_report()
                    continue
                actual_manifest = portable
                for dependency, directory in modules.items():
                    actual_manifest = actual_manifest.replace('<modules>/' + dependency + '"', directory.as_posix() + '"')
                actual_manifest = actual_manifest.replace('<project>', project.as_posix())
                write_if_changed(project / 'cjpm.toml', actual_manifest)
                write_if_changed(project / 'src/main.cj', source)
                started = time.monotonic()
                try:
                    build, result = build_and_run(project, example)
                    record.update(buildCommand=['cjpm', 'build', '--verbose'], buildExitCode=build.returncode,
                                  buildStdout=sanitize(build.stdout, path_replacements), buildStderr=sanitize(build.stderr, path_replacements),
                                  dependencyArtifacts=dependency_artifacts(project))
                    if result is not None:
                        record.update(command=[sanitize(str(argument), path_replacements) for argument in result.args],
                                      executableSha256=sha256_file(pathlib.Path(result.args[0])),
                                      exitCode=result.returncode, stdout=sanitize(result.stdout, path_replacements),
                                      stderr=sanitize(result.stderr, path_replacements))
                    else:
                        record.update(command=['cjpm', 'build', '--verbose'], exitCode=build.returncode,
                                      stdout='', stderr='')
                    if example['mode'] == 'must-fail':
                        first_line = source[:source.index(example['code'])].count('\n') + 1
                        last_line = first_line + example['code'].count('\n')
                        lines = [int(line) for line in re.findall(r'main\.cj:(\d+)(?::\d+)?', build.stdout + build.stderr)]
                        passed = build.returncode != 0 and any(first_line <= line <= last_line for line in lines) and (not example['error'] or example['error'] in build.stdout + build.stderr)
                        reason = 'expected source compilation failure' if passed else 'negative example did not fail in its own source as required'
                    elif build.returncode or UNHANDLED.search(build.stdout + build.stderr):
                        passed, reason = False, f'consumer build failed or reported an unhandled exception (exit {build.returncode})'
                    elif example['mode'] == 'must-pass':
                        passed, reason = True, 'compiled successfully'
                    else:
                        assert result is not None
                        passed, reason = check_run_result(result, example, marker)
                    record.update(status='passed' if passed else 'failed', result=reason)
                except subprocess.TimeoutExpired as error:
                    record.update(status='failed', result='consumer timed out', exitCode=None,
                                  stdout=sanitize(str(error.stdout or ''), path_replacements), stderr=sanitize(str(error.stderr or ''), path_replacements))
                except (OSError, ValueError) as error:
                    record.update(status='failed', result=str(error), exitCode=None, stdout='', stderr='')
                record['elapsedSeconds'] = round(time.monotonic() - started, 3)
                if record['status'] != 'passed':
                    report['failures'] += 1
                    print(f'example failed: {key} [{index}]: {record["result"]}', file=sys.stderr, flush=True)
                else:
                    print(f'example passed: {declaration["qualifiedName"]} [{index}] ({record["elapsedSeconds"]}s)', flush=True)
                save_report()
        verify_frozen_sources(frozen, identity)
    expected = sum(len(example_tags(declaration)) for declaration in visible_declarations(document)
                   if entries.get(declaration_key(declaration), {}).get('category') == 'application'
                   and (only_profiles is None or entries[declaration_key(declaration)].get('profile') in only_profiles))
    if not expected or len(records) != expected or not any(record['status'] != 'not-applicable' for record in records):
        raise ValueError('example execution did not cover the expected nonempty binding inventory')
    report['expectedBindings'] = expected
    report['executedBindings'] = sum(record['status'] != 'not-applicable' for record in records)
    report['notApplicableBindings'] = sum(record['status'] == 'not-applicable' for record in records)
    report.update(status='complete', stage='complete')
    save_report()
    links = ''.join('<li><code>' + html.escape(record['declaration']) + '</code> '
                    + '<a href="' + pathlib.Path(record['source']).name + '">完整消费方源码</a> '
                    + '<a href="' + pathlib.Path(record['manifest']).name + '">依赖清单</a></li>' for record in records)
    (exports / 'index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
        '<title>yjson API 可执行示例</title><h1>API 可执行示例</h1>'
        '<p>源码来自同一份 Doc IR 与显式消费方 profile。依赖清单中的 &lt;modules&gt; '
        '对应离线包 consumer-sources 中的九个包；&lt;project&gt; 对应消费方目录。</p><ul>' + links + '</ul></html>\n', encoding='utf-8')
    groups: dict[str, dict] = {}
    for record in records:
        group_id = hashlib.sha256((record['profile'] + ':' + record['codeSha256']).encode()).hexdigest()
        group = groups.setdefault(group_id, {'profile': record['profile'], 'codeSha256': record['codeSha256'], 'bindings': []})
        group['bindings'].append({'declaration': record['declaration'], 'exampleIndex': record['exampleIndex'], 'status': record['status']})
    save_json_atomic(site / 'example-mapping.json', {'schemaVersion': 'yjson.api-doc-example-mapping/1',
        'docIrSha256': report['docIrSha256'], 'groups': groups})
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('site', type=pathlib.Path)
    parser.add_argument('--contract', type=pathlib.Path)
    parser.add_argument('--only-profile', action='append')
    args = parser.parse_args()
    try:
        report = run_examples(args.site.resolve(), contract_path=args.contract.resolve() if args.contract else None,
                              only_profiles=set(args.only_profile) if args.only_profile else None)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f'API documentation examples error: {error}', file=sys.stderr)
        return 1
    print(f'Doc IR examples: {len(report["examples"])} records, {report["failures"]} failures')
    return int(report['failures'] != 0)


if __name__ == '__main__':
    raise SystemExit(main())
