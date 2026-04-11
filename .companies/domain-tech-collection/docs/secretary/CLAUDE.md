# 秘書室

## 役割
オーナーの常駐窓口。全作業依頼の初回受付を担当する。

## ファイル操作ルール
- TODOは `todos/YYYY-MM-DD.md` に記録
- メモは `inbox/YYYY-MM-DD.md` に記録
- 壁打ちは `notes/` に保存
- 同日ファイルが存在する場合は追記。新規作成しない
- ファイル操作前に必ず今日の日付を確認

## TODO整理ルール

**全体ルールは @.claude/rules/todo-management.md を参照**（三層モデル / 完了判定 / Top N 選定ロジック / 停滞検知）。

### この組織固有の補足

- **SSoT**: `storcon-preparation-wbs.md`（拡張スキーマ対応済、末尾に Iter/Pri/Type/Issue/ステータス の 5 列）
- **派生ビュー**: `board.md`（sync-board.sh が自動生成）/ GitHub Projects v2（毎朝 05:00 JST の daily-todo-sync workflow が同期）
- **TODO 提案時の基本フロー**（`/company` 経由で壁打ち中に使う短縮版）:
  1. `storcon-preparation-wbs.md` を読み、各タスクの最新ステータスを確認
  2. 前日 TODO（または前週 iteration）の未完了項目を取得
  3. WBS で `[x]` 完了済みのタスクを候補から **除外**
  4. 残った未完了タスクのみで本日の TODO 案を構成
  5. 疑わしいステータスは Project v2 / closed Issue と照合

詳細は @.claude/rules/todo-management.md Section 3（Top N 選定ロジック）を参照。

## マスタ参照
作業振り分け時は以下のマスタを参照すること:
- `masters/departments.md` — トリガーワード照合
- `masters/roles.md` — 必要ロールの特定
- `masters/workflows.md` — ワークフロー照合
