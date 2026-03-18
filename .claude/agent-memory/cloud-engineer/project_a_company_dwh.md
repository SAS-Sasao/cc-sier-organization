---
name: A社DWH案件アーキテクチャ決定
description: A社（製造業・中堅企業）基幹システムDWH構築案件のプラットフォーム選定と設計方針
type: project
---

Azure Synapse Analytics を推奨DWHプラットフォームとして採択。

**Why:** Azure主体環境との一体性・SPO連携の容易さ・単一Terraform Provider管理・コスト効率のバランスが最優秀。Snowflakeが総合スコアでやや上回るが、Azure環境との統合コストと別途課金管理の負担が中堅企業少人数チームに不適。

**How to apply:** 追加設計や変更提案を行う際は Synapse Serverless SQL Pool + ADLS Gen2 + ADF + Power BI の構成を前提とすること。

主要設計決定:
- API: Microsoft Graph API v1.0（delta クエリで差分取得）
- 認証: サービスプリンシパル（client_credentials フロー）、シークレットは Key Vault 管理
- 取り込み戦略: 日次差分 + 月1回フルリロード
- スケジュール: ADF 02:00 JST → dbt 04:00 JST → Power BI 06:00 JST（9時までに完了）
- dbt: Bronze/Silver/Gold 3層、`dbt-synapse` アダプタ、匿名化は `anonymize_pii` var で制御
- Terraform: azurerm 単一 Provider、環境分離は `environments/dev|stg|prod`、State は Azure Blob
- 個人情報: dbt マクロ `anonymize_name()` で担当者氏名をマスキング（オプション）

成果物パス:
- `.company/data/pipelines/a-company-dwh/platform-comparison.md`
- `.company/data/pipelines/a-company-dwh/pipeline-design.md`
- `.company/data/pipelines/a-company-dwh/terraform-design.md`
- `terraform/` — Terraform モジュール実装（azurerm ~> 3.90）

Terraform 実装上の重要設計判断:
- 循環参照回避: Key Vault と ADF/Synapse の依存は「Key Vault 先行作成 → 2回目 apply でアクセスポリシー追加」の2フェーズデプロイで解消
- Synapse SQL パスワード: random_password リソースでランダム生成し Key Vault に格納（循環参照なし）
- ADF パイプライン失敗アラートは prod/main.tf に直接定義（monitoring ↔ data_factory の循環を回避）
- 環境 IP アドレス空間: dev=10.0.0.0/16、stg=10.1.0.0/16、prod=10.2.0.0/16（環境分離）
