# IaC設計: A社DWH構築 Terraform実装

## 文書情報

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-03-18 |
| 対象案件 | A社基幹システムDWH構築 |
| 実装場所 | `terraform/` |
| Provider | azurerm ~> 3.90 |
| ステータス | 実装完了 |

---

## ファイル構成

```
terraform/
├── versions.tf                        ← required_providers 宣言
├── modules/
│   ├── networking/                    ← VNet / NSG / Private Endpoint / Private DNS Zone
│   ├── storage/                       ← ADLS Gen2 / ファイルシステム / ライフサイクルポリシー
│   ├── key_vault/                     ← Key Vault / アクセスポリシー / シークレット
│   ├── data_factory/                  ← ADF / Linked Services / IR / トリガー
│   ├── synapse/                       ← Synapse Workspace / RBAC / Managed PE
│   └── monitoring/                    ← Log Analytics / Action Group / アラートルール
└── environments/
    ├── dev/  (main / variables / tfvars / backend / outputs)
    ├── stg/  (main / variables / tfvars / backend / outputs)
    └── prod/ (main / variables / tfvars / backend / outputs)
```

---

## 環境差異サマリー

| 設定項目 | dev | stg | prod |
|---------|-----|-----|------|
| ストレージ冗長 | LRS | LRS | ZRS |
| ADF トリガー | 無効 | 有効（週次相当） | 有効（日次 02:00 JST） |
| ログ保持 | 30 日 | 60 日 | 90 日 |
| パブリックアクセス | 許可（開発用） | 制限 | 禁止 |
| RG 削除保護 | なし | あり | あり |
| VNet アドレス空間 | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| State キー | a-company-dwh/dev/terraform.tfstate | a-company-dwh/stg/terraform.tfstate | a-company-dwh/prod/terraform.tfstate |

---

## 循環参照対策

### 問題1: Key Vault ↔ ADF/Synapse
- Key Vault アクセスポリシーが ADF/Synapse の Managed Identity ID を必要とする
- ADF/Synapse は Key Vault ID を Linked Service 設定に必要とする
- **解決策**: 初回 apply で ADF/Synapse を先に作成し、2回目 apply でアクセスポリシーを追加する2フェーズデプロイ

### 問題2: Synapse パスワード ↔ Key Vault
- Synapse 作成時に SQL 管理者パスワードが必要
- パスワードは Key Vault に保存したい
- **解決策**: `random_password` リソースでパスワードを生成し、Key Vault と Synapse の両方に渡す

### 問題3: monitoring ↔ data_factory
- monitoring モジュールが ADF のアラートルールを作成するために data_factory_id が必要
- data_factory モジュールが Log Analytics workspace_id を Diagnostic Settings に必要とする
- **解決策**: monitoring モジュールへの data_factory_id 渡しをやめ、prod/main.tf に ADF アラートリソースを直接定義

---

## デプロイ手順

### 初回デプロイ（3ステップ）

```bash
# ステップ1: State 管理ストレージを手動作成（初回のみ）
az group create --name rg-terraform-state --location japaneast
az storage account create --name stadwhtfstate \
  --resource-group rg-terraform-state --location japaneast \
  --sku Standard_GRS --min-tls-version TLS1_2
az storage container create --name tfstate --account-name stadwhtfstate

# ステップ2: 対象環境ディレクトリに移動して初回 apply
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# ステップ3: Key Vault アクセスポリシーを追加（2回目 apply）
# environments/dev/main.tf の key_vault モジュール呼び出しを更新:
#   adf_principal_id     = module.data_factory.managed_identity_principal_id
#   synapse_principal_id = module.synapse.managed_identity_principal_id
terraform apply
```

### terraform.tfvars に設定が必要な値

| 変数 | 設定タイミング | 注意 |
|------|------------|------|
| `ops_object_ids` | 初回 apply 前 | 運用者の Azure AD オブジェクト ID |
| `allowed_ip_addresses` | 初回 apply 前 | 運用端末の IP アドレス |
| `teams_webhook_url` | 任意 | CI/CD 環境変数 TF_VAR_teams_webhook_url 推奨 |
| `alert_email_addresses` | 任意 | CI/CD 環境変数 TF_VAR_alert_email_addresses 推奨 |

---

## セキュリティ設計ポイント

| 観点 | 実装内容 |
|------|---------|
| TLS 強制 | 全ストレージで `min_tls_version = "TLS1_2"` |
| 公開アクセス禁止 | `allow_nested_items_to_be_public = false` |
| Managed Identity 優先 | ADF/Synapse → ADLS は Managed Identity + RBAC |
| シークレット外部化 | Key Vault 格納。Terraform コードに直書き禁止 |
| State 保護 | Azure Blob GRS + バージョニング + Blob Lease ロック |
| prod 誤操作防止 | `prevent_deletion_if_contains_resources = true` |
| ネットワーク隔離 | Private Endpoint + Private DNS Zone（prod 必須） |
| 監査ログ | Diagnostic Settings → Log Analytics（全サービス） |
