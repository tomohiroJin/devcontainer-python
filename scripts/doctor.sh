#!/usr/bin/env bash
# Check that this checkout, in this container, is ready for development:
#   make doctor            (or: bash scripts/doctor.sh)
# Options:
#   --offline   skip the checks that contact the Git remote
#   --quiet     print only warnings and failures
#
# scripts/check_devcontainer.sh checks the image (run by CI). This script checks
# what differs per person and per start: Git identity, signing, credentials,
# hooks, the remote. Each warning or failure comes with what to do about it.
#
# Two rules shape the code:
# - Ask Git instead of re-implementing it. Whether credentials or a signature
#   can be produced is decided by running Git, in this repository, not by
#   reading configuration values.
# - The output is meant to be pasted into an issue. Configuration values are
#   not printed, and what is printed (URLs, paths, error text) goes through
#   mask(). Nothing here may wait for input: every external command that could
#   prompt or hang runs through limited().
#
# Bash 3.2 (macOS) compatible: no arrays, no ${var,,}, POSIX sed/grep only.
set -u

offline=0
quiet=0
for argument in "$@"; do
    case $argument in
        --offline) offline=1 ;;
        --quiet) quiet=1 ;;
        -h | --help)
            sed -n '2,7s/^# \{0,1\}//p' "$0"
            exit 0
            ;;
        *)
            printf '不明なオプションです: %s\n' "$argument" >&2
            exit 2
            ;;
    esac
done

home=${HOME:-}
# The home directory of the account, even when HOME points elsewhere (ssh and
# the image's PATH use this one).
account_home=$(getent passwd "$(id -un 2>/dev/null)" 2>/dev/null | cut -d: -f6)
account_home=${account_home:-$home}
warnings=0
failures=0
section_title=''
section_printed=1
section() {
    section_title=$1
    section_printed=0
    [ "$quiet" -eq 1 ] || print_section
}
print_section() {
    [ "$section_printed" -eq 1 ] && return
    printf '\n== %s\n' "$section_title"
    section_printed=1
}
ok() { [ "$quiet" -eq 1 ] || printf 'ok    %s\n' "$1"; }
info() { [ "$quiet" -eq 1 ] || printf 'info  %s\n' "$1"; }
last_shown=1
hint() { [ "$last_shown" -eq 1 ] && printf '      → %s\n' "$1"; }
warn() {
    print_section
    printf 'warn  %s\n' "$1"
    warnings=$((warnings + 1))
    last_shown=1
}
fail() {
    print_section
    printf 'FAIL  %s\n' "$1"
    failures=$((failures + 1))
    last_shown=1
}
have() { command -v "$1" >/dev/null 2>&1; }

# Hide what should not end up in a public issue: the home directory (it holds
# the OS user name), credentials and query strings in URLs, e-mail addresses
# (anything@host, so also non-ASCII local parts) and common token formats.
mask() {
    sed -e "s#${home:-/nonexistent-home}#~#g" \
        -e 's#\(://\)[^/@[:space:]]*@#\1***@#g' \
        -e 's#\(://[^[:space:]?]*\)?[^[:space:]]*#\1?***#g' \
        -e 's/[^][:space:]@\/:<>()"'"'"']\{1,\}@\([A-Za-z0-9.-]\{1,\}\)/***@\1/g' \
        -e 's/\(gh[opsur]_\)[A-Za-z0-9_]\{1,\}/\1***/g' \
        -e 's/\(github_pat_\)[A-Za-z0-9_]\{1,\}/\1***/g' \
        -e 's/\(glpat-\)[A-Za-z0-9_-]\{1,\}/\1***/g' \
        -e 's/\(xox[abprs]-\)[A-Za-z0-9-]\{1,\}/\1***/g' \
        -e 's/\(AKIA\)[A-Z0-9]\{12,\}/\1***/g' \
        -e 's/\([Bb]earer \)[^[:space:]]\{1,\}/\1***/g'
}
# A remote URL for display. The SSH user of an scp-like URL (git@host:path) is
# kept when it is the conventional "git"; any other user name is hidden.
show_url() {
    case $1 in
        git@*) printf 'git@%s' "$(printf '%s' "${1#git@}" | mask)" ;;
        *) printf '%s' "$1" | mask ;;
    esac
}

# Run a command for at most $1 seconds. `timeout` is missing on some hosts
# (macOS), so fall back to a watchdog. In the fallback the output goes through
# a file: a child of the command that outlives it (ssh, a credential helper)
# would otherwise keep a surrounding $(...) or pipe waiting. `<&0` keeps the
# caller's standard input, which a background command would otherwise lose.
limited() {
    local seconds=$1
    shift
    if have timeout; then
        timeout "$seconds" "$@"
        return $?
    fi
    local output="${scratch:-/tmp}/limited.$$.out"
    "$@" <&0 >"$output" &
    local pid=$!
    (
        sleep "$seconds"
        # The command first, then the children it had: the other way round,
        # the command would carry on after its child ended.
        children=''
        have pgrep && children=$(pgrep -P "$pid" 2>/dev/null)
        kill "$pid" 2>/dev/null
        [ -z "$children" ] || kill $children 2>/dev/null
    ) >/dev/null 2>&1 &
    local watchdog=$!
    wait "$pid" 2>/dev/null
    local status=$?
    have pkill && pkill -TERM -P "$watchdog" 2>/dev/null
    kill "$watchdog" 2>/dev/null
    wait "$watchdog" 2>/dev/null
    cat "$output" 2>/dev/null
    rm -f "$output"
    return "$status"
}

scratch=$(mktemp -d 2>/dev/null) || scratch=''
cleanup() { [ -n "$scratch" ] && rm -rf "$scratch"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

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
if [ -r /etc/devcontainer/bashrc ]; then
    in_container=1
    ok 'この Dev Container のイメージの中で実行しています'
elif [ -e /.dockerenv ] || [ -n "${REMOTE_CONTAINERS:-}${CODESPACES:-}" ]; then
    warn '別のイメージのコンテナの中で実行しています。以下の結果は参考です'
    hint 'このリポジトリの .devcontainer で作ったコンテナで開き直してください。'
else
    warn 'ここは Dev Container の外（ホスト）です。以下の結果は参考です'
    hint 'VS Code で「コンテナーで再度開く」を実行し、コンテナ内でコミットと push をしてください。'
fi

if ! have git; then
    fail 'git が見つかりません'
    finish
fi
if ! root=$(git rev-parse --show-toplevel 2>"${scratch:-/tmp}/rev-parse.err"); then
    if grep -q 'dubious ownership' "${scratch:-/tmp}/rev-parse.err" 2>/dev/null; then
        fail 'Git が、このディレクトリの所有者を信頼していません（dubious ownership）。Git の操作がすべて失敗します'
        hint "git config --global --add safe.directory \"$(pwd | mask)\" を実行してください（パスは、実際のディレクトリに読み替えてください）。"
    else
        fail 'Git リポジトリの中で実行してください'
    fi
    finish
fi
ok 'Git がこのリポジトリを操作できます'
lock="$root/requirements.txt"

# --- Tools -----------------------------------------------------------------------
section 'ツール'
pinned() { sed -n "s/^$1==\([^ ]*\).*/\1/p" "$lock" 2>/dev/null | head -n 1; }
version_of() {
    "$1" --version 2>/dev/null | head -n 1 | sed 's/^[^0-9]*\([0-9][0-9A-Za-z.+-]*\).*/\1/'
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
            warn "$tool の版が requirements.txt と違います（必要: $want、実際: $got、場所: $(command -v "$tool" | mask)）"
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
        user_packages=$(limited 20 python -m pip list --user --format=freeze 2>/dev/null |
            cut -d= -f1 | tr '\n' ' ')
        if [ -n "$(printf '%s' "$user_packages" | tr -d ' ')" ]; then
            info "後から pip install で入れたパッケージ: $user_packages"
            [ "$quiet" -eq 1 ] ||
                printf '      → %s\n' 'コンテナを作り直すと消えます。続けて使うものは requirements.in に足してください（README「ターミナル」）。'
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
    extensions=$(printf '%s\n' "$extensions" | tr 'A-Z' 'a-z')
    for extension in ms-python.python ms-python.vscode-pylance ms-python.debugpy charliermarsh.ruff; do
        if printf '%s\n' "$extensions" | grep -qx "$extension"; then ok "$extension"; else
            warn "$extension が入っていません"
            hint 'Dev Container で開き直すと自動で入ります。入らない場合は、拡張機能ビューから入れてください。'
        fi
    done
fi

# --- Git identity ------------------------------------------------------------------
section 'Git の設定'
# Git itself decides whether it can name the author (configuration at any
# level, includeIf, environment variables).
identity_ok=0
if git var GIT_AUTHOR_IDENT >/dev/null 2>&1 && git var GIT_COMMITTER_IDENT >/dev/null 2>&1; then
    identity_ok=1
    explicit=1
    for key in user.name user.email; do
        [ -n "$(git config --get "$key" 2>/dev/null)" ] || explicit=0
    done
    if [ "$explicit" -eq 1 ]; then
        origin=$(git config --show-origin --get user.email 2>/dev/null | cut -f1 | mask)
        ok "コミットの名前とメールアドレスが設定されています（$origin）"
    elif [ -n "${GIT_AUTHOR_NAME:-}${GIT_AUTHOR_EMAIL:-}${GIT_COMMITTER_NAME:-}${GIT_COMMITTER_EMAIL:-}" ]; then
        ok 'コミットの名前とメールアドレスが、環境変数で設定されています'
    else
        warn 'user.name か user.email が設定されていません。Git が、ユーザー名とホスト名から自動で決めた値でコミットします'
        hint 'git config --global user.name "..." と git config --global user.email "..." で設定してください。'
    fi
else
    fail 'コミットの名前とメールアドレスが決まりません（コミットできません）'
    hint 'git config --global user.name "..." と git config --global user.email "..." で設定してください。'
    hint 'ホストの設定が届かない条件は、README「Git と GitHub への接続」にあります。'
fi
if [ "$(git config --get core.autocrlf 2>/dev/null)" = true ]; then
    warn 'core.autocrlf=true です（このリポジトリは .gitattributes で LF に固定しています）'
    hint '問題が出る場合は、このリポジトリだけ git config core.autocrlf false にしてください。'
fi
crlf=$(git ls-files --eol 2>/dev/null | grep -c '^i/crlf')
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
    [ "$sign_commits" = true ] || what='タグ'
    if [ "$identity_ok" -eq 0 ]; then
        info '名前とメールアドレスが決まらないため、署名は確認していません'
    elif [ -z "$scratch" ]; then
        info '一時ディレクトリを作れないため、署名は確認していません'
    else
        mkdir -p "$scratch/objects"
        tree=$(git hash-object -t tree /dev/null 2>/dev/null)
        if (
            export GIT_OBJECT_DIRECTORY="$scratch/objects"
            export SSH_ASKPASS_REQUIRE=force
            SSH_ASKPASS=$(command -v false)
            export SSH_ASKPASS
            unset GPG_TTY
            limited 20 git commit-tree -S "$tree" -m 'doctor signing probe' </dev/null
        ) >/dev/null 2>"$scratch/sign.err"; then
            ok "${what}に署名できます（形式: ${format:-openpgp}）"
        elif grep -Eiq 'passphrase|pinentry|inappropriate ioctl|no such device|cannot open .*/dev/tty' "$scratch/sign.err"; then
            warn "${what}の署名に、パスフレーズの入力が必要です（署名のたびに入力を求められます。VS Code の画面からのコミットは失敗することがあります）"
            hint 'SSH の鍵は、ホストで ssh-add を実行してエージェントに登録すると、入力が不要になります。'
        else
            fail "${what}の署名に失敗します（形式: ${format:-openpgp}）"
            head -n 2 "$scratch/sign.err" | mask | sed 's/^/      /'
            hint 'ホストにしかない署名のプログラムや鍵は、コンテナでは使えません。SSH 署名なら SSH エージェントに鍵を登録してください。'
            hint 'このリポジトリだけ署名を外すには、git config commit.gpgsign false を実行してください。'
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
if [ -f "$installed_hook" ] && grep -q 'devcontainer-python pre-commit hook' "$installed_hook"; then
    if [ "$used_dir" != "$(cd "$hooks_dir" 2>/dev/null && pwd -P)" ]; then
        warn 'core.hooksPath が別の場所を指しているため、このリポジトリのコミット前フックは動きません'
        hint 'make hooks を実行すると、このリポジトリだけ .git/hooks を使う設定にします。'
    elif [ -f "$tracked_hook" ] && ! cmp -s "$tracked_hook" "$installed_hook"; then
        warn '登録されているコミット前フックが、リポジトリのものと違います（古い版の可能性があります）'
        hint 'make hooks を実行して、登録し直してください。'
    elif [ ! -x "$installed_hook" ]; then
        warn 'コミット前フックに実行権限がありません（Git はこのフックを実行しません）'
        hint 'make hooks を実行して、登録し直してください。'
    else
        ok 'コミット前フックが登録されています'
    fi
elif [ -f "$installed_hook" ] && grep -Eq 'generated by (prek|pre-commit)' "$installed_hook"; then
    warn 'prek install が作ったフックが登録されています（ホストでコミットすると失敗します）'
    hint 'make hooks を実行して、このリポジトリのフックに置き換えてください。prek install は使わないでください。'
else
    warn 'コミット前フックが登録されていません'
    hint 'make hooks を実行してください。'
fi

# --- Remote and authentication -----------------------------------------------------------
section 'リモートと認証'
# The remote that `git push` uses for the current branch.
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
remote=''
if [ -n "$branch" ]; then
    remote=$(git config --get "branch.$branch.pushRemote" 2>/dev/null)
    [ -n "$remote" ] || remote=$(git config --get remote.pushDefault 2>/dev/null)
    [ -n "$remote" ] || remote=$(git config --get "branch.$branch.remote" 2>/dev/null)
fi
[ -n "$remote" ] || remote=$(git config --get remote.pushDefault 2>/dev/null)
remotes=$(git remote 2>/dev/null)
if [ -z "$remote" ] || [ "$remote" = . ]; then
    if printf '%s\n' "$remotes" | grep -qx origin; then
        remote=origin
    elif [ "$(printf '%s\n' "$remotes" | grep -c .)" -eq 1 ]; then
        remote=$remotes
    else
        remote=''
    fi
fi

# Classify a URL: https, ssh, anonymous (git://) or local.
kind_of() {
    case $1 in
        https://* | http://*) echo https ;;
        ssh://* | git+ssh://* | ssh+git://*) echo ssh ;;
        git://*) echo anonymous ;;
        *://*) echo other ;;
        [A-Za-z]:[\\/]*) echo local ;; # C:\path or C:/path
        /* | ./* | ../* | '~'*) echo local ;;
        *)
            # scp-like "[user@]host:path": a colon before the first slash.
            if printf '%s' "$1" | grep -Eq '^[^/:]+:'; then echo ssh; else echo local; fi
            ;;
    esac
}
host_of() {
    case $(kind_of "$1") in
        https | ssh | anonymous | other)
            if printf '%s' "$1" | grep -q '://'; then
                printf '%s' "$1" | sed -e 's#^[A-Za-z+]*://##' -e 's#/.*$##' -e 's#^.*@##' -e 's#:[0-9]*$##'
            else
                printf '%s' "$1" | sed -e 's#:.*$##' -e 's#^.*@##'
            fi
            ;;
    esac
}

gh_logged_in=0
if have gh && limited 10 gh auth token --hostname github.com >/dev/null 2>&1 </dev/null; then
    gh_logged_in=1
fi

if [ -z "$remote" ]; then
    if [ -z "$remotes" ]; then
        warn 'リモートがありません（push できません）'
        hint 'git remote add origin <URL> で設定してください。'
    else
        warn 'push 先のリモートを決められません（origin がなく、リモートが複数あります）'
        hint 'git push -u <リモート名> <ブランチ名> で、push 先を決めてください。'
    fi
else
    stored=$(git config --get "remote.$remote.url" 2>/dev/null)
    push_url=$(git remote get-url --push "$remote" 2>/dev/null)
    kind=$(kind_of "$push_url")
    host=$(host_of "$push_url")
    info "push 先: $remote（$(show_url "$stored")）"
    if [ "$push_url" != "$stored" ]; then
        case "$stored|$push_url" in
            git@github.com:*'|'https://github.com/* | ssh://git@github.com/*'|'https://github.com/*)
                info "接続に使う URL: $(show_url "$push_url")（コンテナ内では、github.com に HTTPS で接続します）"
                ;;
            *) info "接続に使う URL: $(show_url "$push_url")（pushurl か、URL の読み替えの設定によるものです）" ;;
        esac
    fi
    if [ -n "$branch" ] && [ -z "$(git config --get "branch.$branch.remote" 2>/dev/null)" ]; then
        info "ブランチ $branch には、まだ push 先（upstream）がありません。最初の push は git push -u $remote $branch です"
    elif [ -z "$branch" ]; then
        info 'ブランチをチェックアウトしていません（detached HEAD）。push するには、ブランチを作ってください'
    fi

    case $kind in
        https)
            # Let Git run the credential helpers exactly as a push would, with
            # every prompt disabled. Only whether a password came back is used.
            proto=${push_url%%://*}
            # Git keys credentials by host and port.
            credential_host=$(printf '%s' "$push_url" | sed -e 's#^[A-Za-z+]*://##' -e 's#/.*$##' -e 's#^.*@##')
            if (
                export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true
                printf 'protocol=%s\nhost=%s\n\n' "$proto" "$credential_host" |
                    limited 20 git credential fill 2>"${scratch:-/tmp}/credential.err"
            ) | grep -q '^password=.'; then
                ok "$host の認証情報を取得できます"
                if grep -q 'is not a git command' "${scratch:-/tmp}/credential.err" 2>/dev/null; then
                    info 'ホストからコピーされた認証ヘルパーの一部は、コンテナにありません（Git は無視して、次のヘルパーを使います）'
                fi
            elif [ "$host" = github.com ]; then
                fail 'github.com の認証情報を取得できません（push すると、認証に失敗するか、ユーザー名とトークンの入力を求められます）'
                if grep -q 'is not a git command' "${scratch:-/tmp}/credential.err" 2>/dev/null; then
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
            keys=0
            if have ssh-add && [ -n "${SSH_AUTH_SOCK:-}" ]; then
                keys=$(limited 10 ssh-add -l 2>/dev/null </dev/null | grep -c .)
            fi
            key_file=0
            if have ssh && [ -n "$host" ]; then
                # The key files ssh would try for this host (defaults and ~/.ssh/config).
                for file in $(limited 10 ssh -G "$host" 2>/dev/null </dev/null |
                    sed -n 's/^identityfile //p' | sed "s#^~#$account_home#"); do
                    [ -f "$file" ] && key_file=1
                done
            fi
            if ! have ssh; then
                fail 'push 先が SSH 形式ですが、ssh がありません'
                hint 'Dev Container をリビルドしてください。'
            elif [ "${keys:-0}" -gt 0 ]; then
                ok "SSH エージェントに鍵があります（$(printf '%s' "$keys" | tr -d ' ') 件）"
            elif [ "$key_file" -eq 1 ]; then
                info 'SSH エージェントに鍵はありません。~/.ssh の鍵のファイルを使います'
            else
                fail 'push 先が SSH 形式ですが、使える SSH の鍵がありません（エージェントにも ~/.ssh にもありません）'
                hint 'ホストで ssh-add を実行してから、コンテナを開き直してください（README「SSH を使う場合」）。'
                [ "$host" = github.com ] &&
                    hint 'github.com なら、GIT_CONFIG_SYSTEM の設定を外すと HTTPS で接続します。'
            fi
            ;;
        anonymous) warn 'push 先が git:// 形式です（認証がなく、push できません）' ;;
        local) info 'push 先は、このマシンの中のリポジトリです（認証は不要です）' ;;
        *) info 'push 先の URL の形式を判別できないため、認証の手段は確認していません' ;;
    esac

    if [ "$gh_logged_in" -eq 1 ]; then
        ok 'gh で github.com に認証済みです'
    elif have gh; then
        info 'gh では認証していません（上の認証情報の確認が ok なら、不要です）'
    fi

    if [ "$offline" -eq 1 ]; then
        info 'リモートへの接続は確認していません（--offline）'
    else
        (
            export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true
            export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10'
            limited 30 git ls-remote "$push_url" HEAD </dev/null
        ) >/dev/null 2>"${scratch:-/tmp}/remote.err"
        status=$?
        if [ "$status" -eq 0 ]; then
            ok 'push 先に接続して、読み取りができました'
            slug=$(printf '%s' "$push_url" | sed -n 's#^https://github\.com/\(.*\)$#\1#p' | sed -e 's#\.git$##' -e 's#/$##')
            if [ -z "$slug" ]; then
                info 'push（書き込み）の権限は確認していません（GitHub 以外のリモートです）'
            elif [ "$gh_logged_in" -eq 0 ]; then
                info 'push（書き込み）の権限は確認していません（gh で認証すると確認できます）'
            else
                case $(limited 20 gh api "repos/$slug" --jq .permissions.push 2>/dev/null </dev/null) in
                    true) ok 'このリポジトリに push する権限があります' ;;
                    false)
                        warn 'このリポジトリに push する権限がありません'
                        hint 'フォークして、フォーク先に push してください。または、権限を付けてもらってください。'
                        ;;
                    *) info 'push（書き込み）の権限は確認できませんでした（gh がリポジトリの情報を取得できません）' ;;
                esac
            fi
        else
            fail 'push 先に接続できないか、認証に失敗しました'
            head -n 3 "${scratch:-/tmp}/remote.err" 2>/dev/null | mask | sed 's/^/      /'
            if [ "$status" -eq 124 ] || [ "$status" -eq 137 ] || [ "$status" -eq 143 ]; then
                hint '応答がないため、30 秒で打ち切りました。ネットワークに接続できているかを確かめてください。'
            elif grep -Eq 'does not appear to be a git repository|Repository not found|No such file or directory' "${scratch:-/tmp}/remote.err"; then
                hint 'リモートの URL が正しいか、そのリポジトリを読む権限があるかを確かめてください。'
            elif grep -Eq 'Authentication failed|could not read Username|returned error: 40[13]|Permission denied \(|terminal prompts disabled' "${scratch:-/tmp}/remote.err"; then
                hint '認証に失敗しています。上の「認証情報」の項目の直し方を試してください。'
            else
                hint 'ネットワークに接続できているかを確かめてください。接続できない環境では、make doctor ARGS=--offline でこの確認を省けます。'
            fi
        fi
    fi
fi

# --- Working tree ----------------------------------------------------------------------------
if [ "$in_container" -eq 1 ] && have ruff; then
    section '作業ツリー'
    report=$(cd "$root" && ruff format --check . 2>&1)
    case $? in
        0) ok 'すべてのファイルが整形済みです' ;;
        1)
            count=$(printf '%s\n' "$report" |
                sed -n 's/^\([0-9]\{1,\}\) files\{0,1\} would be reformatted.*/\1/p' | head -n 1)
            warn "整形されていないファイルが${count:+ $count 件}あります"
            hint 'make fmt を実行してください。'
            ;;
        *)
            warn 'ruff で整形を確認できませんでした（設定ファイルか、Python の構文に誤りがあります）'
            printf '%s\n' "$report" | grep -v '^$' | head -n 2 | mask | sed 's/^/      /'
            hint 'make lint を実行して、エラーの内容を確かめてください。'
            ;;
    esac
fi

finish
