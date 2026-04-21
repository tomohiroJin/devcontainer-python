# Devcontainer Python

このリポジトリは、Python プロジェクトの開発環境を簡単に構築できる Devcontainer を利用したテンプレートです。必要なツールや依存関係があらかじめ設定されており、一貫した開発環境を提供します。

## 特徴

- **Python 3.13** を使用
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
