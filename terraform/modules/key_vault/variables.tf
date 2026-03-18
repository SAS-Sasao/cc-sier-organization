# =============================================================
# modules/key_vault/variables.tf — 変数定義
# =============================================================

variable "resource_group_name" {
  description = "リソースを配置するリソースグループ名"
  type        = string
}

variable "location" {
  description = "デプロイ先 Azure リージョン（例: japaneast）"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault 名（3〜24 文字、英数字とハイフンのみ）"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD テナント ID（Key Vault アクセスポリシーに使用）"
  type        = string
}

variable "sku_name" {
  description = "Key Vault の SKU（standard または premium）"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name は standard または premium を指定してください。"
  }
}

variable "soft_delete_retention_days" {
  description = "ソフト削除の保持日数（7〜90 日）"
  type        = number
  default     = 90
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days は 7〜90 の範囲で指定してください。"
  }
}

variable "adf_principal_id" {
  description = "Azure Data Factory の Managed Identity プリンシパル ID（シークレット読み取り権限を付与）。循環参照回避のため、最初のデプロイ時は空文字を指定し、ADF/Synapse 作成後に terraform apply を再実行すること"
  type        = string
  default     = ""
}

variable "synapse_principal_id" {
  description = "Synapse Workspace の Managed Identity プリンシパル ID（シークレット読み取り権限を付与）。循環参照回避のため、最初のデプロイ時は空文字を指定し、ADF/Synapse 作成後に terraform apply を再実行すること"
  type        = string
  default     = ""
}

variable "ops_object_ids" {
  description = "運用者のオブジェクト ID リスト（管理権限を付与するユーザー/グループ）"
  type        = list(string)
  default     = []
}

variable "spo_client_secret_value" {
  description = "SharePoint Online Graph API 認証用クライアントシークレット値（sensitive）"
  type        = string
  sensitive   = true
  default     = "placeholder-replace-after-deploy"
}

variable "synapse_sql_admin_password" {
  description = "Synapse Workspace SQL 管理者パスワード（sensitive）"
  type        = string
  sensitive   = true
  default     = "placeholder-replace-after-deploy"
}

variable "environment" {
  description = "デプロイ環境識別子（dev / stg / prod）"
  type        = string
}

variable "tags" {
  description = "全リソースに付与する共通タグ（Environment, Project, Owner, CostCenter）"
  type        = map(string)
  default     = {}
}
