# =============================================================
# environments/stg/main.tf — stg 環境エントリーポイント
# 対象案件: A社基幹システムDWH構築（ステージング環境）
# 構成方針:
#   - 本番データの匿名化コピー（直近1ヶ月分）で結合テストを実施
#   - LRS ストレージ（prod 環境の前検証のため冗長性は prod に合わせず）
#   - 週次スケジュールトリガー有効（月〜金の日次相当）→ コスト削減
#   - パブリックアクセス制限（QA チームのみ許可）
# =============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      # stg も本番前検証のため誤削除を防ぐ
      prevent_deletion_if_contains_resources = true
    }
  }
}

data "azurerm_client_config" "current" {}

# -------------------------------------------------------------
# Synapse SQL 管理者パスワード（ランダム生成）
# Key Vault に保存し、Synapse と Key Vault の循環参照を回避する
# -------------------------------------------------------------
resource "random_password" "synapse_sql_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# -------------------------------------------------------------
# リソースグループ
# -------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -------------------------------------------------------------
# monitoring モジュール（stg: ログ 60 日保持）
# -------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  workspace_name          = var.log_analytics_workspace_name
  log_retention_days      = var.log_retention_days
  environment             = var.environment
  teams_webhook_url       = var.teams_webhook_url
  alert_email_addresses   = var.alert_email_addresses
  adls_storage_account_id = module.storage.storage_account_id
  tags                    = var.tags
}

# -------------------------------------------------------------
# networking モジュール（stg 専用アドレス空間 10.1.0.0/16）
# -------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.location
  environment                   = var.environment
  vnet_address_space            = var.vnet_address_space
  subnet_adf_address_prefix     = var.subnet_adf_address_prefix
  subnet_synapse_address_prefix = var.subnet_synapse_address_prefix
  subnet_pe_address_prefix      = var.subnet_pe_address_prefix
  adls_storage_account_id       = module.storage.storage_account_id
  synapse_workspace_id          = module.synapse.workspace_id
  key_vault_id                  = module.key_vault.key_vault_id
  tags                          = var.tags
}

# -------------------------------------------------------------
# storage モジュール（stg: LRS）
# -------------------------------------------------------------
module "storage" {
  source = "../../modules/storage"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  storage_account_name = var.storage_account_name
  replication_type     = var.storage_replication_type
  environment          = var.environment
  tags                 = var.tags
}

# -------------------------------------------------------------
# key_vault モジュール
# 注意: 循環参照回避のため adf/synapse_principal_id は初回デプロイ時は空文字。
#       2 回目の apply で設定すること。
# -------------------------------------------------------------
module "key_vault" {
  source = "../../modules/key_vault"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  key_vault_name             = var.key_vault_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.key_vault_sku
  environment                = var.environment
  ops_object_ids             = var.ops_object_ids
  synapse_sql_admin_password = random_password.synapse_sql_admin.result
  adf_principal_id           = "" # 2回目の apply で設定
  synapse_principal_id       = "" # 2回目の apply で設定
  tags                       = var.tags
}

# -------------------------------------------------------------
# data_factory モジュール
# stg: 週次トリガー有効（月曜 02:00 JST）
# -------------------------------------------------------------
module "data_factory" {
  source = "../../modules/data_factory"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  data_factory_name          = var.data_factory_name
  environment                = var.environment
  adls_storage_account_id    = module.storage.storage_account_id
  adls_filesystem_endpoint   = module.storage.storage_primary_dfs_endpoint
  key_vault_id               = module.key_vault.key_vault_id
  key_vault_uri              = module.key_vault.key_vault_uri
  trigger_enabled            = var.adf_trigger_enabled
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = var.tags
}

# -------------------------------------------------------------
# synapse モジュール
# stg: パブリックアクセス制限（QA チーム端末 IP のみ許可）
# -------------------------------------------------------------
module "synapse" {
  source = "../../modules/synapse"

  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  workspace_name                  = var.synapse_workspace_name
  environment                     = var.environment
  adls_filesystem_id              = module.storage.filesystem_id
  adls_storage_account_id         = module.storage.storage_account_id
  sql_admin_password              = random_password.synapse_sql_admin.result
  managed_virtual_network_enabled = true
  public_network_access_enabled   = false # stg はアクセス制限あり
  allowed_ip_addresses            = var.allowed_ip_addresses
  enable_dedicated_sql_pool       = var.enable_dedicated_sql_pool
  log_analytics_workspace_id      = module.monitoring.workspace_id
  tags                            = var.tags
}
