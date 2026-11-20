#!/usr/bin/env bash
# Smoke test for the Dev Container image. Run it inside the container as the
# image's own user:
#   bash scripts/check_devcontainer.sh
# CI runs it against the freshly built image. It checks what a developer sees
# in the terminal: tools, locale, pager, Git defaults, prompt, history, aliases.
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

# --- Tools ---------------------------------------------------------------------
for tool in bash git less make curl jq tree ps nano python pytest ruff mypy \
    ipython prek coverage; do
    check "command: $tool" command -v "$tool"
done
check "pytest-cov plugin is installed" python -c 'import pytest_cov'
# Deliberately left out (see the README): each of these widens the attack
# surface without being needed for everyday work.
for tool in sudo ssh gcc vim; do
    if command -v "$tool" >/dev/null 2>&1; then
        ng "command must be absent: $tool"
    else
        ok "command is absent: $tool"
    fi
done

# --- User and shell ------------------------------------------------------------
[ "$(id -u)" -ne 0 ] && ok "runs as a non-root user" || ng "runs as a non-root user"
login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
[ "$login_shell" = /bin/bash ] && ok "login shell is bash" ||
    ng "login shell is bash (got '$login_shell')"

# --- Locale and timezone ---------------------------------------------------------
[ "${LANG:-}" = C.UTF-8 ] && ok "LANG is C.UTF-8" || ng "LANG is C.UTF-8"
japanese='日本語のテスト'
[ "$(printf '%s' "$japanese" | wc -m)" -eq 7 ] &&
    ok "multibyte text is counted as characters" ||
    ng "multibyte text is counted as characters"
[ "$(python -c 'import sys; print(sys.stdout.encoding)')" = utf-8 ] &&
    ok "Python writes UTF-8" || ng "Python writes UTF-8"
[ "$(TZ=Asia/Tokyo date +%Z)" = JST ] && ok "timezone data is available" ||
    ng "timezone data is available"

# --- Pager and Git -------------------------------------------------------------
[ "$(git config --system core.pager)" = 'less -FRX' ] &&
    ok "git pager is less" || ng "git pager is less"
[ "$(git config --system core.quotepath)" = false ] &&
    ok "git shows non-ASCII paths" || ng "git shows non-ASCII paths"
[ "$(git config --system color.ui)" = auto ] && ok "git colour is on" ||
    ng "git colour is on"
[ "$(printf '%s\n' "$japanese" | less -FRX)" = "$japanese" ] &&
    ok "less passes Japanese text through" ||
    ng "less passes Japanese text through"

# --- Interactive shell -----------------------------------------------------------
# Start a real interactive bash with the image's rc files and inspect it.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
git init -q "$repo" 2>/dev/null
git -C "$repo" -c user.name=t -c user.email=t@example.invalid \
    commit -q --allow-empty -m init
git -C "$repo" checkout -q -b 'feature/日本語'
: >"$repo/untracked.txt"

rc=/etc/devcontainer/bashrc
interactive() {
    # $1: commands to run in the interactive shell; output goes to stdout.
    (cd "$repo" && HOME="$tmp" bash --rcfile "$rc" -i -c "$1" 2>/dev/null)
}
render_prompt() {
    # $1: command to run first (sets $?); prints the expanded prompt.
    interactive "$1; __devcontainer_prompt; printf '%s' \"\${PS1@P}\""
}

check "bashrc exists" test -r "$rc"
check "~/.bashrc sources it" grep -q /etc/devcontainer/bashrc "$HOME/.bashrc"

prompt=$(render_prompt true)
case $prompt in
    *'feature/日本語'*) ok "prompt shows the git branch" ;;
    *) ng "prompt shows the git branch" ;;
esac
case $prompt in
    *'feature/日本語 %'*) ok "prompt shows untracked files" ;;
    *) ng "prompt shows untracked files" ;;
esac
case $prompt in
    *'exit '*) ng "prompt hides the exit code after success" ;;
    *) ok "prompt hides the exit code after success" ;;
esac
prompt=$(render_prompt '(exit 42)')
case $prompt in
    *'exit 42'*) ok "prompt shows a failing exit code" ;;
    *) ng "prompt shows a failing exit code" ;;
esac
prompt=$(render_prompt 'VIRTUAL_ENV=/tmp/demo/.venv')
case $prompt in
    *'[.venv]'*) ok "prompt shows the virtual environment" ;;
    *) ng "prompt shows the virtual environment" ;;
esac
# A branch name must never be executed by prompt expansion.
git -C "$repo" checkout -q -b 'x$(touch${IFS}pwned)'
render_prompt true >/dev/null
[ ! -e "$repo/pwned" ] && ok "prompt does not execute branch names" ||
    ng "prompt does not execute branch names"

[ "$(interactive 'echo $HISTFILE')" = /commandhistory/.bash_history ] &&
    ok "history is kept in /commandhistory" ||
    ng "history is kept in /commandhistory"
[ "$(interactive 'echo $HISTSIZE:$HISTCONTROL')" = 10000:ignoreboth:erasedups ] &&
    ok "history size and de-duplication" || ng "history size and de-duplication"
check "/commandhistory is writable" test -w /commandhistory
check "alias ll" interactive 'alias ll'
check "alias gs" interactive 'alias gs'
check "bash-completion is loaded" interactive 'declare -F _comp_initialize || declare -F _init_completion'
check "git completion is available" \
    interactive '__load_completion git 2>/dev/null || _comp_load git; declare -F __git_main'
check "make completion is available" \
    interactive '__load_completion make 2>/dev/null || _comp_load make; complete -p make'

if [ "$failures" -ne 0 ]; then
    printf '\n%d check(s) failed\n' "$failures"
    exit 1
fi
printf '\nAll checks passed\n'
