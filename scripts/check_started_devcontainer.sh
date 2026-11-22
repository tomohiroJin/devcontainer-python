#!/usr/bin/env bash
# Checks a Dev Container that was started from devcontainer.json (CI runs this
# through `devcontainer exec`). scripts/check_devcontainer.sh checks the image;
# this checks what only devcontainer.json decides: the user, the workspace,
# the mounts, the environment, and that postCreateCommand registered the hook.
#
# CI has no Git identity and no credentials, so `make doctor` must report
# exactly those two failures and nothing else.
set -u

failures=0
ok() { printf 'ok   - %s\n' "$1"; }
ng() {
    printf 'FAIL - %s\n' "$1"
    failures=$((failures + 1))
}
check() {
    local name=$1
    shift
    if "$@" >/dev/null 2>&1; then ok "$name"; else ng "$name"; fi
}

check "the user is vscode (remoteUser)" test "$(id -un)" = vscode
check "the workspace is the repository" test -f .devcontainer/devcontainer.json
check "the workspace is writable" test -w .
# The directory also exists in the image: only a mount makes it a volume.
check "the history volume is mounted (mounts)" grep -q ' /commandhistory ' /proc/mounts
check "the history volume is writable" test -w /commandhistory
check "TZ is set (containerEnv)" test -n "${TZ:-}"
check "Git trusts the workspace" git rev-parse --show-toplevel

hook=.git/hooks/pre-commit
check "postCreateCommand registered the commit hook" test -x "$hook"
check "the registered hook is the one in the repository" cmp -s scripts/git-hooks/pre-commit "$hook"

report=$(make -s doctor 2>&1)
status=$?
printf '%s\n' "$report" | sed 's/^/    | /'
# Result lines have two spaces after the word (the summary line has one).
problems=$(printf '%s\n' "$report" | grep -E '^(FAIL|warn)  ')
expected='FAIL  コミットの名前とメールアドレスが決まりません（コミットできません）
FAIL  github.com の認証情報を取得できません（push すると、認証に失敗します）'
if [ "$status" -ne 0 ] && [ "$problems" = "$expected" ]; then
    ok "make doctor reports only the missing identity and credentials of CI"
else
    ng "make doctor reports only the missing identity and credentials of CI"
fi
for line in 'ok    この Dev Container のイメージの中で実行しています' \
    'ok    コミット前フックが登録されています' 'ok    すべてのファイルが整形済みです'; do
    if printf '%s\n' "$report" | grep -qxF "$line"; then
        ok "make doctor: $line"
    else
        ng "make doctor: $line"
    fi
done

# A commit runs the checks of the hook, and a file that fails them is refused.
export GIT_AUTHOR_NAME=ci GIT_AUTHOR_EMAIL=ci@example.invalid
export GIT_COMMITTER_NAME=ci GIT_COMMITTER_EMAIL=ci@example.invalid
probe=ci_probe_unformatted.py
trap 'git reset -q -- "$probe" 2>/dev/null; rm -f "$probe"' EXIT
printf 'x = 1\n' >"$probe"
git add "$probe"
if git commit -q -m 'probe: a clean file' >/dev/null 2>&1; then
    ok "a commit of a clean file passes the hook"
    git reset -q --soft HEAD~1
else
    ng "a commit of a clean file passes the hook"
fi
printf 'import os\nx=1\n' >"$probe"
git add "$probe"
if git commit -q -m 'probe: must be refused' >/dev/null 2>&1; then
    ng "a commit of a file that fails lint is refused by the hook"
    git reset -q --soft HEAD~1
else
    ok "a commit of a file that fails lint is refused by the hook"
fi

if [ "$failures" -eq 0 ]; then
    echo "All checks passed"
else
    echo "$failures check(s) failed"
    exit 1
fi
