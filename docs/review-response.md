# PR #7 レビュー指摘への対応

対象: [レビューコメント](https://github.com/tomohiroJin/devcontainer-python/pull/7#issuecomment-6664569984)。以下は指摘番号に対応します。外部コメントの推測は検証済みの事実と区別して扱っています。

1. **監査ゲートと期限**: `security` を独立ジョブにし、`container` が1回だけビルド・テスト・Trivy収集・pip実コード検証した後の生JSON artifactを取得させました。テストの成功チェックを期限切れで赤くしません。期限判定は「今回も残る既知検出」だけに適用し、クリーンな完全レポートは過去のベースライン期限にかかわらず成功します。新規・修正版あり・導入版/深刻度変更のブロックは維持しました。期限 **2026-11-12 09:00 JST（00:00 UTC）** は延長していません。9件の境界/失敗テストで検証し、元の55検出生レポートでも判定成功を確認しました。候補コピー、公式修正・影響との照合、手動承認という更新手順を `ci-security-policy.md` に記載し、自動更新や日付だけの先送りを禁止しました。生のHigh/Criticalと確認済み/ブロック件数はログ・Step Summaryにも表示します。
2. **pipのハッシュ固定**: `requirements-bootstrap.txt` を追加し、公式PyPI JSONから取得したpip 26.3のwheel/sdistハッシュを固定。DockerとPython CIで `--require-hashes` で先に導入します。開発ロックと併せてpip-audit・ルートpip Dependabotの対象にしました。独立したruntime承認版のassertは意図して残し、pip更新時はSBOM・PackageIndex不在とベースラインの手動再評価を必要とします。requirementsからassert版を自動取得してbot更新だけで影響評価を更新する設計にはしません。Dockerfile frontendの `docker/dockerfile:1` は互換構文のメジャー指定として維持しました。今回の必須修正は実行パッケージpipのハッシュ検証であり、未調査のfrontend digestへ変更していません。
3. **二重実行・実行時間**: `push` をmainだけに限定し、PR番号またはrefをキーにconcurrency/cancel-in-progressを設定しました。Python/containerは30分、securityは10分のタイムアウトを設定。feature branchのpushとPRの二重ビルドを避け、単一run内でもセキュリティ判定のための二重ビルドはしません。actionlintで構文を確認しました。
4. **Pythonバージョン契約**: `python_requires=">=3.15,<3.16"` は意図的に維持します。パッケージのインストール契約も検証済みDev Container minorに揃える変更であり、整形だけとは扱いません。3.15以外の `pip install .` が拒否されること、3.16対応時にメタデータ上限・コンテナ・Ruff・CIを更新することをREADMEに明記しました。
5. **記録・設定の整合**: pip-audit JSONの余分な末尾空行を除去。ファイル数を初回32件と監査スクリプト追加後37件に区別し、実CIのビルド成功で解消済みの「再ビルド未実施」「GitHub Actions未実施」を修正しました。推奨を外したcSpell設定（旧wmaurer語を含む）は削除。`ca-certificates` はGit/pipのTLSに必要な依存を明示する意図で残します。ベースで既に導入済みの場合のapt処理は冪等で、脆弱性除外のための削除はしません。`git diff --check` を確認しました。
6. **VS Code Server**: curl/wgetがない場合のホスト側ダウンロード経路をGUIで検証済みとは主張しません。GUIでのDev Containers起動・Server配置・補完・デバッグは引き続き手動確認事項です。確認せずに不要なネットワークツールを再導入したり、動作済みと記録したりしません。Pythonテストと必要ライブラリの確認はServer配置の検証を代替しません。

## 検証

更新したハッシュ要件のクリーン導入、pipを含む全7依存の監査、判定9テスト、更新Dockerfileのビルド、最終イメージ内の49サンプルテスト、Ruff lint/整形、pip実コード評価、pip check、actionlint、差分空白チェックを確認しました。結果の詳細と未実施項目は [検証記録](maintenance-validation.md) に追記します。CIの新しいartifact受渡しがGitHub上で成功したとは、push前のローカル確認段階では主張しません。
