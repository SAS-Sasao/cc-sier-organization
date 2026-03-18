-- =============================================================================
-- check_estimate_amount_range.sql - 見積金額の範囲チェック（シングルテスト）
-- =============================================================================
-- Silver 層の stg_estimates における見積金額の異常値を検知する。
-- 負の金額や極端に高額な見積を検出し、データ品質の劣化を早期に把握する。
--
-- 対応品質ルール:
--   SLV-020: 見積金額正値チェック（負の金額）
--   SLV-021: 見積金額上限チェック（10億円超）
--   ADT-010: 金額の統計的異常検知（3sigma 逸脱）
--
-- 動作:
--   - 負の金額のレコードを検出
--   - 10億円を超える金額のレコードを検出
--   - 過去30日の移動平均から 3sigma を超える金額を検出
--   - 該当レコードがあれば返す（= テスト失敗）
-- =============================================================================

WITH amount_stats AS (
    -- 過去30日間の金額統計（3sigma 検知用）
    SELECT
        AVG(amount) AS avg_amount,
        STDEV(amount) AS stddev_amount
    FROM {{ ref('stg_estimates') }}
    WHERE
        created_at >= DATEADD(DAY, -30, GETUTCDATE())
        AND amount > 0  -- 正の金額のみで統計量を算出
),

violations AS (
    -- 範囲外の見積金額を検出
    SELECT
        e.estimate_number,
        e.amount,
        e.customer_name,
        e.created_at,
        CASE
            WHEN e.amount < 0
                THEN 'NEGATIVE_AMOUNT'
            WHEN e.amount > 1000000000
                THEN 'EXCEEDS_UPPER_LIMIT_1B'
            WHEN s.stddev_amount > 0
                AND ABS(e.amount - s.avg_amount) > (3 * s.stddev_amount)
                THEN 'STATISTICAL_OUTLIER_3SIGMA'
            ELSE NULL
        END AS violation_type,
        s.avg_amount AS reference_avg,
        s.stddev_amount AS reference_stddev
    FROM {{ ref('stg_estimates') }} e
    CROSS JOIN amount_stats s
    WHERE
        -- 負の金額
        e.amount < 0
        -- 10億円超
        OR e.amount > 1000000000
        -- 3sigma 逸脱（統計量が計算可能な場合のみ）
        OR (
            s.stddev_amount > 0
            AND ABS(e.amount - s.avg_amount) > (3 * s.stddev_amount)
        )
)

-- 違反レコードを返す（テスト失敗行）
SELECT
    estimate_number,
    amount,
    customer_name,
    created_at,
    violation_type,
    reference_avg,
    reference_stddev
FROM violations
WHERE violation_type IS NOT NULL
