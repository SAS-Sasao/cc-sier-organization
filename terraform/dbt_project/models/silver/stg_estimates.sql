-- =============================================================================
-- stg_estimates.sql - Silver: 見積管理（型変換・ステータス正規化・重複排除）
-- =============================================================================
-- Bronze 層の brz_estimates からデータを読み込み、以下の処理を実施:
--   1. 型変換: 文字列 -> DECIMAL(18,2), DATE 等
--   2. ステータス正規化: ソースの自由入力 -> 標準コード体系
--   3. 重複排除: estimate_number 単位で最新レコードのみ保持
--   4. NULL値のデフォルト補完
--   5. ソースレコードハッシュの生成（変更検知用）
-- =============================================================================

{{ config(
    materialized='incremental',
    unique_key='estimate_number',
    incremental_strategy='merge',
    tags=['silver', 'estimates']
) }}

WITH source AS (
    -- Bronze 層から生データを取得
    SELECT *
    FROM {{ ref('brz_estimates') }}
    {% if is_incremental() %}
    -- incremental 実行時: 前回ロード以降のデータのみ処理
    WHERE _ingestion_timestamp > (SELECT MAX(_loaded_at) FROM {{ this }})
    {% endif %}
),

-- ステータスマスタを結合して正規化コードを取得
status_mapping AS (
    SELECT
        status_key,
        status_code,
        status_name,
        status_name_ja
    FROM {{ ref('status_master') }}
    WHERE status_category = 'ESTIMATE'
),

-- 型変換・クレンジング
cleaned AS (
    SELECT
        -- ビジネスキー
        CAST(LTRIM(RTRIM(s.estimate_number)) AS VARCHAR(50)) AS estimate_number,

        -- 顧客名: NULL 時は '不明' で補完、前後の空白をトリム
        COALESCE(
            NULLIF(LTRIM(RTRIM(CAST(s.customer_name AS NVARCHAR(200)))), ''),
            N'不明'
        ) AS customer_name,

        -- 金額: 文字列 -> DECIMAL(18,2)。カンマ除去、変換失敗時は 0.00
        COALESCE(
            TRY_CAST(REPLACE(REPLACE(s.amount, ',', ''), N'\', '') AS DECIMAL(18,2)),
            0.00
        ) AS amount,

        -- ステータス正規化: ソースのステータス文字列をマスタと突合
        COALESCE(sm.status_code, 10) AS status_code,
        COALESCE(sm.status_name, 'DRAFT') AS status_name,

        -- 日付: 文字列 -> DATETIME2。変換失敗時は NULL
        TRY_CAST(s.created_date AS DATETIME2) AS created_at,
        TRY_CAST(s.modified_date AS DATETIME2) AS modified_at,

        -- 担当者名: トリム
        LTRIM(RTRIM(CAST(s.assigned_to AS NVARCHAR(200)))) AS assigned_to,

        -- メタデータ
        CAST(GETUTCDATE() AS DATETIME2) AS _loaded_at,

        -- ソースレコードハッシュ（変更検知用）
        -- 主要ビジネスカラムを連結してSHA-256ハッシュを生成
        CONVERT(
            VARCHAR(64),
            HASHBYTES(
                'SHA2_256',
                CONCAT_WS('||',
                    COALESCE(s.estimate_number, ''),
                    COALESCE(s.customer_name, ''),
                    COALESCE(s.amount, ''),
                    COALESCE(s.status, ''),
                    COALESCE(s.created_date, ''),
                    COALESCE(s.modified_date, ''),
                    COALESCE(s.assigned_to, '')
                )
            ),
            2  -- 16進数文字列に変換
        ) AS _source_record_hash,

        -- 重複排除用の行番号（同一見積番号で最新の取り込みを優先）
        ROW_NUMBER() OVER (
            PARTITION BY s.estimate_number
            ORDER BY s._ingestion_timestamp DESC
        ) AS _row_num

    FROM source s
    -- ステータス正規化マッピング
    -- ソースのステータス文字列（日本語）をマスタの日本語名と突合
    LEFT JOIN status_mapping sm
        ON LTRIM(RTRIM(s.status)) = sm.status_name_ja
           OR LTRIM(RTRIM(s.status)) = sm.status_name
    WHERE
        -- NULL キーは除外（BRZ-004 対応）
        s.estimate_number IS NOT NULL
)

-- 重複排除: 同一見積番号で最新レコードのみ出力
SELECT
    estimate_number,
    customer_name,
    amount,
    status_code,
    status_name,
    created_at,
    modified_at,
    assigned_to,
    _loaded_at,
    _source_record_hash
FROM cleaned
WHERE _row_num = 1
