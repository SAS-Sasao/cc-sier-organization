# A社基幹システム DWH データ品質ルール定義書

| 項目 | 内容 |
|------|------|
| クライアント | A社（製造業・中堅企業） |
| バージョン | 1.0.0 |
| 作成日 | 2026-03-18 |
| ステータス | 初版 |
| 関連文書 | medallion-architecture.md, data-models.md |

---

## 1. データ品質フレームワーク

### 1.1 品質次元の定義

本DWHでは以下の6つの品質次元でデータ品質を管理する。

| 品質次元 | 定義 | 主な適用層 |
|----------|------|-----------|
| 完全性 (Completeness) | 必要なデータが欠損なく存在するか | Bronze, Silver |
| 正確性 (Accuracy) | データが現実を正しく反映しているか | Silver, Gold |
| 一貫性 (Consistency) | 同一データが複数箇所で矛盾しないか | Silver, Gold |
| 適時性 (Timeliness) | データが期待する鮮度で提供されているか | Bronze |
| 一意性 (Uniqueness) | 重複レコードが存在しないか | Silver, Gold |
| 妥当性 (Validity) | データが定義済みの形式・範囲に適合するか | Silver, Gold |

### 1.2 品質レベルの定義

| レベル | 名称 | 判定条件 | アクション |
|--------|------|----------|------------|
| CRITICAL | 致命的 | パイプライン停止が必要 | 後続処理を停止。即時アラート |
| ERROR | エラー | 不正データが下流に影響する可能性 | 該当テーブルの更新を停止。アラート |
| WARNING | 警告 | 品質劣化の兆候 | ログ記録。ダッシュボードに表示 |
| INFO | 情報 | 統計的な観測値 | ログ記録のみ |

### 1.3 実装手段

| 手段 | 用途 | 実行タイミング |
|------|------|---------------|
| dbt tests (schema tests) | 一意性、NOT NULL、参照整合性、許容値チェック | dbt run 後（dbt test） |
| dbt tests (custom generic tests) | カスタムビジネスルール | dbt run 後（dbt test） |
| dbt source freshness | ソースデータの鮮度チェック | dbt source freshness |
| Great Expectations (オプション) | 統計的品質チェック | パイプライン内で実行 |
| ADF パイプラインチェック | 取り込みレコード件数チェック | ADF パイプライン内 |

---

## 2. Bronze 層品質ルール

Bronze層はソースデータの「完全な取り込み」を保証する層。データの中身は変更しない。

### 2.1 取り込み完全性チェック

| ルールID | ルール名 | 対象 | 条件 | レベル | 説明 |
|----------|----------|------|------|--------|------|
| BRZ-001 | 取り込みレコード件数チェック | 全テーブル | 取り込み件数 = 0（差分取り込みで変更あり想定時） | WARNING | 前日に更新があったはずのリストから0件取り込みの場合、接続障害の可能性 |
| BRZ-002 | レコード件数急増チェック | 全テーブル | 取り込み件数 > 前日比 500% | WARNING | 大量データの意図しない取り込みを検知 |
| BRZ-003 | レコード件数急減チェック | 全テーブル | 前回フル件数比 50% 未満（フルスキャン時） | ERROR | ソースリストでの大量削除を検知 |
| BRZ-004 | 主キー NOT NULL | 全テーブル | 主キーカラムが NULL | CRITICAL | ソース側のデータ不備。該当レコードを隔離 |
| BRZ-005 | パイプライン実行完了 | 全テーブル | ADF パイプラインが ERROR 終了 | CRITICAL | パイプライン停止。自動リトライ後アラート |

### 2.2 鮮度チェック

| ルールID | ルール名 | 対象 | 条件 | レベル | 説明 |
|----------|----------|------|------|--------|------|
| BRZ-006 | ソース鮮度チェック | 全テーブル | 最新の `_ingestion_timestamp` が 28時間以上前 | ERROR | 日次バッチが実行されていない可能性 |
| BRZ-007 | SLA 遵守チェック | パイプライン全体 | AM 9:00 JST までに Bronze 取り込み未完了 | CRITICAL | SLA 違反。エスカレーション |

### 2.3 dbt source 定義（実装例）

```yaml
# models/staging/src_sharepoint.yml
sources:
  - name: bronze
    database: "{{ var('bronze_database') }}"
    schema: sharepoint
    freshness:
      warn_after:
        count: 24
        period: hour
      error_after:
        count: 28
        period: hour
    loaded_at_field: _ingestion_timestamp

    tables:
      - name: brz_estimates
        identifier: brz_estimates
        columns:
          - name: estimate_number
            tests:
              - not_null:
                  severity: error
                  config:
                    where: "_ingestion_date = CURRENT_DATE"

      - name: brz_projects
        identifier: brz_projects
        columns:
          - name: project_number
            tests:
              - not_null:
                  severity: error
                  config:
                    where: "_ingestion_date = CURRENT_DATE"

      - name: brz_customers
        identifier: brz_customers
        columns:
          - name: customer_code
            tests:
              - not_null:
                  severity: error
                  config:
                    where: "_ingestion_date = CURRENT_DATE"

      - name: brz_employees
        identifier: brz_employees
        columns:
          - name: employee_number
            tests:
              - not_null:
                  severity: error
                  config:
                    where: "_ingestion_date = CURRENT_DATE"
```

---

## 3. Silver 層品質ルール

Silver層はデータのクレンジング・正規化が正しく行われたことを検証する層。

### 3.1 一意性チェック

| ルールID | ルール名 | 対象テーブル | 条件 | レベル | 説明 |
|----------|----------|-------------|------|--------|------|
| SLV-001 | 見積番号一意性 | slv_estimates | `estimate_number` が重複 | ERROR | 重複排除ロジックの不備 |
| SLV-002 | 案件番号一意性 | slv_projects | `project_number` が重複 | ERROR | 重複排除ロジックの不備 |
| SLV-003 | 顧客コード現行一意性 | slv_customers | `customer_code` WHERE `_is_current = true` が重複 | CRITICAL | SCD Type 2 ロジック不備 |
| SLV-004 | 社員番号現行一意性 | slv_employees | `employee_number` WHERE `_is_current = true` が重複 | CRITICAL | SCD Type 2 ロジック不備 |

### 3.2 NOT NULL チェック

| ルールID | ルール名 | 対象テーブル | 対象カラム | レベル | 説明 |
|----------|----------|-------------|-----------|--------|------|
| SLV-010 | 見積番号 NOT NULL | slv_estimates | estimate_number | CRITICAL | ビジネスキーの欠損 |
| SLV-011 | 見積金額 NOT NULL | slv_estimates | amount | ERROR | 金額未変換（変換ロジック不備） |
| SLV-012 | 見積ステータス NOT NULL | slv_estimates | status_code, status_name | ERROR | ステータス正規化失敗 |
| SLV-013 | 案件番号 NOT NULL | slv_projects | project_number | CRITICAL | ビジネスキーの欠損 |
| SLV-014 | 案件フェーズ NOT NULL | slv_projects | phase_code, phase_name | ERROR | フェーズ正規化失敗 |
| SLV-015 | 顧客コード NOT NULL | slv_customers | customer_code | CRITICAL | ビジネスキーの欠損 |
| SLV-016 | 社員番号 NOT NULL | slv_employees | employee_number | CRITICAL | ビジネスキーの欠損 |
| SLV-017 | SCD有効期間 NOT NULL | slv_customers, slv_employees | _valid_from, _valid_to, _is_current | CRITICAL | SCD メタデータ不備 |

### 3.3 妥当性チェック（値の範囲・形式）

| ルールID | ルール名 | 対象テーブル | 条件 | レベル | 説明 |
|----------|----------|-------------|------|--------|------|
| SLV-020 | 見積金額正値 | slv_estimates | `amount < 0` | WARNING | 負の金額は通常ありえない（返金等の特殊ケース除く） |
| SLV-021 | 見積金額上限 | slv_estimates | `amount > 1,000,000,000`（10億円超） | WARNING | 異常値の可能性。手動確認を促す |
| SLV-022 | ステータスコード許容値 | slv_estimates | `status_code NOT IN (10, 20, 30, 40, 50, 90)` | ERROR | 未定義のステータスコード |
| SLV-023 | フェーズコード許容値 | slv_projects | `phase_code NOT IN (10, 20, 30, 40, 50, 60, 70, 80, 90)` | ERROR | 未定義のフェーズコード |
| SLV-024 | 受注金額正値 | slv_projects | `contract_amount < 0` | WARNING | 負の金額は通常ありえない |
| SLV-025 | 日付妥当性（作成日） | slv_estimates | `created_at > CURRENT_TIMESTAMP` | WARNING | 未来日の作成日 |
| SLV-026 | 日付妥当性（期間） | slv_projects | `start_date > end_date` | WARNING | 開始日が終了日より後 |
| SLV-027 | 期間妥当性 | slv_projects | `duration_days > 1825`（5年超） | WARNING | 異常に長い案件期間 |
| SLV-028 | 業種コード許容値 | slv_customers | `industry_code NOT IN ('MFG','WHL','RTL','ICT','CNS','SVC','OTH','UNK')` | ERROR | 未定義の業種コード |
| SLV-029 | 契約ステータス許容値 | slv_customers | `contract_status NOT IN ('ACTIVE','INACTIVE','SUSPENDED')` | ERROR | 未定義の契約ステータス |
| SLV-030 | ハッシュ値存在チェック | slv_employees | `employee_name_hash IS NULL OR LENGTH(employee_name_hash) != 64` | ERROR | SHA-256ハッシュの生成失敗 |

### 3.4 一貫性チェック（テーブル間整合性）

| ルールID | ルール名 | 対象 | 条件 | レベル | 説明 |
|----------|----------|------|------|--------|------|
| SLV-040 | 見積-顧客参照整合性 | slv_estimates | `customer_name` が `slv_customers` に存在しない | WARNING | 顧客マスタ未登録の顧客名（名寄せ不備の可能性） |
| SLV-041 | 見積-担当者参照整合性 | slv_estimates | `assigned_to` が `slv_employees` に存在しない | WARNING | 担当者マスタ未登録の担当者（表記揺れの可能性） |
| SLV-042 | 案件-顧客参照整合性 | slv_projects | `customer_name` が `slv_customers` に存在しない | WARNING | 顧客マスタ未登録の顧客名 |
| SLV-043 | SCD有効期間整合性 | slv_customers, slv_employees | 同一ビジネスキーの有効期間が重複 | CRITICAL | SCD Type 2 の有効期間に隙間・重複がある |

### 3.5 dbt test 定義（実装例）

```yaml
# models/silver/schema.yml
models:
  - name: slv_estimates
    description: "見積管理テーブル（クレンジング済み）"
    columns:
      - name: estimate_number
        tests:
          - unique
          - not_null
      - name: amount
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1000000000
              severity: warn
      - name: status_code
        tests:
          - not_null
          - accepted_values:
              values: [10, 20, 30, 40, 50, 90]
      - name: created_at
        tests:
          - dbt_utils.expression_is_true:
              expression: "<= CURRENT_TIMESTAMP"
              severity: warn

  - name: slv_projects
    description: "案件管理テーブル（クレンジング済み）"
    columns:
      - name: project_number
        tests:
          - unique
          - not_null
      - name: phase_code
        tests:
          - not_null
          - accepted_values:
              values: [10, 20, 30, 40, 50, 60, 70, 80, 90]
      - name: contract_amount
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              severity: warn
    tests:
      - dbt_utils.expression_is_true:
          expression: "start_date <= end_date OR start_date IS NULL OR end_date IS NULL"
          severity: warn

  - name: slv_customers
    description: "顧客マスタテーブル（SCD Type 2）"
    columns:
      - name: customer_sk
        tests:
          - unique
          - not_null
      - name: customer_code
        tests:
          - not_null
      - name: industry_code
        tests:
          - accepted_values:
              values: ['MFG', 'WHL', 'RTL', 'ICT', 'CNS', 'SVC', 'OTH', 'UNK']
              severity: error
      - name: contract_status
        tests:
          - accepted_values:
              values: ['ACTIVE', 'INACTIVE', 'SUSPENDED']
              severity: error
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - customer_code
            - _valid_from

  - name: slv_employees
    description: "担当者マスタテーブル（SCD Type 2）"
    columns:
      - name: employee_sk
        tests:
          - unique
          - not_null
      - name: employee_number
        tests:
          - not_null
      - name: employee_name_hash
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: "LENGTH(employee_name_hash) = 64"
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - employee_number
            - _valid_from
```

---

## 4. Gold 層品質ルール

Gold層は分析結果の信頼性を担保する最終防衛ライン。

### 4.1 参照整合性チェック

| ルールID | ルール名 | 対象テーブル | 条件 | レベル | 説明 |
|----------|----------|-------------|------|--------|------|
| GLD-001 | 見積-顧客FK整合性 | fact_estimates | `customer_key` が `dim_customer` に存在しない | CRITICAL | ディメンションルックアップ失敗 |
| GLD-002 | 見積-担当者FK整合性 | fact_estimates | `employee_key` が `dim_employee` に存在しない（NULLを除く） | ERROR | ディメンションルックアップ失敗 |
| GLD-003 | 見積-日付FK整合性 | fact_estimates | `created_date_key` / `modified_date_key` が `dim_date` に存在しない（NULLを除く） | ERROR | 日付ディメンション範囲外 |
| GLD-004 | 見積-ステータスFK整合性 | fact_estimates | `status_key` が `dim_status` に存在しない | CRITICAL | ステータスディメンション不整合 |
| GLD-005 | 案件-顧客FK整合性 | fact_projects | `customer_key` が `dim_customer` に存在しない | CRITICAL | ディメンションルックアップ失敗 |
| GLD-006 | 案件-日付FK整合性 | fact_projects | `start_date_key` / `end_date_key` が `dim_date` に存在しない（NULLを除く） | ERROR | 日付ディメンション範囲外 |
| GLD-007 | 案件-ステータスFK整合性 | fact_projects | `status_key` が `dim_status` に存在しない | CRITICAL | ステータスディメンション不整合 |

### 4.2 一意性チェック

| ルールID | ルール名 | 対象テーブル | 条件 | レベル | 説明 |
|----------|----------|-------------|------|--------|------|
| GLD-010 | 見積ファクトPK一意性 | fact_estimates | `estimate_fact_key` が重複 | CRITICAL | PK重複 |
| GLD-011 | 案件ファクトPK一意性 | fact_projects | `project_fact_key` が重複 | CRITICAL | PK重複 |
| GLD-012 | 見積番号一意性 | fact_estimates | `estimate_number` が重複 | CRITICAL | 同一見積が複数ファクト行に |
| GLD-013 | 案件番号一意性 | fact_projects | `project_number` が重複 | CRITICAL | 同一案件が複数ファクト行に |
| GLD-014 | 日付ディメンションPK一意性 | dim_date | `date_key` が重複 | CRITICAL | カレンダー生成ロジック不備 |
| GLD-015 | 顧客ディメンションPK一意性 | dim_customer | `customer_key` が重複 | CRITICAL | SCD現行フィルター不備 |
| GLD-016 | ステータスディメンションPK一意性 | dim_status | `status_key` が重複 | CRITICAL | seed データ不備 |

### 4.3 ビジネスルールチェック

| ルールID | ルール名 | 対象テーブル | 条件 | レベル | 説明 |
|----------|----------|-------------|------|--------|------|
| GLD-020 | 受注フラグ整合性 | fact_estimates | `is_won = true` かつ `status_key` が WON 以外を指す | ERROR | フラグとステータスの不整合 |
| GLD-021 | 失注フラグ整合性 | fact_estimates | `is_lost = true` かつ `status_key` が LOST 以外を指す | ERROR | フラグとステータスの不整合 |
| GLD-022 | オープンフラグ整合性 | fact_estimates | `is_open = true` かつ `status_key` が終端ステータスを指す | ERROR | フラグとステータスの不整合 |
| GLD-023 | 受注率範囲 | agg_monthly_sales_summary | `win_rate < 0 OR win_rate > 100` | ERROR | 受注率が0-100%の範囲外 |
| GLD-024 | 件数整合性 | agg_monthly_sales_summary | `won_count + lost_count + open_count != total_estimates` | WARNING | 件数の不整合（タイミング差の可能性あり） |
| GLD-025 | フェーズ順序整合性 | agg_phase_duration | 完了フェーズの案件が前フェーズに存在 | INFO | フェーズスキップの検知（観測用） |
| GLD-026 | 転換率範囲 | agg_conversion_funnel | `conversion_rate < 0 OR conversion_rate > 100` | ERROR | 転換率が0-100%の範囲外 |
| GLD-027 | 滞留日数妥当性 | agg_phase_duration | `avg_duration_days > 365` | WARNING | 平均滞留日数が1年超（異常値の可能性） |
| GLD-028 | 案件アクティブフラグ整合性 | fact_projects | `is_active = true` かつ `status_key` が完了/中止を指す | ERROR | フラグとステータスの不整合 |

### 4.4 dbt test 定義（実装例）

```yaml
# models/gold/schema.yml
models:
  - name: fact_estimates
    description: "見積ファクトテーブル"
    columns:
      - name: estimate_fact_key
        tests:
          - unique
          - not_null
      - name: estimate_number
        tests:
          - unique
          - not_null
      - name: customer_key
        tests:
          - not_null
          - relationships:
              to: ref('dim_customer')
              field: customer_key
      - name: employee_key
        tests:
          - relationships:
              to: ref('dim_employee')
              field: employee_key
              config:
                where: "employee_key IS NOT NULL"
      - name: status_key
        tests:
          - not_null
          - relationships:
              to: ref('dim_status')
              field: status_key
      - name: created_date_key
        tests:
          - relationships:
              to: ref('dim_date')
              field: date_key
              config:
                where: "created_date_key IS NOT NULL"
    tests:
      - dbt_utils.expression_is_true:
          expression: "NOT (is_won = true AND is_lost = true)"
          name: "mutually_exclusive_won_lost"
      - dbt_utils.expression_is_true:
          expression: "NOT (is_open = true AND (is_won = true OR is_lost = true))"
          name: "open_excludes_terminal"

  - name: fact_projects
    description: "案件ファクトテーブル"
    columns:
      - name: project_fact_key
        tests:
          - unique
          - not_null
      - name: project_number
        tests:
          - unique
          - not_null
      - name: customer_key
        tests:
          - not_null
          - relationships:
              to: ref('dim_customer')
              field: customer_key
      - name: status_key
        tests:
          - not_null
          - relationships:
              to: ref('dim_status')
              field: status_key

  - name: dim_date
    columns:
      - name: date_key
        tests:
          - unique
          - not_null

  - name: dim_customer
    columns:
      - name: customer_key
        tests:
          - unique
          - not_null

  - name: dim_status
    columns:
      - name: status_key
        tests:
          - unique
          - not_null

  - name: agg_monthly_sales_summary
    tests:
      - dbt_utils.expression_is_true:
          expression: "win_rate >= 0 AND win_rate <= 100"
          config:
            where: "win_rate IS NOT NULL"
      - dbt_utils.expression_is_true:
          expression: "total_estimates >= 0"
```

---

## 5. 匿名化ルール

### 5.1 概要

個人情報保護の観点から、担当者の氏名について匿名化オプションを提供する。
匿名化は Gold 層のビュー（`dim_employee_anonymized`）で実現し、元データは Silver 層に保持する。

### 5.2 匿名化対象

| 対象テーブル | 対象カラム | 匿名化方式 | 匿名化後の値 |
|-------------|-----------|------------|-------------|
| dim_employee_anonymized | employee_name | SHA-256 ハッシュの先頭4文字 | `担当者_` + hash先頭4文字（例: `担当者_a3f2`） |

### 5.3 匿名化ルール詳細

| ルールID | ルール名 | 内容 |
|----------|----------|------|
| ANM-001 | ハッシュ一貫性 | 同一氏名は常に同一ハッシュを返す（ソルトは環境変数 `ANONYMIZATION_SALT` で管理） |
| ANM-002 | 不可逆性 | ハッシュから元の氏名を復元できないこと |
| ANM-003 | 衝突耐性 | SHA-256先頭4文字（16^4 = 65,536通り）。担当者数が数百人規模の場合、衝突確率は十分低い |
| ANM-004 | ソルト管理 | ソルトは Azure Key Vault で管理。環境ごとに異なるソルトを使用 |
| ANM-005 | 匿名化ビュー切替 | Power BI の Row-Level Security (RLS) で閲覧者のロールに応じて通常ビュー/匿名化ビューを切り替え |

### 5.4 匿名化実装

#### Silver 層でのハッシュ生成

```sql
-- slv_employees の employee_name_hash 生成ロジック
SHA2(
    CONCAT(
        COALESCE(employee_name, ''),
        '||',
        '{{ var("anonymization_salt") }}'
    ),
    256
) AS employee_name_hash
```

#### Gold 層での匿名化ビュー

```sql
-- dim_employee_anonymized ビュー
SELECT
    employee_sk AS employee_key,
    employee_number,
    CONCAT('担当者_', LEFT(employee_name_hash, 4)) AS employee_name_masked,
    department,
    job_title
FROM {{ ref('slv_employees') }}
WHERE _is_current = true
```

### 5.5 匿名化品質チェック

| ルールID | ルール名 | 条件 | レベル | 説明 |
|----------|----------|------|--------|------|
| ANM-010 | 匿名化ビュー氏名漏洩 | `dim_employee_anonymized` に実際の氏名が含まれている | CRITICAL | 匿名化が適用されていない |
| ANM-011 | ハッシュ値一貫性 | 同一 `employee_number` に対して異なるバッチで異なるハッシュが生成される | ERROR | ソルト変更またはロジック不備 |
| ANM-012 | ハッシュ衝突検知 | 異なる `employee_number` で同一の `employee_name_masked` が存在 | WARNING | 衝突発生。先頭桁数の拡張を検討 |

---

## 6. 異常検知の閾値定義

### 6.1 レコード件数ベースの異常検知

| 検知ID | 対象 | 指標 | 閾値 | レベル | 対応 |
|--------|------|------|------|--------|------|
| ADT-001 | Bronze全テーブル | 日次取り込み件数 | 前日比 +500% / -50% | WARNING | 手動確認。ソース側の変更を調査 |
| ADT-002 | Silver全テーブル | 変換後レコード件数 | Bronze取り込み件数の90%未満 | WARNING | 変換ロジックでの大量フィルタを調査 |
| ADT-003 | Gold ファクトテーブル | レコード件数 | Silver件数との乖離 5%超 | WARNING | ディメンションルックアップ失敗の可能性 |

### 6.2 データ値ベースの異常検知

| 検知ID | 対象 | 指標 | 閾値 | レベル | 対応 |
|--------|------|------|------|--------|------|
| ADT-010 | slv_estimates | 金額の平均値 | 過去30日移動平均の 3σ 逸脱 | WARNING | 異常な高額/低額見積の混入を調査 |
| ADT-011 | slv_estimates | NULL率（担当者） | 20% 超過 | WARNING | ソースデータの入力漏れ傾向を報告 |
| ADT-012 | slv_estimates | 未定義ステータス率 | 5% 超過 | ERROR | ソース側で新ステータスが追加された可能性 |
| ADT-013 | slv_projects | 金額の平均値 | 過去30日移動平均の 3σ 逸脱 | WARNING | 異常な高額/低額案件の混入を調査 |
| ADT-014 | slv_projects | フェーズ滞留日数 | 90日超（PLANNING, REQUIREMENTS 以外） | WARNING | プロジェクト停滞の可能性を報告 |
| ADT-015 | slv_customers | 新規顧客急増 | 1日あたり新規10件超 | INFO | マスタデータの大量一括登録を検知 |

### 6.3 トレンドベースの異常検知

| 検知ID | 対象 | 指標 | 閾値 | レベル | 対応 |
|--------|------|------|------|--------|------|
| ADT-020 | agg_monthly_sales_summary | 月次受注率 | 前月比 -20pt 以上低下 | WARNING | ビジネス側への確認（市場変動 or データ品質） |
| ADT-021 | agg_monthly_sales_summary | 月次見積件数 | 前月比 -50% | WARNING | ソースデータの入力遅延 or ビジネス変動 |
| ADT-022 | agg_conversion_funnel | ファネル逆転 | 下流ステータスの件数が上流を超える | ERROR | ステータス遷移ルールの不備 |

---

## 7. 品質モニタリングダッシュボード

### 7.1 品質スコアカード

各テーブルに対して、以下の品質スコアを日次で算出する。

```
品質スコア = (合格したルール数 / 適用ルール総数) * 100
```

| 品質レベル | スコア範囲 | 表示 | アクション |
|-----------|-----------|------|------------|
| Excellent | 98-100% | 緑 | なし |
| Good | 95-97% | 黄緑 | なし |
| Acceptable | 90-94% | 黄 | 原因調査 |
| Poor | 80-89% | オレンジ | 改善計画策定 |
| Critical | 80%未満 | 赤 | 即時対応 |

### 7.2 モニタリング項目

| ダッシュボード | 表示内容 | 更新頻度 |
|---------------|----------|----------|
| パイプライン実行状況 | ADF/dbt の実行結果、所要時間 | 日次 |
| テーブル別品質スコア | 各テーブルの品質スコア推移 | 日次 |
| ルール別違反件数 | 違反が多いルールのランキング | 日次 |
| 鮮度状況 | 各テーブルの最終更新日時 | リアルタイム |
| 異常検知アラート | 閾値超過の検知履歴 | 日次 |

---

## 8. 品質ルール運用ガイドライン

### 8.1 新規ルール追加プロセス

1. 品質問題の発見・報告
2. 根本原因の分析
3. ルールの定義（ルールID、対象、条件、レベル）
4. dbt test への実装
5. テスト環境での検証
6. 本番適用・モニタリング開始

### 8.2 ルールの見直し

- **四半期レビュー**: 全ルールの有効性を確認。誤検知が多いルールは閾値を調整
- **インシデント後**: データ品質インシデント発生時に再発防止ルールを追加
- **ソース変更時**: SharePoint リストのスキーマ変更時に影響ルールを更新

### 8.3 例外処理

品質チェックに意図的に違反するデータ（ビジネス上の正当な理由がある場合）は、
dbt test の `where` 句で除外条件を明示し、除外理由をコメントとして記録する。

```yaml
# 例: 特定の見積番号を品質チェックから除外
- dbt_utils.expression_is_true:
    expression: "amount >= 0"
    config:
      where: "estimate_number NOT IN ('EST-2025-SPECIAL-001')"  # 返金処理のため負の金額を許容
    severity: warn
```
