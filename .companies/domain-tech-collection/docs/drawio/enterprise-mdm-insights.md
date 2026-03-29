# Enterprise MDM & Data Insights Architecture（draw.io AWS公式アイコン版）

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | enterprise-mdm-insights.drawio |
| 図の種類 | C4モデル（AWS公式アイコン付き） |
| ツール | open_drawio_xml |
| 作成日 | 2026-03-29 |
| 作成者 | SAS-Sasao |
| 元図 | [Python Diagrams版](../../docs/diagrams/enterprise-mdm-insights.html) |

## 概要

Python Diagrams で生成した Enterprise MDM & Data Insights Architecture を、
draw.io XML 形式（AWS公式アイコン付き）で再作成したもの。
draw.io デスクトップアプリや Web 版で直接編集可能。

## 構成（20サービス・7層）

### データソース層
- Salesforce CRM、SAP / Legacy DB

### 取り込み層
- Amazon AppFlow（SaaS API連携）
- Amazon EventBridge（イベント駆動）
- Kinesis Data Firehose（ストリーム配信）
- AWS DMS（CDC差分レプリケーション）

### ストレージ層（3ゾーン）
- S3 Raw Zone → S3 Staged Zone → S3 Golden Zone (SSOT)

### MDM処理層
- AWS Entity Resolution（ファジーマッチング名寄せ）
- Glue Data Quality（DQDLルール検証・品質ゲート）

### 分析・可視化層
- Amazon Redshift Serverless（DWH分析）
- Amazon Athena（アドホックSQL）
- Amazon QuickSight（BIダッシュボード）
- Amazon Bedrock RAG（自然言語インサイト）

### オーケストレーション
- AWS Step Functions（パイプライン自動化）

### ガバナンス層
- Glue Data Catalog / Lake Formation / KMS / CloudWatch / CloudTrail
