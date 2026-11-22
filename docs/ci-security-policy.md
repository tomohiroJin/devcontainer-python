# コンテナ監査のCI判定

Trivy 0.76.2でHigh/Criticalを除外せずJSONに保存し、`scripts/check_container_audit.py` で判定します。スキャナーの正常終了は収集成功であり、脆弱性ゼロの意味ではありません。通信・解析エラーを無視せず、`continue-on-error` も使いません。

OS パッケージは Dockerfile の `apt-get upgrade` で Debian の公開済みセキュリティ修正を取り込みます。修正版が出た検出は、CI で導入版の変更（新しい組み合わせとしてブロック）か `FixedVersion` 付きの検出（ブロック）として現れるため、ベースラインの見直しが必要になります。

`python` はテスト・lint・型チェック・カバレッジ・コミット前フック・Python依存監査、`container` は1回だけのイメージビルド・イメージ内での `make check`・ターミナル環境の確認（`scripts/check_devcontainer.sh`）・Trivy収集・pip実コード検証を行います。どちらも `Makefile` のターゲットを呼びます。全レポートを `container-audit-amd64`・`container-audit-arm64` の artifactに保存した後、別の `security` ジョブが同じartifactを取得して判定します。イメージの再ビルドはしません。`security` が新規検出で失敗しても、成功したテスト・lintのチェック結果は独立して残ります。スキャンやpipコード検証が失敗した場合は `container` も失敗し、セキュリティ判定を成功扱いにはしません。

[既知残件](../security/container-baseline.json)は、CVE・パッケージ・導入版・深刻度・エコシステムの完全一致で限定します。パッケージの再ビルドや深刻度の再評価も影響確認が必要なため、照合キーから外しません。新規検出や修正版の提供はブロックします。

既知残件には確認期限を設けません（2026-11-20 に期限と週次の定期実行を廃止しました）。CI は push・PR・手動実行（`workflow_dispatch`）のときだけ動きます。そのため、Debian が後から修正を出しても、次に CI が動くまでは検出されません。見直しは、依存やイメージを更新するときにまとめて行います。各項目の理由には、Debian 側の区分（no-dsa / postponed / 未判断）を書きます。Debian が no-dsa（個別のセキュリティ更新を出さない）とした項目は、point release まで直らないことがあります。

現在のレポートが完全で High/Critical がゼロなら、ベースラインに未使用の項目が残っていても成功します。未知の検出を許容したり、不完全なレポートをクリーンとみなしたりしません。

全検出はartifactに保持します。ログとGitHub Step Summaryには生レポートのHigh/Critical件数、確認済み件数、ブロック件数を表示します。監査判定の成功と残件の解消は別です。開発コンテナを外部サービスとして公開しません。

## 担当者による候補の作成・手動レビュー

担当は tomohiroJin（リポジトリ所有者）です。2026-11-20 時点の残件の記録は [Issue #9](https://github.com/tomohiroJin/devcontainer-python/issues/9) にあります（Debian の修正待ちとして一旦閉じました）。新しい検出や修正版でゲートが失敗したときは、次の手順で見直します。

1. 最新の成功した収集ジョブのartifactを取得します。例:
   ```sh
   gh run download RUN_ID --name container-audit-amd64 --dir /tmp/python-audit-review
   python3 scripts/check_container_audit.py /tmp/python-audit-review/trivy.json security/container-baseline.json
   cp security/container-baseline.json /tmp/python-container-baseline.candidate.json
   ```
   ゲートが新規検出で失敗する場合も、生JSONは削除せず保存します。収集時点・対象コミット・イメージdigest・Trivy/DB版をartifactとCIログで確認します。artifact の `os-packages.txt` で、導入された OS パッケージの版も確認します。
2. 各CVEについてDebian Security Tracker、公式GHSA、pipの上流修正と現在の実コードを確認します。導入版・修正版・深刻度・影響範囲を比較し、修正があれば依存またはイメージを更新して再監査します。新しい版やCVEを機械的に許容しません。
3. 候補JSONを手で編集し、解消項目を削除、残す項目の理由・担当・追跡先を再評価します。CIで現行JSONへ自動コピーしたりはしません。
4. 候補と元ファイル・最新JSONをPRで照合し、承認後にだけ `security/container-baseline.json` と記録を更新します。判断前にCIを緑にするための除外は追加しません。

## pipのSBOMに限定した評価・更新

CVE-2025-47273 / setuptools 70.3.0はpip 26.3のSBOMに残りますが、脆弱な実装は [公式GHSA](https://github.com/advisories/GHSA-5rjg-fvgr-3xxf) の `setuptools/package_index.py` にあります。CIは `scripts/verify_pip_sbom.py` をコンテナ内で実行し、承認済みpip版、SBOMの該当版、setuptools本体と脆弱モジュールの不在を検証します。全検出をTrivy JSONに残し、このCVE・版・影響評価以外を除外しません。

pipは `requirements-bootstrap.txt` に公式PyPIのwheel/sdistハッシュを記載し、`--require-hashes` で先に導入します。開発依存の `requirements.txt` と両方がpip-audit対象です。Dependabotはルートのpip要件ファイルを更新提案します。ただし、pip更新PRはハッシュと実コード/SBOMを照合し、`verify_pip_sbom.py` の独立した承認版も手動レビューで更新します。要件ファイルから承認版を自動取得しないのは、bot更新だけで影響評価の範囲を広げないためです。

## 判定テスト

```sh
python3 -m unittest discover -s scripts -p test_audit_gate.py
python3 scripts/check_container_audit.py REPORT.json security/container-baseline.json
```

新規検出・修正版・版/深刻度変更・レポート欠落をブロックし、既知残件だけのレポートとクリーンな完全レポートが成功することを検証します。

## ジョブの構成と、必須チェック（2026-11-22 追加）

ワークフロー（`.github/workflows/ci.yml`）のジョブは、次のとおりです。

| ジョブ | 内容 |
| --- | --- |
| `python` | テスト、lint、型チェック、カバレッジ、コミット前フック、Python 依存の監査 |
| `container` | amd64 と arm64 のそれぞれで、イメージのビルド、イメージ内での `make check` とターミナル環境の確認、**Dev Container としての起動の確認**、Trivy の収集、pip の実コードの検証 |
| `security` | amd64 と arm64 のそれぞれで、Trivy の結果と、ベースラインの照合 |
| `static` | ワークフロー（actionlint、zizmor）、Dockerfile（hadolint）、シェルスクリプト（shellcheck）の静的解析 |
| `host` | Windows と macOS のランナーで、改行コード、ホストでのコミット、`make doctor` のスクリプトを確認 |
| `ci-ok` | 上のすべてが成功した場合にだけ成功する、合否の集約 |

### main のルールセット（推奨の設定）

**必須チェックにするのは、`ci-ok` の1つだけです。** ホスト（Dev Container の外）でのコミットは、コミット前の検査なしで通ります（README「コミット前フック」）。正しさを保証するのは CI なので、CI が成功していない変更が main に入らないようにします。

設定は、GitHub の画面で行います（Settings → Rules → Rulesets → New branch ruleset）。

| 項目 | 設定 |
| --- | --- |
| Target branches | Default branch（`main`） |
| Restrict deletions | 有効 |
| Block force pushes | 有効 |
| Require a pull request before merging | 有効（直接の push を禁止します）。Required approvals は 0（所有者が1人のため。共同の管理者が増えたら 1 にします） |
| Require status checks to pass | 有効。`ci-ok` を追加します。「Require branches to be up to date before merging」は、有効にしません（PR が少ないため。有効にすると、main が進むたびに更新が必要になります） |
| Bypass list | 空にします（管理者も、CI を通します） |

- `ci-ok` は、`needs` に並べたジョブが1つでも失敗・キャンセル・スキップになると、失敗します。ジョブを足すときは、`ci-ok` の `needs` にも足します（足し忘れは、`scripts/test_project_config.py` が検出します）。ルールセットの変更は要りません。
- `ci-ok` 以外のジョブを、必須チェックに指定しないでください。ジョブの名前を変えたときに、マージできなくなります。
- **設定したかどうかは、リポジトリのファイルからは分かりません。** 設定後に、失敗する PR でマージが止まることを、画面で確かめてください。

### 決めたこと

- **変更されたファイルによるジョブの絞り込みは、行いません。** ドキュメントだけの変更でも、すべてのジョブが動きます（合計で数分）。絞り込むと、「動かなかったジョブ」を `ci-ok` で成功扱いにする規則が必要になり、見逃しの原因になります。
- **静的解析は、CI だけで実行します。** コミット前フックには入れません。フックは、イメージにある道具だけで動かす方針で（README「コミット前フック」）、これらの道具を入れると、イメージの監査の対象が増えるためです。手元で実行する場合のコマンドは、`ci.yml` の `static` ジョブにあります（Docker が要ります）。
- **静的解析の道具は、イメージの digest（actionlint、hadolint、shellcheck）と、ハッシュ付きの要件ファイル（zizmor。`.github/ci/requirements.txt`）で固定します。** zizmor は Dependabot が更新を提案します。digest で固定した3つは、Dependabot が追わないため、手で更新します。
- **Dev Container CLI は、ロックファイル（`.github/ci/devcontainer-cli/package-lock.json`）で固定します。** インストール時のスクリプトは実行しません（`--ignore-scripts`）。
- **`CODEOWNERS` は置きません。** 所有者が1人で、レビューの割り当てが要らないためです。
- **コミットメッセージと PR のタイトルの検査は、入れません。** 規約がまだ決まっていないためです（Issue #17）。
- **定期実行は、引き続き行いません**（上の「コンテナ監査のCI判定」）。
- **arm64 のイメージも、amd64 と同じ検査を行います**（2026-11-22 追加）。Apple silicon の Mac では、arm64 のイメージが使われるためです。`ubuntu-24.04-arm` のランナーで、ビルド、イメージの検査、Dev Container としての起動の確認、Trivy の収集と照合を行います。初回の実行では、検出は amd64 と同じベースラインに収まりました。
- **イメージは、公開しません**（GHCR などへの push は行いません）。各自が、`.devcontainer/` からビルドします。GitHub Codespaces でも、同じ `.devcontainer/` からビルドされます（README「GitHub Codespaces で使う」）。
