#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
package="$repo/packages/runtime_freeze_contract"

for scenario in pure-late generated-reader-late version-mismatch native-conflict activation-failure concurrent-race reentrant-use initialization-wait primitives-failure primitives-failure-wait; do
    printf 'runtime freeze scenario: %s\n' "$scenario"
    status=0
    output=$(cd "$package" && cjpm run -- "$scenario" 2>&1) || status=$?
    printf '%s\n' "$output"
    if [[ "$status" -ne 0 ]]; then
        exit "$status"
    fi
    grep -F "runtime freeze contract passed: $scenario" <<<"$output" >/dev/null
done

printf 'runtime freeze contract checks passed\n'
