#!/usr/bin/env python3
"""Independent examples for the executable-documentation trust boundary."""
import subprocess
import unittest
import pathlib
import tempfile
import json
import os
import hashlib
import tomllib
from unittest.mock import patch

from run_api_doc_examples import check_run_result, consumer_source, consumer_manifest, extract_example, build_and_run, run_examples, set_consumer_stack, sanitize


class DocExampleTest(unittest.TestCase):
    def tag(self, directives='{run}', code='println(7)', output='7'):
        return {'directives': directives, 'description': f'```cangjie\n{code}\n```\n```output\n{output}\n```'}

    def test_windows_path_spellings_are_sanitized_longest_first(self):
        home = pathlib.PureWindowsPath('C:/Users/alice')
        paths = {str(home / 'task'): '<task>', str(home / 'task/source'): '<src>'}
        diagnostic = ('C:\\Users\\alice\\task\\source\\api.cj:2: error: invalid call\n'
                      'C:/Users/alice/task/source/api.cj:3: same error\n'
                      'C:/Users/alice/task/build.log C:\\Users\\alice\\other.txt C:/Users/alice/free.txt')
        with patch('run_api_doc_examples.pathlib.Path.home', return_value=home):
            self.assertEqual(sanitize(diagnostic, paths),
                '<src>\\api.cj:2: error: invalid call\n<src>/api.cj:3: same error\n'
                '<task>/build.log $HOME\\other.txt $HOME/free.txt')

    def test_language_items_and_multiple_code_blocks_preserve_same_body(self):
        tag = self.tag(); tag['description'] = '```cangjie linenos\nlet x = 7\n```\n```cj\nprintln(x)\n```\n```output\n7\n```'
        self.assertEqual(extract_example(tag)['code'], 'let x = 7\nprintln(x)')

    def test_markdown_longer_closing_fence_and_trailing_blank_output_are_preserved(self):
        tag = {'directives': '{run}', 'description': '```cangjie\nprintln(7)\nprintln("")\n````\n```output\n7\n\n````'}
        example = extract_example(tag)
        self.assertEqual(example['expected'], '7\n')
        self.assertTrue(check_run_result(subprocess.CompletedProcess([], 0, 'M_BEGIN\n7\n\nM_END\n', ''), example, 'M')[0])

    def test_profile_title_cannot_execute_a_command(self):
        tag = self.tag(); tag['subject'] = 'profile: shell; rm anything'
        self.assertEqual(extract_example(tag)['code'], 'println(7)')

    def test_unsafe_unknown_duplicate_or_conflicting_directives_are_rejected(self):
        for directives in ('{}', '{flags="-O2"}', '{run shell="command"}', '{run run}', '{run must-fail}', '{run error="bad"}', '{run flags="--output x"}'):
            with self.subTest(directives=directives), self.assertRaises(ValueError):
                extract_example(self.tag(directives))

    def test_expected_output_is_required_for_a_running_example(self):
        with self.assertRaisesRegex(ValueError, 'output fence'):
            extract_example({'directives': '{run}', 'description': '```cangjie\nprintln(7)\n```'})

    def test_wrong_stdout_and_zero_exit_unhandled_exception_fail(self):
        example = extract_example(self.tag())
        for output in ('M_BEGIN\n8\nM_END\n', 'M_BEGIN\n7\nM_END\nAn exception has occurred:\nerror'):
            result = subprocess.CompletedProcess([], 0, output, '')
            self.assertFalse(check_run_result(result, example, 'M')[0])

    def test_real_exit_code_and_output_are_both_required(self):
        example = extract_example(self.tag())
        self.assertTrue(check_run_result(subprocess.CompletedProcess([], 0, 'build\nM_BEGIN\n7\nM_END\n', ''), example, 'M')[0])
        self.assertFalse(check_run_result(subprocess.CompletedProcess([], 1, 'M_BEGIN\n7\nM_END\n', ''), example, 'M')[0])

    def test_complete_consumer_exports_real_imports_and_prelude(self):
        source = consumer_source({'imports': ['yjson.*']}, 'class Point {}', 'println(Point())', 'M')
        self.assertIn('import yjson.*', source)
        self.assertIn('class Point {}', source)
        self.assertIn('main(): Unit', source)

    def test_example_cannot_replace_manifest_import_or_main_entry(self):
        for code in ('package bypass', 'import other.*', 'main() {}'):
            with self.assertRaises(ValueError):
                consumer_source({'imports': ['yjson.*']}, '', code, 'M')

    def test_portable_manifest_preserves_native_dependencies_flags_and_explicit_override(self):
        profile = {'dependencies': ['yjson', 'yjson_schema_formats'], 'compileOption': '-O2',
                   'linkNativeScanner': True, 'nativeLibraries': ['yjson_schema_formats', 'idn2']}
        example = extract_example(self.tag('{run flags="--int-overflow wrapping"}'))
        with patch.dict(os.environ, {'YJSON_CI_DEPENDENCY_OVERRIDE': '-O0'}):
            text = consumer_manifest(profile, example, override_compile_option='-O1')
        document = tomllib.loads(text)
        self.assertEqual(document['package'], {'name': 'yjson_doc_example', 'version': '0.0.0',
            'cjc-version': '1.2.0', 'output-type': 'executable', 'compile-option': '-O2 --int-overflow wrapping',
            'override-compile-option': '-O1', 'link-option': '-L <project>/target/native -lyjson_scanner -lyjson_schema_formats -lidn2'})
        self.assertEqual(document['dependencies'], {'yjson': {'path': '<modules>/yjson'},
                                                    'yjson_schema_formats': {'path': '<modules>/yjson_schema_formats'}})

    def test_portable_manifest_rejects_unresolved_or_unsafe_override(self):
        for option in (None, '', '-O3', '-O2 --output elsewhere'):
            with self.subTest(option=option), self.assertRaisesRegex(ValueError, 'override'):
                consumer_manifest({'dependencies': ['yjson']}, extract_example(self.tag()), override_compile_option=option)

    def test_runner_retains_profile_then_environment_then_default_override_precedence(self):
        for configured, environment, expected in (('-O2', '-O1', '-O2'), (None, '-O1', '-O1'), (None, '', '-O2')):
            with self.subTest(configured=configured, environment=environment), tempfile.TemporaryDirectory() as directory:
                base = pathlib.Path(directory); root = base / 'root'; site = base / 'site'; site.mkdir(); root.mkdir()
                profile = {'schemaVersion': 1, 'dependencies': ['yjson'], 'imports': ['yjson.*'],
                           'platforms': ['linux'], 'compileOption': '-O2'}
                if configured is not None: profile['overrideCompileOption'] = configured
                files = {'release/release-graph.toml': (pathlib.Path(__file__).resolve().parents[1] / 'release/release-graph.toml').read_bytes(),
                         'tests/doc_examples/core/profile.json': json.dumps(profile).encode()}
                for relative, body in files.items():
                    path = root / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(body)
                identity = {'sha256': 'fixture-source', 'files': {name: hashlib.sha256(body).hexdigest() for name, body in files.items()}}
                declaration = {'id': 'entry', 'ownerId': None, 'visibility': 'public', 'kind': 'function',
                    'qualifiedName': 'yjson.example', 'headerSpelling': 'public func example(): Unit',
                    'documentation': {'tags': [{'name': 'example', **self.tag()}]}}
                key = 'yjson.example|function|public func example(): Unit'
                (site / 'docs.json').write_text(json.dumps({'declarations': [declaration]}))
                (site / 'api-docs.json').write_text(json.dumps({'qualificationStatus': 'development-only', 'source': identity}))
                contract = base / 'contract.json'; contract.write_text(json.dumps({'declarations': {key: {'category': 'application', 'profile': 'core'}}}))
                def build(project, example):
                    actual = tomllib.loads((project / 'cjpm.toml').read_text())
                    self.assertEqual(actual['package']['override-compile-option'], expected)
                    binary = project / 'target/release/bin/main'; binary.parent.mkdir(parents=True); binary.write_bytes(b'unit-test executable')
                    library = project / 'target/release/yjson/libyjson.a'; library.parent.mkdir(); library.write_bytes(b'unit-test library')
                    marker = 'YJSON_DOC_' + hashlib.sha256((key + ':0').encode()).hexdigest()[:24]
                    return (subprocess.CompletedProcess([], 0, '', ''),
                            subprocess.CompletedProcess([str(binary)], 0, marker + '_BEGIN\n7\n' + marker + '_END\n', ''))
                sdk = {'version': '1.2.0', 'cjcVersion': 'compiler', 'cjpmVersion': 'manager', 'binarySha256': {'cjc': 'fixture'}}
                with patch.dict(os.environ, {'YJSON_CI_DEPENDENCY_OVERRIDE': environment}), patch(
                        'run_api_doc_examples.source_identity', return_value=identity), patch(
                        'run_api_doc_examples.sdk_identity', return_value=sdk), patch(
                        'run_api_doc_examples.set_consumer_stack', return_value={}), patch(
                        'run_api_doc_examples.sys.platform', 'linux'), patch(
                        'run_api_doc_examples.build_and_run', side_effect=build), patch(
                        'run_api_doc_examples.consumer_manifest', wraps=consumer_manifest) as renderer:
                    report = run_examples(site, root=root, contract_path=contract)
                self.assertEqual(renderer.call_args.kwargs['override_compile_option'], expected)
                self.assertEqual(report['examples'][0]['overrideCompileOption'], expected)
                self.assertEqual(report['failures'], 0)
                exported = (site / report['examples'][0]['manifest']).read_bytes()
                self.assertNotIn(b'\r\n', exported)

    def test_windows_executable_and_dll_discovery_uses_real_output_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            project = pathlib.Path(directory)
            binary = project / 'target/release/bin/main.exe'; binary.parent.mkdir(parents=True); binary.write_bytes(b'executable')
            library = project / 'target/release/dependency/runtime.dll'; library.parent.mkdir(); library.write_bytes(b'library')
            build = subprocess.CompletedProcess([], 0, '', '')
            result = subprocess.CompletedProcess([], 0, 'run output', '')
            with patch('run_api_doc_examples.sys.platform', 'win32'), patch(
                'run_api_doc_examples.subprocess.run', side_effect=[build, result]) as invoked:
                self.assertEqual(build_and_run(project, {'mode': 'run'}), (build, result))
                self.assertEqual(invoked.call_args_list[1].args[0], [str(binary)])
                self.assertIn(str(library.parent), invoked.call_args_list[1].kwargs['env']['PATH'])

    def test_zero_exit_build_exception_does_not_execute_a_stale_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            build = subprocess.CompletedProcess([], 0, 'An exception has occurred:\nerror', '')
            with patch('run_api_doc_examples.subprocess.run', return_value=build) as invoked:
                self.assertEqual(build_and_run(pathlib.Path(directory), {'mode': 'run'}), (build, None))
                self.assertEqual(invoked.call_count, 1)

    @unittest.skipIf(os.name == 'nt', 'POSIX resource boundary')
    def test_darwin_records_its_real_finite_stack_limit(self):
        maximum = 64 * 1024 * 1024
        with patch('run_api_doc_examples.sys.platform', 'darwin'), patch.dict(os.environ, {}, clear=True), patch(
                'resource.getrlimit', side_effect=[(8 * 1024 * 1024, maximum), (maximum, maximum)]), patch(
                'resource.setrlimit') as set_limit:
            report = set_consumer_stack()
            self.assertEqual(set_limit.call_args.args[1], (maximum, maximum))
            self.assertEqual(report['softBytes'], maximum)
            self.assertEqual(report['runtimeThreadStack'], '8MB')

    @unittest.skipIf(os.name == 'nt', 'POSIX resource boundary')
    def test_linux_does_not_claim_a_stack_limit_above_the_actual_hard_limit(self):
        with patch('run_api_doc_examples.sys.platform', 'linux'), patch(
                'resource.getrlimit', return_value=(8 * 1024 * 1024, 64 * 1024 * 1024)):
            with self.assertRaisesRegex(ValueError, '131072 KiB'):
                set_consumer_stack()

    def test_unknown_profile_cannot_pass_by_running_zero_examples(self):
        with tempfile.TemporaryDirectory() as directory:
            site = pathlib.Path(directory)
            (site / 'docs.json').write_text('{}')
            (site / 'api-docs.json').write_text('{}')
            contract = site / 'contract.json'
            contract.write_text(json.dumps({'declarations': {'key': {'category': 'application', 'profile': 'core'}}}))
            with self.assertRaisesRegex(ValueError, 'absent from'):
                run_examples(site, contract_path=contract, only_profiles={'typo'})

    def test_downloaded_doc_ir_or_contract_drift_is_rejected_before_compilation(self):
        for mode in ('doc-ir', 'contract'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                site = pathlib.Path(directory)
                (site / 'docs.json').write_text('{}')
                frozen = site / 'consumer-sources/release'; frozen.mkdir(parents=True)
                (frozen / 'api-documentation-required.json').write_text('{"declarations": {}}')
                manifest = {'qualificationStatus': 'qualified', 'consumerSources': 'consumer-sources',
                            'source': {'files': {'release/api-documentation-required.json': 'original-contract'}}}
                if mode == 'doc-ir': manifest['docIrSha256'] = 'original-document'
                (site / 'api-docs.json').write_text(json.dumps(manifest))
                with patch('run_api_doc_examples.sdk_identity') as installed, self.assertRaisesRegex(
                        ValueError, 'differs from'):
                    run_examples(site)
                installed.assert_not_called()


if __name__ == '__main__':
    unittest.main()
