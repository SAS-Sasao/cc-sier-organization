# タスクログと Issue 自動作成

ファイル生成を伴うタスクの実行過程を `.task-log/` に記録し、完了時に GitHub Issue として自動作成する。

## .task-log/ ディレクトリ

```
.companies/{org-slug}/
├── CLAUDE.md
├── masters/
├── docs/
└── .task-log/                      ← タスク実行ログ（Git管理対象）
    └── {task-id}.md                ← 1タスク1ファイル
```

- **task-id**: `YYYYMMDD-HHMMSS-{概要slug}`（例: `20260411-121507-daily-digest`）
- docs/ とは分離（成果物の可読性を保つ）
- タスク完了時のコミットに含める（PR の一部）

## YAML フロントマター形式（必須）

```yaml
---
task_id: "{task-id}"
org: "{org-slug}"
operator: "{operator}"
status: in-progress          # in-progress / completed / blocked
mode: "agent-teams"          # agent-teams / subagent / direct
started: "2026-04-11T12:15:07"
completed: ""
request: "{ユーザー依頼原文}"
issue_number: null
pr_number: null
subagents: [general-purpose-tech, general-purpose-retail, general-purpose-reviewer]
l0_gate: null                # pass / fail / null（レビュー付き Skill のみ）
l0_retries: 0
l1_gate: null                # pass / fail / null
l1_retries: 0
l2_composite: null           # 0.00 - 1.00（レビュー付き Skill のみ）
l2_retries: 0
---
```

**重要**:
- **Subagent 名は必ず英字**で記録（日本語名だと Case Bank 検出不可）
- **YAML フロントマター形式必須**（MD リスト形式はパーサ検出不可）
- **`reward` の補完は自動化されていない**（2026-08-16 実測）。`.claude/rules/` にも `.git/hooks/` にも `post-merge` hook は存在しない
- **`skill-evaluator.sh` はべき等**（`## reward` が既にあればスキップ）。**タスクが `in-progress` のうちに評価が走ると低いスコアが固定され、完了後も更新されない**
  - 実例: `20260816-150510-cycle-today` は evolve 実行時点で `in-progress` だったため `score: 0.2`（`completed: false` / `artifacts_exist: false`）が付き、完了後も自動では直らなかった
  - **対処**: `## reward` セクションを手で削ってから `evaluate_session` を再実行する（上記の例は 0.2 → **1.0** に是正）

## セクション構成

```markdown
## 実行計画
- **実行モード**: agent-teams / subagent / direct
- **アサインされたロール**: {ロール一覧}
- **参照したマスタ**: {workflows.md, quality-gates 等}
- **判断理由**: {なぜこの実行方式を選んだか}

## エージェント作業ログ
### [2026-04-11 12:15:07] secretary
受付: {依頼原文の要約}

### [2026-04-11 12:18:30] secretary → general-purpose-tech
委譲: Phase 2 Web巡回

### [2026-04-11 12:22:00] general-purpose-tech
完了: tech team 73件収集

## reward
（`skill-evaluator.sh` が追記。**タスク完了後に実行すること** — in-progress のうちに走ると低スコアが固定される）
```

## Issue 自動作成

タスク完了時に `gh issue create` で Issue を作成:

```bash
gh issue create \
  --title "[{org-slug}] {タスク概要}" \
  --label "org:{org-slug},mode:{mode},type:{type},dept:{dept}" \
  --body "$(Issue本文)"
```

### ラベル決定ルール

- `org:{org-slug}` — 常に付与
- `mode:agent-teams` / `mode:subagent` / `mode:direct` — 実行モード
- `type:daily-digest` / `type:diagram` / `type:design` / `type:docs` 等 — タスク種別
- `dept:secretary` / `dept:data` 等 — 関与部署

### ラベル未定義時

```bash
gh label create "{label}" --color "{color}" --force 2>/dev/null
```

色の規則: `org:*` = #0075ca / `mode:*` = #e4e669 / `dept:*` = #7057ff / `type:*` = #008672

## スキップ条件

ファイル生成を伴わない作業は **task-log 作成・Issue 作成ともにスキップ**:

- 壁打ち・雑談
- ダッシュボード表示
- 組織切り替え・選択

Gitワークフロー（ブランチ作成）が必要な作業 = task-log 必要 と同じ基準。

## Skill 直接実行時の扱い

`/company` 経由でなく Skill を直接実行した場合も **task-log は必須**。理由: Case Bank 学習が漏れると、後続セッションで類似ケース参照ができなくなる。

## gh CLI 利用不可時のフォールバック

1. `.task-log/{task-id}.md` にログは記録する（ローカル証跡として有効）
2. Issue 作成はスキップし、完了報告に gh CLI 必須を明示

## 関連

- @.claude/rules/git-workflow.md — コミット・PR
- @.claude/rules/review-pattern.md — L0/L1/L2 の task-log 記録形式
