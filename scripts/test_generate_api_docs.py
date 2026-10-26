#!/usr/bin/env python3
"""Negative release-boundary tests for the unified Doc IR contract."""
from copy import deepcopy
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

from generate_api_docs import (ApiDocsError, ROOT, create_workspace, validate_doc_ir,
                               freeze_sources, verify_frozen_sources, sha256_file,
                               source_identity, source_revisions, validate_agent_result)
from generate_api_docs import bind_standard_quality, verify_standard_quality, validate_agent_page
from generate_api_docs import validate_agent_reading, html_pack_files, file_inventory_digest
from release_temp_tree import manifest_paths, release_identity, write_provenance
import subprocess
from types import SimpleNamespace
from generate_api_docs import validate_module_dependencies


class ApiDocsValidationTest(unittest.TestCase):
    def document(self):
        packages = ('yjson', 'yjson_algorithms', 'yjson_macros')
        declarations = [{'packageName': p, 'name': n, 'visibility': 'public', 'kind': k}
                        for p, n, k in [('yjson', 'JsonKind', 'enum'),
                                        ('yjson_algorithms', 'JsonPatchOperationKind', 'enum')]]
        declarations += [{'packageName': 'yjson_macros', 'name': n, 'visibility': 'public', 'kind': 'macro'}
                         for n in ('Json', 'JsonCodec', 'JsonSubtype', 'JsonUsing')]
        return {'schemaVersion': 'cjdoc.doc-ir/16', 'generator': {'name': 'cjdoc', 'version': '0.7.5'},
                'configuration': {'audience': 'external'}, 'packages': [{'name': p} for p in packages],
                'declarations': declarations, 'diagnostics': [], 'unsupportedDeclarations': [],
                'macroInvocations': [{'name': 'Derive'}, {'name': 'Derive'}]}

    def validate(self, document):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'docs.json'
            path.write_text(json.dumps(document))
            return validate_doc_ir(path, package_names=('yjson', 'yjson_algorithms', 'yjson_macros'),
                                   generator_version='0.7.5', expected_macros=('Json', 'JsonCodec', 'JsonSubtype', 'JsonUsing'))

    def test_accepts_current_macro_declarations_and_honest_unexpanded_metadata(self):
        report = self.validate(self.document())
        self.assertEqual(report['unexpandedMacroInvocations'], 2)
        self.assertEqual(report['unsupported'], [])

    def test_old_ir_is_rejected(self):
        document = self.document(); document['schemaVersion'] = 'cjdoc.doc-ir/8'
        with self.assertRaisesRegex(ApiDocsError, 'v16'):
            self.validate(document)

    def test_missing_extra_duplicate_packages_are_rejected(self):
        for replacement in ([{'name': 'yjson'}], self.document()['packages'] * 2,
                            self.document()['packages'] + [{'name': 'extra'}]):
            document = self.document(); document['packages'] = replacement
            with self.subTest(replacement=replacement), self.assertRaisesRegex(ApiDocsError, 'exactly'):
                self.validate(document)

    def test_unknown_unsupported_cannot_be_allowlisted(self):
        document = self.document(); document['unsupportedDeclarations'] = [{'kind': 'macroInvocation', 'name': 'Unknown'}]
        with self.assertRaisesRegex(ApiDocsError, 'unsupported declarations'):
            self.validate(document)

    def test_deleted_or_old_macro_exports_are_rejected(self):
        document = self.document(); document['declarations'].append(
            {'packageName': 'yjson_macros', 'name': 'JsonValue', 'visibility': 'public', 'kind': 'macro'})
        with self.assertRaisesRegex(ApiDocsError, 'four-macro'):
            self.validate(document)

    def test_macro_wrapper_cannot_hide_source_enum(self):
        document = self.document(); document['declarations'] = document['declarations'][1:]
        with self.assertRaisesRegex(ApiDocsError, 'source declaration is missing'):
            self.validate(document)

    def test_error_diagnostic_is_fatal(self):
        document = self.document(); document['diagnostics'] = [{'severity': 'error', 'code': 'CJDOC9999'}]
        with self.assertRaisesRegex(ApiDocsError, 'reported errors'):
            self.validate(document)

    def test_generator_identity_must_match_qualification(self):
        document = self.document(); document['generator']['version'] = 'wrong'
        with self.assertRaisesRegex(ApiDocsError, 'identity'):
            self.validate(document)

    def test_multi_repository_workspace_cannot_publish_one_machine_repository(self):
        document = self.document()
        document['project'] = {'repository': {'url': 'https://github.com/example/main', 'revision': '1' * 40}}
        with self.assertRaisesRegex(ApiDocsError, 'machine repository URL unavailable'):
            self.validate(document)

    def test_real_downloadable_source_closure_keeps_licenses(self):
        with patch('generate_api_docs.source_revisions', return_value={'revision': '1' * 40, 'macroRevision': '2' * 40}):
            identity = source_identity()
        licenses = ('LICENSE', 'native/vendor/yyjson/LICENSE', 'packages/yjson_macros/LICENSE')
        with tempfile.TemporaryDirectory() as directory:
            destination = pathlib.Path(directory) / 'sources'
            freeze_sources(ROOT, destination, identity)
            for relative in licenses:
                self.assertEqual(identity['files'][relative], sha256_file(destination / relative))

    def test_frozen_source_rejects_linked_ancestor_even_when_bytes_match(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory); source = base / 'sources'; source.mkdir()
            external = base / 'external'; external.mkdir(); (external / 'input.cj').write_text('package example\n')
            (source / 'src').symlink_to(external, target_is_directory=True)
            identity = {'files': {'src/input.cj': sha256_file(external / 'input.cj')}}
            with self.assertRaisesRegex(ApiDocsError, 'linked ancestors'):
                verify_frozen_sources(source, identity)
            with self.assertRaisesRegex(ApiDocsError, 'linked ancestors'):
                freeze_sources(source, base / 'copy', identity)

    def candidate(self, base):
        root = base / 'candidate'; (root / 'release').mkdir(parents=True)
        macro = '{ git = "https://github.com/lIlIIlIll/yjson_macros.git", commitId = "' + '3' * 40 + '" }'
        (root / 'cjpm.toml').write_text('[test-dependencies]\nyjson_macros = ' + macro + '\n')
        (root / 'cjpm.lock').write_text('[requires]\nyjson_macros = ' + macro + '\n')
        (root / 'release/release-files.txt').write_text('release/release-files.txt\ncjpm.toml\ncjpm.lock\n')
        identity = release_identity(root, manifest_paths(root / 'release/release-files.txt'), False)
        identity.update(clean_enforced=True, commit='1' * 40, tree='2' * 40)
        write_provenance(root, identity)
        return root

    def test_source_only_candidate_uses_verified_provenance_and_macro_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            revisions = source_revisions(self.candidate(pathlib.Path(directory)))
            self.assertEqual(revisions['revision'], '1' * 40)
            self.assertEqual(revisions['macroRevision'], '3' * 40)
            self.assertEqual(revisions['tree'], '2' * 40)

    def test_source_only_candidate_missing_dirty_or_tampered_receipt_fails(self):
        for mode in ('missing', 'dirty', 'tampered'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = self.candidate(pathlib.Path(directory)); receipt = root / 'release/candidate-provenance.json'
                if mode == 'missing': receipt.unlink()
                elif mode == 'dirty':
                    data = json.loads(receipt.read_text()); data['clean_enforced'] = False; receipt.write_text(json.dumps(data))
                else: (root / 'cjpm.toml').write_text((root / 'cjpm.toml').read_text() + '# changed\n')
                with self.assertRaisesRegex(ApiDocsError, 'unverified source-only candidate'):
                    source_revisions(root)

    def test_source_only_candidate_macro_manifest_lock_mismatch_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.candidate(pathlib.Path(directory))
            (root / 'cjpm.lock').write_text((root / 'cjpm.lock').read_text().replace('3' * 40, '4' * 40))
            with self.assertRaisesRegex(ApiDocsError, 'immutable macro Git pin'):
                source_revisions(root)

    def test_agent_crash_and_empty_matches_cannot_be_counted_as_pass(self):
        with self.assertRaisesRegex(ApiDocsError, 'exit -11'):
            validate_agent_result(subprocess.CompletedProcess([], -11, '', 'SIGSEGV'))
        with self.assertRaisesRegex(ApiDocsError, 'matches'):
            validate_agent_result(subprocess.CompletedProcess([], 0, json.dumps({
                'schemaVersion': 'cjdoc.query-result/1', 'status': 'ok', 'result': {'items': []}}), ''))

    def test_each_source_guide_must_return_its_entire_original_description(self):
        text = '完整签名与源码链接：https://github.com/example/library/blob/' + '1' * 40 + '/src/api.cj#L2'
        response = {'result': {'items': [{'identity': {'pageId': 'source'},
                     'sections': [{'name': 'description', 'value': {'text': text}}]}]}}
        validate_agent_page(response, 'source', text)
        for wrong in (text[:20], ''):
            response['result']['items'][0]['sections'][0]['value']['text'] = wrong
            with self.assertRaisesRegex(ApiDocsError, 'truncated'):
                validate_agent_page(response, 'source', text)
        with self.assertRaisesRegex(ApiDocsError, 'requested source guide'):
            validate_agent_page(response, 'different-page', text)

    def test_reader_records_exact_inventory_before_execution_and_rejects_changed_pack(self):
        for changed in (False, True):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                site = pathlib.Path(directory) / 'site'; (site / 'html/agent').mkdir(parents=True)
                binary = pathlib.Path(directory) / 'cjdoc'; binary.write_bytes(b'reader binary')
                (site / 'html/agent/manifest.json').write_text('{"snapshotId":"snapshot"}')
                (site / 'html/index.html').write_text('original HTML')
                original = html_pack_files(site)
                response = {'schemaVersion': 'cjdoc.query-result/1', 'status': 'ok', 'result': {'items': [{
                    'identity': {'pageId': 'api-source-index'}, 'sections': [{'name': 'description',
                    'value': {'text': '完整源码'}}]}]}}
                def execute(argv, **kwargs):
                    recorded = json.loads((site / 'agent-reading-check.json').read_text())
                    self.assertEqual(recorded['packFiles'], original)
                    self.assertEqual(recorded['packFilesSha256'], file_inventory_digest(original))
                    self.assertEqual(recorded['status'], 'running')
                    self.assertEqual(kwargs['env']['cjHeapSize'], '2GB')
                    if argv[1] == 'mcp':
                        output = '\n'.join(json.dumps({'id': identifier, 'result': {
                            'isError': False, 'structuredContent': response}}) for identifier in (2, 3))
                        if changed: (site / 'html/index.html').write_text('changed during reading')
                    else: output = json.dumps(response)
                    return subprocess.CompletedProcess(argv, 0, output, '')
                with patch('generate_api_docs.documentation_stack', return_value={
                        'stackSoftBytes': 134217728, 'stackHardBytes': -1}), patch(
                        'generate_api_docs.subprocess.run', side_effect=execute):
                    if changed:
                        with self.assertRaisesRegex(ApiDocsError, 'changed its binary or complete pack'):
                            validate_agent_reading(binary, site, {}, [{'source': 'docs/api-source-index.md', 'markdown': '完整源码'}])
                    else:
                        summary = validate_agent_reading(binary, site, {}, [{'source': 'docs/api-source-index.md', 'markdown': '完整源码'}])
                        self.assertEqual(summary['receiptSha256'], sha256_file(site / 'agent-reading-check.json'))
                recorded = json.loads((site / 'agent-reading-check.json').read_text())
                self.assertEqual(recorded['status'], 'failed' if changed else 'passed')
                self.assertEqual(recorded['binarySha256After'], sha256_file(binary))
                self.assertEqual(recorded['packFilesAfterSha256'], file_inventory_digest(html_pack_files(site)))
                self.assertEqual(len(recorded['checks']), 3)

    def test_reader_inventory_refuses_linked_resources_and_empty_html(self):
        with tempfile.TemporaryDirectory() as directory:
            site = pathlib.Path(directory); (site / 'html').mkdir()
            with self.assertRaisesRegex(ApiDocsError, 'empty'):
                html_pack_files(site)
            external = site / 'outside'; external.write_text('untracked')
            (site / 'html/linked').symlink_to(external)
            with self.assertRaisesRegex(ApiDocsError, 'linked'):
                html_pack_files(site)

    def test_workspace_membership_does_not_substitute_for_dependency_edges(self):
        graph = SimpleNamespace(names=('core', 'consumer'), packages=(
            SimpleNamespace(name='core', dependencies=()), SimpleNamespace(name='consumer', dependencies=('core',))))
        document = {'modules': [{'id': 'core', 'name': 'core', 'dependencyIds': []},
                                {'id': 'consumer', 'name': 'consumer', 'dependencyIds': []}]}
        with self.assertRaisesRegex(ApiDocsError, 'dependency edges'):
            validate_module_dependencies(document, graph)
        document['modules'][1]['dependencyIds'] = ['core']
        validate_module_dependencies(document, graph)


class StandardQualityEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.site = pathlib.Path(self.temporary.name) / 'site'; self.site.mkdir()
        (self.site / 'quality-inputs').mkdir()
        (self.site / 'quality-inputs/standard-cjdoc.toml').write_text('[docs]\nindex="README.md"\n')
        (self.site / 'quality-inputs/full-cjdoc.toml').write_text('[docs]\nindex="README.md"\n[lint]\nseverity="off"\n')
        self.standard = self.site / 'quality-standard'; (self.standard / 'coverage').mkdir(parents=True)
        declaration = {'id': 'api', 'qualifiedName': 'pkg.read', 'kind': 'function', 'visibility': 'public',
                       'ownerId': None, 'headerSpelling': 'public func read(value: Int64): Int64',
                       'source': {'path': 'src/api.cj', 'start': {'line': 2}},
                       'parameters': [{'name': 'value'}],
                       'documentation': {'summary': '读取数值。', 'tags': [{'name': 'param', 'description': '值。'}]}}
        self.document = {'configuration': {'lintProfile': 'standard'}, 'declarations': [declaration],
                         'diagnostics': [{'code': 'CJDOC3036'}]}
        self.quality = {'schemaVersion': 'cjdoc.documentation-quality/1', 'audience': 'external',
                        'assessment': 'conservative-placeholder-heuristic', 'findings': [],
                        'symbols': {'total': 1, 'meaningful': 1, 'percent': 100},
                        'parameters': {'total': 1, 'meaningful': 1, 'percent': 100}}
        self.write()

    def write(self):
        (self.standard / 'docs.json').write_text(json.dumps(self.document))
        (self.standard / 'coverage/quality.json').write_text(json.dumps(self.quality))
        full = deepcopy(self.document)
        (self.site / 'docs.json').write_text(json.dumps(full))

    def test_two_untouched_producer_outputs_bind_to_the_same_source_and_all_declarations(self):
        evidence = bind_standard_quality(self.standard, self.site, 'source')
        self.assertEqual(evidence['declarations'], 1)
        self.assertEqual(evidence['standardDiagnostics'], {'CJDOC3036': 1})
        self.assertEqual(verify_standard_quality(self.site, 'source', evidence), self.quality)

    def test_missing_changed_or_different_source_quality_evidence_is_rejected(self):
        evidence = bind_standard_quality(self.standard, self.site, 'source')
        with self.assertRaisesRegex(ApiDocsError, 'different inputs'):
            verify_standard_quality(self.site, 'other-source', evidence)
        self.quality['findings'].append({'symbolId': 'api', 'code': 'CJDOC3048'})
        (self.standard / 'coverage/quality.json').write_text(json.dumps(self.quality))
        with self.assertRaisesRegex(ApiDocsError, 'different inputs'):
            verify_standard_quality(self.site, 'source', evidence)
        (self.standard / 'coverage/quality.json').unlink()
        with self.assertRaises(OSError):
            verify_standard_quality(self.site, 'source', evidence)

    def test_every_quality_relevant_declaration_field_must_match(self):
        for field, value in (('id', 'other'), ('headerSpelling', 'public func changed(): Unit'),
                             ('parameters', []), ('source', {'path': 'src/other.cj'}),
                             ('documentation', {'summary': '不同契约。'})):
            with self.subTest(field=field):
                full = deepcopy(self.document)
                full['declarations'][0][field] = value
                (self.site / 'docs.json').write_text(json.dumps(full))
                with self.assertRaisesRegex(ApiDocsError, 'declarations differ'):
                    bind_standard_quality(self.standard, self.site, 'source')

    def test_optional_signature_coloring_is_not_api_or_documentation_content(self):
        full = deepcopy(self.document)
        full['declarations'][0]['signatureHighlight'] = {'state': 'highlighted', 'spans': [{'start': 0, 'end': 6}]}
        (self.site / 'docs.json').write_text(json.dumps(full))
        self.assertEqual(bind_standard_quality(self.standard, self.site, 'source')['declarations'], 1)

    def test_native_quality_parameter_denominator_preserves_underscore_rule(self):
        self.document['declarations'][0]['parameters'].append({'name': '_ignored'})
        self.write()
        self.assertEqual(bind_standard_quality(self.standard, self.site, 'source')['qualityCounts']['parameters']['total'], 1)

    def test_off_display_report_and_inconsistent_native_counts_cannot_pass(self):
        self.document['configuration']['lintProfile'] = 'off'; self.write()
        with self.assertRaisesRegex(ApiDocsError, 'standard lint producers'):
            bind_standard_quality(self.standard, self.site, 'source')
        self.document['configuration']['lintProfile'] = 'standard'
        self.quality['symbols']['total'] = 0; self.write()
        with self.assertRaisesRegex(ApiDocsError, 'counts are inconsistent'):
            bind_standard_quality(self.standard, self.site, 'source')


if __name__ == '__main__':
    unittest.main()
