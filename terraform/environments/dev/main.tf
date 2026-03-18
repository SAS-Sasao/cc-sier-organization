# =============================================================
# environments/dev/main.tf — dev 環境エントリーポイント
# 対象案件: A社基幹システムDWH構築（開発環境）
# 構成方針:
#   - 最小構成でコストを抑える（LRS ストレージ、トリガー無効）
#   - Dedicated SQL Pool は作成しない
#   - Public アクセスを許可（開発者が直接接続できるようにする）
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
      # dev では誤削除防止のためパージを許可しない
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      # dev は削除を許可（開発効率のため）
      prevent_deletion_if_contains_resources = false
    }
  }
}

# 現在の Azure クライアント設定を取得（tenant_id などに使用）
data "azurerm_client_config" "current" {}

# -------------------------------------------------------------
# Synapse SQL 管理者パスワード（ランダム生成）
# Key Vault に保存し、Synapse と Key Vault の循環参照を回避する
# terraform apply 完了後、Key Vault から確認すること
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
# monitoring モジュール（最初に作成: 他モジュールが参照するため）
# dev: ログ 30 日保持、Teams/Email は任意設定
# -------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  workspace_name       = var.log_analytics_workspace_name
  log_retention_days   = var.log_retention_days
  environment          = var.environment
  teams_webhook_url    = var.teams_webhook_url
  alert_email_addresses = var.alert_email_addresses
  tags                 = var.tags
}

# -------------------------------------------------------------
# networking モジュール
# dev: Private Endpoint は後から追加（初期構成では PE なし）
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
  tags                          = var.tags

  # PE はストレージ/KV/Synapse 作成後に追加する（初期デプロイは空のまま）
  adls_storage_account_id = module.storage.storage_account_id
  synapse_workspace_id    = module.synapse.workspace_id
  key_vault_id            = module.key_vault.key_vault_id
}

# -------------------------------------------------------------
# storage モジュール
# dev: LRS（最安価）
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
# 注意: adf_principal_id / synapse_principal_id は ADF/Synapse 作成後に判明するため
#       初回 apply 時は空文字。2 回目の apply でアクセスポリシーが設定される。
#       synapse_sql_admin_password はランダム生成した値を渡すことで循環参照を回避。
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
  adf_principal_id           = "" # 2回目の apply で module.data_factory.managed_identity_principal_id を設定
  synapse_principal_id       = "" # 2回目の apply で module.synapse.managed_identity_principal_id を設定
  tags                       = var.tags
}

# -------------------------------------------------------------
# data_factory モジュール
# dev: スケジュールトリガー無効（手動実行のみ）
# -------------------------------------------------------------
module "data_factory" {
  source = "../../modules/data_factory"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  data_factory_name        = var.data_factory_name
  environment              = var.environment
  adls_storage_account_id  = module.storage.storage_account_id
  adls_filesystem_endpoint = module.storage.storage_primary_dfs_endpoint
  key_vault_id             = module.key_vault.key_vault_id
  key_vault_uri            = module.key_vault.key_vault_uri
  trigger_enabled          = var.adf_trigger_enabled
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                     = var.tags
}

# -------------------------------------------------------------
# synapse モジュール
# dev: パブリックアクセス許可（開発者のローカル接続のため）
#      Dedicated Pool 無効
# -------------------------------------------------------------
module "synapse" {
  source = "../../modules/synapse"

  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.location
  workspace_name                = var.synapse_workspace_name
  environment                   = var.environment
  adls_filesystem_id            = module.storage.filesystem_id
  adls_storage_account_id       = module.storage.storage_account_id
  sql_admin_password            = random_password.synapse_sql_admin.result
  managed_virtual_network_enabled = true
  public_network_access_enabled = true  # dev では開発者アクセスのため許可
  allowed_ip_addresses          = var.allowed_ip_addresses
  enable_dedicated_sql_pool     = var.enable_dedicated_sql_pool
  log_analytics_workspace_id    = module.monitoring.workspace_id
  tags                          = var.tags
}
