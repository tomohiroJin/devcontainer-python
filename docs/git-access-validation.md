# Issue #17 検証記録（SSH と GitHub CLI の導入）

日付: 2026-11-21。基準コミット: `62e1128`（main）。対象: [Issue #17](https://github.com/tomohiroJin/devcontainer-python/issues/17) のうち、`openssh-client` と `gh` の導入。親は [Issue #13](https://github.com/tomohiroJin/devcontainer-python/issues/13) です。フック、署名の案内、モブでのコミットの補助は、この変更に含みません。

使い方と採用理由は [README](../README.md) の「Git と GitHub への接続」「同梱ツール」にあります。ここには、決める際に確かめた事実と、検証の結果を記録します。

## 背景

モブプログラミングで、SSH 形式のリモート（`git@github.com:...`）のリポジトリを Dev Container で開いた参加者が、コンテナ内から push できませんでした。イメージに `ssh` がなく、`error: cannot run ssh: No such file or directory` になるためです。[Issue #11](https://github.com/tomohiroJin/devcontainer-python/issues/11) では、脆弱性の検出が増えることを理由に `openssh-client` を入れませんでした。リポジトリの所有者の判断で、入れる方針に改めました（2026-11-21）。

## 採否を決めるために確かめたこと

Trivy 0.76.2（DB 2026-11-21 13:02:47 UTC）と、Debian Security Tracker（`security-tracker.debian.org/tracker/data/json`、2026-11-21 取得）で確かめました。

### 検出の増減

main のイメージ（High 126件、Critical 0件。すべてベースライン済み）に、パッケージを1つずつ足して比べました。

| 追加したパッケージ | 版 | 増えた High/Critical |
| --- | --- | --- |
| `openssh-client` | 1:10.0p1-7+deb13u4 | Critical 1件、High 5件 |
| `gh` | 2.46.0-3 | Critical 1件 |

あわせて入る依存は、`libedit2`・`libcbor0.10`・`libfido2-1` です（検出なし）。

### `openssh-client` の6件

いずれも、trixie では `open` で修正版がなく、no-dsa（Minor issue）です。forky と sid では、10.4p1 または 10.6p1 で修正済みです。

| CVE | 深刻度 | 内容 | このコンテナでの扱い |
| --- | --- | --- | --- |
| CVE-2026-60002 | Critical | サーバーが鍵の再交換の途中でホスト鍵を変えると、クライアント側で解放済みのメモリを使う | 該当します。悪意のあるサーバーに接続した場合です。`github.com` のホスト鍵をイメージに登録し、別のサーバーが `github.com` になりすませないようにしました。信頼できるホストにだけ接続する運用で緩和します |
| CVE-2026-106583 | High | `ssh` のコマンドラインのユーザー名に `$` や `\` があると、意図しない文字列として扱われる | 該当します。Git のリモートは、決まったユーザー名 `git` を使います。信頼できない URL をリモートに設定しない運用で緩和します |
| CVE-2026-106553 | High | `sshd` で、GSSAPI 認証に失敗したあとも認証情報が残る | 該当しません（`sshd` の問題。`openssh-server` は入れていません） |
| CVE-2026-106555 | High | `sshd` で、GSSAPI 認証の状態が次の認証に持ち越される | 該当しません（同上） |
| CVE-2026-59999 | High | `sshd` で、`DisableForwarding` が `PermitTunnel` より優先されない | 該当しません（同上） |
| CVE-2026-60000 | High | `sshd` で、GSSAPI 認証の試行回数が制限されない | 該当しません（同上） |

### `gh` の配布元

| 配布元 | 版 | 確かめた結果 |
| --- | --- | --- |
| Debian trixie の `gh` | 2.46.0-3（上流の 2.46.0 は 2024 年の公開） | 採用。apt で入り、依存は `libc6` だけです。Go 1.23.4 で静的にビルドされています。Trivy は Debian のパッケージとして扱います |
| GitHub の公式 apt リポジトリ（`cli.github.com`） | 最新 | 確かめられませんでした。この検証環境からは `cli.github.com` に接続できません |
| GitHub のリリースのバイナリ | 最新 | 確かめられませんでした。この検証環境からは GitHub のリリースに接続できません |

最新版は、下の表の脆弱性がすべて修正されている見込みです（修正版は 2.92.0〜2.98.0）。ただし、ハッシュと Trivy の検出をこの環境で確かめられないため、確かめられた Debian の版を採用しました。

### `gh` 2.46.0 に残っている脆弱性

Debian のトラッカーでは、8件が trixie で `open`、no-dsa（Minor issue）です。過去の4件（CVE-2024-52308、-53858、-54132、CVE-2025-25204）は、修正済みか、この版には該当しません。

| CVE | Trivy の深刻度 | 内容 | このコンテナでの扱い |
| --- | --- | --- | --- |
| CVE-2026-48501 | Critical | `gh attestation`・`gh release verify`・`gh release verify-asset` が、トークンを別のホストに送る | 該当しません。2.46.0 には、これらのサブコマンドがありません（`gh attestation` は `unknown command`、`gh release` に `verify` はないことを、イメージで確かめました）。ベースラインに入れました |
| CVE-2026-59831 | Medium | `gh codespace jupyter` が、悪意のある Codespace から渡された URL を検証せずに開く | Codespace に接続するサブコマンドを使った場合だけ該当します |
| CVE-2026-72924 | Medium | `gh codespace ports forward` が、すべてのネットワークインターフェースで待ち受ける | 同上 |
| CVE-2026-64653 | Medium | API の URL に、リポジトリ名などを符号化せずに埋め込む | 攻撃者が用意したリポジトリ名などを `gh` に渡した場合に該当します |
| CVE-2026-64654 | Medium | PR・gist・リリースなどの内容を、端末の制御文字を取り除かずに表示する | 該当します。信頼できないリポジトリの内容を `gh` で表示しない運用で緩和します |
| CVE-2026-45803 | Low | `gh run view --log` が、Actions のログの制御文字を取り除かずに表示する | 該当します。同上 |
| CVE-2026-64652 | Low | `gh auth status` が、細かい権限のトークンなどの一部を表示する | `gh auth login --web` で取得するトークン（`gho_`）は該当しません |
| CVE-2026-64655 | Low | `gh attestation verify` が、署名者の名前を正規表現として扱う | 該当しません（サブコマンドがありません） |

Medium と Low は、ゲート（High/Critical）の対象外です。Debian が修正版を出した場合は、ビルド時の `apt-get upgrade` が取り込みます。

### `github.com` のホスト鍵

- イメージの `/etc/ssh/ssh_known_hosts` に、`github.com` の公開ホスト鍵（Ed25519・ECDSA・RSA）を登録しました。
- 目的は2つです。初回の接続で確認を求められないようにすること（VS Code のソース管理からの push が、確認の入力待ちで止まらないようにするため）と、別のサーバーが `github.com` になりすませないようにすること（CVE-2026-60002 の緩和）です。
- 鍵の指紋は、GitHub の公式ドキュメント「GitHub's SSH key fingerprints」に載っている値と一致します。

  ```text
  SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU (ED25519)
  SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM (ECDSA)
  SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s (RSA)
  ```

- **確かめ方の限界**: この検証環境からは、`docs.github.com`、`api.github.com/meta`、`github.com` の 22 番ポートのどれにも接続できません。そのため、鍵と指紋は、公開されている既知の値を書き、鍵から計算した指紋（`ssh-keygen -lf`）が既知の指紋と一致することを確かめました。実際の `github.com` との照合は、していません。マージ前に、手元で `ssh -T git@github.com` が成功することを確かめてください。鍵が違っていれば、`Host key verification failed` で必ず失敗します（誤った鍵を受け入れる方向には倒れません）。

## 変更後の検証

Dockerfile と同じ手順でビルドしたイメージで確かめました。この検証環境は apt の HTTP 通信がプロキシを通らないため、これまでと同じく、apt の取得先だけを HTTPS とプロキシに差し替えた一時 Dockerfile を使いました。

### SSH の動作

この検証環境からは `github.com` に SSH で接続できません。そのため、同じイメージに `openssh-server` を足した SSH サーバーのコンテナを手元に立て、別のコンテナから接続して確かめました。

| 確かめたこと | 結果 |
| --- | --- |
| `github.com` を名乗るサーバーが、登録していないホスト鍵を出した場合 | `REMOTE HOST IDENTIFICATION HAS CHANGED` と `Host key verification failed` で拒否しました。確認に `yes` と答えても、接続しません |
| 登録していないホスト（`github.com` 以外）に、確認なしで接続する場合 | 接続しません（確認が必要なままです） |
| SSH エージェントの鍵で、clone・コミット・push | 成功しました（秘密鍵のファイルは、コンテナに置いていません） |
| SSH エージェントの鍵で、コミットに署名（`gpg.format=ssh`） | 成功しました（`git log --format=%G?` が `G`） |

### その他

- **`make check`**: lint、型チェック、テスト55件、`scripts/` の単体テスト27件が成功しました。
- **`scripts/check_devcontainer.sh`**: すべて成功しました。追加・変更した検査は次のとおりです。
  - `gh`・`ssh`・`ssh-add`・`ssh-keygen` があること。`sshd` がないこと（これまでは `ssh` がないことを確かめていました）
  - `github.com` のホスト鍵が登録されていて、指紋が上の3つと一致すること
  - `ssh` がイメージのホスト鍵のファイルを読むこと。知らないホストを確認なしに信頼しない設定のままであること
  - `gh` が動き、`gh auth setup-git` があること。`gh` の補完があること
- **`scripts/test_project_config.py`**: ホスト鍵のファイルから指紋を計算し、上の3つと一致することを確かめるテストを追加しました（`ssh` のない CI の `python` ジョブでも動きます）。
- **Trivy**: 新しい[ベースライン](../security/container-baseline.json)で `Raw findings: HIGH=131; CRITICAL=2`、`Reviewed: 133; blocking: 0`。[全検出一覧](security-findings.json)と [OS パッケージ一覧](os-packages.txt)を更新しました。
- **`gh`**: `gh --version` が 2.46.0 を表示しました。`gh auth login` の `--hostname`・`--git-protocol`・`--web` と、`gh auth setup-git`・`gh auth logout`・`gh pr checks` があることを確かめました。

## イメージの大きさ

| 項目 | 変更前（main） | 変更後 |
| --- | --- | --- |
| `docker image inspect` の Size | 635 MB | 689 MB |
| `docker save` の出力を gzip で圧縮した大きさ | 147 MB | 160 MB |
| OS パッケージ数 | 131 | 136 |
| Trivy の High / Critical | 126 / 0 | 131 / 2 |

増えた分の多くは `gh` です（静的にビルドされたバイナリが 35 MB）。

## 確かめていないこと

- **実際の `github.com` への SSH 接続**と、`gh auth login` による認証（どちらも、この検証環境から接続できないため）。
- **VS Code による SSH エージェントの受け渡し**（検証環境に VS Code がないため）。README の手順は、Windows・macOS・Linux のどのホストでも確かめていません。
- **`gh` のトークンの保存先**。README には、平文で `~/.config/gh/hosts.yml` に保存されると書きました。これは gh の仕様（OS の保管庫がなければ平文で保存する）に基づく記述で、ログインして確かめたものではありません。
- **arm64**: Debian に `gh` と `openssh-client` の arm64 版があることは確かめていません（Issue #19）。
