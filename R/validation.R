#' Validate a parsed ABARES release
#'
#' Check a parsed observation table against the shared readagau observation
#' contract and source-specific semantic invariants.  Validation is deliberately
#' diagnostic: a structurally complete table can receive `valid = FALSE` with
#' the offending counts and labels retained in the report for review.
#'
#' @param data A data frame or tibble returned by a readagau reader, with the
#'   columns described by [agau_observation_schema()].  The input is inspected
#'   but not modified.
#' @return An object of class `agau_validation_report` (also a `list`) with 23
#'   named elements: `product`, `release_id`, `source_sheets`, and
#'   `matched_table_ids` (character vectors); `row_counts` and `period_ranges`
#'   (data frames); integer counts `non_numeric_unexplained`,
#'   `missing_required_notes`, `duplicate_observation_keys`,
#'   `duplicate_canonical_observation_keys`, `cadence_or_observation_lag`, and
#'   `invalid_sha256`; named integer `missing_semantic_fields`; character
#'   vectors `unknown_status_codes`, `unknown_units`,
#'   `unknown_geography_labels`, `unknown_markets`, `unknown_price_basis`,
#'   `unknown_methods`, and `unknown_rights_status`; character vectors
#'   `parser_version` and `source_versions`; and logical scalar `valid`.
#'   `row_counts` has the `table()` columns `Var1` and `Freq`; `period_ranges`
#'   contains one row per dataset with the aggregate columns `dataset` and
#'   `x`.  `valid` is `TRUE` only when required fields, semantic labels, hashes,
#'   notes, cadence, and canonical-key checks pass.  Duplicate source keys are
#'   reported separately and are not, by themselves, a validity failure.
#' @details A missing observation column raises `agau_schema_error`.  The
#'   function does not warn, download, write to the cache, or contact a source.
#' @seealso [print.agau_validation_report()], [agau_observation_schema()],
#'   [agau_missing_reason()]
#' @family validation helpers
#' @examples
#' path <- system.file(
#'   "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
#' )
#' observations <- read_crop_report(
#'   path, assets = "national", view = "reported", cache_dir = tempdir(),
#'   release_id = "example", release_date = as.Date("2025-03-04")
#' )
#' report <- validate_agau_release(observations)
#' stopifnot(inherits(report, "agau_validation_report"), is.logical(report$valid))
#' print(report)
#' @export
validate_agau_release <- function(data) {
  required <- agau_observation_schema()$field
  missing_fields <- setdiff(required, names(data))
  if (length(missing_fields)) {
    agau_abort("agau_schema_error",
      paste("Observation fields missing:", paste(missing_fields, collapse = ", ")),
      remediation = "Parse with the current readagau version."
    )
  }
  duplicate_keys <- sum(duplicated(paste(data$release_id, data$observation_key, sep = "::")))
  canonical <- data$record_role == "canonical"
  duplicate_canonical <- sum(duplicated(
    paste(data$release_id[canonical], data$observation_key[canonical], sep = "::")
  ))
  unknown_status <- setdiff(unique(data$period_status), c(
    "historical", "estimate", "forecast", "projection", "published-unclassified"
  ))
  unknown_geo <- unique(data$geography[is.na(data$geography) | !nzchar(data$geography)])
  unknown_units <- unique(data$unit[is.na(data$unit) | !nzchar(data$unit)])
  allowed_price_basis <- c(
    "nominal", "real", "unit_value", "spot", "contract", "benchmark",
    "index_basis", "not_applicable"
  )
  unknown_price_basis <- setdiff(unique(data$price_basis), allowed_price_basis)
  missing_markets <- unique(data$market[is.na(data$market) | !nzchar(data$market)])
  allowed_methods <- c(
    "conventional", "climate_adjusted", "interim_adjustment", "not_applicable"
  )
  unknown_methods <- setdiff(unique(data$method), allowed_methods)
  allowed_rights <- c("permitted", "restricted", "review-required", "not_applicable")
  unknown_rights <- setdiff(unique(data$rights_status), allowed_rights)
  required_semantic <- c(
    "product", "release_id", "dataset", "source_dataset", "source_asset",
    "source_sheet", "table_id", "table_title", "geography_type", "geography",
    "commodity", "concept", "period", "period_basis", "period_status", "unit",
    "series_id", "observation_key", "parser_version"
  )
  missing_semantic <- vapply(required_semantic, function(nm) {
    sum(is.na(data[[nm]]) | !nzchar(as.character(data[[nm]])))
  }, integer(1))
  missing_semantic <- missing_semantic[missing_semantic > 0L]
  weekly <- data$product == "weekly_commodity_prices"
  cadence_lag <- if (any(weekly)) sum(
    is.na(data$observation_date[weekly]) | is.na(data$snapshot_date[weekly]) |
      data$observation_date[weekly] > data$snapshot_date[weekly]
  ) else 0L
  invalid_hash <- sum(!grepl("^[a-f0-9]{64}$", data$sha256))
  unexplained <- sum(data$missing_reason == "parse_failure", na.rm = TRUE)
  missing_notes <- sum(is.na(data$source_note) | !nzchar(data$source_note))
  report <- list(
    product = unique(data$product),
    release_id = unique(data$release_id),
    source_sheets = sort(unique(data$source_sheet)),
    matched_table_ids = sort(unique(data$table_id)),
    row_counts = as.data.frame(table(data$table_id), stringsAsFactors = FALSE),
    period_ranges = stats::aggregate(
      data$period, list(dataset = data$dataset),
      function(x) paste(range(x, na.rm = TRUE), collapse = " to ")
    ),
    non_numeric_unexplained = unexplained,
    missing_required_notes = missing_notes,
    duplicate_observation_keys = duplicate_keys,
    duplicate_canonical_observation_keys = duplicate_canonical,
    missing_semantic_fields = missing_semantic,
    unknown_status_codes = unknown_status,
    unknown_units = unknown_units,
    unknown_geography_labels = unknown_geo,
    unknown_markets = missing_markets,
    unknown_price_basis = unknown_price_basis,
    unknown_methods = unknown_methods,
    unknown_rights_status = unknown_rights,
    cadence_or_observation_lag = cadence_lag,
    invalid_sha256 = invalid_hash,
    parser_version = unique(data$parser_version),
    source_versions = unique(data$sha256),
    valid = !length(missing_fields) && unexplained == 0L && missing_notes == 0L &&
      duplicate_canonical == 0L && !length(missing_semantic) &&
      !length(unknown_status) && !length(unknown_units) &&
      !length(unknown_geo) && !length(missing_markets) &&
      !length(unknown_price_basis) && !length(unknown_methods) &&
      !length(unknown_rights) && cadence_lag == 0L && invalid_hash == 0L
  )
  class(report) <- c("agau_validation_report", "list")
  report
}

#' Print an agau validation report
#'
#' @param x An object of class `agau_validation_report`, normally returned by
#'   [validate_agau_release()].
#' @param ... Additional arguments accepted for S3 consistency and ignored.
#' @return `x`, invisibly.  The method writes a compact human-readable summary
#'   to the console and does not modify the report.
#' @seealso [validate_agau_release()]
#' @family validation helpers
#' @examples
#' report <- structure(list(
#'   product = "crop_report", release_id = "example",
#'   matched_table_ids = "demo_table", duplicate_observation_keys = 0L,
#'   duplicate_canonical_observation_keys = 0L, valid = TRUE
#' ), class = c("agau_validation_report", "list"))
#' print(report)
#' @method print agau_validation_report
#' @export
print.agau_validation_report <- function(x, ...) {
  cat("<agau_validation_report>\n")
  cat("  product:", paste(x$product, collapse = ", "), "\n")
  cat("  release:", paste(x$release_id, collapse = ", "), "\n")
  cat("  tables:", length(x$matched_table_ids), "\n")
  cat("  duplicate keys:", x$duplicate_observation_keys, "\n")
  cat("  duplicate canonical keys:", x$duplicate_canonical_observation_keys, "\n")
  cat("  valid:", x$valid, "\n")
  invisible(x)
}

#' Print a readagau observation table
#'
#' @param x A data frame or tibble with class `agau_data` (or a subclass) and a
#'   `table_id` column.  Reader results such as `crop_report_data` and
#'   `weekly_prices_data` satisfy this contract.
#' @param ... Additional arguments passed to the next `print()` method.
#' @return `x`, invisibly, after printing the observation count and number of
#'   distinct tables.  The underlying data are not changed.
#' @seealso [agau_observation_schema()], [validate_agau_release()]
#' @family validation helpers
#' @examples
#' observations <- data.frame(
#'   table_id = c("demo_table", "demo_table", "second_table"),
#'   value = c(1, 2, 3), stringsAsFactors = FALSE
#' )
#' class(observations) <- c("agau_data", "data.frame")
#' print(observations)
#' @method print agau_data
#' @export
print.agau_data <- function(x, ...) {
  cat("<", class(x)[1], "> ", nrow(x), " observations, ",
    length(unique(x$table_id)), " tables\n", sep = ""
  )
  NextMethod()
}
