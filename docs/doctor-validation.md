# Issue #15・#17 検証記録（make doctor と、ホストでのコミット）

日付: 2026-11-21。基準コミット: `33939cc`（main）。対象: [Issue #15](https://github.com/tomohiroJin/devcontainer-python/issues/15)（`make doctor`）と、[Issue #17](https://github.com/tomohiroJin/devcontainer-python/issues/17) のうち、ホストからコミットしたときにフックで失敗する件。親は [Issue #13](https://github.com/tomohiroJin/devcontainer-python/issues/13) です。

使い方は [README](../README.md) の「環境の確認（make doctor）」と「コミット前フック (prek)」にあります。ここには、決めたことと、検証の結果を記録します。

## コミット前フック

### 変更前の問題

`make hooks`（`prek install`）が作る `.git/hooks/pre-commit` は、`prek` を呼び出します。`.git` はホストとコンテナで共有しているため、ホストでのコミットでもこのフックが動きます。ホストに prek がなければ、すべてのコミットが失敗しました。prek を入れても、Ruff と mypy がなければ失敗しました（モブプログラミングで起きた問題です）。

### 決めたこと

- **フックを、このリポジトリで管理します**（[scripts/git-hooks/pre-commit](../scripts/git-hooks/pre-commit)）。`make hooks` は、`git config --local core.hooksPath scripts/git-hooks` を実行します。
- **道具が揃っていないときは、検査をせずにコミットを通します。** prek・Ruff・mypy のどれかがないか、`requirements.txt` と版が違う場合に、理由を表示して終了コード 0 で終わります。Issue #17 の案 (a) です。
  - 版が違う場合も通すのは、別の版の Ruff で整形すると、コンテナや CI と結果が変わるためです。
  - 検査は、Dev Container 内の `make pre-commit` と、プルリクエストの CI（`python` ジョブの `make pre-commit`）で行われます。CI を必須チェックにする設定は、[Issue #20](https://github.com/tomohiroJin/devcontainer-python/issues/20) に残っています。**それまでは、ホストでコミットした未検査の変更を止めるのは、CI の結果を見てからマージする運用です。**
- **検査は `prek run` で実行します。** `prek install` が生成するフックは、prek の内部用のコマンド（`hook-impl` と、スクリプトの版番号）を呼びます。公開されているコマンドだけを使うことで、prek の更新でフックを作り直す必要がなくなります。
- **`core.hooksPath` を使う理由**: フックのファイルを `.git/hooks` にコピーする方法だと、フックを直すたびに全員がコピーし直す必要があります。`core.hooksPath` なら、リポジトリのファイルがそのまま使われます。ホストに `core.hooksPath` のグローバル設定がある場合も、このリポジトリだけ上書きされるので、登録に失敗しません（以前は、`prek install` が失敗していました）。
- **案 (b)（ホストから、コンテナ内の検査を呼び出す）は採用していません。** コンテナの名前の特定や、起動していない場合の扱いが、ホストの環境ごとに変わるためです。

### 確かめたこと

イメージの検査（`scripts/check_devcontainer.sh`）に追加し、一時的なリポジトリで確かめています。

| 状況 | 結果 |
| --- | --- |
| コンテナ内で、問題のない変更をコミット | 検査を実行して、コミットできました |
| コンテナ内で、整形されていないファイルをコミット | コミットが止まりました |
| prek・Ruff・mypy が PATH にない状態（ホストを想定）でコミット | 「prek が見つかりません」と表示して、コミットできました |
| 別の版の Ruff が PATH の先頭にある状態でコミット | 「ruff の版が違います」と表示して、コミットできました |

フックは POSIX の `sh` で書いています（ホストの `sh` は、dash、macOS の sh、Git for Windows の sh のどれかになります）。確かめたのは、Debian の dash だけです。

## make doctor

### 決めたこと

- **イメージの検査とは分けます。** `scripts/check_devcontainer.sh` は、イメージが正しく作られたかを CI で確かめます。`make doctor` は、人や起動のたびに変わるもの（Git の設定、認証、フック、リモート）を確かめます。
- **コンテナの作成時には、自動で実行しません。** VS Code がホストの Git の設定をコピーする前に実行されると、設定がないという誤った結果が出るおそれがあるためです。README の「はじめに」に、手で実行する手順として書きました。
- **ホストで実行した場合は、ツールの版を確認しません。** ホストにはツールがないのが普通で、警告が並んで肝心な項目が埋もれるためです。
- **push の権限は、`gh` で認証している場合だけ確認します。** `git push --dry-run` は、サーバー側の書き込みの権限までは確かめません。`gh` があれば、GitHub の API で権限を確認できます。
- **出力では、秘密を伏せます。** メールアドレス、URL に含まれる認証情報、GitHub のトークン（`ghp_`・`gho_`・`github_pat_` など）です。設定の値は表示せず、設定があるかどうかと、読み込み元のファイルだけを表示します。

### 確かめたこと

イメージの検査に追加し、一時的なリポジトリと、一時的なホームディレクトリで確かめています。

| 状態 | 期待する結果 | 結果 |
| --- | --- | --- |
| 準備ができている状態 | 終了コード 0、`warn` と `FAIL` なし | そのとおりでした |
| `user.email` がない | `FAIL` | そのとおりでした |
| 認証ヘルパーが、ホストにしかないプログラム（`/opt/homebrew/bin/gh`）を指している | `FAIL` | そのとおりでした |
| 認証ヘルパーがない | `warn` | そのとおりでした |
| `commit.gpgsign=true` で、署名のプログラムがない | `FAIL` | そのとおりでした |
| フックが登録されていない | `warn` | そのとおりでした |
| `core.hooksPath` が別の場所を指している | `warn` | そのとおりでした |
| SSH 形式のリモート（`github.com` 以外）で、エージェントに鍵がない | `FAIL` | そのとおりでした |
| 整形されていないファイルがある | `warn` | そのとおりでした |
| ツールが PATH にない | `FAIL` | そのとおりでした |
| リモートに接続できる（ディスク上のリポジトリで確認） | `ok` | そのとおりでした |
| リモートに接続できない | `FAIL` | そのとおりでした |
| 出力にメールアドレスが含まれない | 含まれない | そのとおりでした |

Dev Container の外（この検証環境）でも実行し、「ここは Dev Container の外です」と表示して、ツールの確認を省くことを確かめました。

## 変更後の検証

- **`make check`**: lint、型チェック、テスト55件、`scripts/` の単体テスト29件が成功しました。
- **`make pre-commit`**: 成功しました。
- **`scripts/check_devcontainer.sh`**: すべて成功しました（2回続けて実行）。

## 確かめていないこと

- **実際のホストでのコミット**（Windows の Git for Windows、macOS、WSL）。フックと `make doctor` は、ホストを想定した状態（道具が PATH にない状態）で確かめましたが、実際のホストでは確かめていません。
- **GitHub への接続と、push の権限の確認**。検証環境から GitHub に接続できないため、`make doctor` の接続の確認は、ディスク上のリポジトリで確かめました。`gh` で認証した場合の権限の確認は、確かめていません。
- **VS Code の拡張の確認**（検証環境に VS Code がないため）。`code --list-extensions` を使う部分は、動かして確かめていません。
- **macOS の `sed` などでの動作**。GNU と BSD で動きが違う書き方（`\|` など）は避けましたが、macOS では実行していません。
