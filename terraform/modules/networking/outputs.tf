# =============================================================
# modules/networking/outputs.tf — 出力値定義
# =============================================================

output "vnet_id" {
  description = "仮想ネットワークのリソース ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "仮想ネットワーク名"
  value       = azurerm_virtual_network.main.name
}

output "subnet_adf_id" {
  description = "ADF Managed Integration Runtime 用サブネットのリソース ID"
  value       = azurerm_subnet.adf.id
}

output "subnet_synapse_id" {
  description = "Synapse Analytics 用サブネットのリソース ID"
  value       = azurerm_subnet.synapse.id
}

output "subnet_private_endpoint_id" {
  description = "Private Endpoint 専用サブネットのリソース ID"
  value       = azurerm_subnet.private_endpoint.id
}

output "private_dns_zone_blob_id" {
  description = "Blob Storage 用 Private DNS Zone のリソース ID"
  value       = azurerm_private_dns_zone.blob.id
}

output "private_dns_zone_dfs_id" {
  description = "ADLS Gen2 (DFS) 用 Private DNS Zone のリソース ID"
  value       = azurerm_private_dns_zone.dfs.id
}

output "private_dns_zone_vaultcore_id" {
  description = "Key Vault 用 Private DNS Zone のリソース ID"
  value       = azurerm_private_dns_zone.vaultcore.id
}

output "private_dns_zone_synapse_sql_id" {
  description = "Synapse SQL 用 Private DNS Zone のリソース ID"
  value       = azurerm_private_dns_zone.synapse_sql.id
}

output "private_endpoint_adls_blob_id" {
  description = "ADLS Blob 用 Private Endpoint のリソース ID（未作成の場合は空文字）"
  value       = length(azurerm_private_endpoint.adls_blob) > 0 ? azurerm_private_endpoint.adls_blob[0].id : ""
}

output "private_endpoint_adls_dfs_id" {
  description = "ADLS DFS 用 Private Endpoint のリソース ID（未作成の場合は空文字）"
  value       = length(azurerm_private_endpoint.adls_dfs) > 0 ? azurerm_private_endpoint.adls_dfs[0].id : ""
}

output "private_endpoint_synapse_sql_id" {
  description = "Synapse SQL 用 Private Endpoint のリソース ID（未作成の場合は空文字）"
  value       = length(azurerm_private_endpoint.synapse_sql) > 0 ? azurerm_private_endpoint.synapse_sql[0].id : ""
}

output "private_endpoint_key_vault_id" {
  description = "Key Vault 用 Private Endpoint のリソース ID（未作成の場合は空文字）"
  value       = length(azurerm_private_endpoint.key_vault) > 0 ? azurerm_private_endpoint.key_vault[0].id : ""
}
