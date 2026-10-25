`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || (length(x) == 1L && is.na(x))) y else x
}

.agau_runtime <- new.env(parent = emptyenv())

agau_parser_version <- function() {
  "2026.07.29.02"
}

agau_norm_text <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("[\u2010\u2011\u2012\u2013\u2014\u2212]", "-", x)
  trimws(gsub("\\s+", " ", x))
}

agau_norm_scalar <- function(x) {
  if (length(x) != 1L || is.na(x)) return(agau_norm_text(x))
  key <- paste0("norm\u241f", enc2utf8(as.character(x)))
  cached <- .agau_runtime[[key]]
  if (!is.null(cached)) return(cached)
  value <- agau_norm_text(x)
  .agau_runtime[[key]] <- value
  value
}

agau_slug <- function(x) {
  x <- tolower(agau_norm_text(x))
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}

agau_norm_concept <- function(x) {
  if (length(x) == 1L && !is.na(x)) {
    key <- paste0("concept\u241f", enc2utf8(as.character(x)))
    cached <- .agau_runtime[[key]]
    if (!is.null(cached)) return(cached)
  } else {
    key <- NULL
  }
  y <- agau_norm_text(x)
  y <- sub("^prod\\.?$", "production", y, ignore.case = TRUE)
  y <- sub("^prod\\.?\\s+change$", "production change", y, ignore.case = TRUE)
  if (!is.null(key)) .agau_runtime[[key]] <- y
  y
}

agau_footnote_codes <- function(x, period = FALSE) {
  x <- agau_norm_text(x)
  codes <- regmatches(x, gregexpr("(?:(?<=\\s)|(?<=\\())([a-z])(?=\\)?$|[,;])", x,
    perl = TRUE, ignore.case = TRUE
  ))
  compact <- regmatches(x, regexpr("\\s+[a-k]{1,3}$", x,
    perl = TRUE, ignore.case = TRUE
  ))
  compact <- strsplit(trimws(compact), "", fixed = TRUE)
  codes <- unique(tolower(c(
    unlist(codes, use.names = FALSE),
    unlist(compact, use.names = FALSE)
  )))
  if (isTRUE(period)) codes <- setdiff(codes, c("s", "f", "z"))
  codes[nzchar(codes)]
}

agau_empty_observations <- function(n = 0L) {
  date <- as.Date(rep(NA_character_, n))
  time <- as.POSIXct(rep(NA_character_, n), tz = "UTC")
  chr <- rep(NA_character_, n)
  out <- data.frame(
    product = chr, release_id = chr, release_date = date, dataset = chr,
    source_dataset = chr, source_asset = chr, source_sheet = chr,
    table_id = chr, table_title = chr, record_role = chr,
    geography_type = chr, geography = chr, commodity = chr, concept = chr,
    period = chr, period_start = date, period_end = date, period_basis = chr,
    period_status = chr, status_source = chr, price_basis = chr,
    currency = chr, unit = chr, value = rep(NA_real_, n), raw_value = chr,
    missing_reason = chr, source_note = chr, series_id = chr,
    observation_key = chr, retrieved_at = time, sha256 = chr,
    parser_version = chr, report_number = chr, sector = chr, season = chr,
    market = chr, method = chr, source_provider = chr, rights_status = chr,
    observation_date = date, snapshot_date = date, source_cadence = chr,
    stringsAsFactors = FALSE
  )
  out$footnote_codes <- rep(list(character()), n)
  out <- out[c(
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
  )]
  tibble::as_tibble(out)
}

agau_bind_observations <- function(rows, class) {
  if (!length(rows)) {
    out <- agau_empty_observations()
  } else {
    fields <- agau_observation_schema()$field
    pull_chr <- function(nm) vapply(rows, function(z) as.character(z[[nm]] %||% NA_character_), "")
    out <- data.frame(
      product = pull_chr("product"), release_id = pull_chr("release_id"),
      release_date = as.Date(pull_chr("release_date")), dataset = pull_chr("dataset"),
      source_dataset = pull_chr("source_dataset"), source_asset = pull_chr("source_asset"),
      source_sheet = pull_chr("source_sheet"), table_id = pull_chr("table_id"),
      table_title = pull_chr("table_title"), record_role = pull_chr("record_role"),
      geography_type = pull_chr("geography_type"), geography = pull_chr("geography"),
      commodity = pull_chr("commodity"), concept = pull_chr("concept"),
      period = pull_chr("period"), period_start = as.Date(pull_chr("period_start")),
      period_end = as.Date(pull_chr("period_end")), period_basis = pull_chr("period_basis"),
      period_status = pull_chr("period_status"), status_source = pull_chr("status_source"),
      price_basis = pull_chr("price_basis"), currency = pull_chr("currency"),
      unit = pull_chr("unit"),
      value = vapply(rows, function(z) as.numeric(z$value), 0),
      raw_value = pull_chr("raw_value"), missing_reason = pull_chr("missing_reason"),
      source_note = pull_chr("source_note"), series_id = pull_chr("series_id"),
      observation_key = pull_chr("observation_key"),
      retrieved_at = as.POSIXct(pull_chr("retrieved_at"), tz = "UTC"),
      sha256 = pull_chr("sha256"), parser_version = pull_chr("parser_version"),
      report_number = pull_chr("report_number"), sector = pull_chr("sector"),
      season = pull_chr("season"), market = pull_chr("market"), method = pull_chr("method"),
      source_provider = pull_chr("source_provider"), rights_status = pull_chr("rights_status"),
      observation_date = as.Date(pull_chr("observation_date")),
      snapshot_date = as.Date(pull_chr("snapshot_date")),
      source_cadence = pull_chr("source_cadence"), stringsAsFactors = FALSE
    )
    out$footnote_codes <- lapply(rows, function(z) z$footnote_codes %||% character())
    semantic <- out$series_id
    unique_semantic <- unique(semantic)
    map <- stats::setNames(vapply(unique_semantic, function(text) {
      paste0("agau_", substr(digest::digest(text, algo = "sha256", serialize = FALSE), 1L, 24L))
    }, ""), unique_semantic)
    out$series_id <- unname(map[semantic])
    out$observation_key <- paste(out$series_id, out$period, sep = "::")
    out <- out[fields]
    out <- tibble::as_tibble(out)
  }
  class(out) <- unique(c(class, "agau_data", class(out)))
  out
}

agau_period_like <- function(x, short_quarter = FALSE) {
  x <- agau_norm_text(x)
  full <- grepl(
    paste0(
      "^(?:[0-9]{4}-(?:[0-9]{2}|[0-9]{4})|",
      "(?:19|20)[0-9]{2}|",
      "(?:19|20)[0-9]{2}\\s*Q[1-4]|",
      "Q[1-4]\\s*(?:19|20)[0-9]{2}|",
      "(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)",
      "[- ](?:[0-9]{2}|(?:19|20)[0-9]{2}))\\s*[a-z]?$"
    ),
    x, ignore.case = TRUE
  )
  if (isTRUE(short_quarter)) full | grepl("^Q[1-4]$", x, ignore.case = TRUE) else full
}

agau_period_bounds <- function(period, basis = NULL) {
  p <- agau_norm_text(period)
  p <- agau_status(p)$period
  start <- end <- as.Date(rep(NA_character_, length(p)))
  inferred <- rep("published_period", length(p))
  financial_year_match <- regexec(
    "^([0-9]{4})-([0-9]{2}|[0-9]{4})$",
    p
  )
  financial_year_parts <- regmatches(p, financial_year_match)
  fy <- lengths(financial_year_parts) == 3L
  range_summary <- grepl(
    "^[0-9]{4}-(?:[0-9]{2}|[0-9]{4})\\s+(?:to|through)\\s+[0-9]{4}-(?:[0-9]{2}|[0-9]{4})$",
    p,
    ignore.case = TRUE
  )
  named_summary <- grepl(
    "\\b(?:average|index)\\b",
    p,
    ignore.case = TRUE
  )
  explicit_summary <- range_summary | named_summary
  numeric_multitoken <- grepl(
    "^[0-9]+(?:[[:punct:][:space:]]+[0-9]+)+$",
    p
  )
  incomplete_numeric <- grepl(
    "^(?:[0-9]+[[:punct:][:space:]]+|[[:punct:][:space:]]+[0-9]+)$",
    p
  )
  concatenated_candidate <- grepl("^[0-9]{5,}$", p)
  contaminated_year_prefix <- grepl(
    "^[0-9]{4}\\s*[[:punct:]]+.*$",
    p
  )
  simple_range_candidate <- !explicit_summary & (
    numeric_multitoken |
      incomplete_numeric |
      concatenated_candidate |
      contaminated_year_prefix
  )
  malformed_range <- simple_range_candidate & !fy
  if (any(malformed_range)) {
    agau_abort(
      "agau_validation_error",
      paste(
        "Malformed financial-year label:",
        paste(unique(p[malformed_range]), collapse = ", ")
      ),
      remediation = paste(
        "Use YYYY-YY or YYYY-YYYY with an end year exactly one year",
        "after the start year."
      )
    )
  }
  if (any(fy)) {
    y <- vapply(financial_year_parts[fy], function(parts) {
      as.integer(parts[[2]])
    }, integer(1))
    end_token <- vapply(financial_year_parts[fy], `[[`, character(1), 3L)
    expected_end <- y + 1L
    if (any(expected_end > 9999L)) {
      agau_abort(
        "agau_validation_error",
        paste(
          "Financial-year label exceeds the supported four-digit Date range:",
          paste(unique(p[which(fy)[expected_end > 9999L]]), collapse = ", ")
        ),
        remediation = "Use a four-digit start year from 0000 through 9998."
      )
    }
    coherent <- ifelse(
      nchar(end_token) == 2L,
      end_token == sprintf("%02d", expected_end %% 100L),
      end_token == sprintf("%04d", expected_end)
    )
    if (any(!coherent)) {
      invalid_periods <- p[which(fy)[!coherent]]
      agau_abort(
        "agau_validation_error",
        paste(
          "Incoherent financial-year label:",
          paste(unique(invalid_periods), collapse = ", ")
        ),
        remediation = paste(
          "Use YYYY-YY or YYYY-YYYY with an end year exactly one year",
          "after the start year."
        )
      )
    }
    start[fy] <- as.Date(sprintf("%04d-07-01", y))
    end[fy] <- as.Date(sprintf("%04d-06-30", expected_end))
    inferred[fy] <- "financial_year"
  }
  cy <- grepl("^(?:19|20)[0-9]{2}$", p)
  if (any(cy)) {
    y <- as.integer(p[cy])
    start[cy] <- as.Date(sprintf("%04d-01-01", y))
    end[cy] <- as.Date(sprintf("%04d-12-31", y))
    inferred[cy] <- "calendar_year"
  }
  month_match <- regexec(
    paste0(
      "^",
      "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)",
      "[- ]([0-9]{2}|(?:19|20)[0-9]{2})$"
    ),
    p,
    ignore.case = TRUE
  )
  month_parts <- regmatches(p, month_match)
  for (i in which(lengths(month_parts) == 3L)) {
    month <- match(
      tolower(month_parts[[i]][2]),
      tolower(month.abb)
    )
    year_token <- month_parts[[i]][3]
    year <- as.integer(year_token)
    if (nchar(year_token) == 2L) {
      year <- if (year >= 70L) 1900L + year else 2000L + year
    }
    start[i] <- as.Date(sprintf("%04d-%02d-01", year, month))
    end[i] <- seq(start[i], by = "1 month", length.out = 2L)[2] - 1
    inferred[i] <- "month"
  }
  q <- regexec("^((?:19|20)[0-9]{2})\\s*Q([1-4])$", p, ignore.case = TRUE)
  qm <- regmatches(p, q)
  for (i in which(lengths(qm) == 3L)) {
    y <- as.integer(qm[[i]][2]); qq <- as.integer(qm[[i]][3])
    m <- (qq - 1L) * 3L + 1L
    start[i] <- as.Date(sprintf("%04d-%02d-01", y, m))
    end[i] <- seq(start[i], by = "3 months", length.out = 2L)[2] - 1
    inferred[i] <- "quarter"
  }
  if (!is.null(basis)) inferred[] <- basis
  data.frame(period_start = start, period_end = end, period_basis = inferred)
}

agau_currency <- function(unit) {
  u <- agau_norm_text(unit)
  ifelse(grepl("A\\$", u), "AUD",
    ifelse(grepl("US\\$", u), "USD", "not_applicable")
  )
}

agau_price_basis <- function(label, unit) {
  x <- tolower(paste(label, unit))
  if (grepl("\\breal\\b", x)) "real" else if (grepl("price|\\$/|unit value", x)) "nominal" else if (grepl("index", x)) "index_basis" else "not_applicable"
}

agau_geography_type <- function(x) {
  states <- c(
    "New South Wales", "Victoria", "Queensland", "South Australia",
    "Western Australia", "Tasmania", "Northern Territory"
  )
  ifelse(x %in% c("Australia", "All Australia"), "country",
    ifelse(x %in% states, "state",
      ifelse(grepl("region|grdc|dairy|pastoral|rainfall|beef", x, ignore.case = TRUE), "region", "not_applicable")
    )
  )
}

agau_semantic_text <- function(row) {
  dims <- c(
    "product", "dataset", "geography_type", "geography", "sector", "season",
    "commodity", "concept", "market", "unit", "period_basis", "price_basis",
    "currency", "method"
  )
  paste(vapply(dims, function(nm) as.character(row[[nm]] %||% ""), ""), collapse = "\u241f")
}

agau_make_key <- function(row) {
  text <- agau_semantic_text(row)
  paste0("agau_", substr(digest::digest(text, algo = "sha256", serialize = FALSE), 1L, 24L))
}

agau_rekey_data <- function(data) {
  dims <- c(
    "product", "dataset", "geography_type", "geography", "sector", "season",
    "commodity", "concept", "market", "unit", "period_basis", "price_basis",
    "currency", "method"
  )
  pieces <- lapply(data[dims], function(x) {
    x <- as.character(x); x[is.na(x)] <- ""; x
  })
  semantic <- do.call(paste, c(pieces, sep = "\u241f"))
  unique_semantic <- unique(semantic)
  map <- stats::setNames(vapply(unique_semantic, function(text) {
    paste0("agau_", substr(digest::digest(text, algo = "sha256", serialize = FALSE), 1L, 24L))
  }, ""), unique_semantic)
  data$series_id <- unname(map[semantic])
  data$observation_key <- paste(data$series_id, data$period, sep = "::")
  data
}

agau_observation_row <- function(meta, sheet, table_id, title, geography,
                                 commodity, concept, period, unit, raw_value,
                                 dataset = meta$dataset, source_dataset = dataset,
                                 sector = "not_applicable", season = "not_applicable",
                                 market = "not_applicable", method = "not_applicable",
                                 price_basis = NULL, period_basis = NULL,
                                 currency = NULL,
                                 source_note = "", footnote_codes = character(),
                                 record_role = "supporting") {
  unit <- agau_norm_scalar(unit)
  if (!nzchar(unit)) unit <- "not_stated"
  raw <- if (length(raw_value)) as.character(raw_value) else NA_character_
  numeric_raw <- gsub(",", "", raw, fixed = TRUE)
  numeric_raw <- gsub("(?<=\\d)\\s+(?=\\d)", "", numeric_raw, perl = TRUE)
  value <- suppressWarnings(as.numeric(numeric_raw))
  if (!is.na(value)) {
    missing <- NA_character_
  } else {
    token <- tolower(trimws(raw))
    missing <- if (is.na(raw) || !nzchar(token)) "blank" else if (token == "na") {
      "provider_na"
    } else if (token %in% c("n/a", "not applicable")) {
      "not_applicable"
    } else if (token %in% c("not available", "unavailable", "nr", "not reported")) {
      "unavailable"
    } else if (token %in% c("confidential", "c")) {
      "confidential"
    } else if (token %in% c("suppressed", "..", "-", "\u2014")) {
      "suppressed"
    } else {
      agau_abort("agau_validation_error",
        "Unexplained non-empty value in a numeric region.", raw_value = raw,
        remediation = "Add an explicit source marker or repair the parser."
      )
    }
  }
  clean_period <- agau_norm_scalar(period)
  has_suffix <- grepl("[sfz]\\s*$", clean_period, ignore.case = TRUE)
  suffix <- if (has_suffix) tolower(sub(".*([sfz])\\s*$", "\\1", clean_period)) else ""
  status <- if (suffix == "s") "estimate" else if (suffix == "f") "forecast" else if (suffix == "z") "projection" else "published-unclassified"
  clean_period <- if (has_suffix) trimws(sub("[sfz]\\s*$", "", clean_period, ignore.case = TRUE)) else clean_period
  if (!has_suffix && grepl("^(?:[0-9]{4}-(?:[0-9]{2}|[0-9]{4})|(?:19|20)[0-9]{2})\\s+[a-er-y]$", clean_period, ignore.case = TRUE)) {
    clean_period <- sub("\\s+[a-er-y]$", "", clean_period, ignore.case = TRUE)
  }
  bounds_key <- paste(clean_period, period_basis %||% "", sep = "\u241f")
  bounds <- .agau_runtime[[bounds_key]]
  if (is.null(bounds)) {
    bounds <- agau_period_bounds(clean_period, period_basis)
    .agau_runtime[[bounds_key]] <- bounds
  }
  geo <- agau_norm_scalar(geography %||% "not_applicable")
  row <- list(
    product = meta$product, release_id = meta$release_id,
    release_date = as.Date(meta$release_date), dataset = dataset,
    source_dataset = source_dataset, source_asset = meta$source_asset,
    source_sheet = sheet, table_id = table_id, table_title = title,
    record_role = record_role, geography_type = agau_geography_type(geo),
    geography = geo, commodity = agau_norm_scalar(commodity),
    concept = agau_norm_concept(concept), period = clean_period,
    period_start = bounds$period_start, period_end = bounds$period_end,
    period_basis = bounds$period_basis, period_status = status,
    status_source = if (has_suffix) "suffix" else "unclassified",
    price_basis = price_basis %||% agau_price_basis(concept, unit),
    currency = currency %||% agau_currency(unit),
    unit = unit, value = value,
    raw_value = raw, missing_reason = missing,
    footnote_codes = unique(as.character(footnote_codes)),
    source_note = source_note, series_id = NA_character_,
    observation_key = NA_character_, retrieved_at = as.POSIXct(meta$retrieved_at, tz = "UTC"),
    sha256 = meta$sha256, parser_version = agau_parser_version(),
    report_number = meta$report_number %||% NA_character_,
    sector = agau_norm_scalar(sector), season = agau_norm_scalar(season),
    market = agau_norm_scalar(market), method = agau_norm_scalar(method),
    source_provider = "ABARES", rights_status = "not_applicable",
    observation_date = as.Date(NA), snapshot_date = as.Date(NA),
    source_cadence = "not_applicable"
  )
  row$series_id <- agau_semantic_text(row)
  row$observation_key <- NA_character_
  row
}
