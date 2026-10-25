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
#' @param data Parsed observations.
#' @param releases Optional releases.
#' @param series Optional semantic series.
#' @return A revision tibble.
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
#' @inheritParams agau_history_revision
#' @return A forecast-revision tibble with issue-to-target horizons in months,
#'   report rounds, revision counts and explicit first, previous and latest
#'   forecast selections.
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
#' @inheritParams agau_history_revision
#' @param realisation Either the first realisation or latest revised value.
#' @return A forecast-error tibble.
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
#' @param product Product ID.
#' @param data Parsed canonical observations. When `NULL`, exact releases are
#'   loaded through the package readers.
#' @param releases Exact release IDs, a named list of local release assets, or
#'   an optional release-ID filter when `data` is supplied.
#' @param series Optional semantic series.
#' @param comparison Comparison family.
#' @param cache_dir Cache directory.
#' @return A named list or one comparison tibble.
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
