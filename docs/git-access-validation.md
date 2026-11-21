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
| `gh`（Debian の版） | 2.46.0-3 | Critical 1件（不採用） |
| `gh`（GitHub の公式リポジトリの版） | 2.105.0 | 0件 |

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
| Debian trixie の `gh` | 2.46.0-3（上流の 2.46.0 は 2024 年の公開） | 不採用。Debian に修正版のない脆弱性が8件あります（下の表） |
| GitHub の公式 apt リポジトリ（`cli.github.com`） | 2.105.0（2026-11-17 公開） | **採用**。Trivy の検出は、すべての深刻度で0件でした |
| GitHub のリリースのバイナリ | — | 確かめていません（この検証環境からは、GitHub のリリースに接続できません）。公式の apt リポジトリで足りるため、必要ありません |

最初は、この検証環境から `cli.github.com` に接続できなかったため、確かめられた Debian の版で実装しました。その後、リポジトリの所有者の許可を得て、検証環境の許可ホストに `cli.github.com` を追加し、公式のリポジトリの版に切り替えました。

#### 公式のリポジトリについて確かめたこと

- **署名鍵**: `https://cli.github.com/packages/githubcli-archive-keyring.gpg` から取得しました（2026-11-21、4528 バイト、SHA-256 `6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b`）。鍵は2つ入っています。

  | 作成日 | 指紋 | 状態 |
  | --- | --- | --- |
  | 2022-09-06 | `2C61 0620 1985 B60E 6C7A C873 23F3 D4EA 7571 6059` | 2026-09-05 に期限切れ |
  | 2026-04-07 | `7F38 BBB5 9D06 4DBC B3D8 4D72 5612 B364 6231 3325` | 有効（期限なし） |

  指紋を、GitHub の別の経路（公式ドキュメントなど）の値と照合することは、この検証環境ではできていません（`cli.github.com` 以外の GitHub のホストに接続できないため）。鍵は、TLS で `cli.github.com` から取得したものです。
- **署名の検証**: `signed-by` を付けた apt の取得元で、`apt-get update` と `apt-get install gh` が成功しました。
- **版の固定**: リポジトリの索引（`Packages`）には、最新版の1件しか載っていません。そのため、apt で古い版を指定することはできません。古い版の `.deb` は、`pool/` に残っています（2.104.0 と 2.100.0 があることを確かめました）。版を固定する場合は、`.deb` を直接取得して SHA-256 を照合する方法になりますが、更新を手で追う必要があります。この変更では、OS パッケージと同じく、ビルド時点の最新版を入れる方法にしました。
- **arm64**: 索引に arm64 版（2.105.0）があることを確かめました。ビルドはしていません。
- **依存**: `git` だけです（導入済み）。

### Debian の `gh` 2.46.0 に残っている脆弱性（不採用の理由）

Debian のトラッカーでは、8件が trixie で `open`、no-dsa（Minor issue）です。

| CVE | Trivy の深刻度 | 内容 | 上流の修正版 |
| --- | --- | --- | --- |
| CVE-2026-48501 | Critical | `gh attestation`・`gh release verify`・`gh release verify-asset` が、トークンを別のホストに送る（2.46.0 には、これらのサブコマンドがありません） | 2.93.0 |
| CVE-2026-59831 | Medium | `gh codespace jupyter` が、悪意のある Codespace から渡された URL を検証せずに開く | 2.96.0 |
| CVE-2026-72924 | Medium | `gh codespace ports forward` が、すべてのネットワークインターフェースで待ち受ける | 2.98.0 |
| CVE-2026-64653 | Medium | API の URL に、リポジトリ名などを符号化せずに埋め込む | 2.97.0 |
| CVE-2026-64654 | Medium | PR・gist・リリースなどの内容を、端末の制御文字を取り除かずに表示する | 2.97.0 |
| CVE-2026-45803 | Low | `gh run view --log` が、Actions のログの制御文字を取り除かずに表示する | 2.92.0 |
| CVE-2026-64652 | Low | `gh auth status` が、細かい権限のトークンなどの一部を表示する | 2.97.0 |
| CVE-2026-64655 | Low | `gh attestation verify` が、署名者の名前を正規表現として扱う | 2.97.0 |

2.105.0 は、これらの修正版より新しい版です。`scripts/check_devcontainer.sh` は、入っている `gh` が 2.98.0 以上であることを確かめます。

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

- **`make check`**: lint、型チェック、テスト55件、`scripts/` の単体テスト28件が成功しました。
- **`scripts/check_devcontainer.sh`**: すべて成功しました。追加・変更した検査は次のとおりです。
  - `gh`・`ssh`・`ssh-add`・`ssh-keygen` があること。`sshd` がないこと（これまでは `ssh` がないことを確かめていました）
  - `github.com` のホスト鍵が登録されていて、指紋が上の3つと一致すること
  - `ssh` がイメージのホスト鍵のファイルを読むこと。知らないホストを確認なしに信頼しない設定のままであること
  - `gh` が動き、`gh auth setup-git` があること。`gh` の補完があること
  - `gh` の版が 2.98.0 以上であること（Debian の版に戻っていないこと）と、apt の取得元が署名鍵に結び付けられていること
- **`scripts/test_project_config.py`**: ホスト鍵のファイルから指紋を計算し、上の3つと一致することを確かめるテストを追加しました（`ssh` のない CI の `python` ジョブでも動きます）。`gh` の署名鍵のファイルの SHA-256 を確かめるテストも追加しました。
- **Trivy**: 新しい[ベースライン](../security/container-baseline.json)で `Raw findings: HIGH=131; CRITICAL=1`、`Reviewed: 132; blocking: 0`。[全検出一覧](security-findings.json)と [OS パッケージ一覧](os-packages.txt)を更新しました。
- **`gh`**: `gh --version` が 2.105.0 を表示しました。`gh auth login` の `--hostname`・`--git-protocol`・`--web` と、`gh auth setup-git`・`gh auth logout`・`gh pr checks` があることを確かめました。

## イメージの大きさ

| 項目 | 変更前（main） | 変更後 |
| --- | --- | --- |
| `docker image inspect` の Size | 635 MB | 700 MB |
| `docker save` の出力を gzip で圧縮した大きさ | 147 MB | 165 MB |
| OS パッケージ数 | 131 | 136 |
| Trivy の High / Critical | 126 / 0 | 131 / 1 |

増えた分の多くは `gh` です（インストール後の大きさが約 40 MB）。

## 確かめていないこと

- **実際の `github.com` への SSH 接続**と、`gh auth login` による認証（どちらも、この検証環境から接続できないため）。
- **VS Code による SSH エージェントの受け渡し**（検証環境に VS Code がないため）。README の手順は、Windows・macOS・Linux のどのホストでも確かめていません。
- **`gh` のトークンの保存先**。README には、平文で `~/.config/gh/hosts.yml` に保存されると書きました。これは gh の仕様（OS の保管庫がなければ平文で保存する）に基づく記述で、ログインして確かめたものではありません。
- **arm64**: `gh` は、公式のリポジトリの索引に arm64 版があることだけを確かめました。`openssh-client` の arm64 版と、arm64 でのビルドは確かめていません（Issue #19）。
