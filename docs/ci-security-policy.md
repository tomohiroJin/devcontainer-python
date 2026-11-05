# コンテナ監査のCI判定

Trivy 0.76.2でHigh/Criticalを除外せずJSONに保存し、`scripts/check_container_audit.py` で判定します。スキャナーの正常終了は収集成功であり、脆弱性ゼロの意味ではありません。通信・解析エラーを無視せず、`continue-on-error` も使いません。

`python` はテスト・lint・Python依存監査、`container` は1回だけのイメージビルド・テスト・Trivy収集・pip実コード検証を行います。全レポートを `container-audit` artifactに保存した後、別の `security` ジョブが同じartifactを取得して判定します。イメージの再ビルドはしません。`security` が期限や新規検出で失敗しても、成功したテスト・lintのチェック結果は独立して残ります。スキャンやpipコード検証が失敗した場合は `container` も失敗し、セキュリティ判定を成功扱いにはしません。

[既知残件](../security/container-baseline.json)は、CVE・パッケージ・導入版・深刻度・エコシステムの完全一致で限定します。パッケージの再ビルドや深刻度の再評価も影響確認が必要なため、照合キーから外しません。新規検出や修正版の提供はブロックします。

再確認期限は **2026-11-12 09:00 JST（同日00:00 UTC）** です。期限の延長や自動更新は実施していません。期限当日以降に、許容対象の既知残件が現在のレポートにも残っている場合だけ期限切れとしてブロックします。現在のレポートが完全でHigh/Criticalゼロなら、古いベースラインに未削除項目や過去の期限があっても成功します。未知の検出を許容したり、不完全なレポートをクリーンとみなしたりしません。

全検出はartifactに保持します。ログとGitHub Step Summaryには生レポートのHigh/Critical件数、期限内の確認済み件数、ブロック件数を表示します。監査判定の成功と残件の解消は別です。開発コンテナを外部サービスとして公開しません。

## 担当者による候補の作成・手動レビュー

担当は `Repository maintainer`、追跡先は [Issue #6](https://github.com/tomohiroJin/devcontainer-python/issues/6) です。期限前に次の手順を行い、無条件の猶予や日付だけの延長でゲートを通しません。

1. 最新の成功した収集ジョブのartifactを取得します。例:
   ```sh
   gh run download RUN_ID --name container-audit --dir /tmp/python-audit-review
   python3 scripts/check_container_audit.py /tmp/python-audit-review/trivy.json security/container-baseline.json
   cp security/container-baseline.json /tmp/python-container-baseline.candidate.json
   ```
   ゲートが期限・新規検出で失敗する場合も、生JSONは削除せず保存します。収集時点・対象コミット・イメージdigest・Trivy/DB版をartifactとCIログで確認します。
2. 各CVEについてDebian Security Tracker、公式GHSA、pipの上流修正と現在の実コードを確認します。導入版・修正版・深刻度・影響範囲を比較し、修正があれば依存またはイメージを更新して再監査します。新しい版やCVEを機械的に許容しません。
3. 候補JSONを手で編集し、解消項目を削除、残す項目の理由・担当・追跡先を再評価します。期限の再設定が必要なら、再評価の根拠と新期限を候補の差分に明記し、レビューを受けます。候補生成コマンドで `review_due` を先送りしたり、CIで現行JSONへコピーしたりしません。
4. 候補と元ファイル・最新JSONをPRで照合し、承認後にだけ `security/container-baseline.json` と記録を更新します。判断前にCIを緑にするための除外は追加しません。

## pipのSBOMに限定した評価・更新

CVE-2025-47273 / setuptools 70.3.0はpip 26.3のSBOMに残りますが、脆弱な実装は [公式GHSA](https://github.com/advisories/GHSA-5rjg-fvgr-3xxf) の `setuptools/package_index.py` にあります。CIは `scripts/verify_pip_sbom.py` をコンテナ内で実行し、承認済みpip版、SBOMの該当版、setuptools本体と脆弱モジュールの不在を検証します。全検出をTrivy JSONに残し、このCVE・版・影響評価以外を除外しません。

pipは `requirements-bootstrap.txt` に公式PyPIのwheel/sdistハッシュを記載し、`--require-hashes` で先に導入します。開発依存の `requirements.txt` と両方がpip-audit対象です。Dependabotはルートのpip要件ファイルを更新提案します。ただし、pip更新PRはハッシュと実コード/SBOMを照合し、`verify_pip_sbom.py` の独立した承認版も手動レビューで更新します。要件ファイルから承認版を自動取得しないのは、bot更新だけで影響評価の範囲を広げないためです。期限も別途手動レビューが必要です。

## 判定テスト

```sh
python3 -m unittest discover -s scripts -p test_audit_gate.py
python3 scripts/check_container_audit.py REPORT.json security/container-baseline.json
```

新規検出・修正版・版/深刻度変更・残件がある場合の期限当日/期限後・レポート欠落をブロックし、期限後でもクリーンな完全レポートが成功することを検証します。
