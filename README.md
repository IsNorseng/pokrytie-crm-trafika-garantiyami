# CRM Traffic Coverage by Partner Guarantees

A sanitized portfolio example of an ad-hoc analysis that measures the share of CRM leads and approvals recorded while partner guarantees were active.

> **Portfolio safety:** This is an illustrative reconstruction based on the task description. The original production SQL, source data, client details, internal identifiers, and commercial results are not included. The query uses generic PostgreSQL table and column names; the CSV contains fabricated values for demonstration only.

## Business task

For August and September of the target year, calculate what share of CRM traffic was covered by an active guarantee. Produce separate summary tables by GEO and by offer.

The requested output contains:

- CRM approvals and leads
- CRM leads recorded on days when a matching guarantee was active
- CRM approvals recorded on days when a matching guarantee was active
- Approval coverage, %
- Lead coverage, %

## Data and matching logic

The workflow uses daily CRM statistics, typically at web + offer grain or web + sub + offer grain, and a separate extract of guarantee periods.

| Source | Generic fields used |
| --- | --- |
| `crm_stat` | `traffic_date`, `web_id`, `offer_id`, `geo`, `leads`, `approvals` |
| `partner_guarantees` | `web_id`, `offer_id`, `guarantee_start`, `guarantee_end` |

Before matching, validate the guarantee extract against the relevant offer reference so incorrectly recorded offers do not silently distort coverage. The example SQL also excludes guarantee rows with missing or reversed date bounds. Daily CRM rows are matched to guarantees by `web_id` + `offer_id` and date; an active guarantee marks that day's leads and approvals as covered. The optional `sub_id` can remain in a detailed extract, but it is not part of the guarantee match described here.

## Metrics

- **Lead coverage, %** = leads under guarantee / CRM leads × 100
- **Approval coverage, %** = approvals under guarantee / CRM approvals × 100

Date bounds are inclusive. `EXISTS` prevents overlapping guarantee rows from counting the same daily traffic more than once. If a denominator is zero, coverage is returned as `NULL`.

## Result layout

The SQL returns both breakdowns in one result set. `report_breakdown` identifies the table grain: `geo` rows contain a GEO and leave `offer_id` empty; `offer` rows contain an offer and leave GEO empty. Filter `month` to the August and September rows for the target year.

The [synthetic CSV example](examples/result_example.csv) illustrates this layout with fabricated data. Its example year is illustrative and does not identify the year of the original task.

## Files

- [`sql/traffic_guarantee_coverage.sql`](sql/traffic_guarantee_coverage.sql) — commented PostgreSQL query. Run it with `$1` set to August 1 and `$2` set to October 1 of the target year, so both August and September are included.
- [`examples/result_example.csv`](examples/result_example.csv) — fabricated output rows; not commercial results.
