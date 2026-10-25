#' Validate a parsed ABARES release
#'
#' @param data Parsed observation data.
#' @return A structured validation report.
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

#' @export
print.agau_data <- function(x, ...) {
  cat("<", class(x)[1], "> ", nrow(x), " observations, ",
    length(unique(x$table_id)), " tables\n", sep = ""
  )
  NextMethod()
}
