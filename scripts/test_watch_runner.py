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
