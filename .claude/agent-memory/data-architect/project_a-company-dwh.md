---
name: A社基幹システムDWH構築案件
description: A社（製造業・中堅企業）のSharePoint Online上の業務データをAzure上にメダリオンアーキテクチャで構築するDWH案件
type: project
---

A社基幹システムDWH構築案件のメダリオンアーキテクチャ全体設計を2026-03-18に初版作成。

**Why:** SharePoint Online上の見積管理・案件管理・顧客マスタ・担当者マスタを統合し、Power BIでの分析基盤を構築する。日次バッチ（AM9:00 SLA）、5年データ保持、担当者氏名の匿名化オプションが要件。

**How to apply:** 成果物は `.company/data/models/a-company-dwh/` に格納。技術スタックは ADF + dbt + Azure Data Lake Storage Gen2 + Synapse Serverless + Power BI。Bronze(Parquet) → Silver(Delta Lake, SCD Type 2) → Gold(スタースキーマ) の3層構成。顧客マスタ・担当者マスタは SCD Type 2 で履歴管理。匿名化は SHA-256 ハッシュベースで Gold 層ビューで実現。
