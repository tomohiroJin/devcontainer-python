# Issue #11 検証記録（開発環境の強化）

日付: 2026-11-20。基準コミット: `cdf0f36`（main）。対象: [Issue #11](https://github.com/tomohiroJin/devcontainer-python/issues/11)。

採用したものと理由は [README](../README.md) の「ターミナル」「同梱ツール」「VS Code」にあります。ここには、決める際に確認した事実と、検証の結果を記録します。

## 採否を決めるために確認したこと

- **版**: 2026-11-20 に PyPI の JSON API で最新の安定版を確認しました。mypy 2.4.1、pytest-cov 7.1.0、coverage 7.17.3、IPython 9.18.1、prek 0.5.11、pip-tools 7.7.0、pip-audit 2.10.1。pytest 9.2.0 と Ruff 0.17.6 は最新のままです。
- **wheel だけで入るか**: Python 3.15 のコンテナで `pip install --require-hashes --only-binary :all:` を実行しました。
  - mypy・librt・coverage には `cp315` の wheel があり、成功しました。
  - `pre-commit` 4.7.0 は、依存する PyYAML 6.0.3 に `cp315` の wheel がなく（`cp314` まで）、失敗しました。そのため、依存のない prek を採用しました。
  - `pyright`（PyPI）は Node.js と本体を実行時に取得するため、候補から外しました。
- **OS パッケージの脆弱性**: 候補をすべて入れたイメージを Trivy 0.76.2（DB 2026-11-20 01:04:07 UTC）で調べ、ベースラインと比べました。

  | パッケージ | 増えた High/Critical | 判断 |
  | --- | --- | --- |
  | bash-completion、less、make、jq、tree、procps、nano | 0件 | 採用 |
  | curl（`curl`、`libcurl4t64`） | High 4件（CVE-2026-12064、CVE-2026-8458 が各パッケージに1件ずつ） | 採用。Git が使う `libcurl3t64-gnutls` と同じ CVE で、ベースラインに理由を付けて追加 |
  | openssh-client | Critical 1件（CVE-2026-60002）、High 5件（CVE-2026-106553、-106555、-106583、-59999、-60000） | 不採用 |

  Debian Security Tracker（`security-tracker.debian.org/tracker/data/json`、2026-11-20 取得）で、curl の2件は trixie で `open`（修正版なし）、no-dsa（Minor issue）であることを確認しました。openssh の6件も `open`、no-dsa（Minor issue）です。
- **VS Code の拡張**: Marketplace（`marketplace.visualstudio.com`）にこの検証環境から接続できませんでした（HTTP 403）。そのため、必須の拡張は確認済みの4件から増やしていません。任意の拡張は、公開状態を確認していないことを README に書いています。

## イメージの大きさとビルド時間

同じ環境で、キャッシュなし（`--no-cache`）でビルドして比べました。ベースイメージは取得済みの状態です。

| 項目 | 変更前（main） | 変更後 |
| --- | --- | --- |
| `docker image inspect` の Size | 406 MB | 597 MB |
| `docker save` の出力（圧縮済みレイヤー） | 101 MB | 139 MB |
| ビルド時間 | 27 秒 | 39 秒 |
| OS パッケージ数 | 119 | 131 |
| Python パッケージ数（pip を含む） | 7 | 31 |
| Trivy の High / Critical | 119 / 0 | 123 / 0 |

増えた分の多くは Python のツールです（`site-packages` 全体で 156 MB。mypy が約 65 MB、IPython が使う jedi が約 34 MB）。
この検証環境は apt の HTTP 通信がプロキシを通らないため、前回と同じく、apt の取得先だけを HTTPS とプロキシに差し替えた一時 Dockerfile でビルドしました。パッケージの選択と手順はリポジトリの Dockerfile と同じです。
イメージ ID は `sha256:7f6160f3d0fc0a408ba63f272cc4597f5f6f0ae831021530146ea8bed4cb08a0` です（`apt-get upgrade` と時刻を含むため、別の環境では再現しません）。

## 実行した検証

- **イメージ内のチェック**: ソースを読み取り専用でマウントし、既定ユーザー（`vscode`、UID 1000）で `make check` を実行しました。Ruff の lint と整形、mypy（34ファイル）、pytest の49テスト、`scripts/` の単体テストがすべて成功しました。
- **ターミナル**: `bash scripts/check_devcontainer.sh` の全項目が成功しました。コマンドの有無、ロケール、タイムゾーン、ページャー、Git の設定、プロンプト（ブランチ、未追跡、仮想環境、終了コード）、履歴、エイリアス、補完を調べます。ブランチ名に `$(...)` を含めても、プロンプトの表示時に実行されないことも確認しています。
- **Dev Container としての起動**: `@devcontainers/cli` 0.90.0 の `devcontainer up` で起動しました（上のイメージを `image` に指定した `devcontainer.json` の写しを使用。それ以外の設定は同じです）。
  - 履歴用のボリュームが `/commandhistory` にマウントされ、`vscode` が書き込めました。
  - `TZ=Asia/Tokyo` が設定され、`date` が JST を表示しました。
  - `postCreateCommand`（`make hooks`）が `.git/hooks/pre-commit` を登録しました。
  - 擬似端末で対話シェルを操作し、プロンプトの表示、日本語の入出力、失敗時の `[exit 1]`、`git chec` → `git checkout` と `make typ` → `make typecheck` の Tab 補完を確認しました。
  - コンテナを削除して作り直したあとも、前のセッションで実行したコマンドが履歴に残っていました。
- **コミット前フック**: 行末の空白と未使用の import を含む Python ファイルと、壊れた JSON をステージして `git commit` を実行し、コミットが中断されること（終了コード 1）を確認しました。`make pre-commit` は全ファイルで成功しました。
- **カバレッジ**: `make cov` で 93%（分岐を含む）。`coverage.xml` と `htmlcov/` が出力されました。
- **pip-audit 2.10.1**: `make audit` で、pip を含む31依存すべてに既知の脆弱性がありませんでした（[JSON](pip-audit.json)）。
- **Trivy**: 新しい[ベースライン](../security/container-baseline.json)で `Reviewed: 123; blocking: 0`。[全検出一覧](security-findings.json)と [OS パッケージ一覧](os-packages.txt)を更新しました。
- **pip の SBOM**: 新しいイメージで `scripts/verify_pip_sbom.py` と `pip check` が成功しました。

## 未実施

- **VS Code の GUI での確認**: 補完、型診断、保存時の整形、テスト一覧、pytest のデバッグ、タスクの実行は、この検証環境に VS Code の GUI がないため実施していません。設定ファイルの JSON の構文、必須拡張の一覧の一致、タスクが実在する `make` ターゲットを呼ぶことは、`scripts/test_project_config.py` で検査しています。README の手順で確認してください。
- **Marketplace の公開状態**: 上記のとおり、任意の拡張は確認していません。
- **リポジトリの Dockerfile そのままでのビルド**: この検証環境では apt のためにビルド手順の一部を差し替えています。そのままのビルドは PR の CI（`container` ジョブ）で確認します。
