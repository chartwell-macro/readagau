agau_legacy_numeric_token <- function(x) {
  token <- agau_norm_text(x)
  numeric <- gsub(",", "", token, fixed = TRUE)
  numeric <- gsub("(?<=\\d)\\s+(?=\\d)", "", numeric, perl = TRUE)
  !is.na(suppressWarnings(as.numeric(numeric))) |
    tolower(token) %in% c(
      "na", "n/a", "not applicable", "not available", "unavailable",
      "nr", "not reported", "confidential", "c", "suppressed", "..",
      "-", "\u2014"
    )
}

agau_legacy_numeric_raw <- function(x) {
  token <- agau_norm_text(x)
  candidate <- gsub(",", "", token, fixed = TRUE)
  candidate <- gsub("(?<=\\d)\\s+(?=\\d)", "", candidate, perl = TRUE)
  if (!is.na(suppressWarnings(as.numeric(candidate)))) candidate else token
}

agau_legacy_period_token <- function(x) {
  x <- agau_norm_text(x)
  quarter_match <- regexec(
    paste0(
      "((?:19|20)[0-9]{2})\\s*",
      "(Jan-Mar|Apr-Jun|Jul-Sep|Oct-Dec)"
    ),
    x,
    ignore.case = TRUE
  )
  quarter_parts <- regmatches(x, quarter_match)[[1]]
  if (length(quarter_parts) == 3L) {
    quarter <- match(
      tolower(quarter_parts[[3]]),
      tolower(c("Jan-Mar", "Apr-Jun", "Jul-Sep", "Oct-Dec"))
    )
    return(paste(quarter_parts[[2]], paste0("Q", quarter)))
  }
  month_match <- regexec(
    paste0(
      "(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|",
      "Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|",
      "Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)",
      "[- ]((?:19|20)[0-9]{2})"
    ),
    x,
    ignore.case = TRUE
  )
  month_parts <- regmatches(x, month_match)[[1]]
  if (length(month_parts) == 3L) {
    month <- month.abb[match(
      tolower(substr(month_parts[[2]], 1L, 3L)),
      tolower(month.abb)
    )]
    return(paste(month, month_parts[[3]]))
  }
  hit <- regmatches(
    x,
    regexpr(
      "(?:19|20)[0-9]{2}-(?:[0-9]{2}|[0-9]{4})(?:\\s*[sfz])?",
      x, ignore.case = TRUE
    )
  )
  if (length(hit) && nzchar(hit)) return(hit)
  hit <- regmatches(
    x,
    regexpr("(?:19|20)[0-9]{2}\\s*Q[1-4]", x, ignore.case = TRUE)
  )
  if (length(hit) && nzchar(hit)) return(hit)
  if (grepl("^Q[1-4]$", x, ignore.case = TRUE)) return(toupper(x))
  if (grepl("^(?:19|20)[0-9]{2}\\s*[sfz]?$", x, ignore.case = TRUE)) {
    return(x)
  }
  ""
}

agau_legacy_unit <- function(x) {
  x <- agau_norm_text(x)
  hit <- x[grepl(
    paste0(
      "(?:^|\\s)(?:A?US?\\$|%|index|ha|tonnes?|kt|mt|t/ha|c/kg|c/l|",
      "million|billion|number|head|litres?|ML|GL)(?:$|\\s|/)"
    ),
    x, ignore.case = TRUE
  )]
  if (length(hit)) utils::tail(hit, 1L) else "not_stated"
}

agau_legacy_title <- function(x, fallback) {
  cells <- agau_norm_text(as.vector(x[seq_len(min(10L, nrow(x))), , drop = FALSE]))
  cells <- cells[nzchar(cells)]
  candidates <- cells[
    !agau_legacy_numeric_token(cells) &
      !grepl("^(?:Index|Contents|Notes?|Sources?)$", cells, ignore.case = TRUE)
  ]
  if (!length(candidates)) return(fallback)
  candidates[[which.max(nchar(candidates))]]
}

agau_legacy_crop_unit_token <- function(x) {
  x <- agau_norm_text(x)
  grepl(
    paste0(
      "^(?:A?US?\\$.*|%|index(?:\\s.*)?|'?000\\s*ha|ha|",
      "tonnes?|kt|mt|t/ha|kg/ha|c/kg|c/l|A\\$/t|number|head|",
      "million|billion|litres?|ML|GL|mm|rank)$"
    ),
    x,
    ignore.case = TRUE
  )
}

agau_legacy_crop_clean_label <- function(x) {
  x <- agau_norm_text(x)
  unit <- agau_legacy_crop_unit_token(x)
  x[!unit] <- agau_strip_footnote_suffix(x[!unit])
  x <- trimws(sub("^[-\u2013\u2014]+\\s*", "", x))
  trimws(gsub("\\s+", " ", x))
}

agau_legacy_crop_measure <- function(x) {
  label <- agau_legacy_crop_clean_label(x)
  key <- tolower(label)
  if (!nzchar(key)) return("")
  if (grepl("^area(?: planted)? change\\b", key)) return("Area change")
  if (grepl("^yield change\\b", key)) return("Yield change")
  if (grepl("^(?:prod\\.?|production) change\\b", key)) {
    return("Production change")
  }
  if (grepl("^area planted\\b", key)) return("Area planted")
  if (grepl("^area(?:\\b|$)", key)) return("Area")
  if (grepl("^yield(?:\\b|$)", key)) return("Yield")
  if (grepl("^(?:prod\\.?|production)(?:\\b|$)", key)) return("Production")
  if (grepl("^apparent domestic use(?:\\b|$)", key)) {
    return("Apparent domestic use")
  }
  if (grepl("^domestic use(?:\\b|$)", key)) return("Domestic use")
  if (grepl("^exports?(?:\\b|$)", key)) return(sub("^export$", "Export", label,
    ignore.case = TRUE
  ))
  if (grepl("^imports?(?:\\b|$)", key)) return(sub("^import$", "Import", label,
    ignore.case = TRUE
  ))
  if (grepl("^prices?(?:\\b|$)", key)) return(sub("^price$", "Price", label,
    ignore.case = TRUE
  ))
  if (grepl("\\bprice\\b", key)) return(label)
  if (grepl(
    "^(?:seed|other|feed|malting|malt|stocks?|carry|disappearance|use)\\b",
    key
  )) {
    return(label)
  }
  ""
}

agau_legacy_crop_concept <- function(unit, fallback = "", title = "") {
  semantic <- agau_legacy_crop_measure(fallback)
  if (nzchar(semantic)) return(semantic)
  unit_key <- tolower(agau_norm_text(unit))
  if (grepl("(?:t|kg)/ha", unit_key)) return("Yield")
  if (grepl("\\bha\\b", unit_key)) return("Area")
  if (grepl("\\b(?:kt|mt)\\b|tonnes?|\\bkg\\b", unit_key)) {
    return("Production")
  }
  if (grepl("\\$|c/kg|c/l", unit_key)) return("Price")
  if (grepl("^%$", unit_key)) return("Percentage change")
  title_concept <- agau_title_concept(title)
  if (!identical(title_concept, "published measure")) {
    return(tools::toTitleCase(title_concept))
  }
  clean <- agau_legacy_crop_clean_label(fallback)
  if (nzchar(clean)) clean else "Published measure"
}

agau_legacy_crop_geography <- function(x) {
  key <- gsub(
    "[^a-z]",
    "",
    tolower(agau_legacy_crop_clean_label(x))
  )
  aliases <- c(
    australia = "Australia",
    australian = "Australia",
    aust = "Australia",
    aus = "Australia",
    newsouthwales = "New South Wales",
    nsw = "New South Wales",
    victoria = "Victoria",
    vic = "Victoria",
    queensland = "Queensland",
    qld = "Queensland",
    southaustralia = "South Australia",
    sa = "South Australia",
    westernaustralia = "Western Australia",
    wa = "Western Australia",
    tasmania = "Tasmania",
    tas = "Tasmania",
    northernterritory = "Northern Territory",
    nt = "Northern Territory",
    australiancapitalterritory = "Australian Capital Territory",
    act = "Australian Capital Territory"
  )
  unname(aliases[key]) %||% ""
}

agau_legacy_crop_title_geography <- function(title) {
  states <- c(
    "Australian Capital Territory", "Northern Territory",
    "New South Wales", "South Australia", "Western Australia",
    "Queensland", "Tasmania", "Victoria"
  )
  hits <- states[vapply(states, function(state) {
    grepl(tolower(state), tolower(title), fixed = TRUE)
  }, logical(1))]
  if (length(hits)) return(hits[[1]])
  aliases <- c(
    ACT = "Australian Capital Territory", NT = "Northern Territory",
    NSW = "New South Wales", SA = "South Australia",
    WA = "Western Australia", QLD = "Queensland",
    TAS = "Tasmania", VIC = "Victoria"
  )
  hits <- names(aliases)[vapply(names(aliases), function(alias) {
    grepl(paste0("\\b", alias, "\\b"), title, ignore.case = TRUE)
  }, logical(1))]
  if (length(hits)) return(unname(aliases[[hits[[1]]]]))
  "Australia"
}

agau_legacy_crop_generic_header <- function(x) {
  key <- tolower(agau_legacy_crop_clean_label(x))
  !nzchar(key) ||
    grepl(
      paste0(
        "^(?:year|unit|crop|commodity|category|state|states|",
        "winter crops?|summer crops?|table\\s*[0-9]+)$"
      ),
      key
    ) ||
    nzchar(agau_legacy_period_token(key)) ||
    agau_legacy_crop_unit_token(key)
}

agau_legacy_crop_forward_headers <- function(x, rows, cols) {
  if (!length(rows) || !length(cols)) {
    return(matrix("", nrow = 0L, ncol = length(cols)))
  }
  out <- x[rows, cols, drop = FALSE]
  for (i in seq_len(nrow(out))) {
    last <- ""
    for (j in seq_len(ncol(out))) {
      if (nzchar(out[i, j])) {
        last <- out[i, j]
      } else if (nzchar(last)) {
        out[i, j] <- last
      }
    }
  }
  out
}

agau_legacy_crop_title_commodity <- function(title) {
  season <- agau_title_season(title)
  if (!identical(season, "not_applicable")) {
    return(paste(tools::toTitleCase(season), "crops"))
  }
  candidates <- c(
    "Wheat", "Barley", "Canola", "Chickpeas", "Faba beans",
    "Field peas", "Lentils", "Lupins", "Oats", "Triticale",
    "Sorghum", "Cotton", "Rice", "Sugarcane", "Maize", "Soybeans"
  )
  hit <- candidates[vapply(candidates, function(candidate) {
    grepl(
      paste0("\\b", gsub(" ", "\\\\s+", candidate), "\\b"),
      title,
      ignore.case = TRUE
    )
  }, logical(1))]
  if (length(hit)) hit[[1]] else "Crops"
}

agau_legacy_crop_column_rows <- function(
    x, meta, sheet, dataset, title, table_id, source_note) {
  header_limit <- seq_len(min(12L, nrow(x)))
  axis_score <- vapply(header_limit, function(i) {
    values <- x[i, ]
    period_values <- vapply(values, agau_legacy_period_token, "")
    sum(
      nzchar(period_values) |
        grepl("\\baverage\\b|^%\\s*change", values, ignore.case = TRUE)
    )
  }, integer(1))
  h <- header_limit[[which.max(axis_score)]]
  axis_labels <- vapply(x[h, ], agau_legacy_period_token, "")
  summary_cols <- grepl(
    "\\baverage\\b|^%\\s*change",
    x[h, ],
    ignore.case = TRUE
  )
  axis_labels[summary_cols] <- x[h, summary_cols]
  pcols <- which(nzchar(axis_labels))
  if (length(pcols) < 2L) return(NULL)

  pre <- if (min(pcols) > 1L) seq_len(min(pcols) - 1L) else integer()
  header_rows <- if (h > 2L) seq.int(2L, h - 1L) else integer()
  expanded <- agau_legacy_crop_forward_headers(x, header_rows, pcols)
  column_measure <- rep("", length(pcols))
  if (nrow(expanded)) {
    for (j in seq_along(pcols)) {
      candidates <- unique(expanded[, j])
      measures <- vapply(candidates, agau_legacy_crop_measure, "")
      measures <- measures[nzchar(measures)]
      if (length(measures)) column_measure[[j]] <- utils::tail(measures, 1L)
    }
  }

  column_unit <- rep("", length(pcols))
  unit_rows <- integer()
  scan_rows <- seq.int(h + 1L, min(nrow(x), h + 4L))
  for (i in scan_rows) {
    candidates <- x[i, pcols]
    hits <- agau_legacy_crop_unit_token(candidates)
    if (any(hits)) {
      column_unit[hits] <- candidates[hits]
      unit_rows <- c(unit_rows, i)
    }
  }
  start <- if (length(unit_rows)) max(unit_rows) + 1L else h + 1L
  current_group <- ""
  rows <- list()

  if (start > nrow(x)) return(rows)
  for (i in seq.int(start, nrow(x))) {
    values <- x[i, ]
    payload <- vapply(values[pcols], agau_legacy_numeric_token, logical(1))
    raw_labels <- if (length(pre)) values[pre] else ""
    row_units <- raw_labels[agau_legacy_crop_unit_token(raw_labels)]
    row_unit <- if (length(row_units)) utils::tail(row_units, 1L) else ""
    labels <- raw_labels[
      nzchar(raw_labels) & !agau_legacy_crop_unit_token(raw_labels)
    ]
    label <- if (length(labels)) {
      agau_legacy_crop_clean_label(paste(unique(labels), collapse = " - "))
    } else {
      ""
    }

    if (!any(payload)) {
      if (nzchar(label) &&
          !grepl("\\b(?:Notes?|Sources?)\\s*:", label, ignore.case = TRUE)) {
        current_group <- label
      }
      next
    }
    if (!nzchar(label)) next

    row_measure <- agau_legacy_crop_measure(label)
    group_is_season <- grepl(
      "^(?:winter|summer) crops?$",
      current_group,
      ignore.case = TRUE
    )
    for (j in which(payload)) {
      col <- pcols[[j]]
      period <- axis_labels[[col]]
      if (!nzchar(period)) next
      unit <- column_unit[[j]]
      if (!nzchar(unit)) unit <- row_unit
      measure <- column_measure[[j]]
      if (nzchar(measure)) {
        commodity <- label
        concept <- measure
      } else if (
        nzchar(current_group) &&
          !group_is_season &&
          (
            nzchar(row_measure) ||
              grepl(
                "\\b(?:prices?|supply|disposal|use)\\b",
                title,
                ignore.case = TRUE
              )
          )
      ) {
        commodity <- current_group
        concept <- if (nzchar(row_measure)) row_measure else label
      } else {
        commodity <- label
        concept <- agau_legacy_crop_concept(unit, row_measure, title)
      }
      if (grepl("^%\\s*change", period, ignore.case = TRUE)) {
        concept <- paste(concept, "change")
        unit <- "%"
        token <- agau_legacy_period_token(period)
        if (nzchar(token)) period <- token
      }
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta = meta, sheet = sheet, table_id = table_id, title = title,
        geography = if (identical(dataset, "crop_report_state")) {
          sheet
        } else {
          "Australia"
        },
        commodity = commodity, concept = concept,
        period = period, unit = unit,
        raw_value = agau_legacy_numeric_raw(values[[col]]),
        dataset = dataset, source_dataset = dataset, sector = "crops",
        season = agau_title_season(title), market = "not_applicable",
        period_basis = "crop_year", source_note = source_note,
        footnote_codes = unique(c(
          agau_footnote_codes(label),
          agau_footnote_codes(period, period = TRUE)
        ))
      )
    }
  }
  rows
}

agau_legacy_crop_row_rows <- function(
    x, meta, sheet, dataset, title, table_id, source_note) {
  period_matrix <- apply(x, 2L, function(values) {
    vapply(values, agau_legacy_period_token, "")
  })
  if (is.null(dim(period_matrix))) {
    period_matrix <- matrix(period_matrix, ncol = ncol(x))
  }
  title_rows <- which(apply(x, 1L, function(values) {
    any(values == title)
  }))
  title_row <- if (length(title_rows)) title_rows[[1]] else 1L
  period_matrix[seq_len(title_row), ] <- ""
  col_scores <- colSums(matrix(
    nzchar(period_matrix),
    nrow = nrow(period_matrix),
    ncol = ncol(period_matrix)
  ))
  pcol <- which.max(col_scores)
  if (!length(pcol) || col_scores[[pcol]] < 2L) return(NULL)
  period_rows <- which(nzchar(period_matrix[, pcol]))
  first_period <- min(period_rows)
  candidate_headers <- if (first_period > title_row + 1L) {
    seq.int(title_row + 1L, first_period - 1L)
  } else {
    integer()
  }
  data_cols <- setdiff(seq_len(ncol(x)), pcol)
  header_rows <- candidate_headers[vapply(candidate_headers, function(i) {
    any(nzchar(x[i, data_cols]))
  }, logical(1))]
  expanded <- agau_legacy_crop_forward_headers(x, header_rows, data_cols)
  header_values <- lapply(seq_along(data_cols), function(j) {
    if (!nrow(expanded)) return(character())
    unique(expanded[, j][nzchar(expanded[, j])])
  })
  header_units <- vapply(header_values, function(values) {
    hits <- values[agau_legacy_crop_unit_token(values)]
    if (length(hits)) utils::tail(hits, 1L) else ""
  }, "")
  header_geography <- vapply(header_values, function(values) {
    combined <- if (length(values) >= 2L) {
      paste(values[-length(values)], values[-1L])
    } else {
      character()
    }
    hits <- vapply(c(combined, values), agau_legacy_crop_geography, "")
    hits <- hits[nzchar(hits)]
    if (length(hits)) hits[[1]] else ""
  }, "")
  header_measure <- vapply(header_values, function(values) {
    hits <- vapply(values, agau_legacy_crop_measure, "")
    hits <- hits[nzchar(hits)]
    if (length(hits)) utils::tail(hits, 1L) else ""
  }, "")
  header_commodity <- vapply(seq_along(header_values), function(j) {
    values <- header_values[[j]]
    if (!length(values)) return("")
    keep <- !vapply(values, agau_legacy_crop_generic_header, logical(1)) &
      !nzchar(vapply(values, agau_legacy_crop_geography, "")) &
      !nzchar(vapply(values, agau_legacy_crop_measure, ""))
    values <- agau_legacy_crop_clean_label(values[keep])
    values <- values[nzchar(values)]
    if (length(values)) utils::tail(values, 1L) else ""
  }, "")

  start <- if (length(header_rows)) {
    max(header_rows) + 1L
  } else {
    title_row + 1L
  }
  current_group <- ""
  carry_year <- ""
  rows <- list()
  for (i in seq.int(start, nrow(x))) {
    row_label <- agau_norm_text(x[i, pcol])
    corrected_provider_period <- identical(
      meta$release_id,
      "acr-2012-06-01-no-162"
    ) &&
      identical(sheet, "Table 13") &&
      grepl("^2019-10\\b", row_label)
    if (corrected_provider_period) {
      row_label <- sub("^2019-10\\b", "2009-10", row_label)
    }
    period <- agau_legacy_period_token(row_label)
    if (grepl("\\baverage\\b", row_label, ignore.case = TRUE)) {
      period <- row_label
    }
    if (grepl("^(?:19|20)[0-9]{2}\\s*Q[1-4]$", period,
        ignore.case = TRUE
    )) {
      carry_year <- substr(period, 1L, 4L)
    } else if (grepl("^Q[1-4]$", period, ignore.case = TRUE) &&
        nzchar(carry_year)) {
      period <- paste(carry_year, toupper(period))
    }
    payload <- vapply(x[i, data_cols], agau_legacy_numeric_token, logical(1))
    if (!nzchar(period)) {
      if (nzchar(row_label) && !any(payload) &&
          !grepl("\\b(?:Notes?|Sources?)\\s*:", row_label, ignore.case = TRUE)) {
        current_group <- agau_legacy_crop_clean_label(row_label)
      }
      next
    }

    row_units <- x[i, data_cols]
    explicit_units <- row_units[agau_legacy_crop_unit_token(row_units)]
    row_unit <- if (length(explicit_units)) explicit_units[[1]] else ""
    for (j in which(payload)) {
      col <- data_cols[[j]]
      raw <- x[i, col]
      unit <- header_units[[j]]
      if (!nzchar(unit)) unit <- row_unit
      geography <- header_geography[[j]]
      if (!nzchar(geography)) geography <- "Australia"
      measure <- header_measure[[j]]
      commodity <- if (nzchar(current_group)) {
        current_group
      } else if (nzchar(header_commodity[[j]])) {
        header_commodity[[j]]
      } else {
        agau_legacy_crop_title_commodity(title)
      }
      concept <- agau_legacy_crop_concept(unit, measure, title)
      if (grepl("^%\\s*change|\\bpercentage change\\b", row_label,
          ignore.case = TRUE
      )) {
        concept <- paste(concept, "change")
        unit <- "%"
      } else if (grepl("\\baverage\\b", row_label, ignore.case = TRUE)) {
        concept <- paste(concept, "average")
      }
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta = meta, sheet = sheet, table_id = table_id, title = title,
        geography = geography, commodity = commodity, concept = concept,
        period = period, unit = unit,
        raw_value = agau_legacy_numeric_raw(raw),
        dataset = dataset, source_dataset = dataset, sector = "crops",
        season = agau_title_season(title), market = "not_applicable",
        period_basis = if (grepl("Q[1-4]", period, ignore.case = TRUE)) {
          "quarter"
        } else {
          "crop_year"
        },
        source_note = source_note,
        footnote_codes = unique(c(
          agau_footnote_codes(current_group),
          agau_footnote_codes(row_label, period = TRUE)
        ))
      )
    }
  }
  rows
}

agau_legacy_crop_snapshot_rows <- function(
    x, meta, sheet, dataset, title, table_id, source_note) {
  period <- agau_legacy_period_token(title)
  if (!nzchar(period)) return(NULL)
  if (grepl("\\bforecast", title, ignore.case = TRUE) &&
      !grepl("[sfz]\\s*$", period, ignore.case = TRUE)) {
    period <- paste0(period, " f")
  } else if (grepl("\\bestimate", title, ignore.case = TRUE) &&
      !grepl("[sfz]\\s*$", period, ignore.case = TRUE)) {
    period <- paste0(period, " s")
  }

  title_rows <- which(apply(x, 1L, function(values) any(values == title)))
  title_row <- if (length(title_rows)) title_rows[[1]] else 1L
  candidate_rows <- if (title_row < nrow(x)) {
    seq.int(title_row + 1L, nrow(x))
  } else {
    integer()
  }
  row_profile <- lapply(candidate_rows, function(i) {
    numeric_cols <- which(vapply(
      x[i, ], agau_legacy_numeric_token, logical(1)
    ))
    first_numeric <- if (length(numeric_cols)) min(numeric_cols) else 1L
    label_cols <- if (first_numeric > 1L) {
      seq_len(first_numeric - 1L)
    } else {
      integer()
    }
    labels <- x[i, label_cols]
    labels <- labels[
      nzchar(labels) &
        !vapply(labels, agau_legacy_numeric_token, logical(1)) &
        !vapply(labels, agau_legacy_crop_generic_header, logical(1))
    ]
    list(numeric_cols = numeric_cols, labels = labels)
  })
  data_rows <- candidate_rows[vapply(row_profile, function(profile) {
    length(profile$numeric_cols) > 0L && length(profile$labels) > 0L
  }, logical(1))]
  if (!length(data_rows)) return(NULL)

  first_data <- min(data_rows)
  header_rows <- if (first_data > title_row + 1L) {
    seq.int(title_row + 1L, first_data - 1L)
  } else {
    integer()
  }
  data_cols <- sort(unique(unlist(lapply(
    row_profile[match(data_rows, candidate_rows)],
    `[[`, "numeric_cols"
  ))))
  if (!length(data_cols)) return(NULL)

  header_values <- lapply(data_cols, function(col) {
    values <- if (length(header_rows)) x[header_rows, col] else character()
    unique(values[nzchar(values)])
  })
  header_units <- vapply(header_values, function(values) {
    hits <- values[agau_legacy_crop_unit_token(values)]
    if (length(hits)) utils::tail(hits, 1L) else ""
  }, "")
  header_measures <- vapply(header_values, function(values) {
    hits <- vapply(values, agau_legacy_crop_measure, "")
    hits <- hits[nzchar(hits)]
    if (length(hits)) utils::tail(hits, 1L) else ""
  }, "")
  geography <- if (identical(dataset, "crop_report_state")) {
    sheet
  } else {
    agau_legacy_crop_title_geography(title)
  }

  rows <- list()
  for (i in data_rows) {
    profile <- row_profile[[match(i, candidate_rows)]]
    commodity <- agau_legacy_crop_clean_label(
      paste(unique(profile$labels), collapse = " - ")
    )
    if (!nzchar(commodity)) next
    for (col in intersect(profile$numeric_cols, data_cols)) {
      j <- match(col, data_cols)
      unit <- header_units[[j]]
      measure <- header_measures[[j]]
      concept <- agau_legacy_crop_concept(unit, measure, title)
      if (!nzchar(measure) &&
          identical(tolower(concept), "published measure")) {
        next
      }
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta = meta, sheet = sheet, table_id = table_id, title = title,
        geography = geography, commodity = commodity, concept = concept,
        period = period, unit = unit,
        raw_value = agau_legacy_numeric_raw(x[i, col]),
        dataset = dataset, source_dataset = dataset, sector = "crops",
        season = agau_title_season(title), market = "not_applicable",
        period_basis = "crop_year", source_note = source_note,
        footnote_codes = unique(c(
          agau_footnote_codes(commodity),
          agau_footnote_codes(header_values[[j]])
        ))
      )
    }
  }
  rows
}

agau_legacy_crop_sheet_rows <- function(x, meta, sheet, dataset) {
  x <- apply(x, 2L, agau_norm_text)
  populated_rows <- which(rowSums(matrix(
    nzchar(x),
    nrow = nrow(x),
    ncol = ncol(x)
  )) > 0L)
  top_rows <- seq_len(min(12L, nrow(x)))
  title_hits <- matrix(
    grepl(
      "^(?:Table\\s*)?[0-9]{1,2}\\s+[A-Za-z]",
      x[top_rows, , drop = FALSE],
      ignore.case = TRUE
    ),
    nrow = length(top_rows),
    ncol = ncol(x)
  )
  title_candidates <- which(
    title_hits,
    arr.ind = TRUE
  )
  if (nrow(title_candidates)) {
    title_row <- top_rows[title_candidates[1L, "row"]]
    title_cells <- x[
      title_row,
      title_candidates[title_candidates[, "row"] == title_candidates[1L, "row"],
        "col"
      ]
    ]
  } else {
    title_row <- if (length(populated_rows)) populated_rows[[1]] else 1L
    title_cells <- x[title_row, nzchar(x[title_row, ])]
  }
  title <- if (length(title_cells)) {
    title_cells[[1]]
  } else {
    agau_legacy_title(x, sheet)
  }
  table_id <- paste0("legacy_", agau_slug(sheet))
  source_note <- agau_extract_sheet_note(x)
  if (!nzchar(source_note)) {
    source_note <- paste(
      "Deterministic extraction from the official legacy workbook;",
      "source sheet headers, units and published periods are retained."
    )
  }
  row_counts <- apply(x, 1L, function(values) {
    period_values <- vapply(values, agau_legacy_period_token, "")
    sum(
      nzchar(period_values) |
        grepl("\\baverage\\b|^%\\s*change", values, ignore.case = TRUE)
    )
  })
  row_axis_labels <- vapply(x[, 1L], agau_legacy_period_token, "")
  row_counts[nzchar(row_axis_labels)] <- 0L
  column_counts <- apply(x, 2L, function(values) {
    sum(vapply(values, agau_legacy_period_token, "") != "")
  })
  rows <- if (max(row_counts, 0L) >= 2L) {
    agau_legacy_crop_column_rows(
      x, meta, sheet, dataset, title, table_id, source_note
    )
  } else if (max(column_counts, 0L) >= 2L) {
    agau_legacy_crop_row_rows(
      x, meta, sheet, dataset, title, table_id, source_note
    )
  } else {
    NULL
  }
  if (is.null(rows) || !length(rows)) {
    rows <- agau_legacy_crop_snapshot_rows(
      x, meta, sheet, dataset, title, table_id, source_note
    )
  }
  if (is.null(rows) || !length(rows)) {
    return(list())
  }
  rows
}

agau_legacy_sheet_rows <- function(x, meta, sheet, product, dataset) {
  if (identical(product, "crop_report")) {
    return(agau_legacy_crop_sheet_rows(x, meta, sheet, dataset))
  }
  x <- apply(x, 2L, agau_norm_text)
  title <- agau_legacy_title(x, sheet)
  table_id <- paste0("legacy_", agau_slug(sheet))
  source_note <- agau_extract_sheet_note(x)
  if (!nzchar(source_note)) {
    source_note <- paste(
      "Deterministic extraction from the official legacy workbook;",
      "source sheet labels and published period positions are retained."
    )
  }
  current_period <- rep("", ncol(x))
  current_group <- ""
  rows <- list()

  for (i in seq_len(nrow(x))) {
    values <- x[i, ]
    period_cells <- vapply(values, agau_legacy_period_token, "")
    period_cols <- which(nzchar(period_cells))
    payload <- which(vapply(values, agau_legacy_numeric_token, logical(1)))

    if (length(period_cols) >= 2L &&
        length(period_cols) >= max(2L, length(payload))) {
      current_period[period_cols] <- period_cells[period_cols]
      next
    }

    if (length(payload) < 2L) {
      text <- values[
        nzchar(values) &
          !vapply(values, agau_legacy_numeric_token, logical(1)) &
          !grepl(
            "^(?:Notes?|Sources?|continued|Table\\s+[0-9]+|Index)$",
            values, ignore.case = TRUE
          )
      ]
      text <- text[
        !grepl("\\b(?:ABARE|ABARES|page)\\b", text, ignore.case = TRUE)
      ]
      if (length(text)) current_group <- utils::tail(text, 1L)
      next
    }

    first_payload <- min(payload)
    labels <- if (first_payload > 1L) values[seq_len(first_payload - 1L)] else ""
    labels <- labels[nzchar(labels)]
    labels <- labels[
      !grepl(
        paste0(
          "^(?:A?US?\\$|%|index|'?000 ha|ha|tonnes?|kt|mt|t/ha|c/kg|",
          "c/l|million|billion|number|head)$"
        ),
        labels, ignore.case = TRUE
      )
    ]
    label <- if (length(labels)) paste(unique(labels), collapse = " - ") else ""
    if (!nzchar(label)) {
      label <- if (nzchar(current_group)) current_group else paste("source row", i)
    }
    corrected_label <- label
    corrected_provider_period <- product == "crop_report" &&
      identical(meta$release_id, "acr-2012-06-01-no-162") &&
      identical(sheet, "Table 13") &&
      grepl("^2019-10\\b", corrected_label)
    if (corrected_provider_period) {
      corrected_label <- sub(
        "^2019-10\\b", "2009-10", corrected_label
      )
      source_note <- paste(
        source_note,
        "The provider's `2019-10` row label in Table 13 is normalised to",
        "`2009-10` by the audited sequential-period correction."
      )
    }
    row_period <- if (grepl("\\baverage\\b", corrected_label, ignore.case = TRUE)) {
      corrected_label
    } else {
      agau_legacy_period_token(corrected_label)
    }
    periods <- vapply(payload, function(col) {
      if (nzchar(row_period)) return(row_period)
      if (nzchar(current_period[[col]])) return(current_period[[col]])
      left <- current_period[seq_len(col)]
      left <- left[nzchar(left)]
      if (length(left)) return(utils::tail(left, 1L))
      title_period <- agau_legacy_period_token(title)
      if (nzchar(title_period)) return(title_period)
      paste(format(as.Date(meta$release_date), "%B %Y"), "edition")
    }, "")
    period_occurrence <- stats::ave(
      seq_along(periods), periods,
      FUN = function(z) seq_along(z)
    )
    unit <- agau_legacy_unit(c(labels, values))
    row_label <- trimws(sub(
      "^(?:19|20)[0-9]{2}-(?:[0-9]{2}|[0-9]{4})(?:\\s*[sfz])?\\s*",
      "", corrected_label, ignore.case = TRUE
    ))
    if (!nzchar(row_label)) row_label <- "published value"
    commodity <- if (nzchar(row_period) && nzchar(current_group)) {
      current_group
    } else {
      label
    }
    geography <- if (
      product == "crop_report" && dataset == "crop_report_state"
    ) {
      sheet
    } else if (
      product == "agricultural_commodities" &&
        grepl("\\bworld\\b", paste(title, current_group), ignore.case = TRUE)
    ) {
      "World"
    } else {
      "Australia"
    }
    market <- if (geography == "World") "world" else if (
      product == "agricultural_commodities"
    ) {
      "Australia"
    } else {
      "not_applicable"
    }

    for (j in seq_along(payload)) {
      col <- payload[[j]]
      concept <- paste0(
        row_label, " - published value ",
        sprintf("%02d", period_occurrence[[j]])
      )
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta = meta, sheet = sheet, table_id = table_id, title = title,
        geography = geography, commodity = commodity, concept = concept,
        period = periods[[j]], unit = unit,
        raw_value = agau_legacy_numeric_raw(values[[col]]),
        dataset = dataset, source_dataset = dataset,
        sector = if (product == "crop_report") "crops" else "agriculture",
        season = agau_title_season(paste(title, current_group)),
        market = market,
        period_basis = if (product == "crop_report") "crop_year" else NULL,
        source_note = source_note,
        footnote_codes = unique(c(
          agau_footnote_codes(label),
          agau_footnote_codes(periods[[j]], period = TRUE)
        ))
      )
    }
  }
  rows
}

agau_parse_legacy_workbook <- function(path, meta, product, dataset,
                                       sheets = "all") {
  staged <- agau_readxl_path(path)
  if (!identical(staged, path)) on.exit(unlink(staged), add = TRUE)
  available <- readxl::excel_sheets(staged)
  available <- available[
    !grepl(
      "^(?:index|notes|contents|sheet[0-9]*)$",
      available, ignore.case = TRUE
    )
  ]
  if (!identical(sheets, "all")) available <- intersect(available, sheets)
  if (!length(available)) {
    agau_abort(
      "agau_schema_error",
      "No requested legacy data sheets were found.",
      product = product, release_id = meta$release_id,
      remediation = "Inspect the official workbook attachment and sheet profile."
    )
  }
  rows <- unlist(lapply(available, function(sheet) {
    x <- agau_sheet_matrix(path, sheet)
    if (!nrow(x) || !ncol(x)) return(list())
    agau_legacy_sheet_rows(x, meta, sheet, product, dataset)
  }), recursive = FALSE)
  if (!length(rows)) {
    agau_abort(
      "agau_schema_error",
      "The legacy workbook profile produced no numeric observations.",
      product = product, release_id = meta$release_id,
      remediation = "Review the workbook row and period fingerprints."
    )
  }
  cls <- switch(product,
    crop_report = "crop_report_data",
    agricultural_commodities = "agricultural_commodities_data",
    "agau_data"
  )
  agau_bind_observations(rows, cls)
}

agau_pdftotext <- function(path) {
  executable <- Sys.which("pdftotext")
  if (!nzchar(executable)) {
    agau_abort(
      "agau_dependency_error",
      "Historical PDF extraction requires the Poppler `pdftotext` command.",
      remediation = "Install Poppler, then retry the two 2010 PDF-backed editions."
    )
  }
  target <- tempfile(fileext = ".txt")
  on.exit(if (file.exists(target)) unlink(target), add = TRUE)
  status <- suppressWarnings(system2(
    executable, c("-layout", shQuote(path), shQuote(target)),
    stdout = FALSE, stderr = FALSE
  ))
  if (!identical(status, 0L) || !file.exists(target)) {
    agau_abort(
      "agau_table_parse_error",
      "Poppler could not extract text from the official report PDF.",
      remediation = "Verify the cached PDF bytes and Poppler installation."
    )
  }
  readLines(target, warn = FALSE, encoding = "UTF-8")
}

agau_legacy_pdf_matrix <- function(lines) {
  cells <- strsplit(lines, "\\s{2,}", perl = TRUE)
  width <- max(lengths(cells), 1L)
  out <- matrix("", nrow = length(cells), ncol = width)
  for (i in seq_along(cells)) {
    value <- agau_norm_text(cells[[i]])
    out[i, seq_along(value)] <- value
  }
  out
}

agau_legacy_pdf_values <- function(x) {
  hit <- regmatches(
    x,
    gregexpr(
      "(?<![[:alnum:]])(?:[-\u2013]\\s*)?(?:[0-9]{1,3}(?:\\s[0-9]{3})+|[0-9]+(?:\\.[0-9]+)?|na)(?![[:alnum:]])",
      x, perl = TRUE, ignore.case = TRUE
    )
  )[[1]]
  if (length(hit) == 1L && identical(hit, character(0))) return(character())
  gsub("\\s+", "", trimws(gsub("\u2013", "-", hit, fixed = TRUE)))
}

agau_parse_2010_outlook_indicators <- function(page, meta) {
  release_date <- as.Date(meta$release_date)
  profile <- if (identical(release_date, as.Date("2010-03-01"))) {
    list(
      periods = paste0(2007:2014, "-", sprintf("%02d", 8:15)),
      statuses = c("", "", "f", "f", "z", "z", "z", "z"),
      changes = character()
    )
  } else if (identical(release_date, as.Date("2010-06-01"))) {
    list(
      periods = paste0(2005:2010, "-", sprintf("%02d", 6:11)),
      statuses = c("", "", "", "", "s", "f"),
      changes = c("2009-10", "2010-11")
    )
  } else {
    agau_abort(
      "agau_table_parse_error",
      "No audited PDF table profile exists for this Agricultural Commodities edition.",
      product = "agricultural_commodities", release_id = meta$release_id,
      remediation = "Use the official outlook workbook attachment."
    )
  }
  x <- agau_legacy_pdf_matrix(strsplit(page, "\n", fixed = TRUE)[[1]])
  start <- which(grepl(
    "Major indicators of Australia.*commodit", x[, 1], ignore.case = TRUE
  ))[[1]]
  stop <- which(
    seq_len(nrow(x)) > start &
      grepl("^[a-z] (?:In |Base:|For )", x[, 1], ignore.case = TRUE)
  )
  stop <- if (length(stop)) stop[[1]] - 1L else nrow(x)
  units <- c(
    "US$/A$", "A$m", "index", "'000 ha", "\u2019000 ha", "million",
    "'000", "\u2019000"
  )
  current_group <- "Commodity indicators"
  current_item <- ""
  rows <- list()
  n_levels <- length(profile$periods)

  for (i in seq.int(start + 1L, stop)) {
    label <- agau_norm_text(x[i, 1])
    rest <- agau_norm_text(paste(x[i, -1], collapse = " "))
    unit <- units[vapply(units, function(u) grepl(u, rest, fixed = TRUE), logical(1))]
    unit <- if (length(unit)) unit[[1]] else ""
    values <- agau_legacy_pdf_values(if (nzchar(unit)) {
      sub(unit, "", rest, fixed = TRUE)
    } else {
      rest
    })

    if (!nzchar(label)) next
    if (!nzchar(unit)) {
      if (!grepl(
        "^(?:change from|previous year|unit|%|Notes?|Sources?)$",
        label, ignore.case = TRUE
      )) {
        current_group <- label
        current_item <- ""
      }
      next
    }
    if (length(values) < n_levels) next

    subordinate <- grepl("^[-\u2013]", label)
    clean_label <- trimws(sub("^[-\u2013]\\s*", "", label))
    if (!subordinate) current_item <- clean_label
    commodity <- paste(
      current_group,
      if (subordinate && nzchar(current_item)) current_item else clean_label,
      sep = " - "
    )
    concepts <- c(
      rep(if (subordinate) clean_label else "published level", n_levels),
      rep("change from previous year", length(profile$changes))
    )
    periods <- c(
      paste(profile$periods, profile$statuses),
      profile$changes
    )
    output_units <- c(
      rep(unit, n_levels),
      rep("%", length(profile$changes))
    )
    values <- utils::head(values, length(periods))
    for (j in seq_along(values)) {
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta = meta, sheet = "Major indicators",
        table_id = "ac_outlook_major_indicators",
        title = "Major indicators of Australia's commodity sector",
        geography = "Australia", commodity = commodity,
        concept = concepts[[j]], period = periods[[j]],
        unit = output_units[[j]], raw_value = values[[j]],
        dataset = "commodities_outlook",
        source_dataset = "commodities_outlook", sector = "agriculture",
        season = "not_applicable", market = "Australia",
        period_basis = "fiscal_year",
        source_note = paste(
          "Major indicators table extracted deterministically from the",
          "official report-backed Agricultural Commodities edition."
        )
      )
    }
  }
  rows
}

agau_parse_legacy_pdf <- function(path, meta, product, dataset) {
  if (product != "agricultural_commodities" ||
      dataset != "commodities_outlook") {
    agau_abort(
      "agau_table_parse_error",
      "PDF table extraction is available only for report-backed Agricultural Commodities outlook editions.",
      product = product, release_id = meta$release_id,
      remediation = "Use the official Crop Report workbook attachments."
    )
  }
  pages <- strsplit(paste(agau_pdftotext(path), collapse = "\n"), "\f",
    fixed = TRUE
  )[[1]]
  keep <- vapply(
    pages,
    grepl, logical(1),
    pattern = "Major indicators of Australia.*commodit",
    ignore.case = TRUE
  )
  selected <- which(keep)
  rows <- unlist(lapply(selected, function(page) {
    agau_parse_2010_outlook_indicators(pages[[page]], meta)
  }), recursive = FALSE)
  if (!length(rows)) {
    agau_abort(
      "agau_schema_error",
      "The report-backed Agricultural Commodities edition produced no outlook observations.",
      product = product, release_id = meta$release_id,
      remediation = "Review the archived PDF table extraction profile."
    )
  }
  agau_bind_observations(rows, "agricultural_commodities_data")
}

agau_parse_legacy_cached <- function(path, meta, product, dataset, cache_dir,
                                     sheets = "all") {
  sheet_key <- if (identical(sheets, "all")) {
    "all"
  } else {
    paste(sort(sheets), collapse = "_")
  }
  key <- agau_parsed_cache_key(
    product, meta$release_id, meta$sha256, dataset,
    paste0("legacy_", sheet_key)
  )
  target <- file.path(
    cache_dir, "parsed", product, meta$release_id,
    agau_parser_version(), key, "reported.rds"
  )
  if (file.exists(target)) {
    cached <- tryCatch(readRDS(target), error = function(e) NULL)
    if (!is.null(cached)) return(cached)
  }
  out <- if (agau_detect_format(path) == "pdf") {
    agau_parse_legacy_pdf(path, meta, product, dataset)
  } else {
    agau_parse_legacy_workbook(path, meta, product, dataset, sheets)
  }
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".agau-legacy-", tmpdir = dirname(target))
  on.exit(if (file.exists(stage)) unlink(stage), add = TRUE)
  saveRDS(out, stage, version = 3)
  readRDS(stage)
  if (!file.rename(stage, target) && !file.exists(target)) {
    agau_abort(
      "agau_validation_error",
      "Atomic legacy parsed-cache write failed.",
      product = product, release_id = meta$release_id,
      remediation = "Check cache permissions."
    )
  }
  out
}
