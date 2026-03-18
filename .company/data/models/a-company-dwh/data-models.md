# A社基幹システム DWH データモデル定義書

| 項目 | 内容 |
|------|------|
| クライアント | A社（製造業・中堅企業） |
| バージョン | 1.0.0 |
| 作成日 | 2026-03-18 |
| ステータス | 初版 |
| 関連文書 | medallion-architecture.md, data-quality-rules.md |

---

## 1. Bronze 層テーブル定義

Bronze層は SharePoint Online のリストデータをそのまま格納する。
全テーブルに共通の監査カラム（_source_system, _ingestion_timestamp 等）を付与する。

### 1.1 brz_estimates（見積管理）

**ソース**: SharePoint Online 見積管理リスト
**格納形式**: Parquet（Snappy圧縮）
**パーティション**: `_ingestion_date`

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | estimate_number | STRING | NO | 見積番号（ソース主キー） |
| 2 | customer_name | STRING | YES | 顧客名 |
| 3 | amount | STRING | YES | 金額（ソースのまま文字列保持） |
| 4 | status | STRING | YES | ステータス（ソースのまま） |
| 5 | created_date | STRING | YES | 作成日（ソースのまま文字列保持） |
| 6 | modified_date | STRING | YES | 更新日（ソースのまま文字列保持） |
| 7 | assigned_to | STRING | YES | 担当者（SharePoint Person型の表示名） |
| 8 | _source_system | STRING | NO | 固定値: `sharepoint_online` |
| 9 | _source_list | STRING | NO | 固定値: `見積管理リスト` |
| 10 | _ingestion_timestamp | TIMESTAMP | NO | 取り込み実行日時（UTC） |
| 11 | _ingestion_date | DATE | NO | 取り込み日（パーティションキー） |
| 12 | _adf_pipeline_run_id | STRING | NO | ADF パイプライン実行ID |
| 13 | _raw_json | STRING | NO | ソースレコードのJSON文字列 |

### 1.2 brz_projects（案件管理）

**ソース**: SharePoint Online 案件管理リスト
**格納形式**: Parquet（Snappy圧縮）
**パーティション**: `_ingestion_date`

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | project_number | STRING | NO | 案件番号（ソース主キー） |
| 2 | project_name | STRING | YES | 案件名 |
| 3 | customer_name | STRING | YES | 顧客名 |
| 4 | phase | STRING | YES | フェーズ（ソースのまま） |
| 5 | contract_amount | STRING | YES | 受注金額（ソースのまま文字列保持） |
| 6 | start_date | STRING | YES | 開始日（ソースのまま文字列保持） |
| 7 | end_date | STRING | YES | 終了日（ソースのまま文字列保持） |
| 8 | _source_system | STRING | NO | 固定値: `sharepoint_online` |
| 9 | _source_list | STRING | NO | 固定値: `案件管理リスト` |
| 10 | _ingestion_timestamp | TIMESTAMP | NO | 取り込み実行日時（UTC） |
| 11 | _ingestion_date | DATE | NO | 取り込み日（パーティションキー） |
| 12 | _adf_pipeline_run_id | STRING | NO | ADF パイプライン実行ID |
| 13 | _raw_json | STRING | NO | ソースレコードのJSON文字列 |

### 1.3 brz_customers（顧客マスタ）

**ソース**: SharePoint Online 顧客マスタリスト
**格納形式**: Parquet（Snappy圧縮）
**パーティション**: `_ingestion_date`

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | customer_code | STRING | NO | 顧客コード（ソース主キー） |
| 2 | customer_name | STRING | YES | 顧客名 |
| 3 | industry | STRING | YES | 業種 |
| 4 | region | STRING | YES | 地域 |
| 5 | contract_status | STRING | YES | 契約ステータス |
| 6 | _source_system | STRING | NO | 固定値: `sharepoint_online` |
| 7 | _source_list | STRING | NO | 固定値: `顧客マスタリスト` |
| 8 | _ingestion_timestamp | TIMESTAMP | NO | 取り込み実行日時（UTC） |
| 9 | _ingestion_date | DATE | NO | 取り込み日（パーティションキー） |
| 10 | _adf_pipeline_run_id | STRING | NO | ADF パイプライン実行ID |
| 11 | _raw_json | STRING | NO | ソースレコードのJSON文字列 |

### 1.4 brz_employees（担当者マスタ）

**ソース**: SharePoint Online 担当者マスタリスト
**格納形式**: Parquet（Snappy圧縮）
**パーティション**: `_ingestion_date`

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | employee_number | STRING | NO | 社員番号（ソース主キー） |
| 2 | employee_name | STRING | YES | 氏名 |
| 3 | department | STRING | YES | 部署 |
| 4 | job_title | STRING | YES | 役職 |
| 5 | _source_system | STRING | NO | 固定値: `sharepoint_online` |
| 6 | _source_list | STRING | NO | 固定値: `担当者マスタリスト` |
| 7 | _ingestion_timestamp | TIMESTAMP | NO | 取り込み実行日時（UTC） |
| 8 | _ingestion_date | DATE | NO | 取り込み日（パーティションキー） |
| 9 | _adf_pipeline_run_id | STRING | NO | ADF パイプライン実行ID |
| 10 | _raw_json | STRING | NO | ソースレコードのJSON文字列 |

---

## 2. Silver 層テーブル定義

Silver層はクレンジング・型変換・正規化を適用した分析準備済みデータ。
マスタテーブルは SCD Type 2 で履歴管理する。

### 2.1 slv_estimates（見積管理 クレンジング済み）

**ソース**: `brz_estimates`
**マテリアライゼーション**: Delta Lake（incremental）
**更新方式**: merge（見積番号ベース）

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | estimate_id | BIGINT | NO | サロゲートキー（自動採番） |
| 2 | estimate_number | STRING | NO | 見積番号（ビジネスキー） |
| 3 | customer_name | STRING | NO | 顧客名（トリム済み。NULL時は `'不明'`） |
| 4 | amount | DECIMAL(18,2) | NO | 金額（数値変換済み。NULL時は `0.00`） |
| 5 | status_code | INT | NO | ステータスコード（正規化済み） |
| 6 | status_name | STRING | NO | ステータス名（正規化済み: DRAFT, SUBMITTED, 等） |
| 7 | created_at | TIMESTAMP | YES | 作成日時（ISO 8601 変換済み） |
| 8 | modified_at | TIMESTAMP | YES | 更新日時（ISO 8601 変換済み） |
| 9 | assigned_to | STRING | YES | 担当者名（トリム済み） |
| 10 | _loaded_at | TIMESTAMP | NO | Silver層ロード日時（UTC） |
| 11 | _source_record_hash | STRING | NO | ソースレコードのSHA-256ハッシュ（変更検知用） |

**一意性制約**: `estimate_number` でユニーク（最新レコードのみ保持）

### 2.2 slv_projects（案件管理 クレンジング済み）

**ソース**: `brz_projects`
**マテリアライゼーション**: Delta Lake（incremental）
**更新方式**: merge（案件番号ベース）

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | project_id | BIGINT | NO | サロゲートキー（自動採番） |
| 2 | project_number | STRING | NO | 案件番号（ビジネスキー） |
| 3 | project_name | STRING | NO | 案件名（トリム済み。NULL時は `'無題'`） |
| 4 | customer_name | STRING | NO | 顧客名（トリム済み。NULL時は `'不明'`） |
| 5 | phase_code | INT | NO | フェーズコード（正規化済み） |
| 6 | phase_name | STRING | NO | フェーズ名（正規化済み: PLANNING, REQUIREMENTS, 等） |
| 7 | contract_amount | DECIMAL(18,2) | NO | 受注金額（数値変換済み。NULL時は `0.00`） |
| 8 | start_date | DATE | YES | 開始日 |
| 9 | end_date | DATE | YES | 終了日 |
| 10 | duration_days | INT | YES | 期間（日数）。`DATEDIFF(end_date, start_date)` |
| 11 | _loaded_at | TIMESTAMP | NO | Silver層ロード日時（UTC） |
| 12 | _source_record_hash | STRING | NO | ソースレコードのSHA-256ハッシュ（変更検知用） |

**一意性制約**: `project_number` でユニーク（最新レコードのみ保持）

### 2.3 slv_customers（顧客マスタ クレンジング済み / SCD Type 2）

**ソース**: `brz_customers`
**マテリアライゼーション**: Delta Lake（incremental）
**更新方式**: SCD Type 2（変更検知 → 既存レコード close + 新レコード insert）

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | customer_sk | BIGINT | NO | サロゲートキー（自動採番） |
| 2 | customer_code | STRING | NO | 顧客コード（ビジネスキー） |
| 3 | customer_name | STRING | NO | 顧客名（トリム済み） |
| 4 | industry_code | STRING | YES | 業種コード（標準化済み） |
| 5 | industry_name | STRING | YES | 業種名（標準化済み） |
| 6 | region | STRING | YES | 地域（トリム済み） |
| 7 | contract_status | STRING | YES | 契約ステータス（正規化済み: ACTIVE, INACTIVE, SUSPENDED） |
| 8 | _valid_from | TIMESTAMP | NO | 有効開始日時 |
| 9 | _valid_to | TIMESTAMP | NO | 有効終了日時（現行: `9999-12-31 23:59:59`） |
| 10 | _is_current | BOOLEAN | NO | 現行フラグ（`true` / `false`） |
| 11 | _hash_diff | STRING | NO | 変更検知用ハッシュ（SHA-256）。対象: customer_name, industry_code, region, contract_status |
| 12 | _loaded_at | TIMESTAMP | NO | Silver層ロード日時（UTC） |

**一意性制約**: `customer_sk` でユニーク。`customer_code` + `_is_current = true` で現行レコード1件

#### 業種コード標準化マッピング

| ソース値（例） | 業種コード | 業種名 |
|----------------|------------|--------|
| 製造, 製造業, Manufacturing | MFG | 製造業 |
| 卸売, 卸売業, Wholesale | WHL | 卸売業 |
| 小売, 小売業, Retail | RTL | 小売業 |
| 情報, IT, 情報通信, Information Technology | ICT | 情報通信業 |
| 建設, 建設業, Construction | CNS | 建設業 |
| サービス, サービス業, Services | SVC | サービス業 |
| その他, Other | OTH | その他 |
| (NULL / 空文字) | UNK | 不明 |

### 2.4 slv_employees（担当者マスタ クレンジング済み / SCD Type 2）

**ソース**: `brz_employees`
**マテリアライゼーション**: Delta Lake（incremental）
**更新方式**: SCD Type 2

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | employee_sk | BIGINT | NO | サロゲートキー（自動採番） |
| 2 | employee_number | STRING | NO | 社員番号（ビジネスキー） |
| 3 | employee_name | STRING | NO | 氏名（トリム済み） |
| 4 | employee_name_hash | STRING | NO | 氏名のSHA-256ハッシュ（匿名化用） |
| 5 | department | STRING | YES | 部署名（正規化済み） |
| 6 | job_title | STRING | YES | 役職（正規化済み） |
| 7 | _valid_from | TIMESTAMP | NO | 有効開始日時 |
| 8 | _valid_to | TIMESTAMP | NO | 有効終了日時（現行: `9999-12-31 23:59:59`） |
| 9 | _is_current | BOOLEAN | NO | 現行フラグ |
| 10 | _hash_diff | STRING | NO | 変更検知用ハッシュ。対象: employee_name, department, job_title |
| 11 | _loaded_at | TIMESTAMP | NO | Silver層ロード日時（UTC） |

**一意性制約**: `employee_sk` でユニーク。`employee_number` + `_is_current = true` で現行レコード1件

---

## 3. Gold 層テーブル定義

Gold層はスタースキーマに基づくディメンショナルモデル。
Power BI から DirectQuery / Import で参照する。

### 3.1 dim_date（日付ディメンション）

**ソース**: dbt macro によるカレンダー生成
**マテリアライゼーション**: table（フルリフレッシュ）
**範囲**: 2020-01-01 ~ 2030-12-31

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | date_key | INT | NO | 日付キー（YYYYMMDD形式、例: 20260318）PK |
| 2 | full_date | DATE | NO | 日付 |
| 3 | year | INT | NO | 年 |
| 4 | quarter | INT | NO | 四半期（1-4） |
| 5 | quarter_name | STRING | NO | 四半期名（例: `2026Q1`） |
| 6 | month | INT | NO | 月（1-12） |
| 7 | month_name | STRING | NO | 月名（例: `3月`） |
| 8 | month_name_short | STRING | NO | 月名略称（例: `Mar`） |
| 9 | day_of_month | INT | NO | 日（1-31） |
| 10 | day_of_week | INT | NO | 曜日番号（1=月曜 ~ 7=日曜） |
| 11 | day_name | STRING | NO | 曜日名（例: `水曜日`） |
| 12 | week_of_year | INT | NO | 年内週番号（ISO 8601） |
| 13 | is_weekend | BOOLEAN | NO | 週末フラグ |
| 14 | is_holiday | BOOLEAN | NO | 祝日フラグ（日本の祝日） |
| 15 | fiscal_year | INT | NO | 会計年度（4月始まり: 2026年3月→FY2025） |
| 16 | fiscal_quarter | INT | NO | 会計四半期 |

### 3.2 dim_customer（顧客ディメンション）

**ソース**: `slv_customers` WHERE `_is_current = true`
**マテリアライゼーション**: view

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | customer_key | BIGINT | NO | 顧客キー（= customer_sk）PK |
| 2 | customer_code | STRING | NO | 顧客コード（ビジネスキー） |
| 3 | customer_name | STRING | NO | 顧客名 |
| 4 | industry_code | STRING | YES | 業種コード |
| 5 | industry_name | STRING | YES | 業種名 |
| 6 | region | STRING | YES | 地域 |
| 7 | contract_status | STRING | YES | 契約ステータス |

### 3.3 dim_employee（担当者ディメンション）

**ソース**: `slv_employees` WHERE `_is_current = true`
**マテリアライゼーション**: view

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | employee_key | BIGINT | NO | 担当者キー（= employee_sk）PK |
| 2 | employee_number | STRING | NO | 社員番号（ビジネスキー） |
| 3 | employee_name | STRING | NO | 氏名 |
| 4 | department | STRING | YES | 部署名 |
| 5 | job_title | STRING | YES | 役職 |

### 3.4 dim_employee_anonymized（担当者ディメンション 匿名化版）

**ソース**: `slv_employees` WHERE `_is_current = true`
**マテリアライゼーション**: view
**用途**: 匿名化が必要な場合に dim_employee の代わりに参照

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | employee_key | BIGINT | NO | 担当者キー（= employee_sk）PK |
| 2 | employee_number | STRING | NO | 社員番号（ビジネスキー） |
| 3 | employee_name_masked | STRING | NO | 匿名化氏名（`担当者_` + employee_name_hash先頭4文字） |
| 4 | department | STRING | YES | 部署名 |
| 5 | job_title | STRING | YES | 役職 |

**匿名化ロジック**:
```sql
CONCAT('担当者_', LEFT(employee_name_hash, 4)) AS employee_name_masked
-- 例: 山田太郎 → 担当者_a3f2
```

### 3.5 dim_status（ステータスディメンション）

**ソース**: dbt seed（`seeds/status_master.csv`）
**マテリアライゼーション**: table

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | status_key | INT | NO | ステータスキー PK |
| 2 | status_category | STRING | NO | カテゴリ（`ESTIMATE` / `PROJECT`） |
| 3 | status_code | INT | NO | ステータスコード |
| 4 | status_name | STRING | NO | ステータス名（英語） |
| 5 | status_name_ja | STRING | NO | ステータス名（日本語） |
| 6 | sort_order | INT | NO | 表示順 |
| 7 | is_terminal | BOOLEAN | NO | 終端ステータスフラグ（受注/失注/完了/中止） |

**seed データ例**:

| status_key | status_category | status_code | status_name | status_name_ja | sort_order | is_terminal |
|------------|-----------------|-------------|-------------|----------------|------------|-------------|
| 101 | ESTIMATE | 10 | DRAFT | 作成中 | 1 | false |
| 102 | ESTIMATE | 20 | SUBMITTED | 提出済 | 2 | false |
| 103 | ESTIMATE | 30 | UNDER_REVIEW | 検討中 | 3 | false |
| 104 | ESTIMATE | 40 | WON | 受注 | 4 | true |
| 105 | ESTIMATE | 50 | LOST | 失注 | 5 | true |
| 106 | ESTIMATE | 90 | CANCELLED | 取消 | 6 | true |
| 201 | PROJECT | 10 | PLANNING | 計画 | 1 | false |
| 202 | PROJECT | 20 | REQUIREMENTS | 要件定義 | 2 | false |
| 203 | PROJECT | 30 | DESIGN | 設計 | 3 | false |
| 204 | PROJECT | 40 | DEVELOPMENT | 開発 | 4 | false |
| 205 | PROJECT | 50 | TESTING | テスト | 5 | false |
| 206 | PROJECT | 60 | RELEASE | リリース | 6 | false |
| 207 | PROJECT | 70 | OPERATION | 運用 | 7 | false |
| 208 | PROJECT | 80 | COMPLETED | 完了 | 8 | true |
| 209 | PROJECT | 90 | CANCELLED | 中止 | 9 | true |

### 3.6 fact_estimates（見積ファクト）

**ソース**: `slv_estimates`
**マテリアライゼーション**: Delta Lake（incremental）
**グレイン**: 1見積行

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | estimate_fact_key | BIGINT | NO | ファクトサロゲートキー PK |
| 2 | estimate_number | STRING | NO | 見積番号（degenerate dimension） |
| 3 | customer_key | BIGINT | NO | 顧客キー FK → dim_customer |
| 4 | employee_key | BIGINT | YES | 担当者キー FK → dim_employee（未割当時NULL） |
| 5 | created_date_key | INT | YES | 作成日キー FK → dim_date |
| 6 | modified_date_key | INT | YES | 更新日キー FK → dim_date |
| 7 | status_key | INT | NO | ステータスキー FK → dim_status |
| 8 | amount | DECIMAL(18,2) | NO | 見積金額（メジャー） |
| 9 | is_won | BOOLEAN | NO | 受注フラグ（status_code = 40） |
| 10 | is_lost | BOOLEAN | NO | 失注フラグ（status_code = 50） |
| 11 | is_open | BOOLEAN | NO | オープンフラグ（終端ステータス以外） |
| 12 | days_since_created | INT | YES | 作成からの経過日数 |
| 13 | _loaded_at | TIMESTAMP | NO | Gold層ロード日時（UTC） |

**リレーション**:
- `customer_key` → `dim_customer.customer_key`
- `employee_key` → `dim_employee.employee_key`（または `dim_employee_anonymized.employee_key`）
- `created_date_key` → `dim_date.date_key`
- `modified_date_key` → `dim_date.date_key`
- `status_key` → `dim_status.status_key`

### 3.7 fact_projects（案件ファクト）

**ソース**: `slv_projects`
**マテリアライゼーション**: Delta Lake（incremental）
**グレイン**: 1案件行

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | project_fact_key | BIGINT | NO | ファクトサロゲートキー PK |
| 2 | project_number | STRING | NO | 案件番号（degenerate dimension） |
| 3 | project_name | STRING | NO | 案件名 |
| 4 | customer_key | BIGINT | NO | 顧客キー FK → dim_customer |
| 5 | start_date_key | INT | YES | 開始日キー FK → dim_date |
| 6 | end_date_key | INT | YES | 終了日キー FK → dim_date |
| 7 | status_key | INT | NO | フェーズ/ステータスキー FK → dim_status |
| 8 | contract_amount | DECIMAL(18,2) | NO | 受注金額（メジャー） |
| 9 | duration_days | INT | YES | 案件期間（日数） |
| 10 | is_active | BOOLEAN | NO | アクティブフラグ（完了/中止以外） |
| 11 | is_completed | BOOLEAN | NO | 完了フラグ（phase_code = 80） |
| 12 | phase_duration_days | INT | YES | 現フェーズの滞留日数 |
| 13 | _loaded_at | TIMESTAMP | NO | Gold層ロード日時（UTC） |

**リレーション**:
- `customer_key` → `dim_customer.customer_key`
- `start_date_key` → `dim_date.date_key`
- `end_date_key` → `dim_date.date_key`
- `status_key` → `dim_status.status_key`

### 3.8 agg_monthly_sales_summary（月別売上サマリ）

**ソース**: `fact_estimates` + `dim_date` + `dim_customer`
**マテリアライゼーション**: table（日次フルリビルド）
**グレイン**: 年月 x 顧客 x 業種

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | year_month | STRING | NO | 年月（YYYY-MM 形式）PK(部分) |
| 2 | year | INT | NO | 年 |
| 3 | quarter | INT | NO | 四半期 |
| 4 | month | INT | NO | 月 |
| 5 | customer_key | BIGINT | NO | 顧客キー PK(部分) |
| 6 | customer_name | STRING | NO | 顧客名（非正規化） |
| 7 | industry_name | STRING | YES | 業種名（非正規化） |
| 8 | total_estimates | INT | NO | 見積件数 |
| 9 | total_estimate_amount | DECIMAL(18,2) | NO | 見積金額合計 |
| 10 | won_count | INT | NO | 受注件数 |
| 11 | won_amount | DECIMAL(18,2) | NO | 受注金額合計 |
| 12 | lost_count | INT | NO | 失注件数 |
| 13 | lost_amount | DECIMAL(18,2) | NO | 失注金額合計 |
| 14 | open_count | INT | NO | オープン件数 |
| 15 | win_rate | DECIMAL(5,2) | YES | 受注率（%）。`won / (won + lost) * 100`。母数0の場合NULL |
| 16 | avg_estimate_amount | DECIMAL(18,2) | NO | 平均見積金額 |
| 17 | _calculated_at | TIMESTAMP | NO | 集計実行日時 |

### 3.9 agg_conversion_funnel（コンバージョンファネル）

**ソース**: `fact_estimates` + `dim_status`
**マテリアライゼーション**: table（日次フルリビルド）
**グレイン**: 年月 x ステータス

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | year_month | STRING | NO | 年月（YYYY-MM 形式）PK(部分) |
| 2 | status_code | INT | NO | ステータスコード PK(部分) |
| 3 | status_name | STRING | NO | ステータス名 |
| 4 | status_name_ja | STRING | NO | ステータス名（日本語） |
| 5 | sort_order | INT | NO | 表示順 |
| 6 | estimate_count | INT | NO | 該当ステータスの見積件数 |
| 7 | estimate_amount | DECIMAL(18,2) | NO | 該当ステータスの見積金額合計 |
| 8 | cumulative_count | INT | NO | 累計件数（ファネル上位からの累計） |
| 9 | conversion_rate | DECIMAL(5,2) | YES | 前ステージからの転換率（%） |
| 10 | _calculated_at | TIMESTAMP | NO | 集計実行日時 |

### 3.10 agg_phase_duration（フェーズ滞留分析）

**ソース**: `fact_projects` + `dim_status`
**マテリアライゼーション**: table（日次フルリビルド）
**グレイン**: フェーズ

| # | カラム名 | 型 | NULL許容 | 説明 |
|---|----------|----|----------|------|
| 1 | phase_code | INT | NO | フェーズコード PK |
| 2 | phase_name | STRING | NO | フェーズ名 |
| 3 | phase_name_ja | STRING | NO | フェーズ名（日本語） |
| 4 | sort_order | INT | NO | 表示順 |
| 5 | project_count | INT | NO | 該当フェーズの案件数 |
| 6 | avg_duration_days | DECIMAL(10,1) | YES | 平均滞留日数 |
| 7 | median_duration_days | DECIMAL(10,1) | YES | 中央値滞留日数 |
| 8 | min_duration_days | INT | YES | 最小滞留日数 |
| 9 | max_duration_days | INT | YES | 最大滞留日数 |
| 10 | p90_duration_days | DECIMAL(10,1) | YES | 90パーセンタイル滞留日数 |
| 11 | currently_in_phase | INT | NO | 現在このフェーズにある案件数 |
| 12 | _calculated_at | TIMESTAMP | NO | 集計実行日時 |

---

## 4. テーブル間リレーション（ER図）

### 4.1 Gold層 スタースキーマ ER図

```
                         dim_date
                    ┌──────────────────┐
                    │ PK date_key      │
                    │    full_date     │
                    │    year          │
                    │    quarter       │
                    │    month         │
                    │    ...           │
                    └──────┬───────────┘
                           │
              ┌────────────┼────────────────┐
              │            │                │
    created_date_key  modified_date_key  start_date_key / end_date_key
              │            │                │
              ▼            ▼                ▼
┌─────────────────────────────┐    ┌─────────────────────────────┐
│      fact_estimates         │    │       fact_projects         │
├─────────────────────────────┤    ├─────────────────────────────┤
│ PK estimate_fact_key        │    │ PK project_fact_key         │
│ FK customer_key      ──────┼──┐ │ FK customer_key      ──────┼──┐
│ FK employee_key      ──────┼┐ │ │ FK start_date_key    ──────┼──┤
│ FK created_date_key  ──────┼┤ │ │ FK end_date_key      ──────┼──┤
│ FK modified_date_key ──────┼┤ │ │ FK status_key        ──────┼┐ │
│ FK status_key        ──────┼┤ │ │    project_number           │ │ │
│    estimate_number          │ │ │ │    project_name             │ │ │
│    amount                   │ │ │ │    contract_amount          │ │ │
│    is_won                   │ │ │ │    duration_days            │ │ │
│    is_lost                  │ │ │ │    is_active                │ │ │
│    is_open                  │ │ │ │    phase_duration_days      │ │ │
└─────────────────────────────┘ │ │ └─────────────────────────────┘ │ │
                                │ │                                 │ │
              ┌─────────────────┘ │         ┌───────────────────────┘ │
              ▼                   │         ▼                         │
┌─────────────────────────┐      │ ┌───────────────────────┐         │
│    dim_employee         │      │ │    dim_status          │         │
├─────────────────────────┤      │ ├───────────────────────┤         │
│ PK employee_key         │      │ │ PK status_key          │         │
│    employee_number      │      │ │    status_category     │         │
│    employee_name        │      │ │    status_code         │         │
│    department           │      │ │    status_name         │         │
│    job_title            │      │ │    status_name_ja      │         │
└─────────────────────────┘      │ │    is_terminal         │         │
                                 │ └───────────────────────┘         │
              ┌──────────────────┘                                   │
              ▼                                                      │
┌─────────────────────────┐                                          │
│    dim_customer         │◄─────────────────────────────────────────┘
├─────────────────────────┤
│ PK customer_key         │
│    customer_code        │
│    customer_name        │
│    industry_code        │
│    industry_name        │
│    region               │
│    contract_status      │
└─────────────────────────┘
```

### 4.2 リレーション一覧

| 親テーブル | 子テーブル | 結合カラム | カーディナリティ | NULL許容 |
|------------|------------|------------|-----------------|----------|
| dim_date | fact_estimates | date_key = created_date_key | 1:N | YES |
| dim_date | fact_estimates | date_key = modified_date_key | 1:N | YES |
| dim_date | fact_projects | date_key = start_date_key | 1:N | YES |
| dim_date | fact_projects | date_key = end_date_key | 1:N | YES |
| dim_customer | fact_estimates | customer_key | 1:N | NO |
| dim_customer | fact_projects | customer_key | 1:N | NO |
| dim_employee | fact_estimates | employee_key | 1:N | YES |
| dim_status | fact_estimates | status_key | 1:N | NO |
| dim_status | fact_projects | status_key | 1:N | NO |

### 4.3 Silver → Gold 層間マッピング

| Silver テーブル | Gold テーブル | マッピング方式 |
|----------------|--------------|---------------|
| slv_estimates | fact_estimates | ビジネスキー → サロゲートキー変換。顧客名 → dim_customer ルックアップ |
| slv_projects | fact_projects | ビジネスキー → サロゲートキー変換。顧客名 → dim_customer ルックアップ |
| slv_customers (_is_current=true) | dim_customer | ビュー参照（1:1） |
| slv_employees (_is_current=true) | dim_employee | ビュー参照（1:1） |
| slv_employees (_is_current=true) | dim_employee_anonymized | ビュー参照（1:1、氏名マスク） |
| (seed) | dim_date | カレンダー生成 |
| (seed) | dim_status | 定義データ |
| fact_estimates + dim_* | agg_monthly_sales_summary | 月別集計 |
| fact_estimates + dim_status | agg_conversion_funnel | ステータス別集計 |
| fact_projects + dim_status | agg_phase_duration | フェーズ別集計 |
