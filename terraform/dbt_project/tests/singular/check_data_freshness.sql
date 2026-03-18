-- =============================================================================
-- check_data_freshness.sql - データ鮮度チェック（シングルテスト）
-- =============================================================================
-- Silver 層の各テーブルの最終更新日を確認し、2日以上更新がない場合に
-- テスト失敗とする。日次バッチの実行漏れや取り込み障害を検知する。
--
-- 対応品質ルール: BRZ-006（ソース鮮度チェック）
-- 重大度: ERROR（28時間以上で ERROR）
--
-- 動作:
--   - 各テーブルの MAX(modified_at / _loaded_at) を確認
--   - GETDATE() との差分が 2日以上の場合、該当行を返す（= テスト失敗）
--   - 結果が 0行 = テスト成功
-- =============================================================================

WITH freshness_check AS (
    -- 見積テーブルの鮮度
    SELECT
        'stg_estimates' AS table_name,
        MAX(modified_at) AS latest_business_update,
        MAX(_loaded_at) AS latest_load_timestamp,
        DATEDIFF(DAY, MAX(_loaded_at), GETUTCDATE()) AS days_since_load
    FROM {{ ref('stg_estimates') }}

    UNION ALL

    -- 案件テーブルの鮮度
    SELECT
        'stg_projects' AS table_name,
        CAST(MAX(start_date) AS DATETIME2) AS latest_business_update,
        MAX(_loaded_at) AS latest_load_timestamp,
        DATEDIFF(DAY, MAX(_loaded_at), GETUTCDATE()) AS days_since_load
    FROM {{ ref('stg_projects') }}

    UNION ALL

    -- 顧客マスタの鮮度
    SELECT
        'dim_customers' AS table_name,
        NULL AS latest_business_update,
        MAX(_loaded_at) AS latest_load_timestamp,
        DATEDIFF(DAY, MAX(_loaded_at), GETUTCDATE()) AS days_since_load
    FROM {{ ref('dim_customers') }}

    UNION ALL

    -- 担当者マスタの鮮度
    SELECT
        'dim_employees' AS table_name,
        NULL AS latest_business_update,
        MAX(_loaded_at) AS latest_load_timestamp,
        DATEDIFF(DAY, MAX(_loaded_at), GETUTCDATE()) AS days_since_load
    FROM {{ ref('dim_employees') }}
)

-- 2日以上更新がないテーブルを返す（テスト失敗行）
SELECT
    table_name,
    latest_business_update,
    latest_load_timestamp,
    days_since_load
FROM freshness_check
WHERE days_since_load > 2
