# =============================================================
# modules/storage/outputs.tf — 出力値定義
# =============================================================

output "storage_account_id" {
  description = "ADLS Gen2 ストレージアカウントのリソース ID"
  value       = azurerm_storage_account.datalake.id
}

output "storage_account_name" {
  description = "ADLS Gen2 ストレージアカウント名"
  value       = azurerm_storage_account.datalake.name
}

output "storage_primary_dfs_endpoint" {
  description = "ADLS Gen2 の DFS プライマリエンドポイント URL"
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
}

output "filesystem_id" {
  description = "Data Lake ファイルシステム（コンテナ）のリソース ID"
  value       = azurerm_storage_data_lake_gen2_filesystem.datalake.id
}

output "filesystem_name" {
  description = "Data Lake ファイルシステム名"
  value       = azurerm_storage_data_lake_gen2_filesystem.datalake.name
}

output "filesystem_endpoint" {
  description = "Data Lake ファイルシステムの DFS エンドポイント（Synapse Workspace の紐付けに使用）"
  # Synapse Workspace の storage_data_lake_gen2_filesystem_id には filesystem の ID を渡す
  value = "https://${azurerm_storage_account.datalake.name}.dfs.core.windows.net/${azurerm_storage_data_lake_gen2_filesystem.datalake.name}"
}

output "managed_identity_principal_id" {
  description = "ストレージアカウントの System Assigned Managed Identity プリンシパル ID"
  value       = azurerm_storage_account.datalake.identity[0].principal_id
}
