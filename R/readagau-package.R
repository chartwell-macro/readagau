#' readagau: reproducible Australian agricultural data
#'
#' `readagau` discovers, caches, parses, and compares versioned Australian
#' agricultural data releases published by the Australian Bureau of
#' Agricultural and Resource Economics and Sciences (ABARES).  Public readers
#' return tidy observation tables while retaining release, table, provider,
#' checksum, and source-file provenance.
#'
#' @section Supported workflows:
#' The package supports Australian Crop Report workbooks,
#' Agricultural Commodities outlook and statistics workbooks, weekly commodity
#' price releases, Australian Farm Productivity supporting workbooks, and the
#' Historical Agricultural Forecast Database.  [list_agau_releases()] exposes
#' the audited release catalogue; readers accept exact release identifiers or
#' local source files for deterministic offline replay.
#'
#' @section Reproducibility and caching:
#' Raw assets are stored immutably below [agau_cache_dir()] and parsed results
#' are keyed by source checksum and parser version.  Source-faithful results
#' retain upstream table identity and values; canonical views apply the
#' package's documented deduplication and identity rules.  Missing source cells
#' remain typed `NA` values with an explicit `missing_reason` where available.
#'
#' @section Data contract:
#' Every reader uses the columns described by [agau_observation_schema()].
#' Use [validate_agau_release()] to inspect required fields, semantic labels,
#' checksums, duplicate canonical keys, notes, and cadence before publishing a
#' derived result.  [agau_source_catalog()] and the schema helpers expose the
#' machine-readable source and manifest contracts.
#'
#' @section Network and credentials:
#' Exact local paths and already-populated cache entries can be used without
#' network access.  Discovery and downloads contact the official source only
#' when a requested release is not available locally; the package does not
#' require credentials.  User code should pass a temporary or managed
#' `cache_dir` when isolation is required.
#'
#' @section Further documentation:
#' See the package vignettes for getting started, source-file and vintage
#' workflows, product-specific parsing, weekly prices, and revision/error
#' comparisons. Package code and package-owned synthetic fixtures are licensed
#' under MIT, copyright Chartwell Macro. Source data and provider material remain subject
#' to their upstream terms and attribution requirements.
#'
#' @author Chartwell Macro
"_PACKAGE"
