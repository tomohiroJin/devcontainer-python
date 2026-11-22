"""Tests for the pytest runner behind `make watch`."""

import os
import tempfile
import unittest
from pathlib import Path

import watch_runner


class WatchRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.source = self.root / "tests" / "unit" / "test_sample.py"
        self.source.parent.mkdir(parents=True)
        self.source.write_text("", encoding="utf-8")
        self.set_modified(self.source, 100)
        self.clock = 1_000
        self.messages: list[str] = []

    def set_modified(self, path: Path, when_ns: int) -> None:
        os.utime(path, ns=(when_ns, when_ns))

    def now_ns(self) -> int:
        self.clock += 1_000
        return self.clock

    def run_with(self, runs: list[int | None], status: int = 0) -> tuple[int, int]:
        """Run the loop; each entry of `runs` saves the file at that time."""
        calls = 0

        def run_tests() -> int:
            nonlocal calls
            saved_at = runs[calls] if calls < len(runs) else None
            calls += 1
            if saved_at is not None:
                self.set_modified(self.source, self.clock + saved_at)
            return status

        result = watch_runner.run_until_stable(
            run_tests, self.root, self.now_ns, self.messages.append
        )
        return result, calls

    def test_runs_once_when_nothing_changes(self) -> None:
        self.assertEqual(self.run_with([None]), (0, 1))
        self.assertEqual(self.messages, [])

    def test_runs_again_after_a_save_during_the_run(self) -> None:
        self.assertEqual(self.run_with([500, None]), (0, 2))
        self.assertIn("tests/unit/test_sample.py", self.messages[0])

    def test_a_save_in_the_same_clock_tick_is_not_missed(self) -> None:
        self.assertEqual(self.run_with([0, None]), (0, 2))

    def test_returns_the_status_of_the_last_run(self) -> None:
        self.assertEqual(self.run_with([None], status=1), (1, 1))

    def test_stops_when_every_run_changes_a_file(self) -> None:
        result, calls = self.run_with([500] * 10)
        self.assertEqual(calls, watch_runner.MAX_RUNS)
        self.assertEqual(result, 0)
        self.assertIn("打ち切ります", self.messages[-1])

    def test_ignores_caches_hidden_directories_and_other_files(self) -> None:
        for name in (
            ".venv/lib/module.py",
            "__pycache__/module.py",
            "htmlcov/module.py",
            "README.md",
        ):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("", encoding="utf-8")
            self.set_modified(path, 10**12)
        self.assertEqual(self.run_with([None]), (0, 1))


if __name__ == "__main__":
    unittest.main()


class FormatFilesTests(unittest.TestCase):
    """`make watch-fmt`: the files are formatted with the real Ruff."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        previous = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, previous)
        self.messages: list[str] = []

    def test_formats_a_file_in_place(self) -> None:
        source = self.root / "sample.py"
        source.write_text("x=1\n", encoding="utf-8")
        watch_runner.format_files(self.messages.append)
        self.assertEqual(source.read_text(encoding="utf-8"), "x = 1\n")
        self.assertEqual(self.messages, [])

    def test_leaves_a_formatted_file_untouched(self) -> None:
        source = self.root / "sample.py"
        source.write_text("x = 1\n", encoding="utf-8")
        os.utime(source, ns=(100, 100))
        watch_runner.format_files(self.messages.append)
        self.assertEqual(source.stat().st_mtime_ns, 100)

    def test_reports_a_file_that_does_not_parse_and_formats_the_rest(self) -> None:
        broken = self.root / "broken.py"
        broken.write_text("def f(:\n", encoding="utf-8")
        other = self.root / "other.py"
        other.write_text("y=2\n", encoding="utf-8")
        watch_runner.format_files(self.messages.append)
        self.assertEqual(broken.read_text(encoding="utf-8"), "def f(:\n")
        self.assertEqual(other.read_text(encoding="utf-8"), "y = 2\n")
        self.assertIn("整形できないファイルがあります", self.messages[0])

    def test_formatted_files_cause_one_more_run(self) -> None:
        source = self.root / "sample.py"
        source.write_text("x=1\n", encoding="utf-8")
        runs = 0

        def run_tests() -> int:
            nonlocal runs
            runs += 1
            watch_runner.format_files(self.messages.append)
            return 0

        watch_runner.run_until_stable(run_tests, self.root, report=self.messages.append)
        self.assertEqual(runs, 2)
