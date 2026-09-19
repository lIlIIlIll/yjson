package yjson_algorithms

import yjson.*

import std.collection.*
import std.math.numeric.*

/**
 * Compile-time budget shared by every filter expression validated while
 * parsing one JSONPath (including nested queries inside function
 * arguments). Counts are per whole expression, matching the semantics of
 * JsonPathLimits.maxFilter* fields.
 */
class JsonPathFilterBudget {
    let maxBytes: Int64
    let maxOperators: Int64
    let maxDepth: Int64
    var operators: Int64 = 0
    var depth: Int64 = 0

    init(limits: JsonPathLimits) {
        maxBytes = limits.maxFilterExpressionBytes
        maxOperators = limits.maxFilterOperators
        maxDepth = limits.maxFilterDepth
    }

    func enterExpression(text: String, source: String, position: Int64): Unit {
        if (maxBytes > 0 && text.size > maxBytes) {
            throw jsonPathError(
                "JSONPath filter expression exceeds the ${maxBytes}-byte parse budget (got ${text.size})",
                source, expressionOffset: position)
        }
    }

    func enterDepth(source: String, position: Int64): Unit {
        depth++
        if (maxDepth > 0 && depth > maxDepth) {
            throw jsonPathError(
                "JSONPath filter expression exceeds the ${maxDepth}-level parse depth budget",
                source, expressionOffset: position)
        }
    }

    func exitDepth(): Unit { depth-- }

    func consumeOperator(source: String, position: Int64): Unit {
        operators++
        if (maxOperators > 0 && operators > maxOperators) {
            throw jsonPathError(
                "JSONPath filter expression exceeds the ${maxOperators}-operator parse budget",
                source, expressionOffset: position)
        }
    }
}

func validateJsonPathFilterSyntax(expression: String, source: String,
    position: Int64, budget: JsonPathFilterBudget): Unit {
    budget.enterExpression(expression, source, position)
    budget.enterDepth(source, position)
    let text = stripJsonPathParentheses(trimJsonPathWhitespace(expression))
    match (findJsonPathTopLevelOperator(text, "||")) {
        case Some(index) =>
            budget.consumeOperator(source, position)
            validateJsonPathLogicalOperand(text[0..index], source, position, budget)
            validateJsonPathLogicalOperand(text[index + 2..text.size], source, position + index + 2, budget)
            budget.exitDepth()
            return
        case None => ()
    }
    match (findJsonPathTopLevelOperator(text, "&&")) {
        case Some(index) =>
            budget.consumeOperator(source, position)
            validateJsonPathLogicalOperand(text[0..index], source, position, budget)
            validateJsonPathLogicalOperand(text[index + 2..text.size], source, position + index + 2, budget)
            budget.exitDepth()
            return
        case None => ()
    }
    if (text.startsWith("!")) {
        budget.consumeOperator(source, position)
        validateJsonPathLogicalOperand(text[1..text.size], source, position + 1, budget)
        budget.exitDepth()
        return
    }
    for (op in ["==", "!=", "<=", ">=", "<", ">"]) {
        match (findJsonPathTopLevelOperator(text, op)) {
            case Some(index) =>
                validateJsonPathComparable(text[0..index], source, position, budget)
                validateJsonPathComparable(text[index + op.size..text.size], source, position + index + op.size, budget)
                budget.exitDepth()
                return
            case None => ()
        }
    }
    validateJsonPathLogicalAtom(text, source, position, budget)
    budget.exitDepth()
}

private func validateJsonPathLogicalOperand(expression: String, source: String,
    position: Int64, budget: JsonPathFilterBudget): Unit {
    validateJsonPathFilterSyntax(expression, source, position, budget)
}

private func validateJsonPathLogicalAtom(text: String, source: String,
    position: Int64, budget: JsonPathFilterBudget): Unit {
    let value = trimJsonPathWhitespace(text)
    if (value.startsWith("@") || value.startsWith("$")) {
        // F2: a logical atom is an existence test over a query; the query
        // itself must be syntactically valid at parse time, not only when
        // execution happens to evaluate it.
        validateJsonPathQuerySyntax(value, source, position, budget)
        return
    }
    if (value.startsWith("match(") || value.startsWith("search(")) {
        validateJsonPathFunctionCall(value, source, position, true, budget)
        return
    }
    throw jsonPathError("Filter literals and value-returning functions must be compared", source,
        expressionOffset: position)
}

private func validateJsonPathComparable(text: String, source: String,
    position: Int64, budget: JsonPathFilterBudget): Unit {
    let value = trimJsonPathWhitespace(text)
    if (value.startsWith("@") || value.startsWith("$")) {
        if (!jsonPathQueryIsSingular(value, budget)) {
            throw jsonPathError("Comparison queries must be singular", source, expressionOffset: position)
        }
        return
    }
    for (name in ["length", "count", "value"]) {
        if (value.startsWith(name + "(")) {
            validateJsonPathFunctionCall(value, source, position, false, budget)
            return
        }
    }
    if (value.startsWith("match(") || value.startsWith("search(")) {
        throw jsonPathError("Logical function results cannot be compared", source, expressionOffset: position)
    }
    try {
        let _ = if (value.startsWith("'")) { JsonNode.string(decodeJsonPathQuoted(value)) }
            else { JsonNode.parse(value, config: JsonReadOptions()) }
    } catch (_: Exception) {
        throw jsonPathError("Invalid comparison literal '${value}'", source, expressionOffset: position)
    }
}

private func validateJsonPathFunctionCall(text: String, source: String,
    position: Int64, logical: Bool, budget: JsonPathFilterBudget): Unit {
    let open = text.indexOf("(").getOrThrow({ => jsonPathError("Invalid function", source,
        expressionOffset: position) })
    if (!text.endsWith(")")) { throw jsonPathError("Unterminated function", source, expressionOffset: position) }
    let name = text[0..open]
    let args = splitJsonPathArguments(text[open + 1..text.size - 1])
    let expected = if (name == "match" || name == "search") { 2 } else { 1 }
    if (args.size != expected || (args.size == 1 && args[0].isEmpty())) {
        throw jsonPathError("${name}() expects ${expected} argument(s)", source, expressionOffset: position)
    }
    if (logical != (name == "match" || name == "search")) {
        throw jsonPathError("Function ${name} has the wrong result type here", source, expressionOffset: position)
    }
    if (name == "count") {
        let argument = trimJsonPathWhitespace(args[0])
        if (!(argument.startsWith("@") || argument.startsWith("$"))) {
            throw jsonPathError("count() requires a query argument", source, expressionOffset: position)
        }
        // F2: function arguments carrying queries must be syntactically
        // valid at parse time as well.
        validateJsonPathQuerySyntax(argument, source, position, budget)
    }
    if (name == "length") {
        let argument = trimJsonPathWhitespace(args[0])
        if ((argument.startsWith("@") || argument.startsWith("$"))) {
            if (!jsonPathQueryIsSingular(argument, budget)) {
                throw jsonPathError("length() query arguments must be singular", source, expressionOffset: position)
            }
        }
    }
    if (name == "value") {
        let argument = trimJsonPathWhitespace(args[0])
        if (!(argument.startsWith("@") || argument.startsWith("$"))) {
            throw jsonPathError("value() requires a query argument", source, expressionOffset: position)
        }
        validateJsonPathQuerySyntax(argument, source, position, budget)
    }
    if (name == "match" || name == "search") {
        let argument = trimJsonPathWhitespace(args[0])
        if (argument.startsWith("@") || argument.startsWith("$")) {
            validateJsonPathQuerySyntax(argument, source, position, budget)
        }
    }
}

private func validateJsonPathQuerySyntax(text: String, source: String,
    position: Int64, budget: JsonPathFilterBudget): Unit {
    let normalized = removeJsonPathQueryWhitespace(text)
    let rootQuery = if (normalized.startsWith("@")) { "$" + normalized[1..normalized.size] } else { normalized }
    JsonPathParser(rootQuery, budget).parse()
}

private func jsonPathQueryIsSingular(text: String, budget: JsonPathFilterBudget): Bool {
    let normalized = removeJsonPathQueryWhitespace(text)
    let rootQuery = if (normalized.startsWith("@")) { "$" + normalized[1..normalized.size] } else { normalized }
    JsonPathParser(rootQuery, budget).parse().isSingular()
}

private func removeJsonPathQueryWhitespace(text: String): String {
    let builder = StringBuilder()
    var quoteByte: Byte = 0
    var escaped = false
    for (index in 0..text.size) {
        let current = text[index]
        if (quoteByte != 0) {
            builder.append(text[index..index + 1])
            if (!escaped && current == quoteByte) { quoteByte = 0 }
            if (!escaped && current == b'\\') { escaped = true } else { escaped = false }
        } else if (current == b'\'' || current == b'\"') {
            quoteByte = current
            builder.append(text[index..index + 1])
        } else if (!(current == b' ' || current == b'\t' || current == b'\r' || current == b'\n')) {
            builder.append(text[index..index + 1])
        }
    }
    builder.toString()
}

func evaluateJsonPathFilter(expression: String, current: JsonValueView, root: JsonValueView,
    work: JsonPathWork): Bool {
    // F1: every logical unit of work (operator, comparison, or atom) is
    // accounted against the run-time operation budget, independent of the
    // per-candidate-node filter step counter.
    work.filterOperation()
    let text = stripJsonPathParentheses(trimJsonPathWhitespace(expression))
    match (findJsonPathTopLevelOperator(text, "||")) {
        case Some(index) => return evaluateJsonPathFilter(text[0..index], current, root, work) ||
            evaluateJsonPathFilter(text[index + 2..text.size], current, root, work)
        case None => ()
    }
    match (findJsonPathTopLevelOperator(text, "&&")) {
        case Some(index) => return evaluateJsonPathFilter(text[0..index], current, root, work) &&
            evaluateJsonPathFilter(text[index + 2..text.size], current, root, work)
        case None => ()
    }
    if (text.startsWith("!")) {
        return !evaluateJsonPathFilter(text[1..text.size], current, root, work)
    }
    for (op in ["==", "!=", "<=", ">=", "<", ">"]) {
        match (findJsonPathTopLevelOperator(text, op)) {
            case Some(index) =>
                let left = evaluateJsonPathOperand(text[0..index], current, root, work)
                let right = evaluateJsonPathOperand(text[index + op.size..text.size], current, root, work)
                return compareJsonPathOperands(left, right, op)
            case None => ()
        }
    }
    let value = evaluateJsonPathOperand(text, current, root, work)
    if (text.startsWith("match(") || text.startsWith("search(")) {
        return value.size == 1 && value[0].asBool()
    }
    !value.isEmpty()
}

private func evaluateJsonPathOperand(expression: String, current: JsonValueView,
    root: JsonValueView, work: JsonPathWork): ArrayList<JsonValueView> {
    let text = trimJsonPathWhitespace(expression)
    if (text.startsWith("@") || text.startsWith("$")) {
        let base = if (text.startsWith("@")) { current } else { root }
        let pathText = "$" + removeJsonPathQueryWhitespace(text[1..text.size])
        return JsonPath.parse(pathText, limits: work.limits).collectValuesWithWork(base, work)
    }
    for (functionName in ["length", "count", "value", "match", "search"]) {
        if (text.startsWith(functionName + "(") && text.endsWith(")")) {
            return evaluateJsonPathFunction(functionName,
                text[functionName.size + 1..text.size - 1], current, root, work)
        }
    }
    let result = ArrayList<JsonValueView>()
    try {
        if (text.startsWith("'")) { result.add(JsonNode.string(decodeJsonPathQuoted(text))) }
        else { result.add(JsonNode.parse(text, config: JsonReadOptions())) }
    } catch (_: Exception) {
        throw jsonPathError("Invalid filter operand '${text}'", expression)
    }
    result
}

private func evaluateJsonPathFunction(name: String, arguments: String,
    current: JsonValueView, root: JsonValueView, work: JsonPathWork): ArrayList<JsonValueView> {
    let result = ArrayList<JsonValueView>()
    let args = splitJsonPathArguments(arguments)
    match (name) {
        case "length" =>
            if (args.size != 1) { throw jsonPathError("length() expects one argument", arguments) }
            let values = evaluateJsonPathOperand(args[0], current, root, work)
            if (values.size == 1) {
                match (values[0].kind()) {
                    case JsonKind.String => result.add(JsonNode.int64(values[0].asString().toRuneArray().size))
                    case JsonKind.Array | JsonKind.Object => result.add(JsonNode.int64(values[0].size()))
                    case _ => ()
                }
            }
        case "count" =>
            if (args.size != 1) { throw jsonPathError("count() expects one argument", arguments) }
            result.add(JsonNode.int64(evaluateJsonPathOperand(args[0], current, root, work).size))
        case "value" =>
            if (args.size != 1) { throw jsonPathError("value() expects one argument", arguments) }
            let values = evaluateJsonPathOperand(args[0], current, root, work)
            if (values.size == 1) { result.add(values[0]) }
        case "match" | "search" =>
            if (args.size != 2) { throw jsonPathError("${name}() expects two arguments", arguments) }
            let values = evaluateJsonPathOperand(args[0], current, root, work)
            let patterns = evaluateJsonPathOperand(args[1], current, root, work)
            var matched = false
            if (values.size == 1 && patterns.size == 1) {
                if (values[0].kind() == JsonKind.String && patterns[0].kind() == JsonKind.String) {
                    matched = jsonPathRegexMatches(patterns[0].asString(), values[0].asString(),
                        name == "match", work)
                }
            }
            result.add(JsonNode.boolean(matched))
        case _ => ()
    }
    result
}

private func jsonPathRegexMatches(pattern: String, value: String,
    full: Bool, work: JsonPathWork): Bool {
    match (work.regex(pattern)) {
        case Some(regex) => regex.find(value, work.regexBudget, full: full)
        case None => false
    }
}

private func compareJsonPathOperands(left: ArrayList<JsonValueView>, right: ArrayList<JsonValueView>, op: String): Bool {
    if (left.size != 1 || right.size != 1) {
        if (left.isEmpty() && right.isEmpty()) { return op == "==" || op == "<=" || op == ">=" }
        return op == "!="
    }
    let a = left[0]; let b = right[0]
    if (op == "==") { return jsonNodesEquivalent(a, b) }
    if (op == "!=") { return !jsonNodesEquivalent(a, b) }
    if (jsonNodesEquivalent(a, b)) { return op == "<=" || op == ">=" }
    match ((jsonNodeAsDecimal(a), jsonNodeAsDecimal(b))) {
        case (Some(x), Some(y)) => return compareJsonPathOrdering(x.compare(y), op)
        case _ => ()
    }
    if (a.kind() != JsonKind.String || b.kind() != JsonKind.String) { return false }
    let x = a.asString()
    let y = b.asString()
    if (op == "<") { x < y }
    else if (op == ">") { x > y }
    else if (op == "<=") { x <= y }
    else { x >= y }
}

private func compareJsonPathOrdering(ordering: Ordering, op: String): Bool {
    match (ordering) {
        case Ordering.LT => op == "<" || op == "<="
        case Ordering.EQ => op == "<=" || op == ">="
        case Ordering.GT => op == ">" || op == ">="
    }
}

private func findJsonPathTopLevelOperator(text: String, op: String): Option<Int64> {
    var depth: Int64 = 0; var quoteByte: Byte = 0; var escaped = false; var index: Int64 = 0
    while (index + op.size <= text.size) {
        let current = text[index]
        if (quoteByte != 0) {
            if (!escaped && current == quoteByte) { quoteByte = 0 }
            if (!escaped && current == b'\\') { escaped = true } else { escaped = false }
        } else if (current == b'\'' || current == b'\"') { quoteByte = current
        } else if (current == b'(' || current == b'[') { depth++
        } else if (current == b')' || current == b']') { depth--
        } else if (depth == 0 && text[index..index + op.size] == op) { return Some(index) }
        index++
    }
    None<Int64>
}

private func stripJsonPathParentheses(text: String): String {
    var result = text
    while (result.size >= 2 && result.startsWith("(") && result.endsWith(")") &&
        jsonPathParenthesesEncloseWhole(result)) { result = trimJsonPathWhitespace(result[1..result.size - 1]) }
    result
}

private func jsonPathParenthesesEncloseWhole(text: String): Bool {
    var depth: Int64 = 0; var quoteByte: Byte = 0; var escaped = false
    for (index in 0..text.size) {
        let current = text[index]
        if (quoteByte != 0) {
            if (!escaped && current == quoteByte) { quoteByte = 0 }
            if (!escaped && current == b'\\') { escaped = true } else { escaped = false }
        } else if (current == b'\'' || current == b'\"') { quoteByte = current
        } else if (current == b'(') { depth++
        } else if (current == b')') { depth--; if (depth == 0 && index != text.size - 1) { return false } }
    }
    depth == 0
}

private func splitJsonPathArguments(text: String): ArrayList<String> {
    let result = ArrayList<String>(); var depth: Int64 = 0; var quoteByte: Byte = 0
    var escaped = false; var start: Int64 = 0; var index: Int64 = 0
    while (index < text.size) {
        let current = text[index]
        if (quoteByte != 0) {
            if (!escaped && current == quoteByte) { quoteByte = 0 }
            if (!escaped && current == b'\\') { escaped = true } else { escaped = false }
        } else if (current == b'\'' || current == b'\"') { quoteByte = current
        } else if (current == b'(' || current == b'[') { depth++
        } else if (current == b')' || current == b']') { depth--
        } else if (current == b',' && depth == 0) { result.add(trimJsonPathWhitespace(text[start..index])); start = index + 1 }
        index++
    }
    result.add(trimJsonPathWhitespace(text[start..text.size])); result
}
