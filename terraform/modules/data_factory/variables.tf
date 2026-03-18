# =============================================================
# modules/data_factory/variables.tf — 変数定義
# =============================================================

variable "resource_group_name" {
  description = "リソースを配置するリソースグループ名"
  type        = string
}

variable "location" {
  description = "デプロイ先 Azure リージョン（例: japaneast）"
  type        = string
}

variable "data_factory_name" {
  description = "Azure Data Factory インスタンス名"
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

variable "adls_storage_account_id" {
  description = "ADF が接続する ADLS Gen2 ストレージアカウントのリソース ID"
  type        = string
}

variable "adls_filesystem_endpoint" {
  description = "ADLS Gen2 DFS エンドポイント URL（Linked Service の接続先）"
  type        = string
}

variable "key_vault_id" {
  description = "Linked Service で参照する Key Vault のリソース ID"
  type        = string
}

variable "key_vault_uri" {
  description = "Linked Service で参照する Key Vault のエンドポイント URI"
  type        = string
  default     = ""
}

variable "trigger_enabled" {
  description = "スケジュールトリガーの有効/無効（dev: false、prod: true）"
  type        = bool
  default     = false
}

variable "trigger_start_time" {
  description = "スケジュールトリガーの開始日時（RFC 3339 形式）"
  type        = string
  default     = "2026-04-01T17:00:00Z" # 02:00 JST = 17:00 UTC（前日）
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
