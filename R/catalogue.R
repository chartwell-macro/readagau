#' Read the ABARES semantic source catalogue
#'
#' The catalogue is the package's checked-in description of supported source
#' families.  It is metadata, not a live request: the function reads the
#' installed `inst/catalogue/source-catalog.csv` file and therefore works
#' offline.  Rows describe the product and dataset context, the source asset
#' role and label, the stable table identifier, the semantic and parser
#' families, and the admission decision used by the readers.
#'
#' @return A base `data.frame` with character columns named `product`,
#'   `dataset`, `source_asset`, `source_label`, `table_id`, `semantic_family`,
#'   `parser_family`, `admission_status`, and `unsupported_reason`.  Empty
#'   `unsupported_reason` values are represented as `NA_character_`; row order
#'   follows the checked-in catalogue and is stable for a given package
#'   version.
#' @details If the installed catalogue is missing, the function raises an
#'   `agau_validation_error` with remediation rather than silently returning an
#'   incomplete catalogue.  No network access or cache write occurs.
#' @seealso [agau_series_catalog()], [list_agau_releases()]
#' @family catalogue and schema helpers
#' @examples
#' catalogue <- agau_source_catalog()
#' stopifnot(is.data.frame(catalogue), all(c(
#'   "product", "dataset", "table_id", "admission_status"
#' ) %in% names(catalogue)))
#' utils::head(catalogue[c("product", "table_id", "admission_status")])
#' @export
agau_source_catalog <- function() {
  path <- system.file("catalogue", "source-catalog.csv", package = "readagau")
  if (!nzchar(path)) {
    agau_abort(
      "agau_validation_error",
      "Installed source catalogue is missing.",
      remediation = "Reinstall readagau from a complete source tree."
    )
  }
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
}
