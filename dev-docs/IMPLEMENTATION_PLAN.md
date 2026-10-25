# `readagau` package implementation plan

<!-- Development plan; excluded from the package tarball. -->

Status: approved design for manager handoff  
Prepared: 2026-07-27  
Primary sources: [ABARES Australian Crop Report](https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/australian-crop-report), [Agricultural Commodities and Agricultural Commodity Statistics](https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook), [Australian Farm Productivity](https://www.agriculture.gov.au/abares/research-topics/productivity/agricultural-productivity-estimates), [weekly commodity prices](https://www.agriculture.gov.au/abares/data/weekly-commodity-price-update) and the [fertiliser dashboard](https://www.agriculture.gov.au/abares/data)  
Downstream consumer: Chartwell (`/path/to/user/dev/data_viewer`)  

## 1. Executive decision

Build `readagau` as a small, standalone R package for reproducible Australian agricultural time-series data published by ABARES. The name is intentionally shorter than `readabaresoutlook` and sufficiently distinct from the existing `read.abares` package.

The package covers six related source surfaces:

1. the complete history, estimates and forecasts published in each quarterly Australian Crop Report national and state workbook;
2. the Agricultural Commodities outlook workbook, including macro assumptions, sector totals and commodity-level prices, production, consumption, stocks, trade and export values;
3. the Agricultural Commodities statistical workbook and Agricultural Commodity Statistics history for farm terms of trade, costs, production, yields and agriculture, fisheries and forestry trade;
4. the annual Australian Farm Productivity supporting workbook, including conventional and climate-adjusted total factor productivity by industry and geography;
5. the weekly commodity-price update; and
6. the fertiliser dashboard's Australian and global urea prices and fertiliser import quantities.

The Historical Agricultural Forecast Database remains a supporting input for forecast evaluation. The existing `read.abares` package is useful prior art for that file, but it is not the runtime client for these six surfaces.

The Crop Report and Agricultural Commodities Report are released on the same quarterly schedule and share the same archive, period-status conventions and vintage problem. Productivity is annual and historically revised. Weekly prices and fertiliser data have different transports and third-party attribution risks, but they still belong in the same agricultural-data package once those rights and endpoints pass explicit gates. Keeping the sources together avoids duplicating discovery, transport, cache, provenance and comparison code while retaining separate product-specific parsers.

The app's normal request will be the latest release, but the package must preserve every fetched release as an immutable vintage. It must support:

- the latest coherent history/estimate/forecast view;
- both short-term quarterly outlooks and the March five-year medium-term outlook;
- exact historical releases;
- revisions to values previously presented as history or estimates;
- revisions to forecasts for a fixed target period; and
- forecast errors when a forecast later becomes an estimate or published historical value;
- annual productivity-history revisions; and
- reproducible dated snapshots for weekly commodity and fertiliser observations.

Do not parse data from a report PDF when an Excel or CSV source exists. Store relevant PDFs beside workbooks for release notes, definitions and validation. Do not scrape a chart image when a stable underlying table or structured endpoint exists.

## 2. Why a separate lightweight package

The current rOpenSci [`read.abares`](https://docs.ropensci.org/read.abares/reference/index.html) package is useful prior art. Its `read_historical_forecast_database()` function already normalises:

- issue year and month;
- forecast financial year;
- original forecast value; and
- latest actual value.

It does not expose the quarterly Australian Crop Report workbooks, Agricultural Commodities outlook/statistical workbooks, Farm Productivity workbook, weekly price update or fertiliser dashboard. Its Farm Data Portal and trade readers are outside the present Chartwell use case and must not drive this package's scope. `read.abares` also imports a broad geospatial stack that these time-series routes do not need. The implementation should therefore:

- use `read.abares` naming and historical-forecast semantics where they are sound;
- review its source before designing the Historical Forecast Database parser;
- avoid a mandatory runtime dependency on `read.abares`;
- offer an optional compatibility/coercion helper if useful; and
- offer compatible field names where that improves interoperability without copying the existing package's broad scope; and
- offer suitable release readers upstream after the local API has stabilised.

If upstream accepts the complete feature and its dependency footprint becomes acceptable, the manager may later retire the companion package. That is not a prerequisite for this implementation.

## 3. Evidence baseline

The Crop Report source audit covered all 10 digital releases currently linked from March 2024 through June 2026, including 20 national/state workbooks. The Agricultural Commodities audit inspected the March and June 2026 outlook and statistical workbooks; Phase 0 must extend that audit across every digitally linked edition from March 2024 forward before parser implementation is accepted.

Observed conditions the implementation must handle:

- Each edition is a release bundle containing a national workbook, state workbook and report PDF. A Word report is also commonly offered but is not required.
- The June 2026 national workbook contains `Index` and `Table 1` through `Table 17`.
- The June 2026 state workbook contains `Index`, `Australia`, New South Wales, Queensland, South Australia, Tasmania, Victoria and Western Australia.
- March 2025 download links end in `.xls`, but the files contain OOXML `.xlsx` bytes.
- Some September and December 2025 assets have effectively blank source filenames.
- State sheet names have changed between compact and spaced forms, such as `NewSouthWales` versus `New South Wales`.
- Table widths and row counts expand as new periods are added.
- Some March editions and non-March editions swap the shapes of Tables 1–3 and Tables 4–10.
- Period labels carry semantic suffixes: `f` means ABARES forecast and `s` means ABARES estimate.
- The same target period changes both value and status across releases.
- March 2026 Agricultural Commodities contains an `Index`, `Key macro`, `Major indicators` and 13 commodity/sector outlook sheets. Its period surface runs to 2030–31 and uses `s`, `f` and `z` for estimate, forecast and projection.
- June 2026 Agricultural Commodities contains an `Index`, `Key Macro`, `Major Indicators` and 11 commodity/sector outlook sheets. It is a shorter outlook to 2026–27 and adds published percentage-change columns.
- Commodity sheet names and groupings change between editions: for example March separates chicken and pig while June combines `Pigs, Poultry and Eggs`; March includes dedicated horticulture while June does not.
- Both audited statistical workbooks contain an `Index` plus Tables 1–18. They span farm terms of trade, costs and returns, production/value/volume/price indicators, world prices and balances, Australian production, yields, exports and fisheries trade.
- Agricultural Commodities metrics mix calendar years, Australian financial years and marketing years, and mix nominal and real values. These dimensions must be explicit rather than inferred from a generic period label.
- The June 2026 Farm Productivity release supplies one supporting XLSX covering 1977–78 to 2024–25 by industry, state and region. The release notes state that historical estimates were updated and that the interim 2022–23 to 2024–25 climate-adjustment method will itself be revised when the enhanced method enters production.
- The weekly commodity-price page publishes a current table in HTML and is normally updated each Thursday. Its rows combine weekly, twice-monthly and less-frequent observation dates and carry series-specific units.
- Weekly prices include third-party series such as Cotlook, Intercontinental Exchange, wool, livestock and Global Dairy Trade indicators. The source's data-attribution page must be treated as a series-level licence/redistribution manifest.
- The fertiliser surface is currently presented through a dashboard rather than an obvious versioned bulk download. Phase 0 must prove a stable official structured endpoint and permissible reuse before the parser moves beyond experimental status.

One audited revision sequence is a required golden test:

| Release | Target | Series | Status | Value |
|---|---|---|---|---:|
| June 2025 | 2025–26 | Wheat production, Australia | forecast | 30,560 kt |
| September 2025 | 2025–26 | Wheat production, Australia | forecast | 33,765 kt |
| December 2025 | 2025–26 | Wheat production, Australia | forecast | 35,585 kt |
| March 2026 | 2025–26 | Wheat production, Australia | estimate | 35,985 kt |

The manager must retain the audit files outside the package repository until the fixture and licensing strategy in section 15 is resolved.

A second required golden revision test comes from the Agricultural Commodities `Major indicators` sheet:

| Release | Target | Series | Status | Value |
|---|---|---|---|---:|
| March 2026 | 2025–26 | Value of agricultural exports | forecast | A$80,456.408m |
| June 2026 | 2025–26 | Value of agricultural exports | forecast | A$81,815.978m |
| March 2026 | 2026–27 | Value of agricultural exports | forecast | A$72,844.562m |
| June 2026 | 2026–27 | Value of agricultural exports | forecast | A$74,815.698m |

## 4. Package objective

Provide a stable R interface over related but structurally different ABARES agricultural time-series products without hiding source semantics or pretending their overlapping measures are automatically identical.

The package succeeds when a consumer can:

1. enumerate official releases or snapshots for every admitted product without guessing URLs;
2. download an exact product-specific release bundle reproducibly;
3. parse every published Crop Report national/state table, Agricultural Commodities outlook/statistical table and admitted Farm Productivity table;
4. request the latest release or an exact vintage;
5. identify product, dataset, geography, sector, commodity, concept, period basis, price basis, unit and publication status;
6. trace every value to a file, sheet, release and content hash;
7. compare equivalent observations between releases; and
8. reproduce results offline from cached raw files;
9. retrieve weekly price and fertiliser series only where their official endpoint and redistribution status are recorded; and
10. identify unsupported or rights-restricted series without silently omitting the reason.

## 5. Scope

### 5.1 In scope for version 0.1.0

- Product-aware release discovery from official current and previous-edition pages.
- Crop Report national workbook, state workbook and PDF retrieval.
- Agricultural Commodities outlook workbook, statistical workbook and PDF retrieval.
- Farm Productivity supporting-workbook and methodology-document retrieval.
- Content-type detection from file bytes.
- Immutable raw-asset snapshots and SHA-256 hashes.
- Parsing all Crop Report national table families.
- Parsing the Crop Report Australia and six state history sheets.
- Parsing every Agricultural Commodities outlook sheet published by each supported edition.
- Parsing all 18 Agricultural Commodities statistical table families.
- Parsing all conventional and climate-adjusted Farm Productivity tables by industry, state and region.
- Normalising product, dataset, sector, commodity, geography, market, concept, unit, period basis, status, price basis and currency.
- Retaining source labels, footnotes and notes needed to interpret values.
- Latest-release and exact-release retrieval for each admitted file-backed product.
- A canonical view that resolves known duplicate presentations within a product through an explicit precedence manifest.
- A source-faithful table view that never discards duplicate presentations.
- Historical revision, forecast revision and forecast-error comparison helpers.
- Historical Agricultural Forecast Database retrieval and normalisation.
- Offline fixtures, schema contracts and opt-in live tests.
- Package documentation, vignettes and release notes.

### 5.2 In scope for version 0.2.0 after mandatory gates

- Weekly commodity-price observations from a stable official structured surface, with observation date, page snapshot date, series attribution and redistribution status.
- Fertiliser-grade urea indicator prices and fertiliser import quantities from a proven stable official structured endpoint.
- Append-only snapshots for both feeds so later source corrections remain observable.
- Series-level rights manifests that can exclude restricted observations without disabling the whole product.

Version 0.2.0 work may begin during Phase 0, but it cannot be labelled production-ready until the transport and redistribution gates in sections 18 and 20 pass. If a stable official endpoint or permission cannot be established, retain discovery metadata and an explicit `unsupported_reason`; do not ship a brittle dashboard scraper as a supported API.

### 5.3 Deferred

- Editions available only through the older ABARES historical publications archive when they lack machine-readable workbooks.
- OCR or PDF table extraction.
- Crop modelling, seasonal forecasting or calculated yield series not published by ABARES.
- Farm Data Portal estimates and ABARES Trade Dashboard data. They are less relevant to the present Chartwell use case and already have readers in `read.abares`.
- Water Market Outlook and release-specific forestry or fisheries histories. Fisheries outlook series already enter through the Agricultural Commodities workbooks.
- The ABARES Farmland Price Indicator pending a source and redistribution review of CoreLogic-derived material.
- Farm-level or establishment microdata.
- Chartwell provider code, UI and chart definitions.
- A public CRAN submission before the API has survived at least two new quarterly releases.

### 5.4 Explicit non-goals

- Do not construct asset URLs from a filename convention.
- Do not assume `.xls` or `.xlsx` extensions describe the actual format.
- Do not identify sheets by position alone.
- Do not treat unmarked historical values as final or unrevisable.
- Do not collapse values from different source tables without a documented precedence rule.
- Do not collapse similarly named observations across products without an explicit reviewed concordance.
- Do not infer calendar, financial or marketing-year basis from label shape when the source supplies that context.
- Do not infer nominal/real basis from the unit alone.
- Do not scrape Power BI visual pixels or private undocumented endpoints as the production contract.
- Do not redistribute third-party prices merely because they appear on an ABARES page.
- Do not overwrite an old vintage when a new release arrives.
- Do not silently turn missing, suppressed or non-numeric cells into zero.

## 6. Repository and delivery model

Create `readagau` as a standalone package repository adjacent to the app repository. Use a normal R package layout and a dedicated branch for each implementation phase.

Recommended initial release model:

- package version begins at `0.0.0.9000`;
- Chartwell installs a pinned commit, not a floating default branch;
- tag `v0.1.0` only after all acceptance criteria pass;
- use semantic versioning after `v0.1.0`;
- record the pinned commit in Chartwell's dependency manifest when app integration begins.

Do not place the package's implementation files inside `data_viewer/R`. Only the eventual provider adapter belongs in the app repository.

## 7. Public API

The first stable surface should be deliberately small.

### 7.1 Release discovery

```r
list_agau_releases(
  products = c(
    "crop_report",
    "agricultural_commodities",
    "farm_productivity",
    "weekly_commodity_prices",
    "fertiliser"
  ),
  refresh = FALSE,
  include_archive = TRUE,
  cache_dir = agau_cache_dir()
)
```

Returns one row per product release or dated snapshot with:

- `product`;
- `release_id`;
- `report_number`;
- `release_date`;
- `edition`;
- `landing_url`;
- discovered asset URLs;
- asset availability;
- `discovered_at`; and
- discovery warnings.

`release_id` must be product-qualified and derived from official metadata rather than a download filename. Examples are `acr-2026-06-02-no-218`, `ac-2026-06-02`, `productivity-2026-06` and `weekly-prices-2026-07-23`. Do not assume same-day quarterly products have identical asset completeness.

### 7.2 Bundle retrieval

```r
download_agau_release(
  product,
  release = "latest",
  assets = "all",
  cache_dir = agau_cache_dir(),
  refresh = FALSE,
  verify = TRUE
)
```

Returns an asset manifest. It must:

- resolve `latest` once at the start of the call;
- resolve product-specific assets:
  - `national`, `state` and `report` for Crop Report;
  - `outlook`, `statistics` and `report` for Agricultural Commodities;
  - `supporting_data` and methodology/report assets for Farm Productivity;
  - `page_snapshot` and approved structured assets for weekly prices and fertiliser;
- download through temporary files and atomically promote successful assets;
- retain original URL and server metadata;
- sniff the file signature;
- calculate SHA-256;
- reject HTML error pages returned with spreadsheet filenames;
- preserve an existing valid snapshot unless `refresh = TRUE`; and
- never replace a prior file with different bytes under the same hash path.

### 7.3 Data retrieval

```r
read_crop_report(
  release = "latest",
  assets = c("national", "state"),
  tables = "all",
  geography = NULL,
  crops = NULL,
  measures = NULL,
  view = c("canonical", "reported"),
  cache_dir = agau_cache_dir(),
  refresh = FALSE
)
```

Rules:

- `view = "reported"` returns every parsed source presentation.
- `view = "canonical"` applies a checked-in precedence manifest.
- Filters are applied after structural parsing and before returning the result.
- `tables` accepts stable semantic table IDs, not only worksheet labels.
- The return type is a tibble with a stable schema and class `crop_report_data`.

### 7.4 Agricultural Commodities and ACS

```r
read_agricultural_commodities(
  release = "latest",
  datasets = c("outlook", "statistics"),
  tables = "all",
  sectors = NULL,
  commodities = NULL,
  concepts = NULL,
  view = c("canonical", "reported"),
  cache_dir = agau_cache_dir(),
  refresh = FALSE
)
```

Rules:

- `datasets = "outlook"` returns the release-specific short- or medium-term outlook workbook.
- `datasets = "statistics"` returns the longer Agricultural Commodity Statistics history.
- `tables` accepts stable semantic table IDs, never only worksheet labels.
- Nested row headings must become explicit dimensions rather than an opaque concatenated label.
- `view = "canonical"` may deduplicate equivalent presentations within this product only.
- The return type is a tibble with class `agricultural_commodities_data`.

### 7.5 Farm productivity

```r
read_farm_productivity(
  release = "latest",
  adjustment = c("all", "conventional", "climate_adjusted"),
  industries = NULL,
  geography = NULL,
  view = c("canonical", "reported"),
  cache_dir = agau_cache_dir(),
  refresh = FALSE
)
```

The output must preserve:

- industry and industry aggregation;
- geography type and geography;
- index, input, output and growth concepts as published;
- conventional versus climate-adjusted method;
- methodology regime, including the interim 2022–23 to 2024–25 approach;
- source release and historical revision vintage.

### 7.6 Weekly prices and fertiliser

```r
read_agau_prices(
  product = c("weekly_commodity_prices", "fertiliser"),
  snapshot = "latest",
  series = NULL,
  redistribution = c("permitted", "all_metadata"),
  cache_dir = agau_cache_dir(),
  refresh = FALSE
)
```

This function is experimental until the version 0.2.0 gates pass. `redistribution = "permitted"` returns only series whose rights manifest permits the intended use. `all_metadata` may list restricted or unsupported series and their provenance but must not return values where reuse is not authorised.

Each returned value must distinguish:

- `observation_date`;
- `snapshot_date`;
- `retrieved_at`;
- source cadence;
- original source/provider;
- attribution text or identifier; and
- redistribution status.

### 7.7 Series catalogue

```r
agau_series_catalog(
  product,
  release = "latest",
  datasets = NULL,
  include_unsupported = TRUE,
  cache_dir = agau_cache_dir()
)
```

Returns distinct semantic series, dimensions, available period ranges, source cadence and rights status without returning the full observation payload. This is the intended downstream discovery/search seam.

### 7.8 Historical forecast database

```r
read_agau_forecast_history(
  path = NULL,
  refresh = FALSE,
  cache_dir = agau_cache_dir()
)
```

This is the package-owned equivalent of the useful `read.abares` function. It must retain the official issue and target fields, original forecast and latest actual, while adding source URL, retrieval time and hash.

### 7.9 Vintage comparison

```r
compare_agau_vintages(
  product,
  data = NULL,
  releases = NULL,
  series = NULL,
  comparison = c("all", "history_revision", "forecast_revision", "forecast_error"),
  cache_dir = agau_cache_dir()
)
```

The helper must compare values by semantic observation key, never by row number or spreadsheet coordinate.

### 7.10 Supporting API

The following helpers may be exported if they prove useful in two or more workflows:

```r
agau_cache_dir()
agau_source_catalog()
agau_attribution()
validate_agau_release()
```

Keep low-level workbook parsers internal.

## 8. Data contracts

### 8.1 Release manifest

One row per product release or dated snapshot:

| Field | Meaning |
|---|---|
| `product` | Stable product ID |
| `release_id` | Stable package identifier |
| `report_number` | Official report number when present |
| `release_date` | Official publication date |
| `edition` | Edition label when present |
| `landing_url` | Official release page |
| `asset_roles` | Product-specific discovered asset roles |
| `asset_status` | Complete, partial or invalid |
| `discovered_at` | UTC discovery timestamp |
| `discovery_version` | Package/parser version used |
| `warning` | Any non-fatal source anomaly |

Do not use the filename as the release key.

### 8.2 Raw asset manifest

One row per downloaded asset:

| Field | Meaning |
|---|---|
| `product` | Parent product |
| `release_id` | Parent release |
| `asset_type` | Product-specific role such as `national`, `state`, `outlook`, `statistics`, `supporting_data`, `page_snapshot` or `report` |
| `source_url` | Exact official URL |
| `source_filename` | Server/link filename, even if blank or misleading |
| `detected_format` | `xlsx`, `xls`, `pdf` or unknown |
| `content_type` | HTTP content type |
| `retrieved_at` | UTC retrieval timestamp |
| `etag` / `last_modified` | Server metadata when available |
| `sha256` | Content hash |
| `bytes` | File size |
| `local_path` | Cache location |
| `validation_status` | Valid, warning or rejected |

### 8.3 Observation schema

Every parsed observation must expose:

| Field | Rule |
|---|---|
| `product` | Stable source product ID |
| `release_id` | Exact release vintage |
| `release_date` | Official page date |
| `report_number` | Official report number |
| `dataset` | Product-specific dataset such as `crop_report`, `commodities_outlook`, `commodity_statistics`, `farm_productivity`, `weekly_prices`, `fertiliser` or `historical_forecast_database` |
| `source_asset` | Product-specific asset role |
| `source_sheet` | Actual workbook sheet label |
| `table_id` | Stable semantic ID |
| `table_title` | Published title |
| `record_role` | Canonical or supporting presentation |
| `geography_type` | Country, state, region, market or not applicable |
| `geography` | Normalised published geography |
| `sector` | Agriculture, crops, livestock, fisheries, forestry or a more specific published sector |
| `season` | Winter, summer or not applicable |
| `commodity` | Normalised crop, livestock, product, input or aggregate |
| `concept` | Area, yield, production, productivity, input, output, supply, disposal, price, trade, value or a more specific published concept |
| `market` | World, Australia, export port, domestic market or not applicable |
| `unit` | Normalised unit without losing source unit |
| `period` | Published period label stripped of status marker |
| `period_start` / `period_end` | Parsed bounds where defensible |
| `period_basis` | Calendar year, crop year, financial year, quarter, week, observation date or marketing year |
| `period_status` | Forecast, projection, estimate, historical or published-unclassified |
| `status_source` | Suffix, title, note or unclassified |
| `price_basis` | Nominal, real, index basis or not applicable |
| `currency` | Published currency where relevant |
| `method` | Conventional, climate-adjusted, interim adjustment or not applicable |
| `value` | Numeric observation |
| `raw_value` | Original cell representation |
| `footnote_codes` | Published codes attached to row, column or unit |
| `source_note` | Relevant note or source text |
| `series_id` | Deterministic semantic series key |
| `observation_key` | `series_id` plus target period |
| `retrieved_at` | Asset retrieval time |
| `sha256` | Source asset hash |
| `parser_version` | Package version/parser profile |
| `source_provider` | ABARES or named third-party origin |
| `rights_status` | Permitted, restricted, review-required or not applicable |

The package may add fields, but it must not remove or silently redefine these after `v0.1.0`.

### 8.4 Status rules

Status precedence:

1. an explicit period suffix;
2. an explicit table title such as “forecasts” or “estimates”;
3. an explicit workbook note;
4. otherwise `published-unclassified`.

Required mappings:

- `f` → `forecast`;
- `s` → `estimate`.
- `z` → `projection`.

Do not infer `actual` solely because a period precedes the release date. Use `historical` or `published-unclassified` unless the source establishes finality.

### 8.5 Rights manifest

Maintain a checked-in, versioned manifest for weekly price and fertiliser series:

| Field | Meaning |
|---|---|
| `source_series_id` | Stable source-level identifier |
| `product` | Weekly prices or fertiliser |
| `source_provider` | ABARES or named third party |
| `source_url` | Official attribution or licence URL |
| `licence` | Stated licence where available |
| `attribution` | Required attribution text |
| `redistribution_status` | Permitted, restricted or review-required |
| `approved_use` | Internal research, derived chart, public redistribution or other reviewed scope |
| `reviewed_at` | Date of rights review |
| `review_evidence` | Decision record or source citation |

Unknown status defaults to `review-required`, never `permitted`.

## 9. Source-table catalogue and parser families

Maintain a checked-in semantic catalogue. Worksheet numbers remain provenance, not the durable API.

### 9.1 Crop Report national workbook families

| Semantic family | June 2026 source | Parser responsibility |
|---|---|---|
| National/state crop totals | Tables 1–3 | Winter production, winter area, summer area and production |
| Current state snapshots | Tables 4–10 | Published current forecasts/estimates, area, yield, production and change measures |
| National crop histories | Tables 11–12 | Paired area and production columns by winter/summer crop |
| Recent state production | Tables 13–14 | Major and other crop production by state |
| Supply and disposal | Tables 15–16 | Commodity-specific marketing-year measures and footnotes |
| Prices | Table 17 | Quarterly grain, oilseed and pulse prices |

Table identification must use normalised title patterns and structural fingerprints. A profile may record the expected sheet label for a release range, but sheet number alone cannot select a parser.

### 9.2 State workbook family

Parse Australia and all six state sheets through one state-history parser.

Normalise:

- compact and spaced state names;
- nested crop/measure headers;
- area and production units;
- changing period columns;
- status suffixes;
- empty crop sections; and
- published notes.

### 9.3 Agricultural Commodities outlook families

Use title and structural fingerprints, not a fixed sheet list. The audited editions demonstrate that March medium-term and non-March short-term workbooks differ materially.

| Semantic family | Audited source | Parser responsibility |
|---|---|---|
| Macroeconomic assumptions | `Key macro` / `Key Macro` | Country/group growth, inflation, exchange rate, population and other published assumptions by calendar year |
| Major indicators | `Major indicators` / `Major Indicators` | Production/export values, farm performance and sector aggregates by financial year |
| Crops | Wheat, coarse grains, oilseeds, cotton, sugar, wine and edition-specific horticulture | World/Australian balances, area, yield, production, prices, exports and values |
| Livestock and products | Beef/cattle, lamb/sheep/wool, dairy and edition-specific pig/chicken or combined sheets | Herd/flock, slaughter, production, consumption, trade, prices and values |
| Fisheries, aquaculture and forestry | Dedicated or major-indicator sections depending on edition | Production/export values and sector-specific concepts |

Required behaviours:

- treat March `z` columns as projections, not ordinary forecasts;
- retain published `% change` columns as derived observations with the stated comparison basis;
- preserve hierarchy such as `World → Production → barley` or `Australia → Exports → quantity`;
- use a versioned sheet-alias map for punctuation, case and combined/split commodity sheets;
- never assume the first two columns are sufficient to recover nested headings; and
- retain nominal and real rows as separate series with explicit `price_basis`.

### 9.4 Agricultural Commodity Statistics families

The audited workbooks contain 18 tables:

| Tables | Semantic family |
|---|---|
| 1–2 | Farmers' terms of trade; farm costs and returns |
| 3–4 | Farm production and agricultural export value/volume/price indicators |
| 5–7 | World indicator prices, Australian farm-product unit values, and world production/consumption/stocks/trade |
| 8–11 | Australian commodity production, gross value, crop/forestry area, livestock numbers and yields |
| 12–13 | Agriculture, fisheries and forestry export volume and value |
| 14–18 | Fisheries export/import volumes and values, including selected-country trade |

The parser must retain hierarchical row paths, `na`/suppression tokens, unit changes, current-price versus real/index series, and revisions to the full historical window. The statistical workbook is the package's Agricultural Commodity Statistics surface; do not create a duplicate ingestion path unless ABARES publishes a separate machine-readable ACS file with additional coverage.

### 9.5 Farm Productivity, weekly prices and fertiliser

Farm Productivity must use an explicit workbook catalogue covering:

- conventional TFP;
- climate-adjusted TFP;
- input and output indexes where published;
- industry;
- national, state and regional geography;
- observation financial year; and
- methodology regime.

The parser must treat a release-wide historical replacement as a new vintage, not as an in-place update.

Weekly prices must parse semantic rows rather than table positions. A series key includes the indicator label, market/source, unit and cadence. The row's own observation date is authoritative; the page date is the snapshot vintage.

Fertiliser admission requires a discovered data dictionary or equivalent metadata and a stable structured endpoint. The initial catalogue must distinguish urea prices, import quantities, fertiliser type, origin/market, frequency and unit. If the endpoint cannot be replayed from a saved raw response, it fails admission.

### 9.6 Canonical precedence

Keep every parsed record in `view = "reported"`. For `view = "canonical"`, use a versioned manifest rather than implicit `distinct()` behavior.

Initial Crop Report precedence:

1. state workbook for state-level long histories;
2. Tables 11–12 for national crop-level area and production histories;
3. Tables 1–3 for aggregate winter/summer totals;
4. Tables 4–10 for explicitly published current snapshot measures, especially yield and percentage changes;
5. Tables 13–14 as supporting recent production presentations where equivalent state-workbook observations exist;
6. Tables 15–17 as unique supply/disposal/price concepts.

For Agricultural Commodities, prefer:

1. the outlook workbook for the current release's estimates, forecasts and projections;
2. the statistical workbook for long historical series;
3. the outlook workbook's explicitly historical value only when the statistical workbook lacks the same semantic observation; and
4. separate series when equivalence cannot be established across different period, basis, market or definition metadata.

Do not canonicalise across Crop Report, Agricultural Commodities, Farm Productivity, weekly prices or fertiliser merely because labels match. Cross-product concordances require explicit review and must retain both original series IDs.

If two candidates remain semantically different or cannot be proven equivalent, return both with distinct `series_id` values.

## 10. Parser architecture

Use separate layers:

```text
release discovery
    ↓
asset manifest and download
    ↓
file signature and workbook validation
    ↓
sheet/title or structured-endpoint catalogue
    ↓
table-family parser
    ↓
normalisation, rights filter and semantic keys
    ↓
canonical precedence
    ↓
vintage comparisons
```

Recommended internal modules:

- `release-discovery.R`
- `download.R`
- `cache.R`
- `file-detection.R`
- `workbook-catalog.R`
- `parse-national-totals.R`
- `parse-current-state.R`
- `parse-national-history.R`
- `parse-state-history.R`
- `parse-supply-disposal.R`
- `parse-commodities-outlook.R`
- `parse-commodity-statistics.R`
- `parse-farm-productivity.R`
- `parse-weekly-prices.R`
- `parse-fertiliser.R`
- `parse-historical-forecast.R`
- `rights-manifest.R`
- `normalise.R`
- `canonicalise.R`
- `vintages.R`
- `validation.R`
- `conditions.R`

Parser functions should accept a local path and release metadata. They must not perform network requests.

## 11. File and cache behavior

Use `tools::R_user_dir("readagau", "cache")` by default and allow an explicit `cache_dir`.

Recommended layout:

```text
cache/
  discovery/
    releases.json
  raw/
    <product>/
      <release_id>/
        <sha256>/
          <product-specific-assets>
          asset-manifest.json
  parsed/
    <product>/
      <release_id>/
        <parser-version>/
          observations.rds
          validation.rds
  rights/
    series-rights.json
```

Requirements:

- cache writes are atomic;
- concurrent calls use a lock or safe single-writer protocol;
- cache keys include product, release, asset hash, parser version, output view and rights-manifest version where relevant;
- refreshing discovery does not delete raw assets;
- parsing from a supplied local file works without internet;
- invalid downloads are retained only in a quarantine/debug path, never as valid assets;
- a cache prune helper must require explicit release or age criteria and must never be called automatically.

## 12. Revision and forecast-error model

Use two keys:

- `series_id`: product + dataset + geography + sector + commodity + concept + market + unit + period basis + price basis + method and any other semantic dimensions;
- `observation_key`: `series_id` + target period.

### 12.1 History revision

Compare the same observation key across releases where neither side is a forecast. Return:

- old and new release;
- old and new value;
- absolute and percentage revision where valid;
- old and new status;
- status transition;
- source table and hash on both sides.

### 12.2 Forecast revision

Compare observations that target the same period and were published as forecasts or projections in at least the earlier release.

Also calculate:

- issue-to-target horizon in months or report rounds;
- number of revisions observed; and
- first, previous and latest forecast where requested.

### 12.3 Forecast error

Compare a forecast with the first later observation for the same key explicitly classified as estimate or historical.

Do not default to the latest revised historical value when calculating the first-realisation error. Offer it as a separately named comparison if useful.

### 12.4 Status transitions

Retain transitions such as:

```text
forecast → forecast
forecast → estimate
forecast → projection
projection → projection
projection → forecast
estimate → estimate
estimate → historical
historical → historical revision
```

## 13. Error and warning contract

Create typed conditions so downstream consumers can distinguish failures:

- `agau_release_discovery_error`;
- `agau_asset_missing_error`;
- `agau_download_error`;
- `agau_asset_format_error`;
- `agau_schema_error`;
- `agau_table_parse_error`;
- `agau_endpoint_error`;
- `agau_rights_error`;
- `agau_status_warning`;
- `agau_duplicate_warning`;
- `agau_cadence_warning`;
- `agau_validation_error`.

Each condition should include product, release ID, asset type, sheet/table or series where relevant and a concise remediation hint. Never expose temporary URLs containing secrets; none are currently required.

Fail loudly when:

- a required workbook is absent;
- an asset is HTML or another unexpected type;
- no known table title is found;
- a required header cannot be resolved;
- numeric conversion would discard non-empty unexplained values;
- canonical candidates conflict; or
- a vintage comparison would join on a non-unique key;
- a structured endpoint cannot be replayed from its raw snapshot; or
- a value request includes a series whose rights status is not permitted.

## 14. Dependencies

Keep the runtime package small.

Proposed imports:

- `cli`;
- `digest` for SHA-256;
- `fs`;
- `httr2`;
- `readxl`;
- `rlang`;
- `rvest`;
- `stringr`;
- `tibble`;
- `vctrs`; and
- `xml2`.

Proposed suggests:

- `read.abares`;
- `testthat` (>= 3.0.0);
- `withr`;
- `webfakes`;
- `waldo`;
- `knitr`; and
- `rmarkdown`.

The implementation manager must justify any additional runtime dependency. Do not import `sf`, `stars`, `terra`, database engines or Arrow.

## 15. Test and fixture strategy

### 15.1 Offline default

The default test suite must perform no live network requests.

Use:

- saved HTML fixtures for main, previous-edition and release pages;
- small structurally faithful workbook fixtures for each parser family;
- saved structured-response fixtures for admitted weekly-price and fertiliser endpoints;
- a rights-manifest fixture containing permitted, restricted and review-required cases;
- at least one OOXML fixture carrying a misleading `.xls` name;
- one blank/weak filename discovery fixture;
- one compact state-sheet-name fixture and one spaced-name fixture;
- malformed HTML and malformed workbook fixtures; and
- deterministic expected-output snapshots.

Do not mock the parser under test. Mock or fake transport and feed the real parser real workbook bytes.

### 15.2 Representative full-release matrix

Retain or generate licensed test fixtures representing:

| Release | Why required |
|---|---|
| Crop Report, March 2024 | Earliest current digital-page shape |
| Crop Report, March 2025 | `.xls` link with `.xlsx` bytes and March table layout |
| Crop Report, September 2025 | Weak source filename and non-March layout |
| Crop Report, June 2026 | Latest 17-table/40-column state layout |
| Agricultural Commodities, March 2026 | Five-year outlook, `z` projections and split commodity sheets |
| Agricultural Commodities, June 2026 | Short outlook, percentage-change columns and combined commodity sheets |
| Agricultural Commodity Statistics, March/June 2026 | All 18 long-history table families and full-history revision check |
| Farm Productivity, June 2026 | Conventional/climate-adjusted methods and national/state/region dimensions |
| Weekly prices, 23 July 2026 | Mixed cadence, observation dates, units and third-party rights cases |
| Fertiliser, first admitted snapshot | Stable-endpoint replay, series metadata and rights gate |

If full official workbooks are too large for the package repository, create reduced workbooks that preserve headers, merges, notes, formulas-as-values and failure modes. Keep a separate checksum manifest for opt-in full-release regression tests.

### 15.3 Required test groups

- Release-page discovery.
- Release ordering and `latest` resolution.
- Asset classification by link text and role.
- File-signature detection.
- Atomic cache and hash behavior.
- Every Crop Report national parser family and the state workbook parser.
- Every Agricultural Commodities outlook family.
- All 18 Agricultural Commodity Statistics families.
- Farm Productivity conventional and climate-adjusted families.
- Weekly-price mixed-cadence parsing and rights filtering.
- Fertiliser endpoint replay and admission failure.
- Status and period parsing.
- Unit, geography, market, price-basis and method normalisation.
- Canonical precedence and duplicate detection.
- Historical forecast database compatibility.
- Vintage comparison classifications.
- Typed error conditions.
- Local/offline execution.
- Print methods and API examples.

### 15.4 Golden assertions

At minimum, assert:

- the four-release wheat-production sequence in section 3;
- the March-to-June agricultural-export forecast revisions in section 3;
- `f`, `s` and `z` mappings;
- presence of all 17 June 2026 semantic table IDs;
- presence of all 18 Agricultural Commodity Statistics semantic table IDs;
- Australia plus six state geographies;
- one supply/disposal observation;
- one quarterly price observation;
- one conventional and one climate-adjusted productivity observation;
- one weekly series whose observation date differs from its snapshot date;
- refusal to return a restricted price value through `redistribution = "permitted"`;
- identical results when the March 2025 fixture is named `.xls` or `.xlsx`; and
- unique observation keys within the canonical view.

### 15.5 Live tests

Place live tests behind an explicit environment flag such as `READAGAU_LIVE_TESTS=true`.

Live tests should:

- discover the official latest release for every admitted product;
- download to a temporary cache;
- verify all expected asset roles;
- parse at least one Crop Report national/state series, Agricultural Commodities outlook/statistical series and Farm Productivity series;
- verify weekly-price/fertiliser endpoint and rights manifests without printing restricted values;
- compare one current value with the release page or workbook manually recorded expectation;
- report content hashes; and
- never run on CRAN or in the default Chartwell suite.

## 16. Validation and quality gates

Every release parse must produce a validation report containing:

- product and release/snapshot identity;
- discovered versus expected sheets;
- matched semantic table IDs;
- row counts by table;
- period range by series family;
- non-numeric unexplained cells;
- duplicate canonical observation keys;
- unknown status codes;
- unknown units;
- unknown geography labels;
- unknown markets, price bases or methods;
- unknown or expired rights status;
- unexpected cadence or observation-date lag for weekly sources;
- missing required notes;
- source and parser versions.

Schema drift should be a hard failure where it risks incorrect values. A new column or period may be accepted when the structural fingerprint still resolves unambiguously; a moved or renamed semantic header must not be guessed silently.

## 17. Performance and memory targets

Measure on the manager's standard development machine and report cold and warm results.

Initial targets:

- warm release listing from cache: under 100 ms;
- single cached table parse: under 500 ms;
- complete cached June 2026 Crop Report national/state parse: under 5 seconds;
- complete cached June 2026 Agricultural Commodities outlook/statistics parse: under 5 seconds;
- complete cached Farm Productivity parse: under 3 seconds;
- cached weekly-price/fertiliser snapshot parse: under 1 second each;
- complete parsed-object cache restore: under 500 ms;
- peak RSS delta for one complete release parse: under 200 MB;
- no network request when a valid exact-release raw snapshot is present.

These are package targets, not promises about app search latency. Report at least three runs with min/median/max and peak RSS. If a target is missed, profile before relaxing it.

## 18. Licensing, attribution and terms

ABARES publications are generally released under CC BY 4.0 except third-party content, logos and the Commonwealth Coat of Arms.

The package must:

- include official and series-specific attribution guidance in `agau_attribution()`;
- retain source notes and third-party source labels at table level;
- default unknown weekly-price or fertiliser rights to `review-required`;
- prevent restricted values from being returned through the public-value path;
- version the rights decision alongside each cached snapshot;
- avoid bundling logos or decorative report content;
- document whether official workbook fixtures are redistributed or reduced;
- include the package's own open-source licence separately from data licensing; and
- make clear that package availability does not remove dataset-specific terms.

## 19. Documentation deliverables

Required:

- package README with a latest-release example;
- function reference for every exported function;
- “Source files and vintages” vignette;
- “Crop Report tables” vignette;
- “Agricultural Commodities and ACS tables” vignette;
- “Farm productivity methods and revisions” vignette;
- “Weekly prices, fertiliser and rights gates” vignette;
- “Comparing forecast revisions and errors” vignette;
- cache and offline-use documentation;
- attribution and terms page;
- `NEWS.md`;
- `CODE_OF_CONDUCT.md` and contribution guidance if the repository will be public.

Examples must use a temporary or user cache and must not download data during package checks.

## 20. Implementation phases

### Phase 0 — package and source contract spike

Deliverables:

- package skeleton;
- dependency decision record;
- release-manifest schema;
- observation schema;
- semantic table catalogue;
- decision on full versus reduced fixtures;
- reviewed relationship to `read.abares`;
- audit of every digitally linked Agricultural Commodities edition from March 2024 forward;
- Farm Productivity workbook/sheet audit and methodology-regime map;
- weekly-price attribution matrix;
- fertiliser endpoint/data-dictionary spike; and
- signed decision records for weekly-price and fertiliser transport and redistribution.

Exit criteria:

- the manager approves the public API and schemas;
- no unresolved choice can invalidate parser work;
- one March 2025 Crop Report file is successfully detected and opened despite its extension;
- every proposed weekly price has a source provider and rights status; and
- fertiliser is classified as admitted or experimental-with-explicit-blocker, never assumed supported.

### Phase 1 — discovery, download and immutable cache

Deliverables:

- official page parsers;
- release listing;
- exact-release resolution;
- asset-role classification;
- atomic downloads, hashes and cache;
- typed transport errors;
- offline HTML fixtures.

Exit criteria:

- all 10 audited Crop Report releases and all audited Agricultural Commodities releases are enumerated correctly from fixtures;
- Farm Productivity releases are discoverable without constructing asset filenames;
- `latest` resolves deterministically;
- a repeated download is idempotent;
- HTML masquerading as Excel is rejected.

### Phase 2 — Crop Report parsers

Deliverables:

- workbook catalogue;
- six parser families from section 9.1;
- Australia/state history parser;
- status, unit, period and crop normalisers;
- source-faithful `reported` view;
- offline parser fixtures and golden assertions.

Exit criteria:

- all 17 June 2026 tables parse;
- all seven geography sheets parse across representative releases;
- March and non-March structural variants pass;
- no unexplained non-empty cells are silently discarded.

### Phase 3 — Agricultural Commodities and ACS

Deliverables:

- outlook workbook catalogue and parser families;
- all 18 statistical-table parsers;
- nested heading, market, period-basis, price-basis and status normalisers;
- March medium-term and non-March short-term profiles;
- source-faithful and canonical product views;
- offline fixtures and golden assertions.

Exit criteria:

- all audited outlook sheets and all 18 statistical tables parse;
- `s`, `f` and `z` statuses are correct;
- March split sheets and June combined sheets produce stable semantic series;
- the agricultural-export revisions in section 3 are reproduced;
- canonical observation keys are unique;
- reported view still exposes supporting duplicate presentations.

### Phase 4 — Farm Productivity and cross-release vintages

Deliverables:

- Farm Productivity workbook parser and method-regime metadata;
- Historical Agricultural Forecast Database reader;
- revision comparison engine;
- forecast-error logic;
- status-transition outputs;
- required revision vignette.

Exit criteria:

- conventional and climate-adjusted productivity series parse by industry and geography;
- a changed historical productivity value is reported as a revision;
- the section 3 wheat sequence is reproduced;
- first-realisation and latest-revised comparisons are distinguished;
- joins fail on ambiguous keys.

### Phase 5 — weekly prices and fertiliser admission

Deliverables:

- weekly-price structured parser and dated page snapshots;
- source-provider and rights manifest;
- mixed-cadence handling;
- fertiliser structured-endpoint client and fixtures if admitted;
- explicit unsupported result if the fertiliser endpoint or rights gate fails;
- append-only snapshot and correction-comparison tests.

Exit criteria:

- every returned value has observation date, snapshot date, source provider and permitted rights status;
- restricted values are visible as catalogue metadata but unavailable through the public-value path;
- no supported parser relies on chart pixels or an unversioned private endpoint;
- repeated fetches of unchanged content are idempotent; and
- a changed past value is retained as a new snapshot revision.

### Phase 6 — hardening and release candidates

Deliverables:

- validation reports;
- live opt-in test;
- performance and memory measurements;
- complete documentation;
- reverse-dependency/API review for Chartwell;
- `v0.1.0` release candidate for Crop Report, Agricultural Commodities/ACS and Farm Productivity; and
- `v0.2.0` release candidate for weekly prices/fertiliser only if Phase 5 gates pass.

Exit criteria:

- `R CMD check --as-cran` passes with no errors or warnings and only justified notes;
- offline tests pass from a clean R session;
- a separate reviewer reproduces tests and benchmarks;
- all definition-of-done items pass.

## 21. Manager execution and review model

Use small reviewable pull requests:

1. skeleton, contracts, source audit and rights decisions;
2. download/cache layer;
3. Crop Report parsers and canonicalisation;
4. Agricultural Commodities and ACS parsers;
5. Farm Productivity, vintage comparison and Historical Forecast Database;
6. weekly prices, fertiliser and rights enforcement;
7. documentation, benchmarks and release candidates.

Assign a reviewer who did not implement the parser. The reviewer must inspect workbook-to-output mappings directly and challenge silent assumptions.

For each pull request require:

- exact commands run;
- pasted test output;
- fixture list;
- changed public API;
- known limitations;
- evidence that no unrelated app files changed.

Do not begin Chartwell integration until the relevant product has passed Phase 6. Failure of the fertiliser gate must not block integration of the `v0.1.0` file-backed products.

## 22. Definition of done

`readagau` is complete for `v0.1.0` only when:

- all 10 audited Crop Report digital releases and all supported Agricultural Commodities releases are discoverable;
- every supported Crop Report, Agricultural Commodities, ACS and Farm Productivity table family parses;
- misleading extensions and weak filenames are handled;
- exact raw assets are cached with hashes;
- all values carry release, source and parser provenance;
- period and status semantics are explicit;
- period basis, price basis, market and productivity method are explicit;
- canonical and reported views are both available;
- historical revisions, forecast revisions and forecast errors are distinct;
- the Historical Agricultural Forecast Database is supported;
- offline fixtures cover every parser path;
- live tests are opt-in;
- package checks pass;
- performance and RSS measurements are recorded;
- licence and attribution behavior is documented;
- a separate reviewer reproduces the evidence; and
- Chartwell can install a pinned commit and query `release = "latest"` without package-internal knowledge.

`readagau` is complete for `v0.2.0` only when:

- every admitted weekly-price/fertiliser series has a stable structured endpoint and versioned metadata;
- observation date and snapshot date are separate;
- snapshots are append-only and revisions are comparable;
- each series has a current rights decision and attribution;
- restricted and review-required values cannot leak through the permitted public-value path;
- offline fixtures cover endpoint and rights failures; and
- all `v0.1.0` guarantees remain intact.

## 23. Required handoff evidence

The implementation manager must return:

- repository URL and pinned commit;
- package version;
- public API listing;
- exact `R CMD check` and test commands with output;
- fixture coverage matrix;
- parsed row counts by release and table family;
- golden-value comparison report;
- cold/warm performance table with at least three repetitions;
- peak RSS delta;
- live source hashes used for final validation;
- licence/attribution decision and complete weekly/fertiliser rights manifest;
- endpoint replay evidence and admission decision for weekly prices and fertiliser;
- explicit list of restricted, review-required or unsupported series;
- unresolved limitations; and
- recommendation on whether and when to submit the feature upstream to `read.abares`.

An implementation summary without this evidence is not an accepted handoff.
