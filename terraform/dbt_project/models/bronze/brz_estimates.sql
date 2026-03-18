-- =============================================================================
-- brz_estimates.sql - Bronze: 見積管理リスト（外部テーブル参照）
-- =============================================================================
-- SharePoint Online の見積管理リストから ADF 経由で ADLS Gen2 に取り込まれた
-- Parquet ファイルを OPENROWSET で参照する。
-- パーティション（year/month/day）を考慮して最新データを取得する。
-- =============================================================================

{{ config(
    materialized='view',
    tags=['bronze', 'estimates']
) }}

SELECT
    estimate_number,
    customer_name,
    amount,
    status,
    created_date,
    modified_date,
    assigned_to,
    _source_system,
    _source_list,
    _ingestion_timestamp,
    _ingestion_date,
    _adf_pipeline_run_id,
    _raw_json,
    -- パーティションカラム（Synapse が filepath() 関数で自動抽出）
    result.filepath(1) AS _partition_year,
    result.filepath(2) AS _partition_month,
    result.filepath(3) AS _partition_day
FROM
    OPENROWSET(
        BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/estimates/year=*/month=*/day=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        estimate_number   VARCHAR(50),
        customer_name     NVARCHAR(200),
        amount            VARCHAR(50),
        status            NVARCHAR(100),
        created_date      VARCHAR(50),
        modified_date     VARCHAR(50),
        assigned_to       NVARCHAR(200),
        _source_system    VARCHAR(50),
        _source_list      NVARCHAR(100),
        _ingestion_timestamp DATETIME2,
        _ingestion_date   DATE,
        _adf_pipeline_run_id VARCHAR(100),
        _raw_json         NVARCHAR(MAX)
    ) AS result
WHERE
    -- 最新パーティションのデータのみ取得
    -- get_latest_partition マクロで最新の日付パーティションを取得
    result.filepath(1) = {{ get_latest_partition('estimates', 'year') }}
    AND result.filepath(2) = {{ get_latest_partition('estimates', 'month') }}
    AND result.filepath(3) = {{ get_latest_partition('estimates', 'day') }}
