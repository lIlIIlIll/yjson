#!/usr/bin/env python3
"""Bind supplementary repository links before cjdoc reads ordinary Markdown."""
from __future__ import annotations

from html.parser import HTMLParser
from dataclasses import dataclass
import pathlib
import posixpath
import re
import subprocess
from urllib.parse import quote, unquote, urlsplit


def markdown_sources(root: pathlib.Path) -> tuple[str, ...]:
    return ('README.md', *(path.relative_to(root).as_posix() for path in sorted((root / 'docs').glob('*.md'))))


def _regular_file(root: pathlib.Path, relative: str) -> pathlib.Path:
    path = pathlib.PurePosixPath(relative)
    if (not relative or path.is_absolute() or '..' in path.parts or path.as_posix() != relative
            or '\\' in relative or ':' in relative or any(ord(char) < 32 for char in relative)):
        raise ValueError('repository link has an unsafe relative file path')
    if root.is_symlink() or any(root.joinpath(*path.parts[:index]).is_symlink()
                               for index in range(1, len(path.parts) + 1)):
        raise ValueError('repository link cannot use a symlink or linked ancestor')
    result = root.joinpath(*path.parts)
    if not result.is_file():
        raise ValueError('repository link target is not a regular file: ' + relative)
    return result


def _indent(line: str, column: int = 0) -> tuple[int, int]:
    index = 0
    while index < len(line) and line[index] in ' \t':
        column += 4 - column % 4 if line[index] == '\t' else 1
        index += 1
    return index, column


def _list_marker(line: str):
    start, indent = _indent(line)
    marker = re.match(r'(?:[-+*]|[0-9]{1,9}[.)])(?=[ \t]|$)', line[start:]) if indent <= 3 else None
    if marker is None: return None
    end = start + marker.end()
    whitespace, column = _indent(line[end:], indent + marker.end())
    padding = column - (indent + marker.end())
    content_indent = column if 1 <= padding <= 4 else indent + marker.end() + 1
    return indent, content_indent, ' ' * max(0, column - content_indent) + line[end + whitespace:]


def _quote_content(line: str):
    start, indent = _indent(line)
    if indent > 3 or line[start:start + 1] != '>': return None
    whitespace, column = _indent(line[start + 1:], indent + 1)
    return ' ' * max(0, column - indent - 2) + line[start + 1 + whitespace:]


def _html_block(line: str):
    # Match the pinned Markdown parser's literal HTML block categories.
    stripped = line.lstrip(' ')
    if len(line) - len(stripped) > 3: return None
    lower = stripped.lower()
    if lower.startswith(('<script', '<pre', '<style', '<textarea')):
        return 1, r'</(?:script|pre|style|textarea)>'
    for opener, kind, closer in (('<!--', 2, '-->'), ('<?', 3, r'\?>'), ('<![CDATA[', 5, r'\]\]>')):
        if stripped.startswith(opener): return kind, closer
    if re.match(r'<![A-Z]', stripped): return 4, '>'
    tag = re.match(r'</?([A-Za-z][A-Za-z0-9]*)(?=[ \t/>])', stripped)
    block_tags = ('address article aside base basefont blockquote body caption center col colgroup dd details dialog dir div dl dt '
                  'fieldset figcaption figure footer form frame frameset h1 h2 h3 h4 h5 h6 head header hr html iframe legend li link '
                  'main menu menuitem nav noframes ol optgroup option p param section source summary table tbody td tfoot th thead title tr track ul').split()
    if tag and tag[1].lower() in block_tags: return 6, None
    if re.fullmatch(r'</?[A-Za-z][^>]*>[ \t]*', stripped): return 7, None
    return None


def _fence(line: str):
    return re.match(r'^ {0,3}(`{3,}|~{3,})', line)


def _heading_or_break(line: str) -> bool:
    return bool(re.match(r'^ {0,3}#{1,6}(?:[ \t]|$)', line)
                or any(re.fullmatch(r' {0,3}(?:' + re.escape(marker) + r'[ \t]*){3,}', line) for marker in '*_-'))


def _interrupts_paragraph(line: str) -> bool:
    html = _html_block(line)
    marker = _list_marker(line)
    ordered = re.match(r'^ {0,3}([0-9]+)[.)]', line)
    return bool(_fence(line) or _heading_or_break(line) or _quote_content(line) is not None
                or html and html[0] != 7 or marker and marker[2].strip() and (ordered is None or ordered[1] == '1'))


def _literal_lines(lines: list[tuple[int, str]]) -> set[int]:
    """Find literal blocks after quote/list indentation, without rendering Markdown.

    The column and container rules follow markdown db4f952's parseIndentedCode,
    scanQuote and scanList; indented code cannot interrupt an open paragraph.
    """
    literal = set()
    index = 0
    paragraph = False
    while index < len(lines):
        number, line = lines[index]
        if not line.strip():
            paragraph = False; index += 1; continue
        if paragraph and re.fullmatch(r' {0,3}(?:=+|-+)[ \t]*', line):
            paragraph = False; index += 1; continue
        if paragraph and not _interrupts_paragraph(line):
            index += 1; continue
        paragraph = False
        if _indent(line)[1] >= 4:
            while index < len(lines) and (_indent(lines[index][1])[1] >= 4 or not lines[index][1].strip()):
                literal.add(lines[index][0]); index += 1
            continue
        opening = _fence(line)
        html = _html_block(line)
        if opening or html:
            marker = opening[1] if opening else None
            first = index
            while index < len(lines):
                body = lines[index][1]
                if html and html[1] is None and index > first and not body.strip(): break
                literal.add(lines[index][0]); index += 1
                if marker and index > first + 1 and re.fullmatch(r' {0,3}' + re.escape(marker[0]) + '{' + str(len(marker)) + r',}[ \t]*', body): break
                if html and html[1] and re.search(html[1], body, re.IGNORECASE): break
            continue
        if _quote_content(line) is not None:
            inner = []
            lazy = False
            while index < len(lines):
                number, body = lines[index]
                content = _quote_content(body)
                if content is not None:
                    inner.append((number, content))
                    lazy = (bool(content.strip()) and _indent(content)[1] < 4 and not _fence(content)
                            and not _html_block(content) and not _heading_or_break(content))
                elif lazy and body.strip() and not (_fence(body) or _list_marker(body) or _heading_or_break(body)):
                    inner.append((number, body))
                else: break
                index += 1
            literal.update(_literal_lines(inner))
            continue
        marker = _list_marker(line)
        if marker:
            base_indent, content_indent, content = marker
            inner = [(number, content)]; index += 1
            while index < len(lines):
                number, body = lines[index]
                following = _list_marker(body)
                if following and following[0] == base_indent: break
                if not body.strip():
                    ahead = index + 1
                    while ahead < len(lines) and not lines[ahead][1].strip(): ahead += 1
                    if ahead == len(lines) or _indent(lines[ahead][1])[1] < content_indent: break
                    inner.append((number, ''))
                elif _indent(body)[1] >= content_indent:
                    start, columns = _indent(body)
                    inner.append((number, ' ' * (columns - content_indent) + body[start:]))
                elif not _interrupts_paragraph(body):
                    inner.append((number, body))
                else: break
                index += 1
            literal.update(_literal_lines(inner))
            continue
        paragraph = not _heading_or_break(line) and not re.match(r'^ {0,3}\[[^\]\n]+\]:', line)
        index += 1
    return literal


def _without_code(text: str) -> str:
    """Mask code while preserving offsets into the original Markdown text."""
    masked = list(text)
    lines = text.splitlines(keepends=True)
    literal = _literal_lines([(index, line.rstrip('\r\n')) for index, line in enumerate(lines)])
    offset = 0
    for number, line in enumerate(lines):
        if number in literal:
            for index in range(offset, offset + len(line)):
                if text[index] not in '\r\n': masked[index] = ' '
        offset += len(line)
    visible = ''.join(masked)
    index = 0
    while index < len(visible):
        if visible[index] == '\\':
            index += 2; continue
        if visible[index] != '`':
            index += 1; continue
        end = index
        while end < len(visible) and visible[end] == '`': end += 1
        closing = re.search(r'(?<!`)`{' + str(end - index) + r'}(?!`)', visible[end:])
        if closing:
            finish = end + closing.end()
            for position in range(index, finish):
                if text[position] not in '\r\n': masked[position] = ' '
            index = finish
        else:
            index = end
    return ''.join(masked)


def _destination(text: str, offset: int) -> tuple[int, int] | None:
    while offset < len(text) and text[offset].isspace(): offset += 1
    if offset >= len(text): return None
    if text[offset] == '<':
        end = offset + 1
        while end < len(text):
            if text[end] == '\\': end += 2; continue
            if text[end] == '>': return offset + 1, end
            if text[end] in '\r\n': return None
            end += 1
        return None
    start = offset
    depth = 0
    while offset < len(text):
        char = text[offset]
        if char == '\\': offset += 2; continue
        if char.isspace() or char == ')' and depth == 0: break
        if char == '(': depth += 1
        elif char == ')': depth -= 1
        offset += 1
    return (start, offset) if offset > start and depth == 0 else None


def _destinations(text: str):
    visible = _without_code(text)
    offsets = set()
    # Reference definitions and inline/image links share the destination parser.
    for definition in re.finditer(r'^ {0,3}\[[^\]\n]+\]:[ \t]*', visible, re.MULTILINE):
        destination = _destination(text, definition.end())
        if destination: offsets.add(destination)
    brackets = []
    index = 0
    while index < len(visible):
        char = visible[index]
        if char == '\\': index += 2; continue
        if char == '[': brackets.append(index)
        elif char == ']' and brackets:
            brackets.pop()
            if visible[index + 1:index + 2] == '(':
                destination = _destination(text, index + 2)
                if destination:
                    start, end = destination
                    tail = end + (1 if text[start - 1:start] == '<' else 0)
                    # Leave an optional Markdown title intact.
                    title = re.match(r'''\s*(?:"[^"\n]*"|'[^'\n]*'|\([^\n]*?\))?\s*\)''', text[tail:])
                    if title: offsets.add(destination)
        index += 1
    yield from sorted(offsets)


def _references(root: pathlib.Path, source: str, sources: tuple[str, ...], text: str):
    for start, end in _destinations(text):
        raw = text[start:end]
        target = re.sub(r'\\([!"#$%&\'()*+,\-./:;<=>?@\[\]\\^_`{|}~])', r'\1', raw)
        if re.match(r'^[A-Za-z]:[\\/]', target):
            raise ValueError('repository link cannot use a machine path')
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue  # External URLs, API/symbol links and page anchors keep their input spelling.
        path = unquote(parsed.path, errors='strict')
        if path.startswith('/') or '\\' in path or any(ord(char) < 32 for char in path):
            raise ValueError('repository link has an unsafe target')
        relative = posixpath.normpath(posixpath.join(posixpath.dirname(source), path))
        if relative in sources:
            _regular_file(root, relative)
        else:
            yield start, end, relative, target[len(parsed.path):]


@dataclass(frozen=True)
class RepositoryLink:
    source: str
    destination: str
    target: str
    repository: str
    revision: str
    url: str
    blob_oid: str | None


def _git_files(root: pathlib.Path, revision: str) -> dict[str, tuple[str, str, str]]:
    result = subprocess.run(['git', '-C', str(root), 'ls-tree', '-rz', '--full-tree', revision],
                            capture_output=True, timeout=30, check=False)
    if result.returncode:
        raise ValueError('cannot inspect the immutable repository link revision')
    files = {}
    for entry in result.stdout.split(b'\0'):
        if not entry: continue
        metadata, path = entry.split(b'\t', 1)
        mode, kind, oid = metadata.decode('ascii').split()
        files[path.decode('utf-8')] = mode, kind, oid
    return files


def repository_link_catalog(root: pathlib.Path, sources: tuple[str, ...],
                            repositories: dict[str, tuple[str, str]], *,
                            candidate_files: frozenset[str] | None = None) -> tuple[RepositoryLink, ...]:
    """Read link sources and file metadata, never supplementary target bodies.

    A source-only caller must first validate clean candidate provenance with the
    existing release validator, then supply its release manifest file inventory.
    """
    for prefix, (url, revision) in repositories.items():
        if (prefix != '.' and (not prefix or '\\' in prefix or ':' in prefix
                              or pathlib.PurePosixPath(prefix).as_posix() != prefix
                              or prefix.startswith('/') or '..' in pathlib.PurePosixPath(prefix).parts)):
            raise ValueError('repository link prefix must be a normalized relative directory')
        if re.fullmatch(r'https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', url) is None:
            raise ValueError('repository links require a public GitHub repository')
        if re.fullmatch(r'[0-9a-f]{40}', revision) is None:
            raise ValueError('repository links require exact immutable revisions')
    is_checkout = (root / '.git').exists()
    if not is_checkout and candidate_files is None:
        raise ValueError('source-only repository links require verified candidate provenance')
    if is_checkout and candidate_files is not None:
        raise ValueError('a Git checkout must validate repository links against its fixed trees')
    trees = {}
    records = {}
    for source in sources:
        text = _regular_file(root, source).read_bytes().decode('utf-8')
        for start, end, relative, suffix in _references(root, source, sources, text):
            _regular_file(root, relative)  # File and ancestors only; do not read its body.
            matches = [prefix for prefix in repositories if prefix == '.' or relative.startswith(prefix + '/')]
            if not matches: raise ValueError('repository link target has no repository binding')
            prefix = max(matches, key=len)
            url, revision = repositories[prefix]
            repository_path = relative if prefix == '.' else relative[len(prefix) + 1:]
            oid = None
            if candidate_files is not None:
                if relative not in candidate_files:
                    raise ValueError('repository link target is outside the verified candidate manifest')
            else:
                if prefix not in trees:
                    trees[prefix] = _git_files(root if prefix == '.' else root / prefix, revision)
                committed = trees[prefix].get(repository_path)
                if not committed or committed[0] not in ('100644', '100755') or committed[1] != 'blob':
                    raise ValueError('repository link target is not a regular file in its fixed revision')
                oid = committed[2]
            records[source, text[start:end]] = RepositoryLink(source, text[start:end], relative, url, revision,
                url + '/blob/' + revision + '/' + quote(repository_path, safe='/') + suffix, oid)
    return tuple(records[key] for key in sorted(records))


def rewrite_repository_links(root: pathlib.Path, source: str, sources: tuple[str, ...],
                             catalog: tuple[RepositoryLink, ...]) -> str:
    """Use only the frozen source page and its captured immutable link metadata."""
    text = _regular_file(root, source).read_bytes().decode('utf-8')
    bindings = {entry.destination: entry for entry in catalog if entry.source == source}
    edits = []
    seen = set()
    for start, end, relative, suffix in _references(root, source, sources, text):
        entry = bindings.get(text[start:end])
        if entry is None or entry.target != relative:
            raise ValueError('frozen Markdown differs from its repository link catalog')
        seen.add(entry.destination)
        edits.append((start, end, entry.url))
    if seen != set(bindings):
        raise ValueError('repository link catalog has unused frozen page bindings')
    for start, end, replacement in reversed(edits): text = text[:start] + replacement + text[end:]
    return text


class _HtmlLinks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links = []

    def handle_starttag(self, tag, attrs):
        self.links.extend(value for name, value in attrs if name in ('href', 'src') and value is not None)


def validate_html_file_links(site: pathlib.Path) -> dict:
    """Read every producer HTML page; custom root entries are outside this domain."""
    directory = site / 'html'
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError('cjdoc HTML directory must be present and regular')
    pages = sorted(directory.rglob('*.html'))
    if not pages: raise ValueError('cjdoc HTML has no pages to validate')
    checked = 0
    for page in pages:
        parser = _HtmlLinks()
        parser.feed(_regular_file(site, page.relative_to(site).as_posix()).read_text(encoding='utf-8'))
        for target in parser.links:
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path: continue
            path = unquote(parsed.path, errors='strict')
            if '\\' in path or any(ord(char) < 32 for char in path):
                raise ValueError('cjdoc HTML link has an unsafe target')
            relative = posixpath.normpath(path.lstrip('/') if path.startswith('/') else
                                         posixpath.join(page.relative_to(site).parent.as_posix(), path))
            try:
                _regular_file(site, relative)
            except ValueError as error:
                raise ValueError('cjdoc HTML file link is invalid: ' + page.relative_to(site).as_posix()
                                 + ' -> ' + target) from error
            checked += 1
    return {'htmlPages': len(pages), 'localFileLinks': checked}
