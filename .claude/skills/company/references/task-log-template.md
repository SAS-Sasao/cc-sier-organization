# タスクログ・Issue テンプレート

このファイルは秘書がタスク実行時にログを記録し、完了時に GitHub Issue を作成する際に参照するテンプレートです。

---

## 1. タスクログファイル（.task-log/{task-id}.md）

### task-id の命名規則

`YYYYMMDD-HHMMSS-{概要slug}`

- 概要slug: 依頼内容を英語3〜5単語のkebab-caseで要約
- 例: `20260319-143000-dwh-design`
- 例: `20260319-100000-test-strategy`

### テンプレート

```markdown
---
task_id: "{task-id}"
org: "{org-slug}"
status: in-progress
mode: "{agent-teams / subagent / direct}"
started: "{YYYY-MM-DDTHH:MM:SS}"
completed: ""
request: "{ユーザーの依頼原文}"
issue_number: null
pr_number: null
---

## 実行計画
- **実行モード**: {mode}
- **アサインされたロール**: {ロール一覧}
- **参照したマスタ**: {参照したマスタファイルとエントリ}
- **判断理由**: {なぜこの実行方式を選んだか}

## エージェント作業ログ

### [{timestamp}] {from} → {to}
{action}: {内容}

## 成果物
| ファイル | 作成者 | パス |
|---------|--------|------|
```

### ログエントリの記録ルール

| イベント | フォーマット | 例 |
|---------|------------|-----|
| タスク受付 | `[{ts}] secretary` / `受付: {依頼原文の要約}` | `[2026-03-19 14:30] secretary` / `受付: A社DWH設計の依頼` |
| 判断完了 | `[{ts}] secretary` / `判断: {実行モードと理由}` | `[2026-03-19 14:30] secretary` / `判断: agent-teams、並列設計が効率的` |
| Subagent委譲 | `[{ts}] secretary → {role}` / `委譲: {タスク内容}` | `[2026-03-19 14:31] secretary → data-architect` / `委譲: メダリオン全体設計` |
| エージェント間連携 | `[{ts}] {from} → {to}` / `連携: {内容}` | `[2026-03-19 14:32] data-architect → data-engineer` / `連携: Bronze層スキーマを共有` |
| 成果物生成 | `[{ts}] {role}` / `成果物: {path}` | `[2026-03-19 14:45] data-architect` / `成果物: docs/data/models/.../architecture.md` |
| 作業完了 | `[{ts}] {role}` / `完了: {サマリー}` | `[2026-03-19 14:45] data-architect` / `完了: メダリオン3層設計を完了` |
| タスク完了 | frontmatter の status を `completed`、completed に日時を記入 | |

---

## 2. GitHub Issue テンプレート

タスク完了時に以下の構造で Issue 本文を組み立てる。

```markdown
## タスク概要
- **依頼者**: {owner_name}
- **組織**: {org-slug}
- **依頼日時**: {started}
- **完了日時**: {completed}
- **ステータス**: ✅ 完了

## 依頼内容
> {request}

## 実行計画（秘書の判断）
- **実行モード**: {mode}
- **アサインされたロール**:
  {ロールごとに箇条書き}
- **参照したマスタ**: {参照マスタ}
- **判断理由**: {理由}

## エージェント作業ログ

### 📋 {role}
- **タスク**: {タスク内容}
- **ステータス**: ✅ 完了
- **作業サマリー**: {サマリー}
- **成果物**:
  {成果物パスの箇条書き}
- **他エージェントへの連携**:
  {連携内容の箇条書き}

{各ロールごとに繰り返し}

## 成果物一覧
| ファイル | 作成者 | パス |
|---------|--------|------|
{成果物テーブル}

## 関連
- PR: #{pr_number}
```

### Issue タイトル

```
[{org-slug}] {タスク概要}
```

例: `[a-sha-dwh] DWH メダリオンアーキテクチャ設計`

---

## 3. ラベル決定ルール

### 常に付与
- `org:{org-slug}`

### 実行モード（1つ）
| ラベル | 条件 |
|--------|------|
| `mode:agent-teams` | Agent Teams で実行 |
| `mode:subagent` | Subagent 委譲で実行 |
| `mode:direct` | 秘書が直接対応 |

### 部署（複数可）
- `dept:{dept-name}` — 関与した部署ごとに付与
- 部署名は departments.md の名称（日本語）ではなく、フォルダ名（英語）を使用
- 例: `dept:architecture`, `dept:data`, `dept:quality`

### タスク種別（1つ）
| ラベル | 判定基準 |
|--------|---------|
| `type:design` | 設計書・ADR・アーキテクチャ関連 |
| `type:review` | レビュー系（コードレビュー、設計レビュー） |
| `type:research` | 調査・比較・PoC |
| `type:todo` | TODO・タスク管理・進捗管理 |
| `type:knowledge` | ナレッジ・ポストモーテム・教育資料 |
| `type:admin` | マスタ変更・部署追加等の管理作業 |
| `type:docs` | 上記に当てはまらないドキュメント作成 |

### ラベル自動作成

gh CLI でラベルが存在しない場合、Issue 作成前に自動作成する:

```bash
gh label create "{label}" --color "{color}" --force 2>/dev/null
```

色の規則:
- `org:*` → `#0075ca`（青）
- `mode:*` → `#e4e669`（黄）
- `dept:*` → `#7057ff`（紫）
- `type:*` → `#008672`（緑）

---

## 4. Issue 作成をスキップする条件

以下の場合は .task-log/ の作成自体をスキップする:
- 壁打ち・雑談（ファイル生成を伴わない会話）
- ダッシュボード表示
- 組織切り替え・選択

判定基準: **Gitワークフロー（ブランチ作成）と同じ**。
ファイル生成を伴うタスクのみタスクログを記録し、Issue を作成する。

---

## 5. gh CLI が使えない場合のフォールバック

1. `.task-log/{task-id}.md` にログは記録する（ローカル証跡として有効）
2. Issue 作成はスキップし、秘書が以下を報告:
   ```
   タスクが完了しました。
   作業ログは .companies/{org}/.task-log/{task-id}.md に保存しました。
   GitHub Issue の自動作成には gh CLI が必要です。
   ```
