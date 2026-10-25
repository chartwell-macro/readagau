# readagau

`readagau` provides reproducible access to versioned data published by the
Australian Bureau of Agricultural and Resource Economics and Sciences
(ABARES). It resolves exact editions, caches official source assets
immutably, returns tidy observations, and retains release, table, provider,
and SHA-256 provenance.

## Supported data

| Product | Package surface |
|---|---|
| Australian Crop Report | All 66 quarterly editions from February 2010 to June 2026: national tables for every edition and state tables for the 64 editions with separate state workbooks |
| Agricultural Commodities outlook | All 66 quarterly editions from March 2010 to June 2026: the report-backed Major indicators table for March and June 2010 and all audited outlook-workbook tables for the 64 editions from September 2010 |
| Weekly commodity prices | 475 verified complete-table snapshots from 13 October 2016 through 23 July 2026, plus all 33 current A1–A25 and H1–H8 chart observations |
| Agricultural Commodity Statistics | All 18 table families in the supported March and June 2026 editions |
| Australian Farm Productivity | 19 conventional and seven climate-adjusted tables |
| Historical Agricultural Forecast Database | Package-owned file and cache normalisation |

## Installation

```sh
R CMD build .
R CMD INSTALL readagau_0.1.0.tar.gz
```

Historical PDF parsing uses Poppler's `pdftotext` executable.

## Use

```r
library(readagau)

crop <- read_crop_report(
  release = "acr-2010-02-01-no-153",
  assets = "national",
  view = "canonical"
)

outlook <- read_agricultural_commodities(
  release = "ac-2010-03-01",
  datasets = "outlook",
  view = "canonical"
)

weekly <- read_agau_prices(
  snapshot = "all",
  from = "2016-10-13",
  to = "2026-07-23"
)
```

Use an exact ID from `list_agau_releases()` for reproducible replay.
`release = "latest"` and `snapshot = "latest"` resolve the newest audited
edition. The readers also accept supported local official files.

## Reproducibility

Exact raw assets are stored immutably under
`raw/<product>/<release_id>/<sha256>/<asset>`. Parsed results are keyed by
source hash and parser version. Missing and bounded source cells remain
numeric `NA` with an explicit `missing_reason`; stable `series_id` and
`observation_key` values support release-to-release comparisons.

Installed help is available through `help(package = "readagau")`, with worked
examples in the package vignettes. Engineering inventories and certification
evidence are retained in the source repository under `dev-docs/`.

Package code is licensed under MIT.
