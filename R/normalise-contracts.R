#' Normalise ABARES period-status suffixes
#'
#' Published ABARES period labels may end in `s`, `f`, or `z` to identify an
#' estimate, forecast, or projection.  This helper strips that suffix while
#' retaining the original period meaning in separate contract columns.
#'
#' @param x A character-like vector of published period labels.  Whitespace is
#'   trimmed; input order and length are retained.
#' @return A base `data.frame` with one row per element of `x` and character
#'   columns `period`, `period_status`, and `status_source`.  `period` is the
#'   trimmed label without a terminal status suffix.  `period_status` is one of
#'   `"estimate"`, `"forecast"`, `"projection"`, or
#'   `"published-unclassified"`; `status_source` is `"suffix"` when a suffix
#'   was consumed and `"unclassified"` otherwise.  Missing labels remain
#'   missing in `period` and are treated as unclassified.  No network, cache,
#'   or file-system side effect occurs.
#' @seealso [agau_missing_reason()], [read_crop_report()]
#' @family normalisation helpers
#' @examples
#' status <- agau_status(c("2024", "2025s", "2026f", "2027z"))
#' stopifnot(identical(status$period_status, c(
#'   "published-unclassified", "estimate", "forecast", "projection"
#' )))
#' status
#' @export
agau_status <- function(x) {
  x <- as.character(x)
  trimmed <- trimws(x)
  suffix <- tolower(sub(".*?([sfz])\\s*$", "\\1", trimmed, perl = TRUE))
  has_suffix <- grepl("[sfz]\\s*$", trimmed, ignore.case = TRUE)
  status <- rep("published-unclassified", length(trimmed))
  status[has_suffix & suffix == "s"] <- "estimate"
  status[has_suffix & suffix == "f"] <- "forecast"
  status[has_suffix & suffix == "z"] <- "projection"
  period <- trimmed
  period[has_suffix] <- trimws(sub("[sfz]\\s*$", "", period[has_suffix],
    ignore.case = TRUE
  ))
  data.frame(
    period = period,
    period_status = status,
    status_source = ifelse(has_suffix, "suffix", "unclassified"),
    stringsAsFactors = FALSE
  )
}

#' Classify ABARES missing-value markers
#'
#' Convert the published tokens used for unavailable or suppressed values into
#' the package's controlled `missing_reason` vocabulary.  Numeric-looking
#' values are treated as present observations and therefore return `NA`.
#'
#' @param x A character-like vector of original cell values.  Empty strings and
#'   `NA` values are treated as blank source cells.
#' @return A character vector with the same length as `x`.  Element names are
#'   not part of the contract.  Elements
#'   are `NA` for numeric values and otherwise one of `"blank"`,
#'   `"provider_na"`, `"not_applicable"`, `"unavailable"`,
#'   `"confidential"`, or `"suppressed"`.  Recognised markers include `NA`,
#'   `N/A`, `not applicable`, `not available`, `unavailable`, `NR`, `not
#'   reported`, `confidential`, `C`, `suppressed`, `..`, `-`, and an em dash,
#'   with matching performed case-insensitively after trimming whitespace.
#' @details An unexplained non-empty, non-numeric token raises an
#'   `agau_validation_error` containing the first offending raw value.  The
#'   function does not alter `x` and performs no I/O.
#' @seealso [agau_status()], [validate_agau_release()]
#' @family normalisation helpers
#' @examples
#' reasons <- agau_missing_reason(c("12.5", "NA", "not available", "-", ""))
#' stopifnot(is.na(reasons[[1L]]), identical(reasons[[2L]], "provider_na"))
#' reasons
#' @export
agau_missing_reason <- function(x) {
  raw <- as.character(x)
  raw[is.na(x)] <- NA_character_
  token <- tolower(trimws(raw))
  result <- rep(NA_character_, length(raw))
  result[is.na(raw) | token == ""] <- "blank"
  result[token %in% c("na")] <- "provider_na"
  result[token %in% c("n/a", "not applicable")] <- "not_applicable"
  result[token %in% c("not available", "unavailable")] <- "unavailable"
  result[token %in% c("nr", "not reported")] <- "unavailable"
  result[token %in% c("confidential", "c")] <- "confidential"
  result[token %in% c("suppressed", "..", "\u2014", "-")] <- "suppressed"
  unresolved <- is.na(result) & is.na(suppressWarnings(as.numeric(token)))
  if (any(unresolved)) {
    agau_abort(
      "agau_validation_error",
      "Unexplained non-empty value in a numeric region.",
      raw_value = raw[which(unresolved)[1]],
      remediation = "Add an explicit source marker or repair the parser."
    )
  }
  result
}
