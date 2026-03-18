# Terraform構成案

## 文書情報

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-03-18 |
| 対象案件 | A社基幹システムDWH構築 |
| クライアント | A社（製造業・中堅企業） |
| DWHプラットフォーム | Azure Synapse Analytics |
| Terraform Provider | azurerm ~> 3.x |
| 作成者 | クラウドエンジニア |
| ステータス | 初版ドラフト |

---

## 1. Terraform モジュール構成案

```
terraform/
├── environments/               ← 環境別エントリーポイント
│   ├── dev/
│   │   ├── main.tf             ← dev 環境のモジュール呼び出し
│   │   ├── variables.tf
│   │   ├── terraform.tfvars    ← dev 固有変数値（機密情報は除く）
│   │   └── backend.tf          ← Azure Blob Storage バックエンド設定
│   ├── stg/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
│
└── modules/                    ← 再利用可能モジュール
    ├── networking/             ← 仮想ネットワーク・Private Endpoint
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── storage/                ← ADLS Gen2（Data Lake）
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── key_vault/              ← Azure Key Vault
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── data_factory/           ← Azure Data Factory
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── synapse/                ← Azure Synapse Analytics
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── monitoring/             ← Azure Monitor・Log Analytics
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 2. 主要リソース一覧

### 2-1. リソースグループ

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| リソースグループ | `azurerm_resource_group` | 全リソースのコンテナ。環境ごとに分離 |

### 2-2. networking モジュール

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| 仮想ネットワーク | `azurerm_virtual_network` | DWH基盤の閉域ネットワーク |
| サブネット（ADF） | `azurerm_subnet` | ADF Managed IR 用サブネット |
| サブネット（Synapse） | `azurerm_subnet` | Synapse 用サブネット |
| Private Endpoint（ADLS） | `azurerm_private_endpoint` | ADLS Gen2 へのプライベートアクセス |
| Private Endpoint（Synapse） | `azurerm_private_endpoint` | Synapse SQL へのプライベートアクセス |
| Private Endpoint（Key Vault） | `azurerm_private_endpoint` | Key Vault へのプライベートアクセス |
| Private DNS Zone | `azurerm_private_dns_zone` | 各サービスの DNS 解決（blob, dfs, vaultcore等） |
| NSG | `azurerm_network_security_group` | 各サブネットのトラフィック制御 |

### 2-3. storage モジュール

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| ストレージアカウント | `azurerm_storage_account` | ADLS Gen2（`is_hns_enabled = true`） |
| コンテナ（datalake） | `azurerm_storage_data_lake_gen2_filesystem` | Data Lake ファイルシステム |
| ディレクトリ（bronze） | `azurerm_storage_data_lake_gen2_path` | Bronze 層パス |
| ディレクトリ（silver） | `azurerm_storage_data_lake_gen2_path` | Silver 層パス |
| ディレクトリ（gold） | `azurerm_storage_data_lake_gen2_path` | Gold 層パス |
| ディレクトリ（logs） | `azurerm_storage_data_lake_gen2_path` | ログ出力パス |
| ライフサイクルポリシー | `azurerm_storage_management_policy` | 5年後にアーカイブ層へ移動 |

### 2-4. key_vault モジュール

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| Key Vault | `azurerm_key_vault` | シークレット一元管理（soft_delete_retention_days = 90） |
| シークレット（SPO Client Secret） | `azurerm_key_vault_secret` | Graph API 認証用クライアントシークレット |
| シークレット（Synapse Admin PW） | `azurerm_key_vault_secret` | Synapse SQL Admin パスワード |
| アクセスポリシー（ADF Managed Identity） | `azurerm_key_vault_access_policy` | ADF が Secret を読み取る権限 |
| アクセスポリシー（Synapse Managed Identity） | `azurerm_key_vault_access_policy` | Synapse が Secret を読み取る権限 |
| アクセスポリシー（運用者） | `azurerm_key_vault_access_policy` | 運用チームの管理権限 |

### 2-5. data_factory モジュール

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| Data Factory | `azurerm_data_factory` | パイプラインのオーケストレーションエンジン |
| Linked Service（ADLS） | `azurerm_data_factory_linked_service_data_lake_storage_gen2` | ADLS Gen2 接続（Managed Identity 認証） |
| Linked Service（Key Vault） | `azurerm_data_factory_linked_service_key_vault` | Key Vault 接続（Managed Identity 認証） |
| Linked Service（HTTP/Graph API） | `azurerm_data_factory_linked_service_web` | Graph API 接続（Bearer Token） |
| Integration Runtime（Auto-Resolve） | `azurerm_data_factory_integration_runtime_azure` | ADF のコンピュートリソース |
| トリガー（スケジュール） | `azurerm_data_factory_trigger_schedule` | 毎日 02:00 JST 起動 |
| Diagnostic Setting | `azurerm_monitor_diagnostic_setting` | ADF ログ → Log Analytics |

### 2-6. synapse モジュール

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| Synapse Workspace | `azurerm_synapse_workspace` | Synapse 統合環境（ADLS Gen2 と紐付け） |
| Serverless SQL Pool（組み込み） | ※ Workspace 作成時に自動作成 | dbt 変換・アドホッククエリ |
| Dedicated SQL Pool（オプション） | `azurerm_synapse_sql_pool` | Power BI DirectQuery 用（必要時のみ作成） |
| Managed Private Endpoint（ADLS） | `azurerm_synapse_managed_private_endpoint` | Synapse → ADLS のプライベート接続 |
| Managed Private Endpoint（Key Vault） | `azurerm_synapse_managed_private_endpoint` | Synapse → Key Vault のプライベート接続 |
| Firewall Rule（許可IP） | `azurerm_synapse_firewall_rule` | 運用端末のIPのみ許可（パブリックアクセス制限） |
| Role Assignment（Storage Blob Data Contributor） | `azurerm_role_assignment` | Synapse Managed Identity に ADLS 書込み権限 |
| Role Assignment（Storage Blob Data Reader） | `azurerm_role_assignment` | ADF Managed Identity に ADLS 読込み権限 |
| Diagnostic Setting | `azurerm_monitor_diagnostic_setting` | Synapse ログ → Log Analytics |

### 2-7. monitoring モジュール

| リソース | Terraform リソース型 | 説明 |
|---------|---------------------|------|
| Log Analytics Workspace | `azurerm_log_analytics_workspace` | 全サービスのログ集約 |
| Monitor Action Group（Teams） | `azurerm_monitor_action_group` | Teams Webhook 通知 |
| Monitor Action Group（Email） | `azurerm_monitor_action_group` | メール通知（管理者） |
| アラートルール（Pipeline失敗） | `azurerm_monitor_metric_alert` | ADF パイプライン失敗時アラート |
| アラートルール（ADLS容量） | `azurerm_monitor_metric_alert` | ストレージ使用率 80% 超過アラート |
| Monitor Workbook | `azurerm_application_insights_workbook` | 運用ダッシュボード |

---

## 3. 環境分離戦略（dev / stg / prod）

### 3-1. 環境の役割定義

| 環境 | 役割 | データ | アクセス制限 | コスト最適化 |
|------|------|--------|------------|------------|
| dev | 開発・動作確認 | サンプルデータ（本番の 1/100 程度） | 開発者のみ | Dedicated Pool は起動しない。ADF パイプラインの手動実行のみ |
| stg | 結合テスト・本番前検証 | 本番データの匿名化コピー（直近1ヶ月分） | 開発者 + QA | 週次スケジュール実行（コスト削減） |
| prod | 本番稼働 | 全量データ（5年保持） | 運用者 + Power BI Service のみ | 日次バッチ最適化（不要な常時起動なし） |

### 3-2. 環境間の差異管理

環境固有の差異は `terraform.tfvars` で管理し、モジュールコードは共通化する。

```hcl
# environments/dev/terraform.tfvars
environment         = "dev"
location            = "japaneast"
resource_group_name = "rg-a-company-dwh-dev"

# ADLS設定
storage_account_name        = "stadwhacompanydev"
storage_replication_type    = "LRS"      # dev は LRS（安価）

# Synapse設定
synapse_workspace_name      = "synw-a-company-dwh-dev"
enable_dedicated_sql_pool   = false      # dev は無効

# ADF設定
data_factory_name           = "adf-a-company-dwh-dev"
adf_trigger_enabled         = false      # dev はスケジュールトリガー無効

# Key Vault設定
key_vault_name              = "kv-a-company-dwh-dev"
key_vault_sku               = "standard"

# Log Analytics設定
log_analytics_workspace_name = "law-a-company-dwh-dev"
log_retention_days           = 30        # dev は30日保持

# タグ設定
tags = {
  Environment = "dev"
  Project     = "a-company-dwh"
  Owner       = "data-team"
  CostCenter  = "CC-DWH-001"
}
```

```hcl
# environments/prod/terraform.tfvars
environment         = "prod"
location            = "japaneast"
resource_group_name = "rg-a-company-dwh-prod"

# ADLS設定
storage_account_name        = "stadwhacompanyprod"
storage_replication_type    = "ZRS"      # prod は ZRS（ゾーン冗長）

# Synapse設定
synapse_workspace_name      = "synw-a-company-dwh-prod"
enable_dedicated_sql_pool   = false      # 当初はサーバーレスのみ（コスト最適化）

# ADF設定
data_factory_name           = "adf-a-company-dwh-prod"
adf_trigger_enabled         = true       # prod はスケジュールトリガー有効

# Key Vault設定
key_vault_name              = "kv-a-company-dwh-prod"
key_vault_sku               = "standard"

# Log Analytics設定
log_analytics_workspace_name = "law-a-company-dwh-prod"
log_retention_days           = 90        # prod は90日保持（コンプライアンス）

# タグ設定
tags = {
  Environment = "prod"
  Project     = "a-company-dwh"
  Owner       = "data-team"
  CostCenter  = "CC-DWH-001"
}
```

### 3-3. 環境ごとのリソース命名規則

```
命名規則: {リソース略称}-{プロジェクト略称}-{環境}

例:
  rg-a-company-dwh-dev          # リソースグループ
  vnet-a-company-dwh-prod       # 仮想ネットワーク
  stadwhacompanyprod            # ストレージ（アルファベット・数字のみ）
  adf-a-company-dwh-stg         # Data Factory
  synw-a-company-dwh-prod       # Synapse Workspace
  kv-a-company-dwh-dev          # Key Vault
  law-a-company-dwh-prod        # Log Analytics Workspace
```

---

## 4. 状態管理（Backend 設定）

### 4-1. Remote Backend: Azure Blob Storage

Terraform State を Azure Blob Storage で一元管理する。
State ファイルは環境ごとに分離し、誤操作による prod State の上書きを防ぐ。

**State 管理用ストレージアカウント構成:**

```
ストレージアカウント: stadwhtfstate（管理専用、全環境共通）
コンテナ: tfstate
  └── a-company-dwh/
      ├── dev/terraform.tfstate
      ├── stg/terraform.tfstate
      └── prod/terraform.tfstate
```

### 4-2. Backend 設定ファイル

```hcl
# environments/prod/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stadwhtfstate"
    container_name       = "tfstate"
    key                  = "a-company-dwh/prod/terraform.tfstate"

    # State ファイルの暗号化（Azure Storage の CMK または Microsoft Managed Key）
    use_oidc = true  # GitHub Actions OIDC 認証を使用（CI/CD時）
  }
}
```

```hcl
# environments/dev/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stadwhtfstate"
    container_name       = "tfstate"
    key                  = "a-company-dwh/dev/terraform.tfstate"
    use_oidc = true
  }
}
```

### 4-3. State ロック

Azure Blob Storage の Blob Lease 機能を利用して、複数人の同時 `terraform apply` を防ぐ。
azurerm バックエンドはデフォルトでロックが有効。

```
State ロックの動作:
  terraform apply 開始 → Blob Lease 取得（60秒更新）
  terraform apply 完了 → Blob Lease 解放
  別の apply 試行   → Blob Lease 取得失敗 → エラー表示（誰がロック中かを表示）
```

### 4-4. State ファイルのセキュリティ

State ファイルにはシークレット値が含まれる可能性があるため、以下のセキュリティ設定を適用する。

```hcl
# State 用ストレージアカウントのセキュリティ設定（別途管理）
resource "azurerm_storage_account" "tfstate" {
  name                     = "stadwhtfstate"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = "japaneast"
  account_tier             = "Standard"
  account_replication_type = "GRS"  # State は geo 冗長（誤削除対策）

  # セキュリティ設定
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true

  # バージョニング有効（State 誤削除時の復元用）
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}
```

---

## 5. コードサンプル（主要モジュール）

### 5-1. synapse モジュール（`modules/synapse/main.tf`）

```hcl
# modules/synapse/main.tf

resource "azurerm_synapse_workspace" "main" {
  name                                 = var.workspace_name
  resource_group_name                  = var.resource_group_name
  location                             = var.location
  storage_data_lake_gen2_filesystem_id = var.adls_filesystem_id
  sql_administrator_login              = "synapse_admin"
  sql_administrator_login_password     = var.sql_admin_password  # Key Vault 参照

  # Managed Virtual Network を有効化（プライベートネットワーク強制）
  managed_virtual_network_enabled = true

  # Managed Identity（ADLS アクセスに使用）
  identity {
    type = "SystemAssigned"
  }

  # パブリックネットワークアクセス制限
  public_network_access_enabled = false

  tags = var.tags
}

# Synapse に ADLS へのアクセス権付与
resource "azurerm_role_assignment" "synapse_adls_contributor" {
  scope                = var.adls_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.main.identity[0].principal_id
}

# Managed Private Endpoint（ADLS への接続）
resource "azurerm_synapse_managed_private_endpoint" "adls_dfs" {
  name                 = "pe-adls-dfs"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  target_resource_id   = var.adls_storage_account_id
  subresource_name     = "dfs"
}

# Firewall Rule（運用端末のIP許可）
resource "azurerm_synapse_firewall_rule" "ops_ip" {
  for_each             = toset(var.allowed_ip_addresses)
  name                 = "allow-ops-${replace(each.value, ".", "-")}"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  start_ip_address     = each.value
  end_ip_address       = each.value
}

# Diagnostic Settings（Azure Monitor へのログ出力）
resource "azurerm_monitor_diagnostic_setting" "synapse" {
  name                       = "diag-synapse"
  target_resource_id         = azurerm_synapse_workspace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SynapseRbacOperations"
  }
  enabled_log {
    category = "GatewayApiRequests"
  }
  enabled_log {
    category = "SQLSecurityAuditEvents"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
```

### 5-2. storage モジュール（`modules/storage/main.tf`）

```hcl
# modules/storage/main.tf

resource "azurerm_storage_account" "datalake" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type  # dev=LRS, prod=ZRS

  # ADLS Gen2 有効化
  is_hns_enabled = true

  # セキュリティ設定
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  enable_https_traffic_only       = true

  # Azure AD 認証を優先（共有キーアクセスは将来的に無効化を検討）
  shared_access_key_enabled = true  # ADF Linked Service 互換性のため当面有効

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Data Lake ファイルシステム（階層型名前空間）
resource "azurerm_storage_data_lake_gen2_filesystem" "datalake" {
  name               = "datalake"
  storage_account_id = azurerm_storage_account.datalake.id
}

# 各層ディレクトリの作成
locals {
  lake_directories = ["bronze", "silver", "gold", "logs", "metadata"]
}

resource "azurerm_storage_data_lake_gen2_path" "directories" {
  for_each           = toset(local.lake_directories)
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.datalake.name
  storage_account_id = azurerm_storage_account.datalake.id
  resource           = "directory"
}

# ライフサイクルポリシー（5年後にアーカイブ層へ）
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.datalake.id

  rule {
    name    = "archive-after-5years"
    enabled = true

    filters {
      prefix_match = ["datalake/bronze/", "datalake/silver/", "datalake/gold/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 1825  # 5年
      }
    }
  }

  rule {
    name    = "delete-logs-after-1year"
    enabled = true

    filters {
      prefix_match = ["datalake/logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 365  # 1年
      }
    }
  }
}
```

### 5-3. environments/prod/main.tf（モジュール呼び出し例）

```hcl
# environments/prod/main.tf

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false  # 誤削除防止
    }
    resource_group {
      prevent_deletion_if_contains_resources = true  # prod のリソースグループ誤削除防止
    }
  }
}

# リソースグループ
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# モジュール呼び出し
module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  tags                = var.tags
}

module "storage" {
  source               = "../../modules/storage"
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  storage_account_name = var.storage_account_name
  replication_type     = var.storage_replication_type
  tags                 = var.tags
}

module "key_vault" {
  source                  = "../../modules/key_vault"
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  key_vault_name          = var.key_vault_name
  tenant_id               = data.azurerm_client_config.current.tenant_id
  adf_principal_id        = module.data_factory.managed_identity_principal_id
  synapse_principal_id    = module.synapse.managed_identity_principal_id
  tags                    = var.tags
}

module "data_factory" {
  source                       = "../../modules/data_factory"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.location
  data_factory_name            = var.data_factory_name
  adls_storage_account_id      = module.storage.storage_account_id
  adls_filesystem_endpoint     = module.storage.filesystem_endpoint
  key_vault_id                 = module.key_vault.key_vault_id
  trigger_enabled              = var.adf_trigger_enabled
  log_analytics_workspace_id   = module.monitoring.workspace_id
  tags                         = var.tags
}

module "synapse" {
  source                       = "../../modules/synapse"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.location
  workspace_name               = var.synapse_workspace_name
  adls_filesystem_id           = module.storage.filesystem_id
  adls_storage_account_id      = module.storage.storage_account_id
  sql_admin_password           = module.key_vault.synapse_admin_password
  allowed_ip_addresses         = var.allowed_ip_addresses
  log_analytics_workspace_id   = module.monitoring.workspace_id
  tags                         = var.tags
}

module "monitoring" {
  source                    = "../../modules/monitoring"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = var.location
  workspace_name            = var.log_analytics_workspace_name
  log_retention_days        = var.log_retention_days
  teams_webhook_url         = var.teams_webhook_url
  alert_email_addresses     = var.alert_email_addresses
  data_factory_id           = module.data_factory.data_factory_id
  tags                      = var.tags
}

data "azurerm_client_config" "current" {}
```

---

## 6. CI/CD パイプライン連携（GitHub Actions 想定）

```yaml
# .github/workflows/terraform-deploy.yml（参考）

name: Terraform Deploy

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

permissions:
  id-token: write   # OIDC 認証用
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, stg, prod]

    steps:
      - uses: actions/checkout@v4

      - name: Azure Login（OIDC）
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.6.0"

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/${{ matrix.environment }}

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: terraform/environments/${{ matrix.environment }}

      # prod への apply は main ブランチのマージ時のみ
      - name: Terraform Apply（prod以外は自動）
        if: github.ref == 'refs/heads/main' && matrix.environment != 'prod'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/${{ matrix.environment }}

      - name: Terraform Apply（prod は手動承認）
        if: github.ref == 'refs/heads/main' && matrix.environment == 'prod'
        uses: trstringer/manual-approval@v1
        # → 承認後に apply 実行（Environments の protection rules で制御）
```

---

## 7. セキュリティ考慮事項

| 観点 | 対策 | Terraform リソース |
|------|------|-----------------|
| シークレット管理 | クライアントシークレット・パスワードを Key Vault に格納、コードに直書きしない | `azurerm_key_vault_secret` |
| State ファイル保護 | State 用ストレージに Blob バージョニング + GRS + アクセス制限 | `azurerm_storage_account` (versioning) |
| ネットワーク隔離 | Private Endpoint で全サービスをプライベートアクセスに限定 | `azurerm_private_endpoint` |
| 最小権限 | Managed Identity を使用し、必要最小限の RBAC ロールのみ付与 | `azurerm_role_assignment` |
| 個人情報保護 | dbt の匿名化マクロで担当者氏名をマスキング（Terraform 外の制御） | – |
| 監査ログ | 全サービスの Diagnostic Settings を Log Analytics に集約 | `azurerm_monitor_diagnostic_setting` |
| prod 誤操作防止 | `prevent_deletion_if_contains_resources = true` でリソースグループ誤削除防止 | provider `features` ブロック |
| TLS 強制 | `min_tls_version = "TLS1_2"` を全ストレージに適用 | `azurerm_storage_account` |
