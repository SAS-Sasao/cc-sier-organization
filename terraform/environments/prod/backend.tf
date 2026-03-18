# =============================================================
# environments/prod/backend.tf — Terraform State バックエンド設定（prod）
# State キー: a-company-dwh/prod/terraform.tfstate
#
# prod 環境 State の特別な考慮事項:
#   - State ファイルには機密値（パスワードハッシュ等）が含まれる可能性あり
#   - stadwhtfstate の RBAC で prod State への書き込みは
#     CI/CD サービスプリンシパルのみに制限すること
#   - Blob バージョニングと GRS（State 用ストレージ）で誤削除に対応
# =============================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stadwhtfstate"
    container_name       = "tfstate"
    key                  = "a-company-dwh/prod/terraform.tfstate"

    # GitHub Actions OIDC 認証（prod apply は手動承認後のみ実行される）
    use_oidc = true
  }
}
