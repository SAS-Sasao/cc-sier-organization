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
pr_number: 573
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

### [2026-06-13 19:xx] secretary（ロールバック機構）
オーナー要件「移行失敗時に即戻せる」に対応し4層セーフティ構築: L1 ブランチ隔離（main無傷）/ L2 復元タグ pre-diagram-aws-skill-migration（push済）/ L3 .mcp.json の aws-diagram ==1.0.23 ピンを Step6 まで維持 / L4 Step1 は加算のみ。

### [2026-06-13 19:xx] secretary → cloud-engineer
委譲(Step1): deploy-on-aws 資産の移植。

### [2026-06-13 19:xx] cloud-engineer
完了: deploy-on-aws (Apache-2.0) から 33ファイルを references/drawio/ へ vendoring（references 13 + scripts 9 + samples 7 + 帰属3 + review-drawio.js）。Apache-2.0 帰属付与。既存ファイル不変・plugins↔.claude 同期一致。新パスの review-drawio.js で PoC 検証 pass。commit bdb8f38 / push 済。
- 設計差分解決: xml-templates-{structure,examples}.md, diagram-templates-{basic,advanced}.md, validate-drawio.sh も追加取得。
- Step2 前提: defusedxml 導入法の実機確認が必要。

### [2026-06-13 19:xx] secretary（設計変更: 並列スキル方式）
オーナー要件「移行版も現行版も両方 / で呼べる」を反映し、現行 SKILL を上書きせず **company-diagram-v2 を別スキルとして新設**する方式に変更（ロールバック安全性が最強化）。Step1 で company-diagram 直下に置いた vendored 資産を company-diagram-v2 配下へ git mv 再配置。

### [2026-06-13 19:xx] secretary → ai-developer
委譲(Step2): company-diagram-v2 の SKILL.md + review-prompt.md 作成。

### [2026-06-13 19:xx] ai-developer
完了: company-diagram-v2/SKILL.md(1670語・9フェーズ) + references/review-prompt.md(drawio版6軸: s3_xml_html_consistency / s6_drawio_quality, 旧 s6_english_labels 廃止) を作成。現行 company-diagram は無変更（git diff HEAD クリーン）。plugins↔.claude 同期一致。L0二段(validate_drawio.py[uv run --with defusedxml] + review-drawio.js)を SKILL.md に反映。Phase7 は auto-merge せず人手レビュー推奨を明記。

### [2026-06-13 19:xx] 状態
- /company-diagram（現行 PNG/MCP）と /company-diagram-v2（draw.io）が両方 / から呼出可能
- ロールバック: tag pre-diagram-aws-skill-migration / v2 削除で即復帰 / .mcp.json ピン維持
- 既知: PoC の cloudwatch_alarm は無効シェイプ→正は cloudwatch（実図生成時に修正）
- Phase1+Phase2 を1 PR にまとめ push（auto-merge せず人手レビュー）

## reward
（post-merge hook が自動追記）
