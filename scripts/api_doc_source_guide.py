#!/usr/bin/env python3
"""Render bounded source-index pages before the final cjdoc generation."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import pathlib
import re
from typing import Mapping
from urllib.parse import quote

from check_api_documentation import visible_declarations

MAX_GUIDE_PAGE_BYTES = 32 * 1024  # Keep individual Agent page reads and browser pages bounded.


@dataclass(frozen=True)
class SourceRepository:
    source_root: str
    repository_prefix: str
    repository_url: str
    revision: str


def relative_path(value: str, *, allow_root: bool = False) -> pathlib.PurePosixPath:
    if not isinstance(value, str) or "\\" in value or any(char in value for char in "\r\n\0"):
        raise ValueError("source guide requires a normalized relative source path")
    path = pathlib.PurePosixPath(value)
    if (path.is_absolute() or ".." in path.parts or path.as_posix() != value
            or (not allow_root and not path.parts)):
        raise ValueError("source guide requires a normalized relative source path")
    return path


def inline_code(value: str) -> str:
    value = " ".join(value.split())
    delimiter = "`" * (1 + max((len(run) for run in re.findall(r"`+", value)), default=0))
    return delimiter + " " + value + " " + delimiter


def render_source_guide(document: dict, workspace: pathlib.Path,
                        sources: Mapping[str, SourceRepository], *,
                        max_page_bytes: int = MAX_GUIDE_PAGE_BYTES) -> tuple[list[dict], dict]:
    """Return ordinary guide pages and metadata using actual preliminary positions.

    `source_root` identifies the package's source within the copied workspace.
    `repository_prefix` is stripped only when forming that repository's blob URL
    (for example packages/yjson_macros for the independent macro repository).
    Pages include the short index and deterministic module shards. Each declaration
    remains intact, and no producer-owned projection is modified.
    """
    if document.get("schemaVersion") != "cjdoc.doc-ir/16":
        raise ValueError("source guide requires current Doc IR v16")
    if type(max_page_bytes) is not int or not 1024 <= max_page_bytes <= MAX_GUIDE_PAGE_BYTES:
        raise ValueError("source guide page budget must leave room below cjdoc's 256 KiB limit")
    modules = {}
    for module in document.get("modules", []):
        identity, name = module["id"], module["name"]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", name) is None:
            raise ValueError("source guide module name cannot form a stable page path")
        if identity in modules or name in modules.values():
            raise ValueError("source guide has duplicate module identities")
        modules[identity] = name
    if set(modules.values()) != set(sources):
        raise ValueError("source guide modules do not match the release graph")
    workspace = workspace.resolve()
    repositories = {}
    groups: dict[str, list[tuple]] = {name: [] for name in sources}
    for name, source in sources.items():
        root = relative_path(source.source_root)
        prefix = relative_path(source.repository_prefix, allow_root=True)
        url = source.repository_url.rstrip("/")
        if re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", url) is None:
            raise ValueError("source guide requires a public GitHub repository URL")
        if re.fullmatch(r"[0-9a-f]{40}", source.revision) is None:
            raise ValueError("source guide requires exact lowercase Git revisions")
        if not root.is_relative_to(prefix):
            raise ValueError("source root is outside its repository prefix")
        repositories[name] = (root, prefix, url, source.revision)
    identities = set()
    for declaration in visible_declarations(document):
        identity = declaration["id"]
        identities.add(identity)
        name = modules.get(declaration.get("moduleId"))
        if name is None:
            raise ValueError("source declaration has no release module")
        root, prefix, url, revision = repositories[name]
        location = declaration.get("source")
        if not isinstance(location, dict):
            raise ValueError("source declaration has no actual source position")
        path = relative_path(location.get("path"))
        if not path.is_relative_to(root):
            raise ValueError("source declaration is outside its package source root")
        file = workspace.joinpath(*path.parts)
        components = [workspace.joinpath(*path.parts[:index]) for index in range(1, len(path.parts) + 1)]
        if (any(component.is_symlink() for component in components) or not file.is_file()
                or not file.resolve().is_relative_to(workspace)):
            raise ValueError("source guide cannot locate the regular workspace source")
        line = location.get("start", {}).get("line")
        if type(line) is not int or not 1 <= line <= len(file.read_text(encoding="utf-8").splitlines()):
            raise ValueError("source guide has an invalid source line")
        repository_path = path.relative_to(prefix).as_posix()
        link = f"{url}/blob/{revision}/{quote(repository_path, safe='/')}#L{line}"
        groups[name].append((declaration["qualifiedName"], declaration["kind"],
                             declaration["headerSpelling"], path.as_posix(), line, link))
    index = ["# API 声明源码", "", "以下页面按模块列出每条公开声明的源码位置。链接固定到生成本参考时的提交；宏包使用独立仓库。", ""]
    pages = []
    report_modules = []
    for name in sorted(groups):
        _, _, url, revision = repositories[name]
        declarations = sorted(groups[name])
        heading = ["# " + name + " 声明源码", "", "[返回源码总索引](api-source-index.md)", "",
                   f"[固定源码提交]({url}/tree/{revision})：{inline_code(revision)}", "",
                   "以下各行链接包含声明名、完整签名与源码位置。", ""]
        prefix = "\n".join(heading) + "\n"
        suffix = ""
        overhead = len((prefix + suffix).encode("utf-8"))
        chunks = [[]]
        size = overhead
        for qualified_name, _, signature, path, line, link in declarations:
            # One code span inside an ordinary link keeps all signature syntax
            # literal without a separate Markdown text node per escaped token.
            label = qualified_name + "；" + " ".join(signature.split()) + "；" + path + ':' + str(line)
            row = '[' + inline_code(label) + '](' + link + ')  \n'
            row_bytes = len(row.encode("utf-8"))
            if overhead + row_bytes > max_page_bytes:
                raise ValueError("one source declaration exceeds the guide page byte budget")
            if size + row_bytes > max_page_bytes:
                chunks.append([])
                size = overhead
            chunks[-1].append(row)
            size += row_bytes
        links = []
        for number, rows in enumerate(chunks, 1):
            stem = "api-source-" + name + ("-" + str(number) if number > 1 else "")
            title = name + ("（" + str(number) + "/" + str(len(chunks)) + "）" if len(chunks) > 1 else "")
            pages.append({"source": "docs/" + stem + ".md", "route": "concepts/guides/" + stem,
                          "title": title, "module": name, "declarations": len(rows),
                          "markdown": prefix + "".join(rows) + suffix})
            links.append("[" + title + "](" + stem + ".md)")
        index.append("- " + "、".join(links) + "：" + str(len(declarations)) + " 条声明。")
        report_modules.append({"name": name, "repository": url, "revision": revision,
                               "declarations": len(declarations)})
    index_markdown = "\n".join(index) + "\n"
    if len(index_markdown.encode("utf-8")) > max_page_bytes:
        raise ValueError("source guide index exceeds the page byte budget")
    pages.insert(0, {"source": "docs/api-source-index.md", "route": "concepts/guides/api-source-index",
                     "title": "API 声明源码", "module": None, "declarations": 0, "markdown": index_markdown})
    page_reports = [{key: value for key, value in page.items() if key != "markdown"} | {
        "sha256": hashlib.sha256(page["markdown"].encode("utf-8")).hexdigest(),
        "bytes": len(page["markdown"].encode("utf-8"))} for page in pages]
    return pages, {"schemaVersion": "yjson.api-doc-source-guide/2",
                      "declarations": len(identities), "modules": report_modules,
                      "pageBudgetBytes": max_page_bytes, "pages": page_reports,
                      "sha256": hashlib.sha256(json.dumps(page_reports, ensure_ascii=False, sort_keys=True,
                                                          separators=(",", ":")).encode("utf-8")).hexdigest()}
