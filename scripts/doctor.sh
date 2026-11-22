#!/usr/bin/env bash
# Check that this checkout, in this container, is ready for development:
#   make doctor            (or: bash scripts/doctor.sh)
# Options:
#   --quiet     print only warnings and failures
#
# scripts/check_devcontainer.sh checks the image (run by CI). This script checks
# what differs per person and per start: Git identity, signing, credentials,
# hooks, the remote. Each warning or failure comes with what to do about it.
#
# Rules that shape the code:
# - Ask Git instead of re-implementing it. Whether credentials or a signature
#   can be produced is decided by running Git, in this repository, not by
#   reading configuration values.
# - Stay local. Nothing is sent anywhere: no connection to the remote, no
#   credential leaves this machine. Whether a push really works is for the
#   first push to show. (An earlier version read the remote with the obtained
#   credential; three reviews each found a way for that to go wrong.)
# - Change nothing. The user's credential helpers are only asked to "get", and
#   what they answer is looked at in a pipe, never written to a file.
# - Never wait: prompts are disabled and every external command runs through
#   limited().
# - The output is meant to be pasted into an issue. Every line is printed by
#   ok/info/warn/fail/hint/detail, and those mask what they print.
#
# Bash 3.2 (macOS) compatible: no arrays, no ${var,,}, POSIX sed/grep only.
set -u

quiet=0
for argument in "$@"; do
    case $argument in
        --quiet) quiet=1 ;;
        -h | --help)
            sed -n '2,5s/^# \{0,1\}//p' "$0"
            exit 0
            ;;
        *)
            printf '不明なオプションです: %s\n' "$argument" >&2
            exit 2
            ;;
    esac
done

# The user's tracing settings would fill the error text shown below with
# command lines; this run does not need them.
unset GIT_TRACE GIT_TRACE_SETUP GIT_TRACE_PACKET GIT_TRACE_CURL GIT_TRACE2 \
    GIT_TRACE2_EVENT GIT_TRACE2_PERF GIT_CURL_VERBOSE GIT_TRACE_REDACT 2>/dev/null

home=${HOME:-}
# The home directory of the account, even when HOME points elsewhere (ssh and
# the image's PATH use this one).
account_home=$(getent passwd "$(id -un 2>/dev/null)" 2>/dev/null | cut -d: -f6)
account_home=${account_home:-$home}
# The file that only the image of this repository contains (the same test as
# the commit hook; the variable exists for the tests).
marker=${DEVCONTAINER_HOOK_MARKER:-/etc/devcontainer/bashrc}

have() { command -v "$1" >/dev/null 2>&1; }

# Hide what should not end up in a public issue: the home directory (it holds
# the OS user name), credentials and query strings in URLs, e-mail addresses
# (anything@host, so also non-ASCII local parts) and common token formats.
# The conventional SSH user "git@" is kept. LC_ALL=C: bytes, so that invalid
# UTF-8 neither hides an address nor stops sed.
home_pattern=''
case $home in
    '' | / | *'
'*) ;; # nothing sensible to replace
    *) home_pattern=$(printf '%s' "${home%/}" | LC_ALL=C sed 's/[][\\.*^$#]/\\&/g') ;;
esac
mask() {
    # The home directory only as a whole path component (/home/al is not a
    # prefix of /home/alice).
    LC_ALL=C sed -e "s#${home_pattern:-^/nonexistent-home-directory\$}\([^A-Za-z0-9._-]\)#~\1#g" \
        -e "s#${home_pattern:-^/nonexistent-home-directory\$}\$#~#" \
        -e 's#\(://\)[^/@[:space:]]*@#\1***@#g' \
        -e 's#\(://\)[^@[:space:]]*:[^@[:space:]]*@#\1***@#g' \
        -e 's#\(://[^[:space:]?]*\)?[^[:space:]]*#\1?***#g' \
        -e 's/^git@/git%AT%/' \
        -e 's/\([^A-Za-z0-9._-]\)git@/\1git%AT%/g' \
        -e 's/[^][:space:]@\/:<>()"'"'"']\{1,\}@\([A-Za-z0-9.-]\{1,\}\)/***@\1/g' \
        -e 's/git%AT%/git@/g' \
        -e 's/\(gh[opsur]_\)[A-Za-z0-9_]\{1,\}/\1***/g' \
        -e 's/\(github_pat_\)[A-Za-z0-9_]\{1,\}/\1***/g' \
        -e 's/\(glpat-\)[A-Za-z0-9_-]\{1,\}/\1***/g' \
        -e 's/\(xox[abprs]-\)[A-Za-z0-9-]\{1,\}/\1***/g' \
        -e 's/\(AKIA\)[A-Z0-9]\{12,\}/\1***/g' \
        -e 's/\([Bb]earer \)[^[:space:]]\{1,\}/\1***/g' \
        -e 's/\([Bb]asic \)[A-Za-z0-9+\/=]\{4,\}/\1***/g'
}

warnings=0
failures=0
section_title=''
section_printed=1
first_section=1
section() {
    section_title=$1
    section_printed=0
    [ "$quiet" -eq 1 ] || print_section
}
print_section() {
    [ "$section_printed" -eq 1 ] && return
    [ "$first_section" -eq 1 ] || printf '\n'
    first_section=0
    printf '== %s\n' "$section_title"
    section_printed=1
}
# Every line of the report goes through these, and through mask().
# A value with a line break or an escape sequence (a branch or remote name, a
# URL from .git/config) must not be able to add lines to the report or to
# control the terminal.
plain() { LC_ALL=C tr -d '\000-\010\013-\037\177'; }
line() {
    printf '%s%s' "$1" "$2" | LC_ALL=C tr '\n\r' '  ' | plain | mask
    printf '\n'
}
ok() { [ "$quiet" -eq 1 ] || line 'ok    ' "$1"; }
info() { [ "$quiet" -eq 1 ] || line 'info  ' "$1"; }
note() { [ "$quiet" -eq 1 ] || line '      → ' "$1"; } # advice under an info line
hint() { line '      → ' "$1"; }
detail() { LC_ALL=C tr -d '\r' | plain | mask | sed 's/^/      /'; } # error text from a command, on stdin
warn() {
    print_section
    line 'warn  ' "$1"
    warnings=$((warnings + 1))
}
fail() {
    print_section
    line 'FAIL  ' "$1"
    failures=$((failures + 1))
}

scratch=$(mktemp -d 2>/dev/null) || scratch=''
limited_pid=''
# Print the process ids of $1 and all its descendants (a snapshot: once a
# parent is gone, its children can no longer be found through it).
children_of() {
    # POSIX ps first (also where pgrep is missing), pgrep as a fallback.
    local list
    list=$(ps -A -o pid= -o ppid= 2>/dev/null | awk -v parent="$1" '$2 == parent { print $1 }')
    if [ -z "$list" ] && have pgrep; then list=$(pgrep -P "$1" 2>/dev/null); fi
    printf '%s\n' "$list"
}
tree_of() {
    local child
    printf '%s\n' "$1"
    for child in $(children_of "$1"); do tree_of "$child"; done
}
kill_tree() {
    # $1: process id, $2: signal name.
    local pid
    for pid in $(tree_of "$1"); do kill "-$2" "$pid" 2>/dev/null; done
}
# shellcheck disable=SC2329 # called by the traps below
cleanup() {
    [ -n "$limited_pid" ] && kill_tree "$limited_pid" TERM
    [ -n "$scratch" ] && rm -rf "$scratch"
}
# shellcheck disable=SC2329 # called by the traps below
on_signal() {
    cleanup
    exit 130
}
trap cleanup EXIT
trap on_signal INT TERM

# Run a command for at most $1 seconds. GNU `timeout` is not used: it is
# missing on macOS, and it delays Ctrl-C. The output goes through a file: a
# child of the command that outlives it (ssh, a credential helper) would
# otherwise keep a surrounding $(...) or pipe waiting. `<&0` keeps the caller's
# standard input, which a background command would otherwise lose.
limited() {
    local seconds=$1
    shift
    local output="$scratch/limited.out.$$.$RANDOM"
    trap on_signal INT TERM # also inside $(...), where traps are reset
    "$@" <&0 >"$output" &
    limited_pid=$!
    (
        trap - INT TERM EXIT
        sleep "$seconds"
        # From here on the caller waits for this watchdog to finish, so that
        # no descendant of the command is left running.
        : >"$output.expired"
        processes=$(tree_of "$limited_pid")
        for pid in $processes; do kill -TERM "$pid" 2>/dev/null; done
        sleep 2
        for pid in $processes; do kill -KILL "$pid" 2>/dev/null; done
    ) >/dev/null 2>&1 &
    local watchdog=$!
    wait "$limited_pid" 2>/dev/null
    local status=$?
    if [ -e "$output.expired" ]; then
        wait "$watchdog" 2>/dev/null
        status=143
    else
        kill_tree "$watchdog" TERM
        wait "$watchdog" 2>/dev/null
    fi
    limited_pid=''
    cat "$output" 2>/dev/null
    rm -f "$output" "$output.expired"
    return "$status"
}

finish() {
    if [ "$quiet" -eq 0 ] || [ $((failures + warnings)) -gt 0 ]; then
        printf '\n結果: FAIL %d 件、warn %d 件\n' "$failures" "$warnings"
    fi
    if [ "$failures" -gt 0 ]; then
        printf 'FAIL の項目を直してから、もう一度 make doctor を実行してください。\n'
        exit 1
    fi
    [ "$warnings" -eq 0 ] && [ "$quiet" -eq 0 ] && printf '開発を始められます。\n'
    exit 0
}

# --- Where am I ----------------------------------------------------------------
section '実行場所'
in_container=0
if [ -r "$marker" ]; then
    in_container=1
    ok 'この Dev Container のイメージの中で実行しています'
    if [ "${CODESPACES:-}" = true ]; then
        info 'GitHub Codespaces で実行しています（停止するまで、利用時間に数えられます）'
    fi
elif [ -e /.dockerenv ] || [ -n "${REMOTE_CONTAINERS:-}${CODESPACES:-}" ]; then
    warn '別のイメージのコンテナの中で実行しています。以下の結果は参考です'
    hint 'このリポジトリの .devcontainer で作ったコンテナで開き直してください。'
else
    warn 'ここは Dev Container の外（ホスト）です。以下の結果は参考です'
    hint 'VS Code で「コンテナーで再度開く」を実行し、コンテナ内でコミットと push をしてください。'
fi

if [ -z "$scratch" ]; then
    fail '一時ディレクトリを作れません（確認を続けられません）'
    hint '環境変数 TMPDIR が、書き込めるディレクトリを指しているかを確かめてください。'
    finish
fi
if ! have git; then
    fail 'git が見つかりません'
    finish
fi
if ! root=$(git rev-parse --show-toplevel 2>"$scratch/rev-parse.err"); then
    if grep -q 'dubious ownership' "$scratch/rev-parse.err"; then
        # Git names the repository it refuses: "... repository at '/path'".
        refused=$(sed -n "s/.*dubious ownership in repository at '\(.*\)'.*/\1/p" "$scratch/rev-parse.err" | head -n 1)
        fail 'Git が、このリポジトリの所有者を信頼していません（dubious ownership）。Git の操作がすべて失敗します'
        hint "git config --global --add safe.directory \"${refused:-<リポジトリのディレクトリ>}\" を実行してください。"
    else
        fail 'Git の作業ツリーの中で実行してください（.git の中や、作業ツリーのないリポジトリでは実行できません）'
    fi
    finish
fi
ok 'Git がこのリポジトリを操作できます'
lock="$root/requirements.txt"

# --- Tools -----------------------------------------------------------------------
section 'ツール'
pinned() { sed -n "s/^$1==\([0-9][0-9A-Za-z.+!-]*\).*/\1/p" "$lock" 2>/dev/null | head -n 1; }
version_of() {
    limited 15 "$1" --version 2>/dev/null </dev/null | head -n 1 |
        sed 's/^[^0-9]*\([0-9][0-9A-Za-z.+-]*\).*/\1/'
}
if [ "$in_container" -eq 0 ]; then
    info 'Dev Container の外では、ツールの版と整形は確認しません（検査は Dev Container 内と CI で行います）'
else
    # command:package pairs; the package name is the one in requirements.txt.
    for pair in ruff:ruff mypy:mypy pytest:pytest prek:prek ptw:pytest-watcher; do
        tool=${pair%%:*}
        want=$(pinned "${pair##*:}")
        if ! have "$tool"; then
            fail "$tool が見つかりません"
            hint 'Dev Container をリビルドしてください（VS Code: Dev Containers: Rebuild Container）。'
            continue
        fi
        got=$(version_of "$tool")
        if [ -n "$want" ] && [ "$got" != "$want" ]; then
            warn "$tool の版が requirements.txt と違います（必要: ${want}、実際: ${got:-不明}、場所: $(command -v "$tool")）"
            hint 'Dev Container をリビルドしてください。後から pip install で入れた別の版があれば、pip uninstall で外してください。'
        else
            ok "$tool $got"
        fi
    done
    for tool in gh ssh; do
        if have "$tool"; then ok "$tool があります"; else
            warn "$tool が見つかりません"
            hint 'Dev Container をリビルドしてください。'
        fi
    done
    case ":$PATH:" in
        *":$account_home/.local/bin:"*) ok '~/.local/bin が PATH に入っています' ;;
        *)
            warn '~/.local/bin が PATH に入っていません（pip install で入れたコマンドが見つかりません）'
            hint 'Dev Container をリビルドしてください。'
            ;;
    esac
    if have python; then
        user_packages=$(limited 20 python -m pip list --user --format=freeze 2>/dev/null </dev/null |
            sed 's/[=@ ].*//' | tr '\n' ' ')
        if [ -n "$(printf '%s' "$user_packages" | tr -d ' ')" ]; then
            info "後から pip install で入れたパッケージ: $user_packages"
            note 'コンテナを作り直すと消えます。続けて使うものは requirements.in に足してください（README「ターミナル」）。'
        fi
    fi
fi

# --- VS Code extensions ------------------------------------------------------------
section 'VS Code の拡張'
if ! have code; then
    info 'code コマンドがないため、拡張は確認していません（VS Code の統合ターミナルで実行すると確認できます）'
elif ! extensions=$(limited 20 code --list-extensions 2>/dev/null </dev/null) ||
    [ -z "$extensions" ]; then
    # A stale terminal (tmux, docker exec) has a `code` that cannot reach VS Code.
    info 'code コマンドが VS Code に接続できないため、拡張は確認していません（新しい統合ターミナルで実行してください）'
else
    extensions=$(printf '%s\n' "$extensions" | tr '[:upper:]' '[:lower:]')
    for extension in ms-python.python ms-python.vscode-pylance ms-python.debugpy charliermarsh.ruff; do
        if printf '%s\n' "$extensions" | grep -qx "$extension"; then ok "$extension"; else
            warn "$extension が入っていません"
            hint 'Dev Container で開き直すと自動で入ります。入らない場合は、拡張機能ビューから入れてください。'
        fi
    done
fi

# --- Git identity ------------------------------------------------------------------
section 'Git の設定'
# Git itself decides whether it can name the author and the committer
# (configuration at any level, includeIf, author.*/committer.*, environment).
# With user.useConfigOnly it refuses to guess from the user and host names.
can_name() { git "$@" var GIT_AUTHOR_IDENT >/dev/null 2>&1 && git "$@" var GIT_COMMITTER_IDENT >/dev/null 2>&1; }
identity_ok=0
if can_name -c user.useConfigOnly=true; then
    identity_ok=1
    ok 'コミットの名前とメールアドレスが設定されています'
elif can_name; then
    identity_ok=1
    warn 'コミットの名前かメールアドレスが、Git の設定にありません。Git が、環境（ユーザー名、ホスト名、環境変数 EMAIL など）から決めた値でコミットします'
    hint 'git config --global user.name "..." と git config --global user.email "..." で設定してください。'
else
    fail 'コミットの名前とメールアドレスが決まりません（コミットできません）'
    hint 'git config --global user.name "..." と git config --global user.email "..." で設定してください。'
    hint 'ホストの設定が届かない条件は、README「Git と GitHub への接続」にあります。'
fi
case $(git config --get core.autocrlf 2>/dev/null | tr '[:upper:]' '[:lower:]') in
    true | yes | on | 1)
        warn 'core.autocrlf が有効です（このリポジトリは .gitattributes で LF に固定しています）'
        hint '問題が出る場合は、このリポジトリだけ git config core.autocrlf false にしてください。'
        ;;
esac
crlf=$(limited 30 git ls-files --eol 2>/dev/null </dev/null | grep -c '^i/crlf')
if [ "${crlf:-0}" -gt 0 ]; then
    warn "CRLF で登録されたファイルが $crlf 件あります"
    hint 'git ls-files --eol | grep "^i/crlf" で一覧を確認し、LF に直してコミットしてください。'
fi

# --- Signing -------------------------------------------------------------------------
# Sign a commit object with this repository's own configuration, without
# creating a commit: `git commit-tree` runs no hooks, and the object goes to a
# scratch object directory. Passphrase prompts are refused, not waited for.
sign_commits=$(git config --type=bool --get commit.gpgsign 2>/dev/null)
sign_tags=$(git config --type=bool --get tag.gpgsign 2>/dev/null)
if [ "$sign_commits" = true ] || [ "$sign_tags" = true ]; then
    format=$(git config --get gpg.format 2>/dev/null)
    what='コミット'
    setting=commit.gpgsign
    if [ "$sign_commits" != true ]; then
        what='タグ'
        setting=tag.gpgsign
    fi
    if [ "$identity_ok" -eq 0 ]; then
        info '名前とメールアドレスが決まらないため、署名は確認していません'
    else
        mkdir -p "$scratch/objects"
        tree=$(git hash-object -t tree /dev/null 2>/dev/null)
        if (
            export GIT_OBJECT_DIRECTORY="$scratch/objects"
            export SSH_ASKPASS_REQUIRE=force
            # shellcheck disable=SC2030 # only this probe must see the change
            SSH_ASKPASS=$(command -v false)
            export SSH_ASKPASS
            unset GPG_TTY
            limited 20 git commit-tree -S "$tree" -m 'doctor signing probe' </dev/null
        ) >/dev/null 2>"$scratch/sign.err"; then
            ok "${what}に署名できます（形式: ${format:-openpgp}）"
        elif sed -e 's/"[^"]*"//g' -e "s/'[^']*'//g" "$scratch/sign.err" |
            grep -Eiq 'passphrase|no pinentry|inappropriate ioctl'; then
            # The signing program wanted to ask something (names in quotes are
            # ignored). Without a terminal that cannot be told apart from
            # "would work after typing the passphrase", so it is a warning.
            warn "${what}の署名で、入力を求められました（パスフレーズ付きの鍵や、スマートカードの場合です）。入力なしでは署名できないため、ここでは確かめられません"
            hint '実際にコミットして、署名できるかを確かめてください。VS Code の画面からのコミットは、入力できずに失敗することがあります。'
            hint 'SSH の鍵は、ホストで ssh-add を実行してエージェントに登録すると、入力が不要になります。'
        else
            fail "${what}の署名に失敗します（形式: ${format:-openpgp}）"
            # Key descriptions in the error text carry names: drop quoted parts.
            head -n 2 "$scratch/sign.err" | sed -e 's/"[^"]*"/"***"/g' -e "s/'[^']*'/'***'/g" | detail
            hint 'ホストにしかない署名のプログラムや鍵は、コンテナでは使えません。SSH 署名なら SSH エージェントに鍵を登録してください。'
            hint "このリポジトリだけ署名を外すには、git config $setting false を実行してください。"
        fi
    fi
else
    ok 'コミットの署名は有効にしていません'
fi

# --- Hooks -----------------------------------------------------------------------------
section 'コミット前フック'
# `make hooks` copies scripts/git-hooks/pre-commit into the hooks directory.
hooks_dir="$(git rev-parse --git-common-dir 2>/dev/null)/hooks"
installed_hook="$hooks_dir/pre-commit"
tracked_hook="$root/scripts/git-hooks/pre-commit"
used_dir=$(cd "$(git rev-parse --git-path hooks 2>/dev/null)" 2>/dev/null && pwd -P)
second_line=$(sed -n '2p' "$installed_hook" 2>/dev/null)
case $second_line in
    '# devcontainer-python pre-commit hook'*)
        if [ "$used_dir" != "$(cd "$hooks_dir" 2>/dev/null && pwd -P)" ] &&
            grep -q 'hooks/pre-commit' "$used_dir/pre-commit" 2>/dev/null; then
            info 'core.hooksPath のフックが、登録したコミット前フックを呼び出しているようです（README の方法）。コミットして、検査が動くかを確かめてください'
        elif [ "$used_dir" != "$(cd "$hooks_dir" 2>/dev/null && pwd -P)" ]; then
            warn 'core.hooksPath が別の場所を指しているため、Git は .git/hooks を使いません。コミット前フックは動きません'
            hint '検査は、make pre-commit と、プルリクエストの CI で行われます。'
            hint 'コミットのときにも検査したい場合は、README「コミット前フック」の手順を見てください（make hooks では直りません）。'
        elif [ -f "$tracked_hook" ] && ! cmp -s "$tracked_hook" "$installed_hook"; then
            warn '登録されているコミット前フックが、リポジトリのものと違います（古い版の可能性があります）'
            hint 'make hooks を実行して、登録し直してください。'
        elif [ ! -x "$installed_hook" ]; then
            warn 'コミット前フックに実行権限がありません（Git はこのフックを実行しません）'
            hint 'make hooks を実行して、登録し直してください。'
        else
            ok 'コミット前フックが登録されています'
        fi
        ;;
    '# File generated by prek'* | '# File generated by pre-commit'*)
        warn 'prek install が作ったフックが登録されています（ホストでコミットすると失敗します）'
        hint 'make hooks を実行して、このリポジトリのフックに置き換えてください。prek install は使わないでください。'
        ;;
    *)
        warn 'コミット前フックが登録されていません'
        hint 'make hooks を実行してください。'
        ;;
esac

# --- Remote and authentication -----------------------------------------------------------
section 'リモートと認証'
# The remote that `git push` uses for the current branch.
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
remotes=$(git remote 2>/dev/null)
is_remote() { printf '%s\n' "$remotes" | grep -qxF -- "$1"; }
remote=''
configured=''
if [ -n "$branch" ]; then
    configured=$(git config --get "branch.$branch.pushRemote" 2>/dev/null)
    [ -n "$configured" ] || configured=$(git config --get remote.pushDefault 2>/dev/null)
    [ -n "$configured" ] || configured=$(git config --get "branch.$branch.remote" 2>/dev/null)
fi
[ -n "$configured" ] || configured=$(git config --get remote.pushDefault 2>/dev/null)
[ "$configured" = . ] && configured='' # a branch that tracks a local branch
if [ -n "$configured" ] && is_remote "$configured"; then
    remote=$configured
elif is_remote origin; then
    remote=origin
elif [ "$(printf '%s\n' "$remotes" | grep -c .)" -eq 1 ]; then
    remote=$remotes
fi

# Classify a URL: https, ssh, anonymous (git://), local or other.
kind_of() {
    case $1 in
        https://* | http://*) echo https ;;
        ssh://* | git+ssh://* | ssh+git://*) echo ssh ;;
        git://*) echo anonymous ;;
        file://*) echo local ;;
        *::*) echo other ;; # remote helpers such as ext::
        *://*) echo other ;;
        [A-Za-z]:[\\/]*) echo local ;; # C:\path or C:/path
        /* | ./* | ../* | '~'*) echo local ;;
        *)
            # scp-like "[user@]host:path": a colon before the first slash.
            if printf '%s' "$1" | grep -Eq '^[^/:]+:'; then echo ssh; else echo local; fi
            ;;
    esac
}
# The host of a URL as written (ssh matches its Host patterns by case),
# without user name and port.
host_of() {
    if printf '%s' "$1" | grep -q '://'; then
        printf '%s' "$1" | sed -e 's#^[A-Za-z+]*://##' -e 's#/.*$##' -e 's#^.*@##' -e 's#:[0-9]*$##'
    else
        printf '%s' "$1" | sed -e 's#:.*$##' -e 's#^.*@##'
    fi
}

# An askpass program is a legitimate way to authenticate (VS Code sets one),
# but it asks a person. Remember that there is one; it is not run here.
askpass=0
# shellcheck disable=SC2031 # the user's own value is wanted here
[ -n "${GIT_ASKPASS:-}${SSH_ASKPASS:-}" ] || [ -n "$(git config --get core.askPass 2>/dev/null)" ] && askpass=1
# A custom ssh command (a wrapper, another client) is used as it is.
custom_ssh=0
[ -n "${GIT_SSH_COMMAND:-}${GIT_SSH:-}" ] || [ -n "$(git config --get core.sshCommand 2>/dev/null)" ] && custom_ssh=1

gh_logged_in=0
# `gh auth token` prints the token: it is discarded inside the limited command,
# so it is never written anywhere.
if have gh && limited 10 sh -c 'gh auth token --hostname github.com >/dev/null 2>&1' </dev/null; then
    gh_logged_in=1
fi

# Check the means of authentication for one push URL.
# $1: the URL exactly as `git push` would use it.
check_push_url() {
    local url=$1 kind host ssh_host
    kind=$(kind_of "$url")
    ssh_host=$(host_of "$url")
    host=$(printf '%s' "$ssh_host" | tr '[:upper:]' '[:lower:]') # host names ignore case
    case $kind in
        https)
            # Let Git run the credential helpers exactly as a push would (same
            # URL, so per-path and per-user settings apply), asking only "get",
            # with every prompt disabled. Whether a password came back is
            # decided inside the pipe: the answer is not stored anywhere.
            if (
                # shellcheck disable=SC2031 # set for this probe only
                export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true
                printf 'url=%s\n\n' "$url" |
                    limited 20 sh -c 'git credential fill | grep -q "^password=."' 2>"$scratch/credential.err"
            ); then
                ok "$host の認証情報を取得できます"
                if grep -q 'is not a git command' "$scratch/credential.err"; then
                    info 'ホストからコピーされた認証ヘルパーの一部は、コンテナにありません（Git は無視して、次のヘルパーを使います）'
                fi
            elif [ -n "$(git config --get-urlmatch http.extraHeader "$url" 2>/dev/null)" ]; then
                info "$host には、http.extraHeader の設定で認証します（認証ヘルパーは使いません）"
            elif grep -Eiqs "machine[[:space:]]+$host([[:space:]]|\$)" "${NETRC:-$home/.netrc}" "$home/_netrc"; then
                info "$host には、~/.netrc の設定で認証します（認証ヘルパーは使いません）"
            elif [ "$askpass" -eq 1 ]; then
                warn "$host の認証情報は保存されていません。push のたびに、ユーザー名とトークンの入力を求められます"
                hint '入力を省くには、gh auth login --hostname github.com --git-protocol https --web と gh auth setup-git を実行してください（README「GitHub CLI で認証する」）。'
            elif [ "$host" = github.com ]; then
                fail 'github.com の認証情報を取得できません（push すると、認証に失敗します）'
                if grep -q 'is not a git command' "$scratch/credential.err"; then
                    hint 'ホストからコピーされた認証ヘルパーが、コンテナにありません。'
                fi
                hint 'gh auth login --hostname github.com --git-protocol https --web と gh auth setup-git を実行してください（README「GitHub CLI で認証する」）。'
                hint 'VS Code の認証情報を使う場合は、VS Code の統合ターミナルで実行し直してください。'
            else
                warn "$host の認証情報を取得できません（push のときに、入力を求められるか、失敗します）"
                hint '認証ヘルパーを設定するか、push のときにユーザー名とトークンを入力してください。'
            fi
            ;;
        ssh)
            if [ "$custom_ssh" -eq 1 ]; then
                info '独自の ssh コマンド（core.sshCommand か GIT_SSH_COMMAND）が設定されているため、SSH の鍵は確認していません'
            elif ! have ssh; then
                fail 'push 先が SSH 形式ですが、ssh がありません'
                hint 'Dev Container をリビルドしてください。'
            else
                # ssh itself says which agent and which key files it would use
                # for this host (defaults and ~/.ssh/config).
                limited 10 ssh -G "$ssh_host" >"$scratch/ssh.config" 2>/dev/null </dev/null
                agent=$(sed -n 's/^identityagent //p' "$scratch/ssh.config" | head -n 1)
                case $agent in
                    '' | SSH_AUTH_SOCK) agent=${SSH_AUTH_SOCK:-} ;;
                    none) agent='' ;;
                    '~'*) agent="$account_home${agent#'~'}" ;;
                esac
                keys=0
                if have ssh-add && [ -n "$agent" ]; then
                    keys=$(SSH_AUTH_SOCK=$agent limited 10 ssh-add -l 2>/dev/null </dev/null | grep -c 'SHA256\|MD5')
                fi
                key_file=0
                while IFS= read -r file; do
                    case $file in '~'*) file="$account_home${file#'~'}" ;; esac
                    [ -f "$file" ] && key_file=1
                done <<FILES
$(sed -n 's/^identityfile //p' "$scratch/ssh.config" | sed -e 's/^"\(.*\)"$/\1/')
FILES
                if [ "${keys:-0}" -gt 0 ]; then
                    ok "SSH エージェントに鍵があります（$(printf '%s' "$keys" | tr -d ' ') 件）"
                elif [ "$key_file" -eq 1 ]; then
                    info 'SSH エージェントに鍵はありません。~/.ssh の鍵のファイルを使います'
                else
                    fail 'push 先が SSH 形式ですが、使える SSH の鍵がありません（エージェントにも ~/.ssh にもありません）'
                    hint 'ホストで ssh-add を実行してから、コンテナを開き直してください（README「SSH を使う場合」）。'
                    [ "$host" = github.com ] && [ "$in_container" -eq 1 ] &&
                        hint 'github.com なら、GIT_CONFIG_SYSTEM の設定を外すと HTTPS で接続します。'
                fi
            fi
            ;;
        anonymous) warn 'push 先が git:// 形式です（認証がなく、push できません）' ;;
        local) info 'push 先は、このマシンの中のリポジトリです（認証は不要です）' ;;
        *) info 'push 先の URL の形式を判別できないため、認証の手段は確認していません' ;;
    esac
}

if [ -z "$remote" ]; then
    if [ -z "$remotes" ]; then
        warn 'リモートがありません（push できません）'
        hint 'git remote add origin <URL> で設定してください。'
    else
        warn 'push 先のリモートを決められません（origin がなく、リモートが複数あります）'
        hint 'git push -u <リモート名> <ブランチ名> で、push 先を決めてください。'
    fi
else
    if [ -n "$configured" ] && ! is_remote "$configured"; then
        warn "push 先に設定されているリモート（${configured}）がありません。$remote を確認します"
        hint 'git config の remote.pushDefault と branch.<ブランチ名>.pushRemote を確かめてください。'
    fi
    stored=$(git config --get "remote.$remote.url" 2>/dev/null)
    info "push 先: ${remote}（${stored}）"
    if [ -n "$branch" ] && [ -z "$(git config --get "branch.$branch.remote" 2>/dev/null)" ]; then
        info "ブランチ $branch には、まだ push 先（upstream）がありません。最初の push は git push -u $remote $branch です"
    elif [ -z "$branch" ]; then
        info 'ブランチをチェックアウトしていません（detached HEAD）。push するには、ブランチを作ってください'
    fi
    if [ "$gh_logged_in" -eq 1 ]; then
        ok 'gh で github.com に認証済みです'
    elif have gh; then
        info 'gh では認証していません（下の認証情報の確認が ok なら、不要です）'
    fi
    # Every URL that a push goes to (a remote can have several push URLs).
    git remote get-url --push --all "$remote" 2>/dev/null >"$scratch/push-urls"
    while IFS= read -r push_url; do
        [ -n "$push_url" ] || continue
        if [ "$push_url" != "$stored" ]; then
            case "$in_container|$stored|$push_url" in
                '1|git@github.com:'*'|https://github.com/'* | '1|ssh://git@github.com/'*'|https://github.com/'*)
                    info "接続に使う URL: ${push_url}（コンテナ内では、github.com に HTTPS で接続します）"
                    ;;
                *) info "接続に使う URL: ${push_url}（pushurl か、URL の読み替えの設定によるものです）" ;;
            esac
        fi
        check_push_url "$push_url"
    done <"$scratch/push-urls"
    info 'リモートには接続していません。実際に push できるかは、最初の push で確かめてください（git push --dry-run でも、認証までを確かめられます）'
fi

# --- Working tree ----------------------------------------------------------------------------
if [ "$in_container" -eq 1 ] && have ruff; then
    section '作業ツリー'
    report=$(cd "$root" && limited 120 ruff format --check --no-cache . 2>&1 </dev/null)
    case $? in
        0) ok 'すべてのファイルが整形済みです' ;;
        1)
            count=$(printf '%s\n' "$report" |
                sed -n 's/^\([0-9]\{1,\}\) files\{0,1\} would be reformatted.*/\1/p' | head -n 1)
            warn "整形されていないファイルが${count:+ $count 件}あります"
            hint 'make fmt を実行してください。'
            ;;
        137 | 143) info '整形の確認に時間がかかりすぎるため、打ち切りました（make lint で確かめてください）' ;;
        *)
            warn 'ruff で整形を確認できませんでした（設定ファイルか、Python の構文に誤りがあります）'
            printf '%s\n' "$report" | grep -v '^$' | head -n 2 | detail
            hint 'make lint を実行して、エラーの内容を確かめてください。'
            ;;
    esac
fi

finish
