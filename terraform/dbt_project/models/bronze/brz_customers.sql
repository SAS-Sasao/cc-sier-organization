-- =============================================================================
-- brz_customers.sql - Bronze: 顧客マスタ（外部テーブル参照）
-- =============================================================================
-- SharePoint Online の顧客マスタリストから ADF 経由で ADLS Gen2 に取り込まれた
-- Parquet ファイルを OPENROWSET で参照する。
-- =============================================================================

{{ config(
    materialized='view',
    tags=['bronze', 'customers', 'master']
) }}

SELECT
    customer_code,
    customer_name,
    industry,
    region,
    contract_status,
    _source_system,
    _source_list,
    _ingestion_timestamp,
    _ingestion_date,
    _adf_pipeline_run_id,
    _raw_json,
    result.filepath(1) AS _partition_year,
    result.filepath(2) AS _partition_month,
    result.filepath(3) AS _partition_day
FROM
    OPENROWSET(
        BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/customers/year=*/month=*/day=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        customer_code     VARCHAR(50),
        customer_name     NVARCHAR(200),
        industry          NVARCHAR(100),
        region            NVARCHAR(100),
        contract_status   NVARCHAR(50),
        _source_system    VARCHAR(50),
        _source_list      NVARCHAR(100),
        _ingestion_timestamp DATETIME2,
        _ingestion_date   DATE,
        _adf_pipeline_run_id VARCHAR(100),
        _raw_json         NVARCHAR(MAX)
    ) AS result
WHERE
    result.filepath(1) = {{ get_latest_partition('customers', 'year') }}
    AND result.filepath(2) = {{ get_latest_partition('customers', 'month') }}
    AND result.filepath(3) = {{ get_latest_partition('customers', 'day') }}
