# Traffic Guarantee Coverage Analysis

A sanitized portfolio example of an ad-hoc analysis that measures how much CRM traffic fell within active partner guarantee periods.

> **Portfolio safety:** This is an illustrative reconstruction based on the task description. It does not contain the original production SQL, source data, internal identifiers, or commercial results. The SQL uses generic PostgreSQL table and column names; the CSV contains fabricated example values.

## Business task

Measure the monthly share of CRM leads and approvals generated while a partner guarantee was active. Report the result separately by offer and GEO so that coverage can be compared across business segments.

## Data model

The example query expects two generic source tables:

| Table | Columns used |
| --- | --- |
| `crm_stat` | `traffic_date`, `web_id`, `offer_id`, `geo`, `leads`, `approvals` |
| `partner_guarantees` | `web_id`, `offer_id`, `guarantee_start`, `guarantee_end` |

Map these names to the relevant source fields before running the query. No database connection details or production schema names are included.

## Logic

1. Aggregate CRM metrics by day, web, offer, and GEO.
2. Exclude guarantee records with missing or reversed date bounds.
3. Mark daily traffic as guaranteed when a matching web and offer have an active guarantee on that date. Both boundaries are inclusive.
4. Aggregate by month, offer, and GEO, then calculate the share of leads and approvals covered by a guarantee.

The match uses `EXISTS`, so overlapping guarantee records do not multiply CRM traffic. If the denominator is zero, the corresponding coverage is returned as `NULL`.

## Metrics

- CRM leads and approvals
- Leads and approvals under guarantee
- Lead coverage, %
- Approval coverage, %

Coverage is calculated as guaranteed volume divided by total CRM volume for the same month, offer, and GEO.

## Files

- [`sql/traffic_guarantee_coverage.sql`](sql/traffic_guarantee_coverage.sql) — commented PostgreSQL example query.
- [`examples/result_example.csv`](examples/result_example.csv) — fabricated output rows to illustrate the result format.

## Result

The query produces one row per month, offer, and GEO. The CSV is synthetic and is not a result from the commercial task.
