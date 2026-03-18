-- =============================================================================
-- mart_sales_summary.sql - Gold: 月別・四半期別売上サマリ
-- =============================================================================
-- fact_estimates と dim_customers を結合し、月別・顧客別の売上KPIを集計する。
-- Power BI のレポートやダッシュボードから直接参照されるマートテーブル。
--
-- グレイン: 年月 x 顧客 x 業種
--
-- 集計指標:
--   - 見積件数 / 金額合計
--   - 受注件数 / 金額合計
--   - 失注件数 / 金額合計
--   - オープン件数
--   - 受注率（%）
--   - 平均見積金額
-- =============================================================================

{{ config(
    materialized='table',
    tags=['gold', 'mart', 'sales']
) }}

WITH estimates AS (
    SELECT
        fe.estimate_number,
        fe.amount,
        fe.is_won,
        fe.is_lost,
        fe.is_open,
        fe.customer_key,
        fe.created_date_key
    FROM {{ ref('fct_estimates') }} fe
),

customers AS (
    SELECT
        customer_key,
        customer_code,
        customer_name,
        industry_code,
        industry_name,
        region
    FROM {{ ref('dim_customers') }}
    WHERE _is_current = 1
),

-- 月次集計
monthly_agg AS (
    SELECT
        -- 年月（日付キーから導出: YYYYMMDD -> YYYY-MM）
        LEFT(CAST(e.created_date_key AS VARCHAR(8)), 4)
            + '-'
            + SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS year_month,

        -- 年・四半期・月
        CAST(LEFT(CAST(e.created_date_key AS VARCHAR(8)), 4) AS INT) AS [year],
        CASE
            WHEN CAST(SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS INT) BETWEEN 1 AND 3 THEN 1
            WHEN CAST(SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS INT) BETWEEN 4 AND 6 THEN 2
            WHEN CAST(SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS INT) BETWEEN 7 AND 9 THEN 3
            ELSE 4
        END AS [quarter],
        CAST(SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS INT) AS [month],

        -- 顧客情報（非正規化）
        c.customer_key,
        c.customer_name,
        c.industry_name,

        -- 見積件数・金額
        COUNT(e.estimate_number) AS total_estimates,
        SUM(e.amount) AS total_estimate_amount,

        -- 受注
        COUNT(CASE WHEN e.is_won = 1 THEN 1 END) AS won_count,
        SUM(CASE WHEN e.is_won = 1 THEN e.amount ELSE 0 END) AS won_amount,

        -- 失注
        COUNT(CASE WHEN e.is_lost = 1 THEN 1 END) AS lost_count,
        SUM(CASE WHEN e.is_lost = 1 THEN e.amount ELSE 0 END) AS lost_amount,

        -- オープン
        COUNT(CASE WHEN e.is_open = 1 THEN 1 END) AS open_count,

        -- 受注率: 受注 / (受注 + 失注) * 100
        CASE
            WHEN (COUNT(CASE WHEN e.is_won = 1 THEN 1 END)
                + COUNT(CASE WHEN e.is_lost = 1 THEN 1 END)) > 0
            THEN CAST(
                ROUND(
                    100.0 * COUNT(CASE WHEN e.is_won = 1 THEN 1 END)
                    / (COUNT(CASE WHEN e.is_won = 1 THEN 1 END)
                       + COUNT(CASE WHEN e.is_lost = 1 THEN 1 END)),
                    2
                ) AS DECIMAL(5,2)
            )
            ELSE NULL
        END AS win_rate,

        -- 平均見積金額
        CAST(
            ROUND(AVG(e.amount), 2)
            AS DECIMAL(18,2)
        ) AS avg_estimate_amount,

        -- メタデータ
        CAST(GETUTCDATE() AS DATETIME2) AS _calculated_at

    FROM estimates e
    LEFT JOIN customers c
        ON e.customer_key = c.customer_key
    WHERE
        -- 日付キーが有効な行のみ集計
        e.created_date_key IS NOT NULL
    GROUP BY
        LEFT(CAST(e.created_date_key AS VARCHAR(8)), 4)
            + '-'
            + SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2),
        CAST(LEFT(CAST(e.created_date_key AS VARCHAR(8)), 4) AS INT),
        CAST(SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS INT),
        c.customer_key,
        c.customer_name,
        c.industry_name
)

SELECT *
FROM monthly_agg
