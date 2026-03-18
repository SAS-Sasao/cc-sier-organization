# =============================================================
# modules/data_factory/main.tf — Azure Data Factory / Linked Services / Triggers
# 対象案件: A社基幹システムDWH構築
# パイプライン: SharePoint Online → ADLS Gen2 Bronze 層 日次取り込み
# =============================================================

# -------------------------------------------------------------
# Azure Data Factory 本体
# Managed Identity を使用して Key Vault / ADLS へのキーレスアクセスを実現
# -------------------------------------------------------------
resource "azurerm_data_factory" "main" {
  name                = var.data_factory_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # System Assigned Managed Identity（Key Vault / ADLS の RBAC に使用）
  identity {
    type = "SystemAssigned"
  }

  # Git 連携は別途 Azure Portal / azurerm_data_factory_linked_service_github で設定
  # ここでは Terraform 管理のインフラ定義のみ実装

  tags = var.tags
}

# -------------------------------------------------------------
# Integration Runtime: Auto-Resolve Azure IR
# ADF のコンピュートリソース（Azure マネージド、東日本リージョン固定）
# -------------------------------------------------------------
resource "azurerm_data_factory_integration_runtime_azure" "auto_resolve" {
  name            = "AutoResolveIntegrationRuntime"
  data_factory_id = azurerm_data_factory.main.id
  location        = "AutoResolve" # リージョンを ADF が自動選択

  # コンピュートタイプ: General（汎用。データ変換が重い場合は MemoryOptimized に変更）
  compute_type     = "General"
  core_count       = 8    # DIU 数（コスト最適化のため 8 から開始）
  time_to_live_min = 10   # コンテナの再利用でコールドスタートを削減（分）
}

# -------------------------------------------------------------
# Linked Service: ADLS Gen2
# Managed Identity 認証で共有キーを使わない
# -------------------------------------------------------------
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "adls" {
  name            = "ls_adls_datalake"
  data_factory_id = azurerm_data_factory.main.id
  description     = "A社 ADLS Gen2 Data Lake（Bronze/Silver/Gold 層）への接続"

  # Managed Identity 認証
  use_managed_identity = true
  url                  = var.adls_filesystem_endpoint

  # Integration Runtime 指定（明示的に東日本を使用）
  integration_runtime_name = azurerm_data_factory_integration_runtime_azure.auto_resolve.name

  parameters = {
    environment = var.environment
  }
}

# -------------------------------------------------------------
# Linked Service: Azure Key Vault
# ADF パイプラインがシークレットを安全に参照するための接続
# -------------------------------------------------------------
resource "azurerm_data_factory_linked_service_key_vault" "kv" {
  name            = "ls_keyvault"
  data_factory_id = azurerm_data_factory.main.id
  description     = "Azure Key Vault（シークレット取得用）への接続"

  key_vault_id = var.key_vault_id
}

# -------------------------------------------------------------
# Linked Service: Microsoft Graph API（SharePoint Online）
# Bearer Token 認証で Graph API にアクセス
# クライアントシークレットは Key Vault 参照で安全に取得
# -------------------------------------------------------------
resource "azurerm_data_factory_linked_service_web" "graph_api" {
  name            = "ls_graph_api_spo"
  data_factory_id = azurerm_data_factory.main.id
  description     = "Microsoft Graph API v1.0（SharePoint Online リスト取得）への接続"

  # Bearer Token 認証（Token は Pipeline 内で動的に取得）
  authentication_type = "Anonymous"
  url                 = "https://graph.microsoft.com/v1.0"
}

# -------------------------------------------------------------
# スケジュールトリガー
# 毎日 02:00 JST（= 17:00 UTC 前日）に ADF パイプラインを起動
# prod: 有効、dev: 無効（変数 trigger_enabled で制御）
# -------------------------------------------------------------
resource "azurerm_data_factory_trigger_schedule" "daily_ingest" {
  name            = "trigger_daily_spo_to_bronze"
  data_factory_id = azurerm_data_factory.main.id
  description     = "毎日 02:00 JST に SharePoint Online → Bronze 層 取り込みパイプラインを起動"

  # activated = true のとき有効（dev は false）
  activated = var.trigger_enabled

  # UTC 表記: 02:00 JST = 17:00 UTC（前日）
  # recurrence: 毎日
  recurrence {
    frequency = "Day"
    interval  = 1
    start_time = var.trigger_start_time
    time_zone  = "UTC"
  }

  # トリガー対象パイプライン（パイプライン自体は ADF Studio または ARM テンプレートで定義）
  # Terraform では pipeline_name を参照のみ定義する
  pipeline_name = "pl_spo_to_bronze"

  annotations = [var.environment, "daily-ingest"]
}

# -------------------------------------------------------------
# Diagnostic Settings: ADF ログを Log Analytics に送信
# パイプライン失敗アラートの基礎データとなる
# -------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "adf" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "diag-adf-${var.environment}"
  target_resource_id         = azurerm_data_factory.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # パイプライン実行ログ
  enabled_log {
    category = "PipelineRuns"
  }

  # アクティビティ実行ログ
  enabled_log {
    category = "ActivityRuns"
  }

  # トリガー実行ログ
  enabled_log {
    category = "TriggerRuns"
  }

  # メトリクス（パイプライン実行数、失敗数）
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# -------------------------------------------------------------
# RBAC: ADF Managed Identity に ADLS への読み書き権限を付与
# Storage Blob Data Contributor: Bronze 層への書き込みに必要
# -------------------------------------------------------------
resource "azurerm_role_assignment" "adf_adls_contributor" {
  scope                = var.adls_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}
