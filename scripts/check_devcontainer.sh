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
    ipython prek coverage ptw; do
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

# --- Commands added later with pip ----------------------------------------------
# `pip install` as this user installs commands into ~/.local/bin. They must be
# found without editing ~/.bashrc, in every kind of shell.
user_bin="$HOME/.local/bin"
case ":$PATH:" in
    *":$user_bin:"*) ok "~/.local/bin is on PATH" ;;
    *) ng "~/.local/bin is on PATH" ;;
esac
[ "$(python -c 'import sysconfig; print(sysconfig.get_path("scripts", "posix_user"))')" = "$user_bin" ] &&
    ok "pip installs user commands into ~/.local/bin" ||
    ng "pip installs user commands into ~/.local/bin"
probe="devcontainer-path-probe-$$"
created_user_bin=0
[ -d "$user_bin" ] || created_user_bin=1
if mkdir -p "$user_bin" && printf '#!/bin/sh\n' >"$user_bin/$probe" &&
    chmod +x "$user_bin/$probe"; then
    check "a command in ~/.local/bin is found (plain shell)" \
        bash -c "command -v $probe"
    check "a command in ~/.local/bin is found (interactive shell)" \
        bash -ic "command -v $probe"
    check "a command in ~/.local/bin is found (make)" \
        make -s -f /dev/null --eval "probe: ; @command -v $probe" probe
    rm -f "$user_bin/$probe"
    [ "$created_user_bin" -eq 1 ] && rmdir "$user_bin" "$HOME/.local" 2>/dev/null
else
    ng "~/.local/bin is writable"
fi

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
# Do not let the developer's own Git settings (signing, hooks) change the result.
export GIT_CONFIG_GLOBAL=/dev/null
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
prompt=$(render_prompt 'git commit -q --allow-empty -m x; : >tracked.txt; git add tracked.txt; echo change >tracked.txt')
case $prompt in
    *'*+'*) ok "prompt shows unstaged and staged changes" ;;
    *) ng "prompt shows unstaged and staged changes" ;;
esac
# Branch and directory names must never be executed by prompt expansion.
git -C "$repo" checkout -q -b 'x$(touch${IFS}pwned1)'
render_prompt true >/dev/null
git -C "$repo" checkout -q -b 'y`touch${IFS}pwned2`'
render_prompt true >/dev/null
render_prompt 'VIRTUAL_ENV='"'"'/tmp/$(touch${IFS}pwned3)`touch${IFS}pwned4`'"'" >/dev/null
if ls "$repo" | grep -q pwned; then
    ng "prompt does not execute branch or environment names"
else
    ok "prompt does not execute branch or environment names"
fi

[ "$(interactive 'echo $HISTFILE')" = /commandhistory/.bash_history ] &&
    ok "history is kept in /commandhistory" ||
    ng "history is kept in /commandhistory"
[ "$(interactive 'echo $HISTSIZE:$HISTCONTROL')" = 10000:ignoreboth:erasedups ] &&
    ok "history size and de-duplication" || ng "history size and de-duplication"
check "/commandhistory is writable" test -w /commandhistory
marker="history-marker-$$"
# Checked inside the same shell: the file must be written before the shell
# exits. A temporary file keeps the marker out of the real history.
check "the prompt saves each command to the history file" interactive \
    "HISTFILE=$tmp/history; history -s 'echo $marker'; __devcontainer_prompt; grep -q $marker \$HISTFILE"
[ "$(interactive 'echo $PAGER:$LESS:$EDITOR')" = less:-FRX:nano ] &&
    ok "pager and editor defaults" || ng "pager and editor defaults"
# Dev Containers may change the UID of the user to match the host, so the
# mount point must not depend on UID 1000.
[ "$(stat -c %a /commandhistory)" = 1777 ] &&
    ok "/commandhistory is writable for any UID" ||
    ng "/commandhistory is writable for any UID"
check "alias ll" interactive 'alias ll'
check "alias gs" interactive 'alias gs'
check "alias gl" interactive 'alias gl'
check "bash-completion is loaded" interactive 'declare -F _comp_initialize || declare -F _init_completion'
check "git completion is available" \
    interactive '__load_completion git 2>/dev/null || _comp_load git; declare -F __git_main'
check "make completion is available" \
    interactive '__load_completion make 2>/dev/null || _comp_load make; complete -p make'

# --- Test watcher ----------------------------------------------------------------
# `make watch` must re-run the tests when a file in a subdirectory is saved.
# Use the repository's own [tool.pytest-watcher] settings in a scratch project.
watch="$tmp/watch"
mkdir -p "$watch/tests/unit"
cp "$(dirname "$0")/../pyproject.toml" "$watch/"
printf 'def test_first():\n    assert True\n' >"$watch/tests/unit/test_sample.py"
(cd "$watch" && exec ptw . -p no:cacheprovider >"$tmp/watch.log" 2>&1) &
watch_pid=$!
wait_for_runs() {
    # $1: number of finished test runs to wait for (up to 30 seconds).
    local tries=0
    while [ "$(grep -ac ' passed in ' "$tmp/watch.log")" -lt "$1" ]; do
        tries=$((tries + 1))
        [ "$tries" -gt 60 ] && return 1
        sleep 0.5
    done
}
check "ptw runs the tests at start-up" wait_for_runs 1
# ptw drops the changes that arrive while a run is finishing; wait for it to idle.
sleep 2
printf '\n\ndef test_second():\n    assert True\n' >>"$watch/tests/unit/test_sample.py"
check "ptw re-runs the tests after a file in a subdirectory changes" wait_for_runs 2
grep -aq '2 passed in ' "$tmp/watch.log" && ok "the re-run sees the new test" ||
    ng "the re-run sees the new test"
kill "$watch_pid" 2>/dev/null
wait "$watch_pid" 2>/dev/null

if [ "$failures" -ne 0 ]; then
    printf '\n%d check(s) failed\n' "$failures"
    exit 1
fi
printf '\nAll checks passed\n'
