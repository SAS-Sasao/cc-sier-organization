# =============================================================
# environments/prod/outputs.tf — 主要リソースの出力値
# =============================================================

output "resource_group_name" {
  description = "prod 環境のリソースグループ名"
  value       = azurerm_resource_group.main.name
}

output "storage_account_id" {
  description = "ADLS Gen2 ストレージアカウントのリソース ID"
  value       = module.storage.storage_account_id
}

output "storage_primary_dfs_endpoint" {
  description = "ADLS Gen2 DFS プライマリエンドポイント"
  value       = module.storage.storage_primary_dfs_endpoint
}

output "key_vault_uri" {
  description = "Key Vault エンドポイント URI"
  value       = module.key_vault.key_vault_uri
}

output "data_factory_id" {
  description = "Azure Data Factory のリソース ID"
  value       = module.data_factory.data_factory_id
}

output "synapse_serverless_sql_endpoint" {
  description = "Synapse Serverless SQL Pool 接続エンドポイント（dbt profiles.yml に設定する server 値）"
  value       = module.synapse.serverless_sql_endpoint
}

output "synapse_workspace_id" {
  description = "Synapse Workspace のリソース ID"
  value       = module.synapse.workspace_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace のリソース ID"
  value       = module.monitoring.workspace_id
}

output "vnet_id" {
  description = "仮想ネットワークのリソース ID"
  value       = module.networking.vnet_id
}

output "private_endpoint_adls_dfs_id" {
  description = "ADLS Gen2 DFS Private Endpoint のリソース ID"
  value       = module.networking.private_endpoint_adls_dfs_id
}

output "private_endpoint_synapse_sql_id" {
  description = "Synapse SQL Private Endpoint のリソース ID"
  value       = module.networking.private_endpoint_synapse_sql_id
}

output "private_endpoint_key_vault_id" {
  description = "Key Vault Private Endpoint のリソース ID"
  value       = module.networking.private_endpoint_key_vault_id
}
