---
task_id: "20260328-213000-diagram-enterprise-mdm-insights"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: direct
started: "2026-03-28T21:30:00+09:00"
completed: "2026-03-28T21:45:00+09:00"
request: "エンタープライズアーキテクチャ（CRMとERPを使用している前提）でMDMをためられ、データをインサイトできるようなアーキテクトを考えてほしい"
issue_number: null
pr_number: null
---

## 実行計画

- 描画対象: Enterprise MDM & Data Insights Architecture（マスターデータ管理 + データインサイト基盤）
- 概要: CRM/ERPの分散データをMDM層で統合・品質管理し、分析基盤でインサイトを提供するエンタープライズアーキテクチャ
- 使用AWSサービス: AppFlow, DMS, S3, Glue (ETL/Data Quality/Crawlers), Lake Formation, Entity Resolution, Redshift Serverless, Athena, QuickSight, Bedrock, Step Functions, EventBridge, CloudWatch, KMS
- MCP Server: awslabs.aws-diagram-mcp-server (生成), aws-knowledge-mcp-server (レビュー), aws-iac-mcp-server (IaC検証)
- 既存構成図との差別化: CRM/ERPを前提としたMDM（マスターデータ管理）に特化。Entity Resolutionによる名寄せ、Glue Data Qualityによる品質管理が核心

## 成果物

- [x] docs/diagrams/enterprise-mdm-insights.png
- [x] docs/diagrams/enterprise-mdm-insights.html
- [x] docs/diagrams/enterprise-mdm-insights.yaml
- [x] docs/diagrams/enterprise-mdm-insights-iac.html
- [x] docs/diagrams/index.html（カード追加・件数10件に更新）

## architecture-review (attempt 1/3)

| # | 観点 | 判定 | 検証結果 |
|---|------|------|---------|
| 1 | サービス互換性 | ✅ Pass | AppFlow→S3、DMS→S3、Glue ETL→S3、Entity Resolution→Glue Data Catalog連携、Lake Formation→Athena/Redshift 全統合パターン確認済み |
| 2 | データフロー整合性 | ✅ Pass | Sources→Ingestion→Raw→Staged→Golden→Analytics の一方向フロー。循環参照なし |
| 3 | セキュリティ | ✅ Pass | KMS暗号化、Lake Formationによる列/行レベルアクセス制御、CloudTrail監査ログ |
| 4 | 可用性・耐障害性 | ✅ Pass | S3/Glue/Athena/Redshift Serverless はマネージドHA。Step Functionsでリトライ制御 |
| 5 | コスト効率 | ✅ Pass | サーバーレス中心（Redshift Serverless/Athena/Glue）。重複サービスなし |
| 6 | ユーザー要望との一致 | ✅ Pass | CRM/ERP前提のMDM（Entity Resolution名寄せ+Data Quality品質管理）とデータインサイト（QuickSight BI + Bedrock AI）を網羅 |

**総合判定**: ✅ Pass（6/6）— 1回目で合格

## judge
```yaml
completeness: 10
accuracy: 9
clarity: 9
total: 0.93
failure_reason: ""
judge_comment: "CRM/ERPからMDM統合→インサイトまで一気通貫の参照アーキテクチャ。Entity Resolution名寄せ・Glue Data Quality品質ゲート・Lake Formationガバナンスの3層MDMコアが明確。Bedrock RAGによるAIインサイトも組み込み済み。AWS Knowledge MCPレビュー6/6 Pass。IaCテンプレート(910行)・コードビューアHTML・詳細ページ・一覧カードすべて生成済み。Subagent: cloud-engineer (IaC YAML生成)"
judged_at: "2026-03-28T21:45:00+09:00"
```
