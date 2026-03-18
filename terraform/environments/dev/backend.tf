# =============================================================
# environments/dev/backend.tf — Terraform State バックエンド設定（dev）
# State 管理用ストレージ: stadwhtfstate（全環境共通）
# コンテナ:              tfstate
# State キー:            a-company-dwh/dev/terraform.tfstate
#
# 事前準備（初回のみ）:
#   az group create --name rg-terraform-state --location japaneast
#   az storage account create --name stadwhtfstate \
#     --resource-group rg-terraform-state --location japaneast \
#     --sku Standard_GRS --kind StorageV2 --min-tls-version TLS1_2
#   az storage container create --name tfstate \
#     --account-name stadwhtfstate
# =============================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stadwhtfstate"
    container_name       = "tfstate"
    key                  = "a-company-dwh/dev/terraform.tfstate"

    # GitHub Actions OIDC 認証を使用（CI/CD 環境）
    # ローカル実行時は use_oidc = false にして az login 認証を使用
    use_oidc = true
  }
}
