-- =============================================================================
-- brz_projects.sql - Bronze: 案件管理リスト（外部テーブル参照）
-- =============================================================================
-- SharePoint Online の案件管理リストから ADF 経由で ADLS Gen2 に取り込まれた
-- Parquet ファイルを OPENROWSET で参照する。
-- =============================================================================

{{ config(
    materialized='view',
    tags=['bronze', 'projects']
) }}

SELECT
    project_number,
    project_name,
    customer_name,
    phase,
    contract_amount,
    start_date,
    end_date,
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
        BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/projects/year=*/month=*/day=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        project_number    VARCHAR(50),
        project_name      NVARCHAR(200),
        customer_name     NVARCHAR(200),
        phase             NVARCHAR(100),
        contract_amount   VARCHAR(50),
        start_date        VARCHAR(50),
        end_date          VARCHAR(50),
        _source_system    VARCHAR(50),
        _source_list      NVARCHAR(100),
        _ingestion_timestamp DATETIME2,
        _ingestion_date   DATE,
        _adf_pipeline_run_id VARCHAR(100),
        _raw_json         NVARCHAR(MAX)
    ) AS result
WHERE
    result.filepath(1) = {{ get_latest_partition('projects', 'year') }}
    AND result.filepath(2) = {{ get_latest_partition('projects', 'month') }}
    AND result.filepath(3) = {{ get_latest_partition('projects', 'day') }}
