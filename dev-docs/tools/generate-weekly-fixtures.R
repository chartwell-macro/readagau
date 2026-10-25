# Generate the reduced Weekly fixtures used by the package tests.
#
# These files intentionally contain package-owned synthetic values.  The
# labels below follow the source-series registry because the parser's identity
# matching is part of the contract; they are not copied source observations.

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)

fixture_root <- file.path(root, "inst", "fixtures")
html_root <- file.path(fixture_root, "html")
text_root <- file.path(fixture_root, "text")
pdf_root <- file.path(fixture_root, "pdf")
dir.create(html_root, recursive = TRUE, showWarnings = FALSE)
dir.create(text_root, recursive = TRUE, showWarnings = FALSE)
dir.create(pdf_root, recursive = TRUE, showWarnings = FALSE)

write_utf8 <- function(path, lines) {
  writeLines(lines, path, useBytes = TRUE)
}

escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

escape_pdf <- function(x) {
  gsub("([\\\\()])", "\\\\\\1", x, perl = TRUE)
}

registry <- utils::read.csv(
  file.path(root, "inst", "config", "weekly-series.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
ids <- registry$source_series_id

# Keep the identity-bearing phrases that the registry requires, while making
# every rendered label explicitly synthetic and ASCII-safe for PDF extraction.
labels <- registry$indicator
labels <- gsub("[\u2010-\u2014\u2212]", "-", labels, perl = TRUE)
names(labels) <- ids
labels[c("A1", "A4", "A6", "A9", "A10", "A12", "A16", "L1", "L2")] <- c(
  "AUD/USD exchange rate",
  "Canola - Rapeseed, Canada, FOB Vancouver",
  "Sugar - Intercontinental Exchange, nearby futures, no. 11 contract",
  "Australian Premium White (APW) Wheat, FOB Port Adelaide",
  "Australian Standard White (ASW) Wheat, FOB Port Adelaide",
  "Canola - FOB Kwinana",
  "Lamb - National Trade Lamb Indicator",
  "Goats - synthetic indicator",
  "Live sheep export indicator"
)
labels <- paste0(labels, " [Synthetic fixture]")
names(labels) <- ids

units <- setNames(rep("US$/t", length(ids)), ids)
units[c("A1")] <- "A$/US$"
units[c("A5", "A6")] <- "USc/lb"
units[c("A7", "A8")] <- "Ac/kg clean"
units[c("A9", "A10", "A11", "A12", "A13", "A23", "A24", "A25")] <- "A$/t"
units[c("A14", "A15", "A16", "A17", "L1", "L2")] <- "Ac/kg cwt"
units[c("A18")] <- "Ac/kg lwt"
units[c("H1", "H2", "H3", "H4", "H5", "H6", "H7", "H8")] <- "index points"

groups <- list(
  world = paste0("A", 1:8),
  grain = paste0("A", 9:13),
  livestock = paste0("A", 14:18),
  dairy = paste0("A", 19:22)
)

value_set <- function(id, position, kind = c("table", "chart")) {
  kind <- match.arg(kind)
  latest <- if (kind == "table" && identical(id, "A2")) {
    # Kept as a deliberately simple synthetic assertion value for the public
    # fixture contract; it is not presented as a source observation.
    "321"
  } else if (identical(id, "A1")) {
    "101"
  } else {
    as.character(200L + position)
  }
  list(
    latest = latest,
    previous = as.character(190L + position),
    weekly = if (position %% 2L) "1%" else "-1%",
    year_ago = as.character(150L + position),
    annual = if (position %% 3L) "5%" else "-2%"
  )
}

table_row <- function(id, position) {
  values <- value_set(id, position, "table")
  paste0(
    "<tr><td>", escape_html(labels[[id]]), "</td>",
    "<td>22-Jul</td><td>", escape_html(units[[id]]), "</td>",
    "<td>", values$latest, "</td><td>", values$previous, "</td>",
    "<td>", values$weekly, "</td><td>", values$year_ago, "</td>",
    "<td>", values$annual, "</td></tr>"
  )
}

group_row <- function(title) {
  paste0(
    "<tr><td colspan=\"8\"><strong>", escape_html(title),
    "</strong></td></tr>"
  )
}

group_titles <- c(
  world = "Synthetic world indicator group",
  grain = "Synthetic Australian grain group",
  livestock = "Synthetic livestock indicator group",
  dairy = "Synthetic dairy indicator group"
)

current_rows <- character()
position <- 0L
for (group_name in names(groups)) {
  current_rows <- c(current_rows, group_row(group_titles[[group_name]]))
  for (id in groups[[group_name]]) {
    position <- position + 1L
    current_rows <- c(current_rows, table_row(id, position))
  }
}
write_utf8(
  file.path(html_root, "weekly-prices-current.html"),
  c(
    "<!doctype html>",
    "<html><head><meta charset=\"utf-8\"><title>Synthetic fixture: weekly prices</title></head>",
    "<body>",
    "<h1>Synthetic fixture: weekly commodity prices</h1>",
    "<p>Synthetic fixture only. No. 29/2026 23 July 2026</p>",
    "<p>Current indicators - 23 July 2026</p>",
    paste0(
      "<table><thead><tr><th>Indicator</th><th>Week average</th>",
      "<th>Unit</th><th>Latest Price</th><th>Previous Week</th>",
      "<th>Weekly change</th><th>Price 12 months ago</th>",
      "<th>Annual change</th></tr></thead><tbody>",
      paste(current_rows, collapse = ""), "</tbody></table>"
    ),
    "<p>Synthetic fixture values are package-owned and are not source observations.</p>",
    "</body></html>"
  )
)

chart_page <- function(path, page_ids) {
  rows <- vapply(seq_along(page_ids), function(i) {
    id <- page_ids[[i]]
    values <- value_set(id, match(id, ids), "chart")
    paste0(
      "  <figure><img src=\"chart_", id,
      "_2026-07-16.png\" alt=\"Synthetic fixture: prices for ",
      escape_html(labels[[id]]),
      " from 2024 to 2026. The price on 15 July 2026 was ",
      values$latest, " ", escape_html(units[[id]]), ".\"></figure>"
    )
  }, "")
  write_utf8(path, c(
    "<!doctype html>",
    "<html><head><meta charset=\"utf-8\"><title>Synthetic fixture: weekly charts</title></head>",
    "<body><h1>Synthetic fixture: weekly price charts</h1>",
    "<p>All chart descriptions and values on this page are package-owned synthetic test data.</p>",
    rows,
    "</body></html>"
  ))
}

chart_page(file.path(html_root, "weekly-world-charts.html"), paste0("A", 1:8))
chart_page(file.path(html_root, "weekly-australian-charts.html"), paste0("A", 9:25))
chart_page(file.path(html_root, "weekly-horticulture-charts.html"), paste0("H", 1:8))

# Release discovery uses only the exact audited URL plus this edition-bearing
# heading.  No official page prose or asset URL is required for this fixture.
write_utf8(
  file.path(html_root, "crop-june-2026-real-page-excerpt.html"),
  c(
    "<!doctype html>",
    "<html><head><meta charset=\"utf-8\"><title>Synthetic fixture: Australian Crop Report June 2026</title></head>",
    "<body><h1>Australian Crop Report June 2026</h1>",
    "<p>Synthetic fixture only. Release identity is supplied by the test's audited landing URL.</p>",
    "</body></html>"
  )
)

text_line <- function(id, date_label, values, label_width = 120L) {
  # Fixed columns are intentional: the parser uses the preceding complete row
  # to recover blank cells in historical layout-drift profiles.
  sprintf(
    "%-120s  %-8s  %-13s  %8s  %8s  %8s  %8s  %8s",
    labels[[id]], date_label, units[[id]], values$latest, values$previous,
    values$weekly, values$year_ago, values$annual
  )
}

profile_lines <- function(date, profile_ids, overrides = list(), issue = 1L) {
  release <- as.Date(date)
  date_label <- format(release - 1L, "%d-%b")
  header <- paste(
    "Indicator", "Week average", "Unit", "Latest", "Previous Week",
    "Weekly change", "Price 12 months ago", "Annual change", sep = "  "
  )
  lines <- c(
    "Synthetic fixture only - package-owned reduced profile",
    sprintf("No. %d/%s %s", issue, format(release, "%Y"), format(release, "%d %B %Y")),
    "The following rows contain synthetic values for parser contract tests.",
    header
  )
  for (i in seq_along(profile_ids)) {
    id <- profile_ids[[i]]
    values <- value_set(id, match(id, ids), "table")
    if (length(overrides[[id]])) {
      values[names(overrides[[id]])] <- overrides[[id]]
    }
    lines <- c(lines, text_line(id, date_label, values))
  }
  lines
}

write_utf8(
  file.path(text_root, "weekly-2016-10-13.txt"),
  profile_lines("2016-10-13", c(paste0("A", 1:17), "L1", "L2"), issue = 1L)
)
write_utf8(
  file.path(text_root, "weekly-2021-03-25.txt"),
  profile_lines(
    "2021-03-25", c(paste0("A", 1:22), "L1", "L2"),
    overrides = list(A1 = list(latest = "#N/A")), issue = 11L
  )
)
write_utf8(
  file.path(text_root, "weekly-2025-07-10.txt"),
  profile_lines("2025-07-10", paste0("A", 1:22), issue = 27L)
)

anomaly_profiles <- list(
  list(
    file = "weekly-2018-03-08.txt", date = "2018-03-08", issue = 10L,
    id = "A4", field = "annual", value = ">-1%"
  ),
  list(
    file = "weekly-2018-05-17.txt", date = "2018-05-17", issue = 20L,
    id = "L2", field = "previous", value = ""
  ),
  list(
    file = "weekly-2018-07-05.txt", date = "2018-07-05", issue = 26L,
    id = "A18", field = "year_ago", value = "na"
  ),
  list(
    file = "weekly-2018-10-18.txt", date = "2018-10-18", issue = 41L,
    id = "A9", field = "year_ago", value = ""
  ),
  list(
    file = "weekly-2019-05-16.txt", date = "2019-05-16", issue = 19L,
    id = "A12", field = "previous", value = ""
  ),
  list(
    file = "weekly-2019-06-06.txt", date = "2019-06-06", issue = 22L,
    id = "A12", field = "weekly", value = "#DIV/0!"
  )
)
for (case in anomaly_profiles) {
  overrides <- list()
  overrides[[case$id]] <- setNames(list(case$value), case$field)
  write_utf8(
    file.path(text_root, case$file),
    profile_lines(
      case$date, c(paste0("A", 1:22), "L1", "L2"),
      overrides = overrides, issue = case$issue
    )
  )
}

# Build a small valid PDF directly from the PDF object grammar.  Using a
# literal Courier text stream keeps hyphens and fixed-column whitespace stable
# under Poppler's `pdftotext -layout`, while avoiding any external source bytes.
make_pdf <- function(path, lines, lines_per_page = 49L) {
  pages <- split(lines, ceiling(seq_along(lines) / lines_per_page))
  page_count <- length(pages)
  page_ids <- 3L + seq_len(page_count) - 1L
  content_ids <- 3L + page_count + seq_len(page_count) - 1L
  font_id <- 3L + (2L * page_count)
  kids <- paste0(page_ids, " 0 R", collapse = " ")
  page_objects <- vapply(seq_len(page_count), function(i) {
    paste0(
      # The synthetic registry labels are intentionally identity-bearing and
      # can be long.  Keep every glyph inside the page box so Poppler versions
      # on Windows and Unix extract the same complete rows.
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 1200 792] ",
      "/Resources << /Font << /F1 ", font_id, " 0 R >> >> /Contents ",
      content_ids[[i]], " 0 R >>"
    )
  }, "")
  content_objects <- vapply(pages, function(page) {
    body <- c("BT", "/F1 7 Tf", "28 760 Td")
    for (i in seq_along(page)) {
      if (i > 1L) body <- c(body, "0 -14 Td")
      body <- c(body, paste0("(", escape_pdf(page[[i]]), ") Tj"))
    }
    stream <- paste0(paste(body, collapse = "\n"), "\nET\n")
    paste0(
      "<< /Length ", nchar(stream, type = "bytes"), " >>\nstream\n",
      stream, "endstream"
    )
  }, "")
  objects <- c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    paste0("<< /Type /Pages /Kids [", kids, "] /Count ", page_count, " >>"),
    page_objects,
    content_objects,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>"
  )
  output <- "%PDF-1.4\n% synthetic fixture\n"
  offsets <- numeric(length(objects))
  for (i in seq_along(objects)) {
    offsets[[i]] <- nchar(output, type = "bytes")
    output <- paste0(output, i, " 0 obj\n", objects[[i]], "\nendobj\n")
  }
  xref <- nchar(output, type = "bytes")
  output <- paste0(
    output, "xref\n0 ", length(objects) + 1L,
    "\n0000000000 65535 f \n",
    paste(sprintf("%010d 00000 n ", offsets), collapse = "\n"),
    "\ntrailer\n<< /Size ", length(objects) + 1L,
    " /Root 1 0 R >>\nstartxref\n", xref, "\n%%EOF\n"
  )
  writeBin(charToRaw(output), path)
}

pdf_ids <- c(paste0("A", 1:17), "L1", "L2")
pdf_values <- lapply(seq_along(pdf_ids), function(i) value_set(pdf_ids[[i]], i, "table"))
pdf_lines <- c(
  "Synthetic fixture only - package-owned reduced PDF profile",
  "No. 1/2016 13 October 2016",
  "Indicator  Week average  Unit  Latest  Previous Week  Weekly change  Price 12 months ago  Annual change",
  vapply(seq_along(pdf_ids), function(i) {
    values <- pdf_values[[i]]
    paste(
      labels[[pdf_ids[[i]]]], "12-Oct", units[[pdf_ids[[i]]]], values$latest,
      values$previous, values$weekly, values$year_ago, values$annual,
      sep = "  "
    )
  }, ""),
  "Synthetic fixture only"
)
make_pdf(file.path(pdf_root, "weekly-2016-10-13.pdf"), pdf_lines)

message("Generated synthetic Weekly HTML, text and PDF fixtures under ", fixture_root)
