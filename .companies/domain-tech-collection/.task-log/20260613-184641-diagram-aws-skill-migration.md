---
task_id: "20260613-184641-diagram-aws-skill-migration"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: in-progress
mode: "agent-teams"
started: "2026-06-13T18:46:41"
completed: ""
request: "Issue #569 をサブエージェントチームで対応したい。AWS の skills（deploy-on-aws の aws-architecture-diagram skill）への移行を実行する"
issue_number: 569
pr_number: null
subagents: [tech-researcher, qa-lead, cloud-engineer, system-architect, secretary]
l0_gate: null
l0_retries: 0
l1_gate: null
l1_retries: 0
l2_composite: null
l2_retries: 0
---

## 実行計画
- **実行モード**: agent-teams（Phase 1 設計+PoC を並列）→ 中核改修は人手ゲートを挟む
- **方針**: Issue #569 の選択肢 (B) を採用。`/company-diagram` を AWS 公式 deploy-on-aws の `aws-architecture-diagram` skill 方式（draw.io XML 生成・MCP 不使用）へ移行。オーナー(SAS-Sasao)判断により architect 推奨の (C) より (B) を優先。
- **スコープ（今回）**: Wave1=移行設計の確定 + draw.io レビューパイプライン実証。SKILL.md 中核書き換え・auto-merge は別ゲート（人手確認後）。
- **アサインロール**: tech-researcher（後継skill実体抽出）/ qa-lead（L0/L1/L2 再設計）/ cloud-engineer（drawio PoC）/ system-architect（統合設計・B-1 vs B-2 確定）/ secretary（team-lead 統括）
- **参照マスタ**: workflows.md, review-pattern.md, skill-development.md, artifact-placement.md

## エージェント作業ログ
### [2026-06-13 18:46:41] secretary
受付: Issue #569 を Agent Teams で対応。方針 (B) AWS skills 移行を実行。ブランチ feat/2026-06-13-diagram-aws-skill-migration 作成。Wave1 並列チームを起動。

### [2026-06-13 18:51] secretary → tech-researcher / qa-lead / cloud-engineer
委譲(Wave1 並列): 後継skill実ソース分解 / drawio版L0-L1-L2再設計 / drawio PoC生成+検証。

### [2026-06-13 18:52] cloud-engineer
完了: docs/drawio/poc-aws-migration-sample.drawio を手書き生成 → review-drawio.js で初回3件貫通 → 1回修正 → exit 0/pass。方針Bの実現可能性を実証。

### [2026-06-13 18:55] tech-researcher
完了: deploy-on-aws/aws-architecture-diagram の実ソース（references14/scripts6/aws4-shapes.json 1077/サンプル7、Apache-2.0コピー可）を分解。B-2（cc-sier native skill へ移植）を推奨。

### [2026-06-13 18:55] qa-lead
完了: drawio版L0/L1/L2を再設計。新6軸（s3 PNG→XML整合性、s6 英語ラベル致命→drawio品質致命）、review-prompt骨子、AC、未決A〜E を提示。

### [2026-06-13 18:58] secretary → system-architect
委譲(Wave2): Wave1 3成果を統合し移行設計を確定。

### [2026-06-13 18:58] system-architect
完了: 設計確定（方針B + B-2）。設計書を docs/decisions/2026-06-13-diagram-aws-skill-migration-design.md に作成。未決A〜E決着、変更ファイル一覧、AC、着手順序6ステップ、Issue更新コメントを出力。中核(SKILL.md)改修は人手承認後（Step1）に着手。

## reward
（post-merge hook が自動追記）
