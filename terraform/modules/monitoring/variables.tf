# =============================================================
# modules/monitoring/variables.tf — 変数定義
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
  description = "Log Analytics Workspace 名"
  type        = string
}

variable "log_retention_days" {
  description = "Log Analytics のログ保持日数（dev: 30日、stg: 60日、prod: 90日）"
  type        = number
  default     = 30
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days は 30〜730 の範囲で指定してください。"
  }
}

variable "environment" {
  description = "デプロイ環境識別子（dev / stg / prod）"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment は dev / stg / prod のいずれかを指定してください。"
  }
}

variable "teams_webhook_url" {
  description = "アラート通知先の Teams Incoming Webhook URL（空文字の場合は Teams Action Group を作成しない）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email_addresses" {
  description = "アラート通知先のメールアドレスリスト（管理者向け）"
  type        = list(string)
  default     = []
}

variable "data_factory_id" {
  description = "パイプライン失敗アラートを設定する ADF のリソース ID"
  type        = string
  default     = ""
}

variable "adls_storage_account_id" {
  description = "ADLS 容量アラートを設定するストレージアカウントのリソース ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "全リソースに付与する共通タグ（Environment, Project, Owner, CostCenter）"
  type        = map(string)
  default     = {}
}
