# ワークフロー一覧

## wf-todo-update

- **名称**: TODO進捗更新
- **トリガー**: 「TODO更新」「進捗更新」「タスク完了報告」「対応完了」
- **実行方式**: subagent（secretary）
- **ステップ**:
  1. `docs/secretary/todos/` 配下のTODOファイルを確認
  2. ユーザーからの報告に基づきステータスを更新
  3. ブランチ作成 → コミット → PR作成
- **成果物**:
  - `.companies/{org-slug}/docs/secretary/todos/YYYY-MM-DD.md`（更新）

---

（ワークフローは `/company-admin` で追加できます）
