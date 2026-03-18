# プロジェクトマスタ

## proj-a-company-dwh

- **名称**: A社基幹システムDWH構築
- **ステータス**: planning
- **クライアント**: A社（製造業・中堅企業）
- **概要**: SharePoint Online上の見積データ・案件データ・顧客データをDWHに集約し、経営ダッシュボードと見積分析レポートを構築する。Phase 1はDWH＋ダッシュボード。将来的に見積生成UIも構築予定。
- **関連部署**: [dept-architecture, dept-data]
- **開始日**: 2026-04-01
- **技術スタック**:
  - ソース: SharePoint Online（REST API / Microsoft Graph API）
  - クラウド: Azure（主体）、一部AWS検討
  - DWH候補: Azure Synapse Analytics / Databricks / Snowflake（未決定）
  - ETL/ELT: Azure Data Factory + dbt
  - BI: Power BI
  - IaC: Terraform
