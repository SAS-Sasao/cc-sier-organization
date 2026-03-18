-- =============================================================================
-- anonymize_name.sql - 氏名匿名化マクロ（SHA-256 ベース、var 制御）
-- =============================================================================
-- 個人情報保護のための氏名匿名化マクロ。
-- dbt の var('anonymize_pii') が true の場合にハッシュベースの匿名化を適用する。
--
-- 匿名化方式:
--   SHA-256(氏名 || ソルト) の先頭8文字を使用して「担当者_xxxx」形式に変換。
--   ソルトは環境変数 ANONYMIZATION_SALT で管理し、環境ごとに異なる値を使用。
--
-- 使用例:
--   {{ anonymize_name('emp.employee_name') }}
--
-- 実行方法:
--   匿名化有効: dbt run --vars '{"anonymize_pii": true}'
--   匿名化無効: dbt run （デフォルト）
-- =============================================================================

{% macro anonymize_name(column_name) %}
    {% if var('anonymize_pii', false) %}
        {# -- 匿名化有効: SHA-256ハッシュベースのマスク値に変換 #}
        CONCAT(
            N'担当者_',
            LEFT(
                CONVERT(
                    VARCHAR(64),
                    HASHBYTES(
                        'SHA2_256',
                        CONCAT(
                            COALESCE(CAST({{ column_name }} AS NVARCHAR(200)), ''),
                            '||',
                            '{{ var("anonymization_salt") }}'
                        )
                    ),
                    2
                ),
                4
            )
        )
    {% else %}
        {# -- 匿名化無効: カラム値をそのまま返す #}
        {{ column_name }}
    {% endif %}
{% endmacro %}
