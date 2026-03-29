# Talent Data Integration on AWS

- **ファイル名**: talent-data-arch-aws
- **領域**: MDM / Analytics
- **案件名**: 人材データ統合
- **作成日**: 2026-03-29
- **作成者**: SAS-Sasao
- **元図**: [C4モデル（draw.io）](../../docs/drawio/talent-data-arch.html)

## AWSサービスマッピング

| C4コンポーネント | AWSサービス |
|---|---|
| メンバー/パートナー管理アプリ | API Gateway + Lambda + Aurora PostgreSQL Serverless v2 |
| SharePoint連携 | EventBridge (webhook) |
| MDM | DMS (CDC) + Step Functions + Glue ETL + Data Catalog |
| データレイク | S3 + Lake Formation |
| DWH | Redshift Serverless |
| BIツール | QuickSight |
| タレマネアプリ | Lambda + API Gateway |
| 認証 | Amazon Cognito |

## レビュー結果

- アーキテクチャレビュー: 6/6 Pass (attempt 2)
- IaC検証: cfn-lint valid, cfn-guard 6 violations (S3 optional features)
- EngineVersion: 16.6 (15.4から修正)
