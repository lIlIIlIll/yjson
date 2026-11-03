#!/usr/bin/env python3
"""Validate recorded compiler invocations from clean paired builds."""
import hashlib
import json
from pathlib import Path
import re
import sys

output = Path(sys.argv[1])
names = sys.argv[2:]
assert len(names) == 2
receipt = {'status': 'PASS', 'instrumentation': 'strace execve on cjpm build only; never on timed benchmark processes', 'variants': {}}
for name in names:
    trace_path = output / f'compiler-{name}.execve'
    trace = trace_path.read_text()
    assert '--fno-chir-function-inlining' not in trace
    calls = []
    for line in trace.splitlines():
        match = re.search(r'execve\(("(?:\\.|[^"\\])*")\s*,\s*(\[.*?\])', line)
        if not match:
            continue
        try:
            executable, argv = json.loads(match[1]), json.loads(match[2])
        except json.JSONDecodeError:
            continue
        if Path(executable).name not in ('cjc', 'cjc-frontend') or '= -1 ' in line:
            continue
        if '--scan-dependency' in argv:
            role = 'dependency scan'
        elif any(x in argv for x in ('-v', '--version', '--help')):
            role = 'compiler introspection'
        elif '--compile-macro' in argv:
            role = 'compile-time macro'
        elif any(x.endswith('/build.cj') for x in argv):
            role = 'build helper'
        elif any(x.endswith('/testrunner.cj') for x in argv):
            role = 'unused test framework launcher'
        else:
            role = 'measured runtime or benchmark compilation'
        calls.append({'executable': executable, 'argv': argv, 'role': role})
    measured = [call for call in calls if call['role'] == 'measured runtime or benchmark compilation']
    assert measured and all('-O2' in call['argv'] and all(flag == '-O2' for flag in call['argv'] if flag.startswith('-O')) for call in measured), measured
    receipt['variants'][name] = {'traceSha256': hashlib.sha256(trace_path.read_bytes()).hexdigest(), 'calls': calls}
(output / 'compiler-audit.json').write_text(json.dumps(receipt, indent=2) + '\n')
print('PAIRED_COMPILER_AUDIT_PASS', ','.join(names))
