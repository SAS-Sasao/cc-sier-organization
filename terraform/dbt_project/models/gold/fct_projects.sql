-- =============================================================================
-- fct_projects.sql - Gold: 案件ファクトテーブル
-- =============================================================================
-- Silver 層の stg_projects をベースに、ディメンションテーブルと結合して
-- スタースキーマのファクトテーブルを構築する。
--
-- 結合先ディメンション:
--   - dim_customers (customer_name -> customer_key)
--   - status_master (phase_code -> status_key)
--
-- 派生メジャー:
--   - is_active: アクティブフラグ（完了/中止 以外）
--   - is_completed: 完了フラグ（phase_code = 80）
--   - phase_duration_days: 現フェーズの滞留日数
-- =============================================================================

{{ config(
    materialized='table',
    tags=['gold', 'fact', 'projects']
) }}

WITH projects AS (
    SELECT *
    FROM {{ ref('stg_projects') }}
),

customers AS (
    SELECT
        customer_sk AS customer_key,
        customer_code,
        customer_name
    FROM {{ ref('dim_customers') }}
    WHERE _is_current = 1
),

statuses AS (
    SELECT
        status_key,
        status_code,
        status_name,
        is_terminal
    FROM {{ ref('status_master') }}
    WHERE status_category = 'PROJECT'
),

fact AS (
    SELECT
        -- サロゲートキー
        CAST(
            ABS(
                CAST(
                    HASHBYTES('SHA2_256', CONCAT(p.project_number, '||', CAST(GETUTCDATE() AS VARCHAR(50))))
                    AS BIGINT
                )
            ) % 9999999999
            AS BIGINT
        ) AS project_fact_key,

        -- ビジネスキー（退化ディメンション）
        p.project_number,

        -- 案件名
        p.project_name,

        -- 顧客キー FK
        COALESCE(c.customer_key, -1) AS customer_key,

        -- 日付キー FK（YYYYMMDD 形式の INT）
        CASE
            WHEN p.start_date IS NOT NULL
            THEN CAST(FORMAT(p.start_date, 'yyyyMMdd') AS INT)
            ELSE NULL
        END AS start_date_key,
        CASE
            WHEN p.end_date IS NOT NULL
            THEN CAST(FORMAT(p.end_date, 'yyyyMMdd') AS INT)
            ELSE NULL
        END AS end_date_key,

        -- ステータスキー FK（フェーズコードで結合）
        COALESCE(s.status_key, 201) AS status_key,

        -- メジャー: 受注金額
        p.contract_amount,

        -- 案件期間（日数）
        p.duration_days,

        -- 派生フラグ
        CASE
            WHEN p.phase_code NOT IN (80, 90) THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS is_active,
        CASE
            WHEN p.phase_code = 80 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS is_completed,

        -- 現フェーズの滞留日数（最終更新日からの経過日数で近似）
        DATEDIFF(DAY, p._loaded_at, GETUTCDATE()) AS phase_duration_days,

        -- メタデータ
        CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at

    FROM projects p
    LEFT JOIN customers c
        ON p.customer_name = c.customer_name
    LEFT JOIN statuses s
        ON p.phase_code = s.status_code
)

SELECT *
FROM fact
