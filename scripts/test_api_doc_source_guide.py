#!/usr/bin/env python3
"""Verify per-repository links without rewriting the producer's Doc IR."""
from __future__ import annotations

import copy
from dataclasses import replace
import pathlib
import re
import tempfile
import unittest

from api_doc_source_guide import SourceRepository, render_source_guide


class SourceGuideTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.workspace = pathlib.Path(self.temporary.name)
        for path in ("src/core.cj", "packages/yjson_macros/src/macro.cj"):
            file = self.workspace / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("package fixture\npublic func item(): Unit {}\n", encoding="utf-8")
        self.sources = {
            "yjson": SourceRepository("src", ".", "https://github.com/example/yjson", "a" * 40),
            "yjson_macros": SourceRepository("packages/yjson_macros/src", "packages/yjson_macros",
                                              "https://github.com/example/yjson_macros", "b" * 40),
        }
        self.document = {
            "schemaVersion": "cjdoc.doc-ir/16",
            "modules": [{"id": "core", "name": "yjson"}, {"id": "macro", "name": "yjson_macros"}],
            "declarations": [
                {"id": "one", "qualifiedName": "yjson.item", "kind": "function",
                 "headerSpelling": "public func item(): Unit", "moduleId": "core", "visibility": "public",
                 "source": {"path": "src/core.cj", "start": {"line": 2}}},
                {"id": "two", "qualifiedName": "yjson_macros.Json", "kind": "macro",
                 "headerSpelling": "public macro Json(input: Tokens): Tokens", "moduleId": "macro", "visibility": "public",
                 "source": {"path": "packages/yjson_macros/src/macro.cj", "start": {"line": 2}}},
            ],
        }

    def render(self) -> tuple[list[dict], dict]:
        return render_source_guide(self.document, self.workspace, self.sources)

    def test_links_use_each_repository_and_exact_source_position(self) -> None:
        before = copy.deepcopy(self.document)
        pages, report = self.render()
        markdown = re.sub(r'\\(.)', r'\1', ''.join(page['markdown'] for page in pages))
        self.assertIn("https://github.com/example/yjson/blob/" + "a" * 40 + "/src/core.cj#L2", markdown)
        self.assertIn("https://github.com/example/yjson_macros/blob/" + "b" * 40 + "/src/macro.cj#L2", markdown)
        self.assertNotIn("/blob/" + "a" * 40 + "/packages/yjson_macros/", markdown)
        self.assertNotIn(str(self.workspace), markdown)
        self.assertEqual(self.document, before)
        self.assertEqual(report["declarations"], 2)
        self.assertEqual([page['source'] for page in pages], [
            'docs/api-source-index.md', 'docs/api-source-yjson.md', 'docs/api-source-yjson_macros.md'])
        self.assertIn('(api-source-yjson.md)', pages[0]['markdown'])
        self.assertEqual(pages[1]['markdown'].splitlines()[0], '# yjson 声明源码')
        self.assertEqual(pages[2]['markdown'].splitlines()[0], '# yjson_macros 声明源码')
        self.assertLess(len(pages[0]['markdown'].encode()), 1024)
        self.assertEqual(sum(page['declarations'] for page in report['pages']), 2)

    def test_order_does_not_depend_on_collection_order(self) -> None:
        before = self.render()
        self.document["declarations"].reverse()
        self.document["modules"].reverse()
        self.sources = dict(reversed(list(self.sources.items())))
        self.assertEqual(self.render(), before)

    def test_rejects_path_escape_or_wrong_package(self) -> None:
        declaration = self.document["declarations"][1]
        for path in ("../macro.cj", "/src/core.cj", "packages\\yjson_macros\\src\\macro.cj", "src/core.cj"):
            with self.subTest(path=path):
                declaration["source"]["path"] = path
                with self.assertRaises(ValueError):
                    self.render()

    def test_rejects_missing_or_invalid_source_position(self) -> None:
        declaration = self.document["declarations"][0]
        for line in (0, 3, True, "2", None):
            with self.subTest(line=line):
                declaration["source"]["start"]["line"] = line
                with self.assertRaisesRegex(ValueError, "source line"):
                    self.render()
        declaration["source"] = None
        with self.assertRaisesRegex(ValueError, "actual source position"):
            self.render()

    def test_rejects_source_symlink(self) -> None:
        file = self.workspace / "src/core.cj"
        file.unlink()
        file.symlink_to(self.workspace / "packages/yjson_macros/src/macro.cj")
        with self.assertRaisesRegex(ValueError, "regular workspace source"):
            self.render()

    def test_rejects_source_directory_symlink_into_another_package(self) -> None:
        source = self.workspace / "packages/yjson_macros/src"
        (source / "macro.cj").unlink()
        source.rmdir()
        source.symlink_to(self.workspace / "src", target_is_directory=True)
        self.document["declarations"][1]["source"]["path"] = "packages/yjson_macros/src/core.cj"
        with self.assertRaisesRegex(ValueError, "regular workspace source"):
            self.render()

    def test_rejects_repository_directory_symlink(self) -> None:
        repository = self.workspace / "packages/yjson_macros"
        relocated = self.workspace / "relocated-macros"
        repository.rename(relocated)
        repository.symlink_to(relocated, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "regular workspace source"):
            self.render()

    def test_rejects_unbound_or_duplicate_identity(self) -> None:
        self.document["declarations"].append(copy.deepcopy(self.document["declarations"][0]))
        with self.assertRaisesRegex(ValueError, "unique"):
            self.render()
        self.document["declarations"].pop()
        self.document["declarations"][0]["moduleId"] = "unbound"
        with self.assertRaisesRegex(ValueError, "no release module"):
            self.render()

    def test_rejects_unpinned_source_and_legacy_schema(self) -> None:
        original = self.sources["yjson"]
        self.sources["yjson"] = replace(original, revision="main")
        with self.assertRaisesRegex(ValueError, "exact lowercase Git"):
            self.render()
        self.sources["yjson"] = replace(original, repository_url="https://example.test/yjson")
        with self.assertRaisesRegex(ValueError, "public GitHub"):
            self.render()
        self.sources["yjson"] = original
        self.document["schemaVersion"] = "cjdoc.doc-ir/15"
        with self.assertRaisesRegex(ValueError, "current Doc IR v16"):
            self.render()

    def test_protected_members_remain_visible_and_private_members_are_excluded(self) -> None:
        self.document["declarations"][0]["visibility"] = "protected"
        self.document["declarations"][1]["visibility"] = "private"
        pages, report = self.render()
        markdown = re.sub(r'\\(.)', r'\1', ''.join(page['markdown'] for page in pages))
        self.assertIn("yjson.item", markdown)
        self.assertNotIn("yjson_macros.Json", markdown)
        self.assertEqual(report["declarations"], 1)

    def test_public_member_of_private_owner_is_excluded(self) -> None:
        self.document["declarations"].append({"id": "owner", "visibility": "private", "ownerId": None})
        self.document["declarations"][0]["ownerId"] = "owner"
        pages, report = self.render()
        markdown = re.sub(r'\\(.)', r'\1', ''.join(page['markdown'] for page in pages))
        self.assertNotIn("yjson.item", markdown)
        self.assertEqual(report["declarations"], 1)

    def test_large_module_splits_only_between_complete_utf8_declarations(self) -> None:
        for number in range(40):
            declaration = copy.deepcopy(self.document['declarations'][0])
            declaration.update(id='extra-' + str(number), qualifiedName='yjson.extra' + str(number),
                               headerSpelling='public func extra' + str(number) + '(说明: ' + '仓颉' * 50 + '): Unit')
            self.document['declarations'].append(declaration)
        pages, report = render_source_guide(self.document, self.workspace, self.sources, max_page_bytes=4096)
        self.assertGreater(len(pages), 3)
        self.assertEqual(sum(page['declarations'] for page in pages), 42)
        for page in pages:
            self.assertLessEqual(len(page['markdown'].encode('utf-8')), 4096)
            self.assertEqual(page['markdown'].encode('utf-8').decode('utf-8'), page['markdown'])
            if page['module']:
                self.assertEqual(page['markdown'].count('#L2'), page['declarations'])
        combined = re.sub(r'\\(.)', r'\1', ''.join(page['markdown'] for page in pages))
        for declaration in self.document['declarations']:
            self.assertEqual(combined.count('` ' + declaration['qualifiedName'] + '；'), 1)
        self.document['declarations'].reverse()
        self.assertEqual(render_source_guide(self.document, self.workspace, self.sources, max_page_bytes=4096), (pages, report))

    def test_single_oversize_declaration_and_unbounded_page_budget_are_rejected(self) -> None:
        self.document['declarations'][0]['headerSpelling'] = 'public func huge(' + '输入' * 2000 + '): Unit'
        with self.assertRaisesRegex(ValueError, 'one source declaration'):
            render_source_guide(self.document, self.workspace, self.sources, max_page_bytes=1024)
        with self.assertRaisesRegex(ValueError, 'page budget'):
            render_source_guide(self.document, self.workspace, self.sources, max_page_bytes=262144)

    def test_link_label_treats_source_signatures_as_text(self) -> None:
        self.document['declarations'][0]['headerSpelling'] = 'public func read<T>(value: T): String /* </code><script> */'
        pages, _ = self.render()
        module = next(page for page in pages if page['module'] == 'yjson')
        self.assertIn('[` yjson.item；public func read<T>(value: T): String /* </code><script> */；src/core.cj:2 `]', module['markdown'])

    def test_signature_backticks_and_link_syntax_stay_inside_one_code_span(self) -> None:
        signature = 'public func op(): String /* ` ](https://example.test) | */'
        self.document['declarations'][0]['headerSpelling'] = signature
        pages, _ = self.render()
        module = next(page for page in pages if page['module'] == 'yjson')
        self.assertIn('[`` yjson.item；' + signature + '；src/core.cj:2 ``]', module['markdown'])
        self.assertNotIn('\\|', module['markdown'])


if __name__ == "__main__":
    unittest.main()
