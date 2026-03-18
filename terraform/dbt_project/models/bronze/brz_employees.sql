-- =============================================================================
-- brz_employees.sql - Bronze: 担当者マスタ（外部テーブル参照）
-- =============================================================================
-- SharePoint Online の担当者マスタリストから ADF 経由で ADLS Gen2 に取り込まれた
-- Parquet ファイルを OPENROWSET で参照する。
-- =============================================================================

{{ config(
    materialized='view',
    tags=['bronze', 'employees', 'master']
) }}

SELECT
    employee_number,
    employee_name,
    department,
    job_title,
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
        BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/employees/year=*/month=*/day=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        employee_number   VARCHAR(50),
        employee_name     NVARCHAR(200),
        department        NVARCHAR(100),
        job_title         NVARCHAR(100),
        _source_system    VARCHAR(50),
        _source_list      NVARCHAR(100),
        _ingestion_timestamp DATETIME2,
        _ingestion_date   DATE,
        _adf_pipeline_run_id VARCHAR(100),
        _raw_json         NVARCHAR(MAX)
    ) AS result
WHERE
    result.filepath(1) = {{ get_latest_partition('employees', 'year') }}
    AND result.filepath(2) = {{ get_latest_partition('employees', 'month') }}
    AND result.filepath(3) = {{ get_latest_partition('employees', 'day') }}
