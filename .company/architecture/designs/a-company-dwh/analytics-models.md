# Gold層 分析モデル設計書

**プロジェクト**: A社基幹システム DWH構築
**対象レイヤー**: Gold層（Analytics層）
**作成日**: 2026-03-18
**バージョン**: 1.0

---

## 1. 全体アーキテクチャ概観

```
Bronze層（生データ）
  └─ SharePoint Online リスト → Delta Lake / Parquet として取込
      ├─ raw_estimates        （見積管理リスト）
      ├─ raw_deals            （案件管理リスト）
      ├─ raw_customers        （顧客マスタリスト）
      └─ raw_staff            （担当者マスタリスト）

Silver層（クレンジング・正規化済）
  ├─ stg_estimates           （見積: 型変換・NULL補完・ステータス正規化）
  ├─ stg_deals               （案件: 型変換・フェーズ正規化）
  ├─ stg_customers           （顧客: 重複排除・業種コード付与）
  └─ stg_staff               （担当者: 在籍フラグ付与）

Gold層（分析モデル）  ← 本書の対象
  ディメンション
  ├─ dim_customer             （顧客ディメンション）
  ├─ dim_staff                （担当者ディメンション・匿名化対応）
  └─ dim_date                 （日付ディメンション）
  ファクト
  ├─ fact_estimates           （見積ファクト）
  └─ fact_deals               （案件ファクト）
  マート（集計済みサマリ）
  ├─ mart_sales_summary       （売上サマリ）
  ├─ mart_conversion_funnel   （コンバージョンファネル）
  └─ mart_phase_analysis      （フェーズ滞留分析）
```

---

## 2. スタースキーマ設計

### 2.1 ER図（概念）

```
                        ┌─────────────┐
                        │  dim_date   │
                        │  (日付)     │
                        └──────┬──────┘
                               │ date_key
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────┴──────┐  ┌──────┴───────┐  ┌────┴─────────────┐
    │ fact_estimates  │  │  fact_deals  │  │  dim_customer    │
    │  (見積ファクト) │  │  (案件ファクト│  │  (顧客ディメンション)│
    └─────────┬──────┘  └──────┬───────┘  └────┬─────────────┘
              │                │                │
              └────────────────┼────────────────┘
                               │
                        ┌──────┴──────┐
                        │  dim_staff  │
                        │  (担当者)   │
                        └─────────────┘
```

---

## 3. ディメンション定義

### 3.1 dim_customer（顧客ディメンション）

**目的**: 顧客マスタの SCD Type 2 対応ディメンション。業種・地域別の分析軸を提供する。

**materialization**: `table`（日次フル更新）

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| customer_key | INT (SURROGATE) | NOT NULL | サロゲートキー（PK） |
| customer_code | VARCHAR(20) | NOT NULL | 顧客コード（自然キー） |
| customer_name | VARCHAR(200) | NOT NULL | 顧客名 |
| industry_code | VARCHAR(10) | NOT NULL | 業種コード（正規化後） |
| industry_name | VARCHAR(100) | NOT NULL | 業種名（表示用） |
| industry_category | VARCHAR(50) | NOT NULL | 業種大分類（製造業/サービス業/その他） |
| region_code | VARCHAR(10) | NOT NULL | 地域コード |
| region_name | VARCHAR(50) | NOT NULL | 地域名 |
| contract_status | VARCHAR(20) | NOT NULL | 契約ステータス（有効/無効/保留） |
| is_active | BOOLEAN | NOT NULL | 現在有効な顧客か（SCD有効フラグ） |
| valid_from | DATE | NOT NULL | SCD有効開始日 |
| valid_to | DATE | NULL | SCD有効終了日（現行レコードはNULL） |
| created_at | TIMESTAMP | NOT NULL | Silver層からの取込日時 |
| updated_at | TIMESTAMP | NOT NULL | 最終更新日時 |

**インデックス推奨**: `customer_code`, `industry_code`, `region_code`

**SCD方針**: Type 2（顧客名・業種変更時に新行追加、旧行の valid_to を更新）

---

### 3.2 dim_staff（担当者ディメンション・匿名化対応）

**目的**: 担当者マスタのディメンション。GDPR/個人情報保護対応のため匿名化オプションを内包する。

**materialization**: `table`（日次フル更新）

**匿名化設計方針**:
- 実名カラム（`staff_name_raw`）は Gold層テーブルには格納しない
- Silver層の `stg_staff` に実名を保持し、Gold 層では以下の2パターンを提供する
  - `staff_alias`: 「担当者A」「担当者B」形式の固定エイリアス（社員番号→エイリアスのハッシュマッピング）
  - `staff_display_name`: RLS（Row Level Security）により本人・管理職のみ実名表示、それ以外はエイリアス表示（Power BIで制御）

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| staff_key | INT (SURROGATE) | NOT NULL | サロゲートキー（PK） |
| employee_id | VARCHAR(20) | NOT NULL | 社員番号（自然キー） |
| staff_alias | VARCHAR(50) | NOT NULL | 匿名エイリアス（「担当者001」形式） |
| staff_name_masked | VARCHAR(50) | NOT NULL | 部分マスク名（「山田○○」形式）※中間管理職向け |
| department_code | VARCHAR(20) | NOT NULL | 部署コード |
| department_name | VARCHAR(100) | NOT NULL | 部署名 |
| job_title | VARCHAR(100) | NULL | 役職名 |
| job_grade | VARCHAR(20) | NULL | 職位グレード（主任/係長/課長/部長等） |
| is_manager | BOOLEAN | NOT NULL | 管理職フラグ（RLS判定に使用） |
| is_active | BOOLEAN | NOT NULL | 在籍中フラグ |
| hire_year | INT | NULL | 入社年（個人特定リスクが低い粒度に丸める） |
| created_at | TIMESTAMP | NOT NULL | 取込日時 |
| updated_at | TIMESTAMP | NOT NULL | 最終更新日時 |

> **注意**: Power BI の RLS設定で `is_manager = TRUE` または本人ログインの場合のみ
> `staff_name_raw`（Silver層結合）を表示する DAX 措置を設ける。
> Gold層テーブル自体には氏名を格納しない設計とする。

---

### 3.3 dim_date（日付ディメンション）

**目的**: 時系列分析の軸となる標準的な日付ディメンション。

**materialization**: `table`（静的テーブル、2020〜2030年分を事前生成）

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| date_key | INT | NOT NULL | 日付キー（YYYYMMDD形式の整数、PK） |
| full_date | DATE | NOT NULL | 日付 |
| year | INT | NOT NULL | 年（例: 2026） |
| quarter | INT | NOT NULL | 四半期（1〜4） |
| quarter_label | VARCHAR(10) | NOT NULL | 四半期ラベル（例: 2026Q1） |
| month | INT | NOT NULL | 月（1〜12） |
| month_label | VARCHAR(10) | NOT NULL | 月ラベル（例: 2026-03） |
| week_of_year | INT | NOT NULL | 年間通算週番号（ISO 8601） |
| day_of_week | INT | NOT NULL | 曜日番号（1=月曜〜7=日曜） |
| day_of_week_label | VARCHAR(10) | NOT NULL | 曜日名（月/火/水...） |
| is_weekday | BOOLEAN | NOT NULL | 平日フラグ |
| is_holiday | BOOLEAN | NOT NULL | 祝日フラグ（日本の祝日カレンダー） |
| is_business_day | BOOLEAN | NOT NULL | 営業日フラグ（平日かつ非祝日） |
| fiscal_year | INT | NOT NULL | 会計年度（4月始まり：例 2025年4月〜2026年3月 → 2025） |
| fiscal_quarter | INT | NOT NULL | 会計四半期（Q1=4〜6月、Q2=7〜9月...） |
| fiscal_month | INT | NOT NULL | 会計月（1=4月〜12=3月） |

---

## 4. ファクトテーブル定義

### 4.1 fact_estimates（見積ファクト）

**目的**: 見積の全件記録。見積件数・金額・受注率等の計算基盤。

**materialization**: `incremental`（updated_at の差分取込、日次バッチ）

**粒度**: 見積1件 = 1行（更新があっても1行のまま。履歴はSilver層のスナップショットに保持）

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| estimate_key | BIGINT (SURROGATE) | NOT NULL | サロゲートキー（PK） |
| estimate_id | VARCHAR(50) | NOT NULL | 見積番号（自然キー） |
| customer_key | INT | NOT NULL | dim_customer への FK |
| staff_key | INT | NOT NULL | dim_staff への FK（担当者） |
| created_date_key | INT | NOT NULL | dim_date への FK（作成日） |
| updated_date_key | INT | NOT NULL | dim_date への FK（最終更新日） |
| closed_date_key | INT | NULL | dim_date への FK（クローズ日：受注/失注確定日） |
| estimate_amount | DECIMAL(15,2) | NOT NULL | 見積金額（円） |
| status | VARCHAR(20) | NOT NULL | ステータス（受注/失注/進行中/保留/キャンセル） |
| is_won | BOOLEAN | NOT NULL | 受注フラグ（status = '受注' のとき TRUE） |
| is_lost | BOOLEAN | NOT NULL | 失注フラグ（status = '失注' のとき TRUE） |
| is_active | BOOLEAN | NOT NULL | 進行中フラグ（クローズされていない見積） |
| days_to_close | INT | NULL | 見積作成〜クローズまでの日数（受注/失注案件のみ） |
| deal_id | VARCHAR(50) | NULL | 関連する案件番号（fact_deals との結合キー） |
| dbt_updated_at | TIMESTAMP | NOT NULL | dbt による最終処理日時 |

**dbtインクリメンタル設定**:
```sql
-- dbt_project.yml
config:
  materialized: 'incremental'
  unique_key: 'estimate_id'
  incremental_strategy: 'merge'
  on_schema_change: 'sync_all_columns'
```

---

### 4.2 fact_deals（案件ファクト）

**目的**: 案件の全件記録。フェーズ遷移・受注金額・期間分析の基盤。

**materialization**: `incremental`（updated_at の差分取込、日次バッチ）

**粒度**: 案件1件 = 1行（最新フェーズを保持。フェーズ履歴は Silver層スナップショットテーブルに保持）

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| deal_key | BIGINT (SURROGATE) | NOT NULL | サロゲートキー（PK） |
| deal_id | VARCHAR(50) | NOT NULL | 案件番号（自然キー） |
| deal_name | VARCHAR(500) | NOT NULL | 案件名 |
| customer_key | INT | NOT NULL | dim_customer への FK |
| staff_key | INT | NOT NULL | dim_staff への FK（主担当者） |
| start_date_key | INT | NULL | dim_date への FK（開始日） |
| end_date_key | INT | NULL | dim_date への FK（終了予定日） |
| actual_end_date_key | INT | NULL | dim_date への FK（実際の終了日） |
| current_phase | VARCHAR(50) | NOT NULL | 現在フェーズ |
| phase_order | INT | NOT NULL | フェーズの順序番号（進捗管理用） |
| deal_amount | DECIMAL(15,2) | NULL | 受注金額（円） |
| is_active | BOOLEAN | NOT NULL | 進行中フラグ |
| is_won | BOOLEAN | NOT NULL | 受注済みフラグ |
| is_lost | BOOLEAN | NOT NULL | 失注フラグ |
| duration_days | INT | NULL | 案件期間（開始日〜終了日の日数） |
| days_in_current_phase | INT | NULL | 現フェーズでの滞留日数（日次バッチで更新） |
| dbt_updated_at | TIMESTAMP | NOT NULL | dbt による最終処理日時 |

---

## 5. マートテーブル定義

### 5.1 mart_sales_summary（売上サマリ）

**目的**: 経営層向けの月次・四半期・年次の売上集計サマリ。Power BIの主要ページで直接参照する。

**materialization**: `table`（日次フル再構築）

**粒度**: 年 × 月 × 顧客 × 担当者 × 業種 の集計（事前集計で Power BI の応答速度を確保）

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| summary_key | BIGINT | NOT NULL | サロゲートキー（PK） |
| fiscal_year | INT | NOT NULL | 会計年度 |
| fiscal_quarter | INT | NOT NULL | 会計四半期 |
| year | INT | NOT NULL | カレンダー年 |
| month | INT | NOT NULL | カレンダー月 |
| month_label | VARCHAR(10) | NOT NULL | 月ラベル（表示用） |
| customer_key | INT | NOT NULL | dim_customer への FK |
| staff_key | INT | NOT NULL | dim_staff への FK |
| industry_code | VARCHAR(10) | NOT NULL | 業種コード（集計軸） |
| estimate_count | INT | NOT NULL | 見積件数（当月作成） |
| won_count | INT | NOT NULL | 受注件数 |
| lost_count | INT | NOT NULL | 失注件数 |
| active_count | INT | NOT NULL | 進行中件数 |
| total_estimate_amount | DECIMAL(15,2) | NOT NULL | 見積金額合計 |
| won_amount | DECIMAL(15,2) | NOT NULL | 受注金額合計 |
| win_rate | DECIMAL(5,4) | NULL | 受注率（won_count / (won_count + lost_count)） |
| avg_estimate_amount | DECIMAL(15,2) | NULL | 平均見積金額 |
| avg_days_to_close | DECIMAL(8,2) | NULL | 平均クローズ日数 |

---

### 5.2 mart_conversion_funnel（コンバージョンファネル）

**目的**: 見積→受注のファネル分析。ステータス遷移の件数・金額・転換率を提供する。

**materialization**: `table`（日次フル再構築）

**粒度**: 年 × 月 × ファネルステージ × 業種

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| funnel_key | BIGINT | NOT NULL | サロゲートキー（PK） |
| fiscal_year | INT | NOT NULL | 会計年度 |
| fiscal_quarter | INT | NOT NULL | 会計四半期 |
| year | INT | NOT NULL | カレンダー年 |
| month | INT | NOT NULL | カレンダー月 |
| industry_code | VARCHAR(10) | NOT NULL | 業種コード |
| stage_name | VARCHAR(50) | NOT NULL | ファネルステージ名（作成/提出/交渉/受注/失注） |
| stage_order | INT | NOT NULL | ステージ順序番号 |
| stage_count | INT | NOT NULL | 当ステージに到達した見積件数 |
| stage_amount | DECIMAL(15,2) | NOT NULL | 当ステージの見積金額合計 |
| conversion_rate_to_next | DECIMAL(5,4) | NULL | 次ステージへの転換率 |
| drop_off_count | INT | NULL | 当ステージで離脱した件数 |
| drop_off_amount | DECIMAL(15,2) | NULL | 当ステージで離脱した金額合計 |

**ファネルステージ定義**:
```
Stage 1: 見積作成    （全ての見積）
Stage 2: 見積提出    （ステータス = '提出済' 以降）
Stage 3: 交渉・検討  （ステータス = '交渉中' または '保留'）
Stage 4: 受注        （ステータス = '受注'）
Stage 5: 失注        （ステータス = '失注'）
```

---

### 5.3 mart_phase_analysis（フェーズ滞留分析）

**目的**: 案件のフェーズ別滞留日数の集計。ボトルネックフェーズの特定に使用する。

**materialization**: `table`（日次フル再構築）

**粒度**: 年 × 月 × フェーズ × 担当者

| カラム名 | 型 | NULL | 説明 |
|----------|-----|------|------|
| analysis_key | BIGINT | NOT NULL | サロゲートキー（PK） |
| fiscal_year | INT | NOT NULL | 会計年度 |
| fiscal_quarter | INT | NOT NULL | 会計四半期 |
| year | INT | NOT NULL | カレンダー年 |
| month | INT | NOT NULL | カレンダー月 |
| phase_name | VARCHAR(50) | NOT NULL | フェーズ名 |
| phase_order | INT | NOT NULL | フェーズ順序番号 |
| staff_key | INT | NOT NULL | dim_staff への FK |
| deal_count | INT | NOT NULL | 当フェーズに存在する案件件数 |
| total_amount | DECIMAL(15,2) | NOT NULL | 当フェーズの案件金額合計 |
| avg_days_in_phase | DECIMAL(8,2) | NULL | 平均滞留日数 |
| median_days_in_phase | DECIMAL(8,2) | NULL | 中央値滞留日数 |
| max_days_in_phase | INT | NULL | 最大滞留日数 |
| overdue_count | INT | NOT NULL | SLA超過案件件数（phase_sla_daysを超えた件数） |
| overdue_amount | DECIMAL(15,2) | NOT NULL | SLA超過案件の金額合計 |
| overdue_rate | DECIMAL(5,4) | NULL | SLA超過率（overdue_count / deal_count） |

**フェーズ定義**（A社案件管理リストに合わせて調整が必要）:
```
Phase 1: 初期ヒアリング  SLA目安: 7日
Phase 2: 提案書作成     SLA目安: 14日
Phase 3: 提案・プレゼン  SLA目安: 21日
Phase 4: 価格交渉       SLA目安: 14日
Phase 5: 契約締結       SLA目安: 7日
```

---

## 6. dbt 実装指針

### 6.1 ディレクトリ構成

```
dbt_project/
├── models/
│   ├── staging/          # Silver層対応（stg_* プレフィックス）
│   │   ├── stg_estimates.sql
│   │   ├── stg_deals.sql
│   │   ├── stg_customers.sql
│   │   └── stg_staff.sql
│   ├── dimensions/       # Gold ディメンション
│   │   ├── dim_customer.sql
│   │   ├── dim_staff.sql
│   │   └── dim_date.sql  （シードCSVから生成）
│   ├── facts/            # Gold ファクト
│   │   ├── fact_estimates.sql
│   │   └── fact_deals.sql
│   └── marts/            # Gold マート
│       ├── mart_sales_summary.sql
│       ├── mart_conversion_funnel.sql
│       └── mart_phase_analysis.sql
├── seeds/
│   └── dim_date_seed.csv
└── tests/
    ├── not_null_tests.yml
    └── referential_integrity_tests.yml
```

### 6.2 materialization 方針サマリ

| モデル | materialization | 理由 |
|--------|----------------|------|
| dim_customer | table | 件数が少なく日次フル更新が低コスト。SCD Type 2 処理を含む |
| dim_staff | table | 同上。匿名化処理をここで確定する |
| dim_date | table | 静的データ。シードから1回生成すれば変更なし |
| fact_estimates | incremental | 累積データ。updated_at を使った差分処理で日次負荷を軽減 |
| fact_deals | incremental | 同上 |
| mart_sales_summary | table | 全期間の集計。インクリメンタルの整合性維持が複雑なためフル再構築 |
| mart_conversion_funnel | table | 同上 |
| mart_phase_analysis | table | 同上 |

### 6.3 テスト方針

```yaml
# 必須テスト（全テーブル共通）
- not_null: 全PK・FK・主要メジャー
- unique: 全PK
- accepted_values: ステータス・フラグ系カラム

# 参照整合性テスト
- relationships:
    fact_estimates.customer_key → dim_customer.customer_key
    fact_estimates.staff_key → dim_staff.staff_key
    fact_estimates.created_date_key → dim_date.date_key
    fact_deals.customer_key → dim_customer.customer_key
    fact_deals.staff_key → dim_staff.staff_key
```

### 6.4 インクリメンタル処理の実装例（fact_estimates）

```sql
-- models/facts/fact_estimates.sql
{{
  config(
    materialized='incremental',
    unique_key='estimate_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
  )
}}

WITH source AS (
  SELECT * FROM {{ ref('stg_estimates') }}
  {% if is_incremental() %}
    -- 差分取込: 前回処理時刻以降に更新されたレコードのみ
    WHERE updated_at > (SELECT MAX(dbt_updated_at) FROM {{ this }})
  {% endif %}
),
enriched AS (
  SELECT
    {{ dbt_utils.generate_surrogate_key(['estimate_id']) }} AS estimate_key,
    e.estimate_id,
    dc.customer_key,
    ds.staff_key,
    TO_NUMBER(TO_CHAR(e.created_date, 'YYYYMMDD')) AS created_date_key,
    -- ...（他カラム）
    CURRENT_TIMESTAMP AS dbt_updated_at
  FROM source e
  LEFT JOIN {{ ref('dim_customer') }} dc USING (customer_code)
  LEFT JOIN {{ ref('dim_staff') }} ds USING (employee_id)
)
SELECT * FROM enriched
```
