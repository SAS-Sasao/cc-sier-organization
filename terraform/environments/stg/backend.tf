# =============================================================
# environments/stg/backend.tf — Terraform State バックエンド設定（stg）
# State キー: a-company-dwh/stg/terraform.tfstate
# =============================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stadwhtfstate"
    container_name       = "tfstate"
    key                  = "a-company-dwh/stg/terraform.tfstate"

    use_oidc = true
  }
}
