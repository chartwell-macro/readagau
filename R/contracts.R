agau_schema <- function(fields, types, required = rep(TRUE, length(fields))) {
  stopifnot(length(fields) == length(types), length(types) == length(required))
  data.frame(
    field = fields,
    type = types,
    required = required,
    stringsAsFactors = FALSE
  )
}

#' Release manifest schema
#'
#' @return A data frame describing the frozen release-manifest fields.
#' @export
agau_release_manifest_schema <- function() {
  agau_schema(
    c(
      "product", "release_id", "release_date", "edition", "landing_url",
      "asset_roles", "asset_status", "support_status", "unsupported_reason",
      "discovered_at", "discovery_version", "warning", "report_number"
    ),
    c(
      "character", "character", "Date", "character", "character",
      "list<character>", "character", "character", "character",
      "POSIXct<UTC>", "character", "character", "character"
    ),
    c(rep(TRUE, 8), FALSE, rep(TRUE, 3), FALSE)
  )
}

#' Raw asset manifest schema
#'
#' @return A data frame describing the frozen raw-asset-manifest fields.
#' @export
agau_raw_asset_manifest_schema <- function() {
  agau_schema(
    c(
      "product", "release_id", "asset_type", "source_url",
      "source_filename", "detected_format", "content_type", "retrieved_at",
      "etag", "last_modified", "sha256", "bytes", "local_path",
      "validation_status", "unsupported_reason"
    ),
    c(
      "character", "character", "character", "character", "character",
      "character", "character", "POSIXct<UTC>", "character", "character",
      "character", "integer64", "character", "character", "character"
    ),
    c(rep(TRUE, 8), FALSE, FALSE, rep(TRUE, 4), FALSE)
  )
}

#' Observation schema
#'
#' @return A data frame describing the shared core plus readagau extensions.
#' @export
agau_observation_schema <- function() {
  agau_schema(
    c(
      "product", "release_id", "release_date", "dataset", "source_dataset",
      "source_asset", "source_sheet", "table_id", "table_title", "record_role",
      "geography_type", "geography", "commodity", "concept", "period",
      "period_start", "period_end", "period_basis", "period_status",
      "status_source", "price_basis", "currency", "unit", "value", "raw_value",
      "missing_reason", "footnote_codes", "source_note", "series_id",
      "observation_key", "retrieved_at", "sha256", "parser_version",
      "report_number", "sector", "season", "market", "method",
      "source_provider", "rights_status", "observation_date", "snapshot_date",
      "source_cadence"
    ),
    c(
      "character", "character", "Date", "character", "character",
      "character", "character", "character", "character", "character",
      "character", "character", "character", "character", "character",
      "Date", "Date", "character", "character", "character", "character",
      "character", "character", "double", "character", "character",
      "list<character>", "character", "character", "character",
      "POSIXct<UTC>", "character", "character", "character", "character",
      "character", "character", "character", "character", "character", "Date",
      "Date", "character"
    )
  )
}

agau_cache_contract <- function() {
  list(
    raw_path = "raw/<product>/<release_id>/<sha256>/<asset>",
    immutable_raw = TRUE,
    atomic_promotion = TRUE,
    discovery_refresh_deletes_raw = FALSE,
    parsed_key = c(
      "product", "release_id", "sha256", "parser_version", "view",
      "rights_manifest_version"
    ),
    automatic_pruning = FALSE
  )
}
