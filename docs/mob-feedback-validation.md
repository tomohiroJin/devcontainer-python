# Issue #16・#22 検証記録（日本語の名前、PATH、テストの自動再実行）

日付: 2026-11-21。基準コミット: `88966e8`（main）。対象: [Issue #16](https://github.com/tomohiroJin/devcontainer-python/issues/16) のうち日本語の名前の部分と、[Issue #22](https://github.com/tomohiroJin/devcontainer-python/issues/22) のうち PATH と pytest-watcher の部分。親は [Issue #13](https://github.com/tomohiroJin/devcontainer-python/issues/13) です。

採用したものと理由は [README](../README.md) の「Ruff のルール」「同梱ツール」「ターミナル」にあります。ここには、変更前の再現と、変更後の検証の結果を記録します。

## 変更前の再現（main のイメージ）

- **日本語の名前**: 日本語のテスト名を含むファイルをコンテナ内でコミットすると、コミット前フックの `ruff check` が `N802`・`N999` で失敗しました。関数名・引数名・変数名・クラス名・ファイル名のどれも違反になります（`N802`・`N803`・`N806`・`N801`・`N999`）。pytest と mypy は成功しました。
- **PATH**: `vscode` ユーザーで `pip install pytest-watch` を実行すると、`~/.local/bin` に入り、`ptw` が見つかりませんでした。`~/.local/bin` を PATH に足すのは `~/.profile`（ログインシェルだけが読み、ディレクトリがある場合だけ足す）で、VS Code のターミナルには効きません。

## 採否を決めるために確認したこと

- **pytest-watch**: 最後のリリースは 4.2.0（2018-05-20）です。wheel がなく、`pip download --only-binary :all: pytest-watch` は失敗しました。
- **pytest-watcher**: 0.6.3（2026-01-10 公開）。依存は watchdog（7.1.0、2026-11-05 公開）だけです。Python 3.15 のコンテナで、どちらも wheel で入りました。watchdog には `manylinux2014_x86_64` と `manylinux2014_aarch64` の wheel があります。
- **pytest-watcher と watchdog 7 の組み合わせ**: 既定の設定では、`tests/` のファイルを保存してもテストが再実行されませんでした。
  - 原因: watchdog 7 のパターン照合（`watchdog.utils.patterns`）は、`PurePath.full_match` でパス全体を照合します。pytest-watcher 0.6.3 の既定のパターン `*.py` は、`./tests/test_a.py` のようなサブディレクトリのパスに一致しません。
  - 対処: `pyproject.toml` の `[tool.pytest-watcher]` で `patterns = ["**/*.py"]` を指定しました。サブディレクトリのファイルと、直下のファイルの両方で再実行されること、`.md` のファイルでは再実行されないことを確かめました。
  - pytest-watcher は、テストの実行中に届いた変更を捨てます（実行後に、たまった変更を消します）。レビューの指摘を受けて、`scripts/watch_runner.py` で対処しました（下の「レビューでの指摘と対応」）。

## 変更後の検証

Dockerfile と同じ手順でビルドしたイメージで確かめました。この検証環境は apt の HTTP 通信がプロキシを通らないため、これまでと同じく、apt の取得先だけを HTTPS とプロキシに差し替えた一時 Dockerfile を使いました。

- **`make check`**: lint、型チェック、テスト55件（うち日本語の名前のテスト6件）、`scripts/` の単体テスト26件が成功しました。
- **コミット**: 日本語の名前のファイル（`tests/test_日本語の名前.py`）を含むコミットが、コミット前フック（11個すべて Passed）を通りました。`make pre-commit` も成功しました。
- **`pytest -k "足す"`**: 日本語のテスト名を選んで実行できました。
- **PATH**: `pip install pytest-watch` で後から入れた `pytest-watch` コマンドが、設定を変えずに見つかりました。
- **`scripts/check_devcontainer.sh`**: すべて成功しました。追加した検査は次のとおりです。
  - `ptw` コマンドがあること
  - `~/.local/bin` が PATH にあり、そこに置いたコマンドが、通常のシェル・対話シェル・`make` から見つかること
  - `~/.local/bin` に同じ名前のコマンドがあっても、同梱の `ptw` が使われること（通常のシェル・対話シェル・ログインシェル・`make`）
  - `ptw` が、起動時にテストを実行し、サブディレクトリのファイルの変更で再実行すること
  - `ptw` が、テストの実行中に保存された変更で、もう一度実行すること
- **検査が問題を検出できること**: main のイメージに対して新しい `check_devcontainer.sh` を実行すると、`ptw` と PATH の5件が失敗しました。`patterns` の設定を外すと、再実行の2件が失敗しました。
- **pip-audit 2.10.1**: `make audit` で、pip を含む33依存すべてに既知の脆弱性がありませんでした（[JSON](pip-audit.json)）。
- **pip の SBOM**: `scripts/verify_pip_sbom.py` と `pip check` が成功しました。
- **ロックファイル**: `requirements.txt` の差分は、pytest-watcher と watchdog の追加だけです。既存の依存の版とハッシュは変わっていません。

## レビューでの指摘と対応（2026-11-21）

PR #23 のレビューで、次の2点の指摘があり、どちらも再現しました。

1. **`~/.local/bin` の同名コマンドが、同梱の `ptw` を上書きする**
   - 再現: 最初の実装は、`~/.local/bin` を PATH の先頭に入れていました。そこに `ptw` という名前のコマンドを置くと、`command -v ptw` が `~/.local/bin/ptw` を返しました。`pytest-watch` を入れた人の環境では、`make watch` が古い `ptw` を起動します。
   - 対応: `~/.local/bin` を PATH の末尾に移しました（`ENV PATH=$PATH:...`）。あわせて、Debian の `~/.profile` から、ログインシェルで `~/.local/bin` を PATH の先頭に足す部分を取り除きました。
   - 確認: `pytest-watch` を `pip install` した状態で、`command -v ptw` が `/usr/local/bin/ptw` を返し、`make watch` が同梱の pytest-watcher でテスト55件を実行しました。`pytest-watch` コマンド（同梱にない名前）は、そのまま見つかります。
   - 残る制約: Python のモジュールは、ユーザー領域（`~/.local/lib`）が先に読まれます。同梱のパッケージの別の版を `pip install` すると、`python -m pytest` などはそちらを使います。README に書きました。
2. **テストの実行中に保存すると、古い結果が表示されたままになる**
   - 再現: 時間のかかるテストの実行中にファイルを保存すると、pytest-watcher は変更を検出しましたが、実行の終了後に再実行しませんでした。
   - 対応: `ptw` が pytest の代わりに `scripts/watch_runner.py` を起動するようにしました。このスクリプトは、実行の開始時刻より後に更新された `*.py` があれば、まとめてもう一度実行します。続けて実行するのは5回までです。単体テストは `scripts/test_watch_runner.py` にあります。
   - 確認: `scripts/check_devcontainer.sh` に、4秒かかるテストの実行中に保存し、次の実行に新しいテストが含まれることを確かめる検査を追加しました。

追加した検査が問題を検出できることも確かめました。修正前のイメージでは、PATH の優先順位の4件が失敗しました。`runner` の設定を外すと、実行中の保存の2件が失敗しました。修正後のイメージでは、3回続けてすべて成功しました。

## CI で見つかった新しい検出（この変更とは無関係）

この PR の最初の CI（run 44901086769、2026-11-21）で、`python` と `container` は成功し、`security` が次の3件をブロックしました。

```text
BLOCK: CVE-2026-124709 libssl3t64 3.5.9-1~deb13u1: new finding or changed package/severity
BLOCK: CVE-2026-124709 openssl 3.5.9-1~deb13u1: new finding or changed package/severity
BLOCK: CVE-2026-124709 openssl-provider-legacy 3.5.9-1~deb13u1: new finding or changed package/severity
Raw findings: HIGH=126; CRITICAL=0
Reviewed: 123; blocking: 3
```

- **この PR との関係**: ありません。この PR は OS パッケージを変えていません。追加した pytest-watcher と watchdog からは、検出が出ていません。ビルド時の `apt-get upgrade` が Debian trixie の更新を取り込み、OpenSSL が 3.5.7-1~deb13u3 から 3.5.9-1~deb13u1 に上がりました。あわせて `base-files`・`libc-bin`・`libc6`・`libnghttp2-14` も上がっています。既存の123件は、同じ run ですべてベースラインと一致しました。
- **内容**: OpenSSL の QUIC サーバーが、相手がリセットしたストリームの状態を解放しない問題です。QUIC で接続したクライアントが、サーバーのメモリを使い切らせることができます（サービス拒否）。
- **Debian の状況**: Debian Security Tracker（2026-11-21 取得）では、trixie・forky・sid が `open` で修正版がなく、緊急度は未割り当てです。リビルドでは解消しません。
- **このコンテナへの影響**: QUIC サーバーを動かした場合だけ該当します。この開発コンテナは、OpenSSL を TLS のクライアント（Python の `ssl`、curl）としてだけ使います。
- **対応**: 担当者（リポジトリ所有者）の承認を得て（2026-11-21、PR #23）、3件を理由付きで[ベースライン](../security/container-baseline.json)に追加しました。[全検出一覧](security-findings.json)と [OS パッケージ一覧](os-packages.txt)も更新しています。Debian が修正版を出すと、ゲートが「a fix is now available」でブロックするので、そのときに取り込みます。
- **記録の作り方**: この検証環境からは CI の artifact（`trivy.json`）を取得できません。そのため、3件は `security` ジョブのログの表示（CVE・パッケージ・版）から書きました。OS パッケージ一覧は、キャッシュなしで手元でビルドしたイメージから作り、CI のログに出た差分と一致することを確かめました。ベースラインの照合は、CI の再実行で確かめます。

## 確かめていないこと

- **Trivy**: この PR は OS パッケージを変えていません。Python パッケージ2件の追加による検出の増減は、CI の `container`・`security` ジョブで確かめます。
- **VS Code 上の表示**: テストエクスプローラーでの日本語のテスト名の表示と、タスク `watch` の起動は、この検証環境（VS Code なし）では確かめていません。
- **Docker Desktop（macOS・Windows）と WSL2 でのファイル監視**: Linux のバインドマウントでは動きました。他の環境での動作は Issue #22 に残しています。
- **arm64**: wheel があることは確かめましたが、ビルドはしていません（Issue #19）。
