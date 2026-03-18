# =============================================================
# modules/key_vault/main.tf — Azure Key Vault / アクセスポリシー / シークレット
# 対象案件: A社基幹システムDWH構築
# =============================================================

# -------------------------------------------------------------
# Azure Key Vault
# シークレット（クライアントシークレット、SQL パスワード）を一元管理
# -------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  # ソフト削除: 誤削除からの復元を可能にする（保持日数: 90日）
  soft_delete_retention_days = var.soft_delete_retention_days

  # パージ保護: ソフト削除期間中のパージを禁止（本番環境では必須）
  purge_protection_enabled = true

  # ネットワークアクセス制御: Private Endpoint 経由のみ許可
  # （networking モジュールで PE 作成後に有効化推奨）
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = var.tags
}

# -------------------------------------------------------------
# アクセスポリシー: Azure Data Factory Managed Identity
# Secret の List / Get のみ許可（最小権限の原則）
# 注意: adf_principal_id は ADF 作成後に判明する。
#       循環参照回避のため、2回目の terraform apply で適用される。
# -------------------------------------------------------------
resource "azurerm_key_vault_access_policy" "adf" {
  count = var.adf_principal_id != "" ? 1 : 0

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.adf_principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# -------------------------------------------------------------
# アクセスポリシー: Synapse Workspace Managed Identity
# Secret の List / Get のみ許可
# 注意: synapse_principal_id は Synapse 作成後に判明する。
#       循環参照回避のため、2回目の terraform apply で適用される。
# -------------------------------------------------------------
resource "azurerm_key_vault_access_policy" "synapse" {
  count = var.synapse_principal_id != "" ? 1 : 0

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.synapse_principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# -------------------------------------------------------------
# アクセスポリシー: 運用者
# Secret / Key / Certificate の全操作を許可
# -------------------------------------------------------------
resource "azurerm_key_vault_access_policy" "ops" {
  for_each = toset(var.ops_object_ids)

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = each.value

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Recover", "Purge", "Backup", "Restore"
  ]
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Purge", "Backup", "Restore"
  ]
  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
  ]
}

# -------------------------------------------------------------
# シークレット: SharePoint Online Graph API クライアントシークレット
# 初期値は placeholder。デプロイ後に運用者が実際の値を設定する
# -------------------------------------------------------------
resource "azurerm_key_vault_secret" "spo_client_secret" {
  name         = "spo-client-secret"
  value        = var.spo_client_secret_value
  key_vault_id = azurerm_key_vault.main.id

  # コンテンツタイプで用途を明示
  content_type = "Graph API Client Secret for SharePoint Online"

  tags = var.tags

  # アクセスポリシー設定後に作成する依存関係を明示
  depends_on = [azurerm_key_vault_access_policy.ops]
}

# -------------------------------------------------------------
# シークレット: Synapse Workspace SQL 管理者パスワード
# -------------------------------------------------------------
resource "azurerm_key_vault_secret" "synapse_sql_admin_password" {
  name         = "synapse-sql-admin-password"
  value        = var.synapse_sql_admin_password
  key_vault_id = azurerm_key_vault.main.id

  content_type = "Synapse SQL Administrator Password"

  tags = var.tags

  depends_on = [azurerm_key_vault_access_policy.ops]
}
