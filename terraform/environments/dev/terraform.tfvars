# =============================================================
# environments/dev/terraform.tfvars — dev 環境固有変数値
# 注意: 機密情報（シークレット、パスワード）はここに記載しないこと
#       シークレットは Key Vault に直接設定するか、CI/CD の環境変数経由で渡すこと
# =============================================================

# 基本設定
environment         = "dev"
location            = "japaneast"
resource_group_name = "rg-a-company-dwh-dev"

# ネットワーク設定
vnet_address_space            = ["10.0.0.0/16"]
subnet_adf_address_prefix     = "10.0.1.0/24"
subnet_synapse_address_prefix = "10.0.2.0/24"
subnet_pe_address_prefix      = "10.0.3.0/24"

# ADLS Gen2 設定（dev は LRS で最安価に）
storage_account_name     = "stadwhacompanydev"
storage_replication_type = "LRS"

# Synapse Analytics 設定
synapse_workspace_name    = "synw-a-company-dwh-dev"
enable_dedicated_sql_pool = false # dev は Serverless SQL Pool のみ
# 開発者端末の IP を追加（例: 社内 VPN の出口 IP）
allowed_ip_addresses = []

# Azure Data Factory 設定
data_factory_name   = "adf-a-company-dwh-dev"
adf_trigger_enabled = false # dev はスケジュールトリガー無効（手動実行のみ）

# Key Vault 設定
key_vault_name = "kv-a-company-dwh-dev"
key_vault_sku  = "standard"
ops_object_ids = [] # 運用者の Azure AD オブジェクト ID を追加すること

# Log Analytics 設定（dev は 30 日保持でコスト最適化）
log_analytics_workspace_name = "law-a-company-dwh-dev"
log_retention_days           = 30

# アラート通知設定（dev は任意。空のままでもデプロイ可）
teams_webhook_url     = ""
alert_email_addresses = []

# タグ設定（全リソースに付与）
tags = {
  Environment = "dev"
  Project     = "a-company-dwh"
  Owner       = "data-team"
  CostCenter  = "CC-DWH-001"
}
