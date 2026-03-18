-- =============================================================================
-- mart_phase_analysis.sql - Gold: フェーズ別滞留分析
-- =============================================================================
-- fact_projects と status_master を結合し、フェーズごとの滞留状況を分析する。
-- プロジェクト管理の可視化に使用。停滞案件の早期発見を目的とする。
--
-- グレイン: フェーズ
--
-- 集計指標:
--   - 該当フェーズの案件数
--   - 滞留日数の統計値（平均、中央値、最小、最大、P90）
--   - 現在このフェーズにある案件数
-- =============================================================================

{{ config(
    materialized='table',
    tags=['gold', 'mart', 'phase_analysis']
) }}

WITH projects AS (
    SELECT
        fp.project_number,
        fp.status_key,
        fp.phase_duration_days,
        fp.is_active,
        fp.is_completed
    FROM {{ ref('fct_projects') }} fp
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
    WHERE status_category = 'PROJECT'
),

-- フェーズ別の統計量算出
phase_stats AS (
    SELECT
        s.status_code AS phase_code,
        s.status_name AS phase_name,
        s.status_name_ja AS phase_name_ja,
        s.sort_order,

        -- 該当フェーズの案件数
        COUNT(p.project_number) AS project_count,

        -- 平均滞留日数
        CAST(
            ROUND(AVG(CAST(p.phase_duration_days AS FLOAT)), 1)
            AS DECIMAL(10,1)
        ) AS avg_duration_days,

        -- 中央値滞留日数
        -- T-SQL では PERCENTILE_CONT を使用
        CAST(
            ROUND(
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.phase_duration_days)
                    OVER (PARTITION BY s.status_code),
                1
            ) AS DECIMAL(10,1)
        ) AS median_duration_days,

        -- 最小滞留日数
        MIN(p.phase_duration_days) AS min_duration_days,

        -- 最大滞留日数
        MAX(p.phase_duration_days) AS max_duration_days,

        -- 90パーセンタイル
        CAST(
            ROUND(
                PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY p.phase_duration_days)
                    OVER (PARTITION BY s.status_code),
                1
            ) AS DECIMAL(10,1)
        ) AS p90_duration_days,

        -- 現在このフェーズにある案件数（アクティブのみ）
        COUNT(CASE WHEN p.is_active = 1 THEN 1 END) AS currently_in_phase

    FROM projects p
    INNER JOIN statuses s
        ON p.status_key = s.status_key
    GROUP BY
        s.status_code,
        s.status_name,
        s.status_name_ja,
        s.sort_order
)

SELECT
    phase_code,
    phase_name,
    phase_name_ja,
    sort_order,
    project_count,
    avg_duration_days,
    median_duration_days,
    min_duration_days,
    max_duration_days,
    p90_duration_days,
    currently_in_phase,
    CAST(GETUTCDATE() AS DATETIME2) AS _calculated_at
FROM phase_stats
