# Devcontainer Python

このリポジトリは、Python プロジェクトの開発環境を簡単に構築できる Devcontainer を利用したテンプレートです。必要なツールや依存関係があらかじめ設定されており、一貫した開発環境を提供します。

## 特徴

- **Python 3.15.2** を使用
- あらかじめインストールされているツール:
  - `pytest`（テストフレームワーク）
  - `ruff`（リンタ兼フォーマッタ）
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

4. セットアップを確認するためにテストを実行します:

   ```bash
   pytest
   ```

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

## 使用方法

### **1. テストの実行**

`pytest`を使用してプロジェクトのテストを実行します。以下のように、さまざまな方法でテストを実行できます。

#### **すべてのテストを実行**

```bash
pytest
```

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

#### **テスト中の出力を確認**

テスト中の`print`やログの出力を確認したい場合、`-s`オプションを使用します。

```bash
pytest -s
```

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

## **カスタマイズ**

- `.devcontainer/devcontainer.json` で VS Code 拡張や `remoteUser` を編集できます。
- `.devcontainer/Dockerfile` で Python のバージョンや追加する OS パッケージを変更できます。
- `requirements.txt` を変更した場合は Devcontainer をリビルドすることで反映されます（VS Code: `Dev Containers: Rebuild Container`）。

## ライセンス

このプロジェクトは MIT ライセンスの下で提供されています。

## 更新・セキュリティ運用（Issue #6）

調査日: 2026-11-05。既定ブランチ `88f32205b2579d9a827d2e31d067a4935b7c5afe`
を基に更新しています。採用版は日付から推測せず、公式の公開 API で取得した安定版です。

| 対象 | 更新前 | 採用版・理由 |
| --- | --- | --- |
| Python / OS | `3.13-slim`（OS 不定） | `3.15.2-slim-trixie`、Debian 13。公式公開タグの最新安定系列を採用し digest 固定 |
| pip | イメージ同梱 26.2.2 | 26.3。同梱ライブラリの既知脆弱性を修正 |
| pytest | バージョン未指定 | 9.2.0（PyPI 最新安定版） |
| Ruff | バージョン未指定 / py313 | 0.17.3 / py315。実行 Python と解析対象を統一 |
| 開発依存 / pip | 未固定 / pip版のみ指定 | `requirements.txt` と `requirements-bootstrap.txt` に全依存・配布ハッシュを記録 |
| CI | なし | テスト、lint、整形、pip-audit、コンテナビルド・Trivy、週次実行 |
| Dev Container Features | なし | 追加なし |

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
Debian のサポート期限は上記公式表を次回更新時（2026-11-12）に再確認します。
Dependabot は pip/Docker/Actions の週次更新を提案します。Python minor 更新時には
`setup.py`、Ruff target、CI の Python 指定も合わせて更新してください。

### 依存を再現・更新する

Dev Container 内にはハッシュ検証済みの依存が導入済みです。コンテナ外でも
Python 3.15 で以下を実行できます。

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install --require-hashes --upgrade -r requirements-bootstrap.txt
python -m pip install --require-hashes -r requirements.txt
python -m pytest
ruff check .
ruff format --check .
```

直接依存の変更は `requirements.in` で行い、Python 3.15 の一時仮想環境に
`pip-tools==7.6.2` を導入して次のコマンドでロックを再生成してください。
Dependabot の PR でも入力ファイルとロックの整合を確認します。
`requirements-bootstrap.txt` も Dependabot の pip 更新と pip-audit の対象です。
pip は別のハッシュ付きファイルで先に導入します。pip 更新PRではハッシュの公式PyPI照合、
`scripts/verify_pip_sbom.py` の承認版と実コードの再評価、期限付きベースラインの手動レビューが必要です。
依存botの提案だけで承認版や期限を自動更新しません。

```bash
pip-compile --upgrade --generate-hashes --strip-extras --no-emit-index-url --no-emit-trusted-host requirements.in
```

### VS Code

必須構成は Microsoft Python / Pylance / Python Debugger と Astral Ruff の4件です。
各 ID は提供元の現行公式拡張であることと Marketplace の公開状態を確認済みです
（Python 2026-10-29、Pylance 2026-10-16、Debugger 2026-11-02、Ruff 2026-10-27 更新）。
[Python 公式ガイド](https://code.visualstudio.com/docs/python/python-tutorial)、
[Ruff 公式ガイド](https://docs.astral.sh/ruff/editors/setup/) に基づく構成です。
`.vscode/extensions.json` と Dev Container の必須リストを共通にし、Ruff は
コンテナに固定した版を優先、lint/format/import 整理を担当します。
Pylance が型診断、pytest がテスト検出、debugpy がデバッグを担当します。
Notebook を含まないため Jupyter は任意です。Git Graph、スペルチェック、Live Share、
change-case、Prettier も必要な利用者だけ導入してください。Python の整形は Ruff に統一します。

VS Code で開いたら Python インタープリター `/usr/local/bin/python`、テスト一覧の49件、
F5 の Python デバッガ、補完・定義ジャンプ・型診断、保存時整形と import 整理を確認します。
コンテナ外ではインタープリターを自身の `.venv` に選び直してください。

### 監査

CI は最小権限で動き、Actions をコミット SHA に固定しています。
`pip-audit==2.10.1` はpip bootstrapを含むロック済み全7依存を監査し、Trivy は完成イメージの
OS と言語パッケージを検査します。サンプルと固定依存はコンパイラを必要としないため、
従来の build-essential/curl/vim を外し、Git と CA 証明書に OS 追加パッケージを絞っています。HIGH/CRITICALは全件を記録し、新規・修正可能・期限切れの項目を失敗させます。既知残件に限定した期限付き判定は[CI監査方針](docs/ci-security-policy.md)を参照してください。
結果 JSON は CI artifact に保存されます。監査失敗を無視せず、CVE/GHSA、影響、
修正版、担当、期限、追跡 Issue を記録してください。秘密や未公開の脆弱性情報は公開しません。

```bash
pip-audit --strict --no-deps --disable-pip -r requirements-bootstrap.txt -r requirements.txt --format json --output pip-audit.json
docker build --pull -f .devcontainer/Dockerfile -t devcontainer-python:local .
trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 devcontainer-python:local
```

pip の HTTPS 通信にプロキシ CA が必要な環境では、Dockerfile の任意 BuildKit secret `proxy_ca` に
信頼済み CA バンドルを渡します（例: `--secret id=proxy_ca,src=/path/to/ca-bundle.pem`）。
CA をイメージへコピーしたり TLS 検証を無効化したりしません。

検証結果・制限は [検証記録](docs/maintenance-validation.md) を参照してください。
