# コンテナ監査のCI判定（2026-11-06）

Trivy 0.76.2 で High/Critical を除外なしで JSON に保存し、`scripts/check_container_audit.py` で判定する。スキャナーの正常終了は収集の成功を意味し、脆弱性がないことを意味しない。失敗の無視や `continue-on-error` は使わない。スキャナーの通信・解析エラーもジョブを失敗させる。

[期限付きの既知残件](../security/container-baseline.json) は、CIの実レポートと照合したCVE・パッケージ・導入版・深刻度・エコシステムの組で限定する。担当と追跡Issue、再確認期限 **2026-11-12** を保持する。

- 新規CVE、導入版や深刻度の変化、修正版の提供は失敗させる。
- 期限当日以降は失敗させ、担当が修正状況・影響を再評価するまで更新しない。
- 既知の修正版未提供の残件は、期限内だけ追跡対象として扱う。全検出をartifactに残し、監査の成功と脆弱性対応の完了を区別する。
- 欠損・不正なレポートやOS監査結果の欠落は失敗させる。

この方針は新しく見つかった修正版未提供の脆弱性まで自動的に許容しない。ベースラインの自動生成・自動更新をCIに組み込まない。既存残件にも影響がないとは断定しない。開発用コンテナとして使用し、外部サービスとして公開しない。

判定テストでは、新規検出・修正版の提供・版/深刻度変更・期限切れ・レポート欠落が失敗することを確認する。

```sh
python3 -m unittest discover -s scripts -p test_audit_gate.py
python3 scripts/check_container_audit.py REPORT.json security/container-baseline.json
```

## pipのSBOMに限定した評価

CVE-2025-47273 / setuptools 70.3.0 は pip 26.3 のSBOMに残るが、脆弱な実装は [公式GHSA](https://github.com/advisories/GHSA-5rjg-fvgr-3xxf) の `setuptools/package_index.py` にある。実イメージでsetuptools本体とPackageIndexが存在しないことを確認済み。CIでも `scripts/verify_pip_sbom.py` をコンテナ内で実行し、pip版、SBOMの該当版、setuptools本体と脆弱モジュールの不在を再確認する。条件が変われば失敗する。

この項目だけを特定の版・CVEに限定した影響評価として記録し、setuptools全体や他のCVEの除外はしない。Trivy JSONにも検出を残す。期限は他の残件と同じで、pip更新時にも再評価する。
