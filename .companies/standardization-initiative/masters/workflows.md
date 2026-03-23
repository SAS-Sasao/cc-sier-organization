# ワークフロー一覧

## wf-branch-policy

- **名称**: ブランチ・PR必須ポリシー
- **対象**: `.companies/standardization-initiative/` 配下の全ファイル
- **ルール**: 新規作成・更新を問わず、ファイル変更時は必ずブランチを作成し、PR経由でmainにマージすること
- **ブランチ命名**: `standardization-initiative/{type}/{YYYY-MM-DD}-{summary}`
- **コミットメッセージ**: `{type}: {概要} [standardization-initiative] by {operator}`
- **フロー**:
  1. mainからブランチを作成
  2. ファイルを変更・作成
  3. コミット → プッシュ → PR作成
  4. mainに戻る

---

（ワークフローは `/company-admin` で追加できます）
