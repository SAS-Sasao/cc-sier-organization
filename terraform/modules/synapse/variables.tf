# =============================================================
# modules/synapse/variables.tf — 変数定義
# =============================================================

variable "resource_group_name" {
  description = "リソースを配置するリソースグループ名"
  type        = string
}

variable "location" {
  description = "デプロイ先 Azure リージョン（例: japaneast）"
  type        = string
}

variable "workspace_name" {
  description = "Synapse Workspace 名"
  type        = string
}

variable "environment" {
  description = "デプロイ環境識別子（dev / stg / prod）"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment は dev / stg / prod のいずれかを指定してください。"
  }
}

variable "adls_filesystem_id" {
  description = "Synapse Workspace に紐付ける ADLS Gen2 ファイルシステムのリソース ID"
  type        = string
}

variable "adls_storage_account_id" {
  description = "ADLS Gen2 ストレージアカウントのリソース ID（RBAC 付与対象）"
  type        = string
}

variable "sql_administrator_login" {
  description = "Synapse SQL 管理者のログイン名"
  type        = string
  default     = "synapse_admin"
}

variable "sql_admin_password" {
  description = "Synapse SQL 管理者パスワード（Key Vault から取得した値を渡す）"
  type        = string
  sensitive   = true
}

variable "managed_virtual_network_enabled" {
  description = "Synapse Managed Virtual Network の有効化（true 推奨。プライベート通信強制）"
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "パブリックネットワークアクセスの許可（prod は false 推奨）"
  type        = bool
  default     = false
}

variable "allowed_ip_addresses" {
  description = "Synapse Workspace のファイアウォールで許可する IP アドレスリスト（運用端末）"
  type        = list(string)
  default     = []
}

variable "enable_dedicated_sql_pool" {
  description = "Dedicated SQL Pool の作成有無（デフォルト false: Serverless SQL Pool のみ使用）"
  type        = bool
  default     = false
}

variable "dedicated_sql_pool_name" {
  description = "Dedicated SQL Pool 名（enable_dedicated_sql_pool = true の場合に使用）"
  type        = string
  default     = "sqldedicated"
}

variable "dedicated_sql_pool_sku" {
  description = "Dedicated SQL Pool の SKU（DW100c: 最小。Power BI DirectQuery 用途では DW200c 以上推奨）"
  type        = string
  default     = "DW100c"
}

variable "log_analytics_workspace_id" {
  description = "Diagnostic Settings の送信先 Log Analytics Workspace リソース ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "全リソースに付与する共通タグ（Environment, Project, Owner, CostCenter）"
  type        = map(string)
  default     = {}
}
