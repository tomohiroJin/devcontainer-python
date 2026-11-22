# Devcontainer Python

このリポジトリは、Python プロジェクトの開発環境を簡単に構築できる Devcontainer を利用したテンプレートです。必要なツールや依存関係があらかじめ設定されており、一貫した開発環境を提供します。

## 特徴

- **Python 3.15.2** を使用
- あらかじめインストールされているツール（版と採用理由は[同梱ツール](#同梱ツール)）:
  - `pytest` と `pytest-cov`（テストとカバレッジ）
  - `pytest-watcher`（ファイルを保存するたびにテストを再実行。`make watch`）
  - `ruff`（リンタ兼フォーマッタ）
  - `mypy`（型チェック）
  - `prek`（コミット前フック。pre-commit と同じ形式の設定ファイルを使います）
  - `ipython`（対話シェル）
  - `make`、`curl`、`jq`、`tree`、`less`、`nano`、`ps`/`top` などの基本コマンド
  - `ssh`（OpenSSH クライアント）と `gh`（GitHub CLI）。ホストで SSH と HTTPS のどちらで clone していても、コンテナ内から push できます（[Git と GitHub への接続](#git-と-github-への接続)）
- 整えたターミナル（補完、Git の状態を表示するプロンプト、履歴の保持、日本語表示、ページャー）
- `make` を入口にした共通の操作（テスト、lint、整形、型チェック、カバレッジ、監査）。VS Code のタスクと、CI の Python のチェックも同じ入口を使います
- Devcontainer による一貫性のある開発環境
- Docker ベースの隔離された環境で、設定の一貫性を保証
- 非 root ユーザー (`vscode`) で動作し、マウントしたファイルの権限トラブルを回避
- サンプルコードとリファレンス例の追加
  - Python の基本的な文法やデザインパターンをカバー
  - 詳細なテストケースを含む実装

## はじめに

以下の手順で、この開発環境を利用できます。

1. このリポジトリをクローンします:

   ```bash
   git clone https://github.com/tomohiroJin/devcontainer-python.git
   cd devcontainer-python
   ```

2. VS Code でプロジェクトを開きます:

   ```bash
   code .
   ```

3. Devcontainer でプロジェクトを再オープンするように求められたら、指示に従って再オープンします。

4. 開発を始められる状態かを確認します:

   ```bash
   make doctor
   ```

   Git の名前とメールアドレス、署名、コミット前フック、push に使う認証情報などを確かめ、問題があれば直し方を表示します。リモートには接続しません。`FAIL` がなければ、コミットの準備ができています。push できるかは、最初の push で確かめてください。モブプログラミングやペアプログラミングの前には、参加者それぞれが実行してください（詳しくは[環境の確認（make doctor）](#環境の確認make-doctor)）。

5. lint・型チェック・テストをまとめて実行します:

   ```bash
   make check
   ```

   使えるコマンドの一覧は `make help` で確認できます。

### GitHub Codespaces で使う

手元に Docker がなくても、GitHub Codespaces で同じ環境を使えます。Codespaces は、このリポジトリの `.devcontainer/` から、同じイメージをビルドして起動します。

1. GitHub のリポジトリのページで、「Code」→「Codespaces」→「Create codespace on main」を選びます（ブランチで作業する場合は、そのブランチを選んでから作ります）。
2. ブラウザーの VS Code（または、手元の VS Code）が開いたら、ターミナルで `make doctor` と `make check` を実行します。

- **認証**: Codespaces が、GitHub の認証情報を用意します。このリポジトリへの push の権限があれば、`gh auth login` をしなくても push できます。
- **利用時間**: Codespaces は、起動している時間と、保存している容量が、アカウントの無料枠から引かれます。使い終わったら停止し（何もしなくても、既定では30分で止まります）、要らなくなったら削除してください。`make doctor` は、Codespaces で実行していることを表示します。
- **時刻**: タイムゾーンは、既定の `Asia/Tokyo` になります。
- **プリビルド**（あらかじめイメージを作っておく機能）は、設定していません。初回の起動では、イメージのビルドに数分かかります。
- **確認の状況**: Codespaces は、`devcontainer.json` を、CI の `container` ジョブ（Dev Container CLI による起動の確認）と同じ仕様で読みます。実際の Codespaces でも、次のことを、リポジトリの所有者が確かめました（2026-11-22）: イメージがビルドされて起動する、`make doctor` が `FAIL` も `warn` もなく通る（フックの登録、必須の拡張、Codespaces が用意する認証情報の取得を含みます）、`make check` が成功する、コミットと push ができる。

## リファレンス

このプロジェクトには、基本的な Python の文法と主要なデザインパターンを学習・参照できるサンプルが含まれています。

### **リファレンスの内容**

- `src/reference/basic`:
  - **Python の基本文法**: 変数、関数、クラス、条件分岐、ループ、例外処理
  - 各実装には詳細なテストとコメント付きのコードが含まれています
- `src/reference/patterns`:
  - **デザインパターンの実装例**:
    - Strategy パターン
    - Observer パターン（`observer.py` と property を用いた `observer_property.py` の 2 種類）
    - Decorator パターン
    - Factory パターン
    - Template Method パターン

### **サンプルの内容**

- `src/hello_world`
  - Hello, World! を出力するだけの最小サンプル
- `src/reference/samples/fizzbuzz`
  - FizzBuzz 実装

## 日常の操作（make）

よく使う操作は `make` にまとめています。ターミナル、VS Code のタスク（`Tasks: Run Task`）、CI の Python のチェック（`python` ジョブと、イメージ内での `make check`）は、同じターゲットを呼びます。CI のイメージのビルドと Trivy の監査は、ワークフローに直接書いています（手元では `make audit-container` が同じ手順を実行します）。

| コマンド | 内容 |
| --- | --- |
| `make help` | ターゲットの一覧を表示 |
| `make check` | `make lint`、`make typecheck`、`make test` をまとめて実行 |
| `make test` | pytest（`tests/`）と、`scripts/` の単体テストを実行 |
| `make watch` | ファイル（`*.py`）を保存するたびに pytest を再実行。Ctrl+C で終了 |
| `make watch-fmt` | `make watch` に加えて、保存のたびに Ruff で整形（ファイルを書き換えます）。Live Share のゲストが保存した場合にも効きます |
| `make lint` | `ruff check` と `ruff format --check`（ファイルは変更しません） |
| `make fmt` | `ruff check --fix` と `ruff format`（ファイルを書き換えます） |
| `make typecheck` | mypy で `src`・`tests`・`scripts` を型チェック |
| `make cov` | カバレッジ付きでテスト。端末に未実行の行を表示し、`coverage.xml` と `htmlcov/` を出力 |
| `make pre-commit` | コミット前フックを全ファイルに実行 |
| `make doctor` | 開発を始められる状態か（Git の設定、署名、フック、認証情報など）を確認。リモートには接続しません。`make doctor ARGS=--quiet` で、問題だけを表示 |
| `make hooks` | コミット前フックを Git に登録（Dev Container の作成時に自動で実行） |
| `make unhooks` | コミット前フックの登録を外す |
| `make audit` | pip-audit で Python 依存を監査（ネットワークが必要） |
| `make audit-container` | イメージをビルドして Trivy で監査（ホスト側で実行。docker と trivy が必要） |
| `make lock` | `requirements.in` から `requirements.txt` を再生成（ネットワークが必要） |
| `make clean` | キャッシュと生成物を削除 |

`make audit` と `make lock` は、pip-audit と pip-tools を `.venv-audit`・`.venv-lock`（Git の管理外）に導入してから実行します。この2つはイメージに入れていません。

## ターミナル

既定のシェルは bash です。設定は [.devcontainer/shell/bashrc](.devcontainer/shell/bashrc) にあり、イメージの `/etc/devcontainer/bashrc` に置いて `vscode` ユーザーの `~/.bashrc` から読み込みます。自分用の設定は、`~/.bashrc` のその行より後ろに書けば上書きできます。ただし `~/.bashrc` はコンテナを作り直すと元に戻ります。残したい設定は、Dev Containers の dotfiles 機能を使うか、`.devcontainer/shell/bashrc` に書いてください。

- **プロンプト**: 1行目にユーザー名、ディレクトリ、Git のブランチと状態、仮想環境名を表示します。直前のコマンドが失敗したときは終了コードを `[exit 1]` の形で表示します。2行目が入力位置です。

  ```text
  vscode /workspaces/devcontainer-python (main *%=) [.venv] [exit 1]
  $
  ```

  Git の状態の記号は、`*` が未ステージの変更、`+` がステージ済み、`%` が未追跡のファイル、`$` が stash あり、`<` `>` `<>` `=` が upstream との差（遅れ・進み・分岐・一致）です。
  特別なフォントは必要ありません。フォントはホスト側の VS Code の設定（`terminal.integrated.fontFamily`）で選んでください。
- **補完**: bash-completion を読み込みます。`git`、`make` のターゲットなどを Tab で補完できます。
- **履歴**: 1万件まで保持します。直前と同じコマンドは記録せず、同じシェルの中では古い重複を取り除きます。履歴は名前付きボリューム（`/commandhistory`）に置くので、コンテナを作り直しても残ります。ボリュームは Dev Container ごとに分かれます。消したいときは、コンテナを削除したあとに `docker volume ls` で `devcontainer-python-history-` で始まるボリュームを探して `docker volume rm` で削除してください。
- **後から入れたコマンド**: `pip install <パッケージ>` は、`vscode` ユーザーの `~/.local` に入ります。コマンドの置き場所の `~/.local/bin` は PATH の末尾に入れてあるので、入れたコマンドはそのまま使えます（Dockerfile の `ENV PATH`。ターミナル、VS Code のタスク、`make` のどれでも有効です）。末尾に置いているのは、同梱のツールを優先するためです。同梱のツールと同じ名前のコマンド（たとえば `pytest-watch` が入れる `ptw`）を後から入れても、使われるのは同梱のほうです。後から入れたほうを使うときは、`~/.local/bin/ptw` のようにパスを付けて呼んでください。なお、Python のモジュールは扱いが異なります。同梱のパッケージの別の版を `pip install` で入れると、`python -m pytest` などはそちらを読み込みます。同梱のパッケージの版は、`requirements.in` で変えてください。ただし、後から入れたものはコンテナを作り直すと消え、ハッシュによる固定と脆弱性監査の対象にもなりません。続けて使うツールは `requirements.in` に追加し、`make lock` を実行してからリビルドしてください。
- **エイリアス**: `ll`、`la`、`..`、`gs`（`git status --short --branch`）、`gd`（`git diff`）、`gl`（`git log` の1行グラフ表示）、`py`、`ipy`。
- **日本語**: ロケールは `C.UTF-8` です。日本語の表示・入力・ファイル名を扱えます。メッセージは英語のままです（日本語メッセージ用の `locales` パッケージは入れていません）。
- **タイムゾーン**: ホストに環境変数 `TZ` があればその値をそのまま渡し、なければ `Asia/Tokyo` を使います。ホストの `TZ` が空や `:/etc/localtime` のような値の場合は UTC になります。変えるときは `devcontainer.json` の `containerEnv` を編集してください。
- **ページャー**: `less` を入れ、`LESS=-FRX`（1画面に収まるときはそのまま表示、色を保持）にしています。slim イメージは man ページを含まないため、`man` は入れていません。使い方は `コマンド --help | less` で確認してください。
- **Git**: [.devcontainer/shell/gitconfig](.devcontainer/shell/gitconfig) を `/etc/gitconfig` に置いています。ページャー（`less -FRX`）、色、日本語のファイル名をそのまま表示する設定（`core.quotepath=false`）、差分の計算方法（`diff.algorithm=histogram`）、移動した行の色分け、日付の形式、既定のブランチ名（`main`）、`github.com` の SSH 形式のリモートを HTTPS に読み替える設定（[Git と GitHub への接続](#git-と-github-への接続)）を設定します。`~/.gitconfig`（VS Code がホストからコピーするものを含む）とリポジトリごとの設定が優先されます。

イメージをビルドしたあとの確認は、コンテナ内で次のコマンドを実行します（CI でも実行しています）。

```bash
bash scripts/check_devcontainer.sh
```

## 環境の確認（make doctor）

`make doctor` は、「この人の、この起動の状態で、開発を始められるか」を確かめます。モブプログラミングの開始前に、参加者それぞれが実行してください。

```bash
make doctor
```

結果は、項目ごとに `ok`・`info`・`warn`・`FAIL` で表示します。`warn` と `FAIL` には、直し方が `→` に続けて表示されます。`FAIL` が1件でもあると、失敗で終わります（`bash scripts/doctor.sh` の終了コードは 1 です。`make doctor` は、`make` のエラーとして表示されます）。

| 確かめること | 問題がある場合 |
| --- | --- |
| Dev Container の中で実行しているか | 外で実行すると `warn`。ツールの版と整形の確認は省きます |
| Git がこのリポジトリを操作できるか（所有者の信頼） | できなければ `FAIL`（`dubious ownership`） |
| Ruff・mypy・pytest・prek・ptw の版が `requirements.txt` と同じか | 見つからなければ `FAIL`、版が違えば `warn` |
| `~/.local/bin` が PATH にあるか。後から `pip install` で入れたパッケージ | PATH になければ `warn`。入れたパッケージは一覧を表示 |
| VS Code の必須の拡張が入っているか | VS Code の統合ターミナルで実行した場合だけ確認します |
| コミットの名前とメールアドレス | Git が決められなければ `FAIL`（コミットできません）。設定がなく、Git が自動で決める場合は `warn` |
| コミットやタグの署名（有効にしている場合） | このリポジトリの設定で実際に署名を試し、失敗すれば `FAIL`。パスフレーズの入力が必要な鍵は `warn` |
| コミット前フックが登録されているか | 未登録、古い版、実行権限なし、`prek install` のフック、別の `core.hooksPath` は `warn` |
| push 先の認証情報（HTTPS の場合。push 用の URL がいくつもあれば、すべて） | Git に、push 先の URL の認証情報を問い合わせます。取得できなければ、`github.com` は `FAIL`、他のホストは `warn`。入力を求めるプログラム（askpass。VS Code が設定します）がある場合は、`warn`（push のたびに入力が必要）。`~/.netrc` や `http.extraHeader` で認証する設定の場合は、`info` |
| SSH の鍵（push 先が SSH 形式の場合） | エージェントにも、ssh が使う鍵のファイルにもなければ `FAIL`。独自の ssh コマンドを設定している場合は、確認しません |
| 改行コード（`core.autocrlf`、CRLF で登録されたファイル） | `warn` |
| 整形されていないファイル | `warn` |

- **リモートには接続しません**: `make doctor` は、このマシンの中だけで確かめます。認証情報は「取得できるか」までを確かめ、どこにも送りません。その認証情報で実際に push できるか（期限切れでないか、権限があるか）は、確かめません。最初の push で確かめてください。push せずに認証までを試すには、`git push --dry-run` を使います。
- **問題だけを表示する場合**: `make doctor ARGS=--quiet` を実行します。問題がなければ、何も表示しません。
- **出力を共有する場合**: 出力は、Issue やチャットに貼ることを想定しています。表示するすべての行から、次のものを伏せます: ホームディレクトリ（`~` に置き換えます）、URL に含まれる認証情報とクエリ文字列、メールアドレス、代表的なトークン（GitHub、GitLab、Slack、AWS のアクセスキー、`Bearer`、`Basic`）。SSH の決まったユーザー名 `git@` と、リモートのホスト名・リポジトリ名・リモート名・ブランチ名は表示されます。伏せる処理は形で判断しているため、貼る前に目を通してください。
- **設定や認証情報を変更しません**: Git の設定、リポジトリ、作業ツリー、認証情報の保存先を変更しません。認証ヘルパーには「取得」だけを頼み、返ってきた認証情報は、ファイルに書かずに、あるかどうかだけを確かめます。`gh` が入っている場合は、認証済みかどうかを `gh` に尋ねます（`gh` は、自分の状態を記録するファイルをホームディレクトリに作ることがあります）。
- **入力待ちで止まりません**: パスフレーズや認証情報の入力を求める処理は、入力を受け付けずに次へ進みます。外部のコマンドには制限時間を付け、過ぎたら子プロセスも含めて止めます。ただし、認証ヘルパーが端末に直接入力を求める作りの場合は、表示が出たまま、制限時間（20 秒）まで待つことがあります。
- **認証の画面が開くことがあります**: 認証情報の取得は、実際に認証ヘルパーを動かして確かめます。VS Code の統合ターミナルで実行すると、VS Code のヘルパーが動き、ホスト側で認証の画面が開くことがあります。
- **Dev Container の外で実行した場合**: 「ここは Dev Container の外（ホスト）です」と表示し、ツールの版と整形の確認を省きます。ホストに `make` がなければ、`bash scripts/doctor.sh` でも実行できます。

`scripts/check_devcontainer.sh` は、イメージが正しく作られたかを確かめるもので、CI が実行します。`make doctor` は、人や起動のたびに変わるもの（Git の設定、認証、フック）を確かめます。

## Git と GitHub への接続

コミットと push は、コンテナ内で行ってください。ホストで clone したときのリモートが SSH 形式（`git@github.com:...`）でも HTTPS 形式（`https://github.com/...`）でも、コンテナ内からそのまま push できます。

### 仕組み

- **`github.com` には、常に HTTPS で接続します。** コンテナ内の Git は、SSH 形式の `github.com` のリモートを、HTTPS に読み替えます（[.devcontainer/shell/gitconfig](.devcontainer/shell/gitconfig) の `url."https://github.com/".insteadOf`）。SSH は、ホストで SSH エージェントが動いていないと使えず、モブプログラミングで push できない原因になったためです。
  - 読み替えるのは、通信のときだけです。`.git/config` に保存されているリモートの URL は書き換えません。ホストでは、これまでどおり SSH で接続します。
  - `git remote -v` は、読み替えたあとの URL（`https://github.com/...`）を表示します。保存されている URL は、`git config --get remote.origin.url` で確認できます。
  - `github.com` 以外のホスト（GitLab、社内の Git サーバーなど）は、読み替えません。
- **認証は、次のどちらかを使います。**

  | 方法 | 準備 |
  | --- | --- |
  | ホストの Git の認証情報を、VS Code がコンテナに受け渡す | ホストで、HTTPS で一度 push（または `gh auth login`）できていれば、準備は不要です |
  | コンテナ内で GitHub CLI を使う | 下の「GitHub CLI で認証する」。上の方法が使えないときに使います |

- **`user.name` などの Git の設定は、VS Code がホストからコピーします。** コンテナを作るときに、ホストの `~/.gitconfig` をコンテナの `~/.gitconfig` にコピーします。ホストのファイルを直接読むわけではないので、次の場合は設定が届きません。

  | 届かない場合 | 対処 |
  | --- | --- |
  | ホストの設定が `~/.gitconfig` ではなく `~/.config/git/config` にある | コンテナ内で、下のコマンドで設定します |
  | `[include]` や `[includeIf]` で別のファイルを読み込んでいる（読み込み先はコピーされません） | 同上 |
  | Windows で、リポジトリを WSL から開いているのに、設定が Windows 側にしかない（またはその逆） | リポジトリを開いている側（WSL か Windows）で `git config --global` を設定します |
  | VS Code 以外（`docker exec`、`devcontainer` コマンドなど）からコンテナに入った | コンテナ内で、下のコマンドで設定します |
  | ホストの設定を変えたあと、コンテナを作り直していない | コンテナをリビルドします |

### うまくいかないとき

まず、コンテナ内で `make doctor` を実行してください。下の項目をまとめて確かめ、直し方を表示します（[環境の確認（make doctor）](#環境の確認make-doctor)）。手で確かめる場合は、上から順に実行します。

1. **名前とメールアドレスが設定されているか**

   ```bash
   git config user.name; git config user.email
   ```

   何も表示されない場合や、コミットで `Please tell me who you are` と表示される場合は、設定がコピーされていません。コンテナ内で設定してください（コンテナを作り直すと消えるので、ホスト側の設定も見直してください）。

   ```bash
   git config --global user.name "あなたの名前"
   git config --global user.email "you@example.com"
   ```

2. **push できるか**

   ```bash
   git push --dry-run
   ```

   `could not read Username`、`Authentication failed`、`Permission denied` などが表示される場合は、認証情報が届いていません。次の「GitHub CLI で認証する」を実行してください。`Permission to ... denied to <ユーザー名>` と表示される場合は、認証はできていて、そのリポジトリに push する権限がありません。

3. **どの設定が効いているかを調べる**

   ```bash
   git config --list --show-origin
   ```

   設定の値と、読み込み元のファイルを表示します。`file:/etc/gitconfig` がこのイメージの既定、`file:/home/vscode/.gitconfig` がホストからコピーされたもの（または自分で設定したもの）です。出力を人に見せるときは、メールアドレスなどが含まれることに注意してください。

### GitHub CLI で認証する

ホストの設定に頼らずに、コンテナ内だけで認証する方法です。

```bash
gh auth login --hostname github.com --git-protocol https --web
```

```bash
gh auth setup-git
```

1つ目のコマンドは、8桁のコードと URL を表示します。ホストのブラウザーで URL を開き、コードを入力して承認してください。2つ目のコマンドは、Git が HTTPS の認証に `gh` を使うように設定します。**2つ目を実行しないと、`gh` で認証しても `git push` は通りません。**

- リモートが SSH 形式でも、上の読み替えによって HTTPS で接続するので、この方法で push できます。リモートを書き換える必要はありません。
- 認証情報（トークン）は、コンテナ内の `~/.config/gh/hosts.yml` に平文で保存されます（コンテナには、OS の認証情報の保管庫がないためです）。コンテナを作り直すと消えるので、もう一度実行してください。トークンをボリュームなどに残す設定は、入れていません。
- 使い終わったら、`gh auth logout` でトークンを消せます。
- `gh` は、PR の作成（`gh pr create`）や CI の結果の確認（`gh pr checks`）にも使えます。
- 同梱の `gh` は、GitHub の公式の apt リポジトリから入れた、ビルド時点の最新版です。Debian のパッケージではありません。理由は[同梱ツール](#同梱ツール)にあります。

### SSH を使う場合

`github.com` 以外のホストに SSH で接続する場合や、SSH の鍵でコミットに署名する場合は、SSH を使います。`ssh` コマンド（OpenSSH クライアント）は、イメージに入っています。

鍵の渡し方は2つあります。

| 方法 | 長所 | 短所 |
| --- | --- | --- |
| ホストの SSH エージェントを使う（推奨） | 秘密鍵がコンテナに入りません | ホストでエージェントが動き、鍵が登録されている必要があります |
| ホストの `~/.ssh` を、読み取り専用でコンテナにマウントする | ホストで接続できていれば、エージェントの準備が要りません | 秘密鍵をコンテナから読めるようになります。下の制約があります |

**SSH エージェントを使う**: VS Code（Dev Containers）が、ホストのエージェントをコンテナに受け渡します。

1. ホストで、エージェントに鍵が登録されているかを確認します。

   ```bash
   ssh-add -l
   ```

   `The agent has no identities.` や、エージェントに接続できないという表示が出た場合は、ホストで次の準備をしてから `ssh-add` で鍵を登録します。

   | ホスト | エージェントの準備 |
   | --- | --- |
   | Windows | 管理者の PowerShell で `Set-Service ssh-agent -StartupType Automatic` と `Start-Service ssh-agent` を実行します |
   | macOS | エージェントは最初から動いています。`ssh-add --apple-use-keychain ~/.ssh/id_ed25519` で登録します |
   | Linux | デスクトップ環境のエージェントが動いていない場合は、`eval "$(ssh-agent -s)"` を実行します |

2. Dev Container を開き直し、コンテナ内で `ssh-add -l` を実行します。ホストと同じ鍵が表示されれば、使えます。`Could not open a connection to your authentication agent` と表示される場合は、ホストのエージェントが動いていないか、VS Code の外の端末から入っています。

**ホストの `~/.ssh` をマウントする**: 自分の環境だけで使う設定です。`.devcontainer/devcontainer.json` の `mounts` に次の1行を足し、コンテナをリビルドします。この変更は、コミットしないでください（`~/.ssh` がない人の環境で、コンテナが起動しなくなります）。

```json
"source=${localEnv:HOME}${localEnv:USERPROFILE}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
```

- 秘密鍵のファイルの権限が、本人だけが読める設定（`600`）でないと、`ssh` は `bad permissions` と表示して鍵を使いません。Windows のファイルをマウントした場合に起きやすい問題です。その場合は、SSH エージェントを使ってください。
- ホストの `~/.ssh/config` に、macOS だけの設定（`UseKeychain` など）があると、`Bad configuration option` で接続できません。ホストの `~/.ssh/config` の先頭に `IgnoreUnknown UseKeychain` を足してください。
- 読み取り専用なので、初めて接続するホストの鍵は保存されません（`Failed to add the host to the list of known hosts` と表示されますが、接続はできます）。

**`github.com` にも SSH で接続したい場合**: HTTPS への読み替えを外します。読み替えの設定だけを除いた設定ファイル（`/etc/devcontainer/gitconfig-ssh`）を用意してあるので、環境変数でそちらを指定します。`.devcontainer/devcontainer.json` に次を足して、コンテナをリビルドしてください（自分の環境だけで使う場合は、コミットしないでください）。

```json
"remoteEnv": { "GIT_CONFIG_SYSTEM": "/etc/devcontainer/gitconfig-ssh" }
```

ターミナルで一時的に試すだけなら、`export GIT_CONFIG_SYSTEM=/etc/devcontainer/gitconfig-ssh` でも切り替えられます。接続の確認は `ssh -T git@github.com` です（`Hi <ユーザー名>! You've successfully authenticated` と表示されれば成功です）。

**`github.com` のホスト鍵**: イメージに登録してあります（`/etc/ssh/ssh_known_hosts`。元のファイルは [.devcontainer/ssh/ssh_known_hosts](.devcontainer/ssh/ssh_known_hosts)）。

- 初回の接続で `Are you sure you want to continue connecting` と聞かれません。別の鍵を出すサーバーが `github.com` を名乗った場合は、接続を拒否します。
- 鍵の指紋は、GitHub の公式ドキュメント「[GitHub's SSH key fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)」に載っている値です。`make test` とイメージの検査が、指紋が一致することを確かめます。
- GitHub が鍵を変えた場合は、`Host key verification failed` で接続できなくなります。そのときは、公式ドキュメントの値を確かめたうえで、上のファイルと、`scripts/test_project_config.py`・`scripts/check_devcontainer.sh` にある指紋を更新してください。
- `github.com` 以外のホストは、初回の接続時にこれまでどおり確認を求められます。

**SSH の鍵によるコミットの署名**（`gpg.format=ssh`）は、エージェントの鍵で動きます。ホストにしかないプログラム（`gpg.ssh.program` に 1Password の `op-ssh-sign` を指定している場合など）は、コンテナ内では動きません。その場合は、このリポジトリだけ `git config commit.gpgsign false` で署名を外すか、エージェントの鍵を使う設定に変えてください。

## 同梱ツール

版は 2026-11-20 に確認したものです。OS パッケージは Debian 13（trixie）の版で、ビルド時の `apt-get upgrade` で変わることがあります（一覧は [docs/os-packages.txt](docs/os-packages.txt)）。

### OS パッケージ

| パッケージ | 版 | 採用理由 |
| --- | --- | --- |
| `git` | 2.47.3 | バージョン管理（従来から） |
| `ca-certificates` | — | Git と pip の TLS 検証（従来から） |
| `bash-completion` | 2.16.0 | Tab 補完 |
| `less` | 668 | `git log`・`git diff` などのページャー |
| `make` | 4.4.1 | 操作の入口（`Makefile`） |
| `curl` | 8.14.1 | HTTP の確認とファイルの取得 |
| `jq` | 1.7.1 | JSON の整形と抽出（監査結果の確認など） |
| `tree` | 2.2.1 | ディレクトリ構成の表示 |
| `procps` | 4.0.4 | `ps`・`top`・`free` などのプロセス確認 |
| `nano` | 8.4 | コミットメッセージなどを端末で編集する最小のエディター（`EDITOR` の既定） |
| `openssh-client` | 10.0p2 | `github.com` 以外のホストへの SSH での接続と、SSH の鍵によるコミットの署名。`github.com` には、既定では HTTPS で接続します |
| `gh` | 2.105.0 | GitHub CLI。ホストに頼らない認証（`gh auth login`）と、PR の操作。GitHub の公式の apt リポジトリから入れます。版は固定せず、ビルドした時点の最新版が入ります |

`git` と `ca-certificates` 以外の10個のうち、High/Critical の検出があるのは `curl` と `openssh-client` の2つです。`curl` は、`curl` と `libcurl4t64` に各2件、合計4件です。CVE の番号は、Git が使う `libcurl3t64-gnutls` の検出と同じで、Debian に修正版がありません。理由を付けて[ベースライン](security/container-baseline.json)に入れています。
このうち CVE-2026-12064 は、curl コマンドに scheme のない URL を渡して SFTP/SCP で接続したときの問題です。curl コマンドを入れたことで該当するようになりました。curl を使うときは、URL に `https://` を必ず書き、SFTP/SCP には使わず、信頼できるホストだけを相手にしてください。

`openssh-client` と `gh` は、モブプログラミングで SSH 形式のリモートに push できなかったことを受けて追加しました（[Issue #17](https://github.com/tomohiroJin/devcontainer-python/issues/17)）。詳しくは[検証記録](docs/git-access-validation.md)にあります。

`openssh-client` には、Debian に修正版のない検出が6件あります（2026-11-21 時点）。内容を確かめたうえで、理由を付けてベースラインに入れています。

| 検出 | このコンテナでの扱い |
| --- | --- |
| Critical 1件（CVE-2026-60002） | サーバーが鍵の再交換の途中でホスト鍵を変えると、クライアント側でメモリを誤って使う問題です。悪意のあるサーバーに接続した場合に該当します。信頼できるホストにだけ接続してください。`github.com` はホスト鍵をイメージに登録してあるので、別のサーバーが `github.com` になりすますことはできません |
| High 1件（CVE-2026-106583） | `ssh` のコマンドラインに渡したユーザー名に `$` や `\` があると、意図しない文字列として扱われる問題です。Git のリモートは、決まったユーザー名 `git` を使います。信頼できない URL を、そのままリモートに設定しないでください |
| High 4件（CVE-2026-106553、-106555、-59999、-60000） | SSH サーバー（`sshd`）の問題です。このイメージにはクライアントしか入れておらず、`sshd` がないことを `scripts/check_devcontainer.sh` が確かめます |

`gh` には、検出がありません（Trivy で、すべての深刻度を確かめました）。

- **`gh` を GitHub の公式の apt リポジトリから入れる理由**: Debian trixie の `gh` は 2.46.0（上流では 2024 年の版）で、Debian に修正版のない脆弱性が8件あります（Trivy の判定で Critical 1件、Medium 4件、Low 3件）。公式のリポジトリ（`cli.github.com`）の 2.105.0 では、どれも修正済みです。
  - apt は、リポジトリの署名を確かめます。署名鍵は [.devcontainer/apt/githubcli-archive-keyring.gpg](.devcontainer/apt/githubcli-archive-keyring.gpg) に置き、この鍵で署名されたものだけを `gh` の取得元として受け入れます（`signed-by`）。鍵のファイルは、`cli.github.com/packages/githubcli-archive-keyring.gpg` から取得したものです。`make test` が、ファイルの SHA-256 を確かめます。
  - 版は固定していません。公式のリポジトリの索引には最新版しか載らないため、apt では古い版を指定できません。ビルド時の `apt-get upgrade` と同じく、ビルドした時点の最新版が入ります。そのため、`gh` の版はビルドした日によって変わります。`scripts/check_devcontainer.sh` は、版が 2.98.0 以上であること（Debian の版に戻っていないこと）を確かめます。
  - GitHub が署名鍵を入れ替えた場合は、イメージのビルドが署名の検証で失敗します。そのときは、上の URL から鍵を取得し直し、`scripts/test_project_config.py` の SHA-256 を更新してください。現在のファイルには、2022 年の鍵（2026-09-05 に期限切れ）と、2026 年の鍵（指紋 `7F38 BBB5 9D06 4DBC B3D8 4D72 5612 B364 6231 3325`）が入っています。

### 入れなかったもの

| 対象 | 理由 |
| --- | --- |
| `sudo` | パスワードなしの sudo を入れると、非 root で動かす意味がなくなります。一時的にパッケージを足すときは、ホストから `docker exec -u root -it <コンテナ名> bash` で入って `apt-get update && apt-get install <パッケージ>` を実行してください。恒久的に足すときは Dockerfile に書きます |
| `openssh-server` | SSH サーバーは不要です。`openssh-client` の検出のうち4件は `sshd` だけの問題で、入れなければ該当しません |
| `vim` | エディターは VS Code が主で、端末用には小さい `nano` で足ります |
| `wget` | `curl` と用途が重なります |
| `zsh`・Starship | bash に補完とプロンプトを設定すれば要件を満たせます。シェルや外部バイナリを増やさずに済みます |
| `locales` | 日本語の表示と入力は `C.UTF-8` で足ります |
| `man-db` | slim イメージに man ページが含まれていません |
| `build-essential` | 固定した依存はすべてビルド済みの wheel で入ります（`--only-binary :all:` で確認しています） |
| Dev Container Features（`common-utils` など） | `common-utils` は sudo や zsh など不要なものも入れます。CI は `docker build` でイメージを作って Trivy で監査しており、Features で入るものはその監査の対象になりません。そのため、すべて Dockerfile に書いています |

### Python のツール

直接依存は [requirements.in](requirements.in) に書き、推移的依存を含む全33件（pip を含む）を `requirements.txt` と `requirements-bootstrap.txt` にハッシュ付きで固定しています。このリポジトリのアプリ側には実行時の依存がないため、開発用の依存を別ファイルには分けていません。

| ツール | 版 | 採用理由 |
| --- | --- | --- |
| pytest | 9.2.0 | テスト（従来から） |
| Ruff | 0.17.6 | lint と整形（従来から） |
| mypy | 2.4.1 | 型チェック。PyPI の wheel だけで入り、ハッシュで固定できます |
| pytest-cov | 7.1.0 | カバレッジ（coverage 7.17.3 を使用） |
| pytest-watcher | 0.6.3 | ファイルの変更を監視してテストを再実行（`ptw`、`make watch`。watchdog 7.1.0 を使用）。TDD 用 |
| IPython | 9.18.1 | 対話シェル（`ipython` または `ipy`） |
| prek | 0.5.11 | コミット前フックの実行 |

- **型チェックに mypy を選んだ理由**: PyPI の `pyright` は、初回の実行時に pyright 本体を npm から取得します。この取得はハッシュで固定できず、ネットワークも必要です（Node.js は `pyright[nodejs]` で wheel から入れられますが、本体の取得は残ります）。mypy は Python 3.15 用の wheel があり、他の依存と同じ方法で固定できます。エディター上の診断は Pylance（`basic`）が担当するため、mypy と判定が食い違うことがあります。CI の合否は mypy です。エディターにも mypy の結果を出したい場合は、任意の拡張 Mypy Type Checker を使うか、タスク `typecheck` を実行してください（結果が「問題」パネルに出ます）。
- **pre-commit ではなく prek を選んだ理由**: `pre-commit` が依存する PyYAML 6.0.3 には Python 3.15 用の wheel がなく、ソースからのビルドが必要になります（ビルド時の依存はハッシュで固定できません）。prek は pre-commit と同じ形式の設定ファイル（`.pre-commit-config.yaml`）を読む単一バイナリで、PyPI の wheel 1つで入り、追加の依存がありません。配布元は PyPI の `prek`、開発元は [j178/prek](https://github.com/j178/prek) です。2026-11-20 時点で92回のリリースがあり、最新の 0.5.11 は 2026-11-16 の公開です。0.x 系のため、更新時は変更履歴を確認してください。
  このリポジトリの設定は、prek に内蔵されたフック（`repo: builtin`）を使います。そのため、本家の `pre-commit` コマンドではこの設定ファイルを実行できません。
- **pytest-watch ではなく pytest-watcher を選んだ理由**: どちらもコマンド名は `ptw` です。`pytest-watch` は 2018-05-20 の 4.2.0 が最後のリリースで、wheel がありません（ソースからのビルドが必要で、`--only-binary :all:` の方針に合いません）。`pytest-watcher` は 2026-01-10 に 0.6.3 が公開されており、依存は watchdog だけで、どちらも wheel で入ります（x86_64 と aarch64）。
  pytest-watcher 0.6.3 の既定の監視パターン `*.py` は、watchdog 7 ではサブディレクトリのファイルに一致しません（watchdog 7 がパス全体で照合するようになったためです）。そのままでは `tests/` のファイルを保存してもテストが再実行されないので、`pyproject.toml` の `[tool.pytest-watcher]` で `patterns = ["**/*.py"]` を指定しています。`scripts/check_devcontainer.sh` が、保存後に再実行されることを実際に確かめます。どちらかの版を上げるときは、この設定がまだ必要かを確認してください。
  また、pytest-watcher は、テストの実行中に届いた変更を捨てます。そのままでは、実行中に保存しても再実行されず、古い結果が表示されたままになります。そこで、`ptw` が pytest の代わりに [scripts/watch_runner.py](scripts/watch_runner.py) を起動するようにしています（`runner`・`runner_args`）。このスクリプトは pytest を実行し、実行中に `*.py` が保存されていれば、まとめてもう一度実行します。

### Ruff のルール

`E`・`F`・`W`・`I` に加えて、`UP`（新しい書き方への更新）、`B`（バグになりやすい書き方）、`SIM`（簡潔な書き方）、`C4`（内包表記）を有効にしています。導入時に既存コードで該当したのは9件で、7件を修正しました。残る2件（`B033`）は、集合が重複を取り除くことを説明するサンプルの1行で、意図的な書き方なので `noqa` を付けました。

**日本語の名前を使えます。** テスト名・関数名・クラス名・引数名・変数名・ファイル名のどれにも、日本語を使ってかまいません。

```python
def test_1と2を足すと3になる() -> None:
    assert 計算機().足す(1, 2) == 3
```

そのために、`N`（pep8-naming、命名規則）は有効にしていません。`N` は「小文字であること」などを調べますが、日本語には大文字と小文字の区別がないため、日本語を含む名前をすべて違反と判定します（`N802` 関数名、`N803` 引数名、`N806` 変数名、`N801` クラス名、`N999` ファイル名）。一時は有効にしていましたが（[Issue #11](https://github.com/tomohiroJin/devcontainer-python/issues/11)）、モブプログラミングで日本語のテスト名がコミットできなくなったため外しました（[Issue #16](https://github.com/tomohiroJin/devcontainer-python/issues/16)）。このコンテナは、起動してその場で色々なことを試せることを目的にしているので、書き方の制限は緩めにしています。英語の名前の命名規則も検査されなくなるため、命名はレビューで揃えてください。

- 日本語の名前を使った回帰テストが [tests/test_日本語の名前.py](tests/test_日本語の名前.py) にあります。日本語の名前を違反にする規則を入れると、`make lint` とコミット前フックがこのファイルで失敗します。
- 規則を足すときは、日本語への影響を確かめてください。`RUF001`〜`RUF003`（紛らわしい Unicode 文字。全角の括弧やコロンを検出します）と `PLC2401`・`PLC2403`（ASCII 以外の名前）は、日本語のコメントや名前を違反にします。
- ファイル名は、ホストの Git では `"tests/test_\346\227\245..."` のように表示されることがあります。そのまま表示するには、ホストで `git config --global core.quotepath false` を設定してください（コンテナ内は設定済みです）。
- lint で失敗したときは、`ruff rule <規則の番号>`（例: `ruff rule B006`）で規則の説明を読めます。

## 使用方法

### **1. テストの実行**

`pytest`を使用してプロジェクトのテストを実行します。以下のように、さまざまな方法でテストを実行できます。

#### **すべてのテストを実行**

```bash
pytest
```

`tests/` のテストを実行します。`make test` は、これに加えて `scripts/` の単体テストも実行します。

#### **特定のテストファイルを実行**

特定のテストファイルのみを実行したい場合は、ファイルパスを指定します。

```bash
pytest tests/reference/basic/test_conditionals_and_loops.py
```

#### **テストの進捗と詳細を確認**

`-v`（verbose）オプションを使用して、各テストの詳細を確認できます。

```bash
pytest -v
```

#### **特定のテストケースを実行**

`-k`オプションを使って、名前に特定の文字列を含むテストケースを実行します。

```bash
pytest -k "fizzbuzz"
```

日本語のテスト名も、同じように選べます。

```bash
pytest -k "足す"
```

#### **テスト中の出力を確認**

テスト中の`print`やログの出力を確認したい場合、`-s`オプションを使用します。

```bash
pytest -s
```

#### **保存するたびにテストを再実行（TDD）**

```bash
make watch
```

起動時に一度テストを実行し、そのあとは `*.py` のファイルを保存するたびに再実行します。Ctrl+C で終了します。VS Code では、タスク `watch` でも起動できます。

`make watch-fmt` は、テストの前に、Ruff で整形も行います（`ruff format`。import の並べ替えなどの lint の修正は、行いません）。整形で書き換わったファイルがあると、整形後のコードで、もう一度テストを実行します。構文の誤りがあって整形できないファイルは、そのままにして、その旨を表示します。Live Share で使う場合の注意は、[VS Code](#vs-code) の節にあります。

pytest に引数を渡したいときは、`ptw` を直接使います。`ptw <監視するディレクトリ> <pytest の引数>` の形です。

```bash
ptw . tests/reference/samples -x
```

設定は `pyproject.toml` の `[tool.pytest-watcher]` にあります。テストの実行中に保存した場合は、その実行が終わったあとに、もう一度実行します（実行中の保存は、何回あっても次の1回にまとめます）。そのとき、`[watch] 実行中に変更がありました` と表示します。テスト自身が `*.py` を書き換える場合に備えて、続けて実行するのは5回までです。

`ptw` は、リポジトリのルートで実行してください（`scripts/watch_runner.py` を相対パスで呼ぶためです）。

#### **カバレッジを確認**

```bash
make cov
```

端末に、ファイルごとの網羅率と未実行の行番号を表示します。`htmlcov/index.html` をブラウザーで開くと、行ごとの結果を確認できます。VS Code では、テストビューの「カバレッジを付けてテストを実行」でエディター上に表示できます。

---

### **2. コード品質チェック (Ruff)**

`ruff` を使用してコードの品質を確認します。設定は `pyproject.toml` の `[tool.ruff]` に集約されています。

#### **基本的なコードチェック**

プロジェクト全体をチェックします。

```bash
ruff check
```

#### **自動修正可能な問題を修正**

`--fix` オプションを使用すると、自動修正可能な問題を一括で修正します。

```bash
ruff check --fix
```

#### **特定のファイルのみをチェック**

特定のファイルやディレクトリだけをチェックします。

```bash
ruff check src/reference/samples/fizzbuzz/fizzbuzz.py
```

---

### **3. コードのフォーマット (Ruff)**

`ruff format` を使用してコードを自動整形します。Ruff のフォーマッタは Black 互換の挙動です。

#### **プロジェクト全体をフォーマット**

プロジェクト内のすべての Python ファイルをフォーマットします。

```bash
ruff format .
```

#### **変更内容をプレビュー**

`--check` オプションを使用すると、フォーマットの提案内容だけを確認できます（実際の変更は行われません）。

```bash
ruff format --check .
```

#### **特定のファイルやディレクトリだけをフォーマット**

特定の範囲だけを対象にする場合、パスを指定します。

```bash
ruff format src/reference/samples/fizzbuzz/fizzbuzz.py
```

---

### **4. 型チェック (mypy)**

設定は `pyproject.toml` の `[tool.mypy]` にあります。`src`・`tests`・`scripts` を対象にします（`setup.py` など、それ以外の場所のファイルは対象外です）。

```bash
make typecheck
```

---

### **5. コミット前フック (prek)**

Dev Container を作成すると、`make hooks` がコミット前フックを Git に登録します。`git commit` のたびに、次の検査を実行します。対象は、ステージしたファイルです（mypy だけは、Python か TOML のファイルをコミットするときに、プロジェクト全体を検査します）。CI も `make pre-commit` で同じ検査を全ファイルに実行します。

- 行末の空白の削除、ファイル末尾の改行、改行コードの統一（LF）
- JSON・YAML・TOML の構文、マージ競合の印、大きなファイルの追加
- `ruff check --fix`、`ruff format`、`mypy`

フックがファイルを修正した場合、コミットは中断されます。差分を確認して `git add` し、もう一度コミットしてください。全ファイルに実行するときは次のコマンドを使います。

```bash
make pre-commit
```

フックの本体は [scripts/git-hooks/pre-commit](scripts/git-hooks/pre-commit) です。`make hooks` が、これを `.git/hooks/pre-commit` にコピーして登録します。

- **Dev Container の中でコミットした場合**: 検査を実行し、失敗したらコミットを止めます。`requirements.txt` の版がイメージと違う場合（依存の更新を取り込んだあと、リビルドしていない場合など）も、検査は入っている版で実行し、その旨を表示します。
- **ホスト（Dev Container の外）でコミットした場合**: `.git` はホストとコンテナで共有しているので、フックはホストでのコミットでも動きます。ホストでは、**検査を省いてコミットを通します**（その旨を表示します）。ホストに道具があるかどうかでは判断しません。フックが原因で、コミットできなくなることはありません。検査は、Dev Container 内の `make pre-commit` か、プルリクエストの CI で行われます。検査を確実に通すために、コミットは Dev Container 内で行うことをおすすめします。
- **ホストでも検査を実行したい場合**: 自分で同じ版の prek・Ruff・mypy を用意したうえで、`git config hooks.devcontainerRunOnHost true` を実行します。この設定をすると、ホストでも検査の失敗でコミットが止まります。
- **フックが更新されたあと**: 登録されているのはコピーなので、リポジトリのフックが変わったら（main の更新を取り込んだあとなど）、もう一度 `make hooks` を実行してください。コンテナのリビルドでも実行されます。登録されているフックが、いまチェックアウトしているブランチのものと違う場合は、コミットのたびにその旨を表示します。自動では置き換えません（チェックアウトしているブランチのスクリプトを、確認なしに実行することになるためです）。古いブランチで作業しているだけなら、この表示は無視してかまいません。
- **信頼できないブランチや、古いブランチを開いた状態で `make hooks` を実行しないでください。** `make hooks` は、そのとき作業ツリーにあるフックをコピーします。コピーされたフックは、そのあと、どのブランチでも、どの作業ツリー（`git worktree`）でも、ホストでのコミットでも動きます。
- **検査の設定ファイルが作業ツリーにない場合**: `.pre-commit-config.yaml` が Git には登録されているのに、作業ツリーにない場合（削除した、sparse checkout で外した、など）は、その旨を表示して、検査を省きます。
- **`prek install` は使わないでください。** prek が作るフックは、ホストに prek がないとコミットを失敗させます（以前の不具合の原因です）。実行してしまった場合は、`make hooks` で元に戻せます。`make doctor` も、この状態を検出します。
- **既存の自分のフックがある場合**: `.git/hooks/pre-commit` に自分のフックがある場合は、`pre-commit.before-devcontainer` という名前で退避してから登録します。退避したフックは、`make unhooks` で元に戻すまで動きません。`prek install` が `pre-commit.legacy` として残していた自分のフックも、同じように退避します。`pre-commit` 以外のフック（`commit-msg` や `pre-push` など）には、触れません。
- **`core.hooksPath` を設定している場合**: Git は、その場所のフックだけを使い、`.git/hooks` を見ません。そのため、このリポジトリのコミット前フックは動きません。`make hooks` と `make unhooks` は、この設定を変更しません（グローバルの設定も、リポジトリの設定も）。`make hooks` と `make doctor` が、動かないことを知らせます。検査は、`make pre-commit` と CI で行われます。コミットのときにも検査したい場合は、次のどちらかを行ってください。
  - **コンテナ内でだけ、設定を外す**: コンテナ内で `git config --global --unset-all core.hooksPath` を実行します。ホストの `~/.gitconfig` は変わりません（コンテナを作り直すと、ホストからもう一度コピーされます）。外れたかどうかは、`git config --show-origin --get-all core.hooksPath` で確かめてください。何か表示される場合は、表示されたファイルに設定が残っています。`[include]` で読み込んでいるファイルや `~/.config/git/config` にある設定は、そのファイルを直す必要があります。リポジトリの `.git/config` にある設定は、ホストと共有しているため、外すとホストでも外れます。
  - **自分のフックから、登録されたフックを呼び出す**: `core.hooksPath` の場所にある自分の `pre-commit` の最後に、次の3行を足します。このリポジトリに登録されたフック（`.git/hooks/pre-commit`）があれば、それを実行します。登録されていないリポジトリでは、何もしません。

    ```sh
    hook="$(git rev-parse --git-common-dir)/hooks/pre-commit"
    [ -x "$hook" ] && exec "$hook" "$@"
    exit 0
    ```

    リポジトリの中のファイル（`scripts/git-hooks/pre-commit`）を、自分のフックから直接は呼び出さないでください。そのファイルのないリポジトリやブランチでコミットできなくなり、チェックアウトしているブランチのスクリプトを、ホストでも実行することになります。
- **このプロジェクトを、別の Git リポジトリの一部として置いている場合**: `make hooks` は、何も登録しません（外側のリポジトリのフックを置き換えないためです）。検査は、このディレクトリで `make pre-commit` を実行してください。`.git/hooks` がシンボリックリンクの場合も、同じです。
- **フックを外す場合**: `make unhooks` を実行します。このリポジトリのフック（と、その上に `prek install` が作ったフック）だけを削除し、退避していたフックがあれば戻します。もう一度登録するには、`make hooks` を実行します。
- **一度だけ検査を省く場合**: `git commit --no-verify` を使います。

`.vscode/*.json` と `devcontainer.json` も JSON の構文検査の対象です。コメントは書かないでください。

---

### **6. 対話シェル (IPython)**

```bash
ipython
```

## VS Code

必須の拡張は Microsoft Python / Pylance / Python Debugger と Astral Ruff の4件です。
このほかに、次の3件も、Dev Container と Codespaces に最初から入ります（2026-11-22 追加。[Issue #30](https://github.com/tomohiroJin/devcontainer-python/issues/30)）。Codespaces（特にブラウザー）では、`devcontainer.json` にない拡張は入らないためです。

| 拡張 | ID | 入れた理由 |
| --- | --- | --- |
| Live Share | `ms-vsliveshare.vsliveshare` | モブプログラミング・ペアプログラミングで、画面と編集を共有する |
| Even Better TOML | `tamasfe.even-better-toml` | `pyproject.toml` などの TOML ファイルを、色分けして表示する（VS Code には、TOML の色分けが入っていません）。補完と検証も行います |
| Material Icon Theme | `PKief.material-icon-theme` | エクスプローラーのファイルとフォルダーに、種類ごとのアイコンを表示する。`devcontainer.json` の設定（`workbench.iconTheme`）で、Dev Container と Codespaces の中でだけ有効にしています。別のアイコンにしたい場合は、「基本設定: ファイル アイコンのテーマ」で変えられます |

この3件は、Marketplace にこの検証環境から接続できないため、公開状態を確認していません。`make doctor` が確かめるのは、必須の4件だけです。

Mypy Type Checker と Error Lens は、最初から入れることを試しましたが、やめました（[Issue #30](https://github.com/tomohiroJin/devcontainer-python/issues/30)）。同じ箇所に、Ruff・Pylance・mypy の診断が重なって表示され、うるさくなります。また、Error Lens の行の横の表示は、Live Share のゲストの画面には出ません（ゲストは、マウスを当てて診断を見ます）。必要な人は、下の「任意の拡張」から入れてください。

**作成の直後に、Ruff の拡張が「No Python environment extension is available.」と警告することがあります。** Dev Container や Codespaces を作った直後は、拡張が順に入ります。Python の拡張が入る前に Ruff の拡張が起動すると、この警告が1度だけ出ます。害はありません。Ruff の拡張は、`settings.json` の `ruff.path` で指定した、コンテナの Ruff（`/usr/local/bin/ruff`。`requirements.txt` で固定した版）を使います。気になる場合は、コマンドパレットの「Developer: Reload Window」で読み込み直してください。

各 ID は提供元の現行公式拡張であることと Marketplace の公開状態を確認済みです
（Python 2026-10-29、Pylance 2026-10-16、Debugger 2026-11-02、Ruff 2026-10-27 更新）。
[Python 公式ガイド](https://code.visualstudio.com/docs/python/python-tutorial)、
[Ruff 公式ガイド](https://docs.astral.sh/ruff/editors/setup/) に基づく構成です。
`.vscode/extensions.json` と Dev Container の必須リストを共通にし、Ruff は
コンテナに固定した版を優先、lint/format/import 整理を担当します。
Pylance が型診断、pytest がテスト検出、debugpy がデバッグを担当します。
Python の整形は Ruff に統一します。

**Live Share のゲストでは、保存時の整形が動きません**（2026-11-22 に、リポジトリの所有者が確認）。ホスト（Dev Container や Codespaces を開いている人）が保存すると、Ruff で整形されます。ゲストが保存しても、整形されません。保存時の整形は、このリポジトリの設定（`.vscode/settings.json`）と、コンテナに入っている Ruff の拡張で動いていて、ゲストの VS Code には、そのどちらも届かないためと考えられます。

- **コミットされる内容は、そろいます。** ホストのコンテナでコミットすると、コミット前の検査が Ruff で整形するか、コミットを止めます。CI も、整形されていないコードを通しません。
- **ゲストの保存でも整形したい場合は、ホストが、`make watch` の代わりに `make watch-fmt` を実行します。** ゲストが保存したファイルは、ホストのコンテナの中で書き換わります。`make watch-fmt` は、その変更を見つけて、Ruff で整形してから、テストを実行します（保存の1〜2秒後に、ゲストの画面の内容も、整形後のものに変わります）。ゲストは、何も入れる必要がありません。
  - ゲストの VS Code に Ruff の拡張を入れても、ゲストの保存では整形されませんでした（2026-11-22 に確認）。
  - 整形でファイルが書き換わるのと、誰かの入力が重なると、ホストの VS Code が、ファイルの競合を知らせることがあります。その場合は、保存してから一呼吸おくか、`make watch` に戻してください。
- `make watch-fmt` を使わない場合は、ホストが、そのファイルを保存し直す（Ctrl+S）か、ターミナルで `make fmt` を実行します。
- ゲストとして参加する人が、自分の画面でも保存時に整形したい場合は、Live Share のゲストではなく、自分で Codespaces を開く方法があります（[GitHub Codespaces で使う](#github-codespaces-で使う)）。ブラウザーだけで、ホストと同じ環境になります。

**任意の拡張**は `devcontainer.json` と `extensions.json` には入れていません。必要な人だけ導入してください。
Marketplace にはこの検証環境から接続できないため、下の表の公開状態と更新日は確認していません。導入前に提供元を確認してください。

| 拡張 | ID | 用途 |
| --- | --- | --- |
| Mypy Type Checker | `ms-python.mypy-type-checker` | CI と同じ mypy の結果をエディターに表示。`settings.json` でコンテナ内の mypy を使う設定にしてあります。Pylance や Ruff と、同じ箇所に診断が重なることがあります |
| Error Lens | `usernamehw.errorlens` | 診断を行の横に表示。診断の数が多いと、画面がうるさくなります。Live Share のゲストの画面には、ホストの Error Lens の表示は出ません |
| GitLens | `eamodio.gitlens` | 行ごとの変更履歴（blame）や履歴の比較。機能が多く、一部は有料です。履歴を詳しく調べたい場合に向きます |
| Git Graph | `mhutchie.git-graph` | コミットグラフを表示する軽い拡張です。VS Code の「ソース管理」ビューにもグラフの表示があり、端末では `gl` でも見られるため、最初からは入れていません |
| Code Spell Checker | `streetsidesoftware.code-spell-checker` | 英単語のつづりの確認 |
| Jupyter | `ms-toolsai.jupyter` | Notebook を使う場合（このリポジトリには含みません） |

**エディターの設定**（[.vscode/settings.json](.vscode/settings.json)）: 88桁のルーラー、保存時の行末空白の削除（Markdown を除く）、ファイル末尾の改行、改行コード LF、ターミナルのスクロール量1万行。ターミナルの既定プロファイル（bash）は `devcontainer.json` で指定しています。

**タスク**（[.vscode/tasks.json](.vscode/tasks.json)）: `Tasks: Run Task` から `test`、`cov`、`lint`、`fmt`、`typecheck`、`check`、`pre-commit`、`audit` を実行できます。どれも同名の `make` ターゲットを呼びます。`Tasks: Run Build Task` は `check`、`Tasks: Run Test Task` は `test` です。

**デバッグ構成**（[.vscode/launch.json](.vscode/launch.json)）:

| 構成 | 内容 |
| --- | --- |
| Python: current file | 開いているファイルを実行 |
| Python: module | モジュール名を入力して `python -m` で実行（既定は `hello_world.main`） |
| Pytest: current file | 開いているテストファイルを pytest でデバッグ |
| Pytest: all tests | すべてのテストを pytest でデバッグ |
| Pytest: Test Explorer debug | テストビューの「テストのデバッグ」で使う設定 |

VS Code で開いたら Python インタープリター `/usr/local/bin/python`、テスト一覧の55件、
F5 の Python デバッガ、補完・定義ジャンプ・型診断、保存時整形と import 整理、タスクの実行を確認します。
コンテナ外ではインタープリターを自身の `.venv` に選び直してください。

## **カスタマイズ**

- `.devcontainer/devcontainer.json` で VS Code 拡張や `remoteUser` を編集できます。
- `.devcontainer/Dockerfile` で Python のバージョンや追加する OS パッケージを変更できます。OS パッケージを足したときは、`make audit-container` で Trivy の検出が増えていないか確認してください。`scripts/check_devcontainer.sh` は `sudo`・`sshd`・`gcc`・`vim` が入っていないことも確認しているので、これらを足す場合はその行も直してください。
- `.devcontainer/shell/bashrc` と `.devcontainer/shell/gitconfig` で、ターミナルと Git の既定の設定を変更できます。
- `requirements.txt` を変更した場合は Devcontainer をリビルドすることで反映されます（VS Code: `Dev Containers: Rebuild Container`）。

## ライセンス

このプロジェクトは MIT ライセンスの下で提供されています。

## 更新・セキュリティ運用（Issue #6 / 残件は Issue #9）

調査日: 2026-11-05（初回）、2026-11-20（再確認）。既定ブランチ `88f32205b2579d9a827d2e31d067a4935b7c5afe`
を基に更新しています。採用版は日付から推測せず、公式の公開 API で取得した安定版です。

| 対象 | 更新前 | 採用版・理由 |
| --- | --- | --- |
| Python / OS | `3.13-slim`（OS 不定） | `3.15.2-slim-trixie`、Debian 13。公式公開タグの最新安定系列を採用し digest 固定（2026-11-20 に再ビルド版 `sha256:65a65fc7…` へ更新）。ビルド時に `apt-get upgrade` で Debian のセキュリティ修正を適用 |
| pip | イメージ同梱 26.2.2 | 26.3。同梱ライブラリの既知脆弱性を修正 |
| pytest | バージョン未指定 | 9.2.0（PyPI 最新安定版） |
| Ruff | バージョン未指定 / py313 | 0.17.6 / py315（2026-11-20 時点の PyPI 最新安定版）。実行 Python と解析対象を統一 |
| 開発依存 / pip | 未固定 / pip版のみ指定 | `requirements.txt` と `requirements-bootstrap.txt` に全依存・配布ハッシュを記録 |
| CI | なし | テスト、lint、整形、型チェック、カバレッジ、コミット前フック、pip-audit、コンテナビルド・ターミナル環境の確認・Dev Container としての起動の確認・Trivy、ワークフローと Dockerfile とシェルスクリプトの静的解析、Windows と macOS での改行コードとホストでのコミットの確認（push・PR・手動実行時。定期実行はなし）。ジョブの構成と、main の必須チェックの推奨設定は [CI監査方針](docs/ci-security-policy.md) |
| Dev Container Features | なし | 追加なし |

推移的依存は `requirements.txt` で固定しています（2026-11-20 時点の PyPI 最新安定版）。Issue #11 で追加したツールと合わせて、直接依存6件・推移的依存24件です。

GitHub Actions（コミット SHA で固定。タグはピン留めした SHA に付けたコメントの値です。github.com のリリースページにはこの検証環境から届かないため、最新版かどうかは Dependabot の github-actions 更新で追います。調査日 2026-11-20）:

| Action | 採用版 | 公式 |
| --- | --- | --- |
| actions/checkout | v7.0.1 | https://github.com/actions/checkout |
| actions/setup-python | v7.1.0 | https://github.com/actions/setup-python |
| actions/upload-artifact | v7.0.2 | https://github.com/actions/upload-artifact |
| actions/download-artifact | v8.0.2 | https://github.com/actions/download-artifact |
| aquasecurity/trivy-action | v0.36.0（Trivy 本体は 0.76.2 に固定） | https://github.com/aquasecurity/trivy-action |

**OS 層の再現性**: ベースイメージは digest で固定していますが、ビルド時の `apt-get upgrade` が、その時点で Debian が公開しているセキュリティ修正を取り込みます。
そのため OS パッケージの版はビルドした日によって変わります（Python と pip の依存はハッシュで固定しているので変わりません）。
監査した時点の一覧は [docs/os-packages.txt](docs/os-packages.txt) と、CI の `container-audit-amd64` artifact（arm64 は `container-audit-arm64`） の `os-packages.txt` に残しています。
監査ゲートは、ベースラインにない High/Critical の検出をすべて止めます（[CI監査方針](docs/ci-security-policy.md)）。具体的には、検出のあるパッケージの版が変わった場合、修正版が出た場合、新しい検出が出た場合です。検出が修正で消えただけの場合や、検出のないパッケージの版が変わっただけの場合は止めません。その場合、CI は `docs/os-packages.txt` との差分を警告として表示するだけです。完全に固定したい場合は snapshot.debian.org を使う方法がありますが、修正の取り込みが遅れるため採用していません。

公式情報: [Python イメージ](https://hub.docker.com/_/python)、
[採用タグのメタデータ](https://hub.docker.com/v2/repositories/library/python/tags/3.15.2-slim-trixie)、
[Python サポート状況](https://devguide.python.org/versions/)、
[Debian のサポート期限](https://www.debian.org/releases/)、
[pytest](https://pypi.org/project/pytest/)、[Ruff](https://pypi.org/project/ruff/)。
Python は `>=3.15,<3.16` をサポート対象とし、次の minor 版はテスト後に移行します。
これは Dev Container と公開するパッケージメタデータを同じ検証済み minor に限定する意図的な契約です。
`pip install .` は3.15以外では拒否され、3.16への対応時は `setup.py` の上限も明示的に更新します。
Python 3.15 は公式 [リリース周期 API](https://peps.python.org/api/release-cycle.json) で
`bugfix` サポート、初回公開日2026-10-09、サポート終了予定2031-10と確認しました。
詳細は [PEP 790](https://peps.python.org/pep-0790/) を参照してください。
Devguide 本体はHTTP403でしたが、同サイトが参照する公式APIで期限を照合済みです。
Debian のサポート期限は www.debian.org がこの検証環境から HTTP 403 のため未照合です（必要になった時点で上記公式表と照合してください）。
Dependabot は pip/Docker/Actions の週次更新を提案します。Python minor 更新時には
`setup.py`、Ruff target、CI の Python 指定も合わせて更新してください。

### 依存を再現・更新する

Dev Container 内にはハッシュ検証済みの依存が導入済みです。コンテナ外でも
Python 3.15 で以下を実行できます。

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install --require-hashes --upgrade -r requirements-bootstrap.txt
python -m pip install --require-hashes --only-binary :all: -r requirements.txt
make check
```

直接依存の変更は `requirements.in` で行い、`make lock` でロックを再生成してください。
`make lock` は Python 3.15 の一時仮想環境（`.venv-lock`）に `pip-tools==7.7.0` を導入して、次のコマンドを実行します。
ロックは Python 3.15 の Linux（x86_64）で生成したものです。
Dependabot の PR でも入力ファイルとロックの整合を確認します。
`requirements-bootstrap.txt` も Dependabot の pip 更新と pip-audit の対象です。
pip は別のハッシュ付きファイルで先に導入します。pip 更新PRではハッシュの公式PyPI照合、
`scripts/verify_pip_sbom.py` の承認版と実コードの再評価、ベースラインの手動レビューが必要です。
依存botの提案だけで承認版を自動更新しません。

```bash
pip-compile --upgrade --generate-hashes --strip-extras --no-emit-index-url --no-emit-trusted-host requirements.in
```

### 監査

CI は最小権限で動き、Actions をコミット SHA に固定しています。checkout した認証情報は残しません（`persist-credentials: false`）。ワークフローは、actionlint と zizmor で検査しています。
`pip-audit==2.10.1` はpip bootstrapを含むロック済み全33依存を監査し、Trivy は完成イメージの
OS と言語パッケージを検査します。サンプルと固定依存はコンパイラを必要としないため、
build-essential は入れていません。追加した OS パッケージと、入れなかったものの理由は[同梱ツール](#同梱ツール)にあります。
Git が引き込む krb5・expat・curl のライブラリと、curl コマンドには Debian 未修正の High が残ります。OpenSSH クライアントには、Debian 未修正の Critical が1件と High が5件残ります（[全検出一覧](docs/security-findings.json)）。
次の運用で緩和してください。

- 信頼できないリポジトリを `--recurse-submodules` 付きで clone しない。
- 信頼できないブランチや PR を、このコンテナで merge・rebase・cherry-pick・merge-tree しない（CVE-2026-105437）。どうしても行う場合は、上流が示す回避策として、各リポジトリの `.git/info/attributes` に `* conflict-marker-size=7` を書く。
- 信頼できない `git fast-import` ストリーム、XML、SQLite ファイルを扱わない。
- curl では URL に `https://` を必ず書き、信頼できるホストだけを相手にする（CVE-2026-12064、CVE-2026-8458）。
- SSH では、信頼できるホストにだけ接続する（CVE-2026-60002）。信頼できない URL を Git のリモートに設定しない（CVE-2026-106583）。

HIGH/CRITICALは全件を記録し、新規・修正可能な項目を失敗させます。既知残件に限定した判定は[CI監査方針](docs/ci-security-policy.md)を参照してください。
結果 JSON は CI artifact に保存されます。監査失敗を無視せず、CVE/GHSA、影響、
修正版、担当、追跡 Issue を記録してください。秘密や未公開の脆弱性情報は公開しません。

```bash
make audit
make audit-container
```

`make audit` は pip-audit を、`make audit-container` はイメージのビルド・Trivy・ベースラインとの照合を実行します。実行されるコマンドは [Makefile](Makefile) にあります。

既知の未修正 High が残っているため、Trivy に `--exit-code 1` を付けると常に失敗します。合否はベースラインと照合する `check_container_audit.py` で判定してください（既知の残件だけなら `blocking: 0` で成功します）。残件の一覧は [docs/security-findings.json](docs/security-findings.json) にあります。Debian の修正待ちの118件は [Issue #9](https://github.com/tomohiroJin/devcontainer-python/issues/9) に記録しています（修正待ちとして一旦閉じています）。curl コマンドの追加で増えた4件は Issue #9 の記載には含まれていないため、一覧とベースラインの理由を参照してください。2026-11-21 に追加した OpenSSL の3件（CVE-2026-124709）も同じです。経緯は[検証記録](docs/mob-feedback-validation.md)にあります。同じ日に `openssh-client` の追加で増えた6件（Critical 1件を含む）は、[検証記録](docs/git-access-validation.md)にあります。

pip の HTTPS 通信にプロキシ CA が必要な環境では、Dockerfile の任意 BuildKit secret `proxy_ca` に
信頼済み CA バンドルを渡します（例: `--secret id=proxy_ca,src=/path/to/ca-bundle.pem`）。
CA をイメージへコピーしたり TLS 検証を無効化したりしません。

検証結果・制限は [検証記録](docs/maintenance-validation.md) を参照してください。
Issue #11（開発環境の強化）の検証結果は [開発環境の検証記録](docs/dev-environment-validation.md) にあります。
