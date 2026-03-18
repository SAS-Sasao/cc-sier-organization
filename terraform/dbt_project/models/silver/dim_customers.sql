-- =============================================================================
-- dim_customers.sql - Silver: 顧客マスタ（SCD Type 2）
-- =============================================================================
-- Bronze 層の brz_customers から顧客マスタデータを読み込み、
-- SCD Type 2 で履歴管理する。
--
-- SCD Type 2 動作:
--   1. ソースレコードのハッシュ値で変更を検知
--   2. 変更があったレコード: 既存を close (_valid_to = 現在, _is_current = 0)
--   3. 変更レコードの新バージョンを insert (_valid_from = 現在, _is_current = 1)
--   4. 新規レコード: insert (_valid_from = 現在, _is_current = 1)
--
-- 業種コード標準化マッピング:
--   製造/製造業/Manufacturing -> MFG
--   卸売/卸売業/Wholesale    -> WHL
--   小売/小売業/Retail       -> RTL
--   情報/IT/情報通信         -> ICT
--   建設/建設業/Construction -> CNS
--   サービス/サービス業      -> SVC
--   その他/Other             -> OTH
--   NULL/空文字              -> UNK
-- =============================================================================

{{ config(
    materialized='incremental',
    unique_key='customer_sk',
    incremental_strategy='merge',
    merge_update_columns=['_valid_to', '_is_current'],
    tags=['silver', 'customers', 'scd2', 'master']
) }}

WITH source AS (
    SELECT *
    FROM {{ ref('brz_customers') }}
    {% if is_incremental() %}
    WHERE _ingestion_timestamp > (SELECT MAX(_loaded_at) FROM {{ this }} WHERE _is_current = 1)
    {% endif %}
),

-- 業種コード標準化
industry_standardized AS (
    SELECT
        CAST(LTRIM(RTRIM(customer_code)) AS VARCHAR(50)) AS customer_code,
        COALESCE(
            NULLIF(LTRIM(RTRIM(CAST(customer_name AS NVARCHAR(200)))), ''),
            N'不明'
        ) AS customer_name,

        -- 業種コード標準化マッピング
        CASE
            WHEN LTRIM(RTRIM(industry)) IN (N'製造', N'製造業', 'Manufacturing', 'MFG') THEN 'MFG'
            WHEN LTRIM(RTRIM(industry)) IN (N'卸売', N'卸売業', 'Wholesale', 'WHL')     THEN 'WHL'
            WHEN LTRIM(RTRIM(industry)) IN (N'小売', N'小売業', 'Retail', 'RTL')         THEN 'RTL'
            WHEN LTRIM(RTRIM(industry)) IN (N'情報', N'IT', N'情報通信', N'情報通信業', 'Information Technology', 'ICT') THEN 'ICT'
            WHEN LTRIM(RTRIM(industry)) IN (N'建設', N'建設業', 'Construction', 'CNS')   THEN 'CNS'
            WHEN LTRIM(RTRIM(industry)) IN (N'サービス', N'サービス業', 'Services', 'SVC') THEN 'SVC'
            WHEN LTRIM(RTRIM(industry)) IN (N'その他', 'Other', 'OTH')                   THEN 'OTH'
            ELSE 'UNK'
        END AS industry_code,

        CASE
            WHEN LTRIM(RTRIM(industry)) IN (N'製造', N'製造業', 'Manufacturing', 'MFG') THEN N'製造業'
            WHEN LTRIM(RTRIM(industry)) IN (N'卸売', N'卸売業', 'Wholesale', 'WHL')     THEN N'卸売業'
            WHEN LTRIM(RTRIM(industry)) IN (N'小売', N'小売業', 'Retail', 'RTL')         THEN N'小売業'
            WHEN LTRIM(RTRIM(industry)) IN (N'情報', N'IT', N'情報通信', N'情報通信業', 'Information Technology', 'ICT') THEN N'情報通信業'
            WHEN LTRIM(RTRIM(industry)) IN (N'建設', N'建設業', 'Construction', 'CNS')   THEN N'建設業'
            WHEN LTRIM(RTRIM(industry)) IN (N'サービス', N'サービス業', 'Services', 'SVC') THEN N'サービス業'
            WHEN LTRIM(RTRIM(industry)) IN (N'その他', 'Other', 'OTH')                   THEN N'その他'
            ELSE N'不明'
        END AS industry_name,

        LTRIM(RTRIM(CAST(region AS NVARCHAR(100)))) AS region,

        -- 契約ステータス正規化
        CASE
            WHEN LTRIM(RTRIM(contract_status)) IN (N'有効', 'ACTIVE', 'Active')       THEN 'ACTIVE'
            WHEN LTRIM(RTRIM(contract_status)) IN (N'無効', 'INACTIVE', 'Inactive')   THEN 'INACTIVE'
            WHEN LTRIM(RTRIM(contract_status)) IN (N'審査中', 'SUSPENDED', 'Suspended') THEN 'SUSPENDED'
            ELSE 'ACTIVE'  -- デフォルトは有効
        END AS contract_status,

        _ingestion_timestamp,

        -- 重複排除
        ROW_NUMBER() OVER (
            PARTITION BY customer_code
            ORDER BY _ingestion_timestamp DESC
        ) AS _row_num

    FROM source
    WHERE customer_code IS NOT NULL
),

-- 最新レコードのみ
deduplicated AS (
    SELECT *
    FROM industry_standardized
    WHERE _row_num = 1
),

-- 変更検知用ハッシュ
hashed AS (
    SELECT
        customer_code,
        customer_name,
        industry_code,
        industry_name,
        region,
        contract_status,
        _ingestion_timestamp,
        -- 変更検知ハッシュ: ビジネスカラムの組み合わせ
        CONVERT(
            VARCHAR(64),
            HASHBYTES(
                'SHA2_256',
                CONCAT_WS('||',
                    COALESCE(customer_name, ''),
                    COALESCE(industry_code, ''),
                    COALESCE(region, ''),
                    COALESCE(contract_status, '')
                )
            ),
            2
        ) AS _hash_diff
    FROM deduplicated
)

{% if is_incremental() %}
-- =============================================================================
-- Incremental 実行: SCD Type 2 の既存レコード close + 新レコード insert
-- =============================================================================

-- 変更が検知されたレコード（新バージョン）をINSERT
-- 既存の current レコードの close は merge_update_columns で _valid_to, _is_current を更新
SELECT
    -- サロゲートキー: ビジネスキー + タイムスタンプベースの一意キー生成
    CAST(
        ABS(
            CAST(
                HASHBYTES('SHA2_256', CONCAT(h.customer_code, '||', CAST(GETUTCDATE() AS VARCHAR(50))))
                AS BIGINT
            )
        ) % 9999999999
        AS BIGINT
    ) AS customer_sk,
    h.customer_code,
    h.customer_name,
    h.industry_code,
    h.industry_name,
    h.region,
    h.contract_status,
    CAST(GETUTCDATE() AS DATETIME2) AS _valid_from,
    CAST('9999-12-31 23:59:59' AS DATETIME2) AS _valid_to,
    CAST(1 AS BIT) AS _is_current,
    h._hash_diff,
    CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at
FROM hashed h
LEFT JOIN {{ this }} existing
    ON h.customer_code = existing.customer_code
    AND existing._is_current = 1
WHERE
    -- 新規レコード OR 変更検知
    existing.customer_code IS NULL
    OR existing._hash_diff != h._hash_diff

{% else %}
-- =============================================================================
-- Full refresh 実行: 全レコードを初期ロード
-- =============================================================================
SELECT
    CAST(
        ABS(
            CAST(
                HASHBYTES('SHA2_256', CONCAT(h.customer_code, '||', CAST(GETUTCDATE() AS VARCHAR(50))))
                AS BIGINT
            )
        ) % 9999999999
        AS BIGINT
    ) AS customer_sk,
    h.customer_code,
    h.customer_name,
    h.industry_code,
    h.industry_name,
    h.region,
    h.contract_status,
    CAST(GETUTCDATE() AS DATETIME2) AS _valid_from,
    CAST('9999-12-31 23:59:59' AS DATETIME2) AS _valid_to,
    CAST(1 AS BIT) AS _is_current,
    h._hash_diff,
    CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at
FROM hashed h

{% endif %}
