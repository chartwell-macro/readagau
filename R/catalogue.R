#' ABARES semantic source catalogue
#'
#' @return The checked-in source-family catalogue including admission gates.
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
