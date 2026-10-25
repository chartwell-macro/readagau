agau_schema <- function(fields, types, required = rep(TRUE, length(fields))) {
  stopifnot(length(fields) == length(types), length(types) == length(required))
  data.frame(
    field = fields,
    type = types,
    required = required,
    stringsAsFactors = FALSE
  )
}

#' Describe the release-manifest schema
#'
#' A release manifest identifies one audited publication and the roles that can
#' be resolved from its landing page.  The returned contract is deliberately
#' data rather than an S3 class, so it can be inspected before constructing or
#' validating a manifest.
#'
#' @return A 13-row, 3-column base `data.frame` with columns `field` (the
#'   exact manifest column name), `type` (the package's storage contract), and
#'   `required` (logical).  The fields, in order, are `product`, `release_id`,
#'   `release_date`, `edition`, `landing_url`, `asset_roles`, `asset_status`,
#'   `support_status`, `unsupported_reason`, `discovered_at`,
#'   `discovery_version`, `warning`, and `report_number`.  `asset_roles` is a
#'   list-column of character vectors and `discovered_at` is UTC `POSIXct`;
#'   `release_date` is `Date`.  `unsupported_reason` and `report_number` are
#'   optional; all other fields are required.
#' @seealso [agau_raw_asset_manifest_schema()],
#'   [agau_observation_schema()], [list_agau_releases()]
#' @family catalogue and schema helpers
#' @examples
#' schema <- agau_release_manifest_schema()
#' stopifnot(nrow(schema) == 13L, identical(names(schema),
#'   c("field", "type", "required")))
#' schema[schema$field %in% c("release_date", "asset_roles"), ]
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

#' Describe the raw-asset manifest schema
#'
#' A raw-asset manifest records the immutable bytes selected for one release,
#' including their source URL, detected format, retrieval metadata, checksum,
#' and validation decision.
#'
#' @return A 15-row, 3-column base `data.frame` with columns `field`, `type`,
#'   and logical `required`.  Fields, in order, are `product`, `release_id`,
#'   `asset_type`, `source_url`, `source_filename`, `detected_format`,
#'   `content_type`, `retrieved_at`, `etag`, `last_modified`, `sha256`,
#'   `bytes`, `local_path`, `validation_status`, and `unsupported_reason`.
#'   `retrieved_at` is UTC `POSIXct`; `bytes` is the package's integer64
#'   contract; `etag`, `last_modified`, and `unsupported_reason` are optional.
#'   The schema describes metadata and does not read or download an asset.
#' @seealso [agau_release_manifest_schema()],
#'   [agau_observation_schema()], [download_agau_release()]
#' @family catalogue and schema helpers
#' @examples
#' schema <- agau_raw_asset_manifest_schema()
#' stopifnot(nrow(schema) == 15L, all(schema$type != ""))
#' schema[!schema$required, , drop = FALSE]
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

#' Describe the normalised observation schema
#'
#' The observation contract is shared by every public reader.  It separates
#' source identity and provenance from semantic dimensions and typed values,
#' allowing source-faithful and canonical views to be compared without losing
#' the originating workbook/table information.
#'
#' @return A 43-row, 3-column base `data.frame` with columns `field`, `type`,
#'   and logical `required`.  The `field` column is, in order: `product`,
#'   `release_id`, `release_date`, `dataset`, `source_dataset`, `source_asset`,
#'   `source_sheet`, `table_id`, `table_title`, `record_role`,
#'   `geography_type`, `geography`, `commodity`, `concept`, `period`,
#'   `period_start`, `period_end`, `period_basis`, `period_status`,
#'   `status_source`, `price_basis`, `currency`, `unit`, `value`, `raw_value`,
#'   `missing_reason`, `footnote_codes`, `source_note`, `series_id`,
#'   `observation_key`, `retrieved_at`, `sha256`, `parser_version`,
#'   `report_number`, `sector`, `season`, `market`, `method`, `source_provider`,
#'   `rights_status`, `observation_date`, `snapshot_date`, and
#'   `source_cadence`.  `Date` fields are `release_date`, `period_start`,
#'   `period_end`, `observation_date`, and `snapshot_date`; `retrieved_at` is
#'   UTC `POSIXct`; `value` is numeric; and `footnote_codes` is a list-column of
#'   character vectors.  The remaining fields are character.  A `TRUE` value
#'   in `required` means a parsed observation must carry that field, including
#'   explicit `NA` values where the source publishes a missing observation.
#' @seealso [validate_agau_release()], [agau_release_manifest_schema()],
#'   [agau_raw_asset_manifest_schema()]
#' @family catalogue and schema helpers
#' @examples
#' schema <- agau_observation_schema()
#' stopifnot(nrow(schema) == 43L, identical(names(schema),
#'   c("field", "type", "required")))
#' schema[schema$field %in% c("value", "footnote_codes", "retrieved_at"), ]
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
