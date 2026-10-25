# Getting started

<!-- Development reference; README and vignettes are package-facing. -->

Use the package root [`README.md`](../README.md), installed help and the
[`getting-started`](../vignettes/getting-started.Rmd) vignette first. This page
keeps exact-release and cache details for maintainers and reviewers; it is not
a replacement for those user-facing materials.

## Discover releases

```r
crop_releases <- list_agau_releases("crop_report")
crop_releases[c("release_id", "release_date", "support_status")]
```

The catalogue includes all 66 supported quarterly Crop Report editions from
February 2010 through June 2026.

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

Local files receive checksum-qualified local provenance. To record a reviewed
source identity for a local file, provide both `release_id` and `release_date`;
this records provenance and does not change any upstream licence or terms.

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

## Read Weekly commodity prices

```r
weekly <- read_agau_prices(
  snapshot = "all",
  from = "2016-10-13",
  to = "2026-07-23"
)
```

This returns the complete 475-snapshot table history with exact source and
observation provenance.
