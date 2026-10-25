# Generated fixtures are reduced/derived synthetic structures. They are not
# copies of official workbooks and contain no logos or third-party values.
if (!requireNamespace("writexl", quietly = TRUE)) {
  stop("writexl is required to regenerate fixtures")
}

root <- normalizePath(".", mustWork = TRUE)
out <- file.path(root, "inst", "fixtures", "workbooks")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

pad <- function(x, n) {
  length(x) <- n
  z <- as.data.frame(as.list(x), stringsAsFactors = FALSE, check.names = FALSE)
  names(z) <- paste0("V", seq_len(n))
  z
}

row_table <- function(title, period = "2025-26 s", value = 35985) {
  rbind(
    pad(c(title, "", ""), 3),
    pad(c("Year", "Wheat", ""), 3),
    pad(c("", "Area", "Production"), 3),
    pad(c("", "'000 ha", "kt"), 3),
    pad(c("2024-25 s", "11800", "35000"), 3),
    pad(c(period, "12000", as.character(value)), 3),
    pad(c("Note: s is an estimate. Source: ABARES synthetic fixture.", "", ""), 3)
  )
}

matrix_table <- function(n, status = "f") {
  rbind(
    pad(c(sprintf("Table %d Winter crop forecasts, Synthetic State, 2026-27", n), "", ""), 3),
    pad(c("Crop", "Area", "Production"), 3),
    pad(c("", "'000 ha", "kt"), 3),
    pad(c("Wheat", "100", "250"), 3),
    pad(c("Note: f is a forecast. Source: ABARES synthetic fixture.", "", ""), 3)
  )
}

column_table <- function(title) {
  rbind(
    pad(c(title, "", "", ""), 4),
    pad(c("Crop", "unit", "2024-25 s", "2025-26 f"), 4),
    pad(c("Wheat", "", "", ""), 4),
    pad(c("Production", "kt", "2000", "3000"), 4),
    pad(c("Note: s is an estimate and f is a forecast. Source: ABARES synthetic fixture.", "", "", ""), 4)
  )
}

crop <- list(Index = pad(c("Synthetic index"), 2))
for (i in 1:17) {
  crop[[paste("Table", i)]] <- if (i %in% 4:10) {
    matrix_table(i)
  } else if (i %in% c(15, 16)) {
    column_table(sprintf("Table %d Supply and disposal, synthetic", i))
  } else if (i == 17) {
    rbind(
      pad(c("Table 17 Synthetic quarterly prices", "", ""), 3),
      pad(c("Crop", "A$/t", "Wheat"), 3),
      pad(c("", "", "Domestic price a"), 3),
      pad(c("2026 Q1", "A$/t", "410"), 3),
      pad(c("Q2", "A$/t", "420"), 3),
      pad(c("Note: a is a synthetic footnote code. Source: ABARES synthetic fixture.", "", ""), 3)
    )
  } else {
    row_table(sprintf("Table %d Synthetic crop observations", i))
  }
}
writexl::write_xlsx(crop, file.path(out, "crop-national.xlsx"), col_names = FALSE)

crop_unknown <- crop
crop_unknown[["Table 99"]] <- row_table("Table 99 Unreviewed observations")
writexl::write_xlsx(
  crop_unknown, file.path(out, "crop-national-unknown-table.xlsx"),
  col_names = FALSE
)

crop_missing <- crop
crop_missing[["Table 17"]] <- NULL
writexl::write_xlsx(
  crop_missing, file.path(out, "crop-national-missing-table.xlsx"),
  col_names = FALSE
)

crop_moved <- crop
crop_moved[["Table 1"]] <- rbind(
  crop_moved[["Table 1"]][1, , drop = FALSE],
  matrix("", nrow = 10, ncol = ncol(crop_moved[["Table 1"]])),
  crop_moved[["Table 1"]][-1, , drop = FALSE]
)
writexl::write_xlsx(
  crop_moved, file.path(out, "crop-national-moved-header.xlsx"),
  col_names = FALSE
)

crop_unlabeled_column <- crop
crop_unlabeled_column[["Table 15"]][4, 1:2] <- ""
writexl::write_xlsx(
  crop_unlabeled_column,
  file.path(out, "crop-national-unlabeled-column.xlsx"),
  col_names = FALSE
)

crop_extra_payload <- crop
crop_extra_payload[["Table 15"]]$V5 <- ""
crop_extra_payload[["Table 15"]][2, 5] <- "Unmapped payload"
crop_extra_payload[["Table 15"]][4, 5] <- "999"
writexl::write_xlsx(
  crop_extra_payload,
  file.path(out, "crop-national-extra-payload.xlsx"),
  col_names = FALSE
)

crop_extra_marker_payload <- crop
crop_extra_marker_payload[["Table 15"]]$V5 <- ""
crop_extra_marker_payload[["Table 15"]][2, 5] <- "Unmapped payload"
crop_extra_marker_payload[["Table 15"]][4, 5] <- "na"
writexl::write_xlsx(
  crop_extra_marker_payload,
  file.path(out, "crop-national-extra-marker-payload.xlsx"),
  col_names = FALSE
)

crop_unlabeled_row <- crop
crop_unlabeled_row[["Table 1"]][2:4, 2] <- ""
writexl::write_xlsx(
  crop_unlabeled_row, file.path(out, "crop-national-unlabeled-row.xlsx"),
  col_names = FALSE
)

crop_unlabeled_matrix <- crop
crop_unlabeled_matrix[["Table 4"]][4, 1] <- ""
writexl::write_xlsx(
  crop_unlabeled_matrix,
  file.path(out, "crop-national-unlabeled-matrix.xlsx"),
  col_names = FALSE
)

geos <- c(
  "Australia", "New South Wales", "Queensland", "South Australia",
  "Tasmania", "Victoria", "Western Australia"
)
state <- list(Index = pad(c("Synthetic state index"), 2))
for (g in geos) {
  state[[g]] <- rbind(
    pad(c(paste(g, "grains"), "", "", ""), 4),
    pad(c("Crops", "", "2024-25 s", "2025-26 s"), 4),
    pad(c("Wheat", "", "", ""), 4),
    pad(c("Production", "kt", "35000", if (g == "Australia") "35985" else "100"), 4),
    pad(c("Note: s is an estimate. Source: ABARES synthetic fixture.", "", "", ""), 4)
  )
}
writexl::write_xlsx(state, file.path(out, "crop-state.xlsx"), col_names = FALSE)

outlook_sheet <- function(title, major = FALSE, march = TRUE) {
  periods <- if (march) c("2025-26 f", "2026-27 f", "2027-28 z") else c("2025-26 f", "2026-27 f", "% change")
  values <- if (major && march) c("80456.408", "72844.562", "-9.46") else if (major) c("81815.978", "74815.698", "-8.56") else c("10", "11", "12")
  rbind(
    pad(c(title, "", "", ""), 5),
    pad(c("Category", "unit", periods), 5),
    pad(c(if (major) "Value of exports" else "World", "", "", ""), 5),
    pad(c(if (major) "Agriculture" else "Production", if (major) "A$m" else "Mt", values), 5),
    pad(c("Note: f is a forecast and z is a projection. Source: ABARES synthetic fixture.", "", "", ""), 5)
  )
}

march_names <- c(
  "Key macro", "Major indicators", "Beef and cattle", "Chicken",
  "Coarse grains", "Cotton", "Dairy", "Fisheries", "Horticulture",
  "Oilseeds", "Pig", "Lamb, sheep and wool", "Sugar", "Wheat", "Wine"
)
june_names <- c(
  "Key Macro", "Major Indicators", "Beef & Cattle", "Coarse Grains",
  "Cotton", "Dairy", "Fisheries", "Lamb, Sheep and Wool", "Oilseeds",
  "Pigs, Poultry and Eggs", "Sugar", "Wheat", "Wine"
)
make_outlook <- function(nms, march) {
  z <- list(Index = pad(c("Synthetic outlook index"), 2))
  for (nm in nms) z[[nm]] <- outlook_sheet(
    paste("Synthetic outlook for", nm),
    major = grepl("Major", nm), march = march
  )
  z
}
writexl::write_xlsx(make_outlook(march_names, TRUE), file.path(out, "ac-march-outlook.xlsx"), col_names = FALSE)
writexl::write_xlsx(make_outlook(june_names, FALSE), file.path(out, "ac-june-outlook.xlsx"), col_names = FALSE)

stats <- list(Index = pad(c("Synthetic statistics index"), 2))
for (i in 1:18) {
  stats[[paste("Table", i)]] <- rbind(
    pad(c("", "", "", "STATISTICS"), 4),
    pad(c(sprintf("%d Synthetic statistical table", i), "", "", ""), 4),
    pad(c("Category", "unit", "2024-25 s", "2025-26 f"), 4),
    pad(c("Synthetic series", "index", as.character(99 + i), as.character(100 + i)), 4),
    pad(c("Note: s is an estimate and f is a forecast. Source: ABARES synthetic fixture.", "", "", ""), 4)
  )
}
writexl::write_xlsx(stats, file.path(out, "commodity-statistics.xlsx"), col_names = FALSE)

prod <- list(
  Notes = rbind(
    pad(c("Release Date", "30/06/2026"), 2),
    pad(c("Source: ABARES synthetic fixture.", ""), 2),
    pad(c("Note: climate-adjusted series are synthetic.", ""), 2)
  ),
  table_1 = rbind(
    pad(c("Table 1 - Broadacre productivity index, All industries, by state, 1977-78 to 2024-25", "", ""), 3),
    pad(c("Financial year", "All Australia", "New South Wales"), 3),
    pad(c("2023-24", "148", "143"), 3),
    pad(c("2024-25", "150", "145"), 3)
  ),
  table_c1 = rbind(
    pad(c("Table c1 - Climate adjusted broadacre productivity index, All industries, by state, 1988-89 to 2024-25", "", ""), 3),
    pad(c("Financial year", "All Australia", "New South Wales"), 3),
    pad(c("2021-22", "137", "135"), 3),
    pad(c("2023-24", "139", "137"), 3),
    pad(c("2024-25", "140", "138"), 3)
  )
)
prod_path <- file.path(out, "farm-productivity.xlsx")
writexl::write_xlsx(prod, prod_path, col_names = FALSE)
file.copy(prod_path, file.path(out, "farm-productivity-misnamed.xls"), overwrite = TRUE)

forecast_fixture <- data.frame(
  Commodity = c("Wheat", "Wheat"),
  Estimate_type = c("Production", "Production"),
  Estimate_description = c("Australian wheat production", "Australian wheat production"),
  Unit = c("kt", "kt"),
  Region = c("Australia", "Australia"),
  issue_year = c(2025L, 2026L),
  issue_month = c("June", "March"),
  Year_Issued_FY = c("2024-25", "2025-26"),
  forecast_financial_year = c("2025-26", "2025-26"),
  original_forecast = c(30560, 35985),
  latest_actual = c(35985, 35985)
)
utils::write.csv(forecast_fixture,
  file.path(out, "historical-forecast.csv"), row.names = FALSE
)
writexl::write_xlsx(
  list(
    `Data dictionary` = data.frame(Field = names(forecast_fixture)),
    `Forecast data` = forecast_fixture
  ),
  file.path(out, "historical-forecast.xlsx")
)

html_root <- file.path(root, "inst", "fixtures", "html")
dir.create(file.path(html_root, "crop"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(html_root, "commodities"), recursive = TRUE, showWarnings = FALSE)
writeBin(charToRaw("%PDF-1.4\n% synthetic fixture only\n%%EOF\n"),
  file.path(html_root, "report.pdf")
)
writeLines(c(
  "<!doctype html><html><body><article>",
  "<h1>Historical agricultural forecast database</h1>",
  "<time>22 February 2023</time>",
  '<a href="../workbooks/historical-forecast.xlsx">Historical agricultural forecast database - XLSX</a>',
  '<a href="../workbooks/historical-forecast.xlsx">Forecast performance summary statistics - XLSX</a>',
  "</article></body></html>"
), file.path(html_root, "historical-forecasts.html"), useBytes = TRUE)

editions <- data.frame(
  slug = c(
    "march-2024", "june-2024", "september-2024", "december-2024",
    "march-2025", "june-2025", "september-2025", "december-2025",
    "march-2026", "june-2026"
  ),
  date = c(
    "5 March 2024", "4 June 2024", "3 September 2024", "3 December 2024",
    "4 March 2025", "3 June 2025", "2 September 2025", "2 December 2025",
    "3 March 2026", "2 June 2026"
  ),
  report = 209:218,
  stringsAsFactors = FALSE
)

crop_archive <- c("<!doctype html><html><body>",
  sprintf(
    '<article><a href="crop/%s.html">Australian Crop Report No. %d — %s</a></article>',
    editions$slug, editions$report, editions$date
  ),
  "</body></html>"
)
writeLines(crop_archive, file.path(html_root, "crop-archive.html"), useBytes = TRUE)
for (i in seq_len(nrow(editions))) {
  writeLines(c(
    "<!doctype html><html><body><article>",
    sprintf("<h1>Australian Crop Report No. %d</h1><time>%s</time>", editions$report[i], editions$date[i]),
    '<a href="../../workbooks/crop-national.xlsx">National data workbook</a>',
    '<a href="../../workbooks/crop-state.xlsx">State data workbook</a>',
    '<a href="../report.pdf">Report PDF</a>',
    "</article></body></html>"
  ), file.path(html_root, "crop", paste0(editions$slug[i], ".html")), useBytes = TRUE)
}

ac_archive <- c("<!doctype html><html><body>",
  sprintf(
    '<article><a href="commodities/%s.html">Agricultural Commodities — %s</a></article>',
    editions$slug, editions$date
  ),
  "</body></html>"
)
writeLines(ac_archive, file.path(html_root, "commodities-archive.html"), useBytes = TRUE)
for (i in seq_len(nrow(editions))) {
  outlook <- if (grepl("^march", editions$slug[i])) "ac-march-outlook.xlsx" else "ac-june-outlook.xlsx"
  writeLines(c(
    "<!doctype html><html><body><article>",
    sprintf("<h1>Agricultural Commodities</h1><time>%s</time>", editions$date[i]),
    sprintf('<a href="../../workbooks/%s">Outlook data workbook</a>', outlook),
    '<a href="../../workbooks/commodity-statistics.xlsx">Statistics workbook</a>',
    '<a href="../report.pdf">Report PDF</a>',
    "</article></body></html>"
  ), file.path(html_root, "commodities", paste0(editions$slug[i], ".html")), useBytes = TRUE)
}
