#!/usr/bin/env bash
# Checks what happens on a host, outside the Dev Container (CI runs this on
# Windows and macOS, where the image cannot be used): line endings after a
# checkout, a commit through the hook without any of the tools, and that
# `make doctor`'s script runs to the end with the host's own shell and Git.
set -u

failures=0
ok() { printf 'ok   - %s\n' "$1"; }
ng() {
    printf 'FAIL - %s\n' "$1"
    failures=$((failures + 1))
}

# Every text file is LF in the index and in the working tree, whatever
# core.autocrlf says on this machine (.gitattributes decides).
wrong=$(git ls-files --eol | grep -Ev '^i/(lf|none|-text) +w/(lf|none|-text) ')
if [ -z "$wrong" ]; then
    ok "every file is checked out with LF line endings"
else
    ng "every file is checked out with LF line endings"
    printf '%s\n' "$wrong" | sed 's/^/    | /'
fi

# A commit on the host goes through, with a notice, although prek, Ruff and
# mypy are not what the hook may rely on here.
export GIT_AUTHOR_NAME=ci GIT_AUTHOR_EMAIL=ci@example.invalid
export GIT_COMMITTER_NAME=ci GIT_COMMITTER_EMAIL=ci@example.invalid
probe=ci_probe_host.py
log=$(mktemp)
cleanup() {
    git reset -q -- "$probe" 2>/dev/null
    rm -f "$probe" "$log"
    sh scripts/git-hooks/install.sh uninstall >/dev/null 2>&1
}
trap cleanup EXIT
if sh scripts/git-hooks/install.sh install >"$log" 2>&1 && [ -x "$(git rev-parse --git-path hooks/pre-commit)" ]; then
    ok "the hook can be registered on the host"
else
    ng "the hook can be registered on the host"
    sed 's/^/    | /' "$log"
fi
printf 'import os\nx=1\n' >"$probe"
git add "$probe"
if git commit -q -m 'probe: a host commit' >"$log" 2>&1; then
    git reset -q --soft HEAD~1
    ok "a commit on the host is not stopped by the hook"
else
    ng "a commit on the host is not stopped by the hook"
fi
if grep -q 'Dev Container の外（ホスト）なので、コミット前の検査を省いてコミットします' "$log"; then
    ok "the hook says that the checks were skipped"
else
    ng "the hook says that the checks were skipped"
    sed 's/^/    | /' "$log"
fi

# The doctor runs to its summary with this machine's bash, Git and tools.
# Its verdict is not judged: a CI machine has no identity and no credentials.
started=$(date +%s)
report=$(bash scripts/doctor.sh 2>&1)
status=$?
elapsed=$(($(date +%s) - started))
printf '%s\n' "$report" | sed 's/^/    | /'
if [ "$status" -le 1 ] && printf '%s\n' "$report" | grep -q '^結果: '; then
    ok "the doctor runs to its summary (exit status $status, $elapsed s)"
else
    ng "the doctor runs to its summary (exit status $status, $elapsed s)"
fi
if printf '%s\n' "$report" | grep -q 'ここは Dev Container の外（ホスト）です'; then
    ok "the doctor says that this is a host"
else
    ng "the doctor says that this is a host"
fi
if printf '%s\n' "$report" | grep -Eq 'syntax error|command not found|unbound variable|: line [0-9]+:'; then
    ng "the doctor's output has no shell errors"
else
    ok "the doctor's output has no shell errors"
fi

if [ "$failures" -eq 0 ]; then
    echo "All checks passed"
else
    echo "$failures check(s) failed"
    exit 1
fi
