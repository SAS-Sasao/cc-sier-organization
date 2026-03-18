# =============================================================
# environments/dev/variables.tf — 変数定義（全環境共通）
# 注意: dev / stg / prod の variables.tf は同一内容（DRY 原則）
#       環境固有の値は terraform.tfvars で設定すること
# =============================================================

variable "environment" {
  description = "デプロイ環境識別子（dev / stg / prod）"
  type        = string
}

variable "location" {
  description = "デプロイ先 Azure リージョン"
  type        = string
  default     = "japaneast"
}

variable "resource_group_name" {
  description = "DWH 基盤用リソースグループ名"
  type        = string
}

# ---- ネットワーク ----

variable "vnet_address_space" {
  description = "仮想ネットワークのアドレス空間（CIDR）"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_adf_address_prefix" {
  description = "ADF Managed IR 用サブネットの CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_synapse_address_prefix" {
  description = "Synapse 用サブネットの CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_pe_address_prefix" {
  description = "Private Endpoint 専用サブネットの CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

# ---- ストレージ ----

variable "storage_account_name" {
  description = "ADLS Gen2 ストレージアカウント名（3〜24 文字、小文字英数字のみ）"
  type        = string
}

variable "storage_replication_type" {
  description = "ストレージの冗長化タイプ（dev/stg: LRS、prod: ZRS）"
  type        = string
  default     = "LRS"
}

# ---- Key Vault ----

variable "key_vault_name" {
  description = "Key Vault 名"
  type        = string
}

variable "key_vault_sku" {
  description = "Key Vault の SKU（standard / premium）"
  type        = string
  default     = "standard"
}

variable "ops_object_ids" {
  description = "Key Vault の管理権限を付与する運用者のオブジェクト ID リスト"
  type        = list(string)
  default     = []
}

# ---- Data Factory ----

variable "data_factory_name" {
  description = "Azure Data Factory 名"
  type        = string
}

variable "adf_trigger_enabled" {
  description = "ADF スケジュールトリガーの有効化（dev: false、prod: true）"
  type        = bool
  default     = false
}

# ---- Synapse Analytics ----

variable "synapse_workspace_name" {
  description = "Synapse Workspace 名"
  type        = string
}

variable "enable_dedicated_sql_pool" {
  description = "Dedicated SQL Pool の作成有無（デフォルト false）"
  type        = bool
  default     = false
}

variable "allowed_ip_addresses" {
  description = "Synapse Workspace のファイアウォールで許可する IP アドレスリスト"
  type        = list(string)
  default     = []
}

# ---- Log Analytics / 監視 ----

variable "log_analytics_workspace_name" {
  description = "Log Analytics Workspace 名"
  type        = string
}

variable "log_retention_days" {
  description = "ログ保持日数（dev: 30日、stg: 60日、prod: 90日）"
  type        = number
  default     = 30
}

variable "teams_webhook_url" {
  description = "アラート通知先の Teams Incoming Webhook URL（空文字でスキップ）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email_addresses" {
  description = "アラート通知先メールアドレスリスト"
  type        = list(string)
  default     = []
}

# ---- タグ ----

variable "tags" {
  description = "全リソースに付与する共通タグ（Environment, Project, Owner, CostCenter）"
  type        = map(string)
  default     = {}
}
