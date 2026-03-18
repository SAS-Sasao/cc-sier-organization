# データパイプライン設計書

## 文書情報

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-03-18 |
| 対象案件 | A社基幹システムDWH構築 |
| クライアント | A社（製造業・中堅企業） |
| DWHプラットフォーム | Azure Synapse Analytics |
| 作成者 | クラウドエンジニア |
| ステータス | 初版ドラフト |

---

## 1. パイプライン全体アーキテクチャ

```
=============================================================
  データソース層（SharePoint Online）
=============================================================
  [見積管理リスト]  [案件管理リスト]  [顧客マスタ]  [担当者マスタ]
        |                 |               |              |
        +--------+--------+               +------+-------+
                 |                               |
                 | Microsoft Graph API v1.0       |
                 | (サービスプリンシパル認証)       |
                 +---------------+---------------+
                                 |
=============================================================
  オーケストレーション層（Azure Data Factory / Synapse Pipeline）
=============================================================
                                 |
                    [ADF パイプライン: spo_to_bronze]
                    ┌────────────────────────────────┐
                    │  1. Graph API 呼び出し           │
                    │  2. 差分フィルタ（更新日時）      │
                    │  3. JSON → Parquet 変換          │
                    │  4. ADLS Gen2 Bronze に書込み    │
                    └────────────────────────────────┘
                                 |
=============================================================
  ストレージ層（Azure Data Lake Storage Gen2）
=============================================================
  [Bronze層]                [Silver層]               [Gold層]
  /bronze/                  /silver/                 /gold/
  ├── estimates/            ├── dim_customers/       ├── fact_sales/
  ├── projects/             ├── dim_employees/       ├── dim_customers/
  ├── customers/            ├── fct_estimates/       ├── dim_employees/
  └── employees/            └── fct_projects/        └── rpt_monthly_kpi/
  (生JSON/Parquet)          (整形済みParquet)         (集計済みParquet)
        |                          |                        |
        |                          |                        |
=============================================================
  変換層（dbt on Azure Synapse Serverless SQL Pool）
=============================================================
        |                          |                        |
        +--------- [dbt run] ------+--------[dbt run]-------+
                    Bronze→Silver変換          Silver→Gold変換
                                 |
=============================================================
  分析・可視化層
=============================================================
                    [Azure Synapse Analytics]
                    ├── Serverless SQL Pool（dbt変換・アドホック）
                    └── [Power BI Service]
                           ├── DirectQuery（リアルタイム参照）
                           └── Import（パフォーマンス最適化）
=============================================================

スケジューリング概要:
  毎日 02:00 JST  → ADF パイプライン起動（SPO → Bronze）
  毎日 04:00 JST  → dbt run（Bronze → Silver → Gold）
  毎日 06:00 JST  → Power BI Dataset リフレッシュ
  → 翌朝 09:00 までに前日分反映完了
```

---

## 2. SharePoint Online → Bronze 層 取り込みパイプライン

### 2-1. API 選択: Microsoft Graph API v1.0

**選択理由:**

SharePoint Online のデータ取得には SharePoint REST API と Microsoft Graph API の2系統があるが、以下の理由から **Microsoft Graph API v1.0** を採用する。

| 比較観点 | SharePoint REST API | Microsoft Graph API v1.0 |
|----------|--------------------|-----------------------|
| 認証方式 | サービスプリンシパル対応（要設定） | サービスプリンシパル対応（標準） |
| Azure AD 統合 | 間接的 | ネイティブ |
| リスト取得エンドポイント | `/_api/lists/...` | `/v1.0/sites/{id}/lists/{id}/items` |
| delta クエリ（差分取得） | 非対応 | **対応**（$deltaToken） |
| ADF コネクタ | SharePoint Online リストコネクタ | HTTP コネクタ + ベアラートークン |
| 将来性 | 非推奨化の可能性あり | Microsoft 推奨 |

Graph API の delta クエリを使用することで、前回取得以降に変更されたアイテムのみを効率的に取得できる。

### 2-2. 認証方式: サービスプリンシパル（クライアント認証情報フロー）

```
認証フロー:
┌─────────────────────────────────────────────────────────┐
│  Azure Active Directory / Entra ID                      │
│                                                         │
│  サービスプリンシパル（App Registration）               │
│  ├── Application ID: {app-id}                           │
│  ├── Client Secret: ← Azure Key Vault で管理            │
│  └── API Permissions: Sites.Read.All (Application)      │
└─────────────────────────────────────────────────────────┘
         |
         | POST /oauth2/v2.0/token
         | (client_credentials フロー)
         v
┌─────────────────┐
│  Access Token   │
│  (Bearer Token) │
└─────────────────┘
         |
         v
┌─────────────────────────────────┐
│  Graph API                      │
│  GET /v1.0/sites/{id}/lists/... │
└─────────────────────────────────┘
```

**ADF での設定:**
- Linked Service: `Azure Key Vault` でクライアントシークレットを参照
- ADF Managed Identity と Key Vault のアクセスポリシーを組み合わせ
- シークレット文字列を ADF パイプライン上に直書きしない

**必要な API 権限:**
```
Microsoft Graph API Permissions:
  - Sites.Read.All (Application permission)
    ※ SharePoint リストの読み取りに必要
    ※ 「最小権限の原則」に従い Read.All に限定
```

### 2-3. 差分取り込み vs フル取り込み 戦略

#### 基本方針: **差分取り込みを主軸、月1回フル取り込みで整合性担保**

| ケース | 手法 | 対象 |
|--------|------|------|
| 日次（通常） | 差分取り込み（Graph API delta クエリ） | 全4リスト |
| 月次（1日）  | フル取り込み（洗い替え） | 全4リスト |
| 手動実行     | フル取り込み（パラメータ指定） | 任意リスト |

#### 差分取り込みの詳細（Graph API delta クエリ）

```
1回目（初回フル取得）:
  GET /v1.0/sites/{site-id}/lists/{list-id}/items/delta
  → 全件取得 + @odata.deltaLink を ADLS に保存

2回目以降（差分取得）:
  GET {deltaLink}  ← 前回保存した deltaLink を使用
  → 変更・追加・削除されたアイテムのみ取得
  → 新しい deltaLink を上書き保存

ファイルパス（ADLS Gen2）:
  /bronze/metadata/delta-tokens/
  ├── estimates_delta_token.txt
  ├── projects_delta_token.txt
  ├── customers_delta_token.txt
  └── employees_delta_token.txt
```

#### Bronze 層ファイル構成（パーティション戦略）

```
/bronze/
├── estimates/
│   ├── year=2026/month=03/day=17/
│   │   └── estimates_20260317_full.parquet      ← フル取得時
│   └── year=2026/month=03/day=18/
│       └── estimates_20260318_delta.parquet     ← 差分取得時
├── projects/
│   └── year=2026/month=03/day=18/
│       └── projects_20260318_delta.parquet
├── customers/
│   └── year=2026/month=03/day=18/
│       └── customers_20260318_delta.parquet
└── employees/
    └── year=2026/month=03/day=18/
        └── employees_20260318_delta.parquet
```

#### 削除レコードの扱い

Graph API delta クエリでは削除されたアイテムは `@removed` フラグ付きで返却される。Bronze 層では削除フラグを付けて保持し、Silver 層 dbt モデルで論理削除として処理する。

```json
// Graph API delta レスポンス例（削除アイテム）
{
  "id": "123",
  "@removed": { "reason": "deleted" }
}
```

### 2-4. スケジューリング設計

```
スケジュール（JST）:

02:00  ADF トリガー起動
  ├── パイプライン: spo_to_bronze_trigger
  │   ├── Activity 1: Get Token from Key Vault
  │   ├── Activity 2: ForEach List（4リスト並列実行）
  │   │   ├── [見積管理] Graph API delta → Parquet → ADLS
  │   │   ├── [案件管理] Graph API delta → Parquet → ADLS
  │   │   ├── [顧客マスタ] Graph API delta → Parquet → ADLS
  │   │   └── [担当者マスタ] Graph API delta → Parquet → ADLS
  │   ├── Activity 3: 取り込み件数ログ出力
  │   └── Activity 4: 成功通知（Teams Webhook）
  │
  ├── 推定所要時間: 30〜60分（データ量による）
  └── 完了目標: 03:00 JST

04:00  dbt run 起動（Synapse Serverless SQL Pool）
  ├── dbt run --select bronze_to_silver  → Silver 層生成
  ├── dbt run --select silver_to_gold    → Gold 層生成
  ├── dbt test                           → データ品質チェック
  └── 完了目標: 06:00 JST

06:00  Power BI Dataset リフレッシュ（Power BI REST API）
  └── 完了目標: 08:00 JST（翌朝09:00の1時間前に完了）

バッファ: 08:00〜09:00（異常時のリトライ・手動対応時間）
```

---

## 3. Bronze → Silver → Gold dbt 変換パイプライン

### 3-1. dbt プロジェクト構成

```
dbt_project/
├── dbt_project.yml
├── profiles.yml          ← Synapse Serverless SQL Pool 接続設定
├── packages.yml          ← dbt_utils 等の依存パッケージ
│
├── models/
│   ├── bronze/           ← Bronze層（生データの外部テーブル定義）
│   │   ├── _schema.yml
│   │   ├── brz_estimates.sql
│   │   ├── brz_projects.sql
│   │   ├── brz_customers.sql
│   │   └── brz_employees.sql
│   │
│   ├── silver/           ← Silver層（整形・クレンジング）
│   │   ├── _schema.yml
│   │   ├── stg_estimates.sql
│   │   ├── stg_projects.sql
│   │   ├── dim_customers.sql
│   │   └── dim_employees.sql
│   │
│   └── gold/             ← Gold層（BI用集計・KPI）
│       ├── _schema.yml
│       ├── fct_estimates.sql
│       ├── fct_projects.sql
│       └── rpt_monthly_kpi.sql
│
├── tests/
│   ├── generic/          ← カスタムジェネリックテスト
│   └── singular/         ← 単体テスト SQL
│
├── macros/
│   ├── anonymize_name.sql       ← 氏名匿名化マクロ
│   └── get_latest_snapshot.sql  ← Bronze最新スナップショット取得
│
└── seeds/
    └── status_master.csv        ← ステータスコードマスタ
```

**profiles.yml（Synapse Serverless SQL Pool）:**
```yaml
a_company_dwh:
  target: prod
  outputs:
    dev:
      type: synapse
      driver: 'ODBC Driver 18 for SQL Server'
      server: "{{ env_var('SYNAPSE_SERVER') }}"
      port: 1433
      database: "{{ env_var('SYNAPSE_DATABASE') }}"
      schema: dbt_dev
      authentication: ServicePrincipal
      tenant_id: "{{ env_var('AZURE_TENANT_ID') }}"
      client_id: "{{ env_var('AZURE_CLIENT_ID') }}"
      client_secret: "{{ env_var('AZURE_CLIENT_SECRET') }}"
    prod:
      type: synapse
      schema: dbt_prod
      # 同上（prod用クレデンシャル）
```

### 3-2. モデルの依存関係（DAG）

```
======= Bronze 層（外部テーブル）=======
  brz_estimates    brz_projects    brz_customers    brz_employees
      |                |                 |                |
      |                |                 |                |
======= Silver 層（整形・クレンジング）=======
      |                |                 |                |
      v                v                 v                v
  stg_estimates    stg_projects     dim_customers    dim_employees
      |                |                 |                |
      |                +---------+-------+                |
      |                          |                        |
      |                          v                        |
      |                    [JOIN結合]                     |
      |                          |                        |
======= Gold 層（KPI・集計）=======
      |                          |                        |
      v                          v                        v
  fct_estimates             fct_projects           (匿名化オプション)
      |                          |
      +------------+-------------+
                   |
                   v
           rpt_monthly_kpi

凡例:
  brz_  = Bronze（生データ外部テーブル）
  stg_  = Staging（Silver、クレンジング済み）
  dim_  = Dimension（Silver、マスタ系）
  fct_  = Fact（Gold、トランザクション系）
  rpt_  = Report（Gold、集計・KPI）
```

### 3-3. 主要モデル定義

#### Bronze → Silver: `stg_estimates.sql`

```sql
-- Silver: 見積管理（整形・型変換・重複排除）
{{ config(
    materialized='incremental',
    unique_key='estimate_id',
    incremental_strategy='merge'
) }}

WITH source AS (
    SELECT *
    FROM {{ ref('brz_estimates') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (SELECT MAX(_loaded_at) FROM {{ this }})
    {% endif %}
),

cleaned AS (
    SELECT
        CAST(estimate_id    AS VARCHAR(50))  AS estimate_id,
        CAST(customer_name  AS NVARCHAR(200)) AS customer_name,
        CAST(amount         AS DECIMAL(18,2)) AS amount,
        CAST(status         AS VARCHAR(50))  AS status,
        TRY_CAST(created_at AS DATE)          AS created_at,
        TRY_CAST(updated_at AS DATE)          AS updated_at,
        CAST(assignee_id    AS VARCHAR(50))  AS assignee_id,
        _loaded_at,
        -- 削除フラグ（Graph API @removed から変換）
        COALESCE(is_deleted, FALSE)           AS is_deleted
    FROM source
    WHERE estimate_id IS NOT NULL  -- NULL キーを排除
)

SELECT * FROM cleaned
```

#### Silver → Gold: `fct_estimates.sql`

```sql
-- Gold: 見積ファクトテーブル（dim結合）
{{ config(materialized='table') }}

SELECT
    e.estimate_id,
    e.amount,
    e.status,
    e.created_at,
    e.updated_at,
    -- 顧客ディメンション結合
    c.customer_code,
    c.customer_name,
    c.industry,
    c.region,
    -- 担当者ディメンション結合（匿名化オプション）
    emp.employee_id,
    {{ anonymize_name('emp.employee_name') }}  AS employee_name,
    emp.department,
    emp.position,
    -- メタデータ
    CURRENT_TIMESTAMP AS _dbt_updated_at
FROM {{ ref('stg_estimates') }} e
LEFT JOIN {{ ref('dim_customers') }} c
    ON e.customer_name = c.customer_name
LEFT JOIN {{ ref('dim_employees') }} emp
    ON e.assignee_id = emp.employee_id
WHERE e.is_deleted = FALSE
```

#### 氏名匿名化マクロ: `anonymize_name.sql`

```sql
-- macros/anonymize_name.sql
{% macro anonymize_name(column_name) %}
    {% if var('anonymize_pii', false) %}
        CONCAT('***', RIGHT({{ column_name }}, 1))
    {% else %}
        {{ column_name }}
    {% endif %}
{% endmacro %}
```

使用方法:
```bash
# 匿名化有効
dbt run --vars '{"anonymize_pii": true}'

# 匿名化無効（デフォルト）
dbt run
```

#### Gold KPI: `rpt_monthly_kpi.sql`

```sql
-- Gold: 月次KPIレポート
{{ config(materialized='table') }}

SELECT
    DATE_TRUNC('month', e.created_at)  AS report_month,
    c.region,
    c.industry,
    COUNT(e.estimate_id)               AS estimate_count,
    SUM(e.amount)                      AS total_estimate_amount,
    COUNT(CASE WHEN e.status = '受注' THEN 1 END) AS won_count,
    SUM(CASE WHEN e.status = '受注' THEN e.amount ELSE 0 END) AS won_amount,
    ROUND(
        100.0 * COUNT(CASE WHEN e.status = '受注' THEN 1 END)
        / NULLIF(COUNT(e.estimate_id), 0), 2
    )                                  AS win_rate_pct,
    COUNT(p.project_id)                AS active_project_count,
    SUM(p.contract_amount)             AS total_contract_amount
FROM {{ ref('fct_estimates') }} e
LEFT JOIN {{ ref('dim_customers') }} c
    ON e.customer_code = c.customer_code
LEFT JOIN {{ ref('fct_projects') }} p
    ON c.customer_code = p.customer_code
    AND DATE_TRUNC('month', p.start_date) = DATE_TRUNC('month', e.created_at)
GROUP BY 1, 2, 3
```

### 3-4. dbt テスト設計

```yaml
# models/silver/_schema.yml
version: 2

models:
  - name: stg_estimates
    description: "見積管理 Silver層（整形済み）"
    columns:
      - name: estimate_id
        tests:
          - unique
          - not_null
      - name: amount
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
      - name: status
        tests:
          - accepted_values:
              values: ['見積中', '提案中', '交渉中', '受注', '失注', 'キャンセル']
      - name: created_at
        tests:
          - not_null

  - name: dim_customers
    columns:
      - name: customer_code
        tests:
          - unique
          - not_null
      - name: contract_status
        tests:
          - accepted_values:
              values: ['有効', '無効', '審査中']
```

---

## 4. エラーハンドリング・リトライ戦略

### 4-1. ADF パイプラインのエラーハンドリング

```
ADF パイプライン エラーハンドリング設計:

[Activity 実行]
      |
      ├── 成功 → 次のActivityへ
      |
      └── 失敗
            |
            ├── リトライ設定（Activity レベル）
            │   - retryCount: 3
            │   - retryIntervalInSeconds: 300（5分）
            │   - 対象: 一時的エラー（HTTP 429, 503, タイムアウト）
            │
            └── 失敗（リトライ上限超過）
                  |
                  ├── エラーログを ADLS /logs/pipeline-errors/ に書込み
                  ├── Azure Monitor アラート発火
                  └── Teams Webhook で担当者に通知
```

**Graph API レート制限対応:**
- SharePoint Online の Graph API は 429 Too Many Requests を返す場合がある
- ADF の `Retry` + `Wait` アクティビティで指数バックオフを実装
- 並列実行数の制御（ForEach の `batchCount: 1` を基本とし、負荷状況に応じて調整）

### 4-2. dbt エラーハンドリング

| エラー種別 | 対応 |
|-----------|------|
| dbt compile エラー | 即時停止、Slack/Teams 通知 |
| dbt run 失敗（特定モデル） | 下流モデルはスキップ、他モデルは継続 |
| dbt test 失敗（WARNING） | ログ記録・通知のみ、下流処理は継続 |
| dbt test 失敗（ERROR） | 下流処理を停止、手動確認後に再実行 |

**dbt test の重大度設定:**
```yaml
# dbt_project.yml
tests:
  +severity: warn       # デフォルトは warn
  +error_if: ">= 100"   # 100件超のエラーは ERROR に昇格
  +warn_if: ">= 1"      # 1件以上は WARN
```

### 4-3. リトライ戦略まとめ

| レイヤー | エラー種別 | リトライ回数 | 待機時間 | 最終失敗時の動作 |
|---------|-----------|------------|---------|---------------|
| ADF (Graph API) | HTTP 429/503 | 3回 | 5分（指数バックオフ） | アラート通知 + 手動対応 |
| ADF (Parquet変換) | 変換エラー | 2回 | 1分 | エラーログ出力 + 通知 |
| ADF (ADLS書込み) | 書込みエラー | 3回 | 2分 | 通知 + 翌日再取得 |
| dbt run | SQL実行エラー | 1回（自動） | 即時 | 手動調査・修正 |
| Power BI リフレッシュ | タイムアウト | 2回 | 30分 | 翌日朝の定時更新を待機 |

---

## 5. 監視・アラート設計

### 5-1. 監視アーキテクチャ

```
監視フロー:

[ADF Pipeline] ─── Diagnostic Settings ───> [Azure Monitor / Log Analytics]
[Synapse SQL]  ─── Diagnostic Settings ───>       |
[ADLS Gen2]    ─── Diagnostic Settings ───>       |
                                                   |
                                          [Alert Rules]
                                                   |
                              ┌────────────────────┼──────────────────┐
                              v                    v                  v
                    [Action Group]        [Action Group]    [Action Group]
                    Teams Webhook         Email             PagerDuty(将来)
                    (担当者チャネル)      (管理者)          (重大障害時)
```

### 5-2. アラートルール定義

| アラート名 | 条件 | 重大度 | 通知先 | 対応SLA |
|-----------|------|-------|-------|--------|
| Pipeline_Failed | ADF パイプライン実行失敗 | Critical | Teams + Email | 30分以内確認 |
| Pipeline_Timeout | ADF 実行時間 > 3時間 | Warning | Teams | 1時間以内確認 |
| dbt_Test_Failed | dbt test ERROR > 0 | Critical | Teams + Email | 30分以内確認 |
| Data_Freshness | Gold 層最終更新 > 09:00 JST | Critical | Teams + Email | 即時対応 |
| ADLS_Capacity | ストレージ使用率 > 80% | Warning | Email | 1週間以内対応 |
| API_RateLimit | Graph API 429 エラー > 10回/時 | Warning | Teams | 当日中確認 |

### 5-3. データ品質監視

```sql
-- dbt 単体テスト: 日次データ鮮度確認
-- tests/singular/check_data_freshness.sql

SELECT
    'estimates' AS table_name,
    MAX(updated_at) AS latest_update,
    DATEDIFF(day, MAX(updated_at), GETDATE()) AS days_since_update
FROM {{ ref('stg_estimates') }}
HAVING DATEDIFF(day, MAX(updated_at), GETDATE()) > 2
-- 2日以上更新がない場合にテスト失敗
```

### 5-4. パイプライン実行ログ

```
ログ保存先（ADLS Gen2）:
/logs/
├── pipeline-runs/
│   └── year=2026/month=03/day=18/
│       └── pipeline_run_20260318_020000.json
│           {
│             "run_id": "abc-123",
│             "pipeline": "spo_to_bronze",
│             "start_time": "2026-03-18T02:00:00+09:00",
│             "end_time": "2026-03-18T02:45:00+09:00",
│             "status": "Succeeded",
│             "rows_ingested": {
│               "estimates": 1250,
│               "projects": 340,
│               "customers": 280,
│               "employees": 95
│             }
│           }
├── dbt-runs/
│   └── year=2026/month=03/day=18/
│       └── dbt_run_20260318_040000.json
└── pipeline-errors/
    └── year=2026/month=03/day=18/
        └── error_20260318_035500.json
```

### 5-5. ダッシュボード設計（Azure Monitor Workbook）

監視ダッシュボードに以下のメトリクスを表示する:

1. **パイプライン実行状況**: 直近30日間の成功/失敗数・実行時間トレンド
2. **データ鮮度**: 各層（Bronze/Silver/Gold）の最終更新時刻
3. **取り込みレコード数**: リストごとの日次取り込み件数推移
4. **dbt テスト結果**: テスト成功率・失敗テスト一覧
5. **コスト追跡**: ADF アクティビティ実行数・Synapse クエリ量（課金に直結）
