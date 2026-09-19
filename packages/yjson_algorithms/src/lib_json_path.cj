package yjson_algorithms

import yjson.*

import std.collection.*
import std.convert.Parsable

func jsonPathError(message: String, expression: String,
    expressionOffset!: Int64 = -1): JsonException {
    let _ = expression
    JsonException(message, code: "invalid_json_path",
        location: if (expressionOffset < 0) { None<JsonLocation> } else {
            Some(JsonLocation(expressionOffset, 1, expressionOffset + 1))
        })
}

public class JsonPathMatch {
    public let value: JsonValueView
    /**
     * RFC 9535 normalized path, rooted at `$`.
     */
    public let normalizedPath: String

    public init(value: JsonValueView, normalizedPath: String) {
        this.value = value
        this.normalizedPath = normalizedPath
    }
}

public class JsonPath {
    public let expression: String
    private let segments: Array<JsonPathSegment>

    init(expression: String, segments: Array<JsonPathSegment>) {
        this.expression = expression
        this.segments = segments
    }

    public static func parse(expression: String): JsonPath {
        parse(expression, limits: JsonPathLimits.defaults)
    }

    /**
     * Parses with compile-time filter budgets from `limits`: expression
     * bytes, logical operator count, and logical nesting depth. Filters
     * exceeding a budget throw `JsonException(code: "invalid_json_path")`
     * instead of being accepted for evaluation.
     */
    public static func parse(expression: String, limits!: JsonPathLimits): JsonPath {
        JsonPathParser(expression, JsonPathFilterBudget(limits)).parse()
    }

    /**
     * Creates a single-threaded lazy cursor. No candidate is visited until
     * `next()` is called.
     */
    public func matches(root: JsonValueView,
        limits!: JsonPathLimits = JsonPathLimits.defaults): JsonPathCursor {
        cursorWithWork(root, JsonPathWork(limits))
    }

    public func matches(document: JsonDocument,
        limits!: JsonPathLimits = JsonPathLimits.defaults): JsonPathCursor {
        matches(document.root(), limits: limits)
    }

    public func collect(root: JsonValueView,
        limits!: JsonPathLimits = JsonPathLimits.defaults): ArrayList<JsonPathMatch> {
        collectWithWork(root, JsonPathWork(limits))
    }

    public func collect(document: JsonDocument,
        limits!: JsonPathLimits = JsonPathLimits.defaults): ArrayList<JsonPathMatch> {
        collect(document.root(), limits: limits)
    }

    func collectWithWork(root: JsonValueView, work: JsonPathWork): ArrayList<JsonPathMatch> {
        let result = ArrayList<JsonPathMatch>()
        let cursor = cursorWithWork(root, work)
        while (let Some(matched) <- cursor.next()) { result.add(matched) }
        result
    }

    public func collectValues(root: JsonValueView,
        limits!: JsonPathLimits = JsonPathLimits.defaults): ArrayList<JsonValueView> {
        collectValuesWithWork(root, JsonPathWork(limits))
    }

    public func collectValues(document: JsonDocument,
        limits!: JsonPathLimits = JsonPathLimits.defaults): ArrayList<JsonValueView> {
        collectValues(document.root(), limits: limits)
    }

    func collectValuesWithWork(root: JsonValueView, work: JsonPathWork): ArrayList<JsonValueView> {
        let result = ArrayList<JsonValueView>()
        let cursor = cursorWithWork(root, work)
        while (let Some(matched) <- cursor.next()) { result.add(matched.value) }
        result
    }

    public func first(root: JsonValueView, limits!: JsonPathLimits = JsonPathLimits.defaults): Option<JsonPathMatch> {
        matches(root, limits: limits).next()
    }

    public func first(document: JsonDocument,
        limits!: JsonPathLimits = JsonPathLimits.defaults): Option<JsonPathMatch> {
        first(document.root(), limits: limits)
    }

    private func cursorWithWork(root: JsonValueView, work: JsonPathWork): JsonPathCursor {
        JsonPathCursor(root, segments, work)
    }

    func isSingular(): Bool {
        for (segment in segments) {
            if (segment.descendant || segment.selectors.size != 1) { return false }
            match (segment.selectors[0].kind) {
                case JsonPathSelectorKind.Name | JsonPathSelectorKind.Index => ()
                case _ => return false
            }
        }
        true
    }
}

class JsonPathWork {
    let limits: JsonPathLimits
    let regexBudget: LinearRegexBudget
    private let regexes = HashMap<String, LinearRegex>()
    var visited: Int64 = 0
    var filterSteps: Int64 = 0
    var filterOperations: Int64 = 0
    var emitted: Int64 = 0
    init(limits: JsonPathLimits) {
        this.limits = limits
        this.regexBudget = LinearRegexBudget(limits.maxRegexSteps, "JSONPath regex steps")
    }
    func visit(depth: Int64): Unit {
        visited++
        enforceWorkLimit(visited, limits.maxVisitedNodes, "visited nodes")
        enforceWorkLimit(depth, limits.maxDepth, "depth")
    }
    func filter(): Unit {
        filterSteps++
        enforceWorkLimit(filterSteps, limits.maxFilterSteps, "filter steps")
    }
    func filterOperation(): Unit {
        filterOperations++
        enforceWorkLimit(filterOperations, limits.maxFilterOperations, "filter operations")
    }
    func emit(): Unit {
        emitted++
        enforceWorkLimit(emitted, limits.maxMatches, "matches")
    }
    func regex(pattern: String): Option<LinearRegex> {
        match (regexes.get(pattern)) {
            case Some(compiled) => Some(compiled)
            case None =>
                try {
                    let compiled = LinearRegex.compile(pattern, regexBudget, iRegexp: true)
                    regexes[pattern] = compiled
                    Some(compiled)
                } catch (error: JsonException) {
                    if (error.code == "invalid_regex") { None<LinearRegex> } else { throw error }
                }
        }
    }
}

/**
 * Single-threaded lazy JSONPath result cursor.
 */
public class JsonPathCursor <: Iterator<JsonPathMatch> {
    private let root: JsonValueView
    private let segments: Array<JsonPathSegment>
    private let work: JsonPathWork
    private let frames = ArrayList<JsonPathEvaluationFrame>()
    private var started: Bool = false
    private var rootPending: Bool = false
    private var finished: Bool = false

    init(root: JsonValueView, segments: Array<JsonPathSegment>, work: JsonPathWork) {
        this.root = root
        this.segments = segments
        this.work = work
    }

    public func next(): Option<JsonPathMatch> {
        if (finished) { return None<JsonPathMatch> }
        if (!started) {
            started = true
            if (segments.isEmpty()) {
                rootPending = true
            } else {
                frames.add(JsonPathEvaluationFrame(0, JsonPathMatch(root, "$"),
                    segments, root, work))
            }
        }
        if (rootPending) {
            rootPending = false
            work.emit()
            return Some(JsonPathMatch(root, "$"))
        }
        while (!frames.isEmpty()) {
            let last = frames.size - 1
            let frame = frames[last]
            match (frame.next()) {
                case Some(candidate) =>
                    let nextSegment = frame.segmentIndex + 1
                    if (nextSegment == segments.size) {
                        work.emit()
                        return Some(candidate)
                    }
                    frames.add(JsonPathEvaluationFrame(nextSegment, candidate,
                        segments, root, work))
                case None => frames.remove(at: last)
            }
        }
        finished = true
        None<JsonPathMatch>
    }
}

private class JsonPathEvaluationFrame {
    let segmentIndex: Int64
    private let cursor: JsonPathSegmentCursor

    init(segmentIndex: Int64, candidate: JsonPathMatch,
        segments: Array<JsonPathSegment>, root: JsonValueView, work: JsonPathWork) {
        this.segmentIndex = segmentIndex
        cursor = JsonPathSegmentCursor(segments[segmentIndex], candidate, root, work)
    }

    func next(): Option<JsonPathMatch> { cursor.next() }
}

private class JsonPathTraversalCandidate {
    let matched: JsonPathMatch
    let depth: Int64

    init(matched: JsonPathMatch, depth: Int64) {
        this.matched = matched
        this.depth = depth
    }
}

private class JsonPathSegmentCursor {
    private let segment: JsonPathSegment
    private let root: JsonValueView
    private let work: JsonPathWork
    private let pending = ArrayList<JsonPathTraversalCandidate>()
    private var active: Option<JsonPathTraversalCandidate> = None<JsonPathTraversalCandidate>
    private var selectors: Option<JsonPathSelectorCursor> = None<JsonPathSelectorCursor>

    init(segment: JsonPathSegment, candidate: JsonPathMatch,
        root: JsonValueView, work: JsonPathWork) {
        this.segment = segment
        this.root = root
        this.work = work
        pending.add(JsonPathTraversalCandidate(candidate, 0))
    }

    func next(): Option<JsonPathMatch> {
        while (true) {
            match (selectors) {
                case Some(cursor) => match (cursor.next()) {
                    case Some(matched) => return Some(matched)
                    case None =>
                        selectors = None<JsonPathSelectorCursor>
                        if (segment.descendant) {
                            match (active) {
                                case Some(candidate) => appendChildren(candidate)
                                case None => ()
                            }
                        }
                        active = None<JsonPathTraversalCandidate>
                }
                case None => ()
            }
            if (pending.isEmpty()) { return None<JsonPathMatch> }
            let last = pending.size - 1
            let candidate = pending[last]
            pending.remove(at: last)
            work.visit(candidate.depth)
            active = Some(candidate)
            selectors = Some(JsonPathSelectorCursor(segment, candidate.matched, root, work))
        }
        None<JsonPathMatch>
    }

    private func appendChildren(candidate: JsonPathTraversalCandidate): Unit {
        let value = candidate.matched.value
        var index = value.size() - 1
        match (value.kind()) {
            case JsonKind.Object => while (index >= 0) {
                let name = value.memberName(index)
                pending.add(JsonPathTraversalCandidate(JsonPathMatch(value.memberValue(index),
                    appendNormalizedJsonPathName(candidate.matched.normalizedPath, name)),
                    candidate.depth + 1))
                index--
            }
            case JsonKind.Array => while (index >= 0) {
                pending.add(JsonPathTraversalCandidate(JsonPathMatch(
                    value.element(index).getOrThrow(),
                    "${candidate.matched.normalizedPath}[${index}]"), candidate.depth + 1))
                index--
            }
            case _ => ()
        }
    }
}

private class JsonPathSelectorCursor {
    private let segment: JsonPathSegment
    private let candidate: JsonPathMatch
    private let root: JsonValueView
    private let work: JsonPathWork
    private var selectorIndex: Int64 = 0
    private var childIndex: Int64 = 0
    private var sliceInitialized: Bool = false
    private var sliceIndex: Int64 = 0
    private var sliceEnd: Int64 = 0

    init(segment: JsonPathSegment, candidate: JsonPathMatch,
        root: JsonValueView, work: JsonPathWork) {
        this.segment = segment
        this.candidate = candidate
        this.root = root
        this.work = work
    }

    func next(): Option<JsonPathMatch> {
        while (selectorIndex < segment.selectors.size) {
            let selector = segment.selectors[selectorIndex]
            match (selector.kind) {
                case Name =>
                    advanceSelector()
                    if (candidate.value.kind() == JsonKind.Object) {
                        match (candidate.value.member(selector.name)) {
                            case Some(value) => return Some(JsonPathMatch(value,
                                appendNormalizedJsonPathName(candidate.normalizedPath, selector.name)))
                            case None => ()
                        }
                    }
                case Index =>
                    advanceSelector()
                    if (candidate.value.kind() == JsonKind.Array) {
                        let index = normalizeJsonPathIndex(selector.index, candidate.value.size())
                        if (index >= 0 && index < candidate.value.size()) {
                            return Some(JsonPathMatch(candidate.value.element(index).getOrThrow(),
                                "${candidate.normalizedPath}[${index}]"))
                        }
                    }
                case Wildcard => match (nextChild()) {
                    case Some(child) => return Some(child)
                    case None => advanceSelector()
                }
                case Filter => match (nextChild()) {
                    case Some(child) =>
                        work.filter()
                        if (evaluateJsonPathFilter(selector.filter, child.value, root, work)) {
                            return Some(child)
                        }
                    case None => advanceSelector()
                }
                case Slice => match (nextSlice(selector)) {
                    case Some(child) => return Some(child)
                    case None => advanceSelector()
                }
            }
        }
        None<JsonPathMatch>
    }

    private func nextChild(): Option<JsonPathMatch> {
        let size = candidate.value.size()
        if (childIndex >= size) { return None<JsonPathMatch> }
        let index = childIndex
        childIndex++
        work.visit(0)
        match (candidate.value.kind()) {
            case JsonKind.Object =>
                let name = candidate.value.memberName(index)
                Some(JsonPathMatch(candidate.value.memberValue(index),
                    appendNormalizedJsonPathName(candidate.normalizedPath, name)))
            case JsonKind.Array => Some(JsonPathMatch(candidate.value.element(index).getOrThrow(),
                "${candidate.normalizedPath}[${index}]"))
            case _ => None<JsonPathMatch>
        }
    }

    private func nextSlice(selector: JsonPathSelector): Option<JsonPathMatch> {
        if (candidate.value.kind() != JsonKind.Array || selector.step == 0) {
            return None<JsonPathMatch>
        }
        let size = candidate.value.size()
        if (!sliceInitialized) {
            sliceInitialized = true
            sliceIndex = normalizeJsonPathSliceEndpoint(selector.start, size, selector.step, true)
            sliceEnd = normalizeJsonPathSliceEndpoint(selector.end, size, selector.step, false)
        }
        while ((selector.step > 0 && sliceIndex < sliceEnd && sliceIndex < size) ||
            (selector.step < 0 && sliceIndex > sliceEnd && sliceIndex >= 0)) {
            let index = sliceIndex
            sliceIndex += selector.step
            if (index >= 0 && index < size) {
                work.visit(0)
                return Some(JsonPathMatch(candidate.value.element(index).getOrThrow(),
                    "${candidate.normalizedPath}[${index}]"))
            }
        }
        None<JsonPathMatch>
    }

    private func advanceSelector(): Unit {
        selectorIndex++
        childIndex = 0
        sliceInitialized = false
    }
}

enum JsonPathSelectorKind { Name | Index | Wildcard | Slice | Filter }

class JsonPathSelector {
    let kind: JsonPathSelectorKind
    let name: String
    let index: Int64
    let start: Option<Int64>
    let end: Option<Int64>
    let step: Int64
    let filter: String

    init(kind: JsonPathSelectorKind, name!: String = "", index!: Int64 = 0,
        start!: Option<Int64> = None<Int64>, end!: Option<Int64> = None<Int64>, step!: Int64 = 1,
        filter!: String = "") {
        this.kind = kind; this.name = name; this.index = index
        this.start = start; this.end = end; this.step = step
        this.filter = filter
    }
}

class JsonPathSegment {
    let selectors: Array<JsonPathSelector>
    let descendant: Bool
    init(selectors: Array<JsonPathSelector>, descendant!: Bool = false) {
        this.selectors = selectors; this.descendant = descendant
    }
}


class JsonPathParser {
    let source: String
    let budget: JsonPathFilterBudget
    var offset: Int64 = 0

    init(source: String, budget: JsonPathFilterBudget) {
        this.source = source
        this.budget = budget
    }

    func parse(): JsonPath {
        if (source.isEmpty() || source[0] != b'$') { fail("JSONPath must start with '$'") }
        offset = 1
        let segments = ArrayList<JsonPathSegment>()
        while (offset < source.size) {
            let beforeWhitespace = offset
            skipWhitespace()
            if (offset >= source.size) {
                if (offset != beforeWhitespace) { fail("Trailing whitespace is not allowed") }
                break
            }
            if (source[offset] == b'.') {
                let descendant = offset + 1 < source.size && source[offset + 1] == b'.'
                offset += if (descendant) { 2 } else { 1 }
                if (offset >= source.size) { fail("Expected selector after '.'") }
                if (source[offset] == b'*') {
                    offset++
                    segments.add(JsonPathSegment([JsonPathSelector(JsonPathSelectorKind.Wildcard)], descendant: descendant))
                } else if (source[offset] == b'[') {
                    segments.add(parseBracketSegment(descendant))
                } else {
                    let start = offset
                    while (offset < source.size && source[offset] != b'.' && source[offset] != b'[') { offset++ }
                    if (start == offset) { fail("Expected member name") }
                    validateJsonPathShorthandName(source[start..offset], start)
                    segments.add(JsonPathSegment([
                        JsonPathSelector(JsonPathSelectorKind.Name, name: source[start..offset])
                    ], descendant: descendant))
                }
            } else if (source[offset] == b'[') {
                segments.add(parseBracketSegment(false))
            } else {
                fail("Expected '.' or '['")
            }
        }
        JsonPath(source, segments.toArray())
    }

    private func parseBracketSegment(descendant: Bool): JsonPathSegment {
        offset++
        let selectors = ArrayList<JsonPathSelector>()
        skipWhitespace()
        while (offset < source.size && source[offset] != b']') {
            selectors.add(parseSelector())
            skipWhitespace()
            if (offset < source.size && source[offset] == b',') {
                offset++; skipWhitespace()
                if (offset >= source.size || source[offset] == b']') { fail("Trailing comma in child segment") }
            } else { break }
        }
        if (offset >= source.size || source[offset] != b']') { fail("Unterminated bracket selector") }
        if (selectors.isEmpty()) { fail("A child segment must contain at least one selector") }
        offset++
        JsonPathSegment(selectors.toArray(), descendant: descendant)
    }

    private func parseSelector(): JsonPathSelector {
        if (source[offset] == b'?') {
            offset++
            let start = offset
            var parentheses: Int64 = 0
            var brackets: Int64 = 0
            var quoteByte: Byte = 0
            var escaped = false
            while (offset < source.size) {
                let current = source[offset]
                if (quoteByte != 0) {
                    if (!escaped && current == quoteByte) { quoteByte = 0 }
                    if (!escaped && current == b'\\') { escaped = true } else { escaped = false }
                } else if (current == b'\'' || current == b'\"') { quoteByte = current
                } else if (current == b'(') { parentheses++
                } else if (current == b')') { parentheses--
                } else if (current == b'[') { brackets++
                } else if (current == b']' && brackets > 0) { brackets--
                } else if (parentheses == 0 && brackets == 0 && (current == b',' || current == b']')) { break }
                offset++
            }
            let expression = trimJsonPathWhitespace(source[start..offset])
            if (expression.isEmpty()) { failAt("Filter selector requires an expression", start) }
            validateJsonPathFilterSyntax(expression, source, start, budget)
            return JsonPathSelector(JsonPathSelectorKind.Filter, filter: expression)
        }
        if (source[offset] == b'*') { offset++; return JsonPathSelector(JsonPathSelectorKind.Wildcard) }
        if (source[offset] == b'\'' || source[offset] == b'\"') {
            return JsonPathSelector(JsonPathSelectorKind.Name, name: parseQuotedName())
        }
        let start = offset
        while (offset < source.size && source[offset] != b',' && source[offset] != b']') { offset++ }
        let raw = trimJsonPathWhitespace(source[start..offset])
        if (raw.contains(":")) { return parseSlice(raw, start) }
        try {
            JsonPathSelector(JsonPathSelectorKind.Index, index: parseJsonPathInteger(raw, start))
        } catch (_: Exception) {
            failAt("Invalid array index selector '${raw}'", start)
        }
    }

    private func parseQuotedName(): String {
        let quoteByte = source[offset]
        let start = offset
        offset++
        var escaped = false
        while (offset < source.size) {
            let current = source[offset]
            if (!escaped && current == quoteByte) { offset++; return decodeJsonPathQuoted(source[start..offset]) }
            if (!escaped && current == b'\\') { escaped = true } else { escaped = false }
            offset++
        }
        failAt("Unterminated quoted member name", start)
    }

    private func parseSlice(raw: String, startOffset: Int64): JsonPathSelector {
        let pieces = splitJsonPathText(raw, b':')
        if (pieces.size < 2 || pieces.size > 3) { failAt("Invalid array slice", startOffset) }
        let start = parseOptionalInteger(pieces[0], startOffset)
        let end = parseOptionalInteger(pieces[1], startOffset)
        let step = if (pieces.size == 3) {
            match (parseOptionalInteger(pieces[2], startOffset)) { case Some(value) => value; case None => 1 }
        } else { 1 }
        JsonPathSelector(JsonPathSelectorKind.Slice, start: start, end: end, step: step)
    }

    private func parseOptionalInteger(raw: String, position: Int64): Option<Int64> {
        let text = trimJsonPathWhitespace(raw)
        if (text.isEmpty()) { return None<Int64> }
        try { Some(parseJsonPathInteger(text, position)) }
        catch (_: Exception) { failAt("Invalid slice integer '${text}'", position) }
    }

    private func skipWhitespace(): Unit {
        while (offset < source.size && (source[offset] == b' ' || source[offset] == b'\t' ||
            source[offset] == b'\r' || source[offset] == b'\n')) { offset++ }
    }

    private func fail(message: String): Nothing { throw jsonPathError(message, source, expressionOffset: offset) }
    private func failAt(message: String, position: Int64): Nothing {
        throw jsonPathError(message, source, expressionOffset: position)
    }
}

private let JSON_PATH_EXACT_INTEGER_MAX: Int64 = 9007199254740991

private func parseJsonPathInteger(text: String, position: Int64): Int64 {
    if (text.isEmpty() || text.startsWith("+") || text == "-0" ||
        (text.size > 1 && text.startsWith("0")) || (text.size > 2 && text.startsWith("-0"))) {
        throw jsonPathError("Invalid integer '${text}'", text, expressionOffset: position)
    }
    let value = Int64.parse(text)
    if (value < -JSON_PATH_EXACT_INTEGER_MAX || value > JSON_PATH_EXACT_INTEGER_MAX) {
        throw jsonPathError("Integer '${text}' exceeds the interoperable exact range", text,
            expressionOffset: position)
    }
    value
}



private func normalizeJsonPathIndex(index: Int64, size: Int64): Int64 { if (index < 0) { size + index } else { index } }
private func normalizeJsonPathSliceEndpoint(value: Option<Int64>, size: Int64,
    step: Int64, isStart: Bool): Int64 {
    match (value) {
        case None => if (step > 0) { if (isStart) { 0 } else { size } }
            else { if (isStart) { size - 1 } else { -1 } }
        case Some(raw) =>
            let resolved = if (raw < 0) { size + raw } else { raw }
            if (step > 0) {
                if (resolved < 0) { 0 } else if (resolved > size) { size } else { resolved }
            } else {
                if (resolved < 0) { -1 } else if (resolved >= size) { size - 1 } else { resolved }
            }
    }
}

private func appendNormalizedJsonPathName(base: String, name: String): String {
    "${base}[${jsonPathSingleQuotedName(name)}]"
}

private func jsonPathSingleQuotedName(name: String): String {
    let builder = StringBuilder("'")
    for (rune in name.toRuneArray()) {
        match (rune) {
            case r'\'' => builder.append("\\'")
            case r'\\' => builder.append("\\\\")
            case r'\b' => builder.append("\\b")
            case r'\u{000C}' => builder.append("\\f")
            case r'\n' => builder.append("\\n")
            case r'\r' => builder.append("\\r")
            case r'\t' => builder.append("\\t")
            case _ => builder.append(rune)
        }
    }
    builder.append("'")
    builder.toString()
}

func decodeJsonPathQuoted(raw: String): String {
    if (raw[0] == b'\"') { return JsonNode.parse(raw).asString() }
    let builder = StringBuilder("\"")
    var index: Int64 = 1
    while (index < raw.size - 1) {
        if (raw[index] == b'\"') { builder.append("\\\"") }
        else if (raw[index] == b'\\' && index + 1 < raw.size - 1 && raw[index + 1] == b'\'') {
            builder.append("'"); index++
        } else { builder.append(raw[index..index + 1]) }
        index++
    }
    builder.append("\"")
    JsonNode.parse(builder.toString()).asString()
}

func trimJsonPathWhitespace(text: String): String {
    var start: Int64 = 0; var end = text.size
    while (start < end && (text[start] == b' ' || text[start] == b'\t' || text[start] == b'\r' || text[start] == b'\n')) { start++ }
    while (end > start && (text[end - 1] == b' ' || text[end - 1] == b'\t' || text[end - 1] == b'\r' || text[end - 1] == b'\n')) { end-- }
    text[start..end]
}


private func splitJsonPathText(text: String, separator: Byte): ArrayList<String> {
    let result = ArrayList<String>(); var start: Int64 = 0; var index: Int64 = 0
    while (index < text.size) { if (text[index] == separator) { result.add(text[start..index]); start = index + 1 }; index++ }
    result.add(text[start..text.size]); result
}


private func validateJsonPathShorthandName(name: String, position: Int64): Unit {
    if (name.isEmpty()) { throw jsonPathError("Empty shorthand member name", name, expressionOffset: position) }
    let first = name[0]
    if (!((first >= b'A' && first <= b'Z') || (first >= b'a' && first <= b'z') || first == b'_' || first >= 0x80u8)) {
        throw jsonPathError("Invalid shorthand member name '${name}'", name, expressionOffset: position)
    }
    for (byte in unsafe { name.rawData() }) {
        if (!((byte >= b'A' && byte <= b'Z') || (byte >= b'a' && byte <= b'z') ||
            (byte >= b'0' && byte <= b'9') || byte == b'_' || byte >= 0x80u8)) {
            throw jsonPathError("Invalid shorthand member name '${name}'", name, expressionOffset: position)
        }
    }
}

