# API map

<!-- Development map only; installed help generated from Roxygen is the
     package-facing API source. See CONTENT_MAP.md for source-of-truth rules. -->

This page is a navigation aid for maintainers. For signatures, defaults,
return columns/classes, conditions and runnable examples, use the installed
help or the generated reference site. Edit the Roxygen comments in `R/`, not
these tables, when the public API changes.

## Discovery and transport

| Function | Purpose |
|---|---|
| `list_agau_releases()` | Discover exact product releases and support status |
| `download_agau_release()` | Cache selected release assets immutably |
| `agau_cache_dir()` | Return the user cache location |
| `agau_detect_format()` | Detect supported file bytes independently of extension |

## Product readers

| Function | Purpose |
|---|---|
| `read_crop_report()` | Read national/state Crop Report workbooks |
| `read_agricultural_commodities()` | Read outlook and ACS tables |
| `read_farm_productivity()` | Read conventional and climate-adjusted tables |
| `read_agau_forecast_history()` | Read/cache Historical Forecast Database data |
| `read_agau_prices()` | Parse weekly commodity-price values with source-specific provenance and rights status |

## Catalogues and validation

| Function | Purpose |
|---|---|
| `agau_series_catalog()` | List stable semantic series |
| `validate_agau_release()` | Return release-level validation diagnostics |
| `agau_source_catalog()` | Return source and product metadata |
| `agau_observation_schema()` | Return the observation contract |
| `agau_release_manifest_schema()` | Return the release-manifest contract |
| `agau_raw_asset_manifest_schema()` | Return the raw-asset contract |

## Vintages

| Function | Purpose |
|---|---|
| `compare_agau_vintages()` | Run one or all comparison operations |
| `agau_history_revision()` | Compare historical observations |
| `agau_forecast_revision()` | Compare forecast/projection vintages |
| `agau_forecast_error()` | Compare forecasts with realisations |

## Controlled vocabularies and attribution

| Function | Purpose |
|---|---|
| `agau_status()` | Return supported period statuses |
| `agau_missing_reason()` | Return controlled missing reasons |
| `agau_attribution()` | Return source and attribution guidance |
| `crop_report_attribution()` | Return Crop Report attribution guidance |

Use installed Rd help for full arguments, return values and typed conditions.
The weekly reader returns parsed observations; source terms remain specific to
each upstream publication and provider. See `agau_attribution()` before
publishing results.
