# =============================================================
# modules/storage/variables.tf — 変数定義
# =============================================================

variable "resource_group_name" {
  description = "リソースを配置するリソースグループ名"
  type        = string
}

variable "location" {
  description = "デプロイ先 Azure リージョン（例: japaneast）"
  type        = string
}

variable "storage_account_name" {
  description = "ADLS Gen2 ストレージアカウント名（3〜24文字、小文字英数字のみ）"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "ストレージアカウント名は 3〜24 文字の小文字英数字のみ使用可能です。"
  }
}

variable "replication_type" {
  description = "ストレージの冗長化タイプ（dev/stg: LRS、prod: ZRS）"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "ZRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type は LRS / GRS / ZRS / GZRS / RAGRS / RAGZRS のいずれかを指定してください。"
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

variable "tags" {
  description = "全リソースに付与する共通タグ（Environment, Project, Owner, CostCenter）"
  type        = map(string)
  default     = {}
}
