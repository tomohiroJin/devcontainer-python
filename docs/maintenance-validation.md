# Issue #6 検証記録

日付: 2026-11-05。基準コミット: `88f32205b2579d9a827d2e31d067a4935b7c5afe`。
記録対象はこのコミットを基にした未コミット変更です。

## 実行結果

- Python `3.15.2-slim-trixie` の公式タグ・manifest digest を Docker Hub API で取得し pull 成功。
- `pip-tools==7.6.2` を Python 3.15 コンテナで実行し、6件の直接・推移的依存をハッシュ固定。
- 更新 Dockerfile を BuildKit でビルド成功（pip 用の任意 proxy_ca secret に CA bundle を使用）。
  その後、HTTPを使うaptステップの効力がない SSL_CERT_FILE export と secret mount を削除。
  パッケージ構成は変更しておらず、この記述整理後の再ビルドは未実施。
- 最終イメージ ID: `sha256:45179cc09ce518fd54f001ce31efd280c69ee4ea37a6d0a726243108355a7428`。
- イメージ内の `vscode`（UID 1000）で Python 3.15.2 / pytest 9.2.0 の49テストが成功。
- 同環境で `ruff check --no-cache .`、`ruff format --no-cache --check .`（32ファイル）、`pip check` が成功。
- `pip-audit==2.10.1 --strict --no-deps --disable-pip -r requirements.txt` は6依存すべて既知脆弱性なし。[JSON](pip-audit.json)
- VS Code の設定 JSON 解析、必須拡張と推奨拡張リストの一致、`git diff --check` が成功。
- CI の actionlint は親担当が確認。GitHub Actions 自体の実行は未実施。

## コンテナ監査の残件

Trivy 0.76.2、DB更新時刻 2026-11-05 13:09:41 UTC。
`trivy image --skip-db-update --scanners vuln --severity HIGH,CRITICAL --format json`
で上記最終イメージを監査し、HIGH 55件・CRITICAL 0件を検出。
検査結果は脆弱性IDとパッケージの組み合わせの件数です。
[全検出一覧](security-findings.json) に各ID・版・修正版・状態・参照URLを記録しています。

- Debian 13.7 の OS パッケージで HIGH 54件。DB 上で修正版指定がないため、
  アプリ依存の更新で解消したとは扱いません。対象は util-linux 系、curlの共有ライブラリ、
  expat、ncurses、Perl、SQLite、systemd、zlib 等です。
- Python パッケージの HIGH 1件は `CVE-2025-47273`（setuptools 70.3.0、修正版78.1.1）。
  検出元は pip 26.3 に同梱された `_vendor/bom.cdx.json` の SBOM です。
  実行環境の `pip list` には setuptools はなく、`importlib.util.find_spec("setuptools")`
  は `None`、ファイル検索でも setuptools 本体は検出されませんでした。
  pip は `_vendor/pkg_resources` のみを同梱しています。
  インストール済み setuptools の更新だけでは解決できないため、pip 上流の同梱情報と
  影響範囲を引き続き確認します。誤検知と断定した除外は追加していません。
- pip 26.2.2 を26.3に更新して、msgpack/urllib3 の修正版がある HIGH 4件を解消。
- 不要な build-essential/curl/vim を外して OS パッケージを174件から119件に削減し、
  初回の OS HIGH 79件を54件に削減しました。

残件は既存の [Issue #6](https://github.com/tomohiroJin/devcontainer-python/issues/6) で追跡します。
担当: Repository maintainer。次回確認期限: **2026-11-12**。
週次 CI で再検査し、修正公開時にベース digest / pip を更新してビルド・監査を再実行します。
当面の緩和策は非root実行、不要パッケージの削除、信頼できないプロジェクトやファイルの
実行を避けることです。CI は未修正を含む HIGH/CRITICAL を隠さず失敗させます。
このため現状では security ジョブの成功や脆弱性対応の完全完了は主張しません。

## 未実施・外部確認

- VS Code GUI での補完・定義ジャンプ・型診断・F5デバッグ・Test Explorer・保存時整形は未実施。
  README の確認手順と明示的な debugpy launch 設定を用意しました。
- Python のサポート期限は Devguide 本体のHTTP403に対し、同サイトが参照する
  [公式リリース周期API](https://peps.python.org/api/release-cycle.json) を親担当が照合済みです。
  Python 3.15 は `bugfix`、初回公開2026-10-09、終了予定2031-10。
  根拠は [PEP 790](https://peps.python.org/pep-0790/) です。
  Debian の期限は次回確認期限までに公式表と照合します。
- 環境公開、push、PR作成、Issue のクローズは行っていません。
