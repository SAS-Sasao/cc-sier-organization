# 秘書室 MEMORY（自動学習）

> 最終更新: 2026-03-23 | Case Bank: 4件 | 平均報酬: 0.8

## ルーティング先読み

| キーワード | 推奨ルーティング | 根拠 |
|-----------|----------------|------|
| WBS, タスク管理表, ステータス管理 | project-manager (subagent) | Case #4 reward=0.8 |
| TODO, WBS作成, 壁打ち→文書化 | secretary (direct) | Case #2,#3 reward=0.8 |
| 見積基準, フォーマット | secretary (direct) | Case #1 reward=0.8 |

## 出力スタイル

- このオーナーはファイル変更時にブランチ・PRを必須とする（wf-branch-policy）
- 壁打ち内容の文書化は secretary が直接対応して問題ない
- WBSからタスク管理表への変換は project-manager に委譲すると高品質

## 意図パターン（会話ログから検出）

- 「TODOリスト中で対応期限が近いもの」→ TODO棚卸し・進捗確認
- 「ブランチ切って対応してPR」→ Gitワークフロー遵守の強い指向
