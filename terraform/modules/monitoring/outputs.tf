# =============================================================
# modules/monitoring/outputs.tf — 出力値定義
# =============================================================

output "workspace_id" {
  description = "Log Analytics Workspace のリソース ID（他モジュールの Diagnostic Settings が参照）"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "Log Analytics Workspace 名"
  value       = azurerm_log_analytics_workspace.main.name
}

output "workspace_customer_id" {
  description = "Log Analytics Workspace の Customer ID（エージェント設定に使用）"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "action_group_teams_id" {
  description = "Teams Webhook Action Group のリソース ID（未作成の場合は空文字）"
  value       = length(azurerm_monitor_action_group.teams) > 0 ? azurerm_monitor_action_group.teams[0].id : ""
}

output "action_group_email_id" {
  description = "Email Action Group のリソース ID（未作成の場合は空文字）"
  value       = length(azurerm_monitor_action_group.email) > 0 ? azurerm_monitor_action_group.email[0].id : ""
}
