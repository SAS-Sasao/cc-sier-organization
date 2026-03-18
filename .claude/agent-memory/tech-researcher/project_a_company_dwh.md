---
name: A社DWH構築 プラットフォーム選定知見
description: A社DWH案件でのAzure Synapse vs Databricks 選定判断、コスト試算、SPOコネクタ詳細調査の知見
type: project
---

A社（製造業・中堅企業）のDWH構築案件でAzure Synapse Analyticsを推奨プラットフォームとして選定。

初期3候補（Synapse / Databricks / Snowflake）比較: `platform-comparison.md`
深掘り2候補（Synapse vs Databricks）比較: `platform-deep-comparison.md`

**Why:** 実データ量（初年度100GB、5年後1TB）と少人数チーム（2-3名）という制約から、コスト・運用容易性でSynapseが有利と判断。

**How to apply:** 同規模（〜1TB）のDWH案件でAzure環境を前提とする場合、同様の結論が得られる可能性が高い。データ量10TB超・ML統合・マルチクラウドが要件に加わった時点でDatabricksを再評価する。

## 主要な判断ポイント

- Year 1〜5の5年TCO: Synapse ¥143万 vs Databricks(Premium) ¥370万（為替 1USD=150JPY前提）
- ADF SPOコネクタはdeltaクエリ非対応だが、更新日時フィルタで A社要件は充足可能
- 実装工数: Synapse(ADF GUI) 4日 vs Databricks(MSAL+カスタムコード) 8.5日
- ADLS Gen2 + Delta形式で格納することで将来のDatabricks移行オプションを保持

## 料金前提（2025-2026年）

- Synapse Serverless: $5.00/TBクエリ処理（Japan East）
- Databricks SQL Warehouse Premium: $0.40/DBU/時間
- ADLS Gen2 ホット: $0.023/GB/月
- 為替: 1 USD = 150 JPY
