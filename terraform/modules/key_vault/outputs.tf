# =============================================================
# modules/key_vault/outputs.tf — 出力値定義
# =============================================================

output "key_vault_id" {
  description = "Key Vault のリソース ID"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Key Vault 名"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault のエンドポイント URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "synapse_admin_password_secret_id" {
  description = "Synapse SQL 管理者パスワードシークレットのバージョン付き URI（Synapse Workspace 作成時に使用）"
  value       = azurerm_key_vault_secret.synapse_sql_admin_password.id
  sensitive   = true
}

output "synapse_admin_password" {
  description = "Synapse SQL 管理者パスワード（Synapse Workspace リソース作成時に参照）"
  value       = azurerm_key_vault_secret.synapse_sql_admin_password.value
  sensitive   = true
}

output "spo_client_secret_id" {
  description = "SPO クライアントシークレットのバージョン付き URI"
  value       = azurerm_key_vault_secret.spo_client_secret.id
  sensitive   = true
}
