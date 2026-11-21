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
# The output is meant to be pasted into an issue: e-mail addresses, tokens and
# credentials in URLs are masked.
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

warnings=0
failures=0
section() { [ "$quiet" -eq 1 ] || printf '\n== %s\n' "$1"; }
ok() { [ "$quiet" -eq 1 ] || printf 'ok    %s\n' "$1"; }
info() { [ "$quiet" -eq 1 ] || printf 'info  %s\n' "$1"; }
hint() { printf '      → %s\n' "$1"; }
warn() {
    printf 'warn  %s\n' "$1"
    warnings=$((warnings + 1))
}
fail() {
    printf 'FAIL  %s\n' "$1"
    failures=$((failures + 1))
}
have() { command -v "$1" >/dev/null 2>&1; }
# Hide credentials inside a URL; the fixed SSH user "git@" is not a secret.
mask_url() { sed 's#\(://\)[^/@ ]*@#\1***@#'; }
# Hide the user part of e-mail addresses and credentials inside URLs.
mask() {
    sed -e 's/[A-Za-z0-9._%+-]\{1,\}@\([A-Za-z0-9.-]\{1,\}\.[A-Za-z]\{2,\}\)/***@\1/g' \
        -e 's#\(://\)[^/@ ]*@#\1***@#g' \
        -e 's/\(gh[opsur]_\)[A-Za-z0-9_]\{1,\}/\1***/g' \
        -e 's/\(github_pat_\)[A-Za-z0-9_]\{1,\}/\1***/g'
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || root=''
lock="${root:-.}/requirements.txt"

# --- Where am I ----------------------------------------------------------------
section '実行場所'
in_container=0
if [ -r /etc/devcontainer/bashrc ]; then
    in_container=1
    ok 'この Dev Container のイメージの中で実行しています'
elif [ -e /.dockerenv ] || [ -n "${REMOTE_CONTAINERS:-}${CODESPACES:-}" ]; then
    in_container=1
    warn '別のイメージのコンテナの中で実行しています'
    hint 'このリポジトリの .devcontainer で作ったコンテナで開き直してください。'
else
    warn 'ここは Dev Container の外（ホスト）です。以下の結果は参考です'
    hint 'VS Code で「コンテナーで再度開く」を実行し、コンテナ内でコミットと push をしてください。'
fi
if [ -z "$root" ]; then
    fail 'Git リポジトリの中で実行してください'
    printf '\n結果: FAIL %d 件、warn %d 件\n' "$failures" "$warnings"
    exit 1
fi

# --- Tools -----------------------------------------------------------------------
section 'ツール'
if [ "$in_container" -eq 0 ]; then
    info 'ホストでは、ツールの版は確認しません（検査は Dev Container 内と CI で行います）'
else
    pinned() { sed -n "s/^$1==\([^ ]*\).*/\1/p" "$lock" 2>/dev/null | head -n 1; }
    version_of() {
        "$1" --version 2>/dev/null | head -n 1 | sed 's/^[^0-9]*\([0-9][0-9A-Za-z.+-]*\).*/\1/'
    }
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
            warn "$tool の版が requirements.txt と違います（必要: $want、実際: $got、場所: $(command -v "$tool")）"
            hint 'Dev Container をリビルドしてください。後から pip install で入れた別の版があれば、pip uninstall で外してください。'
        else
            ok "$tool $got"
        fi
    done
    for tool in git gh ssh; do
        if have "$tool"; then ok "$tool があります"; else
            warn "$tool が見つかりません"
            hint 'Dev Container をリビルドしてください。'
        fi
    done
    # The home directory of the account, even when HOME points elsewhere.
    home=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)
    case ":$PATH:" in
        *":${home:-$HOME}/.local/bin:"*) ok '~/.local/bin が PATH に入っています' ;;
        *)
            warn '~/.local/bin が PATH に入っていません（pip install で入れたコマンドが見つかりません）'
            hint 'Dev Container をリビルドしてください。'
            ;;
    esac
    if have python; then
        user_packages=$(python -m pip list --user --format=freeze 2>/dev/null | cut -d= -f1 | tr '\n' ' ')
        if [ -n "${user_packages// /}" ]; then
            info "後から pip install で入れたパッケージ: $user_packages"
            hint 'コンテナを作り直すと消えます。続けて使うものは requirements.in に足してください（README「ターミナル」）。'
        fi
    fi
fi

# --- VS Code extensions ------------------------------------------------------------
section 'VS Code の拡張'
if have code; then
    extensions=$(code --list-extensions 2>/dev/null | tr 'A-Z' 'a-z')
    for extension in ms-python.python ms-python.vscode-pylance ms-python.debugpy charliermarsh.ruff; do
        if printf '%s\n' "$extensions" | grep -qx "$extension"; then ok "$extension"; else
            warn "$extension が入っていません"
            hint 'Dev Container で開き直すと自動で入ります。入らない場合は、拡張機能ビューから入れてください。'
        fi
    done
else
    info 'code コマンドがないため、拡張は確認していません（VS Code の統合ターミナルで実行すると確認できます）'
fi

# --- Git identity ------------------------------------------------------------------
section 'Git の設定'
for key in user.name user.email; do
    value=$(git config --get "$key" 2>/dev/null)
    if [ -n "$value" ]; then
        origin=$(git config --show-origin --get "$key" | cut -f1)
        ok "$key が設定されています（$origin）"
    else
        fail "$key が設定されていません（コミットできません）"
        hint "git config --global $key \"...\" で設定してください。ホストの設定が届かない条件は README「Git と GitHub への接続」にあります。"
    fi
done
status_error=$(git status --porcelain 2>&1 >/dev/null)
case $status_error in
    *'dubious ownership'*)
        fail 'Git が、このディレクトリの所有者を信頼していません（dubious ownership）'
        hint "git config --global --add safe.directory \"$root\" を実行してください。"
        ;;
    *) ok 'Git がこのリポジトリを操作できます' ;;
esac
if [ "$(git config --get core.autocrlf 2>/dev/null)" = true ]; then
    warn 'core.autocrlf=true です（このリポジトリは .gitattributes で LF に固定しています）'
    hint '問題が出る場合は、このリポジトリだけ git config core.autocrlf false にしてください。'
fi
crlf=$(git ls-files --eol 2>/dev/null | grep -c '^i/crlf')
if [ "$crlf" -gt 0 ]; then
    warn "CRLF で登録されたファイルが $crlf 件あります"
    hint 'git ls-files --eol | grep "^i/crlf" で一覧を確認し、LF に直してコミットしてください。'
fi

# --- Signing -------------------------------------------------------------------------
if [ "$(git config --type=bool --get commit.gpgsign 2>/dev/null)" = true ]; then
    format=$(git config --get gpg.format 2>/dev/null)
    probe=$(mktemp -d)
    git init -q "$probe" 2>/dev/null
    if git -C "$probe" commit -q --allow-empty -m probe >/dev/null 2>"$probe/error"; then
        ok "コミットに署名できます（commit.gpgsign=true、形式: ${format:-openpgp}）"
    else
        fail "コミットの署名に失敗します（commit.gpgsign=true、形式: ${format:-openpgp}）"
        head -n 2 "$probe/error" | mask | sed 's/^/      /'
        hint 'ホストにしかない署名のプログラムや鍵は、コンテナでは使えません。SSH 署名なら SSH エージェントに鍵を登録してください。'
        hint 'このリポジトリだけ署名を外すには、git config commit.gpgsign false を実行してください。'
    fi
    rm -rf "$probe"
else
    ok 'コミットの署名は有効にしていません'
fi

# --- Hooks -----------------------------------------------------------------------------
section 'コミット前フック'
hooks_path=$(git config --get core.hooksPath 2>/dev/null)
if [ "$hooks_path" = scripts/git-hooks ]; then
    ok 'コミット前フックが登録されています（core.hooksPath = scripts/git-hooks）'
elif [ -n "$hooks_path" ]; then
    warn "core.hooksPath が別の場所を指しています（$hooks_path）。このリポジトリのフックは動きません"
    hint 'make hooks を実行すると、このリポジトリだけ scripts/git-hooks に切り替えます。'
else
    warn 'コミット前フックが登録されていません'
    hint 'make hooks を実行してください。'
fi
if [ ! -x "$root/scripts/git-hooks/pre-commit" ]; then
    warn 'scripts/git-hooks/pre-commit に実行権限がありません'
    hint 'chmod +x scripts/git-hooks/pre-commit を実行してください。'
fi

# --- Remote and authentication -----------------------------------------------------------
section 'リモートと認証'
stored=$(git config --get remote.origin.url 2>/dev/null)
if [ -z "$stored" ]; then
    warn 'リモート origin がありません'
    hint 'git remote add origin <URL> で設定してください。'
else
    effective=$(git remote get-url --push origin 2>/dev/null)
    info "origin: $(printf '%s' "$stored" | mask_url)"
    [ "$effective" = "$stored" ] ||
        info "接続に使う URL: $(printf '%s' "$effective" | mask_url)（コンテナ内では github.com に HTTPS で接続します）"
    case $effective in
        https://* | http://*)
            helpers=$(git config --get-all credential.helper 2>/dev/null)
            helpers="$helpers
$(git config --get-urlmatch credential.helper "$effective" 2>/dev/null)"
            found=0
            while IFS= read -r helper; do
                [ -n "$helper" ] || continue
                found=1
                case $helper in
                    '!'*) command=${helper#!} ;;
                    /*) command=$helper ;;
                    *) command="git-credential-$helper" ;;
                esac
                # First word, without quotes: the program that Git will run.
                program=$(printf '%s' "$command" | sed -e 's/^ *//' -e "s/^[\"']\([^\"']*\)[\"'].*/\1/" -e 's/ .*//')
                if have "$program" || [ -x "$program" ] ||
                    [ -x "$(git --exec-path 2>/dev/null)/$program" ]; then
                    ok "認証ヘルパーが使えます（$program）"
                else
                    fail "認証ヘルパーのプログラムがコンテナにありません（$program）"
                    hint 'ホストの設定がコピーされたものです。gh auth login と gh auth setup-git を実行してください（README「GitHub CLI で認証する」）。'
                fi
            done <<HELPERS
$helpers
HELPERS
            if [ "$found" -eq 0 ]; then
                warn '認証ヘルパーが設定されていません（push でユーザー名を聞かれるか、失敗します）'
                hint 'VS Code の統合ターミナルで実行するか、gh auth login と gh auth setup-git を実行してください。'
            fi
            ;;
        /* | file://* | ./* | ../*)
            info 'リモートは、このマシンの中のリポジトリです（認証は不要です）'
            ;;
        *)
            if ! have ssh; then
                fail 'リモートが SSH 形式ですが、ssh がありません'
                hint 'Dev Container をリビルドしてください。'
            elif [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
                if ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
                    info 'SSH エージェントに鍵がありません。~/.ssh の鍵のファイルを使います'
                else
                    fail 'リモートが SSH 形式ですが、SSH エージェントに鍵がありません'
                    hint 'ホストで ssh-add を実行してから、コンテナを開き直してください（README「SSH を使う場合」）。'
                    hint 'github.com なら、GIT_CONFIG_SYSTEM の設定を外すと HTTPS で接続します。'
                fi
            else
                ok "SSH エージェントに鍵があります（$(ssh-add -l 2>/dev/null | wc -l) 件）"
            fi
            ;;
    esac
    if have gh; then
        if gh auth status >/dev/null 2>&1; then ok 'gh で認証済みです'; else
            info 'gh では認証していません（VS Code の認証情報で push できるなら、不要です）'
        fi
    fi
    if [ "$offline" -eq 1 ]; then
        info 'リモートへの接続は確認していません（--offline）'
    else
        # `timeout` is missing on some hosts (macOS); the SSH and HTTP settings
        # below already keep the command from waiting for input.
        limit=''
        have timeout && limit='timeout 30'
        if error=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' \
            $limit git ls-remote origin HEAD 2>&1 >/dev/null); then
            ok 'リモートに接続して、認証できました（読み取り）'
            if have gh && gh auth status >/dev/null 2>&1; then
                slug=$(printf '%s' "$effective" | sed -n 's#^https://github\.com/\(.*\)$#\1#p' | sed 's/\.git$//')
                if [ -n "$slug" ]; then
                    case $(gh api "repos/$slug" --jq .permissions.push 2>/dev/null) in
                        true) ok 'このリポジトリに push する権限があります' ;;
                        false)
                            warn 'このリポジトリに push する権限がありません'
                            hint 'フォークして、フォーク先に push してください。または、権限を付けてもらってください。'
                            ;;
                    esac
                fi
            else
                info 'push の権限は確認していません（gh で認証すると確認できます。git push --dry-run でも試せます）'
            fi
        else
            fail 'リモートに接続できないか、認証に失敗しました'
            printf '%s\n' "$error" | head -n 3 | mask | sed 's/^/      /'
            case $error in
                *'Authentication failed'* | *'could not read Username'* | *'Permission denied'* | *'403'* | *'401'* | *'terminal prompts disabled'*)
                    hint '認証に失敗しています。gh auth login --hostname github.com --git-protocol https --web と gh auth setup-git を実行してください。'
                    ;;
                *'not found'* | *'does not appear to be a git repository'*)
                    hint 'リモートの URL が正しいか、そのリポジトリを読む権限があるかを確かめてください。'
                    ;;
                *)
                    hint 'ネットワークに接続できているかを確かめてください。接続できない環境では、make doctor ARGS=--offline でこの確認を省けます。'
                    ;;
            esac
        fi
    fi
fi

# --- Working tree ----------------------------------------------------------------------------
section '作業ツリー'
if have ruff; then
    if format_report=$(cd "$root" && ruff format --check . 2>&1); then
        unformatted=0
    else
        unformatted=$(printf '%s\n' "$format_report" |
            sed -n 's/^\([0-9]\{1,\}\) files\{0,1\} would be reformatted.*/\1/p' | head -n 1)
    fi
    if [ "${unformatted:-1}" != 0 ]; then
        warn "整形されていないファイルが ${unformatted:-何}件あります"
        hint 'make fmt を実行してください。'
    else
        ok 'すべてのファイルが整形済みです'
    fi
fi

printf '\n結果: FAIL %d 件、warn %d 件\n' "$failures" "$warnings"
if [ "$failures" -gt 0 ]; then
    printf 'FAIL の項目を直してから、もう一度 make doctor を実行してください。\n'
    exit 1
fi
[ "$warnings" -eq 0 ] && [ "$quiet" -eq 0 ] && printf '開発を始められます。\n'
exit 0
