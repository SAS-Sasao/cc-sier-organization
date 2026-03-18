# A社基幹システム DWH メダリオンアーキテクチャ設計書

| 項目 | 内容 |
|------|------|
| クライアント | A社（製造業・中堅企業） |
| バージョン | 1.0.0 |
| 作成日 | 2026-03-18 |
| ステータス | 初版 |
| 作成者 | データアーキテクト |

---

## 1. アーキテクチャ概要

### 1.1 全体構成図

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SharePoint Online                                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │
│  │ 見積管理     │ │ 案件管理     │ │ 顧客マスタ   │ │ 担当者マスタ │   │
│  │ リスト       │ │ リスト       │ │ リスト       │ │ リスト       │   │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘   │
└─────────┼────────────────┼────────────────┼────────────────┼───────────┘
          │                │                │                │
          ▼                ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   Azure Data Factory（日次バッチ）                       │
│                  SharePoint Online Connector                            │
│                  増分取り込み（更新日ベース）                              │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│   Bronze 層      │ │   Silver 層      │ │   Gold 層        │
│ (Raw Data)       │ │ (Cleansed)       │ │ (Analytics)      │
│                  │ │                  │ │                  │
│ Azure Data Lake  │ │ Azure Data Lake  │ │ Azure SQL DB /   │
│ Storage Gen2     │ │ Storage Gen2     │ │ Synapse          │
│                  │ │                  │ │                  │
│ Parquet形式      │ │ Delta Lake形式   │ │ Delta Lake /     │
│ (日付パーティ    │ │ (SCD Type 2      │ │ ビュー形式       │
│  ション)         │ │  対応)           │ │                  │
└──────────────────┘ └──────────────────┘ └──────────────────┘
          │                    │                    │
          │         dbt transform              Power BI
          │         (Silver→Gold)              (Gold層参照)
          │                    │                    │
          └────────────────────┘                    ▼
                                          ┌──────────────────┐
                                          │ Power BI         │
                                          │ ダッシュボード    │
                                          │                  │
                                          │ - 売上分析       │
                                          │ - 受注率トレンド │
                                          │ - パフォーマンス │
                                          │ - ファネル分析   │
                                          │ - 滞留分析       │
                                          └──────────────────┘
```

### 1.2 技術スタック

| レイヤー | 技術 | 用途 |
|----------|------|------|
| データ抽出 | Azure Data Factory | SharePoint Online からのデータ取り込み |
| データストレージ | Azure Data Lake Storage Gen2 | Bronze/Silver/Gold 各層の物理格納 |
| データ変換 | dbt (dbt-core + dbt-fabric) | Silver→Gold の変換ロジック |
| データウェアハウス | Azure Synapse Analytics (Serverless SQL Pool) | Gold層のクエリエンジン |
| BI | Power BI | ダッシュボード・レポーティング |
| オーケストレーション | Azure Data Factory | パイプライン制御・スケジューリング |
| メタデータ管理 | Microsoft Purview | データカタログ・リネージ |

### 1.3 設計原則

1. **イミュータビリティ**: Bronze層の生データは上書きしない。日付パーティションで追記
2. **シングルソースオブトゥルース**: 各エンティティの正規化定義は Silver層に1箇所のみ
3. **段階的品質向上**: 層を進むごとにデータ品質が向上する設計
4. **リネージ追跡可能性**: 全変換にリネージメタデータを付与
5. **コスト最適化**: Serverless SQL Pool で必要時のみコンピュートを消費

---

## 2. Bronze 層設計（生データ取り込み）

### 2.1 概要

Bronze層は SharePoint Online リストから取得した生データをそのまま格納する層。
ソースのスキーマ変更に耐えられるよう、取得時のJSON構造を保持しつつ Parquet に変換して格納する。

### 2.2 取り込み方式

| 項目 | 仕様 |
|------|------|
| トリガー | Azure Data Factory スケジュールトリガー（毎日 AM 5:00 JST） |
| 取り込み方式 | 増分取り込み（前回取り込み以降に更新されたレコード） |
| 増分検知キー | 各リストの `Modified`（更新日時）フィールド |
| ウォーターマーク管理 | ADF のウォーターマークテーブル（Azure SQL DB 上） |
| フォーマット | Parquet（Snappy圧縮） |
| パーティション | `_ingestion_date` による日付パーティション（yyyy/MM/dd） |

### 2.3 格納パス規則

```
abfss://bronze@{storage_account}.dfs.core.windows.net/
  └── sharepoint/
      ├── estimates/           ← 見積管理リスト
      │   └── _ingestion_date=2026-03-18/
      │       └── part-00000.parquet
      ├── projects/            ← 案件管理リスト
      │   └── _ingestion_date=2026-03-18/
      │       └── part-00000.parquet
      ├── customers/           ← 顧客マスタリスト
      │   └── _ingestion_date=2026-03-18/
      │       └── part-00000.parquet
      └── employees/           ← 担当者マスタリスト
          └── _ingestion_date=2026-03-18/
              └── part-00000.parquet
```

### 2.4 メタデータカラム

Bronze層の全テーブルに以下の監査カラムを付与する。

| カラム名 | 型 | 説明 |
|----------|----|------|
| `_source_system` | STRING | 固定値 `sharepoint_online` |
| `_source_list` | STRING | SharePoint リスト名 |
| `_ingestion_timestamp` | TIMESTAMP | 取り込み実行日時（UTC） |
| `_ingestion_date` | DATE | 取り込み日（パーティションキー） |
| `_adf_pipeline_run_id` | STRING | ADF パイプラン実行ID |
| `_raw_json` | STRING | ソースレコードのJSON文字列（スキーマ変更対応用） |

### 2.5 Bronze テーブル一覧

| テーブル名 | ソース | 主キー（ソース側） | 更新頻度 |
|------------|--------|-------------------|----------|
| `brz_estimates` | 見積管理リスト | 見積番号 | 日次 |
| `brz_projects` | 案件管理リスト | 案件番号 | 日次 |
| `brz_customers` | 顧客マスタリスト | 顧客コード | 日次 |
| `brz_employees` | 担当者マスタリスト | 社員番号 | 日次 |

---

## 3. Silver 層設計（クレンジング・正規化）

### 3.1 概要

Silver層は Bronze層の生データに対して以下の処理を適用し、分析に利用可能な品質まで引き上げた層。

- データ型の正規化（文字列→適切な型への変換）
- NULL処理・デフォルト値適用
- 重複排除（同一レコードの複数取り込み対応）
- ビジネスキーベースの一意性保証
- SCD Type 2（緩やかに変化するディメンション）対応

### 3.2 変換エンジン

| 項目 | 仕様 |
|------|------|
| 変換エンジン | dbt (dbt-core) |
| 実行環境 | Azure Data Factory 内の dbt Activity / Azure Container Instance |
| マテリアライゼーション | Delta Lake（incremental） |
| テスト | dbt tests（unique, not_null, accepted_values, relationships） |

### 3.3 共通変換ルール

#### 3.3.1 データ型変換

| ソース型（SharePoint） | ターゲット型（Silver） | 変換ルール |
|-----------------------|----------------------|------------|
| Single line of text | STRING | トリム処理。全角スペースも除去 |
| Number | DECIMAL(18,2) | NULL → 0.00 |
| Currency | DECIMAL(18,2) | 通貨記号除去。NULL → 0.00 |
| Date and Time | TIMESTAMP | ISO 8601 形式に統一。無効な日付 → NULL |
| Choice | STRING | 選択肢値の正規化（表記揺れ統一） |
| Person or Group | STRING | 表示名を抽出 |

#### 3.3.2 重複排除ルール

同一ビジネスキーで複数レコードが存在する場合、`Modified`（更新日時）が最新のレコードを採用する。

```sql
-- 重複排除のロジック（dbt model 内の共通パターン）
ROW_NUMBER() OVER (
    PARTITION BY business_key
    ORDER BY source_modified_at DESC
) = 1
```

#### 3.3.3 SCD Type 2 対応

顧客マスタ・担当者マスタは SCD Type 2 で履歴管理する。

| カラム名 | 型 | 説明 |
|----------|----|------|
| `_surrogate_key` | BIGINT | サロゲートキー（自動採番） |
| `_valid_from` | TIMESTAMP | 有効開始日時 |
| `_valid_to` | TIMESTAMP | 有効終了日時（現行レコードは `9999-12-31`） |
| `_is_current` | BOOLEAN | 現行フラグ |
| `_hash_diff` | STRING | 変更検知用ハッシュ（SHA-256） |

### 3.4 Silver テーブル一覧

| テーブル名 | ソース | SCD対応 | 主な変換 |
|------------|--------|---------|----------|
| `slv_estimates` | `brz_estimates` | Type 1 | 型変換、金額正規化、ステータス正規化 |
| `slv_projects` | `brz_projects` | Type 1 | 型変換、金額正規化、フェーズ正規化 |
| `slv_customers` | `brz_customers` | Type 2 | 型変換、業種コード標準化、SCD履歴管理 |
| `slv_employees` | `brz_employees` | Type 2 | 型変換、部署名正規化、SCD履歴管理 |

### 3.5 ステータス・フェーズ正規化マッピング

#### 見積ステータス

| ソース値（表記揺れ例） | 正規化後 | コード |
|------------------------|----------|--------|
| 作成中, 下書き, Draft | DRAFT | 10 |
| 提出済, 提出済み, Submitted | SUBMITTED | 20 |
| 検討中, 交渉中, Under Review | UNDER_REVIEW | 30 |
| 受注, 成約, Won | WON | 40 |
| 失注, 不成立, Lost | LOST | 50 |
| 取消, キャンセル, Cancelled | CANCELLED | 90 |

#### 案件フェーズ

| ソース値（表記揺れ例） | 正規化後 | コード |
|------------------------|----------|--------|
| 計画, Planning | PLANNING | 10 |
| 要件定義, Requirements | REQUIREMENTS | 20 |
| 設計, Design | DESIGN | 30 |
| 開発, Development | DEVELOPMENT | 40 |
| テスト, Testing | TESTING | 50 |
| リリース, Release | RELEASE | 60 |
| 運用, Operation | OPERATION | 70 |
| 完了, Completed | COMPLETED | 80 |
| 中止, Cancelled | CANCELLED | 90 |

---

## 4. Gold 層設計（分析用データマート）

### 4.1 概要

Gold層はスタースキーマ（ディメンショナルモデリング）に基づいたデータマートを構成する。
Power BI からの直接参照を前提とし、パフォーマンスと利便性を最適化する。

### 4.2 スタースキーマ構成図

```
                    ┌──────────────────┐
                    │  dim_date        │
                    │  (日付DIM)       │
                    └────────┬─────────┘
                             │
┌──────────────────┐         │         ┌──────────────────┐
│  dim_customer    │         │         │  dim_employee     │
│  (顧客DIM)      ├─────────┼─────────┤  (担当者DIM)      │
└──────────────────┘         │         └──────────────────┘
                             │
                    ┌────────┴─────────┐
                    │                  │
              ┌─────┴──────┐    ┌──────┴─────┐
              │ fact_       │    │ fact_       │
              │ estimates   │    │ projects   │
              │ (見積FACT)  │    │ (案件FACT) │
              └─────┬──────┘    └──────┬─────┘
                    │                  │
                    └────────┬─────────┘
                             │
                    ┌────────┴─────────┐
                    │  dim_status      │
                    │  (ステータスDIM)  │
                    └──────────────────┘


            ┌──────────────────────────────┐
            │  集計テーブル（Wide Table）    │
            ├──────────────────────────────┤
            │ agg_monthly_sales_summary    │
            │ agg_conversion_funnel        │
            │ agg_phase_duration           │
            └──────────────────────────────┘
```

### 4.3 Gold テーブル一覧

#### ディメンションテーブル

| テーブル名 | 説明 | ソース | グレイン |
|------------|------|--------|----------|
| `dim_date` | 日付ディメンション | カレンダー生成（dbt seed / macro） | 1日 |
| `dim_customer` | 顧客ディメンション | `slv_customers` | 1顧客（現行レコード） |
| `dim_employee` | 担当者ディメンション | `slv_employees` | 1担当者（現行レコード） |
| `dim_status` | ステータス/フェーズ ディメンション | 定義テーブル（dbt seed） | 1ステータス |

#### ファクトテーブル

| テーブル名 | 説明 | ソース | グレイン |
|------------|------|--------|----------|
| `fact_estimates` | 見積ファクト | `slv_estimates` | 1見積行 |
| `fact_projects` | 案件ファクト | `slv_projects` | 1案件行 |

#### 集計テーブル

| テーブル名 | 説明 | 用途 |
|------------|------|------|
| `agg_monthly_sales_summary` | 月別売上サマリ | 月別・四半期別の見積件数/受注率トレンド |
| `agg_conversion_funnel` | コンバージョンファネル | 見積→受注の転換分析 |
| `agg_phase_duration` | フェーズ滞留分析 | 案件フェーズ別の平均滞留日数 |

### 4.4 匿名化対応

担当者ディメンションには匿名化ビューを用意し、Power BI のセキュリティロールに応じて切り替える。

| ビュー名 | 説明 | 匿名化内容 |
|----------|------|------------|
| `dim_employee` | 通常ビュー | 氏名をそのまま表示 |
| `dim_employee_anonymized` | 匿名化ビュー | 氏名を `担当者_XXXX`（ハッシュ先頭4桁）に置換 |

---

## 5. データリネージ

### 5.1 エンドツーエンド リネージマップ

```
[SharePoint Online]          [Bronze層]              [Silver層]              [Gold層]               [Power BI]

見積管理リスト ──ADF──→ brz_estimates ──dbt──→ slv_estimates ──dbt──→ fact_estimates ──DirectQuery──→ 見積分析
     │                      │                      │                    │                          レポート
     │                      │                      │                    ├──→ agg_monthly_sales
     │                      │                      │                    │    _summary
     │                      │                      │                    └──→ agg_conversion
     │                      │                      │                         _funnel

案件管理リスト ──ADF──→ brz_projects ──dbt──→ slv_projects ──dbt──→ fact_projects ──DirectQuery──→ 案件分析
     │                      │                      │                    │                          レポート
     │                      │                      │                    └──→ agg_phase_duration

顧客マスタ    ──ADF──→ brz_customers ──dbt──→ slv_customers ──dbt──→ dim_customer ──DirectQuery──→ 顧客分析
リスト                      │                  (SCD Type 2)              │                          レポート

担当者マスタ  ──ADF──→ brz_employees ──dbt──→ slv_employees ──dbt──→ dim_employee ──DirectQuery──→ 担当者
リスト                      │                  (SCD Type 2)         dim_employee                    分析
                                                                   _anonymized                     レポート
```

### 5.2 変換フロー詳細

#### 5.2.1 見積管理データフロー

```
1. [Source] SharePoint 見積管理リスト
   ↓ ADF Copy Activity（増分: Modified >= last_watermark）
2. [Bronze] brz_estimates
   - 生データ + メタデータカラム追加
   - Parquet形式、日付パーティション
   ↓ dbt model: stg_estimates → slv_estimates
3. [Silver] slv_estimates
   - 型変換: 金額 → DECIMAL(18,2)
   - ステータス正規化: 表記揺れ → 統一コード
   - 重複排除: 見積番号 + Modified DESC で最新1件
   - NULL処理: 金額NULL → 0.00
   ↓ dbt model: fact_estimates
4. [Gold] fact_estimates
   - サロゲートキー付与
   - 日付キー変換（date_key → dim_date FK）
   - 顧客キー変換（顧客名 → dim_customer FK）
   - 担当者キー変換（担当者 → dim_employee FK）
   ↓ dbt model: agg_monthly_sales_summary, agg_conversion_funnel
5. [Gold] 集計テーブル
   - 月別集計、受注率計算
   - ファネル段階別件数集計
```

#### 5.2.2 案件管理データフロー

```
1. [Source] SharePoint 案件管理リスト
   ↓ ADF Copy Activity
2. [Bronze] brz_projects
   ↓ dbt model: stg_projects → slv_projects
3. [Silver] slv_projects
   - フェーズ正規化
   - 金額正規化
   - 期間計算（開始日〜終了日）
   ↓ dbt model: fact_projects
4. [Gold] fact_projects
   - ディメンションキー変換
   ↓ dbt model: agg_phase_duration
5. [Gold] agg_phase_duration
   - フェーズ別平均滞留日数計算
```

### 5.3 リネージメタデータ

各dbtモデルに以下のメタデータを `schema.yml` で管理する。

```yaml
models:
  - name: fact_estimates
    description: "見積ファクトテーブル"
    meta:
      owner: "data-architect"
      lineage:
        source_system: "sharepoint_online"
        source_entity: "見積管理リスト"
        bronze_table: "brz_estimates"
        silver_table: "slv_estimates"
        transformations:
          - "型変換"
          - "ステータス正規化"
          - "重複排除"
          - "サロゲートキー付与"
          - "ディメンションキー変換"
      sla:
        freshness_hours: 4
        quality_score_threshold: 0.95
```

---

## 6. データ品質ルール概要

各層で段階的に品質を担保する。詳細は `data-quality-rules.md` を参照。

| 層 | 品質チェックカテゴリ | 目的 |
|----|---------------------|------|
| Bronze | 完全性チェック | データ取り込みの欠損を検知 |
| Silver | 正確性・一貫性チェック | 型変換・正規化の正しさを検証 |
| Gold | ビジネスルールチェック | 分析結果の信頼性を担保 |

---

## 7. 運用設計

### 7.1 日次バッチスケジュール

```
AM 5:00  ADF パイプライン開始
  ├── 5:00-5:30  Bronze取り込み（4リスト並列）
  ├── 5:30-6:30  dbt run（Silver→Gold 変換）
  ├── 6:30-7:00  dbt test（品質チェック）
  ├── 7:00-7:30  Power BI データセットリフレッシュ
  └── 7:30       完了通知（Teams / メール）
AM 9:00  SLA デッドライン
```

### 7.2 監視・アラート

| 監視項目 | 閾値 | アクション |
|----------|------|------------|
| パイプライン実行時間 | > 3時間 | WARNING アラート |
| dbt test 失敗 | FAIL 1件以上 | ERROR アラート + 当該テーブルの更新停止 |
| レコード件数急変 | 前日比 +/-50% | WARNING アラート |
| SLA 超過 | AM 9:00 未完了 | CRITICAL アラート |

### 7.3 データ保持ポリシー

| 層 | 保持期間 | 削除方式 |
|----|----------|----------|
| Bronze | 5年 | 日付パーティション単位で自動削除（Azure Lifecycle Management） |
| Silver | 5年 | Delta Lake の VACUUM（保持期間超過分） |
| Gold | 5年 + 現行 | 5年超の履歴はアーカイブテーブルに移動 |

---

## 8. セキュリティ設計

### 8.1 アクセス制御

| 層 | アクセス権 | 対象 |
|----|------------|------|
| Bronze | 読み取り: データエンジニアのみ | ADF サービスプリンシパル |
| Silver | 読み取り: データエンジニア + アナリスト | dbt サービスプリンシパル |
| Gold | 読み取り: 全分析ユーザー | Power BI サービスプリンシパル |

### 8.2 暗号化

| 区分 | 方式 |
|------|------|
| 保存時 | Azure Storage Service Encryption (SSE) — Microsoft Managed Key |
| 転送時 | TLS 1.2 |
| 担当者氏名 | SHA-256 ハッシュによる匿名化（Gold層匿名化ビュー） |
