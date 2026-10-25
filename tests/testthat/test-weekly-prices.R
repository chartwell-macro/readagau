weekly_fixture <- function(...) {
  system.file("fixtures", ..., package = "readagau")
}

weekly_measures <- c(
  "latest_price", "previous_week", "weekly_change",
  "price_12_months_ago", "annual_change"
)

test_that("official current HTML is parsed end to end", {
  got <- read_agau_prices(
    snapshot = weekly_fixture("html", "weekly-prices-current.html")
  )
  expect_s3_class(got, "agau_weekly_prices")
  expect_equal(nrow(got), 110)
  expect_equal(length(unique(got$table_id)), 22)
  expect_equal(unique(got$release_date), as.Date("2026-07-23"))
  expect_true(validate_agau_release(got)$valid)
  wheat <- got[
    got$table_id == "weekly_A2" & got$record_role == "latest_price",
  ]
  expect_equal(wheat$value, 321)
  expect_equal(wheat$observation_date, as.Date("2026-07-22"))
})

test_that("all current accessible chart observations are parsed", {
  paths <- weekly_fixture(
    "html",
    c(
      "weekly-world-charts.html",
      "weekly-australian-charts.html",
      "weekly-horticulture-charts.html"
    )
  )
  got <- do.call(rbind, lapply(
    paths, readagau:::agau_parse_weekly_chart_html
  ))
  expect_equal(nrow(got), 33)
  expect_setequal(
    sub("weekly_", "", got$table_id),
    c(paste0("A", 1:25), paste0("H", 1:8))
  )
  expect_true(validate_agau_release(got)$valid)
  expect_true(all(got$status_source == "official_alt_text"))
})

test_that("transition and later official report profiles retain exact tables", {
  transition <- read_agau_prices(
    snapshot = weekly_fixture("text", "weekly-2016-10-13.txt")
  )
  archive <- read_agau_prices(
    snapshot = weekly_fixture("text", "weekly-2021-03-25.txt")
  )
  recent <- read_agau_prices(
    snapshot = weekly_fixture("text", "weekly-2025-07-10.txt")
  )
  expect_equal(c(nrow(transition), nrow(archive), nrow(recent)), c(95, 120, 110))
  expect_equal(
    vapply(
      list(transition, archive, recent),
      function(x) length(unique(x$table_id)),
      integer(1)
    ),
    c(19, 24, 22)
  )
  expect_equal(
    vapply(
      list(transition, archive, recent),
      function(x) validate_agau_release(x)$valid,
      logical(1)
    ),
    rep(TRUE, 3)
  )
  expect_true(any(is.na(archive$value) & archive$missing_reason == "provider_na"))
})

test_that("blank PDF measures are preserved as explicit provider NA", {
  lines <- readLines(
    weekly_fixture("text", "weekly-2025-07-10.txt"),
    warn = FALSE
  )
  row <- grep(
    "Wheat.*US no[.] 2 hard red winter", lines,
    ignore.case = TRUE
  )[[1]]
  lines[[row]] <- sub("-?[0-9]+%[[:space:]]*$", "      ", lines[[row]])
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(lines, path, useBytes = TRUE)
  got <- readagau:::agau_parse_weekly_text(path)
  annual <- got[
    got$table_id == "weekly_A2" & got$record_role == "annual_change",
  ]
  expect_true(is.na(annual$value))
  expect_equal(annual$missing_reason, "provider_na")
  expect_equal(readagau:::agau_weekly_value(NA_character_)$missing_reason, "provider_na")
  expect_equal(readagau:::agau_weekly_value("")$missing_reason, "provider_na")
  expect_equal(readagau:::agau_weekly_value("#N/A")$missing_reason, "provider_na")
  expect_equal(
    readagau:::agau_weekly_value("#DIV/0!")$missing_reason,
    "provider_error"
  )
  expect_equal(
    readagau:::agau_weekly_observation_date(
      "11-Dec", as.Date("2020-12-10")
    ),
    as.Date("2019-12-11")
  )
})

test_that("historical layout drift retains bounded, blank and error cells", {
  cases <- list(
    list(
      file = "weekly-2018-03-08.txt", table = "weekly_A4",
      measure = "annual_change", raw = ">-1%", reason = "bounded_value"
    ),
    list(
      file = "weekly-2018-05-17.txt", table = "weekly_L2",
      measure = "previous_week", raw = "", reason = "provider_na"
    ),
    list(
      file = "weekly-2018-07-05.txt", table = "weekly_A18",
      measure = "price_12_months_ago", raw = "na", reason = "provider_na"
    ),
    list(
      file = "weekly-2018-10-18.txt", table = "weekly_A9",
      measure = "price_12_months_ago", raw = "", reason = "provider_na"
    ),
    list(
      file = "weekly-2019-05-16.txt", table = "weekly_A12",
      measure = "previous_week", raw = "", reason = "provider_na"
    ),
    list(
      file = "weekly-2019-06-06.txt", table = "weekly_A12",
      measure = "weekly_change", raw = "#DIV/0!", reason = "provider_error"
    )
  )
  for (case in cases) {
    got <- read_agau_prices(
      snapshot = weekly_fixture("text", case$file)
    )
    expect_equal(nrow(got), 120, info = case$file)
    expect_equal(length(unique(got$table_id)), 24, info = case$file)
    expect_true(validate_agau_release(got)$valid, info = case$file)
    cell <- got[
      got$table_id == case$table & got$record_role == case$measure,
    ]
    expect_equal(nrow(cell), 1, info = case$file)
    expect_true(is.na(cell$value), info = case$file)
    expect_equal(cell$raw_value, case$raw, info = case$file)
    expect_equal(cell$missing_reason, case$reason, info = case$file)
  }
  wrapped <- read_agau_prices(
    snapshot = weekly_fixture("text", "weekly-2018-03-08.txt")
  )
  expect_equal(sum(wrapped$table_id == "weekly_A6"), 5)
})

test_that("Weekly catalogue routing and quarter IDs are exact", {
  weekly <- agau_series_catalog("weekly_commodity_prices")
  crop <- agau_series_catalog("crop_report")
  expect_equal(nrow(weekly), 35)
  expect_true(all(weekly$product == "weekly_commodity_prices"))
  expect_true(nrow(crop) > 0)
  expect_true(all(crop$product == "crop_report"))
  expect_equal(
    readagau:::agau_weekly_archive_release_id(
      as.Date(c("2016-03-31", "2016-12-15"))
    ),
    c("weekly-archive-2016-q1", "weekly-archive-2016-q4")
  )
})

test_that("release catalogue covers every audited complete-table snapshot", {
  got <- list_agau_releases("weekly_commodity_prices")
  supported <- got[got$support_status == "supported", ]
  expect_equal(nrow(got), 481)
  expect_equal(nrow(supported), 475)
  expect_equal(
    range(supported$release_date),
    as.Date(c("2016-10-13", "2026-07-23"))
  )
  expect_equal(sum(got$support_status == "discovered-unverified"), 6)
  expect_equal(anyDuplicated(got$release_id), 0)
  expect_true(all(lengths(supported$asset_urls) == 1L))
  unverified <- got[got$support_status == "discovered-unverified", ]
  expect_true(all(nzchar(unverified$unsupported_reason)))
  expect_true(all(
    is.na(supported$unsupported_reason) |
      !nzchar(supported$unsupported_reason)
  ))
  expect_true("weekly-prices-2022-01-13" %in% supported$release_id)
  expect_false("weekly-prices-2022-01-12" %in% got$release_id)
})

test_that("discovered source defects fail before download", {
  defective <- c(
    "weekly-prices-2021-01-14",
    "weekly-prices-2021-01-21",
    "weekly-prices-2021-11-25",
    "weekly-prices-2023-01-19",
    "weekly-prices-2024-11-21",
    "weekly-prices-2025-09-25"
  )
  for (release_id in defective) {
    expect_error(
      read_agau_prices(snapshot = release_id),
      class = "agau_asset_missing_error",
      info = release_id
    )
  }
})

test_that("cover issue identity outranks stale report footers", {
  text <- paste(
    "No. 10/2026 19 March 2026",
    "ABARES Weekly Australian Climate, Water and Agricultural Update",
    "19 March 2025"
  )
  expect_equal(
    readagau:::agau_weekly_release_date("", text),
    as.Date("2026-03-19")
  )
  expect_error(
    readagau:::agau_weekly_release_date(
      "", "No. 10/2026 19 March 2025"
    ),
    class = "agau_table_parse_error"
  )
  cover_typo <- paste(
    "No. 4/2024 2 February 2024",
    "ABARES Weekly Australian Climate, Water and Agricultural Update",
    "1 February 2024"
  )
  expect_equal(
    readagau:::agau_weekly_release_date(
      "WeeklyAustClimateWaterAglUpdate20240201.pdf", cover_typo
    ),
    as.Date("2024-02-01")
  )
  wrong_asset <- paste(
    "No. 47/2021 2 December 2021",
    "ABARES Weekly Australian Climate, Water and Agricultural Update",
    "2 December 2021"
  )
  expect_equal(
    readagau:::agau_weekly_release_date(
      "weeklyaustclimatewateraglupdate20211125.pdf", wrong_asset
    ),
    as.Date("2021-12-02")
  )
  expect_equal(
    readagau:::agau_weekly_observation_date(
      "15-Dec-21", as.Date("2022-01-20")
    ),
    as.Date("2021-12-15")
  )
  expect_equal(
    readagau:::agau_weekly_observation_date(
      "17-Feb-2021", as.Date("2022-01-20")
    ),
    as.Date("2021-02-17")
  )
})

test_that("Word reports parse a complete canonical price table", {
  directory <- withr::local_tempdir()
  dir.create(file.path(directory, "word"))
  registry <- readagau:::agau_weekly_series()[1:22, ]
  registry$indicator[registry$source_series_id == "A4"] <-
    "Canola – Rapeseed, Canada, FOB Vancouver"
  registry$indicator[registry$source_series_id == "A6"] <-
    "Sugar – Intercontinental Exchange, nearby futures, no.11 contract"
  registry$indicator[registry$source_series_id == "A9"] <-
    "Australian Premium White (APW) Wheat, FOB Port Adelaide, SA"
  registry$indicator[registry$source_series_id == "A10"] <-
    "Australian Standard White (ASW) Wheat, FOB Port Adelaide, SA"
  registry$indicator[registry$source_series_id == "A12"] <-
    "Canola – FOB Kwinana, WA"
  registry$indicator[registry$source_series_id == "A16"] <-
    "Lamb – National Trade Lamb Indicator"
  escape_xml <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
  }
  cell <- function(value) {
    paste0(
      "<w:tc><w:p><w:r><w:t>",
      escape_xml(value),
      "</w:t></w:r></w:p></w:tc>"
    )
  }
  row <- function(values) {
    paste0("<w:tr>", paste(vapply(values, cell, ""), collapse = ""), "</w:tr>")
  }
  header <- c(
    "Indicator", "Week average", "Unit", "Latest Price",
    "Previous Week", "Weekly change", "Price 12 months ago",
    "Annual change"
  )
  records <- vapply(seq_len(nrow(registry)), function(i) {
    row(c(
      registry$indicator[[i]], "17-Sep",
      if (registry$source_series_id[[i]] == "A1") "A$/US$" else "US$/t",
      as.character(100 + i), as.character(99 + i), "1%",
      as.character(90 + i), "10%"
    ))
  }, "")
  document <- paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/",
    "wordprocessingml/2006/main\"><w:body>",
    "<w:p><w:r><w:t>No. 37/2025 18 September 2025</w:t></w:r></w:p>",
    "<w:tbl>", row(header), paste(records, collapse = ""), "</w:tbl>",
    "</w:body></w:document>"
  )
  writeLines(document, file.path(directory, "word", "document.xml"))
  writeLines(
    paste0(
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/",
      "content-types\"><Default Extension=\"xml\" ",
      "ContentType=\"application/xml\"/></Types>"
    ),
    file.path(directory, "[Content_Types].xml")
  )
  docx <- file.path(directory, "weekly-report.docx")
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  utils::zip(
    docx, c("[Content_Types].xml", "word/document.xml"), flags = "-q"
  )
  expect_equal(agau_detect_format(docx), "docx")
  got <- read_agau_prices(snapshot = docx)
  expect_equal(nrow(got), 110)
  expect_equal(length(unique(got$table_id)), 22)
  expect_equal(unique(got$release_date), as.Date("2025-09-18"))
  expect_true(validate_agau_release(got)$valid)
})

test_that("ZIP parsing scopes members to requested supported dates", {
  directory <- withr::local_tempdir()
  supported <- file.path(
    directory, "WeeklyAustClimateWaterAglUpdate20161013.pdf"
  )
  pre_table <- file.path(
    directory, "WeeklyAustClimateWaterAglUpdate20161006.pdf"
  )
  file.copy(
    weekly_fixture("pdf", "weekly-2016-10-13.pdf"),
    supported
  )
  writeLines("pre-table narrative report", pre_table)
  archive <- file.path(directory, "weekly-2016q4.zip")
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  utils::zip(archive, basename(c(pre_table, supported)), flags = "-q")
  got <- readagau:::agau_parse_weekly_path(
    archive, weekly_measures,
    release_dates = as.Date("2016-10-13")
  )
  expect_equal(nrow(got), 95)
  expect_equal(unique(got$release_date), as.Date("2016-10-13"))
  expect_error(
    readagau:::agau_parse_weekly_path(
      archive, weekly_measures,
      release_dates = as.Date("2016-12-29")
    ),
    class = "agau_asset_missing_error"
  )
})

test_that("ZIP bytes and HTML header schema are detected fail closed", {
  directory <- withr::local_tempdir()
  member <- file.path(directory, "member.txt")
  writeLines("x", member)
  archive <- file.path(directory, "archive.zip")
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  utils::zip(archive, basename(member), flags = "-q")
  expect_equal(agau_detect_format(archive), "zip")

  html <- readLines(
    weekly_fixture("html", "weekly-prices-current.html"),
    warn = FALSE
  )
  html <- sub(
    "Latest price", "Latest quoted value", html,
    ignore.case = TRUE
  )
  changed <- file.path(directory, "changed.html")
  writeLines(html, changed, useBytes = TRUE)
  expect_error(
    read_agau_prices(snapshot = changed),
    class = "agau_table_parse_error"
  )
})
