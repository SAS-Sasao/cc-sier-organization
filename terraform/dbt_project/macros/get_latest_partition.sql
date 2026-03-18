-- =============================================================================
-- get_latest_partition.sql - Bronze 層の最新パーティション取得マクロ
-- =============================================================================
-- ADLS Gen2 の Bronze 層 Parquet ファイルの Hive パーティション
-- （year=YYYY/month=MM/day=DD）から最新の日付パーティションを取得する。
--
-- Synapse Serverless SQL Pool の filepath() 関数と組み合わせて使用。
-- Bronze 層の各モデル（brz_*.sql）で呼び出される。
--
-- 使用例:
--   WHERE result.filepath(1) = {{ get_latest_partition('estimates', 'year') }}
--     AND result.filepath(2) = {{ get_latest_partition('estimates', 'month') }}
--     AND result.filepath(3) = {{ get_latest_partition('estimates', 'day') }}
--
-- 動作:
--   1. OPENROWSET でパーティション構造をスキャンし、最新の year/month/day を取得
--   2. 結果をスカラーサブクエリとして返す
--
-- 注意:
--   - Synapse Serverless SQL Pool ではメタデータキャッシュがあるため、
--     新しいパーティションが即座に認識されない場合がある。
--     ADF パイプラインの完了後、dbt run まで十分な間隔を設ける。
-- =============================================================================

{% macro get_latest_partition(source_name, partition_part) %}

    {#
        partition_part は 'year', 'month', 'day' のいずれか。
        filepath(1) = year, filepath(2) = month, filepath(3) = day に対応。
    #}

    {% if partition_part == 'year' %}
    (
        SELECT MAX(latest.partition_year)
        FROM (
            SELECT
                scan.filepath(1) AS partition_year
            FROM
                OPENROWSET(
                    BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                    FORMAT = 'PARQUET'
                )
                WITH (
                    _dummy VARCHAR(1)
                ) AS scan
            GROUP BY scan.filepath(1)
        ) AS latest
    )
    {% elif partition_part == 'month' %}
    (
        SELECT MAX(latest.partition_month)
        FROM (
            SELECT
                scan.filepath(2) AS partition_month
            FROM
                OPENROWSET(
                    BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                    FORMAT = 'PARQUET'
                )
                WITH (
                    _dummy VARCHAR(1)
                ) AS scan
            WHERE
                scan.filepath(1) = (
                    SELECT MAX(inner_scan.filepath(1))
                    FROM
                        OPENROWSET(
                            BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                            FORMAT = 'PARQUET'
                        )
                        WITH (
                            _dummy VARCHAR(1)
                        ) AS inner_scan
                )
            GROUP BY scan.filepath(2)
        ) AS latest
    )
    {% elif partition_part == 'day' %}
    (
        SELECT MAX(latest.partition_day)
        FROM (
            SELECT
                scan.filepath(3) AS partition_day
            FROM
                OPENROWSET(
                    BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                    FORMAT = 'PARQUET'
                )
                WITH (
                    _dummy VARCHAR(1)
                ) AS scan
            WHERE
                -- 最新の year
                scan.filepath(1) = (
                    SELECT MAX(y.filepath(1))
                    FROM
                        OPENROWSET(
                            BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                            FORMAT = 'PARQUET'
                        )
                        WITH (_dummy VARCHAR(1)) AS y
                )
                -- 最新の month（最新 year 内）
                AND scan.filepath(2) = (
                    SELECT MAX(m.filepath(2))
                    FROM
                        OPENROWSET(
                            BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                            FORMAT = 'PARQUET'
                        )
                        WITH (_dummy VARCHAR(1)) AS m
                    WHERE m.filepath(1) = (
                        SELECT MAX(y2.filepath(1))
                        FROM
                            OPENROWSET(
                                BULK 'https://{{ var("adls_account_name") }}.dfs.core.windows.net/{{ var("adls_container_name") }}/bronze/{{ source_name }}/year=*/month=*/day=*/*.parquet',
                                FORMAT = 'PARQUET'
                            )
                            WITH (_dummy VARCHAR(1)) AS y2
                    )
                )
            GROUP BY scan.filepath(3)
        ) AS latest
    )
    {% else %}
        {{ exceptions.raise_compiler_error("get_latest_partition: partition_part must be 'year', 'month', or 'day'. Got: " ~ partition_part) }}
    {% endif %}

{% endmacro %}
