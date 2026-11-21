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
    ipython prek coverage ptw gh ssh ssh-add ssh-keygen; do
    check "command: $tool" command -v "$tool"
done
check "pytest-cov plugin is installed" python -c 'import pytest_cov'
# Deliberately left out (see the README): each of these widens the attack
# surface without being needed for everyday work.
for tool in sudo sshd gcc vim; do
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

# --- GitHub remotes use HTTPS --------------------------------------------------------
# A repository cloned over SSH on the host must be reachable from the container
# without an SSH agent: github.com SSH URLs are rewritten to HTTPS.
effective_url() {
    # $1: remote URL as stored in .git/config; prints the URL git really uses.
    git -C "$url_repo" remote set-url origin "$1" &&
        git -C "$url_repo" remote get-url --push origin
}
url_repo=$(mktemp -d)
git init -q "$url_repo" 2>/dev/null
git -C "$url_repo" remote add origin https://github.com/owner/repo.git
for url in git@github.com:owner/repo.git ssh://git@github.com/owner/repo.git \
    https://github.com/owner/repo.git; do
    [ "$(GIT_CONFIG_GLOBAL=/dev/null effective_url "$url")" = https://github.com/owner/repo.git ] &&
        ok "github.com remote uses HTTPS ($url)" ||
        ng "github.com remote uses HTTPS ($url)"
done
for url in git@gitlab.com:owner/repo.git git@github.com.example.org:owner/repo.git; do
    [ "$(GIT_CONFIG_GLOBAL=/dev/null effective_url "$url")" = "$url" ] &&
        ok "other hosts keep their URL ($url)" ||
        ng "other hosts keep their URL ($url)"
done
git -C "$url_repo" remote set-url origin git@github.com:owner/repo.git
[ "$(git -C "$url_repo" config --get remote.origin.url)" = git@github.com:owner/repo.git ] &&
    ok "the stored remote URL is not rewritten" ||
    ng "the stored remote URL is not rewritten"
# The documented way to keep SSH: the same system settings without the rule.
ssh_config=/etc/devcontainer/gitconfig-ssh
[ "$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=$ssh_config effective_url git@github.com:owner/repo.git)" = git@github.com:owner/repo.git ] &&
    ok "GIT_CONFIG_SYSTEM=$ssh_config keeps SSH" ||
    ng "GIT_CONFIG_SYSTEM=$ssh_config keeps SSH"
[ "$(git config --file /etc/gitconfig --list | grep -v '^url\.')" = "$(git config --file $ssh_config --list)" ] &&
    ok "gitconfig-ssh differs from /etc/gitconfig only in the URL rule" ||
    ng "gitconfig-ssh differs from /etc/gitconfig only in the URL rule"
rm -rf "$url_repo"

# --- Git over SSH and GitHub CLI ---------------------------------------------------
# The image trusts github.com's published host keys, so the first push over SSH
# asks no question and a different key is refused.
known_hosts=/etc/ssh/ssh_known_hosts
check "github.com host keys are installed" ssh-keygen -F github.com -f "$known_hosts"
fingerprints=$(ssh-keygen -lf "$known_hosts" 2>/dev/null | cut -d' ' -f2 | sort | tr '\n' ' ')
expected='SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s '
[ "$fingerprints" = "$expected" ] &&
    ok "github.com host keys match GitHub's published fingerprints" ||
    ng "github.com host keys match GitHub's published fingerprints"
ssh -G github.com 2>/dev/null | grep -q "^globalknownhostsfile .*$known_hosts" &&
    ok "ssh reads the image's known hosts file" ||
    ng "ssh reads the image's known hosts file"
ssh -G github.com 2>/dev/null | grep -qx 'stricthostkeychecking ask' &&
    ok "ssh still asks before trusting an unknown host" ||
    ng "ssh still asks before trusting an unknown host"
# A server with another key must be refused, not asked about. Use an sshd-free
# check: look the key up the way ssh does for a host that claims to be github.com.
other_key="$(mktemp)"
ssh-keygen -q -t ed25519 -N '' -f "$other_key.key" </dev/null
if ssh-keygen -F github.com -f "$known_hosts" | grep -q "$(cut -d' ' -f2 "$other_key.key.pub")"; then
    ng "an unknown key is not listed for github.com"
else
    ok "an unknown key is not listed for github.com"
fi
rm -f "$other_key" "$other_key.key" "$other_key.key.pub"
check "gh runs" gh --version
# Debian's own gh (2.46.0) has unfixed advisories; the image must carry the
# build from GitHub's apt repository. 2.98.0 fixes the last of them.
gh_version=$(dpkg-query -W -f '${Version}' gh 2>/dev/null)
dpkg --compare-versions "${gh_version:-0}" ge 2.98.0 &&
    ok "gh is a current release from GitHub's repository ($gh_version)" ||
    ng "gh is a current release from GitHub's repository (got '$gh_version')"
grep -qs 'signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg' \
    /etc/apt/sources.list.d/github-cli.list &&
    ok "the GitHub CLI apt source is tied to its signing key" ||
    ng "the GitHub CLI apt source is tied to its signing key"
check "gh can configure git credentials" gh auth setup-git --help
[ -r /usr/share/bash-completion/completions/gh ] && ok "gh completion is available" ||
    ng "gh completion is available"

# --- Commands added later with pip ----------------------------------------------
# `pip install` as this user installs commands into ~/.local/bin. They must be
# found without editing ~/.bashrc, in every kind of shell. A command there must
# not replace a tool of the image that has the same name (for example the `ptw`
# of pytest-watch, which the README used to tell people to install).
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
    if [ -e "$user_bin/ptw" ]; then
        ng "~/.local/bin/ptw already exists; remove it and run this check again"
    else
        bundled_ptw=$(command -v ptw)
        printf '#!/bin/sh\nexit 0\n' >"$user_bin/ptw"
        chmod +x "$user_bin/ptw"
        for shell in 'bash -c' 'bash -ic' 'bash -lc'; do
            [ "$($shell 'command -v ptw' 2>/dev/null)" = "$bundled_ptw" ] &&
                ok "the image's ptw wins over ~/.local/bin/ptw ($shell)" ||
                ng "the image's ptw wins over ~/.local/bin/ptw ($shell)"
        done
        [ "$(make -s -f /dev/null --eval 'probe: ; @command -v ptw' probe)" = "$bundled_ptw" ] &&
            ok "the image's ptw wins over ~/.local/bin/ptw (make)" ||
            ng "the image's ptw wins over ~/.local/bin/ptw (make)"
        rm -f "$user_bin/ptw"
    fi
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
# `make watch` must re-run the tests when a file in a subdirectory is saved,
# also when it is saved while the tests are running. Use the repository's own
# [tool.pytest-watcher] settings and runner script in a scratch project.
watch="$tmp/watch"
mkdir -p "$watch/tests/unit" "$watch/scripts"
cp "$(dirname "$0")/../pyproject.toml" "$watch/"
cp "$(dirname "$0")/watch_runner.py" "$watch/scripts/"
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
# Save a file while a (slow) run is in progress: the result on screen must not
# stay stale.
sleep 2
printf '\n\ndef test_slow():\n    import time\n\n    time.sleep(4)\n' >>"$watch/tests/unit/test_sample.py"
wait_for_sessions() {
    # $1: number of started pytest sessions to wait for (up to 30 seconds).
    local tries=0
    while [ "$(grep -ac 'test session starts' "$tmp/watch.log")" -lt "$1" ]; do
        tries=$((tries + 1))
        [ "$tries" -gt 60 ] && return 1
        sleep 0.5
    done
}
check "ptw starts the slow run" wait_for_sessions 3
sleep 1
printf '\n\ndef test_saved_during_the_run():\n    assert True\n' >>"$watch/tests/unit/test_sample.py"
check "ptw runs the tests again after a save during a run" wait_for_runs 4
grep -aq '4 passed in ' "$tmp/watch.log" &&
    ok "the run after a save during a run sees the new test" ||
    ng "the run after a save during a run sees the new test"
kill "$watch_pid" 2>/dev/null
wait "$watch_pid" 2>/dev/null

# --- Commit hook and `make doctor` -------------------------------------------------
# Both are checked in a scratch clone of the project files with its own HOME,
# so the developer's settings neither change the result nor get changed.
project=$(cd "$(dirname "$0")/.." && pwd)
work="$tmp/project"
mkdir -p "$work" "$tmp/home"
(cd "$project" && tar -cf - --exclude=.git --exclude='.venv*' --exclude=htmlcov \
    --exclude='.*_cache' --exclude=__pycache__ .) | tar -xf - -C "$work"
in_project() {
    # Run a command in the scratch project with a clean, known Git identity.
    (cd "$work" && env -u GIT_CONFIG_GLOBAL HOME="$tmp/home" "$@")
}
in_project git init -q . 2>/dev/null
in_project git config --global user.name 'Doctor Test'
in_project git config --global user.email doctor@example.invalid
in_project git add -A
installed_hook="$work/.git/hooks/pre-commit"
in_project make -s hooks >/dev/null
cmp -s "$work/scripts/git-hooks/pre-commit" "$installed_hook" && [ -x "$installed_hook" ] &&
    ok "make hooks copies the hook into .git/hooks" ||
    ng "make hooks copies the hook into .git/hooks"
[ -z "$(in_project git config --get core.hooksPath)" ] &&
    ok "make hooks leaves core.hooksPath alone when it is not set" ||
    ng "make hooks leaves core.hooksPath alone when it is not set"
in_project make -s hooks >/dev/null &&
    cmp -s "$work/scripts/git-hooks/pre-commit" "$installed_hook" &&
    [ ! -e "$installed_hook.before-devcontainer" ] &&
    ok "make hooks can be run again" || ng "make hooks can be run again"

commit() {
    # $1: commit message; the rest is put in front of `git commit` (env ...).
    # The output goes to $tmp/commit.log; the status is that of git commit.
    local message=$1
    shift
    in_project "$@" git commit -q -m "$message" >"$tmp/commit.log" 2>&1
}
add_file() {
    # $1: file name under src/, $2: content. Stages the file.
    printf '%s\n' "$2" >"$work/src/$1"
    in_project git add "src/$1"
}
# Inside the image the hook runs the checks: a good commit passes ...
commit 'initial' && grep -q 'ruff format' "$tmp/commit.log" &&
    ok "the commit hook runs the checks and accepts a clean commit" ||
    ng "the commit hook runs the checks and accepts a clean commit"
# ... and a file that needs formatting stops the commit, because of that check.
add_file needs_format.py 'x=1'
if commit 'unformatted'; then
    ng "the commit hook stops a commit that fails a check"
elif grep -q 'ruff format.*Failed' "$tmp/commit.log"; then
    ok "the commit hook stops a commit that fails a check"
else
    ng "the commit hook stops a commit that fails a check (it failed for another reason)"
fi
in_project git add src/needs_format.py
commit 'formatted now' && ok "the commit goes through after the fix" ||
    ng "the commit goes through after the fix"

# A requirements.txt that is ahead of the image (pulled, not rebuilt yet) must
# not switch the checks off in the container: they run, with a notice.
sed -i 's/^ruff==[^ ]*/ruff==99.0.0/' "$work/requirements.txt"
add_file pin_ahead.py 'p=1'
if commit 'pin ahead of the image'; then
    ng "a pin that differs from the image does not disable the checks"
elif grep -q 'ruff の版が requirements.txt と違います' "$tmp/commit.log" &&
    grep -q 'ruff format.*Failed' "$tmp/commit.log"; then
    ok "a pin that differs from the image does not disable the checks"
else
    ng "a pin that differs from the image does not disable the checks (no notice)"
fi
in_project git checkout -q -- requirements.txt
in_project git rm -q -f --cached src/pin_ahead.py >/dev/null
rm -f "$work/src/pin_ahead.py"

# On the host (no image marker) the hook never blocks, whatever is installed.
host() { printf '%s\n' env DEVCONTAINER_HOOK_MARKER=/nonexistent "$@"; }
host_cases='no tools|PATH=/usr/bin:/bin
all tools at the pinned versions|PATH='"$PATH"'
another ruff first|PATH='"$tmp/otherbin:$PATH"
mkdir -p "$tmp/otherbin"
printf '#!/bin/sh\necho "ruff 0.0.1"\nexit 2\n' >"$tmp/otherbin/ruff"
chmod +x "$tmp/otherbin/ruff"
number=0
while IFS='|' read -r name setting; do
    number=$((number + 1))
    add_file "host_$number.py" 'h=1'
    if commit "host: $name" env DEVCONTAINER_HOOK_MARKER=/nonexistent "$setting" &&
        grep -q 'コミット前の検査を省いてコミットします' "$tmp/commit.log"; then
        ok "on the host the hook skips the checks and lets the commit through ($name)"
    else
        ng "on the host the hook skips the checks and lets the commit through ($name)"
    fi
done <<CASES
$host_cases
CASES
# Opting in on the host runs the checks there; they can then stop a commit.
in_project git config hooks.devcontainerRunOnHost true
add_file host_opted_in.py 'o=1'
if commit 'host, opted in' env DEVCONTAINER_HOOK_MARKER=/nonexistent; then
    ng "hooks.devcontainerRunOnHost runs the checks on the host"
else
    grep -q 'ruff format.*Failed' "$tmp/commit.log" &&
        ok "hooks.devcontainerRunOnHost runs the checks on the host" ||
        ng "hooks.devcontainerRunOnHost runs the checks on the host"
fi
# ... but still never blocks when prek itself is missing.
if commit 'host, opted in, no prek' env DEVCONTAINER_HOOK_MARKER=/nonexistent PATH=/usr/bin:/bin; then
    ok "the opt-in does not block a host without prek"
else
    ng "the opt-in does not block a host without prek"
fi
in_project git config --unset hooks.devcontainerRunOnHost
# In the container a missing prek is a broken image: say so instead of
# silently committing unchecked code.
add_file no_prek.py 'n = 1'
if commit 'container without prek' env PATH=/usr/bin:/bin; then
    ng "in the container a missing prek stops the commit with advice"
else
    grep -q 'Dev Container をリビルドしてください' "$tmp/commit.log" &&
        ok "in the container a missing prek stops the commit with advice" ||
        ng "in the container a missing prek stops the commit with advice"
fi
in_project git reset -q --hard >/dev/null 2>&1
in_project prek run --all-files >/dev/null 2>&1
in_project git add -A
commit 'tidy up' || true

# `prek install` would write its own hook, which fails on the host. It must not
# touch a tracked file, and `make hooks` must put our hook back.
in_project prek install >/dev/null 2>&1
[ -z "$(in_project git status --porcelain)" ] &&
    ok "prek install does not modify tracked files" ||
    ng "prek install does not modify tracked files"
in_project make -s hooks >/dev/null
cmp -s "$work/scripts/git-hooks/pre-commit" "$installed_hook" &&
    [ ! -e "$installed_hook.before-devcontainer" ] &&
    ok "make hooks replaces a hook generated by prek" ||
    ng "make hooks replaces a hook generated by prek"
rm -f "$installed_hook.legacy"

# A hook of the developer's own is kept aside and comes back with unhooks;
# other hooks in .git/hooks keep running.
in_project make -s unhooks >/dev/null
[ ! -e "$installed_hook" ] && ok "make unhooks removes the hook" ||
    ng "make unhooks removes the hook"
printf '#!/bin/sh\n# my own hook\nexit 0\n' >"$installed_hook"
printf '#!/bin/sh\necho commit-msg-hook-ran >&2\n' >"$work/.git/hooks/commit-msg"
chmod +x "$installed_hook" "$work/.git/hooks/commit-msg"
in_project make -s hooks >/dev/null
grep -q 'my own hook' "$installed_hook.before-devcontainer" 2>/dev/null &&
    ok "make hooks keeps an existing hook aside" ||
    ng "make hooks keeps an existing hook aside"
add_file other_hooks.py 'k = 1'
commit 'other hooks' && grep -q commit-msg-hook-ran "$tmp/commit.log" &&
    ok "other hooks in .git/hooks keep running" ||
    ng "other hooks in .git/hooks keep running"
in_project make -s unhooks >/dev/null
grep -q 'my own hook' "$installed_hook" 2>/dev/null &&
    [ ! -e "$installed_hook.before-devcontainer" ] &&
    ok "make unhooks restores the existing hook" ||
    ng "make unhooks restores the existing hook"
rm -f "$installed_hook" "$work/.git/hooks/commit-msg"

# A core.hooksPath from ~/.gitconfig (copied from the host) would make Git
# ignore .git/hooks: the hook would silently never run.
in_project git config --global core.hooksPath /somewhere/else
in_project make -s hooks >/dev/null
[ "$(in_project git config --get core.hooksPath)" = .git/hooks ] &&
    ok "make hooks overrides a global core.hooksPath for this repository" ||
    ng "make hooks overrides a global core.hooksPath for this repository"
add_file global_hooks_path.py 'g=1'
if commit 'global hooksPath'; then
    ng "the hook runs although a global core.hooksPath is set"
else
    ok "the hook runs although a global core.hooksPath is set"
fi
in_project git reset -q --hard >/dev/null 2>&1
in_project git config --global --unset core.hooksPath
in_project make -s unhooks >/dev/null
[ -z "$(in_project git config --local --get core.hooksPath)" ] &&
    ok "make unhooks removes its core.hooksPath setting" ||
    ng "make unhooks removes its core.hooksPath setting"
# The registration made by the first version of this change is migrated.
in_project git config --local core.hooksPath scripts/git-hooks
in_project make -s hooks >/dev/null
[ -z "$(in_project git config --get core.hooksPath)" ] && [ -x "$installed_hook" ] &&
    ok "make hooks migrates core.hooksPath = scripts/git-hooks" ||
    ng "make hooks migrates core.hooksPath = scripts/git-hooks"

# Checking out a branch must not run code from that branch.
in_project git checkout -q -b with-extra-hook
printf '#!/bin/sh\necho ran-from-branch >"%s/ran"\n' "$tmp" >"$work/scripts/git-hooks/post-checkout"
chmod +x "$work/scripts/git-hooks/post-checkout"
in_project git add scripts/git-hooks/post-checkout
commit 'branch with another hook file' || true
in_project git checkout -q - >/dev/null 2>&1
in_project git checkout -q with-extra-hook >/dev/null 2>&1
[ ! -e "$tmp/ran" ] && ok "checking out a branch does not run its hook files" ||
    ng "checking out a branch does not run its hook files"
in_project git checkout -q - >/dev/null 2>&1
# On a branch without the checks (older than this change) the hook stays quiet.
in_project git checkout -q -b old-branch
in_project git rm -q -r scripts/git-hooks .pre-commit-config.yaml >/dev/null
commit 'branch without the checks' &&
    ok "a branch without .pre-commit-config.yaml can be committed to" ||
    ng "a branch without .pre-commit-config.yaml can be committed to"
in_project git checkout -q - >/dev/null 2>&1

# --- make doctor ---------------------------------------------------------------------
# Every state is set up in the scratch project and a scratch HOME. A case names
# the status word it expects (ok, info, warn or FAIL), a text of that line, and
# the exit status: 1 exactly when a FAIL is expected.
doctor_report=''
doctor_status=0
doctor() {
    # Runs the doctor (offline unless --online is the first argument) with the
    # given environment settings; fills $doctor_report and $doctor_status.
    local mode=--offline
    if [ "${1:-}" = --online ]; then
        mode=''
        shift
    fi
    doctor_report=$(in_project env "$@" bash scripts/doctor.sh $mode 2>&1)
    doctor_status=$?
}
expect() {
    # $1: name, $2: status word, $3: text of that line; uses the last report.
    local want_status=0
    [ "$2" = FAIL ] && want_status=1
    if printf '%s\n' "$doctor_report" | grep -q "^$2 .*$3" &&
        [ "$doctor_status" -eq "$want_status" ]; then
        ok "doctor: $1"
    else
        ng "doctor: $1 (exit $doctor_status)"
        printf '%s\n' "$doctor_report" | grep -E '^(FAIL|warn)' | sed 's/^/       /'
    fi
}
expect_absent() {
    # $1: name, $2: text that must not appear anywhere in the last report.
    if printf '%s\n' "$doctor_report" | grep -q -- "$2"; then
        ng "doctor: $1"
    else
        ok "doctor: $1"
    fi
}
gitconfig() { in_project git config --global "$@"; }

# A prepared checkout: identity, hook, an HTTPS remote and a working helper.
in_project git checkout -q "$(in_project git rev-parse --abbrev-ref HEAD)" 2>/dev/null
in_project make -s hooks >/dev/null
in_project git remote add origin https://github.com/owner/repo.git
helper_ok='!f() { echo username=someone; echo password=ghp_secretsecretsecret1234; }; f'
gitconfig credential.helper "$helper_ok"
doctor
if [ "$doctor_status" -eq 0 ] && ! printf '%s\n' "$doctor_report" | grep -Eq '^(FAIL|warn)'; then
    ok "doctor: a prepared checkout passes without warnings"
else
    ng "doctor: a prepared checkout passes without warnings"
    printf '%s\n' "$doctor_report" | grep -E '^(FAIL|warn)' | sed 's/^/       /'
fi
expect "a shell-function credential helper (the VS Code form) works" ok '認証情報を取得できます'
printf '%s\n' "$doctor_report" | grep -q '開発を始められます' &&
    ok "doctor: says when everything is ready" || ng "doctor: says when everything is ready"

# Nothing secret may be printed: the report is meant to be shared.
expect_absent "does not print the e-mail address" 'doctor@example'
expect_absent "does not print the credential or the helper command" 'secretsecret'
expect_absent "does not print the home directory" "$tmp/home"
gitconfig --replace-all credential.helper '!GH_TOKEN=ghp_tokeninhelper1234567890 /nonexistent/gh auth git-credential'
doctor
expect "a helper that yields nothing fails" FAIL 'github.com の認証情報を取得できません'
expect_absent "does not print a token from a helper command line" 'tokeninhelper'
in_project git remote set-url origin 'https://alice:ghp_tokeninurl1234567890@github.com/owner/repo.git?token=querysecret'
doctor
expect_absent "masks credentials in the remote URL" 'tokeninurl'
expect_absent "masks the query string of the remote URL" 'querysecret'
in_project git remote set-url origin 'alice.smith@corp.example.com:owner/repo.git'
doctor env -u SSH_AUTH_SOCK
expect_absent "masks the user of an SSH remote" 'alice.smith'
in_project git remote set-url origin https://github.com/owner/repo.git

# Credential helpers: what Git would really do decides, not the configuration.
gitconfig --replace-all credential.helper osxkeychain
doctor
expect "a helper that only exists on the host fails" FAIL 'github.com の認証情報を取得できません'
gitconfig --add credential.https://github.com.helper ''
gitconfig --add credential.https://github.com.helper "$helper_ok"
doctor
expect "a host helper that is reset for github.com (gh auth setup-git) passes" ok '認証情報を取得できます'
gitconfig --remove-section credential.https://github.com
gitconfig --unset-all credential.helper
doctor
expect "no credential helper fails for github.com" FAIL 'github.com の認証情報を取得できません'
in_project git remote set-url origin https://git.example.org/owner/repo.git
doctor
expect "no credential helper is a warning for other hosts" warn 'git.example.org の認証情報を取得できません'
in_project git remote set-url origin https://github.com/owner/repo.git
gitconfig credential.helper "$helper_ok"

# Identity.
gitconfig --unset user.email
doctor
expect "a missing user.email fails" FAIL '名前とメールアドレスが決まりません'
doctor GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@example.invalid GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@example.invalid
expect "an identity from the environment passes" ok '環境変数で設定されています'
in_project git config user.email local@example.invalid
doctor
expect "an identity in the repository's own configuration passes" ok '名前とメールアドレスが設定されています'
in_project git config --unset user.email
gitconfig user.email doctor@example.invalid

# Signing is tried with this repository's configuration, and never waits.
in_project git config commit.gpgsign true
gitconfig gpg.program /nonexistent/gpg
doctor
expect "signing set in the repository that cannot work fails" FAIL 'コミットの署名に失敗します'
gitconfig --unset gpg.program
in_project git config --unset commit.gpgsign
ssh-keygen -q -t ed25519 -N '' -f "$tmp/sign_key" </dev/null
ssh-keygen -q -t ed25519 -N 'a passphrase' -f "$tmp/sign_key_locked" </dev/null
gitconfig gpg.format ssh
gitconfig commit.gpgsign true
in_project git config user.signingkey "$tmp/sign_key.pub"
doctor
expect "SSH signing with a key from the repository's configuration passes" ok 'コミットに署名できます'
in_project git config user.signingkey "$tmp/sign_key_locked.pub"
started=$(date +%s)
doctor
expect "a signing key with a passphrase is a warning, not a wait" warn 'パスフレーズの入力が必要です'
[ $(($(date +%s) - started)) -lt 15 ] && ok "doctor: the signing check does not wait for input" ||
    ng "doctor: the signing check does not wait for input"
in_project git config --unset user.signingkey
gitconfig --unset commit.gpgsign
gitconfig tag.gpgsign true
gitconfig gpg.format openpgp
gitconfig gpg.program /nonexistent/gpg
doctor
expect "tag signing that cannot work fails" FAIL 'タグの署名に失敗します'
gitconfig --unset tag.gpgsign
gitconfig --unset gpg.program
gitconfig --unset gpg.format
# A hook from a global core.hooksPath must not run during the signing check.
mkdir -p "$tmp/globalhooks"
printf '#!/bin/sh\ntouch "%s/global-hook-ran"\nexit 1\n' "$tmp" >"$tmp/globalhooks/pre-commit"
chmod +x "$tmp/globalhooks/pre-commit"
gitconfig core.hooksPath "$tmp/globalhooks"
gitconfig commit.gpgsign true
gitconfig gpg.format ssh
in_project git config user.signingkey "$tmp/sign_key.pub"
doctor
[ ! -e "$tmp/global-hook-ran" ] && ok "doctor: the signing check runs no hooks" ||
    ng "doctor: the signing check runs no hooks"
expect "a foreign core.hooksPath is a warning" warn 'core.hooksPath が別の場所'
gitconfig --unset core.hooksPath
gitconfig --unset commit.gpgsign
gitconfig --unset gpg.format
in_project git config --unset user.signingkey

# Hook registration.
in_project make -s unhooks >/dev/null
doctor
expect "an unregistered hook is a warning" warn 'コミット前フックが登録されていません'
in_project prek install >/dev/null 2>&1
doctor
expect "a hook installed by prek is a warning" warn 'prek install が作ったフック'
in_project make -s hooks >/dev/null
printf '# local edit\n' >>"$work/.git/hooks/pre-commit"
doctor
expect "an outdated installed hook is a warning" warn 'リポジトリのものと違います'
in_project make -s hooks >/dev/null
rm -f "$work/.git/hooks/pre-commit.legacy"

# Remotes.
in_project git remote set-url origin git@gitlab.example.org:owner/repo.git
doctor env -u SSH_AUTH_SOCK
expect "an SSH remote without any key fails" FAIL '使える SSH の鍵がありません'
# ssh itself says which key files it would try (defaults and ~/.ssh/config);
# a stand-in ssh reports one that exists.
mkdir -p "$tmp/sshbin"
printf '#!/bin/sh\necho "identityfile %s/sign_key"\n' "$tmp" >"$tmp/sshbin/ssh"
chmod +x "$tmp/sshbin/ssh"
doctor env -u SSH_AUTH_SOCK PATH="$tmp/sshbin:$PATH"
expect "an SSH remote with a key file that ssh would use passes" info '鍵のファイルを使います'
in_project git remote set-url origin git@github.com:owner/repo.git
doctor
expect "a github.com SSH remote is checked as HTTPS" info 'github.com に HTTPS で接続します'
in_project git remote rename origin upstream
doctor
expect "a single remote that is not called origin is used" info 'push 先: upstream'
in_project git remote rename upstream origin
in_project git remote set-url origin https://github.com/owner/repo.git

# Connection checks use the push URL. Use repositories on disk.
git init -q --bare "$tmp/remote.git" 2>/dev/null
in_project git remote set-url origin "$tmp/remote.git"
in_project git push -q origin HEAD >/dev/null 2>&1
doctor --online
expect "a reachable remote passes the connection check" ok 'push 先に接続して'
in_project git remote set-url --push origin "$tmp/proj-4010/missing.git"
doctor --online
expect "an unreachable push URL fails although fetching works" FAIL 'push 先に接続できない'
printf '%s\n' "$doctor_report" | grep -q 'リモートの URL が正しいか' &&
    ok "doctor: a missing repository gets the matching advice" ||
    ng "doctor: a missing repository gets the matching advice"
in_project git config --unset remote.origin.pushurl
in_project git remote set-url origin https://github.com/owner/repo.git

# Working tree, tools, options.
printf 'x=1\n' >"$work/src/needs_format.py"
doctor
expect "an unformatted file is a warning" warn '整形されていないファイルが 1 件'
printf 'def (\n' >"$work/src/needs_format.py"
doctor
expect "a file that ruff cannot parse is reported as such" warn 'ruff で整形を確認できませんでした'
rm -f "$work/src/needs_format.py"
doctor PATH="$tmp/otherbin:$PATH"
expect "a tool of another version is a warning" warn 'ruff の版が requirements.txt と違います'
doctor PATH=/usr/bin:/bin
expect "missing tools fail" FAIL 'ruff が見つかりません'
doctor PATH="$(printf '%s' "$PATH" | sed "s#:*$HOME/.local/bin##")"
expect "~/.local/bin missing from PATH is a warning" warn '~/.local/bin が PATH に入っていません'
printf 'crlf\r\n' >"$work/crlf.txt"
printf 'crlf.txt -text\n' >"$work/.git/info/attributes"
in_project git add crlf.txt
doctor
expect "a file stored with CRLF is a warning" warn 'CRLF で登録されたファイルが 1 件'
in_project git rm -q -f --cached crlf.txt >/dev/null
rm -f "$work/crlf.txt" "$work/.git/info/attributes"
gitconfig core.autocrlf true
doctor
expect "core.autocrlf=true is a warning" warn 'core.autocrlf=true'
gitconfig --unset core.autocrlf
quiet_report=$(in_project bash scripts/doctor.sh --offline --quiet 2>&1)
[ -z "$quiet_report" ] && ok "doctor: --quiet prints nothing when all is well" ||
    ng "doctor: --quiet prints nothing when all is well"
in_project make -s unhooks >/dev/null
quiet_report=$(in_project bash scripts/doctor.sh --offline --quiet 2>&1)
printf '%s\n' "$quiet_report" | grep -q '^warn ' &&
    ! printf '%s\n' "$quiet_report" | grep -Eq '^(ok|info) ' &&
    ok "doctor: --quiet prints only the problems" ||
    ng "doctor: --quiet prints only the problems"
in_project make -s hooks >/dev/null
# Hosts without `timeout` (macOS) use the doctor's own watchdog. It must stop a
# command whose child keeps the output open, pass standard input through, and
# keep the exit status.
limited_test=$(
    have() { [ "$1" != timeout ] && command -v "$1" >/dev/null 2>&1; }
    scratch=$tmp
    eval "$(sed -n '/^limited() {/,/^}/p' "$work/scripts/doctor.sh")"
    started=$(date +%s)
    out=$(limited 2 sh -c 'echo started; sleep 30; echo finished')
    printf 'stop:%s:%s\n' "$out" "$(($(date +%s) - started))"
    printf 'stdin:%s\n' "$(printf 'passed through\n' | limited 5 cat)"
    limited 5 sh -c 'exit 3'
    printf 'status:%s\n' "$?"
)
printf '%s\n' "$limited_test" | grep -Eq '^stop:started:[0-5]$' &&
    ok "doctor: the watchdog stops a command that hangs" ||
    ng "doctor: the watchdog stops a command that hangs ($limited_test)"
printf '%s\n' "$limited_test" | grep -qx 'stdin:passed through' &&
    ok "doctor: the watchdog passes standard input through" ||
    ng "doctor: the watchdog passes standard input through"
printf '%s\n' "$limited_test" | grep -qx 'status:3' &&
    ok "doctor: the watchdog keeps the exit status" ||
    ng "doctor: the watchdog keeps the exit status"
in_project bash scripts/doctor.sh --no-such-option >/dev/null 2>&1
[ $? -eq 2 ] && ok "doctor: an unknown option is rejected" ||
    ng "doctor: an unknown option is rejected"
# Outside a repository, and where Git does not trust the owner.
(cd "$tmp" && HOME="$tmp/home" bash "$work/scripts/doctor.sh" --offline 2>&1) |
    grep -q '^FAIL  Git リポジトリの中で実行してください' &&
    ok "doctor: outside a repository it says so" ||
    ng "doctor: outside a repository it says so"
if (cd "$project" && git rev-parse --show-toplevel 2>&1) | grep -q 'dubious ownership'; then
    (cd "$project" && HOME="$tmp/home" bash scripts/doctor.sh --offline 2>&1) |
        grep -q '^FAIL .*dubious ownership' &&
        ok "doctor: an untrusted owner is reported as such" ||
        ng "doctor: an untrusted owner is reported as such"
else
    ok "doctor: an untrusted owner is reported as such (not applicable here: the owner is trusted)"
fi

if [ "$failures" -ne 0 ]; then
    printf '\n%d check(s) failed\n' "$failures"
    exit 1
fi
printf '\nAll checks passed\n'
