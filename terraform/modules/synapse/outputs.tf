# =============================================================
# modules/synapse/outputs.tf — 出力値定義
# =============================================================

output "workspace_id" {
  description = "Synapse Workspace のリソース ID"
  value       = azurerm_synapse_workspace.main.id
}

output "workspace_name" {
  description = "Synapse Workspace 名"
  value       = azurerm_synapse_workspace.main.name
}

output "managed_identity_principal_id" {
  description = "Synapse Workspace の System Assigned Managed Identity プリンシパル ID（Key Vault アクセスポリシーに使用）"
  value       = azurerm_synapse_workspace.main.identity[0].principal_id
}

output "serverless_sql_endpoint" {
  description = "Serverless SQL Pool の接続エンドポイント（dbt profiles.yml の server 値）"
  value       = azurerm_synapse_workspace.main.connectivity_endpoints["sqlOnDemand"]
}

output "dedicated_sql_endpoint" {
  description = "Dedicated SQL Pool の接続エンドポイント（enable_dedicated_sql_pool = true の場合のみ有効）"
  value       = azurerm_synapse_workspace.main.connectivity_endpoints["sql"]
}

output "dev_endpoint" {
  description = "Synapse Studio の開発エンドポイント URL"
  value       = azurerm_synapse_workspace.main.connectivity_endpoints["dev"]
}

output "dedicated_sql_pool_id" {
  description = "Dedicated SQL Pool のリソース ID（enable_dedicated_sql_pool = false の場合は空文字）"
  value       = length(azurerm_synapse_sql_pool.dedicated) > 0 ? azurerm_synapse_sql_pool.dedicated[0].id : ""
}
