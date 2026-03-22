# 03 Subagent 一覧

---

## secretary（秘書）

メインエージェント。起動時に `.case-bank/index.json` を読み込み（Read フェーズ）、
`masters/` を参照して Subagent に委譲し、タスクログを記録して Git PR を作ります。

---

## 設計・インフラ系

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| system-architect | システム全体のアーキテクチャ設計 | 非機能要件定義、技術選定、構成図 | `docs/system/architecture/` |
| data-architect | データ基盤・DWH設計 | ER図、テーブル設計、クラウドDWH選定 | `docs/data/` |
| infra-engineer | インフラ設計・IaC | AWS/Azure構成設計、Terraform、コスト試算 | `docs/infra/` |

---

## 開発系

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| backend-engineer | バックエンド実装・API設計 | Django/FastAPI、REST API設計 | `docs/system/api/` |
| frontend-engineer | フロントエンド実装・UI設計 | React/Vue、レスポンシブ、アクセシビリティ | `docs/system/frontend/` |
| devops-engineer | CI/CD・運用設計 | GitHub Actions、Docker、監視設計 | `docs/infra/cicd/` |

---

## 文書系

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| technical-writer | 技術文書の作成・整備 | 要件定義書、設計書、手順書 | `docs/system/` |
| proposal-writer | 提案書・見積書の作成 | RFP対応、コスト積算 | `docs/proposals/` |
| report-writer | 報告書・議事録の作成 | 進捗報告、月次報告書 | `docs/reports/` |

---

## PM系

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| project-manager | プロジェクト計画・進捗管理 | WBS作成、リスク管理 | `docs/pm/` |
| scrum-master | アジャイル開発の推進 | スプリント計画、バックログ整理 | `docs/pm/agile/` |

---

## 分析系

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| business-analyst | ビジネス要件の分析・整理 | ヒアリング設計、業務フロー分析 | `docs/system/requirements/` |
| data-analyst | データ分析・可視化設計 | KPI設計、ダッシュボード設計 | `docs/data/analytics/` |
| cost-optimizer | コスト最適化の提案 | AWSコスト分析、Reserved Instance戦略 | `docs/infra/cost/` |

---

## 知識管理系

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| knowledge-manager | 知識の整理・体系化 | ナレッジベース構築、FAQ作成 | `docs/knowledge/` |
| domain-researcher | 技術・ドメインの調査 | 技術比較、市場調査、トレンド分析 | `docs/research/` |

---

## 品質・その他

| Subagent | 役割 | 得意 | 成果物 |
|---|---|---|---|
| code-reviewer | コードレビュー | セキュリティチェック、パフォーマンス分析 | `docs/review/` |
| qa-engineer | テスト設計・品質保証 | テスト計画、テストケース設計 | `docs/qa/` |
| security-engineer | セキュリティ設計・脆弱性評価 | 脅威モデリング、ISMS対応 | `docs/security/` |
| integration-specialist | システム連携・API統合 | EDI連携、API連携設計 | `docs/integration/` |

---

## Subagentの自動精緻化（Phase 3）

`/company-evolve` の Subagent Refiner が以下を自動更新します（3件以上の新規ケースでトリガー）。

| 更新セクション | 内容 |
|---|---|
| `refined_capabilities` | 高報酬ケースから導出した得意領域 |
| `output_format` | 過去ケースの実際の出力先ディレクトリ |
| `constraints` | 低報酬ケース（reward < 0.4）から導出した注意事項 |

対応Subagentが存在しない繰り返しパターンを検出すると、Subagent Spawner が新規 Subagent を自動生成してPR提案します。
