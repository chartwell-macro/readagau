agau_sheet_matrix <- function(path, sheet) {
  staged <- agau_readxl_path(path)
  if (!identical(staged, path)) on.exit(unlink(staged), add = TRUE)
  read_sheet <- function(n_max = Inf) suppressMessages(readxl::read_excel(
    staged, sheet = sheet, col_names = FALSE, col_types = "text",
    n_max = n_max, .name_repair = "minimal"
  ))
  probe_limit <- 2048L
  x <- read_sheet(probe_limit)
  boundary <- if (nrow(x) >= probe_limit) {
    utils::tail(x, min(8L, nrow(x)))
  } else {
    x[0L, , drop = FALSE]
  }
  boundary_has_data <- nrow(boundary) &&
    any(nzchar(agau_norm_text(as.vector(as.matrix(boundary)))))
  if (boundary_has_data) x <- read_sheet()
  x <- as.matrix(x)
  if (!nrow(x) || !ncol(x)) {
    return(matrix("", nrow = 0L, ncol = 0L))
  }
  x[is.na(x)] <- ""
  x <- matrix(
    agau_norm_text(as.vector(x)),
    nrow = nrow(x), ncol = ncol(x)
  )
  present <- matrix(nzchar(x), nrow = nrow(x), ncol = ncol(x))
  nonempty_rows <- which(rowSums(present) > 0L)
  nonempty_cols <- which(colSums(present) > 0L)
  if (!length(nonempty_rows) || !length(nonempty_cols)) {
    return(matrix("", nrow = 0L, ncol = 0L))
  }
  x[
    seq_len(max(nonempty_rows)),
    seq_len(max(nonempty_cols)),
    drop = FALSE
  ]
}

agau_extract_sheet_note <- function(x) {
  cells <- agau_norm_text(as.vector(x))
  cells <- cells[nzchar(cells)]
  notes <- cells[grepl(
    "\\b(notes?|sources?|methodology|definitions?)\\s*:",
    cells, ignore.case = TRUE
  )]
  paste(unique(notes), collapse = "\n")
}

agau_forward_headers <- function(x, rows, cols) {
  if (!length(rows)) return(matrix("", nrow = 0L, ncol = length(cols)))
  out <- x[rows, cols, drop = FALSE]
  for (i in seq_len(nrow(out))) {
    last <- ""
    for (j in seq_len(ncol(out))) {
      if (nzchar(out[i, j])) last <- out[i, j] else out[i, j] <- last
    }
  }
  out
}

agau_outlook_sheet_id <- function(sheet) {
  slug <- agau_slug(sheet)
  aliases <- c(
    beef_and_cattle = "beef_cattle",
    beef_and_veal = "beef_cattle",
    lamb_sheep_and_wool = "lamb_sheep_wool",
    natural_fibres = "cotton",
    sheepmeat = "lamb_sheep_wool",
    sheep_meat = "lamb_sheep_wool",
    pig = "pigs",
    ppe = "pigs_poultry_eggs",
    pigs_poultry_and_eggs = "pigs_poultry_eggs",
    fisheries = "fisheries_aquaculture_forestry"
  )
  unname(aliases[slug]) %||% slug
}

agau_table_id <- function(product, dataset, sheet) {
  if (product == "crop_report" && dataset == "crop_report_state") {
    return(paste0("crop_state_", agau_slug(sheet)))
  }
  if (product == "crop_report") {
    n <- suppressWarnings(as.integer(sub(".*?([0-9]+).*", "\\1", sheet)))
    return(sprintf("crop_national_table_%02d", n))
  }
  if (dataset == "commodity_statistics") {
    n <- suppressWarnings(as.integer(sub(".*?([0-9]+).*", "\\1", sheet)))
    return(sprintf("acs_table_%02d", n))
  }
  if (product == "agricultural_commodities") {
    return(paste0("ac_outlook_", agau_outlook_sheet_id(sheet)))
  }
  if (product == "farm_productivity") return(paste0("productivity_", agau_slug(sheet)))
  agau_slug(sheet)
}

agau_expected_sheet_profiles <- function(product, dataset) {
  if (product == "crop_report" && dataset == "crop_report_national") {
    return(list(paste("Table", 1:17)))
  }
  if (product == "crop_report" && dataset == "crop_report_state") {
    return(list(c(
      "Australia", "New South Wales", "Queensland", "South Australia",
      "Tasmania", "Victoria", "Western Australia"
    )))
  }
  if (dataset == "commodity_statistics") {
    return(list(
      paste("Table", 1:18),
      paste("Table", 1:27)
    ))
  }
  if (dataset == "commodities_outlook") {
    return(list(
      c(
        "Key macro", "Major indicators", "Beef and cattle", "Chicken",
        "Coarse grains", "Cotton", "Dairy", "Fisheries", "Horticulture",
        "Oilseeds", "Pig", "Lamb sheep and wool", "Sugar", "Wheat", "Wine"
      ),
      c(
        "Key macro", "Major indicators", "Beef and cattle", "Coarse grains",
        "Cotton", "Dairy", "Fisheries", "Lamb sheep and wool", "Oilseeds",
        "Pigs poultry and eggs", "Sugar", "Wheat", "Wine"
      ),
      c(
        "Key macro", "Major indicators", "Beef and cattle", "Coarse grains",
        "Cotton", "Dairy", "Fisheries", "Lamb sheep and wool", "Oilseeds",
        "Sugar", "Wheat", "Wine"
      )
    ))
  }
  NULL
}

agau_profile_sheet_token <- function(sheet, dataset) {
  if (dataset == "commodities_outlook") return(agau_outlook_sheet_id(sheet))
  token <- agau_slug(sheet)
  aliases <- c(
    newsouthwales = "new_south_wales",
    southaustralia = "south_australia",
    westernaustralia = "western_australia"
  )
  unname(aliases[token]) %||% token
}

agau_validate_workbook_sheets <- function(available, meta, product, dataset) {
  profiles <- agau_expected_sheet_profiles(product, dataset)
  if (is.null(profiles)) return(invisible(TRUE))
  got <- unname(sort(vapply(
    available, agau_profile_sheet_token, "", dataset = dataset
  )))
  expected <- lapply(profiles, function(profile) {
    unname(sort(vapply(
      profile, agau_profile_sheet_token, "", dataset = dataset
    )))
  })
  matched <- vapply(expected, function(x) {
    length(got) == length(x) && setequal(got, x)
  }, logical(1))
  if (!any(matched)) {
    missing <- lapply(expected, setdiff, y = got)
    extra <- lapply(expected, function(x) setdiff(got, x))
    best <- which.min(vapply(missing, length, integer(1)) +
      vapply(extra, length, integer(1)))
    agau_abort(
      "agau_schema_error",
      paste0(
        "Workbook sheet set does not match an admitted ", dataset,
        " profile. Missing: ", paste(missing[[best]], collapse = ", "),
        "; unexpected: ", paste(extra[[best]], collapse = ", "), "."
      ),
      product = product, release_id = meta$release_id,
      remediation = "Review and version the workbook sheet profile before parsing."
    )
  }
  invisible(TRUE)
}

agau_validate_sheet_fingerprint <- function(x, meta, sheet, table_id,
                                            title, product, dataset) {
  if (product == "crop_report" && dataset == "crop_report_national") {
    expected_number <- as.integer(sub(".*_([0-9]+)$", "\\1", table_id))
    title_number <- suppressWarnings(as.integer(sub(
      "^\\s*Table\\s+([0-9]+).*$", "\\1", title, ignore.case = TRUE
    )))
    if (is.na(title_number) || title_number != expected_number) {
      agau_abort(
        "agau_schema_error",
        paste("Sheet", sheet, "does not retain its admitted table title/number."),
        product = product, release_id = meta$release_id, source_sheet = sheet,
        table_id = table_id,
        remediation = "Review the renamed or moved table before updating the profile."
      )
    }
  }
  if (dataset == "commodity_statistics") {
    all_text <- agau_norm_text(as.vector(x[seq_len(min(5L, nrow(x))), , drop = FALSE]))
    expected_number <- as.integer(sub(".*_([0-9]+)$", "\\1", table_id))
    numbered <- all_text[grepl(paste0("^", expected_number, "(?:\\b|(?=[A-Za-z]))"),
      all_text, perl = TRUE
    )]
    if (!length(numbered)) {
      agau_abort(
        "agau_schema_error",
        paste("Statistics sheet", sheet, "has no admitted numbered title."),
        product = product, release_id = meta$release_id, source_sheet = sheet,
        table_id = table_id,
        remediation = "Review the statistics title fingerprint."
      )
    }
  }
  if (!product %in% c("crop_report", "agricultural_commodities")) {
    return(invisible(TRUE))
  }
  matrix_snapshot <- product == "crop_report" &&
    grepl("^crop_national_table_(0[4-9]|10)$", table_id)
  first_rows <- x[seq_len(min(10L, nrow(x))), , drop = FALSE]
  period_axis <- any(apply(first_rows, 1L, function(z) {
    sum(agau_period_like(z, short_quarter = TRUE)) >= 2L
  })) || any(colSums(apply(
    first_rows, 2L, agau_period_like, short_quarter = TRUE
  )) >= 2L)
  if (!matrix_snapshot && !period_axis) {
    agau_abort(
      "agau_schema_error",
      paste("Period header for", sheet, "is absent or outside the admitted header region."),
      product = product, release_id = meta$release_id, source_sheet = sheet,
      table_id = table_id,
      remediation = "Review a moved-header schema before parsing numeric cells."
    )
  }
  invisible(TRUE)
}

agau_assert_payload_count <- function(rows, expected, meta, sheet, table_id) {
  if (length(rows) != expected) {
    agau_abort(
      "agau_schema_error",
      paste0(
        "Numeric payload accounting failed for ", sheet, ": parsed ",
        length(rows), " of ", expected, " non-empty payload cells."
      ),
      product = meta$product, release_id = meta$release_id,
      source_sheet = sheet, table_id = table_id,
      remediation = "Review unlabeled rows, merged headers, and control-cell rules."
    )
  }
  invisible(TRUE)
}

agau_title_season <- function(title) {
  if (grepl("winter", title, ignore.case = TRUE)) "winter" else if (grepl("summer", title, ignore.case = TRUE)) "summer" else "not_applicable"
}

agau_strip_footnote_suffix <- function(x) {
  trimws(sub("\\s+[a-k]{1,3}$", "", agau_norm_text(x), ignore.case = TRUE))
}

agau_acs_period_basis <- function(table_id, label, group, period) {
  codes <- agau_footnote_codes(c(label, group))
  if (table_id == "acs_legacy_table_07") return("month")
  if (table_id %in% c("acs_table_05", "acs_legacy_table_09")) {
    if (any(codes %in% c("c", "e"))) return("august_july")
    if ("g" %in% codes) return("october_september")
    return("published_year")
  }
  if (table_id %in% c("acs_table_07", "acs_legacy_table_11")) {
    if ("e" %in% codes) return("calendar_year")
    if ("g" %in% codes) return("august_july")
    if ("h" %in% codes) return("october_september")
    return("marketing_year")
  }
  "financial_year"
}

agau_acs_family <- function(table_id) {
  families <- c(
    acs_table_01 = "farmers terms of trade",
    acs_table_02 = "farm costs and returns",
    acs_table_03 = "farm production indicator",
    acs_table_04 = "agricultural export indicator",
    acs_table_05 = "world indicator price",
    acs_table_06 = "gross unit value",
    acs_table_07 = "world balance",
    acs_table_08 = "Australian production",
    acs_table_09 = "gross value of production",
    acs_table_10 = "production area and livestock numbers",
    acs_table_11 = "yield",
    acs_table_12 = "export volume",
    acs_table_13 = "export value",
    acs_table_14 = "fisheries export volume",
    acs_table_15 = "fisheries export value",
    acs_table_16 = "fisheries import volume",
    acs_table_17 = "fisheries import value",
    acs_table_18 = "selected-country fisheries trade",
    acs_legacy_table_01 = "farmers terms of trade",
    acs_legacy_table_02 = "farm costs and returns",
    acs_legacy_table_03 = "farm production indicator",
    acs_legacy_table_04 = "agricultural export indicator",
    acs_legacy_table_05 = "farm production volume index",
    acs_legacy_table_06 = "employment",
    acs_legacy_table_07 = "business lending",
    acs_legacy_table_08 = "rural indebtedness",
    acs_legacy_table_09 = "world indicator price",
    acs_legacy_table_10 = "gross unit value",
    acs_legacy_table_11 = "world balance",
    acs_legacy_table_12 = "Australian production",
    acs_legacy_table_13 = "gross value of production",
    acs_legacy_table_14 = "production area and livestock numbers",
    acs_legacy_table_15 = "yield",
    acs_legacy_table_16 = "export volume",
    acs_legacy_table_17 = "export value",
    acs_legacy_table_18 = "fisheries export volume",
    acs_legacy_table_19 = "fisheries export value",
    acs_legacy_table_20 = "fisheries import volume",
    acs_legacy_table_21 = "fisheries import value",
    acs_legacy_table_22 = "selected-country fisheries trade",
    acs_legacy_table_23 = "forest products export volume",
    acs_legacy_table_24 = "forest products export value",
    acs_legacy_table_25 = "forest products import volume",
    acs_legacy_table_26 = "forest products import value",
    acs_legacy_table_27 = "selected-country forest products trade"
  )
  unname(families[table_id]) %||% "published statistic"
}

agau_payload_token <- function(x) {
  token <- tolower(agau_norm_text(x))
  numeric <- !is.na(suppressWarnings(as.numeric(
    gsub(",", "", token, fixed = TRUE)
  )))
  missing <- token %in% c(
    "na", "n/a", "not applicable", "not available", "unavailable",
    "nr", "not reported", "confidential", "c", "suppressed", "..", "-"
  )
  nzchar(token) & (numeric | missing)
}

agau_title_concept <- function(title) {
  x <- tolower(title)
  if (grepl("productivity growth", x)) return("productivity growth rate")
  if (grepl("input growth", x)) return("input growth rate")
  if (grepl("output growth", x)) return("output growth rate")
  if (grepl("productivity index", x)) return("total factor productivity index")
  if (grepl("production and area|area and production", x)) return("published measure")
  if (grepl("production", x)) return("production")
  if (grepl("area", x)) return("area")
  if (grepl("price", x)) return("price")
  "published measure"
}

agau_title_industry <- function(title) {
  comma <- strsplit(title, ",", fixed = TRUE)[[1]]
  candidates <- trimws(comma)
  hit <- candidates[grepl("All industries|Cropping|Mixed|Sheep-Beef|Sheep|Beef|Dairy", candidates, ignore.case = TRUE)]
  if (length(hit)) sub("^.*? - ", "", hit[1]) else if (grepl("Dairy", title, ignore.case = TRUE)) "Dairy" else "All industries"
}

agau_infer_basis <- function(product, dataset, title, period) {
  if (grepl("Q[1-4]", period, ignore.case = TRUE)) return("quarter")
  if (grepl("marketing year", title, ignore.case = TRUE)) return("marketing_year")
  if (product == "crop_report") return("crop_year")
  if (product == "farm_productivity") return("financial_year")
  if (dataset == "commodity_statistics") return("financial_year")
  if (grepl("^[0-9]{4}-(?:[0-9]{2}|[0-9]{4})", period)) return("financial_year")
  if (grepl("macro|calendar", title, ignore.case = TRUE)) return("calendar_year")
  "financial_year"
}

agau_concept_from_unit <- function(unit, fallback) {
  u <- tolower(unit)
  if (grepl("ha", u)) "area" else if (grepl("kt|mt|tonne|kg", u)) {
    if (grepl("price", fallback, ignore.case = TRUE)) "price" else "production"
  } else fallback
}

agau_parse_column_periods <- function(x, meta, sheet, table_id, title,
                                      product, dataset) {
  scores <- apply(x[seq_len(min(10L, nrow(x))), , drop = FALSE], 1L,
    function(z) sum(agau_period_like(z))
  )
  h <- which.max(scores)
  pcols <- which(agau_period_like(x[h, ]) | grepl("^%\\s*change", x[h, ], ignore.case = TRUE))
  pre <- seq_len(min(pcols) - 1L)
  outside <- setdiff(seq_len(ncol(x)), c(pre, pcols))
  if (length(outside) && h < nrow(x)) {
    data_rows <- seq.int(h + 1L, nrow(x))
    unmapped <- outside[vapply(outside, function(col) {
      any(agau_payload_token(x[data_rows, col]))
    }, logical(1))]
    if (length(unmapped)) {
      header <- agau_norm_text(x[h, unmapped[1]])
      agau_abort(
        "agau_schema_error",
        paste(
          "Numeric or provider-missing payload exists outside the admitted period grid in",
          sheet, "column", unmapped[1],
          if (nzchar(header)) paste0(" (`", header, "`)") else ""
        ),
        product = product, release_id = meta$release_id,
        source_sheet = sheet, table_id = table_id,
        remediation = paste(
          "Review and map the new numeric column or block before admitting",
          "this workbook profile."
        )
      )
    }
  }
  rows <- list()
  payload_count <- 0L
  group <- ""
  group_raw <- ""
  outlook_geo <- ""
  outlook_commodity <- ""
  outlook_measure <- ""
  outlook_flow <- ""
  outlook_section <- ""
  outlook_parent <- ""
  stats_sector <- ""
  stats_sector_raw <- ""
  stats_commodity <- ""
  last_data_label <- ""
  period_labels <- x[h, pcols]
  period_units <- rep("", length(pcols))
  sheet_note <- agau_extract_sheet_note(x)
  if (!nzchar(sheet_note)) sheet_note <- meta$workbook_note %||% ""
  sheet_commodity <- agau_norm_text(gsub("[,&]", " ", sheet))
  sheet_commodity <- agau_norm_text(gsub("\\band\\b", "and", sheet_commodity, ignore.case = TRUE))
  for (i in seq.int(h + 1L, nrow(x))) {
    vals <- x[i, pcols]
    labels <- x[i, pre]
    label <- labels[which(nzchar(labels))[1]] %||% ""
    has_payload <- any(nzchar(vals))
    period_flags <- agau_period_like(vals)
    period_tokens <- vals[period_flags]
    repeated_period_header <- sum(period_flags) >= 2L &&
      sum(period_flags) / max(1L, sum(nzchar(vals))) >= 0.8 &&
      (
        grepl(
          "year|period|category|crop|commodity|marketing",
          label, ignore.case = TRUE
        ) ||
          any(grepl(
            "^[0-9]{4}[- ]|Q[1-4]|[sfz]\\s*$",
            period_tokens, ignore.case = TRUE
          ))
      )
    if (repeated_period_header) {
      period_labels <- vals
      if (nzchar(label)) {
        group <- label
        if (dataset == "commodities_outlook" &&
            table_id == "ac_outlook_key_macro" &&
            grepl("^Australia\\b", label, ignore.case = TRUE)) {
          outlook_geo <- "Australia"
          outlook_measure <- ""
          outlook_parent <- ""
        }
      }
      next
    }
    nonempty_vals <- vals[nzchar(vals)]
    unit_control <- length(nonempty_vals) &&
      all(grepl(
        "\\$|%|index|ha|tonne|\\bkt\\b|\\bmt\\b|t/ha|number|million|litre|\\bml\\b",
        nonempty_vals, ignore.case = TRUE
      ))
    if (!nzchar(label) && unit_control) {
      period_units <- vals
      next
    }
    if (!nzchar(label) && has_payload) {
      agau_abort(
        "agau_schema_error",
        paste("Unlabeled numeric-region payload found on row", i, "of", sheet),
        product = product, release_id = meta$release_id,
        source_sheet = sheet, table_id = table_id,
        remediation = "Review the missing row hierarchy label before parsing."
      )
    }
    if (!nzchar(label)) next
    if (!has_payload) {
      clean_group <- agau_strip_footnote_suffix(label)
      if (product == "agricultural_commodities" &&
          dataset == "commodities_outlook") {
        if (grepl("^World\\b", clean_group, ignore.case = TRUE)) {
          outlook_geo <- "World"
          outlook_commodity <- ""
          outlook_measure <- ""
          outlook_flow <- ""
          outlook_section <- ""
          outlook_parent <- ""
        } else if (grepl("^Australia\\b", clean_group, ignore.case = TRUE)) {
          outlook_geo <- "Australia"
          outlook_commodity <- ""
          outlook_measure <- ""
          outlook_flow <- ""
          outlook_section <- ""
          outlook_parent <- ""
        } else if (table_id == "ac_outlook_key_macro") {
          outlook_measure <- clean_group
          outlook_parent <- ""
        } else if (table_id == "ac_outlook_major_indicators") {
          major_section <- grepl(
            "^(Value of exports|Gross value of production|Volume of (farm )?production|Production area and livestock numbers|Farm sector)\\b",
            clean_group, ignore.case = TRUE
          )
          if (major_section) {
            outlook_section <- clean_group
            outlook_measure <- clean_group
            outlook_commodity <- ""
          } else {
            outlook_commodity <- clean_group
          }
          outlook_parent <- ""
        } else if (table_id == "ac_outlook_horticulture") {
          if (grepl("^(Gross value|Exports)$", clean_group, ignore.case = TRUE)) {
            outlook_section <- clean_group
            outlook_commodity <- ""
          } else {
            outlook_commodity <- clean_group
          }
          outlook_parent <- ""
        } else if (table_id == "ac_outlook_fisheries_aquaculture_forestry") {
          fisheries_section <- grepl(
            "^(?:Real )?(?:Gross value of fisheries products|Gross value of production by sector|Fisheries export value)\\b",
            clean_group, ignore.case = TRUE
          )
          if (fisheries_section) {
            outlook_section <- clean_group
            outlook_commodity <- ""
          } else {
            outlook_commodity <- clean_group
          }
          outlook_parent <- ""
        } else if (table_id == "ac_outlook_coarse_grains") {
          if (grepl(
            "^(Exports?|Imports?|Export value|Prices?)$",
            clean_group, ignore.case = TRUE
          )) {
            outlook_measure <- clean_group
            outlook_parent <- clean_group
          } else if (grepl(
            "^(Sorghum|Barley|.* price)\\b",
            clean_group, ignore.case = TRUE
          )) {
            outlook_commodity <- clean_group
            outlook_measure <- if (grepl("price", clean_group, ignore.case = TRUE)) {
              clean_group
            } else {
              ""
            }
            outlook_parent <- ""
          } else {
            outlook_commodity <- clean_group
            outlook_parent <- ""
          }
        } else if (table_id == "ac_outlook_oilseeds") {
          if (grepl("^Export value$", clean_group, ignore.case = TRUE)) {
            outlook_measure <- clean_group
            outlook_parent <- clean_group
          } else {
            outlook_commodity <- clean_group
            outlook_measure <- ""
            outlook_parent <- ""
          }
        } else if (table_id == "ac_outlook_pigs") {
          outlook_section <- clean_group
          outlook_parent <- ""
        } else if (grepl(
          "^(Exports?|Imports?|Prices?)$", clean_group, ignore.case = TRUE
        )) {
          outlook_flow <- clean_group
          outlook_measure <- ""
        } else if (grepl(
          "exports?|imports?|prices?|production|consumption|slaughter|trade|stocks|value of|volume of|farm sector|crop area|economic growth|inflation|exchange rate|interest rate",
          clean_group, ignore.case = TRUE
        )) {
          outlook_measure <- clean_group
          outlook_flow <- ""
        } else {
          outlook_commodity <- clean_group
          outlook_measure <- ""
        }
        group <- clean_group
        group_raw <- label
      } else if (dataset == "commodity_statistics" &&
                 table_id %in% c("acs_table_07", "acs_legacy_table_11")) {
        if (grepl(
          "^(Grains|Oilseeds and vegetable oils|Industrial crops|Livestock products)$",
          clean_group, ignore.case = TRUE
        )) {
          stats_sector <- clean_group
          stats_sector_raw <- label
          stats_commodity <- ""
        } else {
          stats_commodity <- clean_group
        }
        group <- clean_group
        group_raw <- label
      } else {
        group <- clean_group
        group_raw <- label
        if (dataset == "commodity_statistics") stats_sector <- clean_group
      }
      next
    }
    unit <- ""
    unit_hits <- labels[grepl("\\$|%|index|ha|tonne|\\bkt\\b|\\bmt\\b|t/ha|number", labels, ignore.case = TRUE)]
    if (length(unit_hits)) unit <- utils::tail(unit_hits, 1L)
    geography <- "not_applicable"
    commodity <- label
    concept <- if (nzchar(group)) group else label
    market <- "not_applicable"
    sector <- "not_applicable"
    season <- agau_title_season(title)
    if (product == "crop_report" && meta$source_asset == "state") {
      geography <- sheet
      commodity <- if (nzchar(group)) group else label
      concept <- label
      sector <- "crops"
    } else if (product == "crop_report") {
      geography <- "Australia"
      commodity <- if (nzchar(group)) group else if (season != "not_applicable") paste(season, "crops") else label
      concept <- label
      sector <- "crops"
    } else if (product == "agricultural_commodities" && dataset == "commodities_outlook") {
      sector <- if (grepl("beef|cattle|dairy|pig|poultry|chicken|lamb|sheep|wool", sheet, ignore.case = TRUE)) "livestock" else "agriculture"
      if (grepl("major indicator", sheet, ignore.case = TRUE) &&
          grepl("^Volume of farm production\\b", label, ignore.case = TRUE)) {
        outlook_measure <- agau_strip_footnote_suffix(label)
      }
      if (!grepl("macro|major indicator", sheet, ignore.case = TRUE)) {
        commodity <- if (nzchar(outlook_commodity)) {
          outlook_commodity
        } else sheet_commodity
      }
      if (nzchar(outlook_geo)) {
        geography <- outlook_geo
        market <- if (outlook_geo == "World") "world" else "Australia"
      } else if (table_id %in% c(
        "ac_outlook_pigs", "ac_outlook_pigs_poultry_eggs",
        "ac_outlook_lamb_sheep_wool"
      )) {
        geography <- "Australia"
        market <- "Australia"
      }
      clean_label <- agau_strip_footnote_suffix(label)
      modifier <- grepl(
        "^(nominal|real|quantity|value|volume|unit price)$",
        clean_label, ignore.case = TRUE
      )
      flow_child <- grepl(
        "^(quantity|value|volume|unit price|nominal|real)$",
        clean_label, ignore.case = TRUE
      )
      if (nzchar(outlook_flow) && !flow_child) outlook_flow <- ""
      concept <- label
      if (table_id == "ac_outlook_key_macro") {
        commodity <- "Macroeconomic assumptions"
        if (outlook_geo == "Australia") {
          geography <- "Australia"
          market <- "Australia"
          concept <- clean_label
        } else {
          geography <- clean_label
          concept <- outlook_measure
        }
        if (identical(clean_label, "Exchange rate")) unit <- "US$/A$"
      } else if (table_id == "ac_outlook_major_indicators") {
        if (grepl(
          "^Volume of (farm )?production\\b",
          clean_label, ignore.case = TRUE
        )) {
          outlook_section <- clean_label
          outlook_measure <- clean_label
          outlook_commodity <- ""
        }
        if (modifier && nzchar(outlook_parent)) {
          commodity <- outlook_parent
          concept <- paste(
            c(outlook_section, outlook_parent, clean_label),
            collapse = " - "
          )
        } else {
          commodity <- clean_label
          concept <- paste(
            c(
              outlook_section,
              if (nzchar(outlook_commodity)) outlook_commodity,
              clean_label
            ),
            collapse = " - "
          )
          outlook_parent <- clean_label
        }
        if (grepl("value of exports", outlook_section, ignore.case = TRUE) &&
            grepl("^Agriculture\\b", clean_label, ignore.case = TRUE)) {
          concept <- "Value of agricultural exports"
          commodity <- "Agriculture"
        }
      } else if (table_id == "ac_outlook_horticulture") {
        commodity <- if (nzchar(outlook_commodity)) {
          outlook_commodity
        } else {
          "Horticulture"
        }
        concept <- paste(
          c(outlook_section, clean_label),
          collapse = " - "
        )
      } else if (table_id == "ac_outlook_fisheries_aquaculture_forestry") {
        commodity <- clean_label
        concept <- paste(
          c(
            outlook_section,
            if (nzchar(outlook_commodity) &&
                outlook_commodity != clean_label) outlook_commodity,
            clean_label
          ),
          collapse = " - "
        )
      } else if (table_id == "ac_outlook_coarse_grains") {
        if (outlook_geo == "World") {
          if (modifier) {
            commodity <- if (nzchar(outlook_commodity)) {
              outlook_commodity
            } else {
              sheet_commodity
            }
            concept <- paste(
              c(outlook_measure, clean_label),
              collapse = " - "
            )
          } else if (grepl("^(corn|barley)$", clean_label, ignore.case = TRUE) &&
                     nzchar(outlook_parent)) {
            commodity <- tools::toTitleCase(tolower(clean_label))
            concept <- paste(outlook_parent, clean_label, sep = " - ")
          } else {
            commodity <- sheet_commodity
            concept <- clean_label
            outlook_parent <- clean_label
          }
        } else {
          commodity <- if (nzchar(outlook_commodity)) {
            outlook_commodity
          } else {
            sheet_commodity
          }
          concept <- if (modifier && nzchar(outlook_measure)) {
            paste(outlook_measure, clean_label, sep = " - ")
          } else {
            clean_label
          }
          if (!modifier) outlook_parent <- clean_label
        }
      } else if (table_id == "ac_outlook_oilseeds") {
        commodity <- if (nzchar(outlook_commodity)) {
          outlook_commodity
        } else {
          sheet_commodity
        }
        concept <- if (modifier && nzchar(outlook_parent)) {
          paste(outlook_parent, clean_label, sep = " - ")
        } else if (modifier && nzchar(outlook_measure)) {
          paste(outlook_measure, clean_label, sep = " - ")
        } else {
          clean_label
        }
        if (!modifier) outlook_parent <- clean_label
      } else if (table_id == "ac_outlook_pigs") {
        commodity <- "Pig meat"
        concept <- if (nzchar(outlook_section)) {
          paste(outlook_section, clean_label, sep = " - ")
        } else {
          clean_label
        }
      } else if (grepl("major indicator", sheet, ignore.case = TRUE) &&
          grepl("value of exports", group, ignore.case = TRUE) &&
          grepl("^Agriculture\\b", label, ignore.case = TRUE)) {
        concept <- "Value of agricultural exports"
        commodity <- "Agriculture"
      } else if (sheet == "Wine" &&
                 grepl("^(Red|White) variety$", label, ignore.case = TRUE)) {
        commodity <- paste(sub(" variety$", "", label, ignore.case = TRUE),
          "wine grapes"
        )
        concept <- if (grepl("kt", unit, ignore.case = TRUE)) {
          "crush volume by variety"
        } else if (grepl("\\$/t", unit)) {
          "gross unit value by variety"
        } else label
      } else if (nzchar(outlook_flow) && flow_child) {
        concept <- paste(outlook_flow, label, sep = " - ")
      } else if (nzchar(outlook_measure) && outlook_measure != label) {
        if (grepl("^Prices?$", outlook_measure, ignore.case = TRUE)) {
          concept <- "price"
          commodity <- sub("\\s+price.*$", "", label, ignore.case = TRUE)
        } else {
          concept <- paste(outlook_measure, label, sep = " - ")
        }
      }
    } else if (dataset == "commodity_statistics") {
      world_indicator <- table_id %in% c(
        "acs_table_05",
        "acs_legacy_table_09"
      )
      world_balance <- table_id %in% c(
        "acs_table_07",
        "acs_legacy_table_11"
      )
      world_table <- world_indicator || world_balance
      geography <- if (world_table) "World" else "Australia"
      market <- if (world_indicator) {
        "world_indicator"
      } else if (world_balance) {
        "world"
      } else "Australia"
      if (world_balance && nzchar(stats_commodity)) {
        commodity <- stats_commodity
        concept <- paste(agau_acs_family(table_id), label, sep = " - ")
        sector <- if (nzchar(stats_sector)) stats_sector else "agriculture"
      } else if (world_indicator) {
        commodity <- agau_strip_footnote_suffix(label)
        concept <- "world indicator price"
        sector <- if (nzchar(stats_sector)) stats_sector else "agriculture"
      } else {
        percent_row <- grepl("^%$", agau_norm_text(label))
        commodity <- if (percent_row && nzchar(last_data_label)) {
          agau_strip_footnote_suffix(last_data_label)
        } else agau_strip_footnote_suffix(label)
        concept_parts <- c(
          agau_acs_family(table_id),
          if (nzchar(group)) group,
          if (percent_row) paste(last_data_label, "percentage change") else label
        )
        concept <- paste(concept_parts[nzchar(concept_parts)], collapse = " - ")
        sector <- "agriculture"
      }
      if (!grepl("^%$", agau_norm_text(label))) last_data_label <- label
    }
    base_basis <- if (dataset == "commodity_statistics") {
      agau_acs_period_basis(
        table_id, label, c(group_raw, stats_sector_raw), ""
      )
    } else {
      NULL
    }
    base_footnote_codes <- unique(c(
      agau_footnote_codes(label), agau_footnote_codes(group),
      agau_footnote_codes(group_raw), agau_footnote_codes(stats_sector_raw)
    ))
    for (j in seq_along(pcols)) {
      raw <- vals[j]
      if (!nzchar(raw)) next
      payload_count <- payload_count + 1L
      unit_j <- if (nzchar(unit)) unit else period_units[j]
      period <- period_labels[j]
      concept_j <- concept
      basis <- agau_infer_basis(product, dataset, title, period)
      if (dataset == "commodity_statistics") basis <- base_basis
      if (grepl("^%\\s*change", period, ignore.case = TRUE)) {
        period <- "release percentage change"
        concept_j <- paste(concept, "percentage change")
        unit_j <- "%"
        basis <- "release_comparison"
      }
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta, sheet, table_id, title, geography, commodity, concept_j,
        period, unit_j, raw, dataset = dataset, source_dataset = dataset,
        sector = sector, season = season, market = market,
        price_basis = if (
          table_id == "ac_outlook_key_macro" &&
            identical(concept, "Exchange rate")
        ) {
          "not_applicable"
        } else if (
          dataset == "commodity_statistics" &&
            (grepl("\\$", unit_j) ||
              table_id %in% c(
                "acs_table_05",
                "acs_table_06",
                "acs_legacy_table_09",
                "acs_legacy_table_10"
              ))
        ) "nominal" else NULL,
        currency = if (
          table_id == "ac_outlook_key_macro" &&
            identical(concept, "Exchange rate")
        ) {
          "not_applicable"
        } else if (
          dataset == "commodity_statistics" &&
            geography == "Australia" &&
            grepl("^\\$|^A\\$", unit_j)
        ) "AUD" else NULL,
        period_basis = basis, source_note = sheet_note,
        footnote_codes = unique(c(
          base_footnote_codes,
          agau_footnote_codes(period_labels[j], period = TRUE)
        ))
      )
    }
  }
  agau_assert_payload_count(rows, payload_count, meta, sheet, table_id)
  rows
}

agau_parse_row_periods <- function(x, meta, sheet, table_id, title,
                                   product, dataset) {
  col_scores <- colSums(apply(x, 2L, agau_period_like, short_quarter = TRUE))
  pcol <- which(col_scores >= 2L)[1]
  period_rows <- which(agau_period_like(x[, pcol], short_quarter = TRUE))
  first <- min(period_rows)
  mcols <- setdiff(seq_len(ncol(x)), pcol)
  header_rows <- if (first > 2L) 2:(first - 1L) else first - 1L
  headers <- agau_forward_headers(x, header_rows, mcols)
  rows <- list()
  payload_count <- 0L
  carry_year <- NA_character_
  sheet_note <- agau_extract_sheet_note(x)
  if (!nzchar(sheet_note)) sheet_note <- meta$workbook_note %||% ""
  for (i in period_rows) {
    period <- x[i, pcol]
    if (grepl("^[12][0-9]{3}\\s*Q[1-4]$", period, ignore.case = TRUE)) carry_year <- substr(period, 1, 4)
    if (grepl("^Q[1-4]$", period, ignore.case = TRUE) && !is.na(carry_year)) period <- paste(carry_year, period)
    row_unit <- if (ncol(x) >= 2L) x[i, 2L] else ""
    for (jj in seq_along(mcols)) {
      col <- mcols[jj]
      if (col == 2L && nzchar(row_unit) && grepl("\\$|%|index|ha|kt|mt|t/", row_unit, ignore.case = TRUE)) next
      raw <- x[i, col]
      if (!nzchar(raw)) next
      payload_count <- payload_count + 1L
      hs <- if (nrow(headers)) headers[, jj] else ""
      hs <- unique(hs[nzchar(hs)])
      semantic_hs <- hs[!grepl(
        "^(?:A?US?\\$.*|%|index|'?000 ha|ha|tonnes?|kt|mt|t/ha|A\\$/t)$",
        hs, ignore.case = TRUE
      )]
      if (!length(semantic_hs)) {
        agau_abort(
          "agau_schema_error",
          paste(
            "Numeric payload column", col, "in", sheet,
            "has no admitted header hierarchy."
          ),
          product = product, release_id = meta$release_id,
          source_sheet = sheet, table_id = table_id,
          remediation = "Review merged or moved measurement headers."
        )
      }
      unit_hits <- hs[grepl("\\$|%|index|ha|tonne|\\bkt\\b|\\bmt\\b|t/ha", hs, ignore.case = TRUE)]
      unit <- if (nzchar(row_unit) && grepl("\\$|%|index|ha|tonne|\\bkt\\b|\\bmt\\b|t/", row_unit, ignore.case = TRUE)) row_unit else utils::tail(unit_hits, 1L) %||% ""
      geography <- "Australia"
      commodity <- if (length(hs)) hs[1] else agau_title_industry(title)
      concept <- if (length(hs) >= 2L) hs[length(hs) - as.integer(length(unit_hits) > 0L)] else agau_title_concept(title)
      market <- "not_applicable"
      sector <- if (product == "farm_productivity") "agriculture" else "crops"
      method <- "not_applicable"
      if (product == "farm_productivity") {
        geography <- if (length(hs)) hs[1] else "Australia"
        commodity <- agau_title_industry(title)
        concept <- agau_title_concept(title)
        geography_hierarchy <- if (grepl(
          "by\\s+state", title, ignore.case = TRUE
        )) {
          "by state"
        } else if (grepl(
          "by\\s+(?:(?:GRDC|AAGIS|MLA)\\s+)?(?:region|zone)",
          title, ignore.case = TRUE, perl = TRUE
        )) {
          "by region"
        } else {
          ""
        }
        if (nzchar(geography_hierarchy)) {
          concept <- paste(concept, geography_hierarchy, sep = " - ")
        }
        unit <- if (grepl("growth rates", title, ignore.case = TRUE)) "%" else "index"
        method <- if (grepl("climate adjusted", title, ignore.case = TRUE)) "climate_adjusted" else "conventional"
        clean_productivity_period <- agau_status(period)$period
        if (method == "climate_adjusted" &&
            clean_productivity_period %in% c("2022-23", "2023-24", "2024-25")) {
          method <- "interim_adjustment"
        }
      } else if (product == "crop_report") {
        if (grepl("Table 1[12]\\b", title, ignore.case = TRUE)) {
          commodity <- hs[1] %||% "crop"
          concept <- if (length(hs) >= 2L) hs[2] else agau_concept_from_unit(unit, agau_title_concept(title))
        } else if (grepl("prices", title, ignore.case = TRUE)) {
          commodity <- hs[1] %||% "crop"
          concept <- "price"
          market <- if (length(hs) >= 2L) hs[2] else "published market"
        } else {
          geography <- hs[1] %||% "Australia"
          if (grepl("Production, (major|other) crops", title, ignore.case = TRUE)) {
            prior <- x[seq_len(i - 1L), pcol]
            candidate <- utils::tail(prior[nzchar(prior) &
              !agau_period_like(prior, short_quarter = TRUE) &
              !grepl("^(Winter|Summer) crops?$", prior, ignore.case = TRUE)], 1L)
            commodity <- candidate %||% "crop"
          } else {
            commodity <- paste(agau_title_season(title), "crops")
          }
          concept <- agau_concept_from_unit(unit, agau_title_concept(title))
        }
      }
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta, sheet, table_id, title, geography, commodity, concept, period,
        unit, raw, dataset = dataset, source_dataset = dataset, sector = sector,
        season = agau_title_season(title), market = market, method = method,
        period_basis = agau_infer_basis(product, dataset, title, period),
        source_note = sheet_note,
        footnote_codes = unique(c(
          agau_footnote_codes(hs),
          agau_footnote_codes(period, period = TRUE)
        ))
      )
    }
  }
  agau_assert_payload_count(rows, payload_count, meta, sheet, table_id)
  rows
}

agau_parse_matrix <- function(x, meta, sheet, table_id, title, product, dataset) {
  if (product == "crop_report" && nrow(x) >= 4L) {
    sheet_note <- agau_extract_sheet_note(x)
    if (!nzchar(sheet_note)) sheet_note <- meta$workbook_note %||% ""
    period <- regmatches(title, regexpr("[12][0-9]{3}-[0-9]{2}", title))
    if (!length(period) || !nzchar(period)) {
      agau_abort("agau_table_parse_error", "Current snapshot title has no target period.",
        product = product, release_id = meta$release_id, source_sheet = sheet,
        table_id = table_id, remediation = "Review the current-snapshot profile."
      )
    }
    if (grepl("forecast", title, ignore.case = TRUE)) period <- paste0(period, " f")
    if (grepl("estimate", title, ignore.case = TRUE)) period <- paste0(period, " s")
    geo <- sub("^.*,\\s*([^,]+),\\s*[12][0-9]{3}-[0-9]{2}.*$", "\\1", title)
    if (identical(geo, title)) geo <- "Australia"
    headers <- x[2L, -1L]
    units <- x[3L, -1L]
    rows <- list()
    payload_count <- 0L
    for (i in 4:nrow(x)) {
      commodity <- x[i, 1L]
      if (!nzchar(commodity) && any(nzchar(x[i, -1L]))) {
        agau_abort(
          "agau_schema_error",
          paste("Unlabeled matrix payload found on row", i, "of", sheet),
          product = product, release_id = meta$release_id,
          source_sheet = sheet, table_id = table_id,
          remediation = "Review the missing matrix row label before parsing."
        )
      }
      if (!nzchar(commodity) ||
          grepl("\\bNotes?:", commodity, ignore.case = TRUE)) next
      for (j in 2:ncol(x)) {
        raw <- x[i, j]
        if (!nzchar(raw)) next
        payload_count <- payload_count + 1L
        rows[[length(rows) + 1L]] <- agau_observation_row(
          meta, sheet, table_id, title, geo, commodity, headers[j - 1L],
          period, units[j - 1L], raw, dataset = dataset,
          source_dataset = dataset, sector = "crops",
          season = agau_title_season(title), period_basis = "crop_year",
          source_note = sheet_note,
          footnote_codes = unique(c(
            agau_footnote_codes(commodity),
            agau_footnote_codes(headers[j - 1L])
          ))
        )
      }
    }
    agau_assert_payload_count(rows, payload_count, meta, sheet, table_id)
    return(rows)
  }
  if (product != "farm_productivity" || nrow(x) < 3L) {
    agau_abort("agau_table_parse_error", "No period axis could be identified.",
      product = product, release_id = meta$release_id, source_sheet = sheet,
      table_id = table_id,
      remediation = "Add a reviewed parser fingerprint for this table shape."
    )
  }
  headers <- x[2L, -1L]
  range <- regmatches(title, regexpr("[12][0-9]{3}-[0-9]{2}\\s+to\\s+[12][0-9]{3}-[0-9]{2}", title))
  period <- range %||% "published release interval"
  rows <- list()
  sheet_note <- agau_extract_sheet_note(x)
  if (!nzchar(sheet_note)) sheet_note <- meta$workbook_note %||% ""
  for (i in 3:nrow(x)) {
    label <- x[i, 1]
    if (!nzchar(label)) next
    for (j in 2:ncol(x)) {
      raw <- x[i, j]
      if (!nzchar(raw)) next
      h <- headers[j - 1L]
      by_geography <- grepl(
        "by\\s+(?:state|region)", title, ignore.case = TRUE
      )
      by_input_type <- grepl("by\\s+input type", title, ignore.case = TRUE)
      by_industry <- grepl("by\\s+industry", title, ignore.case = TRUE)
      geo <- if (by_geography && by_input_type) {
        label
      } else if (by_geography) {
        h
      } else {
        "Australia"
      }
      commodity <- if (by_industry) label else agau_title_industry(title)
      concept <- agau_title_concept(title)
      if (by_input_type) concept <- paste(concept, h)
      method <- if (grepl("climate adjusted", title, ignore.case = TRUE)) "climate_adjusted" else "conventional"
      rows[[length(rows) + 1L]] <- agau_observation_row(
        meta, sheet, table_id, title, geo, commodity, concept, period, "%",
        raw, dataset = dataset, source_dataset = dataset, sector = "agriculture",
        method = method, period_basis = "financial_year_range",
        source_note = sheet_note,
        footnote_codes = unique(c(
          agau_footnote_codes(label), agau_footnote_codes(h)
        ))
      )
    }
  }
  rows
}

agau_parse_sheet <- function(path, meta, sheet, product, dataset) {
  x <- agau_sheet_matrix(path, sheet)
  table_id <- agau_table_id(product, dataset, sheet)
  if (dataset == "commodity_statistics" &&
      identical(meta$workbook_profile, "legacy_27")) {
    table_id <- sub(
      "^acs_table_",
      "acs_legacy_table_",
      table_id
    )
  }
  if (dataset == "commodity_statistics") {
    n <- as.integer(sub(".*_([0-9]+)$", "\\1", table_id))
    candidates <- agau_norm_text(as.vector(
      x[seq_len(min(5L, nrow(x))), , drop = FALSE]
    ))
    candidates <- candidates[grepl(
      paste0("^", n, "(?:\\b|(?=[A-Za-z]))"), candidates, perl = TRUE
    )]
    title <- candidates[1] %||% sheet
  } else {
    title <- x[1, which(nzchar(x[1, ]))[1]] %||% sheet
  }
  agau_validate_sheet_fingerprint(
    x, meta, sheet, table_id, title, product, dataset
  )
  if (product == "crop_report" &&
      grepl("^crop_national_table_(0[4-9]|10)$", table_id)) {
    return(agau_parse_matrix(x, meta, sheet, table_id, title, product, dataset))
  }
  scores <- apply(x[seq_len(min(10L, nrow(x))), , drop = FALSE], 1L,
    function(z) sum(agau_period_like(z))
  )
  col_scores <- colSums(apply(x, 2L, agau_period_like, short_quarter = TRUE))
  if (col_scores[1] >= 2L) {
    agau_parse_row_periods(x, meta, sheet, table_id, title, product, dataset)
  } else if (max(scores) >= 2L) {
    agau_parse_column_periods(x, meta, sheet, table_id, title, product, dataset)
  } else if (max(col_scores) >= 2L) {
    agau_parse_row_periods(x, meta, sheet, table_id, title, product, dataset)
  } else {
    agau_parse_matrix(x, meta, sheet, table_id, title, product, dataset)
  }
}

agau_parse_workbook <- function(path, meta, product, dataset, sheets = "all") {
  staged <- agau_readxl_path(path)
  if (!identical(staged, path)) on.exit(unlink(staged), add = TRUE)
  available <- readxl::excel_sheets(staged)
  notes_sheet <- available[tolower(available) == "notes"]
  if (length(notes_sheet)) {
    notes_matrix <- agau_sheet_matrix(path, notes_sheet[1])
    note_cells <- agau_norm_text(as.vector(notes_matrix))
    note_cells <- note_cells[nzchar(note_cells)]
    meta$workbook_note <- paste(note_cells, collapse = "\n")
  }
  available <- available[!tolower(available) %in% c("index", "notes")]
  agau_validate_workbook_sheets(available, meta, product, dataset)
  if (dataset == "commodity_statistics") {
    meta$workbook_profile <- if (length(available) == 27L) {
      "legacy_27"
    } else {
      "current_18"
    }
  }
  if (!identical(sheets, "all")) available <- intersect(available, sheets)
  if (!length(available)) {
    agau_abort("agau_schema_error", "No requested data sheets were found.",
      product = product, release_id = meta$release_id,
      remediation = "Inspect workbook sheet names and parser catalogue."
    )
  }
  rows <- unlist(lapply(available, function(sheet) {
    agau_parse_sheet(path, meta, sheet, product, dataset)
  }), recursive = FALSE)
  cls <- switch(product,
    crop_report = "crop_report_data",
    agricultural_commodities = "agricultural_commodities_data",
    farm_productivity = "farm_productivity_data",
    "agau_data"
  )
  agau_bind_observations(rows, cls)
}

agau_parsed_cache_key <- function(product, release_id, sha256, dataset,
                                  sheet_key, parser_profile = agau_parser_version()) {
  digest::digest(
    paste(product, release_id, sha256, parser_profile,
      dataset, sheet_key, "reported", sep = "\u241f"),
    algo = "sha256", serialize = FALSE
  )
}

agau_parse_workbook_cached <- function(path, meta, product, dataset,
                                       cache_dir, sheets = "all") {
  sheet_key <- if (identical(sheets, "all")) "all" else paste(sort(sheets), collapse = "_")
  key <- agau_parsed_cache_key(
    product, meta$release_id, meta$sha256, dataset, sheet_key
  )
  target <- file.path(
    cache_dir, "parsed", product, meta$release_id,
    agau_parser_version(), key, "reported.rds"
  )
  if (file.exists(target)) {
    out <- tryCatch(readRDS(target), error = function(e) NULL)
    if (!is.null(out)) return(out)
  }
  out <- agau_parse_workbook(path, meta, product, dataset, sheets)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".agau-parsed-", tmpdir = dirname(target))
  on.exit(if (file.exists(stage)) unlink(stage), add = TRUE)
  saveRDS(out, stage, version = 3)
  readRDS(stage)
  if (!file.rename(stage, target) && !file.exists(target)) {
    agau_abort("agau_validation_error", "Atomic parsed-cache write failed.",
      product = product, release_id = meta$release_id,
      remediation = "Check cache permissions."
    )
  }
  out
}

agau_local_meta <- function(path, product, source_asset, release_id = NULL,
                            release_date = NULL, report_number = NA_character_,
                            dataset = NULL) {
  if (xor(is.null(release_id), is.null(release_date))) {
    agau_abort(
      "agau_validation_error",
      "Official local-file provenance requires both a release ID and date.",
      product = product,
      remediation = paste(
        "Pass both explicit values after matching a reviewed release,",
        "or omit both for a checksum-qualified local identity."
      )
    )
  }
  hash <- agau_sha256(path)
  if (is.null(release_id)) {
    release_id <- paste0("local-", substr(hash, 1L, 16L))
    release_date <- as.Date(NA)
    report_number <- NA_character_
  }
  list(
    product = product, release_id = release_id, release_date = as.Date(release_date),
    source_asset = source_asset, retrieved_at = as.POSIXct(file.info(path)$mtime, tz = "UTC"),
    sha256 = hash, report_number = report_number, dataset = dataset
  )
}
