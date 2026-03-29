---
task_id: "20260329-093000-feat-drawio-skill"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: direct
started: "2026-03-29T09:30:00+09:00"
completed: "2026-03-29T09:35:00+09:00"
request: "draw.io MCPを使用してダイアグラムを作成しポータルにアップする仕組みをSKILL化"
subagent: "secretary"
issue_number: null
pr_number: null
reward: null
---

## 実行計画

- 新規Skill `/company-drawio` の作成
- draw.io MCP（mermaid/csv/xml）でER図・フロー・シーケンス図等を生成
- ギャラリーページ・ポータルカード・ダッシュボード連携

## 成果物

- `.claude/skills/company-drawio/SKILL.md` — Skill定義
- `plugins/cc-sier/skills/company-drawio/SKILL.md` — Plugin版
- `docs/drawio/index.html` — ギャラリーページ（検索・フィルタ・ページネーション付き）
- `docs/index.html` — ポータルに紫枠カード追加
- `.claude/hooks/generate-dashboard.sh` — ダッシュボード再生成時のdrawioカード維持
