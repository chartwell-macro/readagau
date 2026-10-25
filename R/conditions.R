.agau_condition_classes <- c(
  "agau_release_discovery_error",
  "agau_asset_missing_error",
  "agau_download_error",
  "agau_dependency_error",
  "agau_asset_format_error",
  "agau_schema_error",
  "agau_table_parse_error",
  "agau_endpoint_error",
  "agau_status_warning",
  "agau_duplicate_warning",
  "agau_cadence_warning",
  "agau_validation_error"
)

agau_condition <- function(subclass, message, ..., warning = FALSE) {
  if (!subclass %in% .agau_condition_classes) {
    stop("Unknown readagau condition subclass: ", subclass, call. = FALSE)
  }
  parent <- if (isTRUE(warning)) "agau_warning" else "agau_error"
  base <- if (isTRUE(warning)) "warning" else "error"
  structure(
    c(list(message = message, call = NULL), list(...)),
    class = c(subclass, parent, base, "condition")
  )
}

agau_abort <- function(subclass, message, ...) {
  stop(agau_condition(subclass, message, ...))
}

agau_warn <- function(subclass, message, ...) {
  warning(agau_condition(subclass, message, ..., warning = TRUE))
}

agau_condition_catalog <- function() {
  data.frame(
    class = .agau_condition_classes,
    kind = ifelse(grepl("_warning$", .agau_condition_classes),
      "warning", "error"
    ),
    stringsAsFactors = FALSE
  )
}
