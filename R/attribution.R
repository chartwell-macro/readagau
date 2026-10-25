#' ABARES attribution and licensing guidance
#'
#' Return the package's attribution guidance for source data, provenance,
#' fixtures, and package-authored code. Licensing terms are source-specific:
#' this helper does not make a package-wide CC BY or redistribution claim.
#'
#' @return A named list of class `list` with exactly six elements, in this order:
#'   `source` (one-character source authority), `source_licence` (one-character
#'   source-terms caveat), `exclusions` (a three-element character vector of
#'   excluded material), `weekly_prices` (one-character weekly provenance and
#'   rights caveat), `fixture_policy` (one-character committed-fixture policy),
#'   and `package_code_licence` (one-character package-code licence, ownership,
#'   and upstream-rights caveat).
#'   The list has no additional attributes.
#' @examples
#' guidance <- agau_attribution()
#' stopifnot(
#'   identical(
#'     names(guidance),
#'     c("source", "source_licence", "exclusions", "weekly_prices",
#'       "fixture_policy", "package_code_licence")
#'   ),
#'   grepl("no package-wide", guidance$source_licence, fixed = TRUE)
#' )
#' @seealso [crop_report_attribution()]
#' @family attribution
#' @export
agau_attribution <- function() {
  list(
    source = "Australian Bureau of Agricultural and Resource Economics and Sciences (ABARES).",
    source_licence = paste(
      "Source-specific terms apply: some ABARES publications state CC BY 4.0,",
      "subject to source-stated exclusions; this package makes no package-wide",
      "CC BY or source-data redistribution claim."
    ),
    exclusions = c(
      "Commonwealth Coat of Arms",
      "trade marks",
      "third-party material"
    ),
    weekly_prices = paste(
      "Weekly commodity-price results retain the ABARES snapshot date, upstream",
      "provider, published unit and accessible chart provenance; no redistribution",
      "permission is asserted for those values."
    ),
    fixture_policy = paste(
      "Committed fixtures are package-owned reduced/derived synthetic structures;",
      "they contain no official source bytes, logos, or third-party values."
    ),
    package_code_licence = paste(
      "Package code and package-owned synthetic fixtures: MIT, copyright Chartwell Macro;",
      "this does not license source data or third-party material."
    )
  )
}

#' Crop Report attribution and licensing guidance
#'
#' Return the same six-element attribution guidance as [agau_attribution()] for
#' workflows using the Crop Report family. Source-specific terms still apply;
#' this helper does not grant source-data redistribution permission.
#'
#' @return A named list of class `list` with the same six names, order, element
#' types, and names attribute as [agau_attribution()].
#' @examples
#' guidance <- crop_report_attribution()
#' stopifnot(identical(guidance, agau_attribution()))
#' @seealso [agau_attribution()]
#' @family attribution
#' @export
crop_report_attribution <- function() {
  agau_attribution()
}
