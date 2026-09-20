#!/usr/bin/env python3
"""Reject runtime failures even when cjpm run would report success."""

from __future__ import annotations

import contextlib
import io
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import release_consumer_checks as consumer


class ReleaseConsumerExecutionTest(unittest.TestCase):
    @unittest.skipUnless(sys.platform == "linux" and shutil.which("cc"), "Linux C toolchain required")
    def test_executable_loads_built_and_inherited_shared_libraries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            project = root / "consumer with spaces"
            dependency = project / "target/release/dependency"
            inherited = root / "inherited"
            binary = project / "target/release/bin/main"
            dependency.mkdir(parents=True)
            inherited.mkdir()
            binary.parent.mkdir()
            for name, value, destination in (
                ("dependency", 42, dependency), ("inherited", 7, inherited)
            ):
                source = root / f"{name}.c"
                source.write_text(f"int {name}(void) {{ return {value}; }}\n", encoding="utf-8")
                subprocess.run(
                    ["cc", "-shared", "-fPIC", str(source), "-o", str(destination / f"lib{name}.so")],
                    check=True, capture_output=True,
                )
            source = root / "main.c"
            source.write_text(
                '#include <stdio.h>\nint dependency(void); int inherited(void);\n'
                'int main(void) { printf("%d\\n", dependency() + inherited()); return 0; }\n',
                encoding="utf-8",
            )
            subprocess.run(
                ["cc", str(source), "-L", str(dependency), "-ldependency",
                 "-L", str(inherited), "-linherited", "-o", str(binary)],
                check=True, capture_output=True,
            )
            cjpm = root / "cjpm"
            cjpm.write_text('#!/usr/bin/env bash\n[[ "$1" == build ]]\n', encoding="utf-8")
            cjpm.chmod(0o755)
            environment = dict(os.environ)
            environment["PATH"] = f"{root}:{environment['PATH']}"
            environment["LD_LIBRARY_PATH"] = str(inherited)
            result = subprocess.run(
                [str(consumer.ROOT / "scripts/run_cjpm_executable.sh"), str(project)],
                env=environment, text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "49\n")

    def test_runtime_failure_is_not_reported_as_success(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            cjpm = root / "cjpm"
            cjpm.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
    run) printf 'Unhandled exception in consumer\n'; exit 0 ;;
    build)
        mkdir -p target/release/bin
        printf '#!/usr/bin/env bash\nexit 23\n' >target/release/bin/main
        chmod +x target/release/bin/main
        ;;
    *) exit 2 ;;
esac
""",
                encoding="utf-8",
            )
            cjpm.chmod(0o755)
            environment = {"PATH": f"{root}:{os.environ['PATH']}"}
            with mock.patch.dict(os.environ, environment):
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(subprocess.CalledProcessError) as raised:
                        consumer.run_fixture(
                            "fault_injection", "", "package fixture\nmain(): Unit {}\n",
                            root / "fixtures", "",
                        )
            self.assertEqual(raised.exception.returncode, 23)


if __name__ == "__main__":
    unittest.main()
