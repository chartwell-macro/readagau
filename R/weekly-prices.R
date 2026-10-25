agau_weekly_series <- function() {
  path <- system.file("config", "weekly-series.csv", package = "readagau")
  if (!nzchar(path)) {
    agau_abort(
      "agau_schema_error",
      "The installed Weekly commodity prices series registry is missing.",
      remediation = "Reinstall readagau from a complete source tree."
    )
  }
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  out$pattern <- gsub("\\\\\\\\", "\\\\", out$pattern)
  out
}

agau_weekly_match_series <- function(label, source_series_id = NULL) {
  registry <- agau_weekly_series()
  if (!is.null(source_series_id)) {
    hit <- which(registry$source_series_id == source_series_id)
  } else {
    clean <- agau_norm_text(label)
    hit <- which(vapply(registry$pattern, function(pattern) {
      grepl(pattern, clean, ignore.case = TRUE, perl = TRUE)
    }, logical(1)))
  }
  if (length(hit) != 1L) {
    agau_abort(
      "agau_table_parse_error",
      if (length(hit)) {
        paste("Weekly indicator matched multiple canonical identities:", label)
      } else {
        paste("Weekly indicator has no canonical identity:", label)
      },
      remediation = "Review the official label and update weekly-series.csv."
    )
  }
  registry[hit, , drop = FALSE]
}

agau_weekly_release_date <- function(path, text = NULL) {
  issue_date <- as.Date(NA_character_)
  if (!is.null(text)) {
    text <- agau_norm_text(gsub("\u00a0", " ", text, fixed = TRUE))
    issue <- regmatches(
      text,
      regexec(
        "\\bNo\\.\\s*[0-9]+\\s*/\\s*(20[0-9]{2})\\s+([0-9]{1,2}\\s+[A-Za-z]+\\s+20[0-9]{2})",
        text, ignore.case = TRUE, perl = TRUE
      )
    )[[1]]
    if (length(issue) == 3L) {
      issue_date <- agau_parse_english_date(issue[[3]])
      if (is.na(issue_date) ||
          !identical(format(issue_date, "%Y"), issue[[2]])) {
        agau_abort(
          "agau_table_parse_error",
          "Weekly issue number and cover date have inconsistent years.",
          remediation = "Audit the exact official report identity."
        )
      }
    }
  }
  file_date <- regmatches(
    basename(path),
    regexpr("20[0-9]{2}-?[0-9]{2}-?[0-9]{2}", basename(path))
  )
  if (length(file_date) && nzchar(file_date)) {
    file_date <- as.Date(gsub("-", "", file_date), "%Y%m%d")
  } else {
    file_date <- as.Date(NA_character_)
  }
  if (!is.na(file_date) && identical(file_date, issue_date)) {
    return(file_date)
  }
  if (!is.na(file_date) && !is.null(text)) {
    file_label <- agau_english_day_month_year(file_date)
    publication <- paste0(
      "(?:ABARES )?Weekly Australian Climate, Water and Agricultural ",
      "Update[^0-9]+", file_label
    )
    if (grepl(publication, text, ignore.case = TRUE, perl = TRUE)) {
      return(file_date)
    }
  }
  if (!is.na(issue_date)) return(issue_date)
  if (!is.na(file_date)) return(file_date)
  text <- text %||% agau_norm_text(
    paste(readLines(path, warn = FALSE), collapse = " ")
  )
  patterns <- c(
    "^([0-9]{1,2} [A-Za-z]+ 20[0-9]{2})",
    "Weekly Australian Climate, Water and Agricultural Update[^0-9]+([0-9]{1,2} [A-Za-z]+ 20[0-9]{2})",
    "ABARES Weekly Australian Climate, Water and Agricultural Update[^0-9]+([0-9]{1,2} [A-Za-z]+ 20[0-9]{2})",
    "Current indicators[^0-9]+([0-9]{1,2} [A-Za-z]+ 20[0-9]{2})"
  )
  for (pattern in patterns) {
    hit <- regmatches(text, regexec(pattern, text, ignore.case = TRUE, perl = TRUE))[[1]]
    if (length(hit) == 2L) {
      got <- agau_parse_english_date(hit[[2]])
      if (!is.na(got)) return(got)
    }
  }
  agau_abort(
    "agau_table_parse_error",
    "Weekly snapshot has no exact publication date.",
    remediation = "Use an official dated report, page snapshot or chart page."
  )
}

agau_weekly_observation_date <- function(label, snapshot_date) {
  cache_key <- if (
    length(label) == 1L && !is.na(label) &&
      length(snapshot_date) == 1L && !is.na(snapshot_date)
  ) {
    paste0(
      "weekly-observation-date\u241f",
      as.character(snapshot_date), "\u241f", enc2utf8(as.character(label))
    )
  } else {
    NULL
  }
  if (!is.null(cache_key)) {
    cached <- .agau_runtime[[cache_key]]
    if (!is.null(cached)) return(cached[[1L]])
  }
  label <- agau_norm_text(label)
  if (grepl("^20[0-9]{2}-[0-9]{2}-[0-9]{2}$", label)) {
    out <- as.Date(label)
  } else if (grepl(
    "^[0-3]?[0-9]-[A-Za-z]{3}-(?:[0-9]{2}|20[0-9]{2})$", label,
    perl = TRUE
  )) {
    out <- agau_parse_english_date(label)
  } else {
    out <- agau_parse_english_date(paste(format(snapshot_date, "%Y"), label))
    if (!is.na(out) && out > snapshot_date) {
      out <- agau_parse_english_date(
        paste(as.integer(format(snapshot_date, "%Y")) - 1L, label)
      )
    }
  }
  if (is.na(out) || out > snapshot_date) {
    agau_abort(
      "agau_table_parse_error",
      paste("Invalid Weekly observation date:", label),
      remediation = "Review the report date and week-average label."
    )
  }
  if (!is.null(cache_key)) .agau_runtime[[cache_key]] <- list(out)
  out
}

agau_weekly_value <- function(raw) {
  if (!length(raw) || is.na(raw) || !nzchar(agau_norm_text(raw))) {
    return(list(value = NA_real_, missing_reason = "provider_na"))
  }
  clean <- gsub("[,%[:space:]]", "", agau_norm_text(raw))
  lower <- tolower(clean)
  if (lower %in% c("na", "n/a", "#n/a", "notavailable", "-", "\u2014")) {
    return(list(value = NA_real_, missing_reason = "provider_na"))
  }
  if (lower %in% c("#div/0!", "#value!", "#ref!")) {
    return(list(value = NA_real_, missing_reason = "provider_error"))
  }
  missing_tokens <- strsplit(tolower(agau_norm_text(raw)), "\\s+")[[1]]
  if (length(missing_tokens) > 1L &&
      all(missing_tokens %in% c("na", "n/a", "#n/a", "-", "\u2014"))) {
    return(list(value = NA_real_, missing_reason = "provider_na"))
  }
  if (grepl("^[<>][-+]?[0-9.]+$", clean)) {
    return(list(value = NA_real_, missing_reason = "bounded_value"))
  }
  value <- suppressWarnings(as.numeric(clean))
  if (is.na(value)) {
    agau_abort(
      "agau_table_parse_error",
      paste("Weekly numeric cell is not recognised:", raw),
      raw_value = raw,
      remediation = "Add the provider token to the explicit missing-value grammar."
    )
  }
  list(value = value, missing_reason = NA_character_)
}

agau_weekly_currency <- function(unit) {
  if (grepl("US\\$|USc", unit)) "USD" else if (
    grepl("A\\$|Ac|\\$/head", unit)
  ) "AUD" else "not_applicable"
}

agau_weekly_row <- function(config, release_date, observation_date, raw_unit,
                            raw_value, measure, source_asset, source_sheet,
                            sha256, retrieved_at, chart = FALSE) {
  measures <- data.frame(
    measure = c(
      "latest_price", "previous_week", "weekly_change",
      "price_12_months_ago", "annual_change"
    ),
    concept = c(
      "price", "previous-week price", "weekly price change",
      "price 12 months ago", "annual price change"
    ),
    percent = c(FALSE, FALSE, TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  spec <- measures[measures$measure == measure, , drop = FALSE]
  if (!nrow(spec)) {
    agau_abort(
      "agau_schema_error",
      paste("Unknown Weekly measure:", measure),
      remediation = "Use one of the documented Weekly measure IDs."
    )
  }
  parsed <- agau_weekly_value(raw_value)
  unit <- if (spec$percent) {
    "percent"
  } else if (config$source_series_id == "A1") {
    "exchange_rate_ratio"
  } else {
    agau_norm_text(raw_unit)
  }
  release_id <- paste0(
    if (isTRUE(chart)) "weekly-charts-" else "weekly-prices-",
    format(release_date, "%Y-%m-%d")
  )
  period <- format(observation_date, "%Y-%m-%d")
  source_note <- paste0(
    if (isTRUE(chart)) {
      "Value and observation date transcribed from the official chart image alt text."
    } else {
      "Value transcribed from the official Weekly price table."
    },
    " Published unit: ", agau_norm_text(raw_unit), "."
  )
  row <- list(
    product = "weekly_commodity_prices",
    release_id = release_id,
    release_date = as.Date(release_date),
    dataset = "weekly_prices",
    source_dataset = if (isTRUE(chart)) "weekly_price_charts" else "weekly_price_table",
    source_asset = source_asset,
    source_sheet = source_sheet,
    table_id = paste0("weekly_", config$source_series_id),
    table_title = config$indicator,
    record_role = measure,
    geography_type = "not_applicable",
    geography = "not_applicable",
    commodity = config$commodity,
    concept = if (isTRUE(chart) && config$sector == "horticulture") {
      "price index"
    } else {
      spec$concept
    },
    period = period,
    period_start = as.Date(observation_date),
    period_end = as.Date(observation_date),
    period_basis = "day",
    period_status = "historical",
    status_source = if (isTRUE(chart)) "official_alt_text" else "published_table",
    price_basis = if (spec$percent) {
      "not_applicable"
    } else if (config$sector == "horticulture") {
      "index_basis"
    } else {
      "spot"
    },
    currency = if (spec$percent) "not_applicable" else agau_weekly_currency(raw_unit),
    unit = unit,
    value = parsed$value,
    raw_value = agau_norm_text(raw_value),
    missing_reason = parsed$missing_reason,
    footnote_codes = character(),
    source_note = source_note,
    series_id = paste(
      "weekly_commodity_prices", config$source_series_id, spec$concept,
      unit, sep = "\u241f"
    ),
    observation_key = NA_character_,
    retrieved_at = as.POSIXct(retrieved_at, tz = "UTC"),
    sha256 = sha256,
    parser_version = agau_parser_version(),
    report_number = NA_character_,
    sector = config$sector,
    season = "not_applicable",
    market = paste0(config$source_series_id, ": ", config$market),
    method = "not_applicable",
    source_provider = config$source_provider,
    rights_status = "not_applicable",
    observation_date = as.Date(observation_date),
    snapshot_date = as.Date(release_date),
    source_cadence = config$source_cadence
  )
  row
}

agau_weekly_table_rows <- function(records, release_date, source_asset,
                                   source_sheet, sha256, retrieved_at,
                                   measures) {
  expected <- c(
    "latest_price", "previous_week", "weekly_change",
    "price_12_months_ago", "annual_change"
  )
  rows <- list()
  for (i in seq_len(nrow(records))) {
    config <- agau_weekly_match_series(records$indicator[[i]])
    observation_date <- agau_weekly_observation_date(
      records$week_average[[i]], release_date
    )
    values <- unname(unlist(records[i, expected], use.names = FALSE))
    for (j in seq_along(expected)) {
      if (!expected[[j]] %in% measures) next
      rows[[length(rows) + 1L]] <- tryCatch(
        agau_weekly_row(
          config, release_date, observation_date, records$unit[[i]],
          values[[j]], expected[[j]], source_asset, source_sheet, sha256,
          retrieved_at
        ),
        agau_table_parse_error = function(e) {
          agau_abort(
            "agau_table_parse_error",
            paste(
              conditionMessage(e), "Indicator:", records$indicator[[i]],
              "Measure:", expected[[j]]
            ),
            remediation = e$remediation %||%
              "Audit the exact official Weekly table row."
          )
        }
      )
    }
  }
  agau_bind_observations(rows, "agau_weekly_prices")
}

agau_parse_weekly_html_table <- function(path, measures) {
  doc <- tryCatch(rvest::read_html(path), error = function(e) {
    agau_abort(
      "agau_table_parse_error",
      conditionMessage(e),
      remediation = "Use an immutable official Weekly HTML snapshot."
    )
  })
  tables <- rvest::html_elements(doc, "table")
  selected <- NULL
  for (table in tables) {
    candidate <- rvest::html_table(table, fill = TRUE, trim = TRUE)
    headers <- tolower(agau_norm_text(names(candidate)))
    if (all(c("indicator", "week average", "unit", "latest price") %in% headers)) {
      selected <- candidate
      break
    }
  }
  if (is.null(selected)) return(NULL)
  names(selected) <- gsub("[^a-z0-9]+", "_", tolower(names(selected)))
  required <- c(
    "indicator", "week_average", "unit", "latest_price", "previous_week",
    "weekly_change", "price_12_months_ago", "annual_change"
  )
  if (!identical(names(selected), required)) {
    agau_abort(
      "agau_schema_error",
      paste("Weekly HTML columns changed:", paste(names(selected), collapse = ", ")),
      remediation = "Audit the official table and update the exact schema profile."
    )
  }
  group_row <- vapply(seq_len(nrow(selected)), function(i) {
    values <- agau_norm_text(unlist(selected[i, ], use.names = FALSE))
    length(unique(values)) == 1L
  }, logical(1))
  records <- as.data.frame(selected[!group_row, , drop = FALSE])
  if (nrow(records) != 22L) {
    agau_abort(
      "agau_table_parse_error",
      paste("Expected 22 current Weekly indicators; found", nrow(records)),
      remediation = "Audit the current official table before admitting its values."
    )
  }
  text <- rvest::html_text2(doc)
  release_date <- agau_weekly_release_date(path, text)
  agau_weekly_table_rows(
    records, release_date, basename(path), "HTML current indicators",
    agau_sha256(path), as.POSIXct(file.info(path)$mtime, tz = "UTC"), measures
  )
}

agau_parse_weekly_docx <- function(path, measures) {
  directory <- tempfile("agau-weekly-docx-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  extracted <- tryCatch(
    utils::unzip(path, files = "word/document.xml", exdir = directory),
    error = function(e) character()
  )
  document_path <- file.path(directory, "word", "document.xml")
  if (!length(extracted) || !file.exists(document_path)) {
    agau_abort(
      "agau_asset_format_error",
      "Weekly Word report has no OOXML document body.",
      remediation = "Use the exact official DOCX report asset."
    )
  }
  document <- tryCatch(xml2::read_xml(document_path), error = function(e) {
    agau_abort(
      "agau_table_parse_error",
      conditionMessage(e),
      remediation = "Verify the official Word report bytes."
    )
  })
  namespace <- xml2::xml_ns(document)
  tables <- xml2::xml_find_all(document, ".//w:tbl", namespace)
  records <- NULL
  for (table in tables) {
    rows <- xml2::xml_find_all(table, "./w:tr", namespace)
    if (!length(rows)) next
    cell_text <- function(row) {
      cells <- xml2::xml_find_all(row, "./w:tc", namespace)
      vapply(cells, function(cell) {
        agau_norm_text(paste(
          xml2::xml_text(xml2::xml_find_all(cell, ".//w:t", namespace)),
          collapse = " "
        ))
      }, "")
    }
    header <- tolower(cell_text(rows[[1]]))
    expected_header <- c(
      "indicator", "week average", "unit", "latest price",
      "previous week", "weekly change", "price 12 months ago",
      "annual change"
    )
    if (length(header) != length(expected_header) ||
        !identical(header[-2L], expected_header[-2L]) ||
        !header[[2]] %in% c("week average", "week ended")) next
    body <- lapply(rows[-1L], cell_text)
    body <- body[lengths(body) == 8L]
    body <- body[vapply(body, function(row) {
      grepl(
        "^[0-3]?[0-9]-[[:space:]]*[A-Za-z]{3}(?:-(?:[0-9]{2}|20[0-9]{2}))?$",
        row[[2]], perl = TRUE
      ) &&
        nzchar(row[[3]])
    }, logical(1))]
    if (!length(body)) next
    matrix <- do.call(rbind, body)
    records <- data.frame(
      indicator = matrix[, 1],
      week_average = matrix[, 2],
      unit = matrix[, 3],
      latest_price = matrix[, 4],
      previous_week = matrix[, 5],
      weekly_change = matrix[, 6],
      price_12_months_ago = matrix[, 7],
      annual_change = matrix[, 8],
      stringsAsFactors = FALSE
    )
    break
  }
  if (is.null(records) || nrow(records) < 15L || nrow(records) > 35L) {
    agau_abort(
      "agau_table_parse_error",
      paste(
        "Expected 15 to 35 complete Weekly Word-report indicators; found",
        if (is.null(records)) 0L else nrow(records)
      ),
      remediation = "Audit the exact official Word table before admission."
    )
  }
  records$week_average <- gsub(
    "-[[:space:]]+", "-", records$week_average, perl = TRUE
  )
  records$source_series_id <- vapply(
    records$indicator,
    function(label) agau_weekly_match_series(label)$source_series_id,
    ""
  )
  if (anyDuplicated(records$source_series_id)) {
    agau_abort(
      "agau_schema_error",
      "Weekly Word report repeats a canonical series identity.",
      remediation = "Audit the exact official Word table before admission."
    )
  }
  paragraphs <- xml2::xml_find_all(document, ".//w:p", namespace)
  document_text <- paste(vapply(paragraphs, function(paragraph) {
    paste(
      xml2::xml_text(
        xml2::xml_find_all(paragraph, ".//w:t", namespace)
      ),
      collapse = ""
    )
  }, ""), collapse = " ")
  release_date <- agau_weekly_release_date(
    "", document_text
  )
  agau_weekly_table_rows(
    records, release_date, basename(path), "DOCX commodities table",
    agau_sha256(path), as.POSIXct(file.info(path)$mtime, tz = "UTC"),
    measures
  )
}

agau_parse_weekly_chart_html <- function(path) {
  doc <- tryCatch(rvest::read_html(path), error = function(e) return(NULL))
  images <- rvest::html_elements(doc, "figure img[src]")
  if (!length(images)) return(NULL)
  src <- rvest::html_attr(images, "src")
  alt <- agau_norm_text(rvest::html_attr(images, "alt"))
  chart_id <- vapply(src, function(x) {
    hit <- regmatches(x, regexec("chart_([AH][0-9]+)_20[0-9]{2}-[0-9]{2}-[0-9]{2}", x))[[1]]
    if (length(hit) == 2L) hit[[2]] else NA_character_
  }, "")
  keep <- !is.na(chart_id)
  if (!any(keep)) return(NULL)
  rows <- list()
  for (i in which(keep)) {
    hit <- regmatches(
      alt[[i]],
      regexec(
        "prices for (.+?) from .+?\\. The price on ([0-9]{1,2} [A-Za-z]+ 20[0-9]{2}) was (-?[0-9,.]+) (.+?)\\.",
        alt[[i]], ignore.case = TRUE, perl = TRUE
      )
    )[[1]]
    if (length(hit) != 5L) {
      agau_abort(
        "agau_table_parse_error",
        paste("Chart alt text changed for", chart_id[[i]]),
        remediation = "Audit the official accessible description."
      )
    }
    snapshot_hit <- regmatches(
      src[[i]], regexpr("20[0-9]{2}-[0-9]{2}-[0-9]{2}", src[[i]])
    )
    snapshot_date <- as.Date(snapshot_hit)
    observation_date <- as.Date(hit[[3]], "%d %B %Y")
    if (is.na(snapshot_date) || is.na(observation_date) ||
        observation_date > snapshot_date) {
      agau_abort(
        "agau_table_parse_error",
        paste("Chart dates are incoherent for", chart_id[[i]]),
        remediation = "Audit the dated image and accessible description."
      )
    }
    config <- agau_weekly_match_series(hit[[2]], chart_id[[i]])
    rows[[length(rows) + 1L]] <- agau_weekly_row(
      config, snapshot_date, observation_date, hit[[5]], hit[[4]],
      "latest_price", basename(path), "PNG chart alt text",
      agau_sha256(path), as.POSIXct(file.info(path)$mtime, tz = "UTC"),
      chart = TRUE
    )
  }
  ids <- vapply(rows, function(x) x$table_id, "")
  if (anyDuplicated(ids)) {
    agau_abort(
      "agau_schema_error",
      "A chart page repeats a canonical Weekly chart ID.",
      remediation = "Audit the official chart markup."
    )
  }
  agau_bind_observations(rows, "agau_weekly_prices")
}

agau_parse_weekly_text <- function(path, source_asset = basename(path),
                                   sha256 = agau_sha256(path),
                                   retrieved_at = file.info(path)$mtime,
                                   measures = c(
                                     "latest_price", "previous_week",
                                     "weekly_change", "price_12_months_ago",
                                     "annual_change"
                                   )) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  release_date <- agau_weekly_release_date(
    source_asset, paste(lines, collapse = " ")
  )
  price_unit <- "^(?:US\\$/t|USc/lb|A\\$/t|Ac/kg(?: clean| cwt| lwt)?|\\$/head|A\\$/US\\$|US\\$/A\\$)$"
  records <- list()
  header_starts <- NULL
  data_bounds <- NULL
  for (line_number in seq_along(lines)) {
    line <- lines[[line_number]]
    if (grepl("Latest", line, ignore.case = TRUE)) {
      header <- lines[line_number:min(length(lines), line_number + 4L)]
      data_bounds <- NULL
      position <- function(pattern) {
        hits <- vapply(header, function(x) {
          regexpr(pattern, x, ignore.case = TRUE, perl = TRUE)[[1]]
        }, integer(1))
        hits <- hits[hits > 0L]
        if (length(hits)) min(hits) else NA_integer_
      }
      candidate <- c(
        latest_price = position("\\bLatest\\b"),
        previous_week = position("\\b(?:Previous|Price week)\\b"),
        weekly_change = position("\\bWeekly\\b"),
        price_12_months_ago = position("\\bPrice 12\\b"),
        annual_change = position("\\b(?:Annual|Year[- ]on[- ]year)\\b")
      )
      if (all(!is.na(candidate)) && all(diff(candidate) > 0L)) {
        header_starts <- candidate
      }
    }
    parts <- trimws(strsplit(line, "[[:space:]]{2,}", perl = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    parts <- parts[
      !parts %in% c("\u21e7", "\u21e9", "\u25cf", "\u2191", "\u2193", "#")
    ]
    date_at <- which(grepl(
      "^[0-3]?[0-9]-[A-Za-z]{3}(?:-(?:[0-9]{2}|20[0-9]{2}))?$",
      parts, perl = TRUE
    ))
    if (length(date_at) != 1L || date_at <= 1L ||
        length(parts) < date_at + 5L) next
    label <- agau_norm_text(paste(parts[seq_len(date_at - 1L)], collapse = " "))
    unit <- agau_norm_text(parts[[date_at + 1L]])
    if (!grepl(price_unit, unit)) next
    split_values <- parts[(date_at + 2L):length(parts)]
    split_values <- split_values[
      !split_values %in%
        c("\u21e7", "\u21e9", "\u25cf", "\u2191", "\u2193", "#")
    ]
    values <- if (length(split_values) == 5L) {
      split_values
    } else if (!is.null(data_bounds)) {
      starts <- c(data_bounds$start, data_bounds$breaks + 1L)
      ends <- c(data_bounds$breaks, nchar(line))
      vapply(seq_along(starts), function(i) {
        trimws(substr(line, starts[[i]], ends[[i]]))
      }, "")
    } else if (!is.null(header_starts)) {
      ends <- c(header_starts[-1L] - 1L, nchar(line))
      vapply(seq_along(header_starts), function(i) {
        trimws(substr(line, header_starts[[i]], ends[[i]]))
      }, "")
    } else {
      split_values
    }
    values <- trimws(gsub("[\u21e7\u21e9\u25cf\u2191\u2193]", "", values))
    values <- trimws(gsub(
      "(^|[[:space:]])#(?=[[:space:]]|$)", "\\1", values,
      perl = TRUE
    ))
    if (length(values) != 5L) {
      agau_abort(
        "agau_table_parse_error",
        paste("Weekly PDF price row has", length(values), "measures:", label),
        remediation = "Audit the report-era table profile."
      )
    }
    config <- tryCatch(
      agau_weekly_match_series(label),
      agau_table_parse_error = function(e) NULL
    )
    if (is.null(config) && line_number > 1L) {
      stitched <- agau_norm_text(paste(lines[[line_number - 1L]], label))
      config <- tryCatch(
        agau_weekly_match_series(stitched),
        agau_table_parse_error = function(e) NULL
      )
      if (!is.null(config)) label <- stitched
    }
    if (is.null(config)) config <- agau_weekly_match_series(label)
    if (length(split_values) == 5L) {
      cursor <- regexpr(unit, line, fixed = TRUE)[[1]]
      if (cursor > 0L) {
        cursor <- cursor + nchar(unit)
        ends <- integer(5L)
        ok <- TRUE
        for (value_index in seq_along(split_values)) {
          remainder <- substr(line, cursor, nchar(line))
          relative <- regexpr(
            split_values[[value_index]], remainder, fixed = TRUE
          )[[1]]
          if (relative < 0L) {
            ok <- FALSE
            break
          }
          start <- cursor + relative - 1L
          ends[[value_index]] <- start +
            nchar(split_values[[value_index]]) - 1L
          cursor <- ends[[value_index]] + 1L
        }
        if (ok) {
          unit_at <- regexpr(unit, line, fixed = TRUE)[[1]]
          starts <- ends - nchar(split_values) + 1L
          unit_end <- unit_at + nchar(unit) - 1L
          breaks <- floor(
            (ends[1:4] + starts[2:5]) / 2
          )
          data_bounds <- list(
            start = floor((unit_end + starts[[1]]) / 2) + 1L,
            breaks = breaks
          )
        }
      }
    }
    records[[length(records) + 1L]] <- data.frame(
      indicator = label,
      week_average = parts[[date_at]],
      unit = unit,
      latest_price = values[[1]],
      previous_week = values[[2]],
      weekly_change = values[[3]],
      price_12_months_ago = values[[4]],
      annual_change = values[[5]],
      source_series_id = config$source_series_id,
      stringsAsFactors = FALSE
    )
  }
  if (!length(records)) {
    agau_abort(
      "agau_table_parse_error",
      "No complete Weekly price table was found in the report.",
      release_id = paste0("weekly-prices-", release_date),
      remediation = paste(
        "Use a report from the complete-table era beginning 13 October 2016;",
        "earlier archive reports use narrative and graphical presentation."
      )
    )
  }
  records <- do.call(rbind, records)
  records <- records[!duplicated(records), , drop = FALSE]
  if (nrow(records) < 15L || nrow(records) > 35L ||
      anyDuplicated(records$source_series_id)) {
    agau_abort(
      "agau_schema_error",
      paste("Weekly report table has an invalid canonical series set of", nrow(records)),
      remediation = "Audit the exact report and parser profile."
    )
  }
  agau_weekly_table_rows(
    records, release_date, source_asset, "PDF commodities table",
    sha256, as.POSIXct(retrieved_at, tz = "UTC"), measures
  )
}

agau_pdf_to_text <- function(path) {
  binary <- Sys.which("pdftotext")
  if (!nzchar(binary)) {
    agau_abort(
      "agau_dependency_error",
      "PDF history parsing requires the Poppler pdftotext executable.",
      remediation = "Install Poppler and ensure pdftotext is on PATH."
    )
  }
  out <- tempfile(fileext = ".txt")
  status <- suppressWarnings(system2(
    binary, c("-layout", shQuote(path), shQuote(out)),
    stdout = TRUE, stderr = TRUE
  ))
  if (!file.exists(out) || !is.null(attr(status, "status"))) {
    agau_abort(
      "agau_table_parse_error",
      "Poppler could not extract the official Weekly report text.",
      remediation = "Verify the PDF bytes and Poppler installation."
    )
  }
  out
}

agau_assert_safe_zip_members <- function(members) {
  normalised <- gsub("\\", "/", members, fixed = TRUE)
  unsafe <- !nzchar(normalised) |
    grepl("^/", normalised) |
    grepl("^[A-Za-z]:/", normalised) |
    grepl("(^|/)\\.\\.?(/|$)", normalised)
  if (any(unsafe)) {
    agau_abort(
      "agau_asset_format_error",
      "Weekly archive contains an unsafe member path.",
      remediation = paste(
        "Use an official archive whose members are relative paths without",
        "parent-directory components."
      )
    )
  }
  invisible(normalised)
}

agau_parse_weekly_path <- function(path, measures, release_dates = NULL) {
  if (!file.exists(path)) {
    agau_abort(
      "agau_asset_missing_error",
      paste("Weekly source does not exist:", path),
      remediation = "Supply a local official snapshot or a documented snapshot ID."
    )
  }
  format <- if (tolower(tools::file_ext(path)) == "txt") {
    "text"
  } else {
    agau_detect_format(path)
  }
  if (format == "html") {
    table <- agau_parse_weekly_html_table(path, measures)
    charts <- agau_parse_weekly_chart_html(path)
    out <- Filter(Negate(is.null), list(table, charts))
    if (!length(out)) {
      agau_abort(
        "agau_table_parse_error",
        "HTML contains neither the Weekly table nor dated chart observations.",
        remediation = "Use an official Weekly commodity prices page snapshot."
      )
    }
    return(do.call(rbind, out))
  }
  if (format == "docx") {
    return(agau_parse_weekly_docx(path, measures))
  }
  if (format == "pdf") {
    text <- agau_pdf_to_text(path)
    on.exit(unlink(text), add = TRUE)
    return(agau_parse_weekly_text(
      text, source_asset = basename(path), sha256 = agau_sha256(path),
      retrieved_at = file.info(path)$mtime, measures = measures
    ))
  }
  if (format == "text") return(agau_parse_weekly_text(path, measures = measures))
  if (format == "zip") {
    listing <- utils::unzip(path, list = TRUE)
    agau_assert_safe_zip_members(listing$Name)
    members <- listing$Name[grepl("\\.pdf$", listing$Name, ignore.case = TRUE)]
    member_dates <- as.Date(
      regmatches(members, regexpr("20[0-9]{6}", members)),
      "%Y%m%d"
    )
    if (!is.null(release_dates)) {
      release_dates <- as.Date(release_dates)
      requested <- !is.na(member_dates) & member_dates %in% release_dates
      absent <- setdiff(release_dates, member_dates[requested])
      if (length(absent)) {
        agau_abort(
          "agau_asset_missing_error",
          paste(
            "Weekly archive is missing requested supported reports:",
            paste(absent, collapse = ", ")
          ),
          remediation = "Refresh the exact official quarterly archive."
        )
      }
      members <- members[requested]
      member_dates <- member_dates[requested]
    } else {
      supported_era <- !is.na(member_dates) &
        member_dates >= as.Date("2016-10-13")
      members <- members[supported_era]
      member_dates <- member_dates[supported_era]
    }
    if (!length(members)) {
      agau_abort(
        "agau_asset_format_error",
        "Weekly archive contains no PDF reports.",
        remediation = "Use an official ABARES quarterly Weekly Update archive."
      )
    }
    directory <- tempfile("agau-weekly-archive-")
    dir.create(directory)
    on.exit(unlink(directory, recursive = TRUE), add = TRUE)
    utils::unzip(path, files = members, exdir = directory)
    rows <- lapply(members, function(member) {
      report <- file.path(directory, member)
      text <- agau_pdf_to_text(report)
      on.exit(unlink(text), add = TRUE)
      agau_parse_weekly_text(
        text, source_asset = paste0(basename(path), "::", member),
        sha256 = agau_sha256(report), retrieved_at = file.info(path)$mtime,
        measures = measures
      )
    })
    return(do.call(rbind, rows))
  }
  agau_abort(
    "agau_asset_format_error",
    paste("Unsupported Weekly source format:", format),
    remediation = paste(
      "Use official HTML, PDF, Word, text-extract fixture or quarterly ZIP bytes."
    )
  )
}

agau_weekly_current_urls <- function() {
  c(
    current = "https://www.agriculture.gov.au/abares/data/weekly-commodity-price-update",
    world = paste0(
      "https://www.agriculture.gov.au/abares/data/weekly-commodity-price-update/",
      "world-agricultural-prices"
    ),
    australian = paste0(
      "https://www.agriculture.gov.au/abares/data/weekly-commodity-price-update/",
      "australian-agricultural-prices"
    ),
    horticulture = paste0(
      "https://www.agriculture.gov.au/abares/data/weekly-commodity-price-update/",
      "australian-horticulture-prices"
    )
  )
}

agau_weekly_catalogue <- function() {
  path <- system.file("catalogue", "weekly-release-catalog.csv", package = "readagau")
  if (!nzchar(path)) {
    agau_abort(
      "agau_schema_error",
      "Installed Weekly release catalogue is missing.",
      remediation = "Reinstall readagau from a complete source tree."
    )
  }
  out <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
  out$release_date <- as.Date(out$release_date)
  out
}

agau_weekly_archive_release_id <- function(release_date) {
  release_date <- as.Date(release_date)
  month <- as.integer(format(release_date, "%m"))
  quarter <- ((month - 1L) %/% 3L) + 1L
  paste0("weekly-archive-", format(release_date, "%Y-q"), quarter)
}

agau_weekly_download_source <- function(row, cache_dir, refresh) {
  asset_type <- row$asset_type[[1]]
  release <- if (asset_type == "archive") {
    agau_weekly_archive_release_id(row$release_date[[1]])
  } else {
    row$release_id[[1]]
  }
  agau_cache_asset(
    "weekly_commodity_prices", release, asset_type, row$source_url[[1]],
    basename(row$source_url[[1]]), cache_dir = cache_dir, refresh = refresh
  )$local_path[[1]]
}

#' Read Weekly commodity-price observations
#'
#' Parse a current Weekly commodity-price table and its accessible chart pages,
#' an exact dated report, the supported complete-table history, or one or more
#' local HTML, PDF, Word, text-extract, or ZIP snapshots. The local-path form
#' is deterministic and offline; catalogue IDs and `snapshot = "latest"`
#' use the official source catalogue and may download missing assets.
#'
#' @param product Character scalar. Must be
#'   `"weekly_commodity_prices"` (the default).
#' @param snapshot Character scalar or vector. Use `"latest"` (the default)
#'   for the current table and, optionally, its chart pages; `"all"` for all
#'   supported catalogue snapshots; an ISO date or exact Weekly release ID for
#'   selected catalogue rows; or one or more existing local HTML, PDF, DOCX,
#'   text-extract, or ZIP paths. When supplying paths, every element must
#'   exist or the input is interpreted as catalogue IDs and an
#'   `agau_asset_missing_error` may result.
#' @param series Optional character vector of canonical source IDs such as
#'   `"A2"` or `"H1"`, table IDs such as `"weekly_A2"`, or returned
#'   `series_id` values. Filtering occurs after parsing; an unmatched filter
#'   returns a zero-row result with the same columns and classes.
#' @param measures Character vector of source measures to retain. The default
#'   retains all five: `"latest_price"`, `"previous_week"`,
#'   `"weekly_change"`, `"price_12_months_ago"`, and `"annual_change"`.
#'   Unknown measures raise an `agau_validation_error`.
#' @param include_charts Logical scalar, default `TRUE`. For
#'   `snapshot = "latest"`, include the 33 dated chart observations (A1-A25
#'   and H1-H8) in addition to the 22 current-table indicators. Set to
#'   `FALSE` to request only the current table. For explicit local paths this
#'   flag is ignored: each supplied HTML path is parsed for both a recognised
#'   table and chart descriptions.
#' @param from Optional inclusive lower date limit used only with
#'   `snapshot = "all"`. The value is converted with [as.Date()] and filters
#'   catalogue `release_date` before any source bytes are requested.
#' @param to Optional inclusive upper date limit used only with
#'   `snapshot = "all"`. The value is converted with [as.Date()] and filters
#'   catalogue `release_date` before any source bytes are requested.
#' @param cache_dir Character path to the immutable Weekly cache. Defaults to
#'   [agau_cache_dir()]. Local parsing does not alter the source files and
#'   normally does not need the cache; catalogue/live requests store raw bytes,
#'   discovery metadata, and manifests below this directory.
#' @param refresh Logical scalar, default `FALSE`. Reuse valid cached source
#'   bytes when `FALSE`; when `TRUE`, refresh discovery and retrieve current
#'   source bytes. This has no effect on explicit local paths.
#' @return A tibble with classes `agau_weekly_prices`, `agau_data`,
#'   `tbl_df`, `tbl`, and `data.frame`, using the 43-column observation
#'   contract from [agau_observation_schema()]. Columns are, in order,
#'   `product`, `release_id`, `release_date`, `dataset`, `source_dataset`,
#'   `source_asset`, `source_sheet`, `table_id`, `table_title`, `record_role`,
#'   `geography_type`, `geography`, `commodity`, `concept`, `period`,
#'   `period_start`, `period_end`, `period_basis`, `period_status`,
#'   `status_source`, `price_basis`, `currency`, `unit`, `value`, `raw_value`,
#'   `missing_reason`, `footnote_codes`, `source_note`, `series_id`,
#'   `observation_key`, `retrieved_at`, `sha256`, `parser_version`,
#'   `report_number`, `sector`, `season`, `market`, `method`, `source_provider`,
#'   `rights_status`, `observation_date`, `snapshot_date`, and
#'   `source_cadence`. Date fields are `Date`; `retrieved_at` is UTC
#'   `POSIXct`; `value` is numeric; and `footnote_codes` is a list-column of
#'   character vectors. Table rows use `record_role` for the selected measure;
#'   chart rows use `latest_price`. Missing provider tokens remain `NA` with
#'   `missing_reason` set to `provider_na`, `provider_error`, or
#'   `bounded_value` when the token is recognised.
#' @details Live requests use HTTPS catalogue URLs, a 60-second request
#'   timeout, and a bounded retry policy. They write only below `cache_dir`
#'   and fail with structured conditions rather than returning partial data:
#'   `agau_asset_missing_error` covers unknown/unsupported snapshots,
#'   `agau_dependency_error` reports missing Poppler for PDF parsing,
#'   `agau_asset_format_error` covers unsupported formats or unsafe ZIP member
#'   paths, and `agau_table_parse_error`/`agau_schema_error` cover malformed
#'   source tables, reports, and chart descriptions. A PDF requires the
#'   external `pdftotext` executable from Poppler; HTML, text, DOCX, and
#'   non-PDF workflows do not. ZIP inputs are extracted only after relative
#'   member-path validation, and supported PDF members are parsed individually.
#'   Source hashes, provider labels, and rights/provenance fields are retained;
#'   package fixtures are synthetic and do not represent official prices.
#' @seealso [agau_observation_schema()], [agau_series_catalog()],
#'   [list_agau_releases()], [download_agau_release()],
#'   [validate_agau_release()]
#' @family readers
#' @examples
#' current <- system.file(
#'   "fixtures", "html", "weekly-prices-current.html", package = "readagau"
#' )
#' weekly <- read_agau_prices(
#'   snapshot = current, series = "A2", include_charts = FALSE,
#'   measures = c("latest_price", "annual_change"),
#'   cache_dir = tempfile("readagau-weekly-example-")
#' )
#' stopifnot(
#'   inherits(weekly, "agau_weekly_prices"), ncol(weekly) == 43L,
#'   all(weekly$table_id == "weekly_A2"),
#'   identical(sort(unique(weekly$record_role)),
#'     sort(c("latest_price", "annual_change"))),
#'   all(file.exists(current))
#' )
#' weekly[, c("release_date", "table_id", "record_role", "value", "unit")]
#' @export
read_agau_prices <- function(
    product = "weekly_commodity_prices", snapshot = "latest", series = NULL,
    measures = c(
      "latest_price", "previous_week", "weekly_change",
      "price_12_months_ago", "annual_change"
    ),
    include_charts = TRUE, from = NULL, to = NULL,
    cache_dir = agau_cache_dir(), refresh = FALSE) {
  if (!identical(product, "weekly_commodity_prices")) {
    agau_abort(
      "agau_validation_error",
      paste("Unsupported price product:", paste(product, collapse = ", ")),
      remediation = "Use product = 'weekly_commodity_prices'."
    )
  }
  allowed_measures <- c(
    "latest_price", "previous_week", "weekly_change",
    "price_12_months_ago", "annual_change"
  )
  bad_measures <- setdiff(measures, allowed_measures)
  if (length(bad_measures)) {
    agau_abort(
      "agau_validation_error",
      paste("Unknown Weekly measure:", paste(bad_measures, collapse = ", ")),
      remediation = paste("Use one of:", paste(allowed_measures, collapse = ", "))
    )
  }
  local <- length(snapshot) && all(file.exists(snapshot))
  if (local) {
    rows <- lapply(snapshot, agau_parse_weekly_path, measures = measures)
    out <- do.call(rbind, rows)
  } else if (length(snapshot) == 1L && identical(snapshot, "latest")) {
    urls <- agau_weekly_current_urls()
    if (!isTRUE(include_charts)) urls <- urls["current"]
    paths <- lapply(seq_along(urls), function(i) {
      agau_cache_asset(
        "weekly_commodity_prices", "weekly-prices-current",
        "page_snapshot", urls[[i]], paste0(names(urls)[[i]], ".html"),
        cache_dir = cache_dir, refresh = refresh
      )$local_path[[1]]
    })
    rows <- lapply(paths, agau_parse_weekly_path, measures = measures)
    out <- do.call(rbind, rows)
  } else {
    catalogue <- agau_weekly_catalogue()
    if (length(snapshot) == 1L && identical(snapshot, "all")) {
      hit <- catalogue[catalogue$support_status == "supported", , drop = FALSE]
      if (!is.null(from)) hit <- hit[hit$release_date >= as.Date(from), , drop = FALSE]
      if (!is.null(to)) hit <- hit[hit$release_date <= as.Date(to), , drop = FALSE]
    } else {
      wanted_date <- tryCatch(
        as.Date(snapshot),
        error = function(e) as.Date(rep(NA_character_, length(snapshot)))
      )
      wanted_id <- as.character(snapshot)
      hit <- catalogue[
        catalogue$release_id %in% wanted_id |
          (!is.na(wanted_date) & catalogue$release_date %in% wanted_date),
        , drop = FALSE
      ]
    }
    if (!nrow(hit)) {
      agau_abort(
        "agau_asset_missing_error",
        "No requested Weekly snapshot is present in the official catalogue.",
        remediation = "Use list_agau_releases('weekly_commodity_prices')."
      )
    }
    unsupported <- hit$support_status != "supported"
    if (any(unsupported)) {
      agau_abort(
        "agau_asset_missing_error",
        paste(unique(hit$unsupported_reason[unsupported]), collapse = "; "),
        release_id = paste(hit$release_id[unsupported], collapse = ", "),
        remediation = "Choose a supported exact Weekly report snapshot."
      )
    }
    unique_sources <- hit[!duplicated(hit$source_url), , drop = FALSE]
    parsed <- lapply(seq_len(nrow(unique_sources)), function(i) {
      path <- agau_weekly_download_source(unique_sources[i, ], cache_dir, refresh)
      requested_dates <- hit$release_date[
        hit$source_url == unique_sources$source_url[[i]]
      ]
      got <- agau_parse_weekly_path(
        path, measures, release_dates = requested_dates
      )
      absent <- setdiff(requested_dates, unique(got$release_date))
      if (length(absent)) {
        agau_abort(
          "agau_table_parse_error",
          paste(
            "Weekly source did not parse every requested supported report:",
            paste(absent, collapse = ", ")
          ),
          remediation = "Refresh and audit the exact official source bytes."
        )
      }
      got
    })
    out <- do.call(rbind, parsed)
    keep_dates <- unique(hit$release_date)
    out <- out[out$release_date %in% keep_dates, , drop = FALSE]
  }
  if (!is.null(series)) {
    source_id <- sub("^weekly_", "", out$table_id)
    out <- out[
      source_id %in% series | out$table_id %in% series |
        out$series_id %in% series,
      , drop = FALSE
    ]
  }
  out <- out[order(out$release_date, out$table_id, out$record_role), , drop = FALSE]
  out <- tibble::as_tibble(out)
  class(out) <- unique(c("agau_weekly_prices", "agau_data", class(out)))
  out
}

#' Catalogue semantic ABARES series
#'
#' Return stable semantic series metadata for a product, without downloading
#' source bytes. The Weekly product has a dedicated 35-row registry that is
#' available offline; for other products the function exposes the package's
#' source catalogue, or derives a de-duplicated series view from a supplied
#' local observation file.
#'
#' @param product Character scalar product ID, such as
#'   `"weekly_commodity_prices"`, `"crop_report"`,
#'   `"agricultural_commodities"`, or `"farm_productivity"`.
#' @param release Character scalar release ID or `"latest"` (the default),
#'   or one or more existing local source paths. `"latest"` is meaningful for
#'   the Weekly registry and other catalogue products; when all values are
#'   existing paths, the corresponding reader parses them offline and the
#'   result is reduced to one row per `series_id`.
#' @param datasets Optional character vector of exact dataset IDs to retain.
#'   `NULL` (the default) retains all datasets represented by the selected
#'   product or local observations.
#' @param include_unsupported Logical scalar, default `TRUE`. For catalogue
#'   products, retain rows whose `admission_status` is not `"supported"` when
#'   `TRUE`; set to `FALSE` to show only admitted source families. This does
#'   not alter the Weekly registry, whose packaged rows are supported metadata.
#' @param cache_dir Character path passed to a local reader when `release`
#'   contains paths, or used by any underlying reader that needs it. Defaults
#'   to [agau_cache_dir()]. Catalogue-only calls do not write to the cache.
#' @return A tibble. For `product = "weekly_commodity_prices"` with
#'   `release = "latest"`, it has 35 rows and these 12 columns:
#'   `source_series_id`, `pattern`, `indicator`, `commodity`, `sector`,
#'   `market`, `source_provider`, `source_cadence`, `product`, `dataset`,
#'   `table_id`, and `admission_status`; all are character. For other
#'   catalogue products, columns follow [agau_source_catalog()] and include
#'   `product`, `dataset`, `source_asset`, `source_label`, `table_id`,
#'   `semantic_family`, `parser_family`, `admission_status`, and
#'   `unsupported_reason`. For local observations, the returned 14 columns
#'   are `product`, `dataset`, `table_id`, `series_id`, `geography_type`,
#'   `geography`, `commodity`, `concept`, `unit`, `period_basis`, `price_basis`,
#'   `currency`, `method`, and `rights_status`, with one row per unique
#'   `series_id` after filtering.
#' @details This is a metadata operation: it does not contact the network for
#'   the normal catalogue paths. A missing catalogue, unsupported product, or
#'   malformed local source raises a structured `agau_*_error`; parsing a local
#'   PDF can additionally require Poppler, while local ZIP safety and source
#'   format checks are delegated to the underlying reader. Provider names and
#'   URLs identify source series and do not grant redistribution rights.
#' @seealso [agau_source_catalog()], [agau_observation_schema()],
#'   [list_agau_releases()], [read_agau_prices()]
#' @family catalogue and schema helpers
#' @examples
#' weekly_series <- agau_series_catalog(
#'   "weekly_commodity_prices", cache_dir = tempfile("readagau-series-example-")
#' )
#' stopifnot(
#'   inherits(weekly_series, "tbl_df"), nrow(weekly_series) == 35L,
#'   all(weekly_series$product == "weekly_commodity_prices"),
#'   all(c("source_series_id", "table_id", "source_provider") %in%
#'     names(weekly_series))
#' )
#' weekly_series[weekly_series$source_series_id %in% c("A2", "H1"),
#'   c("source_series_id", "indicator", "commodity", "source_provider")]
#' @export
agau_series_catalog <- function(product, release = "latest", datasets = NULL,
                                include_unsupported = TRUE,
                                cache_dir = agau_cache_dir()) {
  if (identical(product, "weekly_commodity_prices") &&
      (!length(release) || identical(release, "latest"))) {
    out <- agau_weekly_series()
    out$product <- "weekly_commodity_prices"
    out$dataset <- "weekly_prices"
    out$table_id <- paste0("weekly_", out$source_series_id)
    out$admission_status <- "supported"
    return(tibble::as_tibble(out))
  }
  if (length(release) && all(file.exists(release))) {
    data <- switch(product,
      crop_report = read_crop_report(release, view = "reported"),
      agricultural_commodities = read_agricultural_commodities(release, view = "reported"),
      farm_productivity = read_farm_productivity(release, view = "reported"),
      weekly_commodity_prices = read_agau_prices(snapshot = release),
      agau_abort("agau_validation_error", "Unsupported catalogue product.",
        remediation = "Use a documented product ID."
      )
    )
    if (!is.null(datasets)) data <- data[data$dataset %in% datasets, ]
    key <- !duplicated(data$series_id)
    return(data[key, c(
      "product", "dataset", "table_id", "series_id", "geography_type",
      "geography", "commodity", "concept", "unit", "period_basis",
      "price_basis", "currency", "method", "rights_status"
    )])
  }
  cat <- agau_source_catalog()
  cat <- cat[cat$product == product, , drop = FALSE]
  if (!is.null(datasets)) cat <- cat[cat$dataset %in% datasets, , drop = FALSE]
  if (!include_unsupported) cat <- cat[cat$admission_status == "supported", , drop = FALSE]
  tibble::as_tibble(cat)
}
