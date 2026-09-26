-- Sanitized portfolio demonstration, not the original production query.
-- Map generic table and column names to the target schema before use.
-- Guarantee date bounds are inclusive. EXISTS prevents duplicate CRM counts
-- when guarantee records overlap. A zero denominator produces NULL coverage.

WITH crm_daily AS (
    -- Normalize CRM traffic to one row per day, web, offer, and GEO.
    SELECT
        traffic_date::date AS traffic_date,
        web_id,
        offer_id,
        geo,
        SUM(leads) AS crm_leads,
        SUM(approvals) AS crm_approvals
    FROM crm_stat
    GROUP BY
        traffic_date::date,
        web_id,
        offer_id,
        geo
),
valid_guarantees AS (
    -- Keep only complete, chronologically valid guarantee periods.
    SELECT
        web_id,
        offer_id,
        guarantee_start::date AS guarantee_start,
        guarantee_end::date AS guarantee_end
    FROM partner_guarantees
    WHERE guarantee_start IS NOT NULL
      AND guarantee_end IS NOT NULL
      AND guarantee_start::date <= guarantee_end::date
),
classified AS (
    -- EXISTS flags a CRM row once even if several guarantee periods overlap.
    SELECT
        c.*,
        EXISTS (
            SELECT 1
            FROM valid_guarantees AS g
            WHERE g.web_id = c.web_id
              AND g.offer_id = c.offer_id
              AND c.traffic_date BETWEEN g.guarantee_start AND g.guarantee_end
        ) AS is_guaranteed
    FROM crm_daily AS c
),
monthly AS (
    -- Sum total and covered volumes at the reporting grain.
    SELECT
        date_trunc('month', traffic_date)::date AS month,
        offer_id,
        geo,
        SUM(crm_leads) AS crm_leads,
        SUM(crm_approvals) AS crm_approvals,
        SUM(CASE WHEN is_guaranteed THEN crm_leads ELSE 0 END) AS leads_under_guarantee,
        SUM(CASE WHEN is_guaranteed THEN crm_approvals ELSE 0 END) AS approvals_under_guarantee
    FROM classified
    GROUP BY
        date_trunc('month', traffic_date)::date,
        offer_id,
        geo
)
SELECT
    month,
    offer_id,
    geo,
    crm_leads,
    crm_approvals,
    leads_under_guarantee,
    approvals_under_guarantee,
    ROUND(100.0 * leads_under_guarantee / NULLIF(crm_leads, 0), 2) AS lead_coverage_pct,
    ROUND(100.0 * approvals_under_guarantee / NULLIF(crm_approvals, 0), 2) AS approval_coverage_pct
FROM monthly
ORDER BY month, offer_id, geo;
