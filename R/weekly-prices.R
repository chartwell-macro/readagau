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
      issue_date <- as.Date(issue[[3]], "%d %B %Y")
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
    file_label <- trimws(format(file_date, "%e %B %Y"))
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
      got <- as.Date(hit[[2]], "%d %B %Y")
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
  label <- agau_norm_text(label)
  if (grepl("^20[0-9]{2}-[0-9]{2}-[0-9]{2}$", label)) {
    out <- as.Date(label)
  } else if (grepl(
    "^[0-3]?[0-9]-[A-Za-z]{3}-(?:[0-9]{2}|20[0-9]{2})$", label,
    perl = TRUE
  )) {
    out <- as.Date(
      label,
      if (grepl("-20[0-9]{2}$", label)) "%d-%b-%Y" else "%d-%b-%y"
    )
  } else {
    out <- as.Date(
      paste(format(snapshot_date, "%Y"), label),
      tryFormats = c("%Y %d-%b", "%Y %d-%B")
    )
    if (!is.na(out) && out > snapshot_date) {
      out <- as.Date(
        paste(as.integer(format(snapshot_date, "%Y")) - 1L, label),
        tryFormats = c("%Y %d-%b", "%Y %d-%B")
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
      "agau_endpoint_error",
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

#' Read Weekly commodity prices observations
#'
#' Read the current official HTML table and accessible chart observations, an
#' exact dated report, the full complete-table history, or local official
#' HTML/PDF/ZIP snapshots.
#'
#' @param product Must be `"weekly_commodity_prices"`.
#' @param snapshot `"latest"`, `"all"`, an ISO date, a Weekly release ID, or
#'   one or more local HTML, PDF, Word, text-extract or ZIP paths.
#' @param series Optional canonical source IDs such as `"A2"` or `"H1"`,
#'   canonical table IDs, or returned `series_id` values.
#' @param measures Source measures to retain: `latest_price`, `previous_week`,
#'   `weekly_change`, `price_12_months_ago`, and `annual_change`.
#' @param include_charts Include all 33 dated A1-A25 and H1-H8 current chart
#'   observations when `snapshot = "latest"`.
#' @param from,to Optional inclusive release-date limits for `"all"`.
#' @param cache_dir Immutable cache directory.
#' @param refresh Re-fetch official bytes instead of replaying the cache.
#' @return Canonical Weekly price observations with exact source provenance.
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
#' @param product Product ID.
#' @param release Release ID or local path.
#' @param datasets Optional dataset filter.
#' @param include_unsupported Include discovered-unverified sources.
#' @param cache_dir Cache directory.
#' @return A semantic series catalogue.
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
