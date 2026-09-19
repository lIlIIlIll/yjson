#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'usage: %s PACKAGE_DIR\n' "$0" >&2
    exit 2
fi

package_dir=$1
if [[ ! -d "$package_dir" ]]; then
    printf 'error: package directory not found: %s\n' "$package_dir" >&2
    exit 2
fi

cd "$package_dir"
cjpm build

binary=target/release/bin/main
if [[ ! -x "$binary" ]]; then
    printf 'error: expected executable not found: %s/%s\n' "$package_dir" "$binary" >&2
    exit 2
fi

# cjpm places dynamic dependencies beside the executable package, not in bin.
shopt -s nullglob
library_path=
for directory in "$PWD"/target/release/*; do
    [[ -d "$directory" ]] || continue
    libraries=("$directory"/*.so "$directory"/*.dylib)
    if (( ${#libraries[@]} != 0 )); then
        library_path+="${library_path:+:}$directory"
    fi
done
if [[ -n "$library_path" ]]; then
    export LD_LIBRARY_PATH="$library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export DYLD_LIBRARY_PATH="$library_path${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
fi

exec "$binary"
