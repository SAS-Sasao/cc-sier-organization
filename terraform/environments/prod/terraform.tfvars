# =============================================================
# environments/prod/terraform.tfvars — prod 環境固有変数値
# 注意:
#   - 機密情報（シークレット、パスワード）はここに記載しないこと
#   - teams_webhook_url と alert_email_addresses は CI/CD 環境変数
#     TF_VAR_teams_webhook_url / TF_VAR_alert_email_addresses で渡すこと
# =============================================================

# 基本設定
environment         = "prod"
location            = "japaneast"
resource_group_name = "rg-a-company-dwh-prod"

# ネットワーク設定（prod: 10.2.0.0/16 空間を使用して dev/stg と分離）
vnet_address_space            = ["10.2.0.0/16"]
subnet_adf_address_prefix     = "10.2.1.0/24"
subnet_synapse_address_prefix = "10.2.2.0/24"
subnet_pe_address_prefix      = "10.2.3.0/24"

# ADLS Gen2 設定（prod: ZRS でゾーン冗長。年5年保持対応）
storage_account_name     = "stadwhacompanyprod"
storage_replication_type = "ZRS"

# Synapse Analytics 設定
synapse_workspace_name    = "synw-a-company-dwh-prod"
enable_dedicated_sql_pool = false # 当初はサーバーレスのみ（Power BI DirectQuery 要件が生じたら有効化）
# prod: 運用端末のみ許可（Private Endpoint 接続が主経路）
allowed_ip_addresses = []

# Azure Data Factory 設定（prod: 日次トリガー有効）
data_factory_name   = "adf-a-company-dwh-prod"
adf_trigger_enabled = true

# Key Vault 設定
key_vault_name = "kv-a-company-dwh-prod"
key_vault_sku  = "standard"
ops_object_ids = [] # 運用チームの Azure AD オブジェクト ID を必ず設定すること

# Log Analytics 設定（prod: 90 日保持。コンプライアンス要件に対応）
log_analytics_workspace_name = "law-a-company-dwh-prod"
log_retention_days           = 90

# アラート通知設定（prod は必須。CI/CD 環境変数から注入推奨）
teams_webhook_url     = "" # TF_VAR_teams_webhook_url 環境変数で設定すること
alert_email_addresses = [] # TF_VAR_alert_email_addresses 環境変数で設定すること

# タグ設定
tags = {
  Environment = "prod"
  Project     = "a-company-dwh"
  Owner       = "data-team"
  CostCenter  = "CC-DWH-001"
}
