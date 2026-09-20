package yjson_algorithms

import yjson.*

import std.math.numeric.*

func jsonNodesEquivalent(left: JsonValueView, right: JsonValueView): Bool {
    if (left.kind() != right.kind()) { return false }
    match (left.kind()) {
        case JsonKind.Null => true
        case JsonKind.Boolean => left.asBool() == right.asBool()
        case JsonKind.String => left.asString() == right.asString()
        case JsonKind.Number => jsonNumbersEquivalent(left, right)
        case JsonKind.Array =>
            if (left.size() != right.size()) { return false }
            for (index in 0..left.size()) {
                if (!jsonNodesEquivalent(left.element(index).getOrThrow(),
                    right.element(index).getOrThrow())) { return false }
            }
            true
        case JsonKind.Object =>
            if (left.size() != right.size()) { return false }
            for (index in 0..left.size()) {
                let key = left.memberName(index)
                match (right.member(key)) {
                    case Some(other) => if (!jsonNodesEquivalent(left.memberValue(index), other)) { return false }
                    case None => return false
                }
            }
            true
    }
}

private func jsonNumbersEquivalent(left: JsonValueView, right: JsonValueView): Bool {
    match ((jsonNodeAsDecimal(left), jsonNodeAsDecimal(right))) {
        case (Some(a), Some(b)) => a == b
        case _ => false
    }
}

func jsonNodeAsDecimal(value: JsonValueView): Option<Decimal> {
    try {
        if (value.kind() == JsonKind.Number) { Some(Decimal.parse(value.asNumberText())) }
        else { None<Decimal> }
    } catch (_: Exception) {
        None<Decimal>
    }
}
