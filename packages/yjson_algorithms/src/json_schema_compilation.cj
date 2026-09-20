package yjson_algorithms

import yjson.*

import std.collection.*

func compileJsonSchemaResourceGraph(root: JsonNode,
    resolver: Option<UriResolver>, limits: JsonSchemaLimits): HashMap<String, JsonNode> {
    let resources = HashMap<String, JsonNode>()
    let pending = ArrayList<String>()
    let scheduled = HashSet<String>()
    collectJsonSchemaResourceDependencies(root, "", root, resources, pending, scheduled)
    var cursor: Int64 = 0
    var resolutions: Int64 = 0
    while (cursor < pending.size) {
        let uri = pending[cursor]
        cursor++
        if (jsonSchemaResourceIsAvailable(root, resources, uri)) { continue }
        match (resolver) {
            case Some(source) =>
                resolutions++
                enforceWorkLimit(resolutions, limits.maxRefResolutions,
                    "compile-time reference resolutions")
                match (source.resolve(uri)) {
                    case Some(resolved) =>
                        let detached = resolved.deepCopy()
                        validateJsonSchemaDocument(detached, "#")
                        resources[uri] = detached
                        indexJsonSchemaCompiledResources(detached, uri, resources)
                        collectJsonSchemaResourceDependencies(detached, uri, root,
                            resources, pending, scheduled)
                    case None => ()
                }
            case None => ()
        }
    }
    resources
}

private func collectJsonSchemaResourceDependencies(node: JsonNode,
    inheritedBase: String, root: JsonNode, resources: HashMap<String, JsonNode>,
    pending: ArrayList<String>, scheduled: HashSet<String>): Unit {
    match (node) {
        case objectValue: JsonObject =>
            var base = inheritedBase
            match (objectValue.get("$id")) {
                case Some(idValue) => base = stripJsonSchemaFragment(
                    resolveJsonSchemaUri(inheritedBase, idValue.asString()))
                case None => ()
            }
            for (keyword in ["$ref", "$dynamicRef", "$schema"]) {
                match (objectValue.get(keyword)) {
                    case Some(referenceValue) => if (referenceValue.kind() == JsonKind.String) {
                        let absolute = resolveJsonSchemaUri(base, referenceValue.asString())
                        let uri = stripJsonSchemaFragment(absolute)
                        if (!uri.isEmpty() && uri != stripJsonSchemaFragment(base) &&
                            !jsonSchemaKnownMetaResource(uri) &&
                            !jsonSchemaResourceIsAvailable(root, resources, uri) &&
                            !scheduled.contains(uri)) {
                            scheduled.add(uri)
                            pending.add(uri)
                        }
                    }
                    case None => ()
                }
            }
            for (child in jsonSchemaChildSchemas(objectValue)) {
                collectJsonSchemaResourceDependencies(child, base, root,
                    resources, pending, scheduled)
            }
        case _ => ()
    }
}

private func indexJsonSchemaCompiledResources(node: JsonNode,
    inheritedBase: String, resources: HashMap<String, JsonNode>): Unit {
    match (node) {
        case objectValue: JsonObject =>
            var base = inheritedBase
            match (objectValue.get("$id")) {
                case Some(idValue) =>
                    base = stripJsonSchemaFragment(resolveJsonSchemaUri(
                        inheritedBase, idValue.asString()))
                    if (!base.isEmpty() && resources.get(base).isNone()) {
                        resources[base] = node
                    }
                case None => ()
            }
            for (child in jsonSchemaChildSchemas(objectValue)) {
                indexJsonSchemaCompiledResources(child, base, resources)
            }
        case _ => ()
    }
}

private func jsonSchemaResourceIsAvailable(root: JsonNode,
    resources: HashMap<String, JsonNode>, uri: String): Bool {
    if (resources.get(uri).isSome()) { return true }
    findJsonSchemaResource(root, "", uri).isSome()
}

private func jsonSchemaKnownMetaResource(uri: String): Bool {
    uri == "https://json-schema.org/draft/2020-12/schema"
}

func jsonSchemaChildSchemas(objectValue: JsonObject): ArrayList<JsonNode> {
    let result = ArrayList<JsonNode>()
    for (keyword in ["additionalProperties", "contains", "contentSchema", "else", "if", "items",
        "not", "propertyNames", "then", "unevaluatedItems", "unevaluatedProperties"]) {
        match (objectValue.get(keyword)) { case Some(child) => result.add(child); case None => () }
    }
    for (keyword in ["allOf", "anyOf", "oneOf", "prefixItems"]) {
        match (objectValue.get(keyword)) {
            case Some(children) =>
                let array = children.asArray()
                for (index in 0..array.size()) { result.add(array[index]) }
            case None => ()
        }
    }
    for (keyword in ["$defs", "definitions", "dependentSchemas", "patternProperties", "properties"]) {
        match (objectValue.get(keyword)) {
            case Some(children) =>
                let object = children.asObject()
                for (index in 0..object.size()) { result.add(object.valueAt(index)) }
            case None => ()
        }
    }
    result
}

func compileJsonSchemaRegexes(document: JsonNode,
    resources: HashMap<String, JsonNode>, limits: JsonSchemaLimits): HashMap<String, LinearRegex> {
    let result = HashMap<String, LinearRegex>()
    let budget = LinearRegexBudget(limits.maxRegexSteps, "JSON Schema regex compilation steps")
    collectJsonSchemaRegexes(document, result, budget)
    for ((_, resource) in resources) { collectJsonSchemaRegexes(resource, result, budget) }
    result
}

private func collectJsonSchemaRegexes(node: JsonNode,
    result: HashMap<String, LinearRegex>, budget: LinearRegexBudget): Unit {
    match (node) {
        case objectValue: JsonObject =>
            match (objectValue.get("pattern")) {
                case Some(patternValue) => compileJsonSchemaRegex(patternValue.asString(), result, budget)
                case None => ()
            }
            match (objectValue.get("patternProperties")) {
                case Some(patternProperties) =>
                    let patterns = patternProperties.asObject()
                    for (index in 0..patterns.size()) {
                        compileJsonSchemaRegex(patterns.nameAt(index), result, budget)
                    }
                case None => ()
            }
            for (child in jsonSchemaChildSchemas(objectValue)) {
                collectJsonSchemaRegexes(child, result, budget)
            }
        case _ => ()
    }
}

private func compileJsonSchemaRegex(pattern: String,
    result: HashMap<String, LinearRegex>, budget: LinearRegexBudget): Unit {
    if (result.get(pattern).isNone()) { result[pattern] = LinearRegex.compile(pattern, budget) }
}
