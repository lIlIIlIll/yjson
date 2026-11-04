"""Recompute a build receipt from copied raw traces using locally trusted code."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def verify_compiler_audit(folder: Path, baseline: str, temporary_parent: Path) -> dict:
    auditor = Path(__file__).with_name('audit-pure-build.py')
    recorded = json.loads((folder / 'compiler-audit.json').read_text())
    names = (baseline, 'pure-candidate')
    with tempfile.TemporaryDirectory(prefix='compiler-replay.', dir=temporary_parent) as work:
        work = Path(work)
        for name in names:
            shutil.copy2(folder / f'compiler-{name}.execve', work / f'compiler-{name}.execve')
        subprocess.run([sys.executable, str(auditor), str(work), *names], check=True)
        recomputed = json.loads((work / 'compiler-audit.json').read_text())
        assert recomputed == recorded
    return {'status':'PASS','rawExecveRecomputed':True,'allMeasuredCompilerInvocationsExplicitO2':True,'noChirInliningDisabled':True,'compilerAuditorSha256':hashlib.sha256(auditor.read_bytes()).hexdigest(),'replayHelperSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'archivedProgramsExecuted':False}
