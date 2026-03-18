# =============================================================
# modules/storage/main.tf — ADLS Gen2 / Data Lake ファイルシステム / ライフサイクルポリシー
# 対象案件: A社基幹システムDWH構築
# =============================================================

# -------------------------------------------------------------
# ADLS Gen2 ストレージアカウント
# HNS（階層型名前空間）を有効化して Data Lake として機能させる
# -------------------------------------------------------------
resource "azurerm_storage_account" "datalake" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type # dev/stg: LRS、prod: ZRS

  # ADLS Gen2 として機能させる（階層型名前空間）
  is_hns_enabled = true

  # セキュリティ設定: TLS 1.2 強制 + 公開アクセス禁止
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  enable_https_traffic_only       = true

  # 共有キーアクセス: ADF Linked Service の互換性のため当面有効
  # 将来的には Azure AD 認証のみに移行を推奨
  shared_access_key_enabled = true

  # Managed Identity（RBAC による ADLS アクセスの受け口）
  identity {
    type = "SystemAssigned"
  }

  # Blob のソフト削除（誤削除からの復元）
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Data Lake ファイルシステム（コンテナ相当）
# 階層型名前空間が有効な場合のエンドポイント
# -------------------------------------------------------------
resource "azurerm_storage_data_lake_gen2_filesystem" "datalake" {
  name               = "datalake"
  storage_account_id = azurerm_storage_account.datalake.id
}

# -------------------------------------------------------------
# Data Lake ディレクトリ構造
# メダリオンアーキテクチャ（Bronze / Silver / Gold）+ logs + metadata
# -------------------------------------------------------------
locals {
  lake_directories = ["bronze", "silver", "gold", "logs", "metadata"]
}

resource "azurerm_storage_data_lake_gen2_path" "directories" {
  for_each = toset(local.lake_directories)

  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.datalake.name
  storage_account_id = azurerm_storage_account.datalake.id
  resource           = "directory"
}

# -------------------------------------------------------------
# ライフサイクルポリシー
#   1. bronze/silver/gold: 5年（1825日）後にアーカイブ層へ移行
#   2. logs: 1年（365日）後に削除
# -------------------------------------------------------------
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.datalake.id

  # ルール1: データ層（bronze/silver/gold）を5年後にアーカイブへ
  rule {
    name    = "archive-after-5years"
    enabled = true

    filters {
      prefix_match = [
        "datalake/bronze/",
        "datalake/silver/",
        "datalake/gold/"
      ]
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 1825 # 5年
      }
    }
  }

  # ルール2: ログファイルを1年後に削除
  rule {
    name    = "delete-logs-after-1year"
    enabled = true

    filters {
      prefix_match = ["datalake/logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 365 # 1年
      }
    }
  }
}
