#!/usr/bin/env python3
"""Negative release-boundary tests for the unified Doc IR contract."""
from copy import deepcopy
import json
import pathlib
import shutil
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
from generate_api_docs import validate_homepage


class HomepageRenderingTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.site = pathlib.Path(self.temporary.name)
        (self.site / 'html').mkdir()

    def write_home(self, article, *, heading='<h1>yjson</h1>', extra=''):
        (self.site / 'html/index.html').write_text(
            extra + '<main>' + heading + '<article>' + article + '</article></main>', encoding='utf-8')

    def test_native_prose_and_documented_code_are_readable(self):
        self.write_home('<p><strong>面向仓颉的类型安全 JSON 库</strong></p>'
                        '<p>默认使用纯仓颉实现。</p>'
                        '<pre><code data-language="cangjie">let value = 7</code></pre>'
                        '<pre><code>expected output</code></pre>')
        validate_homepage(self.site)

    def test_escaped_readme_presentation_cannot_pass_as_code(self):
        for raw in ('&lt;!-- BEAUTIFIED --&gt;', '&lt;h1 align="center"&gt;yjson&lt;/h1&gt;',
                    '\n&lt;p align="center"&gt;介绍&lt;/p&gt;', '&lt;img src="badge.svg" /&gt;'):
            with self.subTest(raw=raw):
                self.write_home('<p>yjson 是仓颉 JSON 库。</p><pre><code>' + raw + '</code></pre>')
                with self.assertRaisesRegex(ApiDocsError, 'raw HTML presentation'):
                    validate_homepage(self.site)

    def test_intentionally_labelled_html_examples_remain_code(self):
        for attributes in ('data-language="html"', 'class="language-html"'):
            with self.subTest(attributes=attributes):
                self.write_home('<p>HTML 示例。</p><pre><code ' + attributes
                                + '>&lt;p&gt;example&lt;/p&gt;</code></pre>')
                validate_homepage(self.site)

    def test_article_prose_cannot_be_replaced_with_code(self):
        self.write_home('<pre><code data-language="text">介绍</code></pre>')
        with self.assertRaisesRegex(ApiDocsError, 'readable article prose'):
            validate_homepage(self.site)

    def test_home_has_one_project_heading(self):
        for heading in ('', '<h1>other</h1>', '<h1>yjson</h1><h1>yjson</h1>'):
            with self.subTest(heading=heading):
                self.write_home('<p>介绍。</p>', heading=heading)
                with self.assertRaisesRegex(ApiDocsError, 'one yjson heading'):
                    validate_homepage(self.site)

    def test_navigation_and_comments_are_outside_the_article_contract(self):
        self.write_home('<!-- author comment --><p>介绍。</p>',
                        extra='<aside><pre><code>&lt;p&gt;</code></pre><p>导航</p></aside>')
        validate_homepage(self.site)


class RepositoryLinksTest(unittest.TestCase):
    MAIN = 'https://github.com/example/library'
    MACRO = 'https://github.com/example/macros'

    def setUp(self):
        from api_doc_repository_links import repository_link_catalog, rewrite_repository_links, validate_html_file_links, _git_files
        self.make_catalog = repository_link_catalog; self.rewrite = rewrite_repository_links; self.check_html = validate_html_file_links
        self.read_git_files = _git_files
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.sources = ('README.md', 'docs/guide.md', 'docs/peer.md')
        self.repositories = {'.': (self.MAIN, '1' * 40), 'packages/yjson_macros': (self.MACRO, '2' * 40)}
        for name in (*self.sources, 'RELEASE_NOTES.md', 'docs/maintainers/testing.md',
                     'docs/performance/report.md', 'packages/yjson_macros/LICENSE', 'with (space).md'):
            path = self.root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('original bytes\n')
        (self.root / '.git').mkdir()
        self.trees = {'.': {path.relative_to(self.root).as_posix(): ('100644', 'blob', 'a' * 40)
                           for path in self.root.rglob('*') if path.is_file()},
                      'packages/yjson_macros': {'LICENSE': ('100644', 'blob', 'b' * 40)}}
        mocked = patch('api_doc_repository_links._git_files', side_effect=lambda root, revision:
            self.trees['.' if root == self.root else root.relative_to(self.root).as_posix()])
        mocked.start(); self.addCleanup(mocked.stop)
        self.collect = lambda root, sources: {entry.target for entry in self.make_catalog(root, sources, self.repositories)}

    def catalog(self, repositories=None):
        return self.make_catalog(self.root, self.sources, self.repositories if repositories is None else repositories)

    def render(self, text, source='docs/guide.md'):
        (self.root / source).write_text(text, encoding='utf-8')
        return self.rewrite(self.root, source, self.sources, self.catalog())

    def test_repository_targets_use_fixed_main_and_macro_revisions_and_keep_suffixes(self):
        text = ('[release](../RELEASE_NOTES.md?raw=1#升级) '
                '[maintainer](maintainers/testing.md) [performance](performance/report.md) '
                '[macro](../packages/yjson_macros/LICENSE#notice) '
                '[space](<../with%20%28space%29.md#part> "title")\n')
        actual = self.render(text)
        self.assertEqual(actual, ('[release](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md?raw=1#升级) '
            '[maintainer](' + self.MAIN + '/blob/' + '1' * 40 + '/docs/maintainers/testing.md) '
            '[performance](' + self.MAIN + '/blob/' + '1' * 40 + '/docs/performance/report.md) '
            '[macro](' + self.MACRO + '/blob/' + '2' * 40 + '/LICENSE#notice) '
            '[space](<' + self.MAIN + '/blob/' + '1' * 40 + '/with%20%28space%29.md#part> "title")\n'))
        self.assertEqual(self.collect(self.root, self.sources), {'RELEASE_NOTES.md', 'docs/maintainers/testing.md',
            'docs/performance/report.md', 'packages/yjson_macros/LICENSE', 'with (space).md'})

    def test_registered_pages_api_anchors_and_external_urls_remain_byte_identical(self):
        text = ('[peer](peer.md#中文) [root](../README.md) [local](#anchor) '
                '[API](symbol:yjson.YJson.toJson) [API2](api:yjson.YJson) '
                '[web](https://example.test/file?q=1#part) [mail](mailto:docs@example.test)\n')
        self.assertEqual(self.render(text), text)
        self.assertEqual(self.collect(self.root, self.sources), set())

    def test_code_fences_inline_code_and_raw_html_are_untouched(self):
        text = ('`[inline](missing.md)` ``[long](missing.md) ` text``\n'
                '```markdown\n[code](missing.md)\n````\n'
                '~~~\n[tilde](missing.md)\n~~~\n'
                '<a href="missing.md">raw HTML</a>\n'
                '[`release`](../RELEASE_NOTES.md)\n')
        self.assertEqual(self.render(text), text.replace('](../RELEASE_NOTES.md)',
            '](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md)'))
        self.assertEqual(self.collect(self.root, self.sources), {'RELEASE_NOTES.md'})

    def test_reference_destinations_and_balanced_parentheses_share_the_same_resolution(self):
        text = ('[release][notes]\n[notes]: ../RELEASE_NOTES.md?plain=1#section "title"\n'
                '[space](../with%20(space).md)\n')
        actual = self.render(text)
        self.assertIn('[notes]: ' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md?plain=1#section "title"', actual)
        self.assertIn('/with%20%28space%29.md)', actual)
        self.assertEqual(self.collect(self.root, self.sources), {'RELEASE_NOTES.md', 'with (space).md'})

    def test_quoted_list_fences_escaped_links_and_crlf_keep_original_text(self):
        text = ('> ```markdown\r\n> [quoted](missing.md)\r\n> ```\r\n'
                '- ~~~\r\n  [list](missing.md)\r\n  ~~~\r\n'
                '\\[escaped](missing.md)\r\n[release](../RELEASE_NOTES.md)\r\n')
        self.assertEqual(self.render(text), text.replace('](../RELEASE_NOTES.md)',
            '](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md)'))
        self.assertEqual(self.collect(self.root, self.sources), {'RELEASE_NOTES.md'})

    def test_indented_and_pre_code_remains_literal_and_links_after_code_are_resolved(self):
        for newline in ('\n', '\r\n'):
            for literal in ('    [literal](../RELEASE_NOTES.md)', '\t[literal](../RELEASE_NOTES.md)',
                            '<pre class="example">\n[literal](../RELEASE_NOTES.md)\n</pre>',
                            '<PRE>\n[literal](../RELEASE_NOTES.md)\n</PRE>'):
                with self.subTest(newline=repr(newline), literal=literal):
                    text = (literal + '\n\n[after](maintainers/testing.md)\n').replace('\n', newline)
                    expected = text.replace('](maintainers/testing.md)',
                        '](' + self.MAIN + '/blob/' + '1' * 40 + '/docs/maintainers/testing.md)')
                    self.assertEqual(self.render(text), expected)
                    self.assertEqual(self.collect(self.root, self.sources), {'docs/maintainers/testing.md'})

    def test_quote_and_list_indentation_distinguishes_literal_code_from_normal_links(self):
        for newline in ('\n', '\r\n'):
            text = ('- parent\n'
                    '    - [nested](maintainers/testing.md)\n'
                    '    [continuation](performance/report.md)\n\n'
                    '  [loose](maintainers/testing.md)\n\n'
                    '      [literal-list](../RELEASE_NOTES.md)\n\n'
                    '  [after-list-code](performance/report.md)\n\n'
                    '>     [literal-quote](../RELEASE_NOTES.md)\n>\n'
                    '> [quote](maintainers/testing.md)\n>\n'
                    '> - item\n>\n'
                    '>       [literal-quote-list](../RELEASE_NOTES.md)\n>\n'
                    '>   [quote-list](performance/report.md)\n\n'
                    '[after](maintainers/testing.md)\n').replace('\n', newline)
            expected = text
            for target in ('maintainers/testing.md', 'performance/report.md'):
                expected = expected.replace('](' + target + ')', '](' + self.MAIN + '/blob/' + '1' * 40 + '/docs/' + target + ')')
            with self.subTest(newline=repr(newline)):
                self.assertEqual(self.render(text), expected)
                self.assertEqual(self.collect(self.root, self.sources), {'docs/maintainers/testing.md', 'docs/performance/report.md'})

    def test_code_paths_need_not_exist_and_indentation_cannot_interrupt_a_paragraph(self):
        text = ('    [literal](missing.md)\n\n'
                '<pre>\n[raw-literal](missing.md)\n</pre>\n'
                '[paragraph](maintainers/testing.md)\n    [continuation](../RELEASE_NOTES.md)\n')
        expected = text.replace('](maintainers/testing.md)', '](' + self.MAIN + '/blob/' + '1' * 40 + '/docs/maintainers/testing.md)')
        expected = expected.replace('](../RELEASE_NOTES.md)', '](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md)')
        self.assertEqual(self.render(text), expected)

    def test_list_padding_tabs_and_paragraph_boundaries_keep_prose_links(self):
        for prefix in ('-    ', '-\t', '1.   '):
            text = prefix + '[normal](../RELEASE_NOTES.md)\n'
            self.assertEqual(self.render(text), text.replace('](../RELEASE_NOTES.md)',
                '](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md)'))
        text = '-     [literal](../RELEASE_NOTES.md)\n\n[after](maintainers/testing.md)\n'
        self.assertEqual(self.render(text), text.replace('](maintainers/testing.md)',
            '](' + self.MAIN + '/blob/' + '1' * 40 + '/docs/maintainers/testing.md)'))
        for beginning in ('=', 'paragraph\n+'):
            text = beginning + '\n    [normal](../RELEASE_NOTES.md)\n'
            self.assertEqual(self.render(text), text.replace('](../RELEASE_NOTES.md)',
                '](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md)'))

    def test_repository_bindings_reject_mutable_revisions_and_unsafe_prefixes(self):
        (self.root / 'docs/guide.md').write_text('[release](../RELEASE_NOTES.md)')
        for mapping in ({'.': (self.MAIN, 'main')}, {'../escape': (self.MAIN, '1' * 40)},
                        {r'packages\macros': (self.MACRO, '2' * 40)}):
            with self.subTest(mapping=mapping), self.assertRaises(ValueError):
                self.catalog(mapping)

    def test_illegal_or_missing_repository_paths_fail_during_collection_and_rewrite(self):
        for target in ('../../outside.md', '..%2f..%2foutside.md', '/absolute.md', r'..\outside.md',
                       r'C:\private\file.md', '../missing.md', '../bad%00.md'):
            with self.subTest(target=target):
                (self.root / 'docs/guide.md').write_text('[bad](' + target + ')')
                with self.assertRaises(ValueError): self.collect(self.root, self.sources)
                with self.assertRaises(ValueError): self.rewrite(self.root, 'docs/guide.md', self.sources, ())

    def test_symlink_file_and_ancestor_cannot_supply_repository_links(self):
        for mode in ('file', 'ancestor'):
            with self.subTest(mode=mode):
                target = self.root / ('linked.md' if mode == 'file' else 'linked')
                target.symlink_to(self.root / ('RELEASE_NOTES.md' if mode == 'file' else 'docs'), target_is_directory=mode != 'file')
                (self.root / 'docs/guide.md').write_text('[bad](../' + ('linked.md' if mode == 'file' else 'linked/peer.md') + ')')
                with self.assertRaises(ValueError): self.collect(self.root, self.sources)
                with self.assertRaises(ValueError): self.rewrite(self.root, 'docs/guide.md', self.sources, ())

    def test_frozen_rewrite_needs_only_bound_source_and_metadata_never_target_bodies(self):
        (self.root / 'docs/guide.md').write_text('[release](../RELEASE_NOTES.md)')
        catalog = self.catalog()
        frozen = self.root / 'frozen'; (frozen / 'docs').mkdir(parents=True)
        (frozen / 'docs/guide.md').write_bytes((self.root / 'docs/guide.md').read_bytes())
        self.assertEqual(self.rewrite(frozen, 'docs/guide.md', self.sources, catalog),
            '[release](' + self.MAIN + '/blob/' + '1' * 40 + '/RELEASE_NOTES.md)')
        (frozen / 'docs/guide.md').write_text('[changed](../elsewhere.md)')
        with self.assertRaises(ValueError): self.rewrite(frozen, 'docs/guide.md', self.sources, catalog)

    def test_target_body_changes_do_not_change_immutable_metadata_but_tree_type_must_match(self):
        (self.root / 'docs/guide.md').write_text('[release](../RELEASE_NOTES.md)')
        original = self.catalog()
        (self.root / 'RELEASE_NOTES.md').write_text('updated editorial record, not producer input')
        self.assertEqual(self.catalog(), original)
        for committed in (None, ('120000', 'blob', 'a' * 40), ('160000', 'commit', 'a' * 40)):
            with self.subTest(committed=committed):
                if committed is None: self.trees['.'].pop('RELEASE_NOTES.md', None)
                else: self.trees['.']['RELEASE_NOTES.md'] = committed
                with self.assertRaisesRegex(ValueError, 'fixed revision'): self.catalog()

    def test_source_only_catalog_requires_verified_manifest_membership(self):
        with self.assertRaisesRegex(ValueError, 'fixed trees'):
            self.make_catalog(self.root, self.sources, self.repositories, candidate_files=frozenset())
        (self.root / '.git').rmdir()
        (self.root / 'docs/guide.md').write_text('[release](../RELEASE_NOTES.md)')
        with self.assertRaisesRegex(ValueError, 'provenance'): self.catalog()
        with self.assertRaisesRegex(ValueError, 'candidate manifest'):
            self.make_catalog(self.root, self.sources, self.repositories, candidate_files=frozenset())
        actual = self.make_catalog(self.root, self.sources, self.repositories,
            candidate_files=frozenset({'RELEASE_NOTES.md'}))
        self.assertEqual(actual[0].target, 'RELEASE_NOTES.md')
        self.assertIsNone(actual[0].blob_oid)

    def test_real_git_tree_decoder_keeps_modes_and_paths(self):
        output = b'100644 blob ' + b'a' * 40 + b'\twith space.md\0' + b'120000 blob ' + b'b' * 40 + b'\tlinked.md\0'
        with patch('api_doc_repository_links.subprocess.run', return_value=subprocess.CompletedProcess([], 0, output, b'')):
            decoded = self.read_git_files(self.root, '1' * 40)
        self.assertEqual(decoded, {'with space.md': ('100644', 'blob', 'a' * 40),
                                   'linked.md': ('120000', 'blob', 'b' * 40)})

    def test_html_checker_checks_all_relative_href_src_within_site_but_not_anchors_or_external_urls(self):
        site = self.root / 'site'; (site / 'html/guides').mkdir(parents=True)
        (site / 'html/style.css').write_text('body {}')
        (site / 'html/image.svg').write_text('<svg/>')
        (site / 'html/guides/page.html').write_text('<a href="../index.html?x=1#not-an-anchor-check">index</a>')
        (site / 'html/index.html').write_text('<a href="guides/page.html">page</a><a href="#unknown">anchor</a>'
            '<link href="style.css" rel="stylesheet"><img src="image.svg"><a href="https://example.test/missing">web</a>')
        self.assertEqual(self.check_html(site)['htmlPages'], 2)
        # Custom product entry points are outside the producer-owned html scan.
        (site / 'index.html').write_text('<a href="examples/index.html">pending</a>')
        self.check_html(site)
        for reference in ('<a href="RELEASE_NOTES.md">bad</a>', '<img src="missing.svg">',
                          '<a href="../../outside.md">escape</a>'):
            with self.subTest(reference=reference):
                (site / 'html/index.html').write_text(reference)
                with self.assertRaises(ValueError): self.check_html(site)
        (site / 'html/linked').symlink_to(self.root, target_is_directory=True)
        (site / 'html/index.html').write_text('<a href="linked/README.md">bad</a>')
        with self.assertRaises(ValueError): self.check_html(site)


class RepositoryLinksIntegrationTest(unittest.TestCase):
    def test_actual_workspace_rewrites_release_maintainer_and_performance_before_production(self):
        original = (ROOT / 'README.md').read_bytes()
        identity = source_identity()
        with tempfile.TemporaryDirectory() as directory:
            workspace = pathlib.Path(directory) / 'workspace'; create_workspace(workspace, revisions=identity)
            text = (workspace / 'README.md').read_text()
            for target in ('RELEASE_NOTES.md', 'docs/maintainers/testing.md', 'docs/performance/README.md'):
                self.assertIn('https://github.com/lIlIIlIll/yjson/blob/' + identity['revision'] + '/' + target, text)
            self.assertIn('](docs/custom-codecs.md)', text)
        self.assertEqual((ROOT / 'README.md').read_bytes(), original)

    def test_real_link_catalog_avoids_supplementary_bodies_and_preserves_consumer_closure(self):
        required = {'CHANGELOG.md', 'CONTRIBUTING.md', 'LICENSE', 'RELEASE_NOTES.md', 'SECURITY.md', 'THIRD_PARTY_NOTICES.md',
            'docs/implementation/cjdoc-020.md', 'docs/migration/0.1-to-0.2.md',
            'docs/maintainers/api-documentation.md', 'docs/maintainers/native-internals.md',
            'docs/maintainers/releasing.md', 'docs/maintainers/repository-layout.md', 'docs/maintainers/testing.md',
            'docs/performance/README.md', 'docs/performance/methodology.md',
            'docs/performance/results/2026-10-26-cjdoc-020-pure.md', 'docs/performance/results/2026-10-26-cjdoc-020-seven-library.md',
            'packages/examples/README.md', 'release/0.1.1/binary-compatibility.json', 'release/0.1.1/evidence.md',
            'release/0.2.0/enum-case-inventory.json', 'release/cjdoc-policy.toml', 'release/cjdoc-tool.toml',
            'release/public-api-inventory.toml', 'release/public-api-snapshot.txt',
            'release/public-cangjie-delta-0.2.0.toml', 'release/public-cangjie-delta-bfd29.toml', 'release/release-graph.toml'}
        self.assertLessEqual(required, {p.as_posix() for p in manifest_paths(ROOT / 'release/release-files.txt')})
        existing = {'LICENSE', 'THIRD_PARTY_NOTICES.md', 'release/cjdoc-policy.toml', 'release/cjdoc-tool.toml',
                    'release/public-api-inventory.toml', 'release/public-api-snapshot.txt', 'release/release-graph.toml'}
        original_read = pathlib.Path.read_bytes
        def producer_bytes(path):
            self.assertNotIn(path, {ROOT / target for target in required - existing})
            return original_read(path)
        with patch.object(pathlib.Path, 'read_bytes', producer_bytes):
            identity = source_identity()
        self.assertEqual({entry['target'] for entry in identity['repositoryLinks']}, required)
        self.assertTrue((required - existing).isdisjoint(identity['files']))
        self.assertEqual(len(identity['files']), 145)
        self.assertIn('scripts/api_doc_repository_links.py', identity['files'])
        with tempfile.TemporaryDirectory() as directory:
            frozen = pathlib.Path(directory) / 'sources'; freeze_sources(ROOT, frozen, identity)
            with patch('generate_api_docs.source_revisions', side_effect=AssertionError('must use frozen revisions')):
                create_workspace(pathlib.Path(directory) / 'workspace', root=frozen, revisions=identity)
            for relative in required - existing:
                self.assertFalse((frozen / relative).exists())
            verify_frozen_sources(frozen, identity)

    def test_source_only_identity_derives_links_only_after_real_provenance_validation(self):
        # A deterministic unit fixture, not a formally clean production candidate.
        paths = manifest_paths(ROOT / 'release/release-files.txt')
        with tempfile.TemporaryDirectory() as directory:
            candidate = pathlib.Path(directory) / 'candidate'; candidate.mkdir()
            for relative in paths:
                target = candidate / relative; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, target)
            provenance = release_identity(candidate, paths, False)
            provenance.update(clean_enforced=True, commit='1' * 40, tree='2' * 40)
            write_provenance(candidate, provenance)
            identity = source_identity(candidate)
            self.assertEqual(identity['revision'], '1' * 40)
            self.assertEqual(len(identity['files']), 145)
            self.assertTrue(all(entry['blob_oid'] is None for entry in identity['repositoryLinks']))
            self.assertIn('https://github.com/lIlIIlIll/yjson/blob/' + '1' * 40 + '/RELEASE_NOTES.md',
                          {entry['url'] for entry in identity['repositoryLinks']})
            frozen = pathlib.Path(directory) / 'frozen'; freeze_sources(candidate, frozen, identity)
            create_workspace(pathlib.Path(directory) / 'workspace', root=frozen, revisions=identity)
            (candidate / 'RELEASE_NOTES.md').write_text('tampered candidate payload')
            with self.assertRaisesRegex(ApiDocsError, 'unverified source-only candidate'):
                source_identity(candidate)


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
