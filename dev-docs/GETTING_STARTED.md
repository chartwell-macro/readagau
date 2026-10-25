# Getting started

<!-- Development reference; README and vignettes are package-facing. -->

## Discover releases

```r
crop_releases <- list_agau_releases("crop_report")
crop_releases[
  c("release_id", "release_date", "support_status", "unsupported_reason")
]
```

Support status is distinct from discovery. A page can be
`discovered-unverified` without being accepted by a parser.

## Read an exact supported edition

```r
crop <- read_crop_report(
  "acr-2026-06-02-no-218",
  view = "canonical"
)

validation <- validate_agau_release(crop)
stopifnot(validation$valid)
```

Persist the exact release ID, source hash and package version with derived
output.

## Use local source files

```r
reported <- read_agricultural_commodities(
  c(
    outlook = "/path/to/outlook.xlsx",
    statistics = "/path/to/statistics.xlsx"
  ),
  view = "reported"
)
```

Local files receive checksum-qualified local provenance. To assign reviewed
official provenance, provide both `release_id` and `release_date`.

## Choose a view

- `reported` preserves every admitted source row.
- `canonical` applies the checked-in precedence and identity policy.

Use reported data for audits and canonical data for one stable observation per
semantic key. Validation fails when equal-priority values remain ambiguous.

## Compare vintages

```r
changes <- compare_agau_vintages(
  "agricultural_commodities",
  releases = c("ac-2026-03-03", "ac-2026-06-02"),
  comparison = "forecast_revision"
)
```

Inspect structural-break diagnostics before interpreting changes as revisions.
Use `agau_attribution()` when publishing results.
