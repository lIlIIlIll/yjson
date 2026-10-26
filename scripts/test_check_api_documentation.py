#!/usr/bin/env python3
"""Regressions for complete declarations, overloads, binding, and execution proof."""
from copy import deepcopy
import hashlib
import json
import unittest
import pathlib
import tempfile
import zipfile
import io
import shutil
import os
from unittest.mock import patch

from check_api_documentation import declaration_key, doc_ir_digest, validate, write_offline_archive, verify_agent_reading, main
from run_api_doc_examples import extract_example, load_profile, consumer_source, ROOT


def fixture():
    example = {'name': 'example', 'directives': '{run}', 'description': '```cangjie\nprintln(Example().read("{}"))\n```\n```output\nvalue\n```'}
    owner = {'id': 'owner', 'name': 'Example', 'qualifiedName': 'yjson.Example', 'packageName': 'yjson',
             'ownerId': None, 'visibility': 'public', 'kind': 'class', 'parameters': [],
             'headerSpelling': 'public class Example', 'documentation': {'summary': '读取 JSON。', 'tags': []}}
    member = {'id': 'method', 'name': 'read', 'qualifiedName': 'yjson.Example.read', 'packageName': 'yjson',
              'ownerId': 'owner', 'visibility': 'public', 'kind': 'function',
              'headerSpelling': 'public func read(text: String): String',
              'parameters': [{'name': 'text', 'documentation': None}], 'returnType': {'spelling': 'String'},
              'documentation': {'summary': '读取文本。', 'tags': [{'name': 'param', 'subject': 'text', 'description': '输入 JSON。'},
                  {'name': 'return', 'description': '读取结果。'}, example]}}
    document = {'schemaVersion': 'cjdoc.doc-ir/16', 'packages': [{'name': 'yjson'}],
                'declarations': [owner, member], 'unsupportedDeclarations': []}
    contract = {'schemaVersion': 2, 'cjcVersion': '1.2.0', 'packages': ['yjson'],
                'requiredOwners': {'Example': {'read': 1}}, 'declarations': {
                    declaration_key(owner): {'category': 'application', 'profile': 'core'},
                    declaration_key(member): {'category': 'application', 'profile': 'core'}}}
    execution = {'schemaVersion': 'yjson.api-doc-examples/1', 'docIrSha256': doc_ir_digest(document),
                 'qualificationStatus': 'qualified',
                 'status': 'complete', 'failures': 0, 'partialProfileSelection': None,
                 'sourceSha256': 'source', 'sdk': {'cjcVersion': '1.2.0', 'cjcSha256': 'compiler'},
                 'platform': 'linux',
                 'examples': [{'declaration': declaration_key(member), 'exampleIndex': 0, 'profile': 'core',
                               'codeSha256': extract_example(example)['sha256'], 'status': 'passed',
                               'exitCode': 0, 'stdout': '', 'stderr': ''}]}
    identity = hashlib.sha256((declaration_key(member) + ':0').encode()).hexdigest()
    marker = 'YJSON_DOC_' + identity[:24]
    profile, prelude = load_profile('core')
    execution['examples'][0].update(
        stdout=marker + '_BEGIN\nvalue\n' + marker + '_END\n', mode='run', buildExitCode=0,
        frozenSourceSha256='source', executableSha256='1' * 64,
        dependencyArtifacts={'target/release/yjson/libyjson.a': '2' * 64},
        profileSha256=hashlib.sha256((ROOT / 'tests/doc_examples/core/profile.json').read_bytes()).hexdigest(),
        preludeSha256=hashlib.sha256(prelude.encode()).hexdigest(),
        consumerSha256=hashlib.sha256(consumer_source(profile, prelude, extract_example(example)['code'], marker).encode()).hexdigest())
    return document, contract, execution


class DocumentationContractTest(unittest.TestCase):
    def check(self, fixture_value, *, update_ir=True):
        document, contract, execution = fixture_value
        if update_ir and execution is not None:
            execution['docIrSha256'] = doc_ir_digest(document)
        return validate(document, contract, execution, expected_source_sha256='source')

    def test_accepts_bound_comments_with_executed_source_identical_example(self):
        report = self.check(fixture())
        self.assertEqual(report['requiredDeclarations'], 2)
        self.assertEqual(report['executedPositiveExamples'], 1)

    def test_disappearing_declaration_or_overload_fails(self):
        f = fixture(); f[0]['declarations'].pop()
        with self.assertRaisesRegex(ValueError, 'required declaration missing'):
            self.check(f)

    def test_new_public_declaration_requires_explicit_classification(self):
        f = fixture(); extra = deepcopy(f[0]['declarations'][1]); extra.update(id='new', name='new', qualifiedName='yjson.Example.new')
        f[0]['declarations'].append(extra)
        with self.assertRaisesRegex(ValueError, 'unclassified public declaration'):
            self.check(f)

    def test_implicit_interface_member_is_not_hidden(self):
        f = fixture(); f[0]['declarations'][0]['kind'] = 'interface'
        f[0]['declarations'][0]['headerSpelling'] = 'public interface Example'
        contract = f[1]['declarations']; old = next(k for k in contract if '|class|' in k)
        contract[declaration_key(f[0]['declarations'][0])] = contract.pop(old)
        f[0]['declarations'][1]['documentation'] = None
        with self.assertRaisesRegex(ValueError, 'summary'):
            self.check(f)

    def test_member_of_private_owner_is_not_an_application_entry(self):
        f = fixture(); private = deepcopy(f[0]['declarations'][0]); private.update(id='private', visibility='private')
        member = deepcopy(f[0]['declarations'][1]); member.update(id='private-member', ownerId='private', qualifiedName='yjson.Hidden.read')
        f[0]['declarations'] += [private, member]
        self.check(f)

    def test_empty_or_unbound_parameter_and_return_fail(self):
        for tag_name in ('param', 'return'):
            f = fixture(); tags = f[0]['declarations'][1]['documentation']['tags']
            next(t for t in tags if t['name'] == tag_name)['description'] = ' '
            with self.subTest(tag=tag_name), self.assertRaisesRegex(ValueError, '@' + tag_name):
                self.check(f)

    def test_parameter_tag_bound_to_wrong_name_fails(self):
        f = fixture(); f[0]['declarations'][1]['documentation']['tags'][0]['subject'] = 'other'
        with self.assertRaisesRegex(ValueError, '@param text'):
            self.check(f)

    def test_example_not_run_and_wrong_output_status_fail(self):
        for status in ('missing', 'failed'):
            f = fixture()
            if status == 'missing': f[2]['examples'] = []
            else: f[2]['examples'][0]['status'] = 'failed'
            with self.subTest(status=status), self.assertRaisesRegex(ValueError, 'example'):
                self.check(f)

    def test_changed_code_or_sdk_or_source_cannot_reuse_evidence(self):
        for field in ('code', 'sdk', 'source'):
            f = fixture()
            if field == 'code': f[2]['examples'][0]['codeSha256'] = 'different'
            if field == 'sdk': f[2]['sdk']['cjcVersion'] = '1.1.3'
            if field == 'source': f[2]['sourceSha256'] = 'different'
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'mismatch|different'):
                self.check(f)

    def test_same_sdk_version_with_different_installed_bits_is_rejected(self):
        document, contract, execution = fixture()
        execution['sdk']['installation'] = {'binarySha256': {'cjc': 'original'}}
        with self.assertRaisesRegex(ValueError, 'installation identity mismatch'):
            validate(document, contract, execution, expected_sdk={'binarySha256': {'cjc': 'different'}})

    def test_different_prelude_consumer_or_frozen_dependencies_cannot_reuse_evidence(self):
        for field in ('preludeSha256', 'profileSha256', 'consumerSha256', 'frozenSourceSha256'):
            f = fixture(); f[2]['examples'][0][field] = 'different'
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'hash mismatch'):
                self.check(f)

    def test_successful_stdout_cannot_hide_missing_artifacts_or_a_failed_build(self):
        for field, value in (('dependencyArtifacts', {}), ('executableSha256', ''), ('buildExitCode', 1),
                             ('buildStderr', 'An exception has occurred:\ncompile failure')):
            f = fixture(); f[2]['examples'][0][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'artifact identities'):
                self.check(f)

    def test_a_different_declaration_contract_cannot_reuse_execution(self):
        document, contract, execution = fixture()
        execution['contractSha256'] = 'original'
        with self.assertRaisesRegex(ValueError, 'different declaration contract'):
            validate(document, contract, execution, expected_contract_sha256='different')

    def test_absent_ir_return_type_cannot_hide_return_documentation_requirement(self):
        f = fixture(); f[0]['declarations'][1]['returnType'] = None
        with self.assertRaisesRegex(ValueError, 'return type'):
            self.check(f)

    def test_cjdoc_placeholder_findings_block_the_application_surface(self):
        document, contract, execution = fixture()
        quality = {'schemaVersion': 'cjdoc.documentation-quality/1', 'audience': 'external',
                   'findings': [{'symbolId': 'method', 'code': 'CJDOC3048', 'message': 'parameter text'}]}
        with self.assertRaisesRegex(ValueError, 'CJDOC3048'):
            validate(document, contract, execution, quality=quality)

    def test_unknown_unsupported_fails(self):
        f = fixture(); f[0]['unsupportedDeclarations'] = [{'name': 'new'}]
        with self.assertRaisesRegex(ValueError, 'unsupported'):
            self.check(f)

    def test_chinese_summary_and_preserved_owner_inventory_are_required(self):
        f = fixture(); f[0]['declarations'][0]['documentation']['summary'] = 'Example.'
        with self.assertRaisesRegex(ValueError, 'Chinese'):
            self.check(f)
        f = fixture(); f[1]['requiredOwners']['Example']['read'] = 2
        with self.assertRaisesRegex(ValueError, 'at least 2'):
            self.check(f)

    def test_running_or_partial_execution_is_not_a_completed_acceptance(self):
        for field, value in (('status', 'running'), ('partialProfileSelection', ['core'])):
            f = fixture(); f[2][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'incomplete'):
                self.check(f)

    def test_offline_archive_preserves_agent_shards_sources_and_example_receipts(self):
        with tempfile.TemporaryDirectory() as directory:
            site = pathlib.Path(directory)
            expected = {'html/agent/manifest.json': '{}', 'html/agent/symbols/a.md': 'API',
                        'html/llms-full.txt': 'Full', 'consumer-sources/LICENSE': 'License',
                        'quality-standard/.cjdoc-output.json': 'original ownership bytes',
                        'quality-standard/docs.json': 'original standard diagnostics bytes',
                        'quality-standard/coverage/quality.json': 'original quality bytes',
                        'standard-quality-evidence.json': 'source-bound receipt',
                        'example-execution.json': 'receipt'}
            for relative, contents in expected.items():
                path = site / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_text(contents)
            archive = write_offline_archive(site)
            with zipfile.ZipFile(archive) as opened:
                self.assertEqual(set(opened.namelist()), set(expected))
                for relative, contents in expected.items():
                    self.assertEqual(opened.read(relative).decode(), contents)


class ExportArchiveBoundaryTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.base = pathlib.Path(self.temporary.name); self.counter = 0

    def artifact(self):
        self.counter += 1; site = self.base / str(self.counter); site.mkdir()
        document, contract, execution = fixture()
        frozen = site / 'consumer-sources'
        contents = {'src/input.cj': b'package example\n',
                    'release/api-documentation-required.json': json.dumps(contract).encode(),
                    'tests/doc_examples/core/profile.json': (ROOT / 'tests/doc_examples/core/profile.json').read_bytes()}
        for relative, body in contents.items():
            path = frozen / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(body)
        source = {'sha256': 'source', 'files': {name: hashlib.sha256(body).hexdigest() for name, body in contents.items()}}
        execution['contractSha256'] = source['files']['release/api-documentation-required.json']
        execution['sdk']['installation'] = {}
        record = execution['examples'][0]
        identifier = hashlib.sha256((record['declaration'] + ':0').encode()).hexdigest()
        record.update(source='examples/' + identifier + '.cj', manifest='examples/' + identifier + '.toml',
                      compileOption='-O2', overrideCompileOption='-O2')
        profile, prelude = load_profile('core')
        example = extract_example(document['declarations'][1]['documentation']['tags'][-1])
        (site / 'examples').mkdir()
        (site / 'examples/index.html').write_bytes(b'<!doctype html><title>Consumer exports</title>')
        (site / record['source']).write_bytes(consumer_source(profile, prelude, example['code'], 'YJSON_DOC_' + identifier[:24]).encode())
        # Independent literal oracle: compare the delivered bytes, not a second renderer.
        (site / record['manifest']).write_text('[package]\nname = "yjson_doc_example"\nversion = "0.0.0"\ncjc-version = "1.2.0"\n'
            'output-type = "executable"\ncompile-option = "-O2 "\noverride-compile-option = "-O2"\n\n'
            '[dependencies]\nyjson = { path = "<modules>/yjson" }\n', encoding='utf-8')
        (site / 'docs.json').write_text(json.dumps(document))
        manifest = {'qualificationStatus': 'qualified', 'consumerSources': 'consumer-sources',
                    'source': source, 'sdk': {}, 'standardQuality': {},
                    'docIrSha256': hashlib.sha256((site / 'docs.json').read_bytes()).hexdigest()}
        (site / 'api-docs.json').write_text(json.dumps(manifest))
        (site / 'standard-quality-evidence.json').write_text('{}')
        self.save_execution(site, execution)
        return site, manifest, execution

    def save_execution(self, site, execution):
        (site / 'example-execution.json').write_text(json.dumps(execution))

    def check(self, site, manifest):
        # Isolate final downloadable bytes; the pre-existing quality/reader gates
        # have their own real-file regression suites and must not execute here.
        contract = site / 'consumer-sources/release/api-documentation-required.json'
        with patch('sys.argv', ['check_api_documentation.py', str(site), '--contract', str(contract)]), patch(
                'generate_api_docs.source_identity', return_value=manifest['source']), patch(
                'generate_api_docs.verify_standard_quality', return_value=None), patch(
                'check_api_documentation.verify_agent_reading', return_value={'status': 'accepted'}), patch(
                'check_api_documentation.write_offline_archive', wraps=write_offline_archive) as archive, patch(
                'sys.stdout', new_callable=io.StringIO), patch('sys.stderr', new_callable=io.StringIO):
            result = main()
        return result, archive.call_count

    def test_original_exported_bytes_are_accepted_and_archived(self):
        site, manifest, _ = self.artifact()
        self.assertEqual(self.check(site, manifest), (0, 1))

    def test_post_execution_frozen_source_tamper_missing_and_extra_are_rejected(self):
        for mode in ('tamper', 'missing', 'extra'):
            with self.subTest(mode=mode):
                site, manifest, _ = self.artifact(); path = site / 'consumer-sources/src/input.cj'
                if mode == 'tamper': path.write_bytes(b'package changed\n')
                elif mode == 'missing': path.unlink()
                else: (path.parent / 'extra.cj').write_bytes(b'package unexecuted\n')
                self.assertEqual(self.check(site, manifest), (1, 0))

    def test_unbound_example_files_and_nested_exports_are_rejected(self):
        for relative in ('extra.cj', 'extra.toml', 'nested/extra.cj', 'nested/extra.toml'):
            with self.subTest(relative=relative):
                site, manifest, _ = self.artifact(); path = site / 'examples' / relative
                path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b'unbound bytes\n')
                self.assertEqual(self.check(site, manifest), (1, 0))

    def test_frozen_source_file_directory_and_root_symlinks_are_rejected(self):
        for mode in ('file', 'directory', 'root'):
            with self.subTest(mode=mode):
                site, manifest, _ = self.artifact()
                path = site / 'consumer-sources' / ('src/input.cj' if mode == 'file' else 'src')
                if mode == 'root': path = site / 'consumer-sources'
                external = site / 'outside'; path.rename(external)
                path.symlink_to(external, target_is_directory=mode != 'file')
                self.assertEqual(self.check(site, manifest), (1, 0))

    def test_exported_source_and_manifest_tamper_or_missing_are_rejected(self):
        for field in ('source', 'manifest'):
            for mode in ('tamper', 'missing'):
                with self.subTest(field=field, mode=mode):
                    site, manifest, execution = self.artifact(); path = site / execution['examples'][0][field]
                    if mode == 'tamper': path.write_bytes(b'changed delivered bytes\n')
                    else: path.unlink()
                    self.assertEqual(self.check(site, manifest), (1, 0))

    def test_exported_paths_must_be_canonical_even_when_target_bytes_match(self):
        for field in ('source', 'manifest'):
            for mode in ('other-name', 'parent', 'absolute'):
                with self.subTest(field=field, mode=mode):
                    site, manifest, execution = self.artifact(); record = execution['examples'][0]
                    original = site / record[field]
                    alternate = site / ('other.cj' if field == 'source' else 'other.toml')
                    if mode == 'parent': alternate = site.parent / ('external-' + str(self.counter))
                    shutil.copyfile(original, alternate)
                    record[field] = str(alternate) if mode == 'absolute' else ('../' + alternate.name if mode == 'parent' else alternate.name)
                    self.save_execution(site, execution)
                    self.assertEqual(self.check(site, manifest), (1, 0))

    def test_exported_file_and_ancestor_symlinks_are_rejected(self):
        for field in ('source', 'manifest', 'directory'):
            with self.subTest(field=field):
                site, manifest, execution = self.artifact()
                path = site / (execution['examples'][0][field] if field != 'directory' else 'examples')
                external = site / 'outside-export'; path.rename(external)
                path.symlink_to(external, target_is_directory=field == 'directory')
                self.assertEqual(self.check(site, manifest), (1, 0))

    def test_recorded_o2_manifest_is_independent_of_checker_environment(self):
        site, manifest, _ = self.artifact()
        with patch.dict(os.environ, {'YJSON_CI_DEPENDENCY_OVERRIDE': '-O1'}):
            self.assertEqual(self.check(site, manifest), (0, 1))

    def test_invalid_profile_conflicting_or_nonproduction_optimization_is_rejected(self):
        for field, option in (('overrideCompileOption', '--output elsewhere'), ('overrideCompileOption', '-O1'),
                              ('compileOption', '-O1')):
            with self.subTest(field=field, option=option):
                site, manifest, execution = self.artifact(); execution['examples'][0][field] = option
                self.save_execution(site, execution)
                self.assertEqual(self.check(site, manifest), (1, 0))

    def test_crlf_export_bytes_cannot_reuse_lf_execution_inputs(self):
        for field in ('source', 'manifest'):
            with self.subTest(field=field):
                site, manifest, execution = self.artifact(); path = site / execution['examples'][0][field]
                path.write_bytes(path.read_bytes().replace(b'\n', b'\r\n'))
                self.assertEqual(self.check(site, manifest), (1, 0))

    def test_extra_record_cannot_introduce_an_unbound_export(self):
        site, manifest, execution = self.artifact()
        extra = deepcopy(execution['examples'][0]); extra['declaration'] = 'unbound'
        execution['examples'].append(extra); self.save_execution(site, execution)
        self.assertEqual(self.check(site, manifest), (1, 0))

    def test_legal_environment_override_still_cannot_lower_qualified_o2_policy(self):
        site, manifest, execution = self.artifact()
        profile, prelude = load_profile('core'); profile = dict(profile); profile.pop('overrideCompileOption', None)
        record = execution['examples'][0]; record['overrideCompileOption'] = '-O1'
        path = site / record['manifest']
        path.write_bytes(path.read_bytes().replace(b'override-compile-option = "-O2"', b'override-compile-option = "-O1"'))
        self.save_execution(site, execution)
        with patch('run_api_doc_examples.load_profile', return_value=(profile, prelude)):
            self.assertEqual(self.check(site, manifest), (1, 0))

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'named pipes require POSIX')
    def test_nonregular_inputs_are_rejected_without_opening_a_fifo(self):
        for field in ('frozen', 'source', 'manifest'):
            with self.subTest(field=field):
                site, manifest, execution = self.artifact()
                path = site / ('consumer-sources/src/input.cj' if field == 'frozen' else execution['examples'][0][field])
                path.unlink(); os.mkfifo(path)
                self.assertEqual(self.check(site, manifest), (1, 0))


class ReaderEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.base = pathlib.Path(self.temporary.name); self.counter = 0

    def fixture(self):
        self.counter += 1; site = self.base / str(self.counter); (site / 'html/agent').mkdir(parents=True)
        (site / 'html/index.html').write_text('<a href="concepts/guides/api-source-yjson.html">源码</a>')
        snapshot = 'cjdoc:snapshot:v1:fixture'
        (site / 'html/agent/manifest.json').write_text(json.dumps({'snapshotId': snapshot}))
        text = '# 中文源码\n[` yjson.read；public func read(): Unit；src/api.cj:2 `](https://github.com/example/library/blob/' + '1' * 40 + '/src/api.cj#L2)\n'
        pages = [{'id': 'api-source-index', 'source': 'docs/api-source-index.md', 'text': '# 源码索引\n'},
                 {'id': 'api-source-yjson', 'source': 'docs/api-source-yjson.md', 'text': text}]
        document = {'pages': pages}
        (site / 'docs.json').write_text(json.dumps(document, ensure_ascii=False))
        metadata = [{'source': page['source'], 'bytes': len(page['text'].encode()),
                     'sha256': hashlib.sha256(page['text'].encode()).hexdigest()} for page in pages]
        requests = [{'operation': 'search', 'query': 'yjson.YJson', 'limit': 2}]
        requests += [{'operation': 'get_symbol', 'pageId': page['id'], 'sections': ['description'], 'maxBytes': 2097152} for page in pages]
        def response(request):
            page = next((page for page in pages if page['id'] == request.get('pageId')), None)
            return {'schemaVersion': 'cjdoc.query-result/1', 'status': 'ok', 'error': None,
                    'operation': request['operation'], 'scope': {'requested': request, 'snapshots': [{
                        'snapshotId': snapshot, 'sourceSnapshotId': snapshot, 'sourceKind': 'machine-manifest'}]},
                    'result': {'items': [{'identity': {'pageId': page['id']}, 'sections': [{
                        'name': 'description', 'value': {'text': page['text']}}]}] if page else [{'identity': {'symbolId': 'symbol'}}]},
                    'completeness': {'query': {'complete': bool(page)}, 'content': {'complete': bool(page)}}}
        query_command = ['<cjdoc>', 'query', '--snapshot', '<site>/html/agent/manifest.json', '--request', '-']
        checks = [{'name': 'query-search' if index == 0 else 'query-' + request['pageId'], 'command': query_command,
                   'stdin': json.dumps(request), 'exitCode': 0, 'stdout': json.dumps(response(request), ensure_ascii=False), 'stderr': ''}
                  for index, request in enumerate(requests)]
        initialize = {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
            'protocolVersion': '2025-11-25', 'capabilities': {}, 'clientInfo': {'name': 'yjson-doc-check', 'version': '0.2.0'}}}
        messages = [initialize, {'jsonrpc': '2.0', 'method': 'notifications/initialized'}]
        replies = [{'jsonrpc': '2.0', 'id': 1, 'result': {'protocolVersion': '2025-11-25'}}]
        for identifier, request in enumerate(requests, 2):
            messages.append({'jsonrpc': '2.0', 'id': identifier, 'method': 'tools/call', 'params': {
                'name': request['operation'], 'arguments': {key: value for key, value in request.items() if key != 'operation'}}})
            replies.append({'jsonrpc': '2.0', 'id': identifier, 'result': {'isError': False, 'structuredContent': response(request)}})
        checks.append({'name': 'stdio-mcp', 'command': ['<cjdoc>', 'mcp', '--snapshot', '<site>/html/agent/manifest.json'],
                       'stdin': ''.join(json.dumps(message) + '\n' for message in messages), 'exitCode': 0,
                       'stdout': ''.join(json.dumps(reply, ensure_ascii=False) + '\n' for reply in replies), 'stderr': ''})
        files = {path.relative_to(site).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in sorted((site / 'html').rglob('*')) if path.is_file()}
        digest = hashlib.sha256(json.dumps(files, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        receipt = {'schemaVersion': 'yjson.agent-reading-check/3', 'status': 'passed', 'binarySha256': 'a' * 64,
                   'binarySha256After': 'a' * 64, 'snapshotSha256': files['html/agent/manifest.json'],
                   'packFiles': files, 'packFilesSha256': digest, 'packFilesAfterSha256': digest,
                   'resources': {'cjHeapSize': '2GB', 'stackSoftBytes': 134217728, 'stackHardBytes': -1},
                   'checks': checks, 'sourceGuidePages': [page['id'] for page in pages],
                   'queryStatus': 'ok', 'stdioMcpStatus': 'ok', 'allPackInputsUnchanged': True, 'binaryUnchanged': True}
        manifest = {'generator': {'binarySha256': 'a' * 64},
                    'sourceGuide': {'schemaVersion': 'yjson.api-doc-source-guide/2', 'pages': metadata}}
        self.write(site, manifest, receipt)
        return site, manifest, receipt, document

    def write(self, site, manifest, receipt):
        path = site / 'agent-reading-check.json'; path.write_text(json.dumps(receipt, ensure_ascii=False))
        manifest['agentReading'] = {key: receipt[key] for key in ('queryStatus', 'stdioMcpStatus', 'snapshotSha256',
            'binarySha256', 'packFilesSha256', 'resources', 'sourceGuidePages')}
        manifest['agentReading'].update(report='agent-reading-check.json', receiptSha256=hashlib.sha256(path.read_bytes()).hexdigest())

    def test_rechecks_raw_query_and_mcp_without_executing_a_reader(self):
        site, manifest, _, document = self.fixture()
        with patch('subprocess.run', side_effect=AssertionError('reader must not run')):
            result = verify_agent_reading(site, manifest, document)
        self.assertEqual(result, {'status': 'accepted', 'packFiles': 2, 'sourceGuidePages': 2,
                                  'queryExecutions': 3, 'stdioMcpPageResponses': 2})

    def test_final_html_tamper_missing_or_extra_resource_fails(self):
        for mode in ('tamper', 'missing', 'extra'):
            with self.subTest(mode=mode):
                site, manifest, _, document = self.fixture()
                if mode == 'tamper': (site / 'html/index.html').write_text('changed HTML')
                elif mode == 'missing': (site / 'html/index.html').unlink()
                else: (site / 'html/extra.js').write_text('new untested resource')
                with self.assertRaisesRegex(ValueError, 'exact reader input inventory'):
                    verify_agent_reading(site, manifest, document)

    def test_missing_or_old_reader_receipt_and_manifest_binding_fail(self):
        for mode in ('missing', 'old', 'missing-inventory', 'missing-summary', 'receipt-tamper'):
            with self.subTest(mode=mode):
                site, manifest, receipt, document = self.fixture()
                if mode == 'missing': (site / 'agent-reading-check.json').unlink()
                elif mode == 'old': receipt['schemaVersion'] = 'yjson.agent-reading-check/2'; self.write(site, manifest, receipt)
                elif mode == 'missing-inventory': del receipt['packFiles']; self.write(site, manifest, receipt)
                elif mode == 'missing-summary': del manifest['agentReading']
                else:
                    path = site / 'agent-reading-check.json'; path.write_text(path.read_text() + '\n')
                with self.assertRaises((ValueError, OSError)):
                    verify_agent_reading(site, manifest, document)

    def test_failed_exit_exception_incomplete_and_resource_mismatch_fail(self):
        for mode in ('exit', 'exception', 'running', 'page-list', 'heap', 'stack', 'binary', 'snapshot'):
            with self.subTest(mode=mode):
                site, manifest, receipt, document = self.fixture()
                if mode == 'exit': receipt['checks'][1]['exitCode'] = -11
                elif mode == 'exception': receipt['checks'][1]['stderr'] = 'An exception has occurred:\nOut of memory'
                elif mode == 'running': receipt['status'] = 'running'
                elif mode == 'page-list': receipt['sourceGuidePages'].pop()
                elif mode == 'heap': receipt['resources']['cjHeapSize'] = '256MB'
                elif mode == 'stack': receipt['resources']['stackSoftBytes'] = 8388608
                elif mode == 'binary': receipt['binarySha256After'] = 'b' * 64
                else: receipt['snapshotSha256'] = 'c' * 64
                self.write(site, manifest, receipt)
                with self.assertRaises(ValueError):
                    verify_agent_reading(site, manifest, document)

    def test_query_missing_truncated_wrong_page_or_scope_cannot_be_reported_as_pass(self):
        for mode in ('missing', 'truncated', 'wrong-page', 'wrong-request', 'wrong-snapshot', 'incomplete'):
            with self.subTest(mode=mode):
                site, manifest, receipt, document = self.fixture()
                check = receipt['checks'][2]; response = json.loads(check['stdout'])
                if mode == 'missing': receipt['checks'].pop(2)
                elif mode == 'truncated': response['result']['items'][0]['sections'][0]['value']['text'] = '# 中文源码'
                elif mode == 'wrong-page': response['result']['items'][0]['identity']['pageId'] = 'other'
                elif mode == 'wrong-request': response['scope']['requested']['pageId'] = 'other'
                elif mode == 'wrong-snapshot': response['scope']['snapshots'][0]['snapshotId'] = 'other-snapshot'
                else: response['completeness']['content']['complete'] = False
                check['stdout'] = json.dumps(response, ensure_ascii=False); self.write(site, manifest, receipt)
                with self.assertRaises(ValueError):
                    verify_agent_reading(site, manifest, document)

    def test_mcp_missing_duplicate_wrong_request_and_truncated_content_fail(self):
        for mode in ('missing-response', 'duplicate-response', 'wrong-page', 'missing-request', 'truncated'):
            with self.subTest(mode=mode):
                site, manifest, receipt, document = self.fixture(); check = receipt['checks'][-1]
                replies = [json.loads(line) for line in check['stdout'].splitlines()]
                if mode == 'missing-response': replies.pop()
                elif mode == 'duplicate-response': replies.append(deepcopy(replies[-1]))
                elif mode == 'missing-request': check['stdin'] = '\n'.join(check['stdin'].splitlines()[:-1])
                elif mode == 'wrong-page': replies[-1]['result']['structuredContent']['result']['items'][0]['identity']['pageId'] = 'other'
                else: replies[-1]['result']['structuredContent']['result']['items'][0]['sections'][0]['value']['text'] = '短'
                check['stdout'] = ''.join(json.dumps(reply, ensure_ascii=False) + '\n' for reply in replies)
                self.write(site, manifest, receipt)
                with self.assertRaises(ValueError):
                    verify_agent_reading(site, manifest, document)

    def test_utf8_bytes_are_checked_instead_of_character_count(self):
        site, manifest, receipt, document = self.fixture()
        manifest['sourceGuide']['pages'][1]['bytes'] = len(document['pages'][1]['text'])
        with self.assertRaisesRegex(ValueError, 'UTF-8 length'):
            verify_agent_reading(site, manifest, document)

    def test_native_source_guide_page_cannot_be_omitted_from_reading_inventory(self):
        site, manifest, _, document = self.fixture()
        document['pages'].append({'id': 'api-source-unread', 'source': 'docs/api-source-unread.md', 'text': '未读取的声明来源'})
        with self.assertRaisesRegex(ValueError, 'every native source guide page'):
            verify_agent_reading(site, manifest, document)

    def test_main_refuses_to_archive_when_reader_receipt_is_missing(self):
        site, manifest, _, document = self.fixture(); (site / 'agent-reading-check.json').unlink()
        contract = site / 'contract.json'; contract.write_text('{}')
        source = {'sha256': 'source', 'files': {'release/api-documentation-required.json': hashlib.sha256(contract.read_bytes()).hexdigest()}}
        manifest.update(qualificationStatus='qualified', source=source, standardQuality={},
                        docIrSha256=hashlib.sha256((site / 'docs.json').read_bytes()).hexdigest())
        (site / 'api-docs.json').write_text(json.dumps(manifest)); (site / 'standard-quality-evidence.json').write_text('{}')
        with patch('sys.argv', ['check_api_documentation.py', str(site), '--contract', str(contract)]), patch(
                'generate_api_docs.source_identity', return_value=source), patch(
                'generate_api_docs.verify_standard_quality', return_value={}), patch(
                'check_api_documentation.write_offline_archive') as archive, patch(
                'subprocess.run', side_effect=AssertionError('no reader execution')):
            self.assertEqual(main(), 1)
            archive.assert_not_called()


if __name__ == '__main__':
    unittest.main()
