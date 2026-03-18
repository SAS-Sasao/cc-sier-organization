# =============================================================
# modules/synapse/main.tf — Azure Synapse Analytics Workspace
# 対象案件: A社基幹システムDWH構築
# 主体: Serverless SQL Pool（dbt 変換・Power BI 参照）
# オプション: Dedicated SQL Pool（変数で制御）
# =============================================================

# -------------------------------------------------------------
# Synapse Workspace 本体
# Managed VNet 有効化でアウトバウンドをプライベート接続に限定
# -------------------------------------------------------------
resource "azurerm_synapse_workspace" "main" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # ADLS Gen2 ファイルシステムを Primary Data Lake として紐付け
  storage_data_lake_gen2_filesystem_id = var.adls_filesystem_id

  # SQL 管理者認証（初期設定用。運用時は Azure AD 認証に移行推奨）
  sql_administrator_login          = var.sql_administrator_login
  sql_administrator_login_password = var.sql_admin_password

  # Managed Virtual Network: 全アウトバウンドを Managed PE 経由に強制
  managed_virtual_network_enabled = var.managed_virtual_network_enabled

  # パブリックネットワークアクセス制限（prod では false 必須）
  public_network_access_enabled = var.public_network_access_enabled

  # System Assigned Managed Identity（ADLS / Key Vault の RBAC に使用）
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# -------------------------------------------------------------
# RBAC: Synapse Managed Identity に ADLS への書き込み権限を付与
# dbt on Serverless SQL Pool が Gold 層を書き込むために必要
# -------------------------------------------------------------
resource "azurerm_role_assignment" "synapse_adls_contributor" {
  scope                = var.adls_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.main.identity[0].principal_id
}

# -------------------------------------------------------------
# Managed Private Endpoint: Synapse → ADLS Gen2 (DFS)
# Managed VNet 内から ADLS へのプライベート接続
# 承認は自動（azurerm プロバイダーが自動承認を処理）
# -------------------------------------------------------------
resource "azurerm_synapse_managed_private_endpoint" "adls_dfs" {
  name                 = "mpe-adls-dfs-${var.environment}"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  target_resource_id   = var.adls_storage_account_id
  subresource_name     = "dfs"
}

# -------------------------------------------------------------
# Firewall Rule: 運用端末の IP アドレスのみ許可
# public_network_access_enabled が false の場合は機能しないが、
# 将来的な一時開放時の設定として定義しておく
# -------------------------------------------------------------
resource "azurerm_synapse_firewall_rule" "ops_ip" {
  for_each = toset(var.allowed_ip_addresses)

  name                 = "allow-ops-${replace(each.value, ".", "-")}"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  start_ip_address     = each.value
  end_ip_address       = each.value
}

# -------------------------------------------------------------
# Firewall Rule: Azure サービスからの接続を許可
# Synapse Studio / Power BI Service からのアクセスに必要
# （0.0.0.0 は "Azure サービスを許可" の特殊ルール）
# -------------------------------------------------------------
resource "azurerm_synapse_firewall_rule" "azure_services" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

# -------------------------------------------------------------
# Dedicated SQL Pool（オプション）
# 変数 enable_dedicated_sql_pool = true の場合のみ作成
# Power BI DirectQuery のパフォーマンス要件が生じた場合に有効化
# コスト注意: DW100c = 約 ¥181/時間。不使用時は必ず停止すること
# -------------------------------------------------------------
resource "azurerm_synapse_sql_pool" "dedicated" {
  count = var.enable_dedicated_sql_pool ? 1 : 0

  name                 = var.dedicated_sql_pool_name
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  sku_name             = var.dedicated_sql_pool_sku

  # 作成時のデータソース（新規作成）
  create_mode = "Default"

  # 自動一時停止（コスト最適化: アイドル時間後に自動停止）
  # azurerm 3.x では直接設定できないため、ARM テンプレートまたは運用スクリプトで設定
  tags = var.tags
}

# -------------------------------------------------------------
# Diagnostic Settings: Synapse ログを Log Analytics に送信
# RBAC 操作・SQL 監査・ゲートウェイリクエストを記録
# -------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "synapse" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "diag-synapse-${var.environment}"
  target_resource_id         = azurerm_synapse_workspace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Synapse RBAC 操作ログ
  enabled_log {
    category = "SynapseRbacOperations"
  }

  # ゲートウェイ API リクエストログ
  enabled_log {
    category = "GatewayApiRequests"
  }

  # SQL セキュリティ監査ログ
  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  # Synapse Link 操作ログ
  enabled_log {
    category = "SynapseLinkEvent"
  }

  # 全メトリクス
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
