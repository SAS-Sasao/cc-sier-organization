-- =============================================================================
-- fct_estimates.sql - Gold: 見積ファクトテーブル
-- =============================================================================
-- Silver 層の stg_estimates をベースに、ディメンションテーブルと結合して
-- スタースキーマのファクトテーブルを構築する。
--
-- 結合先ディメンション:
--   - dim_customers (customer_name -> customer_key)
--   - dim_employees (assigned_to -> employee_key)
--   - status_master (status_code -> status_key)
--
-- 派生メジャー:
--   - is_won: 受注フラグ（status_code = 40）
--   - is_lost: 失注フラグ（status_code = 50）
--   - is_open: オープンフラグ（終端ステータス以外）
--   - days_since_created: 作成からの経過日数
-- =============================================================================

{{ config(
    materialized='table',
    tags=['gold', 'fact', 'estimates']
) }}

WITH estimates AS (
    SELECT *
    FROM {{ ref('stg_estimates') }}
),

-- 顧客ディメンション（現行レコードのみ）
customers AS (
    SELECT
        customer_sk AS customer_key,
        customer_code,
        customer_name
    FROM {{ ref('dim_customers') }}
    WHERE _is_current = 1
),

-- 担当者ディメンション（現行レコードのみ）
employees AS (
    SELECT
        employee_sk AS employee_key,
        employee_number,
        employee_name
    FROM {{ ref('dim_employees') }}
    WHERE _is_current = 1
),

-- ステータスマスタ（ESTIMATE カテゴリ）
statuses AS (
    SELECT
        status_key,
        status_code,
        status_name,
        is_terminal
    FROM {{ ref('status_master') }}
    WHERE status_category = 'ESTIMATE'
),

-- ファクトテーブル構築
fact AS (
    SELECT
        -- サロゲートキー
        CAST(
            ABS(
                CAST(
                    HASHBYTES('SHA2_256', CONCAT(e.estimate_number, '||', CAST(GETUTCDATE() AS VARCHAR(50))))
                    AS BIGINT
                )
            ) % 9999999999
            AS BIGINT
        ) AS estimate_fact_key,

        -- ビジネスキー（退化ディメンション）
        e.estimate_number,

        -- 顧客キー FK
        COALESCE(c.customer_key, -1) AS customer_key,

        -- 担当者キー FK（未割当時は NULL）
        emp.employee_key AS employee_key,

        -- 日付キー FK（YYYYMMDD 形式の INT）
        CASE
            WHEN e.created_at IS NOT NULL
            THEN CAST(FORMAT(e.created_at, 'yyyyMMdd') AS INT)
            ELSE NULL
        END AS created_date_key,
        CASE
            WHEN e.modified_at IS NOT NULL
            THEN CAST(FORMAT(e.modified_at, 'yyyyMMdd') AS INT)
            ELSE NULL
        END AS modified_date_key,

        -- ステータスキー FK
        COALESCE(s.status_key, 101) AS status_key,

        -- メジャー: 見積金額
        e.amount,

        -- 派生フラグ
        CASE WHEN e.status_code = 40 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_won,
        CASE WHEN e.status_code = 50 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_lost,
        CASE
            WHEN e.status_code NOT IN (40, 50, 90) THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS is_open,

        -- 派生メジャー: 作成からの経過日数
        CASE
            WHEN e.created_at IS NOT NULL
            THEN DATEDIFF(DAY, e.created_at, GETUTCDATE())
            ELSE NULL
        END AS days_since_created,

        -- メタデータ
        CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at

    FROM estimates e
    -- 顧客ディメンション結合（顧客名ベース）
    LEFT JOIN customers c
        ON e.customer_name = c.customer_name
    -- 担当者ディメンション結合（担当者名ベース）
    LEFT JOIN employees emp
        ON e.assigned_to = emp.employee_name
    -- ステータスマスタ結合
    LEFT JOIN statuses s
        ON e.status_code = s.status_code
)

SELECT *
FROM fact
