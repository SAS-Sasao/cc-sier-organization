# 04 Hooks 設定

---

## 概要

| Hook タイプ | タイミング | スクリプト | 役割 |
|---|---|---|---|
| `PostToolUse` | ツール実行のたびに | `capture-interaction.sh` | インタラクションログ記録 |
| `PostToolUse` | docs/.md の保存時 | `quality-gate.sh` | 品質チェック自動実行 |
| `Stop` | Claude の応答完了時 | `session-boundary.sh` | セッション統計・GitHub Issue・学習 |

---

## settings.json の設定

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/capture-interaction.sh"}]
      }
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-boundary.sh"}]
      }
    ]
  }
}
```

---

## capture-interaction.sh（PostToolUse）

ツール実行のたびに `.interaction-log/YYYY-MM-DD.md` に記録します。

```markdown
### 14:32:15 | tool: Write

- path: `.companies/jutaku-dev-team/docs/system/requirements.md`
- action: write
- session: abc123
```

ログは `.gitignore` に含まれており、Git 管理外です。

---

## session-boundary.sh（Stop）

セッション終了時に以下を順番に実行します。

```
1. session_id 取得
2. .companies/.active から org-slug 取得
3. .interaction-log/ に区切り線追記
4. ツール種別カウント（Write/Read/Bash/Other）
5. .session-summaries/ に統計JSON保存
6. GitHub Issue に投稿（1日1件・追記方式）
7. [Phase 1] Skill Evaluator: 本日タスクの報酬スコア付与
8. [Phase 1] Case Bank 再構築
9. [Phase 3] Skill Synthesizer: 新規Skill候補をPR提案
10. [Phase 3] Subagent Refiner/Spawner: Agent更新をPR提案
```

### GitHub Issue のルール

- **1日1件**: 同日の複数セッションはコメントとして追記
- **ラベル**: `interaction-log`, `org:{slug}`
- **本文**: ミニサマリー + ログ全文（`<details>` で折りたたみ）

---

## カスタマイズ

**特定ツールのみ記録する:**
```json
{"matcher": "Write|Edit|CreateFile"}   // Write系のみ
{"matcher": ".*"}                       // すべて（デフォルト）
```

**Phase 3 の PR が多すぎる場合:**
`session-boundary.sh` の Phase 3 呼び出しブロックをコメントアウトして、`/company-evolve` を手動で実行するときだけ走らせることができます。

---

## 動作確認

```bash
# interaction-log が更新されているか確認
ls -la .companies/jutaku-dev-team/.interaction-log/
tail -20 .companies/jutaku-dev-team/.interaction-log/$(date +%Y-%m-%d).md
```

---

## quality-gate.sh（PostToolUse）

`docs/` 配下の `.md` ファイルが保存されるたびに自動起動し、品質チェックリストと照合します。

**起動条件:** `Write|str_replace_based_edit_tool|create_file` ツールが `**/docs/**.md` に対して実行されたとき

**処理の順序:**

| ステップ | 処理 | 出力先 |
|---|---|---|
| 1 | ファイルパスからチェックリストを決定 | - |
| 2 | キーワードベースで必須項目を検査 | - |
| 3 | 結果を JSONL で保存 | `.quality-gate-log/YYYY-MM-DD.jsonl` |
| 4 | タスクボードを更新（Pass→Done / Fail→Review） | `docs/secretary/board.md` |
| 5 | Fail の場合 GitHub Issue を作成 | GitHub Issues（ラベル: `quality-gate-fail`） |

**チェックリストの選択ロジック:**

```
ファイルパスに応じて以下を自動選択:
  - 常に: _default.md
  - */requirements/* → by-type/requirements.md
  - */design/* or */architecture/* → by-type/design.md
  - */proposals/* → by-type/proposal.md
  - */reports/* → by-type/report.md
  - */adrs/* → by-type/adr.md
  - パスに顧客slug が含まれる → by-customer/{slug}.md
```

**quality-gate-log のフォーマット:**
```json
{
  "status": "pass",
  "error_count": 0,
  "warning_count": 2,
  "errors": [],
  "warnings": [{"check": "変更履歴セクションがある", "cl": "_default.md"}],
  "target": ".companies/jutaku-dev-team/docs/system/requirements/a-corp.md",
  "checklists": ["_default.md", "requirements.md"]
}
```

---

## update-board.sh（ユーティリティ）

タスクボード（`docs/secretary/board.md`）を操作するユーティリティ関数群です。
`secretary.md` のタスク管理処理から `source` して使います。

**提供する関数:**

| 関数 | 役割 | 呼び出し元 |
|---|---|---|
| `board_add_task` | Todo に新規タスクを追加 | 秘書（タスク開始時） |
| `board_start_task` | Todo → In Progress に移動 | 秘書（タスク開始時） |
| `board_complete_task` | In Progress → Done に移動 | 秘書（タスク完了時） |
| `board_set_review_fail` | → Review に移動（品質NG時） | `quality-gate.sh` |

**直接呼び出す例:**
```bash
source .claude/hooks/update-board.sh
board_add_task "jutaku-dev-team" "20260322-001" "A社要件定義書" "sasao" "2026-03-31"
board_start_task "jutaku-dev-team" "20260322-001" "sasao"
board_complete_task "jutaku-dev-team" "20260322-001" ".companies/.../requirements.md"
```

---

## generate-dashboard.sh（手動・自動）

ダッシュボードHTMLを生成します。

**起動タイミング:**
- 手動: `/company-dashboard` Skill から呼び出し
- 自動: `/company-report` 完了後に自動呼び出し

**データソース（全て Python で集計）:**

| データ | ソース |
|---|---|
| タスクボード状況 | `docs/secretary/board.md` |
| 品質ゲート合格率 | `.quality-gate-log/*.jsonl` |
| Subagent使用頻度 | `.task-log/*.md` |
| スコア推移 | `.case-bank/index.json` |
| セッション統計 | `.session-summaries/*.json` |

**出力:** `docs/secretary/dashboard.html`（Chart.js使用、ダークモード対応）
