# 04 Hooks 設定

---

## 概要

| Hook タイプ | タイミング | スクリプト | 役割 |
|---|---|---|---|
| `PostToolUse` | ツール実行のたびに | `capture-interaction.sh` | インタラクションログ記録 |
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
