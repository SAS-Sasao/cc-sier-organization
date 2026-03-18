# =============================================================
# modules/data_factory/outputs.tf — 出力値定義
# =============================================================

output "data_factory_id" {
  description = "Azure Data Factory のリソース ID"
  value       = azurerm_data_factory.main.id
}

output "data_factory_name" {
  description = "Azure Data Factory 名"
  value       = azurerm_data_factory.main.name
}

output "managed_identity_principal_id" {
  description = "ADF の System Assigned Managed Identity プリンシパル ID（Key Vault アクセスポリシーに使用）"
  value       = azurerm_data_factory.main.identity[0].principal_id
}

output "managed_identity_tenant_id" {
  description = "ADF の System Assigned Managed Identity テナント ID"
  value       = azurerm_data_factory.main.identity[0].tenant_id
}

output "integration_runtime_id" {
  description = "Azure Integration Runtime のリソース ID"
  value       = azurerm_data_factory_integration_runtime_azure.auto_resolve.id
}
