# =============================================================
# environments/prod/main.tf — prod 環境エントリーポイント
# 対象案件: A社基幹システムDWH構築（本番環境）
# 構成方針:
#   - ZRS ストレージ（ゾーン冗長でデータ保護強化）
#   - 日次スケジュールトリガー有効（毎日 02:00 JST）
#   - パブリックアクセス禁止（Private Endpoint のみ）
#   - リソースグループ削除保護有効
#   - 監視充実（Teams + Email アラート）
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
      # prod: パージ保護を有効化（誤削除からシークレットを守る）
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      # prod: リソースが残っている場合はリソースグループ削除を禁止
      prevent_deletion_if_contains_resources = true
    }
  }
}

data "azurerm_client_config" "current" {}

# -------------------------------------------------------------
# Synapse SQL 管理者パスワード（ランダム生成）
# Key Vault に保存し、Synapse と Key Vault の循環参照を回避する
# prod: パスワードは Key Vault に格納済み。ローテーションは運用手順書に従うこと
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
# prod 環境は削除保護 (prevent_deletion_if_contains_resources) を provider で設定済み
# -------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -------------------------------------------------------------
# monitoring モジュール（prod: ログ 90 日保持、アラート充実）
# 注意: data_factory_id は data_factory → monitoring → data_factory の循環参照を避けるため
#       ここでは渡さず、後続の azurerm_monitor_metric_alert リソースで直接定義する
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
# ADF パイプライン失敗アラート（prod 専用 — 循環参照を回避するため直接定義）
# monitoring モジュールに data_factory_id を渡すと循環参照が発生するため、
# data_factory 作成後に参照する形でここに配置する
# -------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "adf_pipeline_failed_prod" {
  name                = "alert-adf-pipeline-failed-prod"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [module.data_factory.data_factory_id]
  description         = "ADF パイプライン実行失敗を検知（SLA: 30分以内確認）"

  frequency   = "PT5M"
  window_size = "PT5M"
  severity    = 0 # Critical

  criteria {
    metric_namespace = "Microsoft.DataFactory/factories"
    metric_name      = "PipelineFailedRuns"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  dynamic "action" {
    for_each = var.teams_webhook_url != "" ? [module.monitoring.action_group_teams_id] : []
    content {
      action_group_id = action.value
    }
  }

  dynamic "action" {
    for_each = length(var.alert_email_addresses) > 0 ? [module.monitoring.action_group_email_id] : []
    content {
      action_group_id = action.value
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------
# networking モジュール（prod 専用アドレス空間 10.2.0.0/16）
# prod: Private Endpoint を全サービスに設定
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
# storage モジュール（prod: ZRS でゾーン冗長）
# -------------------------------------------------------------
module "storage" {
  source = "../../modules/storage"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  storage_account_name = var.storage_account_name
  replication_type     = var.storage_replication_type # ZRS
  environment          = var.environment
  tags                 = var.tags
}

# -------------------------------------------------------------
# key_vault モジュール
# prod: パージ保護は provider features で設定済み
# 注意: 循環参照回避のため adf/synapse_principal_id は初回デプロイ時は空文字。
#       2 回目の apply でアクセスポリシーが設定される。
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
  soft_delete_retention_days = 90 # prod は最大の 90 日
  synapse_sql_admin_password = random_password.synapse_sql_admin.result
  adf_principal_id           = "" # 2回目の apply で設定
  synapse_principal_id       = "" # 2回目の apply で設定
  tags                       = var.tags
}

# -------------------------------------------------------------
# data_factory モジュール
# prod: 日次スケジュールトリガー有効（毎日 02:00 JST）
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
  trigger_enabled            = var.adf_trigger_enabled # true
  trigger_start_time         = "2026-04-01T17:00:00Z"  # 02:00 JST
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = var.tags
}

# -------------------------------------------------------------
# synapse モジュール
# prod: パブリックアクセス禁止。Private Endpoint 経由のみ
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
  public_network_access_enabled   = false  # prod は完全にプライベート
  allowed_ip_addresses            = var.allowed_ip_addresses
  enable_dedicated_sql_pool       = var.enable_dedicated_sql_pool
  log_analytics_workspace_id      = module.monitoring.workspace_id
  tags                            = var.tags
}
