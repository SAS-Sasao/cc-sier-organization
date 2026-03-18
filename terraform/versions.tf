# =============================================================
# versions.tf — Terraform バージョン制約 / プロバイダー宣言
# 対象案件: A社基幹システムDWH構築
# =============================================================

terraform {
  # Terraform 本体のバージョン制約
  required_version = ">= 1.6.0"

  required_providers {
    # Azure Resource Manager プロバイダー
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }

    # ランダム文字列生成（リソース名のサフィックスに使用）
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
