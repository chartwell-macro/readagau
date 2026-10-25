# Quarterly history audit

This development record describes the official-byte gate behind the quarterly
catalogue. It is excluded from the package tarball; the concise package-facing
statement is in the README.

## Admitted editions

- Australian Crop Report: 66 quarterly editions, No. 153 (February 2010)
  through No. 218 (June 2026).
- Agricultural Commodities outlook: 66 quarterly editions, March 2010 through
  June 2026.

The catalogue stores direct URLs on the official DAFF SirsiDynix archive host.
Every Crop Report edition has an official national workbook. ABARES published
separate state workbooks for 64 editions. Sixty-four Agricultural Commodities
editions have outlook workbooks.

March and June 2010 Agricultural Commodities are report-backed. The package
extracts their published `Major indicators of Australia's commodity sector`
table with edition-specific period/status profiles. This is the affirmative
surface for those two editions. From September 2010, the package exposes the
audited outlook-workbook tables.

## Gate

Run from a source checkout with the audited official assets:

```sh
Rscript --vanilla dev-docs/tools/audit-quarterly-history.R \
  /path/to/workbook-assets \
  /path/to/report-assets \
  /tmp/readagau-quarterly-history-audit.csv
```

The gate checks all 196 structured assets:

- 66 Crop Report national workbooks;
- 64 Crop Report state workbooks;
- 64 Agricultural Commodities outlook workbooks; and
- two Agricultural Commodities report PDFs.

The completed 27 July 2026 evidence is
[`evidence/quarterly-history-audit-2026-07-27.csv`](evidence/quarterly-history-audit-2026-07-27.csv).
Its SHA-256 is
`5c185f22b80d0c3e39df31fa18711adde690e1e9427be3ab1962aa7f96a4042b`.
All 196 assets validated and produced 698,944 observations:

| Product and role | Assets | Observations |
|---|---:|---:|
| Crop Report national | 66 | 270,678 |
| Crop Report state | 64 | 339,888 |
| Agricultural Commodities outlook workbook | 64 | 87,898 |
| Agricultural Commodities report-backed table | 2 | 480 |

Every asset has a 64-character SHA-256 and every parsed release has zero
duplicate canonical observation keys.

For each asset it records release identity, role, archive asset ID and index,
SHA-256, observation and table counts, elapsed time, schema validity and
duplicate canonical-key count. The command fails when any asset is missing,
cannot be parsed, has incomplete provenance or semantics, or produces a
duplicate canonical observation key.

## Audited provider transitions

The cross-era gate includes the 2010 report/workbook boundary, the early
binary `.xls` layouts, 2012–14 Crop Report layout anomalies, the 2020 and 2023
workbook generations, and the 2024 modern profile transition.

The June 2012 Crop Report workbook publishes `2019-10` in a sequential
2009-10 row position in Table 13. For exact release
`acr-2012-06-01-no-162`, the parser applies a fail-closed normalization to
`2009-10` and records that correction in the source note. Five-year-average
labels remain named summary periods.

For archive records without a day-level publication timestamp, release
identity uses the edition-month first day and the catalogue warning records
the official archive asset ID. Modern editions retain their audited exact
release dates.
