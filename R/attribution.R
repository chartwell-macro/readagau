#' ABARES attribution guidance
#'
#' @return A named list separating source-data and package-code terms.
#' @export
agau_attribution <- function() {
  list(
    source = "Australian Bureau of Agricultural and Resource Economics and Sciences (ABARES).",
    source_licence = "CC BY 4.0, subject to source-stated exclusions.",
    exclusions = c(
      "Commonwealth Coat of Arms",
      "trade marks",
      "third-party material"
    ),
    weekly_prices = paste(
      "Weekly commodity prices retain the exact ABARES snapshot, upstream",
      "provider, published unit and accessible chart provenance."
    ),
    fixture_policy = "Reduced official excerpts and structurally faithful fixtures.",
    package_code_licence = "MIT"
  )
}

#' Crop Report attribution guidance
#'
#' @return The package-wide ABARES attribution guidance.
#' @export
crop_report_attribution <- function() {
  agau_attribution()
}
