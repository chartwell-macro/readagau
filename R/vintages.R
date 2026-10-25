agau_structural_breaks <- function(data) {
  identity_fields <- c(
    "product", "dataset", "sector", "season", "commodity", "concept", "period"
  )
  metadata_fields <- c(
    "geography_type", "geography", "market", "unit", "currency",
    "price_basis", "period_basis", "method"
  )
  if (!all(c(identity_fields, metadata_fields, "release_id") %in% names(data)) ||
      nrow(data) < 2L) {
    return(tibble::tibble())
  }
  text_field <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- "<NA>"
    x
  }
  identity <- do.call(
    paste,
    c(lapply(data[identity_fields], text_field), sep = "\u241f")
  )
  groups <- split(seq_len(nrow(data)), identity)
  rows <- list()
  for (idx in groups) {
    g <- data[idx, , drop = FALSE]
    geography_key <- paste(
      text_field(g$geography_type), text_field(g$geography),
      text_field(g$market), sep = "\u241f"
    )
    geography_per_release <- split(geography_key, g$release_id)
    parallel_geographies <- any(vapply(
      geography_per_release,
      function(z) length(unique(z)) > 1L,
      logical(1)
    ))
    subgroups <- if (parallel_geographies) {
      split(seq_len(nrow(g)), geography_key)
    } else {
      list(seq_len(nrow(g)))
    }
    for (sub_idx in subgroups) {
      candidate <- g[sub_idx, , drop = FALSE]
      release_ids <- unique(as.character(candidate$release_id))
      if (length(release_ids) < 2L) next
      changed <- vapply(metadata_fields, function(field) {
        values <- split(text_field(candidate[[field]]), candidate$release_id)
        sets <- vapply(values, function(z) {
          paste(sort(unique(z)), collapse = "\u241e")
        }, "")
        length(unique(sets)) > 1L
      }, logical(1))
      if (!any(changed)) next
      report_fields <- c(
        identity_fields,
        if (parallel_geographies) c("geography_type", "geography", "market")
      )
      identity_values <- vapply(report_fields, function(field) {
        unique(text_field(candidate[[field]]))[[1]]
      }, "")
      rows[[length(rows) + 1L]] <- data.frame(
        identity = paste(
          paste(report_fields, identity_values, sep = "="),
          collapse = ", "
        ),
        release_ids = paste(sort(release_ids), collapse = ", "),
        fields = paste(metadata_fields[changed], collapse = ", "),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(tibble::tibble())
  tibble::as_tibble(do.call(rbind, rows))
}

agau_prepare_vintages <- function(data, releases = NULL, series = NULL) {
  required <- c(
    "release_id", "release_date", "series_id", "observation_key", "period",
    "period_status", "value", "unit", "currency", "price_basis",
    "period_basis", "geography", "source_sheet", "sha256"
  )
  absent <- setdiff(required, names(data))
  if (length(absent)) {
    agau_abort("agau_validation_error",
      paste("Vintage data is missing:", paste(absent, collapse = ", ")),
      remediation = "Use a readagau observation result."
    )
  }
  if (!is.null(releases) && (!is.atomic(releases) || is.list(releases))) {
    agau_abort(
      "agau_validation_error",
      "`releases` must be a character release-ID filter when data is supplied.",
      remediation = "Pass package-loading release specifications to compare_agau_vintages()."
    )
  }
  if (!is.null(releases)) data <- data[data$release_id %in% releases, , drop = FALSE]
  if (!is.null(series)) data <- data[data$series_id %in% series, , drop = FALSE]
  if (any(is.na(data$release_date))) {
    agau_abort(
      "agau_validation_error",
      "Vintage data contains a missing release date.",
      remediation = "Use exact releases with official publication dates."
    )
  }
  structural_breaks <- agau_structural_breaks(data)
  if (nrow(structural_breaks)) {
    first <- structural_breaks[1, , drop = FALSE]
    agau_abort(
      "agau_validation_error",
      paste(
        "Semantic metadata structural break detected for",
        first$identity[[1]], "in", first$fields[[1]]
      ),
      product = if ("product" %in% names(data)) unique(data$product)[[1]] else NA_character_,
      structural_breaks = structural_breaks,
      remediation = paste(
        "Review and version a semantic concordance before comparing",
        "these releases."
      )
    )
  }
  dup <- duplicated(paste(data$release_id, data$observation_key, sep = "::"))
  if (any(dup)) {
    agau_abort("agau_validation_error",
      "Vintage join is non-unique within a release.",
      release_id = data$release_id[which(dup)[1]],
      series_id = data$series_id[which(dup)[1]],
      remediation = "Use canonical data or resolve the source collision explicitly."
    )
  }
  data[order(data$observation_key, data$release_date, data$release_id), , drop = FALSE]
}

agau_issue_to_target_months <- function(row) {
  release_date <- as.Date(row$release_date[[1]])
  period_end <- if ("period_end" %in% names(row)) {
    as.Date(row$period_end[[1]])
  } else {
    as.Date(NA)
  }
  if (is.na(period_end)) {
    period_end <- agau_period_bounds(row$period[[1]])$period_end[[1]]
  }
  if (is.na(release_date) || is.na(period_end)) return(NA_integer_)
  release_parts <- as.POSIXlt(release_date)
  target_parts <- as.POSIXlt(period_end)
  as.integer(
    (target_parts$year - release_parts$year) * 12L +
      (target_parts$mon - release_parts$mon)
  )
}

agau_revision_row <- function(old, new, kind) {
  old_value <- old$value[[1]]; new_value <- new$value[[1]]
  data.frame(
    comparison = kind,
    observation_key = old$observation_key[[1]],
    series_id_old = old$series_id[[1]],
    series_id_new = new$series_id[[1]],
    period = old$period[[1]],
    old_release = old$release_id[[1]],
    new_release = new$release_id[[1]],
    old_release_date = as.Date(old$release_date[[1]]),
    new_release_date = as.Date(new$release_date[[1]]),
    old_issue_to_target_horizon_months = agau_issue_to_target_months(old),
    new_issue_to_target_horizon_months = agau_issue_to_target_months(new),
    old_status = old$period_status[[1]],
    new_status = new$period_status[[1]],
    status_transition = paste(old$period_status[[1]], new$period_status[[1]], sep = " -> "),
    old_value = old_value,
    new_value = new_value,
    absolute_revision = new_value - old_value,
    percentage_revision = if (!is.na(old_value) && old_value != 0) 100 * (new_value - old_value) / abs(old_value) else NA_real_,
    old_source_sheet = old$source_sheet[[1]],
    new_source_sheet = new$source_sheet[[1]],
    old_sha256 = old$sha256[[1]],
    new_sha256 = new$sha256[[1]],
    stringsAsFactors = FALSE
  )
}

agau_collect_revisions <- function(data, predicate, kind) {
  groups <- split(seq_len(nrow(data)), data$observation_key)
  rows <- list()
  for (idx in groups) {
    if (length(idx) < 2L) next
    for (j in 2:length(idx)) {
      old <- data[idx[j - 1L], , drop = FALSE]
      new <- data[idx[j], , drop = FALSE]
      if (predicate(old, new)) {
        rows[[length(rows) + 1L]] <- agau_revision_row(old, new, kind)
      }
    }
  }
  if (!length(rows)) return(tibble::tibble())
  tibble::as_tibble(do.call(rbind, rows))
}

#' Compare historical observations across ABARES vintages
#'
#' Compares adjacent releases for each `observation_key` when both rows are
#' realised observations.  A row is returned only when the numeric `value`
#' changes.  This is the history-revision member of the vintage-comparison
#' family; use [agau_forecast_revision()] for forecast updates and
#' [agau_forecast_error()] for forecast-to-realisation errors.
#'
#' @param data A data frame of canonical observations, normally returned by a
#'   readagau reader.  It must contain `release_id`, `release_date`,
#'   `series_id`, `observation_key`, `period`, `period_status`, `value`,
#'   `unit`, `currency`, `price_basis`, `period_basis`, `geography`,
#'   `source_sheet`, and `sha256`.  The semantic columns `product`, `dataset`,
#'   `sector`, `season`, `commodity`, `concept`, `geography_type`, `market`,
#'   and `method` are used when present to detect structural breaks.
#' @param releases An optional character vector of exact release IDs to retain
#'   when `data` is supplied.  `NULL` keeps every row.  A list is not accepted
#'   by this function; use `compare_agau_vintages()` with `data = NULL` when
#'   exact releases must be loaded from local assets or from the source.
#' @param series An optional character vector of `series_id` values to retain.
#'   `NULL` keeps every series.
#' @return A tibble.  A non-empty result has these columns, in order:
#'   `comparison`, `observation_key`, `series_id_old`, `series_id_new`,
#'   `period`, `old_release`, `new_release`, `old_release_date`,
#'   `new_release_date`, `old_issue_to_target_horizon_months`,
#'   `new_issue_to_target_horizon_months`, `old_status`, `new_status`,
#'   `status_transition`, `old_value`, `new_value`, `absolute_revision`,
#'   `percentage_revision`, `old_source_sheet`, `new_source_sheet`,
#'   `old_sha256`, and `new_sha256`.  The release-date columns have class
#'   `Date`; horizon columns are integer; value and revision columns are
#'   numeric; IDs, statuses, source-sheet names, hashes, and `comparison` are
#'   character.  `absolute_revision` is `new_value - old_value` and
#'   `percentage_revision` is that difference divided by `abs(old_value)` and
#'   multiplied by 100, or `NA` when the old value is missing or zero.  When
#'   no changed realised pair remains, the result is a zero-row, zero-column
#'   tibble (`tibble::tibble()`, class `c("tbl_df", "tbl", "data.frame")`).
#' @details Rows are ordered by `observation_key`, `release_date`, and
#'   `release_id`; only consecutive rows within an observation are compared.
#'   History statuses are `estimate`, `historical`, and
#'   `published-unclassified`.  The issue-to-target horizon is the calendar
#'   month difference from `release_date` to `period_end`, using a supplied
#'   `period_end` column when available and otherwise the period bounds inferred
#'   by readagau.
#'
#' Before comparison, required-column, missing-release-date, semantic
#' structural-break, and duplicate-join checks are applied.  A structural
#' break means that metadata (`geography_type`, `geography`, `market`, `unit`,
#' `currency`, `price_basis`, `period_basis`, or `method`) changes for one
#' semantic identity across releases; it raises an `agau_validation_error`
#' with a `structural_breaks` diagnostic.  A duplicate `(release_id,
#' observation_key)` raises the same class.  These functions do not make
#' network requests or write cache files when `data` is supplied.
#' @examples
#' vintage <- data.frame(
#'   product = rep("crop_report", 4), dataset = rep("state", 4),
#'   sector = rep("crops", 4), season = rep("winter", 4),
#'   commodity = rep("Wheat", 4), concept = rep("Production", 4),
#'   period = rep("2026-27", 4), geography_type = rep("national", 4),
#'   geography = rep("Australia", 4), market = rep(NA_character_, 4),
#'   unit = rep("kt", 4), currency = rep("not_applicable", 4),
#'   price_basis = rep("not_applicable", 4),
#'   period_basis = rep("financial_year", 4), method = rep("synthetic", 4),
#'   release_id = c("acr-2025-01-01", "acr-2025-04-01",
#'     "acr-2025-07-01", "acr-2025-10-01"),
#'   release_date = as.Date(c("2025-01-01", "2025-04-01", "2025-07-01",
#'     "2025-10-01")), series_id = rep("wheat-production", 4),
#'   observation_key = rep("wheat-production::2026-27", 4),
#'   period_status = c("forecast", "forecast", "estimate", "historical"),
#'   value = c(100, 110, 120, 125), source_sheet = rep("synthetic", 4),
#'   sha256 = sprintf("%064d", 1:4), stringsAsFactors = FALSE
#' )
#' agau_history_revision(vintage)[, c("old_release", "new_release",
#'   "old_value", "new_value")]
#' @seealso [agau_forecast_revision()], [agau_forecast_error()],
#'   [compare_agau_vintages()]
#' @family vintage comparisons
#' @export
agau_history_revision <- function(data, releases = NULL, series = NULL) {
  data <- agau_prepare_vintages(data, releases, series)
  non_forecast <- c("estimate", "historical", "published-unclassified")
  agau_collect_revisions(data, function(old, new) {
    old$period_status %in% non_forecast &&
      new$period_status %in% non_forecast &&
      !isTRUE(all.equal(old$value, new$value))
  }, "history_revision")
}

#' Compare forecasts across ABARES vintages
#'
#' Compares adjacent releases for each `observation_key` when the old row is a
#' `forecast` or `projection` and the new row is a forecast, projection,
#' estimate, or historical observation.  A row is returned only when `value`
#' changes.  The result records the forecast horizon and report-round context
#' needed to interpret each update.
#'
#' @inheritParams agau_history_revision
#' @return A tibble.  The first 22 columns are the same as
#' [agau_history_revision()] (`comparison`, `observation_key`,
#' `series_id_old`, `series_id_new`, `period`, `old_release`, `new_release`,
#' `old_release_date`, `new_release_date`,
#' `old_issue_to_target_horizon_months`,
#' `new_issue_to_target_horizon_months`, `old_status`, `new_status`,
#' `status_transition`, `old_value`, `new_value`, `absolute_revision`,
#' `percentage_revision`, `old_source_sheet`, `new_source_sheet`,
#' `old_sha256`, `new_sha256`).  They are followed, in order, by
#' `revision_number`, `revision_count`, `old_report_round`, `new_report_round`,
#' `first_forecast_release`, `first_forecast_status`, `first_forecast_value`,
#' `previous_forecast_release`, `previous_forecast_status`,
#' `previous_forecast_value`, `latest_forecast_release`,
#' `latest_forecast_status`, and `latest_forecast_value`.  Date columns have
#' class `Date`; horizon, round, and count columns are integer; values and
#' revisions are numeric; all IDs, statuses, source-sheet names, hashes, and
#' `comparison` are character.  `revision_number` is the one-based order of
#' the changed transitions for an observation and `revision_count` is their
#' total.  The first, previous, and latest fields describe the first forecast,
#' the latest forecast strictly before the new release date, and the latest
#' forecast in the selected vintages, respectively; unavailable previous
#' fields are `NA`.  If no changed forecast transition remains, the result is
#' a zero-row, zero-column tibble (`tibble::tibble()`, class
#' `c("tbl_df", "tbl", "data.frame")`).
#' @details Rows are sorted by observation, release date, and release ID.
#'   `old_report_round` and `new_report_round` are one-based positions in the
#'   complete release sequence for that observation, not positions only among
#'   changed rows.  Horizon fields are calendar-month differences from each
#'   issue date to the target period end.  A supplied `period_end` column is
#'   used; otherwise readagau infers the end from `period`.  The previous
#'   forecast requires a strictly earlier release date, so two releases on the
#'   same date do not create a previous selection.
#'
#' Required-column, missing-date, structural-break, and duplicate-join
#' validation is identical to [agau_history_revision()].  Structural metadata
#' changes are reported as `agau_validation_error` before values are compared.
#' This function is deterministic and has no network or cache side effects
#' when `data` is supplied.
#' @examples
#' vintage <- data.frame(
#'   product = rep("crop_report", 4), dataset = rep("state", 4),
#'   sector = rep("crops", 4), season = rep("winter", 4),
#'   commodity = rep("Wheat", 4), concept = rep("Production", 4),
#'   period = rep("2026-27", 4), geography_type = rep("national", 4),
#'   geography = rep("Australia", 4), market = rep(NA_character_, 4),
#'   unit = rep("kt", 4), currency = rep("not_applicable", 4),
#'   price_basis = rep("not_applicable", 4),
#'   period_basis = rep("financial_year", 4), method = rep("synthetic", 4),
#'   release_id = c("acr-2025-01-01", "acr-2025-04-01",
#'     "acr-2025-07-01", "acr-2025-10-01"),
#'   release_date = as.Date(c("2025-01-01", "2025-04-01", "2025-07-01",
#'     "2025-10-01")), series_id = rep("wheat-production", 4),
#'   observation_key = rep("wheat-production::2026-27", 4),
#'   period_status = c("forecast", "forecast", "estimate", "historical"),
#'   value = c(100, 110, 120, 125), source_sheet = rep("synthetic", 4),
#'   sha256 = sprintf("%064d", 1:4), stringsAsFactors = FALSE
#' )
#' agau_forecast_revision(vintage)[, c("old_release", "new_release",
#'   "old_value", "new_value", "revision_number",
#'   "previous_forecast_value")]
#' @seealso [agau_history_revision()], [agau_forecast_error()],
#'   [compare_agau_vintages()]
#' @family vintage comparisons
#' @export
agau_forecast_revision <- function(data, releases = NULL, series = NULL) {
  data <- agau_prepare_vintages(data, releases, series)
  out <- agau_collect_revisions(data, function(old, new) {
    old$period_status %in% c("forecast", "projection") &&
      new$period_status %in% c("forecast", "projection", "estimate", "historical") &&
      !isTRUE(all.equal(old$value, new$value))
  }, "forecast_revision")
  if (!nrow(out)) return(out)
  out$revision_number <- NA_integer_
  out$revision_count <- NA_integer_
  out$old_report_round <- NA_integer_
  out$new_report_round <- NA_integer_
  out$first_forecast_release <- NA_character_
  out$first_forecast_status <- NA_character_
  out$first_forecast_value <- NA_real_
  out$previous_forecast_release <- NA_character_
  out$previous_forecast_status <- NA_character_
  out$previous_forecast_value <- NA_real_
  out$latest_forecast_release <- NA_character_
  out$latest_forecast_status <- NA_character_
  out$latest_forecast_value <- NA_real_
  for (key in unique(out$observation_key)) {
    out_idx <- which(out$observation_key == key)
    g <- data[data$observation_key == key, , drop = FALSE]
    g <- g[order(g$release_date, g$release_id), , drop = FALSE]
    forecasts <- g$period_status %in% c("forecast", "projection")
    forecast_rows <- which(forecasts)
    first <- forecast_rows[[1]]
    latest <- utils::tail(forecast_rows, 1L)
    out$revision_number[out_idx] <- seq_along(out_idx)
    out$revision_count[out_idx] <- length(out_idx)
    out$first_forecast_release[out_idx] <- g$release_id[[first]]
    out$first_forecast_status[out_idx] <- g$period_status[[first]]
    out$first_forecast_value[out_idx] <- g$value[[first]]
    out$latest_forecast_release[out_idx] <- g$release_id[[latest]]
    out$latest_forecast_status[out_idx] <- g$period_status[[latest]]
    out$latest_forecast_value[out_idx] <- g$value[[latest]]
    for (i in out_idx) {
      old <- match(out$old_release[[i]], g$release_id)
      new <- match(out$new_release[[i]], g$release_id)
      out$old_report_round[[i]] <- old
      out$new_report_round[[i]] <- new
      previous <- forecast_rows[
        g$release_date[forecast_rows] < out$new_release_date[[i]]
      ]
      if (length(previous)) {
        p <- utils::tail(previous, 1L)
        out$previous_forecast_release[[i]] <- g$release_id[[p]]
        out$previous_forecast_status[[i]] <- g$period_status[[p]]
        out$previous_forecast_value[[i]] <- g$value[[p]]
      }
    }
  }
  out
}

#' Compare ABARES forecasts with realised observations
#'
#' Matches every forecast or projection to a later realised observation for
#' the same `observation_key`.  `realisation` chooses the earliest available
#' actual or the latest revised actual, allowing forecast errors to be
#' reported under either convention.
#'
#' @inheritParams agau_history_revision
#' @param realisation A character choice of `"first"` (the earliest later
#'   `estimate` or `historical` release) or `"latest_revised"` (the latest
#'   such release).  The default is `"first"`.
#' @return A tibble.  A non-empty result has these columns, in order:
#'   `comparison`, `observation_key`, `series_id_old`, `series_id_new`,
#'   `period`, `old_release`, `new_release`, `old_release_date`,
#'   `new_release_date`, `old_issue_to_target_horizon_months`,
#'   `new_issue_to_target_horizon_months`, `old_status`, `new_status`,
#'   `status_transition`, `old_value`, `new_value`, `forecast_error`,
#'   `percentage_error`, `old_source_sheet`, `new_source_sheet`, `old_sha256`,
#'   `new_sha256`, and `realisation_selection`.  Date columns have class
#'   `Date`; horizon columns are integer; values and error columns are numeric;
#'   IDs, statuses, source-sheet names, hashes, `comparison`, and
#'   `realisation_selection` are character.  `forecast_error` is
#'   `new_value - old_value` (actual minus forecast), and
#'   `percentage_error` uses the same `abs(old_value)` denominator as a
#'   revision percentage, or is `NA` for a missing or zero forecast.  A
#'   forecast is eligible only when the selected actual has a strictly later
#'   `release_date`; no value-change filter is applied.  If no match remains,
#'   the result is a zero-row, zero-column tibble (`tibble::tibble()`, class
#'   `c("tbl_df", "tbl", "data.frame")`).
#' @details Rows are ordered by observation, release date, and release ID.
#'   For `"first"`, the first later actual in that order is used; for
#'   `"latest_revised"`, the last is used.  The `comparison` column is
#'   `"forecast_error_first_realisation"` or
#'   `"forecast_error_latest_revised"`, matching the selection.  Forecasts
#'   and projections are eligible on the old side; estimates and historical
#'   observations are eligible on the realised side.
#'
#' Required-column, missing-date, structural-break, and duplicate-join
#' validation is identical to [agau_history_revision()].  Invalid
#' `realisation` values raise the standard `match.arg()` error.  With `data`
#' supplied this function makes no network requests and writes no cache files.
#' @examples
#' vintage <- data.frame(
#'   product = rep("crop_report", 4), dataset = rep("state", 4),
#'   sector = rep("crops", 4), season = rep("winter", 4),
#'   commodity = rep("Wheat", 4), concept = rep("Production", 4),
#'   period = rep("2026-27", 4), geography_type = rep("national", 4),
#'   geography = rep("Australia", 4), market = rep(NA_character_, 4),
#'   unit = rep("kt", 4), currency = rep("not_applicable", 4),
#'   price_basis = rep("not_applicable", 4),
#'   period_basis = rep("financial_year", 4), method = rep("synthetic", 4),
#'   release_id = c("acr-2025-01-01", "acr-2025-04-01",
#'     "acr-2025-07-01", "acr-2025-10-01"),
#'   release_date = as.Date(c("2025-01-01", "2025-04-01", "2025-07-01",
#'     "2025-10-01")), series_id = rep("wheat-production", 4),
#'   observation_key = rep("wheat-production::2026-27", 4),
#'   period_status = c("forecast", "forecast", "estimate", "historical"),
#'   value = c(100, 110, 120, 125), source_sheet = rep("synthetic", 4),
#'   sha256 = sprintf("%064d", 1:4), stringsAsFactors = FALSE
#' )
#' agau_forecast_error(vintage, realisation = "latest_revised")[,
#'   c("old_release", "new_release", "old_value", "new_value",
#'     "forecast_error", "realisation_selection")]
#' @seealso [agau_history_revision()], [agau_forecast_revision()],
#'   [compare_agau_vintages()]
#' @family vintage comparisons
#' @export
agau_forecast_error <- function(
    data, releases = NULL, series = NULL,
    realisation = c("first", "latest_revised")) {
  realisation <- match.arg(realisation)
  data <- agau_prepare_vintages(data, releases, series)
  groups <- split(seq_len(nrow(data)), data$observation_key)
  rows <- list()
  for (idx in groups) {
    g <- data[idx, , drop = FALSE]
    forecasts <- which(g$period_status %in% c("forecast", "projection"))
    actuals <- which(g$period_status %in% c("estimate", "historical"))
    for (f in forecasts) {
      later <- actuals[g$release_date[actuals] > g$release_date[f]]
      if (!length(later)) next
      r <- if (realisation == "first") later[1] else utils::tail(later, 1L)
      row <- agau_revision_row(
        g[f, , drop = FALSE], g[r, , drop = FALSE],
        if (realisation == "first") "forecast_error_first_realisation" else "forecast_error_latest_revised"
      )
      names(row)[names(row) == "absolute_revision"] <- "forecast_error"
      names(row)[names(row) == "percentage_revision"] <- "percentage_error"
      row$realisation_selection <- realisation
      rows[[length(rows) + 1L]] <- row
    }
  }
  if (!length(rows)) return(tibble::tibble())
  tibble::as_tibble(do.call(rbind, rows))
}

agau_vintage_release_date <- function(release_id) {
  day <- regmatches(
    release_id,
    regexpr("20[0-9]{2}-[0-9]{2}-[0-9]{2}", release_id)
  )
  if (length(day) && nzchar(day)) return(as.Date(day))
  month <- regmatches(
    release_id,
    regexpr("20[0-9]{2}-[0-9]{2}", release_id)
  )
  if (length(month) && nzchar(month)) {
    return(as.Date(paste0(month, "-01")))
  }
  as.Date(NA)
}

agau_vintage_specs <- function(releases) {
  if (is.null(releases) || !length(releases)) {
    agau_abort(
      "agau_validation_error",
      "At least one exact release must be supplied when data is NULL.",
      remediation = "Supply exact release IDs or a named list of local release assets."
    )
  }
  if (is.character(releases) && !is.list(releases)) {
    if (!is.null(names(releases)) && all(nzchar(names(releases))) &&
        all(file.exists(releases))) {
      specs <- as.list(unname(releases))
      names(specs) <- names(releases)
    } else {
      specs <- as.list(unname(releases))
      names(specs) <- unname(releases)
    }
  } else if (is.list(releases)) {
    specs <- releases
    if (is.null(names(specs)) || any(!nzchar(names(specs)))) {
      inferred <- vapply(specs, function(x) {
        if (is.character(x) && length(x) == 1L && !file.exists(x)) x else ""
      }, "")
      if (any(!nzchar(inferred))) {
        agau_abort(
          "agau_validation_error",
          "Local vintage release specifications must be named by exact release ID.",
          remediation = paste(
            "Use releases = list(`acr-YYYY-MM-DD-...` =",
            "c(state = 'path/to/workbook.xlsx'))."
          )
        )
      }
      names(specs) <- inferred
    }
  } else {
    agau_abort(
      "agau_validation_error",
      "Unsupported vintage release specification.",
      remediation = "Use character release IDs or a named list of release inputs."
    )
  }
  if (any(names(specs) == "latest") ||
      any(vapply(specs, function(x) identical(x, "latest"), logical(1)))) {
    agau_abort(
      "agau_validation_error",
      "Vintage comparison requires exact releases; `latest` is not stable.",
      remediation = "Resolve and record exact release IDs before comparison."
    )
  }
  if (anyDuplicated(names(specs))) {
    agau_abort(
      "agau_validation_error",
      "Vintage release IDs must be unique.",
      remediation = "Supply each exact release once."
    )
  }
  specs
}

agau_load_product_vintage <- function(product, release, release_id, cache_dir) {
  seam <- getOption("readagau.vintage_loader")
  if (is.function(seam)) {
    out <- seam(
      product = product, release = release, release_id = release_id,
      cache_dir = cache_dir
    )
  } else if (product == "crop_report") {
    assets <- if (is.character(release) && all(file.exists(release))) {
      roles <- names(release)
      if (is.null(roles) || any(!nzchar(roles))) {
        roles <- vapply(release, agau_infer_role, "", product = product)
        names(release) <- roles
      }
      roles
    } else {
      c("national", "state")
    }
    out <- read_crop_report(
      release = release, assets = assets, view = "canonical",
      cache_dir = cache_dir
    )
  } else if (product == "agricultural_commodities") {
    datasets <- if (is.character(release) && all(file.exists(release))) {
      roles <- names(release)
      if (is.null(roles) || any(!nzchar(roles))) {
        roles <- vapply(release, agau_infer_role, "", product = product)
        names(release) <- roles
      }
      roles
    } else {
      c("outlook", "statistics")
    }
    out <- read_agricultural_commodities(
      release = release, datasets = datasets, view = "canonical",
      cache_dir = cache_dir
    )
  } else if (product == "farm_productivity") {
    out <- read_farm_productivity(
      release = release, view = "canonical", cache_dir = cache_dir
    )
  } else {
    agau_abort(
      "agau_validation_error",
      paste("Vintage loading is not supported for product:", product),
      product = product,
      remediation = paste(
        "Use crop_report, agricultural_commodities or farm_productivity,",
        "or supply parsed data explicitly."
      )
    )
  }
  if (!is.data.frame(out)) {
    agau_abort(
      "agau_validation_error",
      "Vintage loader did not return observation data.",
      product = product, release_id = release_id,
      remediation = "Return a readagau observation data frame from the loader."
    )
  }
  out$release_id <- release_id
  release_date <- agau_vintage_release_date(release_id)
  if (!is.na(release_date)) out$release_date <- release_date
  out
}

agau_load_vintages <- function(product, releases, cache_dir) {
  supported <- c(
    "crop_report", "agricultural_commodities", "farm_productivity"
  )
  if (!product %in% supported) {
    agau_abort(
      "agau_validation_error",
      paste("Vintage loading is not supported for product:", product),
      product = product,
      remediation = paste("Use one of:", paste(supported, collapse = ", "))
    )
  }
  specs <- agau_vintage_specs(releases)
  rows <- lapply(seq_along(specs), function(i) {
    agau_load_product_vintage(
      product, specs[[i]], names(specs)[[i]], cache_dir
    )
  })
  if (!length(rows)) return(agau_empty_observations())
  out <- do.call(rbind, rows)
  class(out) <- unique(c("agau_data", class(out)))
  out
}

#' Compare ABARES vintages
#'
#' Provides one entry point for the three vintage-comparison families.  Supply
#' canonical observations in `data` for a deterministic offline comparison, or
#' leave `data` `NULL` to load the requested exact releases through the
#' package readers before comparing them.
#'
#' @param product A product ID.  When `data` is `NULL`, loading supports
#'   `"crop_report"`, `"agricultural_commodities"`, and
#'   `"farm_productivity"`; another value raises an `agau_validation_error`.
#'   When `data` is supplied, the value is retained as the caller's product
#'   declaration and the supplied observations are compared directly.
#' @param data A canonical observation data frame.  When `NULL`, exact
#'   releases are loaded through the product reader selected by `product`.
#'   When non-`NULL`, it is passed to the same validation and comparison
#'   routines as [agau_history_revision()], [agau_forecast_revision()], and
#'   [agau_forecast_error()].
#' @param releases When `data` is `NULL`, exact release IDs as a character
#'   vector, or a named list of local release assets keyed by exact release ID.
#'   A named character vector whose values are existing files is also accepted
#'   for local assets.  `"latest"` is rejected because it is not a stable
#'   vintage.  When `data` is supplied, this must instead be an optional
#'   character release-ID filter; `NULL` keeps all rows.
#' @param series An optional character vector of `series_id` values to retain.
#'   `NULL` keeps every series.
#' @param comparison One of `"all"`, `"history_revision"`,
#'   `"forecast_revision"`, or `"forecast_error"`.  The default, `"all"`,
#'   computes every family.
#' @param cache_dir Directory used by the underlying readers when exact
#'   releases must be loaded.  It defaults to [agau_cache_dir()].  It is not
#'   used for filtering an already supplied `data` frame.
#' @return If `comparison` is `"all"`, a named list with exactly three
#'   elements: `history_revision`, `forecast_revision`, and `forecast_error`,
#'   in that order.  Each element is the corresponding tibble described in
#'   [agau_history_revision()], [agau_forecast_revision()], or
#'   [agau_forecast_error()], including its zero-row, zero-column tibble when
#'   no matches exist.  For any other `comparison`, the corresponding single
#'   tibble is returned.  Non-empty tibbles retain the column names, order,
#'   classes, and types of their underlying function; the list itself has no
#'   additional class.
#' @details When `data` is `NULL`, releases are loaded in the order supplied
#'   and exact release IDs are attached to every observation.  A release ID
#'   date is used when it can be read from the ID; otherwise the release input
#'   must provide a valid `release_date`.  Network requests, downloaded asset
#'   files, and parser/cache metadata are delegated to the readers and are
#'   bounded to `cache_dir`; named local release assets avoid source discovery
#'   and network downloads.  With `data` supplied, no readers are called and
#'   this function performs no network or cache side effects.
#'
#' All modes apply the same required-column, release-date, semantic
#' structural-break, and `(release_id, observation_key)` uniqueness checks.
#' Validation failures raise `agau_validation_error`; structural-break
#' diagnostics are attached as `structural_breaks`.  Exact release loading
#' additionally rejects missing release specifications, duplicate IDs,
#' unsupported products, and the unstable `"latest"` selector.
#' @examples
#' vintage <- data.frame(
#'   product = rep("crop_report", 4), dataset = rep("state", 4),
#'   sector = rep("crops", 4), season = rep("winter", 4),
#'   commodity = rep("Wheat", 4), concept = rep("Production", 4),
#'   period = rep("2026-27", 4), geography_type = rep("national", 4),
#'   geography = rep("Australia", 4), market = rep(NA_character_, 4),
#'   unit = rep("kt", 4), currency = rep("not_applicable", 4),
#'   price_basis = rep("not_applicable", 4),
#'   period_basis = rep("financial_year", 4), method = rep("synthetic", 4),
#'   release_id = c("acr-2025-01-01", "acr-2025-04-01",
#'     "acr-2025-07-01", "acr-2025-10-01"),
#'   release_date = as.Date(c("2025-01-01", "2025-04-01", "2025-07-01",
#'     "2025-10-01")), series_id = rep("wheat-production", 4),
#'   observation_key = rep("wheat-production::2026-27", 4),
#'   period_status = c("forecast", "forecast", "estimate", "historical"),
#'   value = c(100, 110, 120, 125), source_sheet = rep("synthetic", 4),
#'   sha256 = sprintf("%064d", 1:4), stringsAsFactors = FALSE
#' )
#' comparisons <- compare_agau_vintages(
#'   "crop_report", data = vintage, comparison = "all"
#' )
#' vapply(comparisons, nrow, integer(1))
#' @seealso [agau_history_revision()], [agau_forecast_revision()],
#'   [agau_forecast_error()]
#' @family vintage comparisons
#' @export
compare_agau_vintages <- function(
    product, data = NULL, releases = NULL, series = NULL,
    comparison = c("all", "history_revision", "forecast_revision", "forecast_error"),
    cache_dir = agau_cache_dir()) {
  comparison <- match.arg(comparison)
  loaded <- is.null(data)
  if (is.null(data)) {
    data <- agau_load_vintages(product, releases, cache_dir)
  }
  release_filter <- if (loaded) NULL else releases
  operation <- function(kind) switch(
    kind,
    history_revision = agau_history_revision(data, release_filter, series),
    forecast_revision = agau_forecast_revision(data, release_filter, series),
    forecast_error = agau_forecast_error(data, release_filter, series)
  )
  if (comparison == "all") {
    kinds <- c("history_revision", "forecast_revision", "forecast_error")
    stats::setNames(lapply(kinds, operation), kinds)
  } else {
    operation(comparison)
  }
}
