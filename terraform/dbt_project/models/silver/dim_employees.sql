-- =============================================================================
-- dim_employees.sql - Silver: 担当者マスタ（SCD Type 2 + 匿名化対応）
-- =============================================================================
-- Bronze 層の brz_employees から担当者マスタデータを読み込み、
-- SCD Type 2 で履歴管理する。
-- 匿名化用に SHA-256 ハッシュ（employee_name_hash）を生成する。
--
-- 匿名化:
--   - employee_name_hash: 氏名 + ソルト の SHA-256 ハッシュ（64文字hex）
--   - ソルトは環境変数 ANONYMIZATION_SALT で管理
--   - Gold 層の dim_employee_anonymized ビューで
--     先頭4文字を使用したマスク値に変換
-- =============================================================================

{{ config(
    materialized='incremental',
    unique_key='employee_sk',
    incremental_strategy='merge',
    merge_update_columns=['_valid_to', '_is_current'],
    tags=['silver', 'employees', 'scd2', 'master', 'pii']
) }}

WITH source AS (
    SELECT *
    FROM {{ ref('brz_employees') }}
    {% if is_incremental() %}
    WHERE _ingestion_timestamp > (SELECT MAX(_loaded_at) FROM {{ this }} WHERE _is_current = 1)
    {% endif %}
),

cleaned AS (
    SELECT
        -- ビジネスキー
        CAST(LTRIM(RTRIM(employee_number)) AS VARCHAR(50)) AS employee_number,

        -- 氏名: トリム
        COALESCE(
            NULLIF(LTRIM(RTRIM(CAST(employee_name AS NVARCHAR(200)))), ''),
            N'不明'
        ) AS employee_name,

        -- 氏名の SHA-256 ハッシュ（匿名化用）
        -- ソルトを連結してハッシュを生成し、同一ソルト環境では一貫したハッシュを保証
        CONVERT(
            VARCHAR(64),
            HASHBYTES(
                'SHA2_256',
                CONCAT(
                    COALESCE(LTRIM(RTRIM(CAST(employee_name AS NVARCHAR(200)))), ''),
                    '||',
                    '{{ var("anonymization_salt") }}'
                )
            ),
            2
        ) AS employee_name_hash,

        -- 部署名: 正規化（前後空白トリム）
        LTRIM(RTRIM(CAST(department AS NVARCHAR(100)))) AS department,

        -- 役職: 正規化（前後空白トリム）
        LTRIM(RTRIM(CAST(job_title AS NVARCHAR(100)))) AS job_title,

        _ingestion_timestamp,

        -- 重複排除
        ROW_NUMBER() OVER (
            PARTITION BY employee_number
            ORDER BY _ingestion_timestamp DESC
        ) AS _row_num

    FROM source
    WHERE employee_number IS NOT NULL
),

deduplicated AS (
    SELECT *
    FROM cleaned
    WHERE _row_num = 1
),

hashed AS (
    SELECT
        employee_number,
        employee_name,
        employee_name_hash,
        department,
        job_title,
        _ingestion_timestamp,
        -- 変更検知ハッシュ: ビジネスカラムの組み合わせ
        CONVERT(
            VARCHAR(64),
            HASHBYTES(
                'SHA2_256',
                CONCAT_WS('||',
                    COALESCE(employee_name, ''),
                    COALESCE(department, ''),
                    COALESCE(job_title, '')
                )
            ),
            2
        ) AS _hash_diff
    FROM deduplicated
)

{% if is_incremental() %}
-- =============================================================================
-- Incremental: SCD Type 2 新バージョン INSERT
-- =============================================================================
SELECT
    CAST(
        ABS(
            CAST(
                HASHBYTES('SHA2_256', CONCAT(h.employee_number, '||', CAST(GETUTCDATE() AS VARCHAR(50))))
                AS BIGINT
            )
        ) % 9999999999
        AS BIGINT
    ) AS employee_sk,
    h.employee_number,
    h.employee_name,
    h.employee_name_hash,
    h.department,
    h.job_title,
    CAST(GETUTCDATE() AS DATETIME2) AS _valid_from,
    CAST('9999-12-31 23:59:59' AS DATETIME2) AS _valid_to,
    CAST(1 AS BIT) AS _is_current,
    h._hash_diff,
    CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at
FROM hashed h
LEFT JOIN {{ this }} existing
    ON h.employee_number = existing.employee_number
    AND existing._is_current = 1
WHERE
    existing.employee_number IS NULL
    OR existing._hash_diff != h._hash_diff

{% else %}
-- =============================================================================
-- Full refresh: 全レコードを初期ロード
-- =============================================================================
SELECT
    CAST(
        ABS(
            CAST(
                HASHBYTES('SHA2_256', CONCAT(h.employee_number, '||', CAST(GETUTCDATE() AS VARCHAR(50))))
                AS BIGINT
            )
        ) % 9999999999
        AS BIGINT
    ) AS employee_sk,
    h.employee_number,
    h.employee_name,
    h.employee_name_hash,
    h.department,
    h.job_title,
    CAST(GETUTCDATE() AS DATETIME2) AS _valid_from,
    CAST('9999-12-31 23:59:59' AS DATETIME2) AS _valid_to,
    CAST(1 AS BIT) AS _is_current,
    h._hash_diff,
    CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at
FROM hashed h

{% endif %}
