"""Keep the entry points (Makefile, VS Code, CI, Dev Container) consistent."""

import base64
import hashlib
import json
import os
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
        # Only the target: VS Code shows the command in its log, and the text
        # of a fallback message there was read as a warning.
        self.assertEqual(command, "make post-create")
        self.assertIn("post-create", make_targets())
        # The Dev Container registers the commit hook when it is created, and
        # a failure there does not stop the container from starting.
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        recipe = makefile.split("\npost-create:")[1].split("\n\n")[0]
        self.assertIn("if sh scripts/git-hooks/install.sh install; then", recipe)
        self.assertIn("else", recipe)
        self.assertNotIn("exit 1", recipe)

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
        # At the end of PATH: the pinned tools of the image must win.
        self.assertIn("ENV PATH=$PATH:/home/$USERNAME/.local/bin\n", dockerfile)

    def test_watch_uses_the_runner_script(self):
        with (ROOT / "pyproject.toml").open("rb") as file:
            watcher = tomllib.load(file)["tool"]["pytest-watcher"]
        self.assertEqual(watcher["runner"], "python")
        for argument in watcher["runner_args"]:
            self.assertTrue((ROOT / argument).is_file())

    def test_github_host_keys_match_the_published_fingerprints(self):
        # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
        expected = {
            "ssh-ed25519": "SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU",
            "ecdsa-sha2-nistp256": "SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM",
            "ssh-rsa": "SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s",
        }
        text = (ROOT / ".devcontainer/ssh/ssh_known_hosts").read_text(encoding="utf-8")
        found = {}
        for line in text.splitlines():
            if not line or line.startswith("#"):
                continue
            host, key_type, key = line.split()
            self.assertEqual(host, "github.com")
            digest = hashlib.sha256(base64.b64decode(key, validate=True)).digest()
            found[key_type] = "SHA256:" + base64.b64encode(digest).decode().rstrip("=")
        self.assertEqual(found, expected)
        dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text(encoding="utf-8")
        self.assertIn("ssh_known_hosts /etc/ssh/ssh_known_hosts\n", dockerfile)

    def test_github_cli_signing_key_is_the_reviewed_one(self):
        # Downloaded from https://cli.github.com/packages/githubcli-archive-keyring.gpg
        # on 2026-11-21. apt trusts packages signed with this key, so a changed
        # file must be reviewed, not just committed.
        keyring = ROOT / ".devcontainer/apt/githubcli-archive-keyring.gpg"
        self.assertEqual(
            hashlib.sha256(keyring.read_bytes()).hexdigest(),
            "6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b",
        )
        dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text(encoding="utf-8")
        self.assertIn(
            "signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg", dockerfile
        )
        attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
        self.assertIn("*.gpg binary\n", attributes)

    def test_commit_hook_is_registered_from_the_repository(self):
        # The hook is a tracked file that `make hooks` copies into .git/hooks:
        # it must be executable in the checkout and carry the text by which
        # the installer and the doctor recognise the installed copy.
        hook = ROOT / "scripts/git-hooks/pre-commit"
        self.assertTrue(os.access(hook, os.X_OK))
        lines = hook.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[0], "#!/bin/sh")
        # The installer and the doctor recognise the hook by its second line.
        self.assertTrue(lines[1].startswith("# devcontainer-python pre-commit hook"))
        # The installer and the doctor recognise the installed copy by this text.
        self.assertIn("devcontainer-python pre-commit hook", hook.read_text("utf-8"))
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        self.assertIn("\t@sh scripts/git-hooks/install.sh install\n", makefile)
        self.assertIn("sh scripts/git-hooks/install.sh uninstall", makefile)

    def test_ci_ok_waits_for_every_job(self):
        # `ci-ok` is the one required check: a job that it does not wait for
        # could fail without blocking a merge.
        text = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        body = text.split("\njobs:\n")[1]
        jobs = set(re.findall(r"^  ([a-z][a-z-]*):$", body, flags=re.MULTILINE))
        needs = re.search(
            r"^  ci-ok:\n(?:    .*\n)*?    needs: \[([^\]]*)\]",
            text,
            flags=re.MULTILINE,
        )
        assert needs is not None
        waited_for = {name.strip() for name in needs.group(1).split(",")}
        self.assertEqual(waited_for, jobs - {"ci-ok"})
        self.assertRegex(text, r"  ci-ok:\n(?:    #.*\n)*    if: always\(\)\n")

    def test_ci_does_not_keep_credentials_after_checkout(self):
        text = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        checkouts = text.count("uses: actions/checkout@")
        without_credentials = re.findall(
            r"uses: actions/checkout@.*\n"
            r"        with:\n          persist-credentials: false\n",
            text,
        )
        self.assertGreater(checkouts, 0)
        self.assertEqual(len(without_credentials), checkouts)

    def test_shell_variables_are_delimited_before_japanese_text(self):
        # bash 3.2 (the /bin/sh and bash of macOS) takes the first byte of a
        # multi-byte character as part of the name: "$name（" is an unbound
        # variable there. "${name}（" works everywhere.
        scripts = [*ROOT.glob("scripts/*.sh"), *ROOT.glob("scripts/git-hooks/*")]
        self.assertGreater(len(scripts), 3)
        for script in scripts:
            text = script.read_text(encoding="utf-8")
            found = re.findall(r"\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7f]", text)
            self.assertEqual(found, [], script.name)

    def test_remote_user_matches_the_image(self):
        container = load_json(".devcontainer/devcontainer.json")
        dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text(encoding="utf-8")
        self.assertIn(f"ARG USERNAME={container['remoteUser']}\n", dockerfile)


if __name__ == "__main__":
    unittest.main()
