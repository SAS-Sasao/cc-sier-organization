-- =============================================================================
-- stg_projects.sql - Silver: 案件管理（型変換・フェーズ正規化・重複排除）
-- =============================================================================
-- Bronze 層の brz_projects からデータを読み込み、以下の処理を実施:
--   1. 型変換: 文字列 -> DECIMAL(18,2), DATE 等
--   2. フェーズ正規化: ソースの自由入力 -> 標準コード体系
--   3. 重複排除: project_number 単位で最新レコードのみ保持
--   4. 派生カラム計算: duration_days 等
-- =============================================================================

{{ config(
    materialized='incremental',
    unique_key='project_number',
    incremental_strategy='merge',
    tags=['silver', 'projects']
) }}

WITH source AS (
    SELECT *
    FROM {{ ref('brz_projects') }}
    {% if is_incremental() %}
    WHERE _ingestion_timestamp > (SELECT MAX(_loaded_at) FROM {{ this }})
    {% endif %}
),

-- フェーズマスタを結合して正規化コードを取得
phase_mapping AS (
    SELECT
        status_key,
        status_code,
        status_name,
        status_name_ja
    FROM {{ ref('status_master') }}
    WHERE status_category = 'PROJECT'
),

cleaned AS (
    SELECT
        -- ビジネスキー
        CAST(LTRIM(RTRIM(s.project_number)) AS VARCHAR(50)) AS project_number,

        -- 案件名: NULL 時は '無題' で補完
        COALESCE(
            NULLIF(LTRIM(RTRIM(CAST(s.project_name AS NVARCHAR(200)))), ''),
            N'無題'
        ) AS project_name,

        -- 顧客名: NULL 時は '不明' で補完
        COALESCE(
            NULLIF(LTRIM(RTRIM(CAST(s.customer_name AS NVARCHAR(200)))), ''),
            N'不明'
        ) AS customer_name,

        -- フェーズ正規化
        COALESCE(pm.status_code, 10) AS phase_code,
        COALESCE(pm.status_name, 'PLANNING') AS phase_name,

        -- 受注金額: 文字列 -> DECIMAL(18,2)
        COALESCE(
            TRY_CAST(REPLACE(REPLACE(s.contract_amount, ',', ''), N'\', '') AS DECIMAL(18,2)),
            0.00
        ) AS contract_amount,

        -- 日付: 文字列 -> DATE
        TRY_CAST(s.start_date AS DATE) AS start_date,
        TRY_CAST(s.end_date AS DATE) AS end_date,

        -- 派生カラム: 期間（日数）
        CASE
            WHEN TRY_CAST(s.start_date AS DATE) IS NOT NULL
                 AND TRY_CAST(s.end_date AS DATE) IS NOT NULL
            THEN DATEDIFF(DAY, TRY_CAST(s.start_date AS DATE), TRY_CAST(s.end_date AS DATE))
            ELSE NULL
        END AS duration_days,

        -- メタデータ
        CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at,

        -- ソースレコードハッシュ
        CONVERT(
            VARCHAR(64),
            HASHBYTES(
                'SHA2_256',
                CONCAT_WS('||',
                    COALESCE(s.project_number, ''),
                    COALESCE(s.project_name, ''),
                    COALESCE(s.customer_name, ''),
                    COALESCE(s.phase, ''),
                    COALESCE(s.contract_amount, ''),
                    COALESCE(s.start_date, ''),
                    COALESCE(s.end_date, '')
                )
            ),
            2
        ) AS _source_record_hash,

        -- 重複排除
        ROW_NUMBER() OVER (
            PARTITION BY s.project_number
            ORDER BY s._ingestion_timestamp DESC
        ) AS _row_num

    FROM source s
    LEFT JOIN phase_mapping pm
        ON LTRIM(RTRIM(s.phase)) = pm.status_name_ja
           OR LTRIM(RTRIM(s.phase)) = pm.status_name
    WHERE
        s.project_number IS NOT NULL
)

SELECT
    project_number,
    project_name,
    customer_name,
    phase_code,
    phase_name,
    contract_amount,
    start_date,
    end_date,
    duration_days,
    _loaded_at,
    _source_record_hash
FROM cleaned
WHERE _row_num = 1
