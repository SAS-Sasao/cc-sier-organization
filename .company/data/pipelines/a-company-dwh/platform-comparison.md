# DWHプラットフォーム比較・推奨書

## 文書情報

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-03-18 |
| 対象案件 | A社基幹システムDWH構築 |
| クライアント | A社（製造業・中堅企業） |
| 作成者 | クラウドエンジニア |
| ステータス | 初版ドラフト |

---

## 1. 評価候補

以下の3候補を比較検討する。

1. **Azure Synapse Analytics** - Microsoftのクラウドネイティブ統合分析サービス
2. **Databricks (on Azure)** - Apache Spark基盤のデータプラットフォーム
3. **Snowflake (on Azure)** - クラウドネイティブDWH（マルチクラウド対応）

---

## 2. 比較表

### 2-1. コスト（月額概算: 小規模DWH想定）

想定規模の前提:
- データ量: 累積50GB（5年保持）、月次増分 500MB 程度
- クエリ頻度: 日次バッチ + BI参照（同時接続10ユーザー以下）
- パイプライン: ADF経由での日次取り込み

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| 計算コスト | 専用プール: 約 ¥30,000〜50,000/月（DW100c、使用時のみ起動可）<br>サーバーレスプール: 従量課金（TB処理あたり約 ¥500） | DBU消費ベース: 約 ¥20,000〜40,000/月（Standard Tier、使用時のみ） | クレジットベース: 約 ¥15,000〜30,000/月（XS倉庫、1クレジット≒$3） |
| ストレージコスト | Azure Blob/ADLS Gen2: 約 ¥500〜1,000/月（50GB） | Azure Blob/ADLS Gen2: 約 ¥500〜1,000/月（50GB） | Snowflake内ストレージ: 約 ¥1,500〜2,000/月（圧縮後想定） |
| ライセンス・固定費 | なし（消費ベース） | Databricks Platform費用あり（Premium: DBUの40%追加） | なし（消費ベース）、ただし最低利用推奨あり |
| 月額概算合計 | **¥31,000〜51,000** | **¥25,000〜50,000** | **¥17,000〜32,000** |
| コスト予測性 | 中（専用プール固定 or サーバーレス従量の選択） | 低（DBU消費量が変動しやすい） | 高（クレジット消費が把握しやすい） |
| 備考 | ADF, Power BI が同一Azure課金で管理しやすい | AutoScaleにより不用意にコスト増加する可能性 | 円安時は割高感あり（USD建て） |

### 2-2. SharePoint Online 連携の容易さ

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| 公式コネクタ | Azure Data Factory のSPO コネクタを利用（Synapse Pipeline内に統合済み） | ADF経由 or カスタムPythonコード（Graph API呼び出し） | ADF経由 or カスタムコネクタ（Snowflake Connector for Python） |
| 認証方式 | サービスプリンシパル認証をADFが標準サポート | Databricks Secrets でサービスプリンシパルを管理、手動実装要 | 同左（ADF経由の場合はADF側で吸収） |
| 実装コスト | 低（ADFコネクタで設定ベース実装可） | 中〜高（Spark DataFrameへの取り込みに追加コード要） | 中（ADFのSPOコネクタ → Snowflake Sink は標準対応） |
| 評価 | ★★★★★ | ★★★ | ★★★★ |

### 2-3. dbt 連携の成熟度

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| 公式アダプタ | dbt-synapse（dbt Labs公式サポート） | dbt-databricks（dbt Labs公式、Lakehouseモデル完全対応） | dbt-snowflake（dbt Labsのリファレンス実装、最も成熟） |
| dbt Cloudサポート | 対応（dbt Cloud managed） | 対応（dbt Cloud managed） | 対応（dbt Cloud native、推奨構成） |
| サポート品質 | ドキュメント充実、ただしSynapseはQueries制約あり（一部SQL文法差異） | Spark SQLとdbt SQLの差異が一部あり、学習コスト中程度 | ドキュメント・サンプル最豊富、SQL互換性最高 |
| Incremental model 対応 | merge/insert_overwrite 対応（専用プールは制約あり） | merge/insert_overwrite 完全対応 | merge/unique_key 完全対応、最も安定 |
| 評価 | ★★★★ | ★★★★ | ★★★★★ |

### 2-4. Power BI 連携の容易さ

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| 公式コネクタ | Power BI Desktop/Service に標準内蔵（Azure Synapse コネクタ） | Power BI コネクタあり（Partner Certified） | Power BI コネクタあり（Certified） |
| DirectQuery対応 | 完全対応（専用プール推奨） | 対応（Databricks SQL Endpoint経由） | 対応（DirectQuery + Import 両対応） |
| パフォーマンス | 専用プールで高速（最適化された列ストアインデックス） | Databricks SQL Warehouse で良好 | 中〜良好（ウェアハウスサイズに依存） |
| 認証統合 | Azure AD統合（シームレスなSSO） | Azure AD + Databricks個別認証（二重管理の懸念） | Entra ID（Azure AD）SAML連携対応 |
| Azure環境との統合度 | ★★★★★（同一テナント内でシームレス） | ★★★★ | ★★★★ |
| 評価 | ★★★★★ | ★★★★ | ★★★★ |

### 2-5. Terraform 対応状況

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| Terraform Provider | azurerm（HashiCorp公式） | databricks（Databricks公式、terraform-provider-databricks） | snowflake（Snowflake公式、terraform-provider-snowflake） |
| リソース網羅性 | 高（Synapse Workspace, SQL Pool, Spark Pool, Linked Service等 azurermで一元管理） | 高（Cluster, Job, Notebook, Secret Scope等 Databricks固有リソースを網羅） | 中〜高（Database, Schema, Table, Warehouse, Role等対応、一部制限あり） |
| 主要インフラの単一Provider管理 | 可能（全てazurerm） | 要二Provider管理（azurerm + databricks） | 要二Provider管理（azurerm + snowflake） |
| State管理の複雑さ | 低（単一Provider） | 中（二Provider、クロス参照要） | 中（二Provider、クロス参照要） |
| 評価 | ★★★★★ | ★★★★ | ★★★★ |

### 2-6. 運用・管理の容易さ（中堅企業・少人数チーム）

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| 学習コスト | 中（Azure Portal操作が中心、Sparkも使えるが必須ではない） | 高（Spark, Delta Lake, Notebookの習熟が必要） | 低〜中（標準SQL中心、学習曲線がなだらか） |
| 管理コンソール | Azure Portal統合（使い慣れたUIで一元管理） | Databricks独自UI（高機能だが複雑） | Snowflake独自UI（シンプルで直感的） |
| パッチ・バージョン管理 | AzureによるフルマネージドPaaS | Databricks Runtimeのバージョン管理が必要 | Snowflakeによるフルマネージド（バージョン管理不要） |
| 監視・アラート | Azure Monitor, Log Analytics 統合（Azure native） | Azure Monitor + Databricks固有ログ（二元管理） | Snowflake固有の監視 + Azure Monitor連携（要設定） |
| バックアップ・DR | Azure標準の地理冗長ストレージで対応 | ADLS Gen2の冗長性に依存 | Snowflake標準でクロスリージョンレプリケーション対応 |
| 少人数チーム適合性 | ★★★★ | ★★★ | ★★★★★ |
| 評価 | ★★★★ | ★★★ | ★★★★★ |

### 2-7. スケーラビリティ

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| コンピュート拡張 | 専用プール: DWUスケールアップ（手動/自動）、サーバーレス: 自動 | AutoScale（クラスタの自動拡縮） | マルチクラスタウェアハウス（自動スケールアウト） |
| データ量拡張 | ADLS Gen2のスケールに追随（実質無制限） | ADLS Gen2のスケールに追随 | Snowflakeストレージの自動拡張（実質無制限） |
| コンカレンシー | 専用プール: ウェアハウスの性能依存、サーバーレス: 高コンカレンシー対応 | Databricks SQL Warehouse: 高コンカレンシー対応 | マルチクラスタで高コンカレンシー自動対応（最優秀） |
| 将来の大規模化 | 良好（DWUを上げるだけ） | 最良（Spark基盤でPBスケールも対応） | 良好（マルチクラスタで対応、ただしコスト増） |
| 評価 | ★★★★ | ★★★★★ | ★★★★ |

### 2-8. Azure主体環境との親和性

| 項目 | Azure Synapse Analytics | Databricks (on Azure) | Snowflake (on Azure) |
|------|------------------------|----------------------|----------------------|
| Azure AD / Entra ID 統合 | ネイティブ統合（シームレスなSSO/RBAC） | 統合対応（設定必要） | SAML/SCIM連携（設定必要） |
| Azure Monitor 統合 | ネイティブ（Diagnostic Settings 標準対応） | Azure Monitor連携（カスタム設定要） | 制限あり（ログエクスポートで対応） |
| Azure Key Vault 統合 | ネイティブ対応 | シークレットスコープ経由で対応 | 外部トークンサービス経由で対応 |
| Private Endpoint対応 | 完全対応（Synapse Managed Private Endpoint） | 対応（Azure Private Link） | 対応（Azure Private Link、要設定） |
| Azure Cost Management | Azure課金として一元管理 | Azure課金に含まれるが内訳複雑 | 別途Snowflake課金（Azure Marketplaceで統合可能） |
| 評価 | ★★★★★ | ★★★★ | ★★★ |

---

## 3. 総合評価マトリクス

各観点を重み付けして総合スコアを算出する。
重み: コスト(20%), SPO連携(15%), dbt(15%), PowerBI(15%), Terraform(10%), 運用(15%), スケーラビリティ(5%), Azure親和性(5%)

| 評価観点 | 重み | Azure Synapse | Databricks | Snowflake |
|----------|------|:------------:|:----------:|:---------:|
| コスト | 20% | 3 | 3 | 5 |
| SPO連携 | 15% | 5 | 3 | 4 |
| dbt連携 | 15% | 4 | 4 | 5 |
| Power BI連携 | 15% | 5 | 4 | 4 |
| Terraform | 10% | 5 | 4 | 4 |
| 運用容易性 | 15% | 4 | 3 | 5 |
| スケーラビリティ | 5% | 4 | 5 | 4 |
| Azure親和性 | 5% | 5 | 4 | 3 |
| **加重合計** | 100% | **4.25** | **3.60** | **4.55** |

※スコアは5点満点

---

## 4. 最終推奨

### 推奨: **Azure Synapse Analytics**

総合スコアでは Snowflake がわずかに上回るが、A社の制約・要件を総合的に判断すると **Azure Synapse Analytics** を推奨する。

### 推奨理由

**1. Azure主体環境との一体性**
A社はAzure主体での構成を前提としており、SharePoint Online、Azure Data Factory、Power BI がすでに同一テナント内で稼働している（または稼働予定）。Azure Synapse は同一 Azure テナント内でネイティブに統合されており、Azure AD によるアクセス管理、Azure Monitor による監視、Azure Key Vault によるシークレット管理を追加設定なしで利用できる。Snowflake の場合は別途課金管理・認証設定・監視連携が必要になり、少人数チームには管理コストとなる。

**2. SharePoint Online 連携の最優秀性**
Azure Data Factory の SharePoint Online コネクタは Microsoft 製品同士の公式対応であり、Graph API 認証、差分取り込み、スケジューリングをコード不要で設定できる。Synapse Pipeline（ADF互換）として Synapse Workspace 内に統合できるため、パイプラインの一元管理が可能。

**3. Power BI 連携のシームレス性**
Power BI Service と Azure Synapse は同一 Azure テナント内での DirectQuery が最も安定して動作する。認証が Azure AD で統一されるため、Power BI Dataset の設定・更新に際してユーザーが追加の認証情報を管理する必要がない。

**4. Terraform の単一 Provider 管理**
azurerm Provider のみで全インフラを管理できるため、State ファイル管理・クロス参照の複雑さが生じない。Snowflake/Databricks は専用 Provider を追加する必要があり、少人数チームの IaC 管理コストが増加する。

**5. コスト**
Synapse Analytics のサーバーレス SQL プールは、クエリ実行量に対する従量課金であり、小規模 DWH では月数千円〜1万円台での運用が現実的。Power BI や ADF が既に Azure 課金に含まれる場合、追加コストを最小化できる。

### Snowflake を選ぶべきケース（参考）

以下に該当する場合は Snowflake を再検討することを推奨する。

- マルチクラウド展開（Azure + AWS + GCP）が将来的に決定している場合
- dbt Cloud を中心にしたデータ変換ワークフローを構築したい場合
- 高コンカレンシー（BI 同時接続が50ユーザー超）が想定される場合
- 標準 SQL スキルしかないメンバーで運用する場合

---

## 5. 推奨アーキテクチャ概要

```
SharePoint Online
      |
      | Graph API (サービスプリンシパル認証)
      v
Azure Data Factory（Synapse Pipeline）
      |
      v
Azure Data Lake Storage Gen2
  ├── bronze/   ← 生データ (Parquet)
  ├── silver/   ← 整形済みデータ (Delta format)
  └── gold/     ← BI用集計データ
      |
      v
Azure Synapse Analytics
  ├── Serverless SQL Pool（dbt変換・探索クエリ）
  └── Dedicated SQL Pool（Power BI DirectQuery用、必要に応じて）
      |
      v
Power BI Service（DirectQuery / Import）
```

---

## 6. 付帯事項

### セキュリティ考慮
- 個人情報（担当者氏名）のマスキングは Synapse View または dbt モデル内の `sha2()` / `md5()` 関数で対応
- ADLS Gen2 は階層型名前空間（HNS）を有効化し、POSIX ACL でアクセス制御
- Synapse Workspace には Managed Private Endpoint を設定し、パブリックアクセスを遮断

### データ保持
- ADLS Gen2 のライフサイクルポリシーで5年（1825日）後に自動アーカイブ（Archive Tier）または削除

### 移行リスク
- Azure Synapse Analytics の専用 SQL プールは T-SQL ベースだが、一部 SQL 構文の制限（例: `MERGE` 文の制約）があるため、dbt モデル作成時に留意が必要
- サーバーレス SQL プールを主用途とする場合は上記制約が緩和される
