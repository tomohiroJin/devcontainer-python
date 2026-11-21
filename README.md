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

4. セットアップを確認するために、lint・型チェック・テストをまとめて実行します:

   ```bash
   make check
   ```

   使えるコマンドの一覧は `make help` で確認できます。

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
| `make lint` | `ruff check` と `ruff format --check`（ファイルは変更しません） |
| `make fmt` | `ruff check --fix` と `ruff format`（ファイルを書き換えます） |
| `make typecheck` | mypy で `src`・`tests`・`scripts` を型チェック |
| `make cov` | カバレッジ付きでテスト。端末に未実行の行を表示し、`coverage.xml` と `htmlcov/` を出力 |
| `make pre-commit` | コミット前フックを全ファイルに実行 |
| `make hooks` | コミット前フックを Git に登録（Dev Container の作成時に自動で実行） |
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
- **後から入れたコマンド**: `pip install <パッケージ>` は、`vscode` ユーザーの `~/.local` に入ります。コマンドの置き場所の `~/.local/bin` は PATH に入れてあるので、入れたコマンドはそのまま使えます（Dockerfile の `ENV PATH`。ターミナル、VS Code のタスク、`make` のどれでも有効です）。ただし、後から入れたものはコンテナを作り直すと消え、ハッシュによる固定と脆弱性監査の対象にもなりません。続けて使うツールは `requirements.in` に追加し、`make lock` を実行してからリビルドしてください。
- **エイリアス**: `ll`、`la`、`..`、`gs`（`git status --short --branch`）、`gd`（`git diff`）、`gl`（`git log` の1行グラフ表示）、`py`、`ipy`。
- **日本語**: ロケールは `C.UTF-8` です。日本語の表示・入力・ファイル名を扱えます。メッセージは英語のままです（日本語メッセージ用の `locales` パッケージは入れていません）。
- **タイムゾーン**: ホストに環境変数 `TZ` があればその値をそのまま渡し、なければ `Asia/Tokyo` を使います。ホストの `TZ` が空や `:/etc/localtime` のような値の場合は UTC になります。変えるときは `devcontainer.json` の `containerEnv` を編集してください。
- **ページャー**: `less` を入れ、`LESS=-FRX`（1画面に収まるときはそのまま表示、色を保持）にしています。slim イメージは man ページを含まないため、`man` は入れていません。使い方は `コマンド --help | less` で確認してください。
- **Git**: [.devcontainer/shell/gitconfig](.devcontainer/shell/gitconfig) を `/etc/gitconfig` に置いています。ページャー（`less -FRX`）、色、日本語のファイル名をそのまま表示する設定（`core.quotepath=false`）、差分の計算方法（`diff.algorithm=histogram`）、移動した行の色分け、日付の形式、既定のブランチ名（`main`）を設定します。`~/.gitconfig`（VS Code がホストからコピーするものを含む）とリポジトリごとの設定が優先されます。

イメージをビルドしたあとの確認は、コンテナ内で次のコマンドを実行します（CI でも実行しています）。

```bash
bash scripts/check_devcontainer.sh
```

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

`git` と `ca-certificates` 以外の8個のうち、High/Critical の検出があるのは `curl` だけです（`curl` と `libcurl4t64` に各2件、合計4件）。CVE の番号は、Git が使う `libcurl3t64-gnutls` の検出と同じで、Debian に修正版がありません。理由を付けて[ベースライン](security/container-baseline.json)に入れています。
このうち CVE-2026-12064 は、curl コマンドに scheme のない URL を渡して SFTP/SCP で接続したときの問題です。curl コマンドを入れたことで該当するようになりました。curl を使うときは、URL に `https://` を必ず書き、SFTP/SCP には使わず、信頼できるホストだけを相手にしてください。

### 入れなかったもの

| 対象 | 理由 |
| --- | --- |
| `sudo` | パスワードなしの sudo を入れると、非 root で動かす意味がなくなります。一時的にパッケージを足すときは、ホストから `docker exec -u root -it <コンテナ名> bash` で入って `apt-get update && apt-get install <パッケージ>` を実行してください。恒久的に足すときは Dockerfile に書きます |
| `openssh-client` | Trivy で Critical 1件（CVE-2026-60002）と High 5件が増え、いずれも Debian に修正版がありません（2026-11-20 時点）。Git の接続は HTTPS を使ってください（VS Code がホストの認証情報を引き継ぎます）。SSH のリモートが必要な場合は、上記の検出を確認したうえで Dockerfile に追加してください。その際は、`ssh` がないことを確認している `scripts/check_devcontainer.sh` の該当行と、ベースラインも更新が必要です |
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

pytest に引数を渡したいときは、`ptw` を直接使います。`ptw <監視するディレクトリ> <pytest の引数>` の形です。

```bash
ptw . tests/reference/samples -x
```

設定は `pyproject.toml` の `[tool.pytest-watcher]` にあります。テストの実行中に保存した変更は、再実行のきっかけになりません。その場合は、もう一度保存してください。

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

Dev Container を作成すると、`make hooks` がコミット前フックを Git に登録します。登録に失敗しても（ホストの Git 設定に `core.hooksPath` がある場合など）コンテナの作成は続き、メッセージだけを表示します。`git commit` のたびに、次の検査をステージしたファイルに実行します。CI も `make pre-commit` で同じ検査を全ファイルに実行します。

- 行末の空白の削除、ファイル末尾の改行、改行コードの統一（LF）
- JSON・YAML・TOML の構文、マージ競合の印、大きなファイルの追加
- `ruff check --fix`、`ruff format`、`mypy`

フックがファイルを修正した場合、コミットは中断されます。差分を確認して `git add` し、もう一度コミットしてください。全ファイルに実行するときは次のコマンドを使います。

```bash
make pre-commit
```

フックは `.git/hooks/pre-commit` に登録され、`prek` を呼び出します。コンテナの外（ホスト）からコミットすると、`prek` が見つからずに失敗します。ホストからもコミットする場合は、ホストに prek を導入するか、コンテナ内で `prek uninstall` を実行してフックを外してください。

`.vscode/*.json` と `devcontainer.json` も JSON の構文検査の対象です。コメントは書かないでください。

---

### **6. 対話シェル (IPython)**

```bash
ipython
```

## VS Code

必須の拡張は Microsoft Python / Pylance / Python Debugger と Astral Ruff の4件です。
各 ID は提供元の現行公式拡張であることと Marketplace の公開状態を確認済みです
（Python 2026-10-29、Pylance 2026-10-16、Debugger 2026-11-02、Ruff 2026-10-27 更新）。
[Python 公式ガイド](https://code.visualstudio.com/docs/python/python-tutorial)、
[Ruff 公式ガイド](https://docs.astral.sh/ruff/editors/setup/) に基づく構成です。
`.vscode/extensions.json` と Dev Container の必須リストを共通にし、Ruff は
コンテナに固定した版を優先、lint/format/import 整理を担当します。
Pylance が型診断、pytest がテスト検出、debugpy がデバッグを担当します。
Python の整形は Ruff に統一します。

**任意の拡張**は `devcontainer.json` と `extensions.json` には入れていません。必要な人だけ導入してください。
Marketplace にはこの検証環境から接続できないため、下の表の公開状態と更新日は確認していません。導入前に提供元を確認してください。

| 拡張 | ID | 用途 |
| --- | --- | --- |
| Mypy Type Checker | `ms-python.mypy-type-checker` | CI と同じ mypy の結果をエディターに表示。`settings.json` でコンテナ内の mypy を使う設定にしてあります |
| GitLens | `eamodio.gitlens` | 行ごとの変更履歴（blame）や履歴の比較。機能が多く、一部は有料です。履歴を詳しく調べたい場合に向きます |
| Git Graph | `mhutchie.git-graph` | コミットグラフの表示だけを行う軽い拡張です。グラフだけ見たい場合は GitLens よりこちらで足ります。端末では `gl` でも見られます |
| Error Lens | `usernamehw.errorlens` | 診断を行の横に表示 |
| Even Better TOML | `tamasfe.even-better-toml` | `pyproject.toml` の補完と検証 |
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
- `.devcontainer/Dockerfile` で Python のバージョンや追加する OS パッケージを変更できます。OS パッケージを足したときは、`make audit-container` で Trivy の検出が増えていないか確認してください。`scripts/check_devcontainer.sh` は `sudo`・`ssh`・`gcc`・`vim` が入っていないことも確認しているので、これらを足す場合はその行も直してください。
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
| CI | なし | テスト、lint、整形、型チェック、カバレッジ、コミット前フック、pip-audit、コンテナビルド・ターミナル環境の確認・Trivy（push・PR・手動実行時。定期実行はなし） |
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
監査した時点の一覧は [docs/os-packages.txt](docs/os-packages.txt) と、CI の `container-audit` artifact の `os-packages.txt` に残しています。
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

CI は最小権限で動き、Actions をコミット SHA に固定しています。
`pip-audit==2.10.1` はpip bootstrapを含むロック済み全33依存を監査し、Trivy は完成イメージの
OS と言語パッケージを検査します。サンプルと固定依存はコンパイラを必要としないため、
build-essential は入れていません。追加した OS パッケージと、入れなかったものの理由は[同梱ツール](#同梱ツール)にあります。
Git が引き込む krb5・expat・curl のライブラリと、curl コマンドには Debian 未修正の High が残ります（[全検出一覧](docs/security-findings.json)）。
次の運用で緩和してください。

- 信頼できないリポジトリを `--recurse-submodules` 付きで clone しない。
- 信頼できないブランチや PR を、このコンテナで merge・rebase・cherry-pick・merge-tree しない（CVE-2026-105437）。どうしても行う場合は、上流が示す回避策として、各リポジトリの `.git/info/attributes` に `* conflict-marker-size=7` を書く。
- 信頼できない `git fast-import` ストリーム、XML、SQLite ファイルを扱わない。
- curl では URL に `https://` を必ず書き、信頼できるホストだけを相手にする（CVE-2026-12064、CVE-2026-8458）。

HIGH/CRITICALは全件を記録し、新規・修正可能な項目を失敗させます。既知残件に限定した判定は[CI監査方針](docs/ci-security-policy.md)を参照してください。
結果 JSON は CI artifact に保存されます。監査失敗を無視せず、CVE/GHSA、影響、
修正版、担当、追跡 Issue を記録してください。秘密や未公開の脆弱性情報は公開しません。

```bash
make audit
make audit-container
```

`make audit` は pip-audit を、`make audit-container` はイメージのビルド・Trivy・ベースラインとの照合を実行します。実行されるコマンドは [Makefile](Makefile) にあります。

既知の未修正 High が残っているため、Trivy に `--exit-code 1` を付けると常に失敗します。合否はベースラインと照合する `check_container_audit.py` で判定してください（既知の残件だけなら `blocking: 0` で成功します）。残件の一覧は [docs/security-findings.json](docs/security-findings.json) にあります。Debian の修正待ちの118件は [Issue #9](https://github.com/tomohiroJin/devcontainer-python/issues/9) に記録しています（修正待ちとして一旦閉じています）。curl コマンドの追加で増えた4件は Issue #9 の記載には含まれていないため、一覧とベースラインの理由を参照してください。2026-11-21 に追加した OpenSSL の3件（CVE-2026-124709）も同じです。経緯は[検証記録](docs/mob-feedback-validation.md)にあります。

pip の HTTPS 通信にプロキシ CA が必要な環境では、Dockerfile の任意 BuildKit secret `proxy_ca` に
信頼済み CA バンドルを渡します（例: `--secret id=proxy_ca,src=/path/to/ca-bundle.pem`）。
CA をイメージへコピーしたり TLS 検証を無効化したりしません。

検証結果・制限は [検証記録](docs/maintenance-validation.md) を参照してください。
Issue #11（開発環境の強化）の検証結果は [開発環境の検証記録](docs/dev-environment-validation.md) にあります。
