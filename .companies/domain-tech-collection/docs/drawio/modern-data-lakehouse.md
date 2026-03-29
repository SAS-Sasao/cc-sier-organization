# Modern Data Lakehouse on AWS（draw.io編集版）

- **図の種類**: AWS構成図（draw.io + AWS Architecture Icons）
- **案件**: 技術ドメイン収集
- **作成日**: 2026-03-29
- **作成者**: SAS-Sasao
- **ツール**: open_drawio_xml（AWS 4 shapes使用）
- **ファイル**: [modern-data-lakehouse.html](https://sas-sasao.github.io/cc-sier-organization/drawio/modern-data-lakehouse.html)
- **参照元**: [AWS Diagram MCP版](https://sas-sasao.github.io/cc-sier-organization/diagrams/modern-data-lakehouse.html)

## 概要

既存のAWS Diagram MCP版（PNG画像）をdraw.io編集可能なXML形式に変換。
AWS公式アイコン（mxgraph.aws4）を使用し、draw.ioアプリで自由に編集・カスタマイズ可能。

## 使用AWSサービス

- Amazon S3（Bronze/Silver/Gold）
- AWS DMS（CDC）
- Kinesis Data Streams / Data Firehose
- Step Functions
- AWS Glue ETL / Glue Data Catalog
- Amazon EMR（Spark）
- AWS Lake Formation
- Amazon Athena
- Amazon Redshift Serverless
- Amazon QuickSight

## draw.io XMLソース

`open_drawio_xml` で生成。ファイル: `docs/drawio/modern-data-lakehouse.drawio`
