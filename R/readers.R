agau_infer_role <- function(path, product) {
  if (agau_detect_format(path) == "pdf") return("report")
  staged <- agau_readxl_path(path)
  if (!identical(staged, path)) on.exit(unlink(staged), add = TRUE)
  sheets <- readxl::excel_sheets(staged)
  if (product == "crop_report") {
    if (all(c("Australia", "New South Wales") %in% sheets)) "state" else "national"
  } else if (product == "agricultural_commodities") {
    if (sum(grepl("^Table [0-9]+$", sheets)) >= 18L) "statistics" else "outlook"
  } else "supporting_data"
}

agau_resolve_reader_assets <- function(product, release, roles, cache_dir, refresh) {
  if (is.character(release) && length(release) >= 1L && all(file.exists(release))) {
    got_roles <- names(release)
    if (is.null(got_roles) || any(!nzchar(got_roles))) {
      got_roles <- vapply(release, agau_infer_role, "", product = product)
    }
    return(data.frame(
      asset_type = got_roles, local_path = unname(release),
      sha256 = vapply(unname(release), agau_sha256, ""),
      retrieved_at = as.POSIXct(file.info(unname(release))$mtime, tz = "UTC"),
      stringsAsFactors = FALSE
    ))
  }
  requested <- roles
  if (is.character(release) && length(release) == 1L &&
      !identical(release, "latest")) {
    audited <- agau_bundled_releases()
    hit <- audited[
      audited$product == product & audited$release_id == release,
      , drop = FALSE
    ]
    if (nrow(hit) == 1L) {
      available <- hit$asset_roles[[1]]
      requested <- intersect(roles, available)
      if (!length(requested) &&
          product == "agricultural_commodities" &&
          "outlook" %in% roles &&
          "report" %in% available) {
        requested <- "report"
      }
      if (!length(requested)) {
        agau_abort(
          "agau_validation_error",
          paste(
            "Requested dataset is not available for",
            hit$edition[[1]], "in the audited release catalogue."
          ),
          product = product, release_id = release,
          remediation = paste(
            "Request one of:", paste(available, collapse = ", "),
            if ("report" %in% available) "(the report represents outlook)." else ""
          )
        )
      }
    }
  }
  download_agau_release(product, release, assets = requested, cache_dir = cache_dir,
    refresh = refresh, verify = TRUE
  )
}

agau_ac_dataset_role <- function(asset_type) {
  ifelse(asset_type == "report", "outlook", asset_type)
}

agau_crop_commodity_season <- function(commodity) {
  key <- tolower(agau_strip_footnote_suffix(commodity))
  winter <- c(
    "wheat", "barley", "canola", "oats", "triticale", "chickpeas",
    "faba beans", "field peas", "lentils", "lupins"
  )
  summer <- c(
    "grain sorghum", "sorghum", "cottonseed", "cotton lint", "cotton",
    "rice", "maize", "corn", "corn (maize)", "soybeans", "sunflower",
    "sunflowers"
  )
  ifelse(
    key %in% winter,
    "winter",
    ifelse(key %in% summer, "summer", "")
  )
}

agau_harmonise_crop_identity <- function(data) {
  semantic_concept <- vapply(data$concept, agau_legacy_crop_measure, "")
  has_semantic_concept <- nzchar(semantic_concept)
  data$concept[has_semantic_concept] <-
    semantic_concept[has_semantic_concept]
  inferred <- agau_crop_commodity_season(data$commodity)
  identity_dimensions <- c(
    "product", "dataset", "geography_type", "geography", "sector",
    "commodity", "concept", "market", "unit", "period_basis",
    "price_basis", "currency", "method"
  )
  identity_parts <- lapply(data[identity_dimensions], function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  identity_key <- do.call(paste, c(identity_parts, sep = "\u241f"))
  source_sets <- split(data$source_dataset, identity_key)
  cross_workbook_keys <- names(source_sets)[vapply(source_sets, function(x) {
    all(c("crop_report_national", "crop_report_state") %in% unique(x))
  }, logical(1))]
  stream_dimensions <- c(
    "source_dataset", "source_sheet", "table_id", "season"
  )
  stream_parts <- lapply(data[stream_dimensions], function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  stream_key <- paste(
    identity_key,
    do.call(paste, c(stream_parts, sep = "\u241f")),
    sep = "\u241e"
  )
  streams <- split(seq_len(nrow(data)), stream_key)
  matched_streams <- character()
  for (key in cross_workbook_keys) {
    candidate_streams <- unique(stream_key[identity_key == key])
    target_season <- unique(inferred[
      identity_key == key & nzchar(inferred)
    ])
    national_streams <- candidate_streams[vapply(
      candidate_streams,
      function(candidate) {
        all(data$source_dataset[streams[[candidate]]] ==
          "crop_report_national")
      },
      logical(1)
    )]
    preferred_national_streams <- national_streams[vapply(
      national_streams,
      function(candidate) {
        all(data$season[streams[[candidate]]] %in% target_season)
      },
      logical(1)
    )]
    if (length(preferred_national_streams)) {
      national_streams <- preferred_national_streams
    }
    state_streams <- candidate_streams[vapply(
      candidate_streams,
      function(candidate) {
        all(data$source_dataset[streams[[candidate]]] ==
          "crop_report_state")
      },
      logical(1)
    )]
    for (national_stream in national_streams) {
      national_indices <- streams[[national_stream]]
      for (state_stream in state_streams) {
        state_indices <- streams[[state_stream]]
        shared_periods <- intersect(
          unique(as.character(data$period[national_indices])),
          unique(as.character(data$period[state_indices]))
        )
        compared_periods <- 0L
        conflict <- FALSE
        for (period in shared_periods) {
          national_values <- as.numeric(data$value[
            national_indices[
              as.character(data$period[national_indices]) == period
            ]
          ])
          state_values <- as.numeric(data$value[
            state_indices[
              as.character(data$period[state_indices]) == period
            ]
          ])
          national_values <- national_values[!is.na(national_values)]
          state_values <- state_values[!is.na(state_values)]
          if (!length(national_values) || !length(state_values)) next
          compared_periods <- compared_periods + 1L
          compared <- c(national_values, state_values)
          tolerance <- pmax(
            1e-8,
            1e-9 * pmax(abs(compared), abs(compared[[1]]))
          )
          if (any(abs(compared - compared[[1]]) > tolerance)) {
            conflict <- TRUE
            break
          }
        }
        if (compared_periods > 0L && !conflict) {
          matched_streams <- c(
            matched_streams,
            national_stream,
            state_stream
          )
        }
      }
    }
  }
  commodity_key <- tolower(agau_strip_footnote_suffix(data$commodity))
  pairwise_commodity <- commodity_key %in% c("corn", "corn (maize)")
  use_inferred <- nzchar(inferred) & (
    (!pairwise_commodity & identity_key %in% cross_workbook_keys) |
      (pairwise_commodity & stream_key %in% matched_streams)
  )
  data$season[use_inferred] <- inferred[use_inferred]
  data <- agau_rekey_data(data)

  duplicate_keys <- unique(data$observation_key[
    duplicated(data$observation_key) |
      duplicated(data$observation_key, fromLast = TRUE)
  ])
  if (!length(duplicate_keys)) return(data)

  keep <- rep(TRUE, nrow(data))
  for (key in duplicate_keys) {
    indices <- which(data$observation_key == key)
    sources <- unique(data$source_dataset[indices])
    if (!all(c(
      "crop_report_national",
      "crop_report_state"
    ) %in% sources)) {
      next
    }
    values <- as.numeric(data$value[indices])
    non_missing <- values[!is.na(values)]
    conflict <- if (length(non_missing) <= 1L) {
      FALSE
    } else {
      tolerance <- pmax(
        1e-8,
        1e-9 * pmax(abs(non_missing), abs(non_missing[[1]]))
      )
      any(abs(non_missing - non_missing[[1]]) > tolerance)
    }
    if (conflict) next

    candidates <- if (any(!is.na(values))) {
      indices[!is.na(values)]
    } else {
      indices
    }
    national_total <- data$geography[candidates] == "Australia" &
      data$source_dataset[candidates] == "crop_report_national"
    state_detail <- data$geography[candidates] != "Australia" &
      data$source_dataset[candidates] == "crop_report_state"
    priority <- ifelse(national_total | state_detail, 0L, 1L)
    selected <- if (any(priority == 0L)) {
      candidates[priority == 0L]
    } else {
      candidates
    }
    keep[setdiff(indices, selected)] <- FALSE
  }
  data[keep, , drop = FALSE]
}

agau_release_meta_for_asset <- function(asset, product, release,
                                        release_id = NULL,
                                        release_date = NULL) {
  local_input <- is.character(release) && length(release) >= 1L &&
    all(file.exists(release))
  if (xor(is.null(release_id), is.null(release_date))) {
    agau_abort(
      "agau_validation_error",
      "Local official release metadata requires both `release_id` and `release_date`.",
      product = product,
      remediation = paste(
        "Supply both fields, or omit both to retain a checksum-qualified",
        "local identity without claiming an official release."
      )
    )
  }
  report_number <- NA_character_
  if (!local_input) {
    release_id <- as.character(asset$release_id[[1]] %||% release)
    audited <- agau_bundled_releases()
    hit <- audited[
      audited$product == product & audited$release_id == release_id,
      , drop = FALSE
    ]
    if (nrow(hit) == 1L) {
      release_date <- hit$release_date[[1]]
      report_number <- as.character(hit$report_number[[1]])
    } else {
      token <- regmatches(
        release_id,
        regexpr("20[0-9]{2}-[0-9]{2}(?:-[0-9]{2})?", release_id)
      )
      release_date <- if (length(token) && nchar(token) == 7L) {
        as.Date(paste0(token, "-01"))
      } else if (length(token)) {
        as.Date(token)
      } else {
        as.Date(NA)
      }
    }
  }
  agau_local_meta(asset$local_path, product, asset$asset_type,
    release_id = release_id, release_date = release_date,
    report_number = report_number
  )
}

#' Read Australian Crop Report workbooks
#'
#' @param release Exact release ID, `"latest"`, a local workbook path, or a
#'   named vector of local `national` and `state` paths.
#' @param assets Workbook roles.
#' @param tables Semantic table IDs or `"all"`.
#' @param geography,crops,measures Optional post-parse filters.
#' @param view Source-faithful or canonical view.
#' @param cache_dir Cache directory.
#' @param refresh Refresh discovery and raw assets.
#' @param release_id,release_date Explicit official identity for local files.
#'   Omit both to use a checksum-qualified local identity.
#' @return A `crop_report_data` tibble.
#' @export
read_crop_report <- function(
    release = "latest", assets = c("national", "state"), tables = "all",
    geography = NULL, crops = NULL, measures = NULL,
    view = c("canonical", "reported"), cache_dir = agau_cache_dir(),
    refresh = FALSE, release_id = NULL, release_date = NULL) {
  view <- match.arg(view)
  manifest <- agau_resolve_reader_assets("crop_report", release, assets, cache_dir, refresh)
  manifest <- manifest[manifest$asset_type %in% assets, , drop = FALSE]
  if (!nrow(manifest)) {
    agau_abort(
      "agau_validation_error",
      "No requested Crop Report workbook role was resolved.",
      product = "crop_report",
      remediation = "Request an available `national` or `state` workbook."
    )
  }
  parsed <- lapply(seq_len(nrow(manifest)), function(i) {
    a <- manifest[i, , drop = FALSE]
    meta <- agau_release_meta_for_asset(
      a, "crop_report", release, release_id, release_date
    )
    physical <- if (a$asset_type == "state") {
      "crop_report_state"
    } else {
      "crop_report_national"
    }
    legacy <- (!is.na(meta$release_date) &&
      meta$release_date < as.Date("2024-01-01")) ||
      a$asset_type == "report"
    parse_sheets <- if (identical(tables, "all")) "all" else {
      if (a$asset_type == "national") {
        sub("crop_national_table_0?", "Table ", tables)
      } else {
        "all"
      }
    }
    got <- if (legacy) {
      agau_parse_legacy_cached(
        a$local_path, meta, "crop_report", physical,
        cache_dir = cache_dir, sheets = parse_sheets
      )
    } else {
      agau_parse_workbook_cached(
        a$local_path, meta, "crop_report", physical,
        cache_dir = cache_dir, sheets = parse_sheets
      )
    }
    got$source_dataset <- physical
    got$dataset <- "crop_report"
    agau_rekey_data(got)
  })
  out <- do.call(rbind, parsed)
  out <- agau_harmonise_crop_identity(out)
  class(out) <- unique(c("crop_report_data", "agau_data", class(out)))
  out <- agau_filter_data(out, tables, geography, crops, measures = measures)
  if (view == "canonical") out <- agau_canonicalise(out)
  out
}

#' Read Agricultural Commodities outlook and statistics workbooks
#'
#' @param release Exact release ID, `"latest"`, or named local workbook paths.
#' @param datasets `outlook`, `statistics`, or both.
#' @param tables Semantic table IDs or `"all"`.
#' @param sectors,commodities,concepts Optional post-parse filters.
#' @param view Source-faithful or canonical.
#' @param cache_dir Cache directory.
#' @param refresh Refresh source discovery.
#' @param release_id,release_date Explicit official identity for local files.
#'   Omit both to use a checksum-qualified local identity.
#' @return An `agricultural_commodities_data` tibble.
#' @export
read_agricultural_commodities <- function(
    release = "latest", datasets = c("outlook", "statistics"), tables = "all",
    sectors = NULL, commodities = NULL, concepts = NULL,
    view = c("canonical", "reported"), cache_dir = agau_cache_dir(),
    refresh = FALSE, release_id = NULL, release_date = NULL) {
  view <- match.arg(view)
  manifest <- agau_resolve_reader_assets(
    "agricultural_commodities", release, datasets, cache_dir, refresh
  )
  resolved_dataset <- agau_ac_dataset_role(manifest$asset_type)
  keep <- resolved_dataset %in% datasets
  manifest <- manifest[keep, , drop = FALSE]
  resolved_dataset <- resolved_dataset[keep]
  if (!nrow(manifest)) {
    agau_abort(
      "agau_validation_error",
      "No requested Agricultural Commodities dataset was resolved.",
      product = "agricultural_commodities",
      remediation = "Request an available `outlook` or `statistics` dataset."
    )
  }
  parsed <- lapply(seq_len(nrow(manifest)), function(i) {
    a <- manifest[i, , drop = FALSE]
    dataset <- if (resolved_dataset[[i]] == "statistics") {
      "commodity_statistics"
    } else {
      "commodities_outlook"
    }
    meta <- agau_release_meta_for_asset(
      a, "agricultural_commodities", release, release_id, release_date
    )
    legacy <- (!is.na(meta$release_date) &&
      meta$release_date < as.Date("2024-01-01")) ||
      a$asset_type == "report"
    if (legacy) {
      agau_parse_legacy_cached(
        a$local_path, meta, "agricultural_commodities", dataset,
        cache_dir = cache_dir
      )
    } else {
      agau_parse_workbook_cached(
        a$local_path, meta, "agricultural_commodities", dataset,
        cache_dir = cache_dir
      )
    }
  })
  out <- do.call(rbind, parsed)
  class(out) <- unique(c("agricultural_commodities_data", "agau_data", class(out)))
  out <- agau_filter_data(out, tables, commodities = commodities,
    concepts = concepts, sectors = sectors
  )
  if (view == "canonical") out <- agau_canonicalise(out)
  out
}

#' Read Australian Farm Productivity supporting data
#'
#' @param release Exact release ID, `"latest"`, or a local workbook path.
#' @param adjustment Method filter.
#' @param industries,geography Optional filters.
#' @param view Source-faithful or canonical.
#' @param cache_dir Cache directory.
#' @param refresh Refresh source discovery.
#' @param release_id,release_date Explicit official identity for a local file.
#'   Omit both to use a checksum-qualified local identity.
#' @return A `farm_productivity_data` tibble.
#' @export
read_farm_productivity <- function(
    release = "latest", adjustment = c("all", "conventional", "climate_adjusted"),
    industries = NULL, geography = NULL, view = c("canonical", "reported"),
    cache_dir = agau_cache_dir(), refresh = FALSE,
    release_id = NULL, release_date = NULL) {
  adjustment <- match.arg(adjustment)
  view <- match.arg(view)
  manifest <- agau_resolve_reader_assets(
    "farm_productivity", release, "supporting_data", cache_dir, refresh
  )
  a <- manifest[manifest$asset_type == "supporting_data", , drop = FALSE][1, ]
  meta <- agau_release_meta_for_asset(
    a, "farm_productivity", release, release_id, release_date
  )
  out <- agau_parse_workbook_cached(
    a$local_path, meta, "farm_productivity", "farm_productivity",
    cache_dir = cache_dir
  )
  if (adjustment != "all") out <- out[out$method == adjustment, , drop = FALSE]
  if (!is.null(industries)) out <- out[out$commodity %in% industries, , drop = FALSE]
  if (!is.null(geography)) out <- out[out$geography %in% geography, , drop = FALSE]
  if (view == "canonical") out <- agau_canonicalise(out)
  out
}

agau_hafd_aliases <- function() {
  list(
    commodity = c("commodity"),
    estimate_type = c("estimate_type"),
    estimate_description = c("estimate_description", "description"),
    unit = c("unit"),
    region = c("region"),
    year_issued = c("year_issued", "issue_year", "forecast_issue_year"),
    month_issued = c("month_issued", "issue_month", "forecast_issue_month"),
    year_issued_fy = c("year_issued_fy", "issue_financial_year"),
    forecast_year_fy = c(
      "forecast_year_fy", "forecast_financial_year", "financial_year",
      "target_year"
    ),
    original_forecast = c(
      "forecast_original", "original_forecast", "forecast"
    ),
    latest_actual = c("actual_latest", "latest_actual", "actual")
  )
}

agau_hafd_field_map <- function(nms) {
  nms <- agau_slug(nms)
  aliases <- agau_hafd_aliases()
  stats::setNames(vapply(names(aliases), function(field) {
    hit <- intersect(aliases[[field]], nms)
    if (length(hit)) hit[[1]] else NA_character_
  }, ""), names(aliases))
}

agau_hafd_assert_schema <- function(x, source_sheet = NA_character_) {
  field_map <- agau_hafd_field_map(names(x))
  missing <- names(field_map)[is.na(field_map)]
  if (length(missing)) {
    agau_abort(
      "agau_schema_error",
      paste(
        "Historical forecast data is missing required fields:",
        paste(missing, collapse = ", ")
      ),
      product = "historical_forecast_database",
      source_sheet = source_sheet,
      remediation = paste(
        "Use the official Historical Agricultural Forecast Database schema",
        "or update reviewed column aliases."
      )
    )
  }
  field_map
}

agau_hafd_numeric <- function(x, field, integer = FALSE) {
  raw <- trimws(as.character(x))
  normalised <- gsub(",", "", raw, fixed = TRUE)
  missing <- is.na(raw) | !nzchar(raw) |
    tolower(raw) %in% c(
      "na", "n/a", "not applicable", "not available", "unavailable",
      "nr", "not reported", "confidential", "c", "suppressed", "..",
      "-", "\u2014"
    )
  value <- suppressWarnings(as.numeric(normalised))
  invalid <- !missing & is.na(value)
  if (any(invalid)) {
    row <- which(invalid)[[1]]
    agau_abort(
      "agau_schema_error",
      sprintf(
        "Historical forecast field `%s` contains a non-numeric value at row %d.",
        field, row
      ),
      product = "historical_forecast_database",
      raw_value = raw[[row]],
      remediation = "Review the source marker or update the typed field parser."
    )
  }
  value[missing] <- NA_real_
  if (isTRUE(integer)) {
    fractional <- !is.na(value) & value != trunc(value)
    outside <- !is.na(value) &
      (value < -.Machine$integer.max | value > .Machine$integer.max)
    if (any(fractional | outside)) {
      row <- which(fractional | outside)[[1]]
      agau_abort(
        "agau_schema_error",
        sprintf(
          "Historical forecast field `%s` is not a valid integer at row %d.",
          field, row
        ),
        product = "historical_forecast_database",
        raw_value = raw[[row]],
        remediation = "Review the official issue-year field."
      )
    }
    return(as.integer(value))
  }
  value
}

#' Read the Historical Agricultural Forecast Database
#'
#' @param path Optional local CSV or workbook. When `NULL`, the official
#'   landing page is discovered and the workbook is immutably cached.
#' @param refresh Reserved for source refresh.
#' @param cache_dir Cache directory.
#' @return Normalised forecast-history observations.
#' @export
read_agau_forecast_history <- function(path = NULL, refresh = FALSE,
                                       cache_dir = agau_cache_dir()) {
  source_url <- NA_character_
  release_id <- "historical-forecast-local"
  if (is.null(path) && !isTRUE(refresh)) {
    cached <- agau_find_cached_product_asset(
      cache_dir, "historical_forecast_database", "supporting_data"
    )
    if (!is.null(cached)) {
      path <- cached$local_path[[1]]
      source_url <- cached$source_url[[1]]
      release_id <- cached$release_id[[1]]
    }
  }
  if (is.null(path)) {
    landing <- getOption(
      "readagau.hafd_landing_url",
      "https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/historical-forecasts"
    )
    release <- agau_parse_release_page(
      landing, "historical_forecast_database", landing_url = landing
    )
    urls <- release$asset_urls[[1]]
    if (!"supporting_data" %in% names(urls)) {
      agau_abort("agau_asset_missing_error",
        "Historical forecast landing page has no database workbook.",
        product = "historical_forecast_database",
        release_id = release$release_id[[1]], asset_type = "supporting_data",
        remediation = "Refresh the official landing-page asset-role profile."
      )
    }
    source_url <- urls[["supporting_data"]]
    release_id <- release$release_id[[1]]
    asset <- agau_cache_asset(
      "historical_forecast_database", release_id, "supporting_data",
      source_url, cache_dir = cache_dir, refresh = refresh
    )
    path <- asset$local_path[[1]]
  }
  if (!file.exists(path)) {
    agau_abort("agau_asset_missing_error", "Historical forecast asset does not exist.",
      product = "historical_forecast_database", asset_type = "supporting_data",
      remediation = "Supply an existing local path or use path = NULL online."
    )
  }
  if (agau_detect_format(path) %in% c("xls", "xlsx")) {
    staged <- agau_readxl_path(path); if (!identical(staged, path)) on.exit(unlink(staged), add = TRUE)
    sheets <- readxl::excel_sheets(staged)
    headers <- lapply(sheets, function(sheet) {
      suppressMessages(readxl::read_excel(staged, sheet = sheet, n_max = 0))
    })
    fingerprints <- lapply(headers, function(z) agau_hafd_field_map(names(z)))
    complete <- vapply(fingerprints, function(z) all(!is.na(z)), logical(1))
    if (sum(complete) != 1L) {
      scores <- vapply(fingerprints, function(z) sum(!is.na(z)), integer(1))
      agau_abort(
        "agau_schema_error",
        if (any(complete)) {
          "Historical forecast workbook contains multiple matching data sheets."
        } else {
          "Historical forecast workbook has no sheet with the required field fingerprint."
        },
        product = "historical_forecast_database",
        source_sheet = paste(sheets[scores == max(scores)], collapse = ", "),
        remediation = paste(
          "Select a workbook with exactly one official forecast-data sheet;",
          "do not guess from sheet position."
        )
      )
    }
    selected_sheet <- sheets[which(complete)]
    x <- suppressMessages(readxl::read_excel(staged, sheet = selected_sheet))
  } else {
    x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    selected_sheet <- "CSV"
  }
  names(x) <- agau_slug(names(x))
  field_map <- agau_hafd_assert_schema(x, selected_sheet)
  pick <- function(nm) {
    x[[field_map[[nm]]]]
  }
  out <- tibble::tibble(
    commodity = as.character(pick("commodity")),
    estimate_type = as.character(pick("estimate_type")),
    estimate_description = as.character(pick("estimate_description")),
    unit = as.character(pick("unit")),
    region = as.character(pick("region")),
    year_issued = agau_hafd_numeric(
      pick("year_issued"), "year_issued", integer = TRUE
    ),
    month_issued = as.character(pick("month_issued")),
    year_issued_fy = as.character(pick("year_issued_fy")),
    forecast_year_fy = as.character(pick("forecast_year_fy")),
    original_forecast = agau_hafd_numeric(
      pick("original_forecast"), "original_forecast"
    ),
    latest_actual = agau_hafd_numeric(
      pick("latest_actual"), "latest_actual"
    ),
    release_id = release_id,
    source_url = source_url,
    retrieved_at = as.POSIXct(file.info(path)$mtime, tz = "UTC"),
    sha256 = agau_sha256(path)
  )
  class(out) <- c("agau_forecast_history", class(out))
  out
}
