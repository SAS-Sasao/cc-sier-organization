# =============================================================
# modules/monitoring/main.tf — Log Analytics / Action Group / アラートルール
# 対象案件: A社基幹システムDWH構築
# 監視対象: ADF パイプライン失敗 / ADLS 容量超過 / データ鮮度 SLA
# =============================================================

# -------------------------------------------------------------
# Log Analytics Workspace
# ADF / Synapse / ADLS のログを集約する中央ログストア
# -------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # SKU: PerGB2018（従量課金。固定価格が必要な場合は CapacityReservation に変更）
  sku = "PerGB2018"

  # ログ保持日数（dev: 30日、stg: 60日、prod: 90日）
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# -------------------------------------------------------------
# Action Group: Teams Webhook 通知
# パイプライン失敗時に担当チャネルへ即時通知
# teams_webhook_url が設定された場合のみ作成
# -------------------------------------------------------------
resource "azurerm_monitor_action_group" "teams" {
  count = var.teams_webhook_url != "" ? 1 : 0

  name                = "ag-teams-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "teams-alert"

  webhook_receiver {
    name                    = "teams-webhook"
    service_uri             = var.teams_webhook_url
    use_common_alert_schema = true
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Action Group: Email 通知
# 管理者への重大アラート通知
# alert_email_addresses が設定された場合のみ作成
# -------------------------------------------------------------
resource "azurerm_monitor_action_group" "email" {
  count = length(var.alert_email_addresses) > 0 ? 1 : 0

  name                = "ag-email-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "email-alert"

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name                    = "admin-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------
# アラートルール: ADF パイプライン失敗
# ADF の PipelineFailedRuns メトリクスが 1 以上になった場合に発火
# SLA: 30 分以内確認
# -------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "pipeline_failed" {
  count = var.data_factory_id != "" ? 1 : 0

  name                = "alert-adf-pipeline-failed-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.data_factory_id]
  description         = "ADF パイプライン実行失敗を検知（SLA: 30分以内確認）"

  # 評価頻度: 5分ごと、評価ウィンドウ: 5分
  frequency   = "PT5M"
  window_size = "PT5M"

  # 重大度: 0（Critical）
  severity = 0

  criteria {
    metric_namespace = "Microsoft.DataFactory/factories"
    metric_name      = "PipelineFailedRuns"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0

    # パイプライン名でフィルタリング（全パイプラインを対象とするため、ここでは未指定）
  }

  # Teams と Email の両方に通知
  dynamic "action" {
    for_each = var.teams_webhook_url != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.teams[0].id
    }
  }

  dynamic "action" {
    for_each = length(var.alert_email_addresses) > 0 ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.email[0].id
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------
# アラートルール: ADLS 容量 80% 超過
# ストレージ使用量が閾値を超えた場合に警告
# SLA: 1週間以内対応（Warning レベル）
# 注意: ADLS Gen2 の容量制限は実質無制限だが、コストコントロールのため閾値を設定
# -------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "adls_capacity" {
  count = var.adls_storage_account_id != "" ? 1 : 0

  name                = "alert-adls-capacity-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.adls_storage_account_id]
  description         = "ADLS Gen2 使用容量が 800 GB を超過（コストアラート）"

  # 評価頻度: 1時間ごと
  frequency   = "PT1H"
  window_size = "PT1H"

  # 重大度: 2（Warning）
  severity = 2

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "UsedCapacity"
    aggregation      = "Average"
    operator         = "GreaterThan"
    # 800 GB = 858,993,459,200 bytes（prod Year 1 予測 100 GB の 80% 超を想定）
    threshold = 858993459200
  }

  dynamic "action" {
    for_each = length(var.alert_email_addresses) > 0 ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.email[0].id
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------
# アラートルール: ADF パイプライン タイムアウト
# 実行時間が 3 時間（180 分）を超過した場合に警告
# SLA: 1時間以内確認（Warning レベル）
# -------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "pipeline_timeout" {
  count = var.data_factory_id != "" ? 1 : 0

  name                = "alert-adf-pipeline-timeout-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.data_factory_id]
  description         = "ADF パイプライン実行時間が 3 時間を超過（タイムアウト警告）"

  frequency   = "PT15M"
  window_size = "PT15M"

  # 重大度: 2（Warning）
  severity = 2

  criteria {
    metric_namespace = "Microsoft.DataFactory/factories"
    metric_name      = "PipelineElapsedTimeRuns"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "Name"
      operator = "Include"
      values   = ["*"]
    }
  }

  dynamic "action" {
    for_each = var.teams_webhook_url != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.teams[0].id
    }
  }

  tags = var.tags
}
