# API map

<!-- Development reference; installed help is the package-facing API source. -->

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
| `read_agau_prices()` | Return rights-gated weekly/fertiliser metadata |

## Catalogues and validation

| Function | Purpose |
|---|---|
| `agau_series_catalog()` | List stable semantic series |
| `validate_agau_release()` | Return release-level validation diagnostics |
| `agau_source_catalog()` | Return source, product and rights metadata |
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
| `agau_attribution()` | Return source and rights guidance |
| `crop_report_attribution()` | Return Crop Report attribution guidance |

Use installed Rd help for full arguments, return values and typed conditions.
