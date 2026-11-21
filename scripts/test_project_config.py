"""Keep the entry points (Makefile, VS Code, CI, Dev Container) consistent."""

import json
import re
import tomllib
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent


def load_json(path: str) -> Any:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def make_targets() -> set[str]:
    text = (ROOT / "Makefile").read_text(encoding="utf-8")
    return set(re.findall(r"^([a-z][a-z-]*):", text, flags=re.MULTILINE))


class ProjectConfigTests(unittest.TestCase):
    def test_required_extensions_match(self):
        container = load_json(".devcontainer/devcontainer.json")
        recommended = load_json(".vscode/extensions.json")["recommendations"]
        self.assertEqual(
            sorted(container["customizations"]["vscode"]["extensions"]),
            sorted(recommended),
        )

    def test_vscode_tasks_call_existing_make_targets(self):
        targets = make_targets()
        tasks = load_json(".vscode/tasks.json")["tasks"]
        self.assertTrue(tasks)
        for task in tasks:
            with self.subTest(task=task["label"]):
                match = re.fullmatch(r"make ([a-z-]+)", task["command"])
                self.assertIsNotNone(match, "tasks must call a make target")
                assert match is not None
                self.assertIn(match.group(1), targets)
                self.assertEqual(match.group(1), task["label"])

    def test_ci_runs_the_make_targets(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        # Only whole steps count: a target that is commented out, or whose
        # failure is ignored with "||", is not a check.
        used = set(re.findall(r"^ +- run: make ([a-z-]+)$", workflow, flags=re.M))
        used |= set(
            re.findall(
                r"^ +devcontainer-python:ci make ([a-z-]+)$", workflow, flags=re.M
            )
        )
        self.assertNotIn("continue-on-error", workflow)
        self.assertLessEqual(used, make_targets())
        for target in ("lint", "typecheck", "test", "cov", "pre-commit", "audit"):
            with self.subTest(target=target):
                self.assertIn(target, used)
        # The image is checked with the aggregate target.
        self.assertIn("check", used)

    def test_documented_make_targets_exist(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        documented = set(re.findall(r"`make ([a-z-]+)`", readme))
        self.assertTrue(documented)
        self.assertLessEqual(documented, make_targets())

    def test_history_volume_matches_the_image(self):
        container = load_json(".devcontainer/devcontainer.json")
        dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text(encoding="utf-8")
        bashrc = (ROOT / ".devcontainer/shell/bashrc").read_text(encoding="utf-8")
        self.assertTrue(
            any("target=/commandhistory," in mount for mount in container["mounts"])
        )
        self.assertIn("/commandhistory", dockerfile)
        self.assertIn("HISTFILE=/commandhistory/.bash_history", bashrc)

    def test_post_create_command_calls_an_existing_make_target(self):
        command = load_json(".devcontainer/devcontainer.json")["postCreateCommand"]
        match = re.match(r"make ([a-z-]+) \|\| echo ", command)
        assert match is not None
        self.assertIn(match.group(1), make_targets())

    def test_files_are_checked_out_with_lf(self):
        # CRLF in the bashrc or the shell scripts breaks them inside the image.
        attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
        self.assertIn("* text=auto eol=lf\n", attributes)

    def test_japanese_names_are_allowed(self):
        # pep8-naming rejects every identifier that contains Japanese. The
        # regression test file makes `make lint` fail if such a rule returns.
        with (ROOT / "pyproject.toml").open("rb") as file:
            lint = tomllib.load(file)["tool"]["ruff"]["lint"]
        self.assertFalse([rule for rule in lint["select"] if rule.startswith("N")])
        self.assertTrue((ROOT / "tests/test_日本語の名前.py").is_file())

    def test_user_installed_commands_are_on_path(self):
        dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text(encoding="utf-8")
        self.assertIn("ENV PATH=/home/$USERNAME/.local/bin:$PATH\n", dockerfile)

    def test_remote_user_matches_the_image(self):
        container = load_json(".devcontainer/devcontainer.json")
        dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text(encoding="utf-8")
        self.assertIn(f"ARG USERNAME={container['remoteUser']}\n", dockerfile)


if __name__ == "__main__":
    unittest.main()
