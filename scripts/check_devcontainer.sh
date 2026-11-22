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

# Only the staged files are checked: an unformatted file that is tracked but
# not part of this commit does not stop it (mypy still checks the project).
add_file not_staged.py 'u = 1'
commit 'file that is changed later' || true
printf 'u=2\n' >"$work/src/not_staged.py"
add_file staged.py 's = 1'
commit 'only the staged file is checked' &&
    ok "the commit hook checks the staged files only" ||
    ng "the commit hook checks the staged files only"
in_project git checkout -q -- src/not_staged.py
# A commit started with an empty environment still finds the image's tools.
add_file empty_env.py 'e=1'
if in_project env -i HOME="$tmp/home" /usr/bin/git commit -q -m 'empty environment' >"$tmp/commit.log" 2>&1; then
    ng "a commit with an empty environment is still checked"
elif grep -q 'ruff format.*Failed' "$tmp/commit.log"; then
    ok "a commit with an empty environment is still checked"
else
    ng "a commit with an empty environment is still checked (it failed for another reason)"
fi
in_project git reset -q --hard >/dev/null 2>&1
# A configuration that is tracked but missing from the working tree cannot be
# used by prek: the hook says so and lets the commit through.
mv "$work/.pre-commit-config.yaml" "$tmp/config.saved"
add_file config_missing.py 'c = 1'
commit 'configuration missing from the working tree' &&
    grep -q '設定ファイル.*が作業ツリーにない' "$tmp/commit.log" &&
    ok "a configuration missing from the working tree is reported, not fatal" ||
    ng "a configuration missing from the working tree is reported, not fatal"
# prek also reads the configuration under its other names.
for name in .pre-commit-config.yml prek.toml; do
    if [ "$name" = prek.toml ]; then
        printf '[[repos]]\nrepo = "local"\n\n[[repos.hooks]]\nid = "ruff-format"\nname = "ruff format"\nentry = "ruff format --force-exclude"\nlanguage = "system"\ntypes_or = ["python"]\n' >"$work/$name"
    else
        cp "$tmp/config.saved" "$work/$name"
    fi
    in_project git add "$name"
    add_file other_config.py 'c=2'
    if commit "configuration named $name"; then
        ng "the checks run with a configuration named $name"
    else
        grep -q 'ruff format.*Failed' "$tmp/commit.log" &&
            ok "the checks run with a configuration named $name" ||
            ng "the checks run with a configuration named $name (it failed for another reason)"
    fi
    in_project git rm -q -f --cached "$name" src/other_config.py >/dev/null
    rm -f "$work/$name" "$work/src/other_config.py"
done
mv "$tmp/config.saved" "$work/.pre-commit-config.yaml"
in_project git reset -q --hard >/dev/null 2>&1

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
# The notice names each tool that differs, and nothing else: the unchanged
# requirements.txt (with pip-compile's "name==version \\" lines) gives none.
sed -i 's/^mypy==[^ ]*/mypy==99.0.0/; s/^prek==[^ ]*/prek==99.0.0/' "$work/requirements.txt"
add_file pin_others.py 'q = 1'
commit 'pins of mypy and prek differ' || true
grep -q 'mypy の版が requirements.txt と違います' "$tmp/commit.log" &&
    grep -q 'prek の版が requirements.txt と違います' "$tmp/commit.log" &&
    ! grep -q 'ruff の版が' "$tmp/commit.log" &&
    ok "the version notice names exactly the tools that differ" ||
    ng "the version notice names exactly the tools that differ"
in_project git reset -q --hard >/dev/null 2>&1
add_file no_notice.py 'm = 1'
commit 'no notice when the versions match' && ! grep -q 'の版が' "$tmp/commit.log" &&
    ! grep -q '登録されているコミット前フック' "$tmp/commit.log" &&
    ok "no version notice and no stale notice on an ordinary commit" ||
    ng "no version notice and no stale notice on an ordinary commit"
# A tool that prints a warning before its version, and a pin that is a range.
mkdir -p "$tmp/noisybin"
printf '#!/bin/sh\n[ "$1" = --version ] && echo "warning: something 9.9"\nexec /usr/local/bin/ruff "$@"\n' >"$tmp/noisybin/ruff"
chmod +x "$tmp/noisybin/ruff"
sed -i 's/^mypy==[^ ]*/mypy==2.*/' "$work/requirements.txt"
add_file noisy.py 'y = 1'
commit 'warning line and a range pin' env PATH="$tmp/noisybin:$PATH" || true
! grep -q 'の版が' "$tmp/commit.log" &&
    ok "a warning line or a range pin gives no false version notice" ||
    ng "a warning line or a range pin gives no false version notice"
in_project git checkout -q -- requirements.txt
in_project git reset -q --hard >/dev/null 2>&1

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
in_project git config hooks.devcontainerRunOnHost yes
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
in_project git config hooks.devcontainerRunOnHost false
add_file host_opted_out.py 'f=1'
commit 'host, opt-in set to false' env DEVCONTAINER_HOOK_MARKER=/nonexistent &&
    grep -q 'コミット前の検査を省いてコミットします' "$tmp/commit.log" &&
    ok "hooks.devcontainerRunOnHost=false keeps the checks off on the host" ||
    ng "hooks.devcontainerRunOnHost=false keeps the checks off on the host"
in_project git config --unset hooks.devcontainerRunOnHost
# Outside a repository the hook has nothing to do and must not fail.
(cd "$tmp" && sh "$work/scripts/git-hooks/pre-commit") >/dev/null 2>&1 &&
    ok "the hook exits 0 where Git finds no repository" ||
    ng "the hook exits 0 where Git finds no repository"
# A prek found somewhere else first does not hide the image's Ruff and mypy.
mkdir -p "$tmp/prekbin"
ln -sf /usr/local/bin/prek "$tmp/prekbin/prek"
add_file foreign_prek.py 'r=1'
if commit 'another prek first, short PATH' env PATH="$tmp/prekbin:/usr/bin:/bin"; then
    ng "the image's tools are found although another prek comes first"
else
    grep -q 'ruff format.*Failed' "$tmp/commit.log" &&
        ok "the image's tools are found although another prek comes first" ||
        ng "the image's tools are found although another prek comes first"
fi
in_project git reset -q --hard >/dev/null 2>&1
# In the container the tools are found even when PATH does not list them.
add_file short_path.py 'n=1'
if commit 'container with a short PATH' env PATH=/usr/bin:/bin; then
    ng "in the container the checks run although PATH lacks /usr/local/bin"
else
    grep -q 'ruff format.*Failed' "$tmp/commit.log" &&
        ok "in the container the checks run although PATH lacks /usr/local/bin" ||
        ng "in the container the checks run although PATH lacks /usr/local/bin"
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
    [ ! -e "$installed_hook.before-devcontainer" ] && [ ! -e "$installed_hook.legacy" ] &&
    ok "make hooks replaces a hook generated by prek and leaves nothing behind" ||
    ng "make hooks replaces a hook generated by prek and leaves nothing behind"

# The installed copy says when the repository has another version of the hook.
printf '# changed later\n' >>"$work/scripts/git-hooks/pre-commit"
add_file stale.py 't = 1'
commit 'stale installed hook' || true
grep -q '登録されているコミット前フックが、いまのブランチのものと違います' "$tmp/commit.log" &&
    ok "a stale installed hook says so at commit time" ||
    ng "a stale installed hook says so at commit time"
add_file stale_host.py 't = 2'
commit 'stale installed hook, on the host' env DEVCONTAINER_HOOK_MARKER=/nonexistent &&
    grep -q 'いまのブランチのものと違います' "$tmp/commit.log" &&
    ok "the stale notice is shown on the host too" ||
    ng "the stale notice is shown on the host too"
in_project git checkout -q -- scripts/git-hooks/pre-commit
in_project git reset -q --hard >/dev/null 2>&1

# What belongs to the user is kept. A hook of their own is moved aside and
# comes back with unhooks; other hooks in .git/hooks keep running.
in_project make -s unhooks >/dev/null
[ ! -e "$installed_hook" ] && ok "make unhooks removes the hook" ||
    ng "make unhooks removes the hook"
own_hook() {
    # $1: a comment line for the user's own hook.
    printf '#!/bin/sh\n# my own hook\n%s\nexit 0\n' "$1" >"$installed_hook"
    chmod +x "$installed_hook"
}
own_hook '# nothing special'
printf '#!/bin/sh\necho commit-msg-hook-ran >&2\n' >"$work/.git/hooks/commit-msg"
chmod +x "$work/.git/hooks/commit-msg"
in_project make -s hooks >/dev/null
grep -q 'my own hook' "$installed_hook.before-devcontainer" 2>/dev/null &&
    ok "make hooks keeps an existing hook aside" ||
    ng "make hooks keeps an existing hook aside"
add_file other_hooks.py 'k = 1'
commit 'other hooks' && grep -q commit-msg-hook-ran "$tmp/commit.log" &&
    ok "other hooks in .git/hooks keep running" ||
    ng "other hooks in .git/hooks keep running"
# A second hook of the user's own must not overwrite the one kept aside.
own_hook '# a second hook'
if in_project make -s hooks >/dev/null 2>&1; then
    ng "make hooks refuses to overwrite a hook it keeps aside"
else
    grep -q 'a second hook' "$installed_hook" &&
        grep -q 'nothing special' "$installed_hook.before-devcontainer" &&
        ok "make hooks refuses to overwrite a hook it keeps aside" ||
        ng "make hooks refuses to overwrite a hook it keeps aside"
fi
# unhooks only removes our hook: here the installed one is the user's.
in_project make -s unhooks >/dev/null
grep -q 'a second hook' "$installed_hook" 2>/dev/null &&
    ok "make unhooks leaves a hook that is not ours" ||
    ng "make unhooks leaves a hook that is not ours"
rm -f "$installed_hook"
mv "$installed_hook.before-devcontainer" "$installed_hook"
in_project make -s hooks >/dev/null
in_project make -s unhooks >/dev/null
grep -q 'nothing special' "$installed_hook" 2>/dev/null &&
    [ ! -e "$installed_hook.before-devcontainer" ] &&
    ok "make unhooks restores the existing hook" ||
    ng "make unhooks restores the existing hook"
rm -f "$installed_hook"
# A hook of the user's own that merely mentions our marker, or the words of a
# generated hook, is still theirs.
for words in '# then the devcontainer-python pre-commit hook runs' \
    '# NOT a File generated by pre-commit; my own'; do
    own_hook "$words"
    in_project make -s hooks >/dev/null
    in_project make -s unhooks >/dev/null
    grep -qF "$words" "$installed_hook" 2>/dev/null &&
        ok "a user's hook that mentions '${words#\# }' survives hooks and unhooks" ||
        ng "a user's hook that mentions '${words#\# }' survives hooks and unhooks"
    rm -f "$installed_hook" "$installed_hook.before-devcontainer"
done
# The hook that `prek install` kept as pre-commit.legacy is the user's too.
own_hook '# kept by prek as legacy'
in_project prek install >/dev/null 2>&1
in_project make -s hooks >"$tmp/hooks.log" 2>&1
grep -q '退避しました' "$tmp/hooks.log" && [ ! -e "$installed_hook.legacy" ] &&
    ok "make hooks keeps the hook that prek had kept as legacy, and says so" ||
    ng "make hooks keeps the hook that prek had kept as legacy, and says so"
in_project make -s unhooks >/dev/null
grep -q 'kept by prek as legacy' "$installed_hook" 2>/dev/null &&
    ok "make unhooks restores that hook" || ng "make unhooks restores that hook"
rm -f "$installed_hook"
# The header counts on the second line only, also at the start of another line.
printf '#!/bin/sh\n# my own hook\n# devcontainer-python pre-commit hook (a copy of the header)\nexit 0\n' >"$installed_hook"
chmod +x "$installed_hook"
in_project make -s hooks >/dev/null
in_project make -s unhooks >/dev/null
grep -q 'a copy of the header' "$installed_hook" 2>/dev/null &&
    ok "a user's hook with our header on another line survives hooks and unhooks" ||
    ng "a user's hook with our header on another line survives hooks and unhooks"
rm -f "$installed_hook"
# Hooks written by the Python pre-commit are replaced like prek's.
printf '#!/usr/bin/env bash\n# File generated by pre-commit: https://pre-commit.com\nexec pre-commit hook-impl "$@"\n' >"$installed_hook"
chmod +x "$installed_hook"
in_project make -s hooks >/dev/null
cmp -s "$work/scripts/git-hooks/pre-commit" "$installed_hook" &&
    [ ! -e "$installed_hook.before-devcontainer" ] &&
    ok "make hooks replaces a hook generated by pre-commit" ||
    ng "make hooks replaces a hook generated by pre-commit"
# `prek install` on top of our hook, then unhooks: nothing of either is left.
in_project prek install >/dev/null 2>&1
in_project make -s unhooks >"$tmp/hooks.log" 2>&1
[ ! -e "$installed_hook" ] && [ ! -e "$installed_hook.legacy" ] &&
    grep -q '登録を外しました' "$tmp/hooks.log" &&
    ok "make unhooks also removes what prek install put on top of our hook" ||
    ng "make unhooks also removes what prek install put on top of our hook"
# A pre-commit that is not a regular file (a directory) is kept aside too.
mkdir "$installed_hook"
in_project make -s hooks >/dev/null
[ -d "$installed_hook.before-devcontainer" ] && [ -f "$installed_hook" ] &&
    ok "a pre-commit that is a directory is kept aside" ||
    ng "a pre-commit that is a directory is kept aside"
in_project make -s unhooks >/dev/null
rmdir "$installed_hook"
# Nothing is changed when the installation has to be refused: own hook A is
# aside, own hook B was put in place, then prek install ran on top of it.
own_hook '# hook A'
in_project make -s hooks >/dev/null
own_hook '# hook B'
in_project prek install >/dev/null 2>&1
if in_project make -s hooks >/dev/null 2>&1; then
    ng "a refused installation changes nothing"
else
    grep -q 'generated by prek' "$installed_hook" && grep -q 'hook B' "$installed_hook.legacy" &&
        grep -q 'hook A' "$installed_hook.before-devcontainer" &&
        ok "a refused installation changes nothing" ||
        ng "a refused installation changes nothing"
fi
rm -f "$installed_hook" "$installed_hook.legacy" "$installed_hook.before-devcontainer"
# The hooks directory is created when it is missing.
mv "$work/.git/hooks" "$tmp/hooks.saved"
in_project make -s hooks >/dev/null && [ -x "$installed_hook" ] &&
    ok "make hooks creates a missing hooks directory" ||
    ng "make hooks creates a missing hooks directory"
rm -rf "$work/.git/hooks"
# A hooks directory that is a symbolic link may be shared: nothing is done.
mkdir "$tmp/shared-hooks"
ln -s "$tmp/shared-hooks" "$work/.git/hooks"
in_project make -s hooks >"$tmp/hooks.log" 2>&1
[ -z "$(ls -A "$tmp/shared-hooks")" ] && grep -q 'シンボリックリンク' "$tmp/hooks.log" &&
    ok "a hooks directory that is a symbolic link is left alone" ||
    ng "a hooks directory that is a symbolic link is left alone"
rm -f "$work/.git/hooks"
mv "$tmp/hooks.saved" "$work/.git/hooks"
rm -f "$installed_hook"
# A hook that is a symbolic link is never written through.
printf '#!/bin/sh\n# File generated by pre-commit: shared\nexit 0\n' >"$tmp/shared-hook"
cp "$tmp/shared-hook" "$tmp/shared-hook.orig"
ln -s "$tmp/shared-hook" "$installed_hook"
in_project make -s hooks >/dev/null
in_project make -s unhooks >/dev/null
cmp -s "$tmp/shared-hook" "$tmp/shared-hook.orig" && [ -L "$installed_hook" ] &&
    ok "a hook that is a symbolic link is kept aside, not written through" ||
    ng "a hook that is a symbolic link is kept aside, not written through"
rm -f "$installed_hook" "$work/.git/hooks/commit-msg"

# core.hooksPath belongs to the user: it is never changed, at any level. When it
# makes Git ignore .git/hooks, `make hooks` says so.
in_project git config --global core.hooksPath /somewhere/else
in_project make -s hooks >"$tmp/hooks.log" 2>&1
[ "$(in_project git config --get-all core.hooksPath)" = /somewhere/else ] &&
    [ -z "$(in_project git config --local --get-all core.hooksPath)" ] &&
    ok "make hooks does not change a global core.hooksPath" ||
    ng "make hooks does not change a global core.hooksPath"
grep -q 'Git は .git/hooks を使いません' "$tmp/hooks.log" &&
    ok "make hooks says that the hook will not run with that core.hooksPath" ||
    ng "make hooks says that the hook will not run with that core.hooksPath"
in_project git config --global --unset core.hooksPath
in_project git config --local core.hooksPath .husky
in_project make -s hooks >"$tmp/hooks.log" 2>&1
grep -q 'Git は .git/hooks を使いません' "$tmp/hooks.log" &&
    ok "make hooks also reports a core.hooksPath of the repository" ||
    ng "make hooks also reports a core.hooksPath of the repository"
in_project make -s unhooks >/dev/null 2>&1
[ "$(in_project git config --local --get-all core.hooksPath)" = .husky ] &&
    ok "hooks and unhooks leave the repository's own core.hooksPath alone" ||
    ng "hooks and unhooks leave the repository's own core.hooksPath alone"
in_project git config --local --unset core.hooksPath
# The registration made by the first version of this change is migrated.
in_project git config --local core.hooksPath scripts/git-hooks
in_project make -s hooks >"$tmp/hooks.log" 2>&1
[ -z "$(in_project git config --get-all core.hooksPath)" ] && [ -x "$installed_hook" ] &&
    ! grep -q '注意' "$tmp/hooks.log" &&
    ok "make hooks migrates core.hooksPath = scripts/git-hooks" ||
    ng "make hooks migrates core.hooksPath = scripts/git-hooks"
in_project git config --local core.hooksPath scripts/git-hooks
in_project make -s unhooks >/dev/null 2>&1
[ -z "$(in_project git config --get-all core.hooksPath)" ] &&
    ok "make unhooks removes the old core.hooksPath = scripts/git-hooks too" ||
    ng "make unhooks removes the old core.hooksPath = scripts/git-hooks too"
in_project make -s hooks >/dev/null
# The documented way to chain from a hook of one's own (core.hooksPath): call
# the installed copy if this repository has one. Other repositories are not
# affected, and no file of the checked-out branch is run.
mkdir -p "$tmp/chain-hooks"
cat >"$tmp/chain-hooks/pre-commit" <<'CHAIN'
#!/bin/sh
hook="$(git rev-parse --git-common-dir)/hooks/pre-commit"
[ -x "$hook" ] && exec "$hook" "$@"
exit 0
CHAIN
chmod +x "$tmp/chain-hooks/pre-commit"
in_project git config --global core.hooksPath "$tmp/chain-hooks"
add_file chained.py 'h=1'
if commit 'chained from a core.hooksPath hook'; then
    ng "the documented chaining from a core.hooksPath hook runs the checks"
else
    grep -q 'ruff format.*Failed' "$tmp/commit.log" &&
        ! grep -q 'いまのブランチのものと違います' "$tmp/commit.log" &&
        ok "the documented chaining from a core.hooksPath hook runs the checks" ||
        ng "the documented chaining from a core.hooksPath hook runs the checks"
fi
in_project git reset -q --hard >/dev/null 2>&1
mkdir -p "$tmp/unrelated" && git init -q "$tmp/unrelated" 2>/dev/null
(cd "$tmp/unrelated" && : >f && env -u GIT_CONFIG_GLOBAL HOME="$tmp/home" sh -c \
    'git add f && git commit -q -m "another repository"') >/dev/null 2>&1 &&
    ok "the documented chaining leaves other repositories committable" ||
    ng "the documented chaining leaves other repositories committable"
in_project git config --global --unset core.hooksPath

# Linked worktrees share the hooks directory: the hook runs there too.
in_project git worktree add -q "$tmp/linked" -b linked >/dev/null 2>&1
(cd "$tmp/linked" && HOME="$tmp/home" env -u GIT_CONFIG_GLOBAL make -s hooks >/dev/null 2>&1)
printf 'w=1\n' >"$tmp/linked/src/in_worktree.py"
if (cd "$tmp/linked" && env -u GIT_CONFIG_GLOBAL HOME="$tmp/home" sh -c \
    'git add src/in_worktree.py && git commit -q -m "in a linked worktree"') >"$tmp/commit.log" 2>&1; then
    ng "the hook checks commits in a linked worktree"
else
    grep -q 'ruff format.*Failed' "$tmp/commit.log" &&
        ! grep -q 'いまのブランチのものと違います' "$tmp/commit.log" &&
        ok "the hook checks commits in a linked worktree" ||
        ng "the hook checks commits in a linked worktree (it failed for another reason)"
fi
in_project git worktree remove --force "$tmp/linked" >/dev/null 2>&1
in_project git branch -q -D linked >/dev/null 2>&1

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

# The project as a subdirectory of a larger repository: that repository's
# hooks are not ours to replace.
mkdir -p "$tmp/outer/tools/template" "$tmp/outer/.git-placeholder"
git init -q "$tmp/outer" 2>/dev/null
printf '#!/bin/sh\n# hook of the outer repository\nexit 0\n' >"$tmp/outer/.git/hooks/pre-commit"
chmod +x "$tmp/outer/.git/hooks/pre-commit"
cp -r "$work/scripts" "$work/Makefile" "$tmp/outer/tools/template/"
(cd "$tmp/outer/tools/template" && HOME="$tmp/home" make -s hooks) >"$tmp/hooks.log" 2>&1
grep -q 'hook of the outer repository' "$tmp/outer/.git/hooks/pre-commit" &&
    grep -q '別の Git リポジトリの一部' "$tmp/hooks.log" &&
    ok "inside a larger repository make hooks leaves its hooks alone and says so" ||
    ng "inside a larger repository make hooks leaves its hooks alone and says so"
# Where Git does not trust the owner, the installer fails with the reason
# (so that the Dev Container's postCreateCommand reports it).
if (cd "$project" && git rev-parse --show-toplevel 2>&1) | grep -q 'dubious ownership'; then
    if (cd "$project" && HOME="$tmp/home" sh scripts/git-hooks/install.sh install) >"$tmp/hooks.log" 2>&1; then
        ng "make hooks fails with the reason when Git does not trust the owner"
    else
        grep -q 'dubious ownership' "$tmp/hooks.log" &&
            ok "make hooks fails with the reason when Git does not trust the owner" ||
            ng "make hooks fails with the reason when Git does not trust the owner"
    fi
else
    ok "make hooks fails with the reason when Git does not trust the owner (not applicable here: the owner is trusted)"
fi

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
in_project git remote set-url origin git@gitlab.example.org:owner/repo.git
doctor env -u SSH_AUTH_SOCK
printf '%s\n' "$doctor_report" | grep -q 'push 先: origin（git@gitlab.example.org:owner/repo.git）' &&
    ok "doctor: keeps the conventional git@ user and the host readable" ||
    ng "doctor: keeps the conventional git@ user and the host readable"
in_project git remote set-url origin https://github.com/owner/repo.git
# Names chosen by the user are masked too.
in_project git remote rename origin ghp_remotenamesecret1234567890
in_project git checkout -q -b 'someone@corp.example.com/ghp_branchnamesecret1234'
doctor
expect_absent "masks a token in the remote name" 'remotenamesecret'
expect_absent "masks an address in the branch name" 'someone@corp'
expect_absent "masks a token in the branch name" 'branchnamesecret'
in_project git checkout -q -
in_project git branch -q -D 'someone@corp.example.com/ghp_branchnamesecret1234'
in_project git remote rename ghp_remotenamesecret1234567890 origin
# Each kind of secret, through the doctor's own mask().
masked=$(
    home=/home/someone
    eval "$(sed -n '/^home_pattern=/,/^esac/p; /^mask() {/,/^}/p' "$work/scripts/doctor.sh")"
    printf '%s\n' 'file:/home/someone/.gitconfig' 'https://alice@github.com/o/r' \
        'https://alice:pa/ss@github.com/o/r' 'https://h/o/r?token=querysecret' \
        'ghp_aaaa1111 gho_bbbb2222 github_pat_cccc3333 glpat-dddd4444' \
        'xoxb-eeee5555 AKIAABCDEFGHIJKLMNOP Bearer ffff6666 Basic Z2dnZzc3Nzc=' \
        "$(printf 'ren\351@example.com')" '太郎@example.jp x@localhost' | mask
)
leaks=''
for secret in /home/someone alice 'pa/ss' querysecret aaaa1111 bbbb2222 cccc3333 dddd4444 \
    eeee5555 ABCDEFGHIJKLMNOP ffff6666 Z2dnZzc3Nzc 'ren' '太郎' 'x@'; do
    printf '%s\n' "$masked" | grep -qF -- "$secret" && leaks="$leaks $secret"
done
[ -z "$leaks" ] && ok "doctor: mask() hides every kind of secret it lists" ||
    ng "doctor: mask() hides every kind of secret it lists (leaked:$leaks)"
printf '%s\n' "$masked" | grep -q 'file:~/.gitconfig' && printf '%s\n' "$masked" | grep -q 'github.com/o/r' &&
    ok "doctor: mask() keeps the rest readable" || ng "doctor: mask() keeps the rest readable"
# A home directory that is "/" or contains characters special to sed.
doctor HOME=/
printf '%s\n' "$doctor_report" | grep -q 'https://github.com/owner/repo.git' &&
    ok "doctor: HOME=/ does not garble the report" || ng "doctor: HOME=/ does not garble the report"
mkdir -p "$tmp/h#o&me"
cp "$tmp/home/.gitconfig" "$tmp/h#o&me/.gitconfig"
doctor HOME="$tmp/h#o&me"
printf '%s\n' "$doctor_report" | grep -q 'https://github.com/owner/repo.git' &&
    ! printf '%s\n' "$doctor_report" | grep -q 'unknown option' &&
    ok "doctor: a home directory with # and & does not break the masking" ||
    ng "doctor: a home directory with # and & does not break the masking"

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
# The whole URL is asked about, as a push does: settings per path or per user.
gitconfig credential.useHttpPath true
gitconfig credential.https://github.com/owner/repo.git.helper "$helper_ok"
doctor
expect "a helper configured for the repository path is found" ok '認証情報を取得できます'
gitconfig --unset credential.useHttpPath
gitconfig --remove-section credential.https://github.com/owner/repo.git
in_project git remote set-url origin https://alice@github.com/owner/repo.git
gitconfig credential.helper '!f() { grep -q "^username=bob" || exit 0; echo password=bobstoken1234567890; }; f'
doctor
expect "another user's stored credential does not count" FAIL 'github.com の認証情報を取得できません'
in_project git remote set-url origin https://github.com/owner/repo.git
gitconfig --unset-all credential.helper
# An askpass program is a way to authenticate, but it asks a person: it is
# reported, and it is never run by the doctor.
printf '#!/bin/sh\ntouch "%s/askpass-ran"\necho answer\n' "$tmp" >"$tmp/askpass"
chmod +x "$tmp/askpass"
doctor SSH_ASKPASS="$tmp/askpass"
expect "SSH_ASKPASS counts as an askpass program too" warn '認証情報は保存されていません'
# Other ways to authenticate that the credential helpers do not know about.
printf 'machine github.com login someone password netrcsecret1234\n' >"$tmp/home/.netrc"
chmod 600 "$tmp/home/.netrc"
doctor
expect "authentication through ~/.netrc is recognised" info '~/.netrc の設定で認証します'
expect_absent "does not print the password from ~/.netrc" 'netrcsecret'
rm -f "$tmp/home/.netrc"
in_project git config http.https://github.com/.extraHeader 'Authorization: Basic c29tZW9uZTpzZWNyZXQ='
doctor
expect "authentication through http.extraHeader is recognised" info 'http.extraHeader の設定で認証します'
expect_absent "does not print the header from http.extraHeader" 'c29tZW9uZTpzZWNyZXQ'
in_project git config --unset http.https://github.com/.extraHeader
doctor GIT_ASKPASS="$tmp/askpass"
expect "with an askpass program, missing credentials are a warning" warn '認証情報は保存されていません'
gitconfig core.askPass "$tmp/askpass"
doctor
expect "the same for core.askPass" warn '認証情報は保存されていません'
gitconfig --unset core.askPass
[ ! -e "$tmp/askpass-ran" ] && ok "doctor: does not run the askpass program" ||
    ng "doctor: does not run the askpass program"
# A helper that hangs is given up on.
gitconfig credential.helper '!f() { sleep 61.8033; }; f'
started=$(date +%s)
doctor
elapsed=$(($(date +%s) - started))
# Longer than the limit (the helper really hung), shorter than the helper.
[ "$elapsed" -ge 15 ] && [ "$elapsed" -lt 45 ] && [ "$(pgrep -fc 'sleep 61.8033')" = 0 ] &&
    ok "doctor: a credential helper that hangs is stopped and not left running" ||
    ng "doctor: a credential helper that hangs is stopped and not left running"
gitconfig --replace-all credential.helper "$helper_ok"

# Identity.
gitconfig --unset user.email
doctor
expect "a missing user.email fails" FAIL '名前とメールアドレスが決まりません'
doctor GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@example.invalid GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@example.invalid
expect "an identity from the environment passes" ok '名前とメールアドレスが設定されています'
doctor GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@example.invalid
expect "an author without a committer fails" FAIL '名前とメールアドレスが決まりません'
in_project git config author.email a@example.invalid
in_project git config committer.email c@example.invalid
doctor
expect "an identity from author.* and committer.* passes" ok '名前とメールアドレスが設定されています'
in_project git config --unset author.email
in_project git config --unset committer.email
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
objects_before=$(in_project git count-objects -v | tr '\n' ' ')
doctor
expect "SSH signing with a key from the repository's configuration passes" ok 'コミットに署名できます'
[ "$(in_project git count-objects -v | tr '\n' ' ')" = "$objects_before" ] &&
    ok "doctor: the signing check writes nothing into the repository" ||
    ng "doctor: the signing check writes nothing into the repository"
in_project git config user.signingkey "$tmp/sign_key_locked.pub"
started=$(date +%s)
doctor
expect "a signing key with a passphrase is a warning, not a wait" warn '署名で、入力を求められました'
[ $(($(date +%s) - started)) -lt 15 ] && ok "doctor: the signing check does not wait for input" ||
    ng "doctor: the signing check does not wait for input"
in_project git config --unset user.signingkey
gitconfig --unset commit.gpgsign
gitconfig tag.gpgsign true
gitconfig gpg.format openpgp
gitconfig gpg.program /nonexistent/gpg
doctor
expect "tag signing that cannot work fails" FAIL 'タグの署名に失敗します'
printf '%s\n' "$doctor_report" | grep -q 'git config tag.gpgsign false' &&
    ok "doctor: the advice names the setting that is on" ||
    ng "doctor: the advice names the setting that is on"
# A missing smartcard is a failure, not "needs a passphrase".
printf '#!/bin/sh\necho "gpg: signing failed: No such device" >&2\nexit 2\n' >"$tmp/gpg-card"
chmod +x "$tmp/gpg-card"
gitconfig gpg.program "$tmp/gpg-card"
doctor
expect "a missing smartcard fails" FAIL 'タグの署名に失敗します'
# An error that names the key's owner does not show the name.
cat >"$tmp/gpg-name" <<'STUB'
#!/bin/sh
echo 'gpg: skipped "Alice Example <alice@corp.example>": No secret key' >&2
exit 2
STUB
chmod +x "$tmp/gpg-name"
gitconfig gpg.program "$tmp/gpg-name"
doctor
printf '%s\n' "$doctor_report" | grep -q 'gpg: skipped' &&
    ok "doctor: shows the reason of a signing failure" ||
    ng "doctor: shows the reason of a signing failure"
# A key name that happens to contain "pinentry" or "passphrase" does not turn
# the failure into a warning; names in single quotes are not shown either.
cat >"$tmp/gpg-name" <<'STUB'
#!/bin/sh
echo "gpg: skipped \"pinentry passphrase <key@corp.example>\": No secret key for 'Bob Example'" >&2
exit 2
STUB
doctor
expect "a quoted key name does not change a failure into a warning" FAIL 'タグの署名に失敗します'
expect_absent "does not print a single-quoted name from an error" 'Bob Example'
# The user's Git tracing does not end up in the report.
doctor GIT_TRACE=1 GIT_CURL_VERBOSE=1
expect_absent "does not show Git trace output" 'run_command'
expect_absent "does not print the key owner's name from an error" 'Alice Example'
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
chmod -x "$work/.git/hooks/pre-commit"
doctor
expect "an installed hook that is not executable is a warning" warn '実行権限がありません'
in_project make -s hooks >/dev/null
rm -f "$work/.git/hooks/pre-commit.legacy"

# Remotes.
in_project git remote set-url origin git@gitlab.example.org:owner/repo.git
doctor env -u SSH_AUTH_SOCK
expect "an SSH remote without any key fails" FAIL '使える SSH の鍵がありません'
# ssh itself says which agent and key files it would use (defaults and
# ~/.ssh/config); a stand-in ssh reports them.
mkdir -p "$tmp/sshbin" "$tmp/my keys"
cp "$tmp/sign_key" "$tmp/my keys/id"
stub_ssh() { printf '#!/bin/sh\n%s\n' "$1" >"$tmp/sshbin/ssh" && chmod +x "$tmp/sshbin/ssh"; }
stub_ssh "echo 'identityfile $tmp/my keys/id'"
doctor env -u SSH_AUTH_SOCK PATH="$tmp/sshbin:$PATH"
expect "a key file that ssh would use (with a space in its path) passes" info '鍵のファイルを使います'
eval "$(ssh-agent -s -a "$tmp/agent.sock")" >/dev/null
ssh-add -q "$tmp/sign_key" 2>/dev/null
doctor SSH_AUTH_SOCK="$tmp/agent.sock"
expect "a key in the SSH agent passes" ok 'SSH エージェントに鍵があります（1 件）'
stub_ssh "echo 'identityagent $tmp/agent.sock'"
doctor env -u SSH_AUTH_SOCK PATH="$tmp/sshbin:$PATH"
expect "an agent named by IdentityAgent in the ssh configuration passes" ok 'SSH エージェントに鍵があります'
kill "$SSH_AGENT_PID" 2>/dev/null
unset SSH_AUTH_SOCK SSH_AGENT_PID
# ssh matches host aliases by case: the alias is passed on as written.
stub_ssh "[ \"\$2\" = MyGit ] && echo 'identityfile $tmp/my keys/id'"
in_project git remote set-url origin MyGit:owner/repo.git
doctor env -u SSH_AUTH_SOCK PATH="$tmp/sshbin:$PATH"
expect "an SSH host alias with capital letters is looked up as written" info '鍵のファイルを使います'
in_project git remote set-url origin git@gitlab.example.org:owner/repo.git
gitconfig core.sshCommand "$tmp/sshbin/ssh"
doctor env -u SSH_AUTH_SOCK
expect "with a custom ssh command the keys are not judged" info '独自の ssh コマンド'
gitconfig --unset core.sshCommand
in_project git remote set-url origin git://git.example.org/owner/repo.git
doctor
expect "a git:// push URL is a warning" warn 'git:// 形式'
in_project git remote set-url origin 'ext::sh -c "touch '"$tmp"'/ext-ran"'
doctor --online
[ ! -e "$tmp/ext-ran" ] && ok "doctor: a remote-helper URL is not executed" ||
    ng "doctor: a remote-helper URL is not executed"
in_project git remote set-url origin git@github.com:owner/repo.git
doctor
expect "a github.com SSH remote is checked as HTTPS" info 'github.com に HTTPS で接続します'
in_project git remote rename origin upstream
doctor
expect "a single remote that is not called origin is used" info 'push 先: upstream'
in_project git remote rename upstream origin
in_project git remote add other https://git.example.org/other/repo.git
gitconfig remote.pushDefault other
in_project git config "branch.$(in_project git symbolic-ref --short HEAD).remote" origin
doctor
expect "remote.pushDefault wins over the branch's own remote" info 'push 先: other'
in_project git config --unset "branch.$(in_project git symbolic-ref --short HEAD).remote"
gitconfig remote.pushDefault missing-remote
doctor
expect "a push remote that does not exist is a warning" warn 'リモート（missing-remote）がありません'
gitconfig --unset remote.pushDefault
in_project git remote remove other
in_project git checkout -q --detach
doctor
expect "a detached HEAD is mentioned" info 'detached HEAD'
in_project git checkout -q -
# A branch that tracks a local branch (remote ".") is not a missing remote.
in_project git checkout -q -b local-tracking --track "$(in_project git rev-parse --abbrev-ref HEAD)"
doctor
expect_absent "a branch tracking a local branch is not reported as a missing remote" 'リモート（.）'
in_project git checkout -q -
in_project git branch -q -D local-tracking
# A value from .git/config cannot add lines to the report or control the terminal.
in_project git config remote.origin.url "$(printf 'https://example.org/a\nok    すべて問題ありません\033[2J')"
doctor
printf '%s\n' "$doctor_report" | grep -q '^ok    すべて問題ありません' &&
    ng "doctor: a value with a line break cannot forge a report line" ||
    ok "doctor: a value with a line break cannot forge a report line"
printf '%s\n' "$doctor_report" | LC_ALL=C grep -q "$(printf '\033')" &&
    ng "doctor: escape sequences are removed from the report" ||
    ok "doctor: escape sequences are removed from the report"
in_project git remote set-url origin https://github.com/owner/repo.git
in_project git remote set-url origin https://GitHub.com/owner/repo.git
gitconfig --unset-all credential.helper
doctor
expect "the host name is compared without regard to case" FAIL 'github.com の認証情報を取得できません'
gitconfig credential.helper "$helper_ok"
in_project git remote set-url origin https://github.com/owner/repo.git
# A host setting that turns HTTPS back into SSH, on top of the image's rule: the
# connection must go where a push goes (HTTPS), not through a second rewrite.
gitconfig url.git@github.com:.insteadOf https://github.com/
in_project git remote set-url origin git@github.com:owner/repo.git
stub_ssh "touch '$tmp/ssh-was-used'"
doctor --online PATH="$tmp/sshbin:$PATH"
[ ! -e "$tmp/ssh-was-used" ] &&
    ok "doctor: the connection check does not rewrite the push URL a second time" ||
    ng "doctor: the connection check does not rewrite the push URL a second time"
gitconfig --remove-section url.git@github.com:
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
in_project git remote set-url --add --push origin "$tmp/remote.git"
in_project git remote set-url --add --push origin "$tmp/second-missing.git"
doctor --online
expect "every push URL is checked, not only the first" FAIL 'push 先に接続できない'
in_project git config --unset-all remote.origin.pushurl
# The user's credential helpers are only ever asked to "get": a server that
# refuses the credential must not make Git erase it, and none is stored.
python "$work/scripts/http_401_server.py" 8765 &
server_pid=$!
sleep 1
printf '#!/bin/sh\necho "$1" >>"%s/helper.log"\n[ "$1" = get ] && { echo username=u; echo password=storedtoken1234; }\nexit 0\n' "$tmp" >"$tmp/logging-helper"
chmod +x "$tmp/logging-helper"
gitconfig --replace-all credential.helper "$tmp/logging-helper"
gitconfig --add credential.helper cache
in_project git remote set-url origin http://127.0.0.1:8765/owner/repo.git
doctor --online
expect "a refused credential fails the connection check" FAIL 'push 先に接続できない'
printf '%s\n' "$doctor_report" | grep -q '認証に失敗しています' &&
    ok "doctor: a refused credential gets the advice about authentication" ||
    ng "doctor: a refused credential gets the advice about authentication"
[ "$(sort -u "$tmp/helper.log" | tr '\n' ' ')" = 'get ' ] &&
    ok "doctor: the user's credential helper is only asked to get" ||
    ng "doctor: the user's credential helper is only asked to get ($(tr '\n' ' ' <"$tmp/helper.log"))"
[ "$(pgrep -fc 'credential-cache--daemon')" = 0 ] && [ ! -e "$tmp/home/.git-credentials" ] &&
    ok "doctor: no credential is stored and no credential daemon is started" ||
    ng "doctor: no credential is stored and no credential daemon is started"
expect_absent "does not print the stored credential" 'storedtoken'
kill "$server_pid" 2>/dev/null
wait "$server_pid" 2>/dev/null
gitconfig --replace-all credential.helper "$helper_ok"
in_project git remote set-url origin https://github.com/owner/repo.git
# gh is asked whether it is logged in (a stand-in gh says yes).
mkdir -p "$tmp/ghbin"
printf '#!/bin/sh\n[ "$1 $2" = "auth token" ] && { echo ghp_fromghstub123456; exit 0; }\nexit 1\n' >"$tmp/ghbin/gh"
chmod +x "$tmp/ghbin/gh"
doctor PATH="$tmp/ghbin:$PATH"
expect "a logged-in gh is reported" ok 'gh で github.com に認証済みです'
expect_absent "does not print the token that gh returns" 'fromghstub'
# VS Code extensions (a stand-in `code`).
mkdir -p "$tmp/codebin"
printf '#!/bin/sh\nprintf "%%s\\n" ms-python.python MS-Python.Vscode-Pylance ms-python.debugpy\n' >"$tmp/codebin/code"
chmod +x "$tmp/codebin/code"
doctor PATH="$tmp/codebin:$PATH"
expect "a missing required extension is a warning" warn 'charliermarsh.ruff が入っていません'
printf '%s\n' "$doctor_report" | grep -q '^ok    ms-python.vscode-pylance' &&
    ok "doctor: extension names are compared without regard to case" ||
    ng "doctor: extension names are compared without regard to case"
printf '#!/bin/sh\nexit 1\n' >"$tmp/codebin/code"
doctor PATH="$tmp/codebin:$PATH"
expect "a code command that cannot reach VS Code is not a warning" info 'VS Code に接続できない'
# Outside the dev container (no image marker): said so, tools are not judged.
doctor DEVCONTAINER_HOOK_MARKER=/nonexistent PATH=/usr/bin:/bin
expect "outside the dev container it says so and skips the tools" info 'ツールの版と整形は確認しません'
expect_absent "outside the dev container, missing tools are not failures" 'が見つかりません'
# Nothing is left behind in the temporary directory.
mkdir -p "$tmp/doctor-tmp"
doctor TMPDIR="$tmp/doctor-tmp"
[ -z "$(ls -A "$tmp/doctor-tmp")" ] && ok "doctor: leaves nothing in the temporary directory" ||
    ng "doctor: leaves nothing in the temporary directory"
doctor TMPDIR="$tmp/no-such-directory"
expect "an unusable TMPDIR is reported" FAIL '一時ディレクトリを作れません'

# Working tree, tools, options.
status_before=$(in_project git status --porcelain --ignored)
doctor
[ "$(in_project git status --porcelain --ignored)" = "$status_before" ] &&
    ok "doctor: creates no file in the working tree (not even an ignored cache)" ||
    ng "doctor: creates no file in the working tree (not even an ignored cache)"
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
expect "core.autocrlf=true is a warning" warn 'core.autocrlf が有効です'
gitconfig core.autocrlf yes
doctor
expect "core.autocrlf=yes is a warning as well" warn 'core.autocrlf が有効です'
gitconfig --unset core.autocrlf
quiet_report=$(in_project bash scripts/doctor.sh --offline --quiet 2>&1)
[ -z "$quiet_report" ] && ok "doctor: --quiet prints nothing when all is well" ||
    ng "doctor: --quiet prints nothing when all is well"
in_project make -s unhooks >/dev/null
quiet_report=$(in_project bash scripts/doctor.sh --offline --quiet 2>&1)
printf '%s\n' "$quiet_report" | grep -q '^warn ' &&
    [ "$(printf '%s\n' "$quiet_report" | head -n 1)" = '== コミット前フック' ] &&
    ! printf '%s\n' "$quiet_report" | grep -Eq '^(ok|info) ' &&
    ok "doctor: --quiet prints only the problems" ||
    ng "doctor: --quiet prints only the problems"
in_project make -s hooks >/dev/null
# The doctor's time limit: it must stop a command whose child keeps the output
# open, leave no process behind, pass standard input through and keep the
# exit status.
limited_test=$(
    scratch=$tmp
    # Without pgrep (Git for Windows has none): the process list comes from ps.
    have() { [ "$1" != pgrep ] && command -v "$1" >/dev/null 2>&1; }
    cleanup() { :; }
    eval "$(sed -n '/^children_of() {/,/^}/p; /^tree_of() {/,/^}/p; /^kill_tree() {/,/^}/p; /^on_signal() {/,/^}/p; /^limited() {/,/^}/p' "$work/scripts/doctor.sh")"
    limited_pid=''
    started=$(date +%s)
    out=$(limited 2 sh -c 'echo started; sleep 31.4159; echo finished')
    printf 'stop:%s:%s\n' "$out" "$(($(date +%s) - started))"
    # Repeatedly, with a grandchild: the caller must wait until the whole
    # tree is stopped (stopping only starts when the limit is reached).
    for round in 1 2 3 4 5 6; do
        limited 1 sh -c 'sh -c "sleep 27.1828; :"; :' >/dev/null
    done
    printf 'left:%s\n' "$(pgrep -fc 'sleep 31.4159|sleep 27.1828')"
    # A child that ignores the request to stop, under a parent that obeys it,
    # is stopped by force, and the caller waits for that.
    limited 1 sh -c 'sh -c "trap \"\" TERM; : stubborn-7f3a; while :; do sleep 0.2; done" & wait' >/dev/null
    printf 'stubborn:%s\n' "$(pgrep -fc 'stubborn-7f3a')"
    printf 'stdin:%s\n' "$(printf 'passed through\n' | limited 5 cat)"
    limited 5 sh -c 'exit 3'
    printf 'status:%s\n' "$?"
)
printf '%s\n' "$limited_test" | grep -Eq '^stop:started:[0-5]$' &&
    ok "doctor: the time limit stops a command that hangs" ||
    ng "doctor: the time limit stops a command that hangs ($limited_test)"
printf '%s\n' "$limited_test" | grep -qx 'left:0' &&
    ok "doctor: the time limit leaves no process behind" ||
    ng "doctor: the time limit leaves no process behind"
printf '%s\n' "$limited_test" | grep -qx 'stubborn:0' &&
    ok "doctor: the time limit stops a command that ignores the request" ||
    ng "doctor: the time limit stops a command that ignores the request"
printf '%s\n' "$limited_test" | grep -qx 'stdin:passed through' &&
    ok "doctor: the time limit passes standard input through" ||
    ng "doctor: the time limit passes standard input through"
printf '%s\n' "$limited_test" | grep -qx 'status:3' &&
    ok "doctor: the time limit keeps the exit status" ||
    ng "doctor: the time limit keeps the exit status"
in_project bash scripts/doctor.sh --no-such-option >/dev/null 2>&1
[ $? -eq 2 ] && ok "doctor: an unknown option is rejected" ||
    ng "doctor: an unknown option is rejected"
# Outside a repository, and where Git does not trust the owner.
(cd "$tmp" && HOME="$tmp/home" bash "$work/scripts/doctor.sh" --offline 2>&1) |
    grep -q '^FAIL  Git の作業ツリーの中で実行してください' &&
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
