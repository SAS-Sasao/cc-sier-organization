-- =============================================================================
-- mart_conversion_funnel.sql - Gold: 見積 -> 受注 コンバージョンファネル
-- =============================================================================
-- fact_estimates と dim_status を結合し、ステータス別の見積件数・金額を集計。
-- ファネル分析（作成中 -> 提出済 -> 検討中 -> 受注 / 失注）の可視化に使用。
--
-- グレイン: 年月 x ステータス
--
-- 集計指標:
--   - 該当ステータスの見積件数 / 金額
--   - 累計件数（ファネル上位からの累計）
--   - 前ステージからの転換率（%）
-- =============================================================================

{{ config(
    materialized='table',
    tags=['gold', 'mart', 'funnel']
) }}

WITH estimates AS (
    SELECT
        fe.estimate_number,
        fe.amount,
        fe.status_key,
        fe.created_date_key
    FROM {{ ref('fct_estimates') }} fe
),

statuses AS (
    SELECT
        status_key,
        status_code,
        status_name,
        status_name_ja,
        sort_order,
        is_terminal
    FROM {{ ref('status_master') }}
    WHERE status_category = 'ESTIMATE'
),

-- ステータス別の月次集計
status_monthly AS (
    SELECT
        -- 年月
        LEFT(CAST(e.created_date_key AS VARCHAR(8)), 4)
            + '-'
            + SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2) AS year_month,

        -- ステータス情報
        s.status_code,
        s.status_name,
        s.status_name_ja,
        s.sort_order,

        -- 件数・金額
        COUNT(e.estimate_number) AS estimate_count,
        SUM(e.amount) AS estimate_amount

    FROM estimates e
    INNER JOIN statuses s
        ON e.status_key = s.status_key
    WHERE
        e.created_date_key IS NOT NULL
    GROUP BY
        LEFT(CAST(e.created_date_key AS VARCHAR(8)), 4)
            + '-'
            + SUBSTRING(CAST(e.created_date_key AS VARCHAR(8)), 5, 2),
        s.status_code,
        s.status_name,
        s.status_name_ja,
        s.sort_order
),

-- 累計件数と転換率の計算
with_cumulative AS (
    SELECT
        year_month,
        status_code,
        status_name,
        status_name_ja,
        sort_order,
        estimate_count,
        estimate_amount,

        -- 累計件数: 当該年月の全ステータス合計件数
        -- （ファネルの頂点 = 全見積件数に対する割合算出用）
        SUM(estimate_count) OVER (
            PARTITION BY year_month
        ) AS total_count_in_month,

        -- 前ステージの件数（転換率の分母）
        LAG(estimate_count) OVER (
            PARTITION BY year_month
            ORDER BY sort_order
        ) AS prev_stage_count,

        -- 累計件数（sort_order 順に上位ステータスからの累計）
        SUM(estimate_count) OVER (
            PARTITION BY year_month
            ORDER BY sort_order
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_count

    FROM status_monthly
)

SELECT
    year_month,
    status_code,
    status_name,
    status_name_ja,
    sort_order,
    estimate_count,
    estimate_amount,
    cumulative_count,

    -- 前ステージからの転換率
    -- 最初のステージ（DRAFT）は NULL、以降は前ステージ件数に対する割合
    CASE
        WHEN prev_stage_count IS NOT NULL AND prev_stage_count > 0
        THEN CAST(
            ROUND(100.0 * estimate_count / prev_stage_count, 2)
            AS DECIMAL(5,2)
        )
        ELSE NULL
    END AS conversion_rate,

    CAST(GETUTCDATE() AS DATETIME2) AS _calculated_at

FROM with_cumulative
