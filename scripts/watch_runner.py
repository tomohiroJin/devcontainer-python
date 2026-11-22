"""Run pytest for `make watch`, and again when files changed during the run.

pytest-watcher (`ptw`) discards the changes it sees while a test run is in
progress, so a file saved during a run would leave a stale result on screen.
`ptw` starts this script instead of pytest ([tool.pytest-watcher] in
pyproject.toml). After each run the script looks for Python files modified
since the run started and, if there are any, runs pytest once more for all of
them together.

With WATCH_FORMAT=1 in the environment (`make watch-fmt`), every run first
formats the Python files with Ruff. That is for Live Share sessions: a guest's
save does not trigger the host's format-on-save, but it does change the file
on the host, where this script runs. A file that the formatter rewrites counts
as changed during the run, so the tests run once more on the formatted code.
"""

import os
import subprocess
import sys
import time
from collections.abc import Callable, Iterator, Sequence
from pathlib import Path

# Give up after this many runs in a row: a test that rewrites a Python file on
# every run would otherwise loop forever.
MAX_RUNS = 5
# Directories that hold no source files (caches, virtual environments, reports).
SKIPPED_DIRECTORIES = frozenset({"__pycache__", "htmlcov", "node_modules"})


def python_files(root: Path) -> Iterator[Path]:
    for directory, subdirectories, files in os.walk(root):
        subdirectories[:] = [
            name
            for name in subdirectories
            if not name.startswith(".") and name not in SKIPPED_DIRECTORIES
        ]
        for name in files:
            if name.endswith(".py"):
                yield Path(directory, name)


def changed_since(root: Path, started_ns: int) -> list[Path]:
    changed = []
    for path in python_files(root):
        try:
            modified_ns = path.stat().st_mtime_ns
        except OSError:
            # Deleted between the directory listing and the stat call.
            continue
        # ">=": some file systems store coarse timestamps. A file saved in the
        # same tick as the start costs one extra run, never a missed one.
        if modified_ns >= started_ns:
            changed.append(path)
    return sorted(changed)


def run_until_stable(
    run_tests: Callable[[], int],
    root: Path,
    now_ns: Callable[[], int] = time.time_ns,
    report: Callable[[str], None] = print,
) -> int:
    """Run the tests until no Python file changes during a run."""
    status = 0
    for attempt in range(1, MAX_RUNS + 1):
        started_ns = now_ns()
        status = run_tests()
        changed = changed_since(root, started_ns)
        if not changed:
            return status
        names = ", ".join(str(path.relative_to(root)) for path in changed[:3])
        if len(changed) > 3:
            names += f" (+{len(changed) - 3})"
        if attempt == MAX_RUNS:
            report(f"[watch] {names} が実行中に変更されましたが、再実行は打ち切ります")
        else:
            report(f"[watch] 実行中に変更がありました（{names}）。再実行します")
    return status


def format_files(report: Callable[[str], None] = print) -> None:
    """Format the Python files in place with the Ruff of this environment."""
    try:
        result = subprocess.run(
            ["ruff", "format", "--quiet", "."],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as error:
        report(f"[watch] ruff を実行できないため、整形していません（{error}）")
        return
    if result.returncode != 0:
        # Usually a file that does not parse yet; the tests will say more.
        reason = (result.stderr or result.stdout).strip().splitlines()[:3]
        report("[watch] 整形できないファイルがあります（構文の誤りなど）")
        for line in reason:
            report(f"[watch]   {line}")


def main(arguments: Sequence[str]) -> int:
    format_first = os.environ.get("WATCH_FORMAT") == "1"

    def run_tests() -> int:
        if format_first:
            format_files()
        # sys.executable: the same interpreter, whatever `pytest` is on PATH.
        return subprocess.call([sys.executable, "-m", "pytest", *arguments])

    return run_until_stable(run_tests, Path.cwd())


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
