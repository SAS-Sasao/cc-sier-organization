# =============================================================
# environments/stg/terraform.tfvars — stg 環境固有変数値
# 注意: 機密情報はここに記載しないこと
# =============================================================

# 基本設定
environment         = "stg"
location            = "japaneast"
resource_group_name = "rg-a-company-dwh-stg"

# ネットワーク設定（stg: 10.1.0.0/16 空間を使用して dev と分離）
vnet_address_space            = ["10.1.0.0/16"]
subnet_adf_address_prefix     = "10.1.1.0/24"
subnet_synapse_address_prefix = "10.1.2.0/24"
subnet_pe_address_prefix      = "10.1.3.0/24"

# ADLS Gen2 設定（stg: LRS）
storage_account_name     = "stadwhacompanystg"
storage_replication_type = "LRS"

# Synapse Analytics 設定
synapse_workspace_name    = "synw-a-company-dwh-stg"
enable_dedicated_sql_pool = false
# QA チームおよび開発者端末の IP を追加すること
allowed_ip_addresses = []

# Azure Data Factory 設定
# stg: 週次トリガー有効（月曜 02:00 JST でテスト実行）
data_factory_name   = "adf-a-company-dwh-stg"
adf_trigger_enabled = true

# Key Vault 設定
key_vault_name = "kv-a-company-dwh-stg"
key_vault_sku  = "standard"
ops_object_ids = [] # QA チームおよび運用者の Azure AD オブジェクト ID を追加すること

# Log Analytics 設定（stg: 60 日保持）
log_analytics_workspace_name = "law-a-company-dwh-stg"
log_retention_days           = 60

# アラート通知設定（stg は Teams 通知を設定推奨）
teams_webhook_url     = "" # stg テスト用チャネルの Webhook URL を設定すること
alert_email_addresses = [] # QA チームのメールアドレスを追加すること

# タグ設定
tags = {
  Environment = "stg"
  Project     = "a-company-dwh"
  Owner       = "data-team"
  CostCenter  = "CC-DWH-001"
}
