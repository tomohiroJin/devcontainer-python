# Issue #6 検証記録

日付: 2026-11-05。基準コミット: `88f32205b2579d9a827d2e31d067a4935b7c5afe`。
この基準コミットを基にした初回ローカル検証と、その後のPR/CI検証の記録です。

## 実行結果

- Python `3.15.2-slim-trixie` の公式タグ・manifest digest を Docker Hub API で取得し pull 成功。
- `pip-tools==7.6.2` を Python 3.15 コンテナで実行し、6件の直接・推移的依存をハッシュ固定。
- 更新 Dockerfile を BuildKit でビルド成功（pip 用の任意 proxy_ca secret に CA bundle を使用）。
  その後、HTTPを使うaptステップの効力がない SSL_CERT_FILE export と secret mount を削除。
  その記述整理後の Dockerfile もPRの実CIでビルド・コンテナテスト成功を確認しました。
- 最終イメージ ID: `sha256:45179cc09ce518fd54f001ce31efd280c69ee4ea37a6d0a726243108355a7428`。
- イメージ内の `vscode`（UID 1000）で Python 3.15.2 / pytest 9.2.0 の49テストが成功。
- 同環境で `ruff check --no-cache .`、`ruff format --no-cache --check .`、`pip check` が成功（対象ファイル数は Ruff 0.17 が Markdown 内のコードブロックも数えるため、ドキュメント追加で変わります。件数ではなく成功可否を記録します）。
- 初回pip-auditは開発依存6件とも既知脆弱性なし。PRレビュー対応でpip bootstrapを加えた7依存を再監査し、7件とも既知脆弱性なしの最新結果を [JSON](pip-audit.json) に保存しました。
- VS Code の設定 JSON 解析、必須拡張と推奨拡張リストの一致、`git diff --check` が成功。
- CI の actionlint は親担当が確認。PRの実GitHub ActionsでもPython・コンテナ検証が成功。

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
  影響範囲は下記CI再検証で公式GHSAと実コードを照合しました。全検出はJSONに残します。
- pip 26.2.2 を26.3に更新して、msgpack/urllib3 の修正版がある HIGH 4件を解消。
- 不要な build-essential/curl/vim を外して OS パッケージを174件から119件に削減し、
  初回の OS HIGH 79件を54件に削減しました。

残件は当時、既存の [Issue #6](https://github.com/tomohiroJin/devcontainer-python/issues/6) で追跡していました（2026-11-20 に [Issue #9](https://github.com/tomohiroJin/devcontainer-python/issues/9) へ移し、担当を tomohiroJin にしました）。
当時の担当表記: Repository maintainer。初回の確認期限は **2026-11-12** でした（2026-11-20 の再評価は末尾の節を参照）。
週次 CI で再検査し、修正公開時にベース digest / pip を更新してビルド・監査を再実行します。
当面の緩和策は非root実行、不要パッケージの削除、信頼できないプロジェクトやファイルの
実行を避けることです。CIの現行判定は[期限付き監査方針](ci-security-policy.md)に従います。
CIが成功しても、脆弱性対応の完全完了を意味しません。

## 未実施・外部確認

- VS Code GUI での補完・定義ジャンプ・型診断・F5デバッグ・Test Explorer・保存時整形は未実施。
  README の確認手順と明示的な debugpy launch 設定を用意しました。
- Python のサポート期限は Devguide 本体のHTTP403に対し、同サイトが参照する
  [公式リリース周期API](https://peps.python.org/api/release-cycle.json) を親担当が照合済みです。
  Python 3.15 は `bugfix`、初回公開2026-10-09、終了予定2031-10。
  根拠は [PEP 790](https://peps.python.org/pep-0790/) です。
  Debian の期限は次回確認期限までに公式表と照合します。
- 初回ローカル検証時は公開・push・PR作成を行わず、その後PR #7を作成して実CIを検証しました。
  環境公開とIssueのクローズは行っていません。

## PR作成時の追加確認（2026-11-06）

GitHub Actions の Python ジョブは成功。コンテナ内の49テストも成功したが、runner と vscode の UID の違いで Ruff のキャッシュ作成が失敗した。CIでは pytest のキャッシュを `/tmp/pytest-cache` に置き、Ruff を `--no-cache` で実行するよう修正した。読み取り可能なソースコピーをUID1001でマウントしたコンテナで49テスト・lint・整形が成功し、actionlintも成功。脆弱性ゲートの残件は上記のとおり。

## CI再検証（2026-11-06）

実CIの失敗原因は記録済みHigh検出を無条件にブロックしていたことと、Trivyがローカル検証と異なる既定版0.70.0だったこと。監査ツールを0.76.2に固定し、実CIの全55検出を版/CVE単位で[監査方針](ci-security-policy.md)に照合する。新規・修正版あり・期限切れを止める7つの判定テストが成功。pipのSBOMに関するコード不在の検証も最終イメージで成功した。テスト・lint・整形と全監査artifactの保存を維持する。

## PRレビュー対応の追加検証

[指摘別の判断と変更](review-response.md)を記録しました。期限は2026-11-12 09:00 JST（00:00 UTC）のままです。
9件の監査判定テストで、残件ありの期限当日/期限後がブロックされ、期限切れでも完全なクリーンレポートが成功することを確認しました。
以前の生レポート（HIGH55/CRITICAL0）に対する判定は確認済み55、ブロック0で、Step Summaryも同じ件数でした。
Ruff lint/整形、actionlint、差分チェックに成功しています。

pip bootstrapは公式PyPIのwheel/sdistハッシュでクリーン仮想環境へ導入成功し、開発ロックも `--require-hashes` で導入成功しました。
pip-audit 2.10.1でpip26.3を含む全7依存に既知脆弱性はありません。
ハッシュ付きbootstrapを使う更新Dockerfileのビルドも成功しました（イメージID `sha256:85052d01f22ec636460545d0ec7737372a857f46398355775ecae0ae24f91111`）。

更新後の最終イメージを非rootユーザーで実行し、49テスト・Ruff lint/整形・pip SBOMの実コード検証・pip checkがすべて成功しました。
新しいsecurityジョブのartifact受渡しは、その後の PR CI（run 42080383425）で成功を確認しました。

## 再評価（2026-11-20）

初回期限 2026-11-12 の失効後に、[監査方針](ci-security-policy.md)の手順で全件を見直しました。

- 公式情報の再確認: Docker Hub の `python:3.15.2-slim-trixie` は再ビルドされ、digest が
  `sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928` に変わっていました
  （`3.15-slim-trixie` と `3-slim` も同じ digest のため、3.15.2 が現行の最新版です）。PyPI で
  Ruff 0.17.6 と pip-tools 7.7.0 の公開を確認し、pip 26.3・pytest 9.2.0・推移的依存はいずれも最新のままでした。Trivy は 0.76.2 が最新です。
- 更新: Dockerfile のベース digest、`requirements.in`/`requirements.txt` の Ruff 0.17.6（pip-tools 7.7.0 で再生成し、7依存すべてのハッシュを PyPI JSON と照合済み）。
  Dockerfile に `apt-get upgrade` を追加し、Debian で修正済みの zlib（CVE-2026-85091、`1:1.3.dfsg+really1.3.1-1+deb13u1`）を取り込みました。
- ビルド: この検証環境は apt の HTTP 通信がプロキシを通らないため、apt の取得先だけを HTTPS とプロキシに差し替えた一時 Dockerfile でビルドし、最後に apt 設定を元に戻しました。
  パッケージの選択と手順はリポジトリの Dockerfile と同じです。イメージ ID は `sha256:918f891b23fffeaa24c8a8a51094f395a4f4884e48e7fecd0585e732113516c9`、OS パッケージは119件です。
- 実行確認: 非 root（UID 1001）で Python 3.15.2 / pip 26.3 / Ruff 0.17.6 を使い、49テスト、`ruff check --no-cache .`、`ruff format --no-cache --check .`、`pip check`、`scripts/verify_pip_sbom.py` がすべて成功しました。
- pip-audit 2.10.1: pip を含む7依存すべてで既知脆弱性なし（[JSON](pip-audit.json)）。
- Trivy 0.76.2（DB 2026-11-20 01:04:07 UTC）: HIGH 119件・CRITICAL 0件。内訳は OS 118件と、pip の SBOM 由来の setuptools 1件です。
  前回から zlib の CVE-2026-76844 が消え、新たに出た CVE-2026-85091 は修正済み版で解消しました。新規65件の内訳は krb5 56件、git 6件、sqlite3 2件、expat 1件です。
- Debian Security Tracker（`security-tracker.debian.org/tracker/data/json`、2026-11-20 取得）で、残る OS の検出はすべて trixie で `open`（修正版なし）であることを確認しました。
  krb5・expat・curl は git の依存（`libcurl3t64-gnutls`）として入ります。krb5 の多くは KDC/kadmind 側の問題で、これらのサーバーはイメージに入っていません。
  git は開発に必要なため削除しません。緩和策は README に記載しています。
- ベースライン: [security/container-baseline.json](../security/container-baseline.json) を現在の119件に置き換え、OS の各項目の理由に Debian 側の状況と緩和策を書きました。全検出は [JSON](security-findings.json) に記録しています。
  新しい確認期限は **2026-12-18** です。毎週の CI は、修正版が出た時点や導入版が変わった時点でブロックするため、修正が出ても気付かずに残ることはありません。
  期限を4週間としたのは、Debian での修正待ちが大半で、1週間では毎回同じ再評価を繰り返すだけになるためです。
- Debian 側の区分: OS の118件の内訳は、no-dsa の指定なしが64件、no-dsa が50件（Minor issue 49件と、point release で修正予定の acl 1件）、postponed（perl）が4件です。各項目の理由に区分を書きました。
- 追跡: 作業用の #6 を閉じても残件を追えるよう、[Issue #9](https://github.com/tomohiroJin/devcontainer-python/issues/9) を作り、ベースラインの追跡先と担当（tomohiroJin）を更新しました。
- OS パッケージの一覧: `apt-get upgrade` を入れたため、OS の版はビルドした日によって変わります。監査したイメージの一覧を [os-packages.txt](os-packages.txt) に保存し、CI でも `container-audit` artifact に保存するようにしました。
- 判定: 新しいベースラインで `Reviewed: 119; blocking: 0`。判定テスト9件も成功しました。
- 監査の対象: Dockerfile とロックファイルはコミット `31d2abe` 時点のものです（後のコミットでも変更していません）。ローカルのイメージ ID は再現できないため、CI での確認として run 44667812184（コミット `1abf8d2`）の `container-audit` artifact で同じ119件を確認しました。
- git の緩和策: CVE-2026-105437 は merge・rebase・cherry-pick で起きるため、信頼できないブランチをこのコンテナで統合しないこと、上流の回避策 `conflict-marker-size=7` を、README とベースラインに書きました。
- 未実施: VS Code GUI での確認、Debian のサポート期限の公式表との照合（www.debian.org が HTTP 403）。

## 運用の変更（2026-11-20）

リポジトリ所有者の判断で、次のとおり運用を簡略化しました。上の節にある「確認期限」「週次 CI」の記述は、当時の方針として残しています。

- 既知残件の確認期限（`review_due`）を廃止しました。判定スクリプトから期限の判定を外し、ベースラインと全件一覧から `review_due` を削除しました。
- CI の週次の定期実行（`schedule`）を廃止しました。CI は push（main）・PR・手動実行のときだけ動きます。Dependabot の週次の更新提案はそのまま残しています。
- Debian の修正待ちの残件（High 118件）は、[Issue #9](https://github.com/tomohiroJin/devcontainer-python/issues/9) に記録したうえで一旦閉じました。Debian のサポート期限の照合も対象外にしました。
- 判定テストは9件のまま成功し、新しいベースラインでの判定は `Reviewed: 119; blocking: 0` です。
