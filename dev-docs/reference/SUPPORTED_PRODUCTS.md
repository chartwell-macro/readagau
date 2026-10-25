# Supported products and releases

<!-- Development inventory; README is the package-facing support statement. -->

This page describes support domains for maintainers; it intentionally does not
copy mutable release counts or row totals. The package root
[`README.md`](../../README.md), `list_agau_releases()`, and the checked-in
catalogues/registries are authoritative for the current inventory.

| Product | Supported edition surface |
|---|---|
| Australian Crop Report | Audited national and separately published state workbook roles selected by the release catalogue |
| Agricultural Commodities | Audited outlook and Agricultural Commodity Statistics workbook/table roles selected by the release catalogue |
| Australian Farm Productivity | Conventional and climate-adjusted workbook table families selected by the supported matrix |
| Historical Agricultural Forecast Database | Landing-page discovery plus local CSV/workbook normalisation |
| Weekly commodity prices | Current pages, dated reports and supported archive snapshots parsed into values by `read_agau_prices()`; each row retains source, provider, hash and rights/provenance fields |

Weekly readers return parsed observations, while source terms, provider
attribution and any `rights_status` value remain source-specific. Package code
and package-owned synthetic fixtures are licensed under MIT, copyright Chartwell Macro;
that package licence does not cover source data or third-party material.

## Canonical registries

- `inst/catalogue/release-catalog.csv` and `weekly-release-catalog.csv` hold
  release identities, source URLs and support status.
- `inst/catalogue/source-catalog.csv` records source/product metadata.
- `inst/config/supported-matrix.csv`, `product-pages.csv`, and
  `weekly-series.csv` drive admitted layouts and semantic series.

Read these through `list_agau_releases()`, `agau_source_catalog()` and
`agau_series_catalog()` rather than duplicating their contents in prose.

## Support policy

A discovered page is not automatically supported. Support requires an admitted
asset/profile, structural and semantic tests, canonical validation, cache
replay and a documented provenance/attribution review. A discovered-unverified
release remains outside the supported reader path until those checks pass.
