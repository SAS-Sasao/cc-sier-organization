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

## wf-wbs-task-management

- **名称**: WBS・タスク管理表作成（高報酬パターンから自動生成）
- **トリガー**: [WBS, タスク管理表, 作業TODO, ステータス管理, 対応日時]
- **実行方式**: subagent
- **ロール**: project-manager（WBS→タスク管理表の変換時）、secretary（TODO・WBSの初期作成時）
- **ステップ**:
  1. 壁打ちメモまたは既存WBSを参照
  2. WBSを構造化（secretary or project-manager）
  3. タスク管理表を作成（営業日ベースの日程算出含む）
  4. TODO を `docs/secretary/todos/` に記録
- **成果物**: `docs/pm/projects/{project-id}/`
- **平均報酬**: 0.8
- **検出日**: 2026-03-23

---

（ワークフローは `/company-admin` で追加できます）
