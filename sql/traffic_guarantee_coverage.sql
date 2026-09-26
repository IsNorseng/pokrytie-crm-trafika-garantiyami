-- Обезличенная реконструкция для портфолио, а не исходный рабочий запрос.
-- Задайте $1 как 1 августа, а $2 как 1 октября нужного года (конечная дата не включается).
-- До сопоставления проверьте корректность офферов в выгрузке гарантов.
-- Границы гарантии включены; EXISTS не дублирует трафик при пересекающихся периодах.

WITH report_period AS (
    SELECT $1::date AS start_date, $2::date AS end_date_exclusive
),
crm_daily AS (
    -- Собираем CRM-метрики за день по вебу, офферу и GEO.
    -- Если в исходной выгрузке есть sub_id, его можно сохранить на детальном уровне;
    -- описанное в задаче сопоставление гаранта выполняется по вебу и офферу.
    SELECT
        s.traffic_date::date AS traffic_date,
        s.web_id,
        s.offer_id,
        s.geo,
        SUM(s.leads) AS crm_leads,
        SUM(s.approvals) AS crm_approvals
    FROM crm_stat AS s
    CROSS JOIN report_period AS p
    WHERE s.traffic_date::date >= p.start_date
      AND s.traffic_date::date < p.end_date_exclusive
    GROUP BY
        s.traffic_date::date,
        s.web_id,
        s.offer_id,
        s.geo
),
valid_guarantees AS (
    -- Исключаем неполные периоды и случаи, когда дата начала позже даты окончания.
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
    -- День CRM покрыт, если гарантия совпала по вебу, офферу и дате.
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
monthly_by_geo AS (
    -- Первая сводка: отдельно по GEO, суммарно по офферам.
    SELECT
        date_trunc('month', traffic_date)::date AS month,
        geo,
        SUM(crm_approvals) AS crm_approvals,
        SUM(crm_leads) AS crm_leads,
        SUM(CASE WHEN is_guaranteed THEN crm_leads ELSE 0 END) AS leads_under_guarantee,
        SUM(CASE WHEN is_guaranteed THEN crm_approvals ELSE 0 END) AS approvals_under_guarantee
    FROM classified
    GROUP BY date_trunc('month', traffic_date)::date, geo
),
monthly_by_offer AS (
    -- Вторая сводка: отдельно по офферу, суммарно по GEO.
    SELECT
        date_trunc('month', traffic_date)::date AS month,
        offer_id::text AS offer_id,
        SUM(crm_approvals) AS crm_approvals,
        SUM(crm_leads) AS crm_leads,
        SUM(CASE WHEN is_guaranteed THEN crm_leads ELSE 0 END) AS leads_under_guarantee,
        SUM(CASE WHEN is_guaranteed THEN crm_approvals ELSE 0 END) AS approvals_under_guarantee
    FROM classified
    GROUP BY date_trunc('month', traffic_date)::date, offer_id
),
report_rows AS (
    SELECT
        'По GEO'::text AS report_breakdown,
        month,
        geo::text AS geo,
        NULL::text AS offer_id,
        crm_approvals,
        crm_leads,
        leads_under_guarantee,
        approvals_under_guarantee
    FROM monthly_by_geo

    UNION ALL

    SELECT
        'По офферу'::text AS report_breakdown,
        month,
        NULL::text AS geo,
        offer_id,
        crm_approvals,
        crm_leads,
        leads_under_guarantee,
        approvals_under_guarantee
    FROM monthly_by_offer
)
SELECT
    report_breakdown AS "Срез",
    month AS "Месяц",
    geo AS "GEO",
    offer_id AS "Оффер",
    crm_approvals AS "Аппрувов CRM",
    crm_leads AS "Лидов CRM",
    leads_under_guarantee AS "Лидов под гарантом",
    approvals_under_guarantee AS "Аппрувов под гарантом",
    ROUND(100.0 * approvals_under_guarantee / NULLIF(crm_approvals, 0), 2) AS "Аппрувов под гарантом, %",
    ROUND(100.0 * leads_under_guarantee / NULLIF(crm_leads, 0), 2) AS "Лидов под гарантом, %"
FROM report_rows
ORDER BY month, report_breakdown, geo, offer_id;
