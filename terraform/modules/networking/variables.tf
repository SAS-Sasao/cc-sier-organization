# =============================================================
# modules/networking/variables.tf — 変数定義
# =============================================================

variable "resource_group_name" {
  description = "リソースを配置するリソースグループ名"
  type        = string
}

variable "location" {
  description = "デプロイ先 Azure リージョン（例: japaneast）"
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

variable "project_name" {
  description = "プロジェクト略称（リソース命名に使用）"
  type        = string
  default     = "a-company-dwh"
}

variable "vnet_address_space" {
  description = "仮想ネットワークのアドレス空間（CIDR 表記）"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_adf_address_prefix" {
  description = "ADF Managed Integration Runtime 用サブネットの CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_synapse_address_prefix" {
  description = "Synapse Analytics 用サブネットの CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_pe_address_prefix" {
  description = "Private Endpoint 専用サブネットの CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

variable "adls_storage_account_id" {
  description = "Private Endpoint を作成する ADLS Gen2 ストレージアカウントのリソース ID"
  type        = string
  default     = ""
}

variable "synapse_workspace_id" {
  description = "Private Endpoint を作成する Synapse Workspace のリソース ID"
  type        = string
  default     = ""
}

variable "key_vault_id" {
  description = "Private Endpoint を作成する Key Vault のリソース ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "全リソースに付与する共通タグ（Environment, Project, Owner, CostCenter）"
  type        = map(string)
  default     = {}
}
