quarterly_cache_row <- function(product, release_id, role, path, source_url) {
  data.frame(
    product = product, release_id = release_id, asset_type = role,
    source_url = source_url, source_filename = basename(path),
    detected_format = readagau:::agau_detect_format(path),
    content_type = NA_character_,
    retrieved_at = as.POSIXct("2026-07-27 00:00:00", tz = "UTC"),
    etag = NA_character_, last_modified = NA_character_,
    sha256 = readagau:::agau_sha256(path),
    bytes = as.numeric(file.info(path)$size), local_path = path,
    validation_status = "valid", unsupported_reason = NA_character_,
    stringsAsFactors = FALSE
  )
}

test_that("legacy Crop Report column headers retain semantic measures", {
  fixture <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  meta <- readagau:::agau_local_meta(
    fixture, "crop_report", "national",
    release_id = "acr-2013-02-01-no-165",
    release_date = as.Date("2013-02-01")
  )
  x <- rbind(
    c("Table 12 Australian crop production", rep("", 12)),
    c("Crop", "Area planted", "", "", "", "Yield", "", "", "",
      "Production", "", "", ""),
    c("", "average a", "2010-11", "2011-12 s", "2012-13 f",
      "average a", "2010-11", "2011-12 s", "2012-13 f",
      "average a", "2010-11", "2011-12 s", "2012-13 f"),
    c("", rep("'000 ha", 4), rep("t/ha", 4), rep("kt", 4)),
    c("Barley", "4358.7", "3681.0", "3774", "3874.6",
      "1.84", "2.17", "2.21", "1.82",
      "7873.0", "7994.7", "8349", "7062.3")
  )
  rows <- readagau:::agau_legacy_crop_sheet_rows(
    x, meta, "Table 12", "crop_report_national"
  )
  got <- readagau:::agau_bind_observations(rows, "crop_report_data")
  forecast <- got[got$period_status == "forecast", ]

  expect_setequal(unique(got$commodity), "Barley")
  expect_setequal(
    unique(got$concept),
    c("Area planted", "Yield", "Production")
  )
  expect_setequal(unique(got$unit), c("'000 ha", "t/ha", "kt"))
  expect_equal(
    forecast$value[match(
      c("Area planted", "Yield", "Production"),
      forecast$concept
    )],
    c(3874.6, 1.82, 7062.3)
  )
  expect_false(any(grepl("published value", got$concept, ignore.case = TRUE)))
})

test_that("legacy Crop Report row periods separate commodity and measure", {
  fixture <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  meta <- readagau:::agau_local_meta(
    fixture, "crop_report", "national",
    release_id = "acr-2019-02-01-no-189",
    release_date = as.Date("2019-02-01")
  )
  x <- rbind(
    c("", "", "", "", "AUSTRALIAN CROP REPORT"),
    c("Table 14 Production, major crops, Australian states, 2017-18 to 2018-19",
      rep("", 4)),
    c("Winter Crop", "New South", "", "", ""),
    c("", "Wales", "", "Victoria", ""),
    c("", "area", "prod.", "area", "prod."),
    c("", "'000 ha", "kt", "'000 ha", "kt"),
    c("Barley", "", "", "", ""),
    c("2018-19 f", "600", "630", "770", "1100"),
    c("2017-18 s", "790", "1185", "800", "2100")
  )
  rows <- readagau:::agau_legacy_crop_sheet_rows(
    x, meta, "Table 14", "crop_report_national"
  )
  got <- readagau:::agau_bind_observations(rows, "crop_report_data")

  expect_setequal(unique(got$commodity), "Barley")
  expect_setequal(unique(got$concept), c("Area", "Production"))
  expect_setequal(
    unique(got$geography),
    c("New South Wales", "Victoria")
  )
  expect_setequal(unique(got$unit), c("'000 ha", "kt"))
  expect_false(any(grepl("published value", got$concept, ignore.case = TRUE)))
})

test_that("legacy Crop Report snapshots use semantic sparse headers", {
  fixture <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  meta <- readagau:::agau_local_meta(
    fixture, "crop_report", "national",
    release_id = "acr-2011-12-01-no-160",
    release_date = as.Date("2011-12-01")
  )
  x <- rbind(
    c("", "", "", "", "", "", "", "", "AUSTRALIAN CROP REPORT"),
    c("Table 5 Winter crop forecasts, 2011-12, New South Wales",
      rep("", 8)),
    rep("", 9),
    c("", "area", "", "yield", "", "a", "production", "",
      "production change from 2010-11"),
    c("", "'000 ha", "", "t/ha", "", "", "kt", "", "%"),
    rep("", 9),
    c("Wheat", "4000", "", "2.10", "AG55", "", "8400", "", "4.2"),
    c("Barley", "880", "", "1.9318", "AG56", "", "1700", "", "-24.41")
  )
  rows <- readagau:::agau_legacy_crop_sheet_rows(
    x, meta, "Table 5", "crop_report_national"
  )
  got <- readagau:::agau_bind_observations(rows, "crop_report_data")
  barley <- got[got$commodity == "Barley", ]

  expect_setequal(unique(got$commodity), c("Wheat", "Barley"))
  expect_setequal(
    unique(got$concept),
    c("Area", "Yield", "Production", "Production change")
  )
  expect_setequal(unique(got$unit), c("'000 ha", "t/ha", "kt", "%"))
  expect_setequal(unique(got$geography), "New South Wales")
  expect_true(all(got$period_status == "forecast"))
  expect_equal(
    barley$value[match(
      c("Area", "Yield", "Production", "Production change"),
      barley$concept
    )],
    c(880, 1.9318, 1700, -24.41)
  )
  expect_false(any(grepl("published value", got$concept, ignore.case = TRUE)))
})

test_that("duplicate national crop aggregates share one semantic identity", {
  fixture <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  got <- read_crop_report(
    release = c(national = fixture),
    assets = "national",
    view = "reported",
    release_id = "acr-2026-06-02-no-218",
    release_date = as.Date("2026-06-02"),
    cache_dir = withr::local_tempdir()
  )
  source <- got[
    got$commodity == "Wheat" &
      tolower(got$concept) == "area" &
      got$geography == "Australia",
    ,
    drop = FALSE
  ][1L, , drop = FALSE]
  expect_equal(nrow(source), 1L)
  source$season <- "winter"

  duplicate <- source
  duplicate$source_dataset <- "crop_report_state"
  duplicate$source_asset <- "state"
  duplicate$source_sheet <- "Australia"
  duplicate$season <- "not_applicable"
  combined <- rbind(source, duplicate)
  combined <- readagau:::agau_rekey_data(combined)
  expect_equal(length(unique(combined$series_id)), 2L)

  harmonised <- readagau:::agau_harmonise_crop_identity(combined)
  expect_equal(nrow(harmonised), 1L)
  expect_equal(harmonised$commodity, "Wheat")
  expect_equal(harmonised$season, "winter")
  expect_equal(harmonised$source_dataset, "crop_report_national")
})

test_that("compatible crop duplicates retain the longer forecast horizon", {
  fixture <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  got <- read_crop_report(
    release = c(national = fixture),
    assets = "national",
    view = "reported",
    release_id = "acr-2026-06-02-no-218",
    release_date = as.Date("2026-06-02"),
    cache_dir = withr::local_tempdir()
  )
  source <- got[
    got$commodity == "Wheat" &
      tolower(got$concept) == "area" &
      got$geography == "Australia",
    ,
    drop = FALSE
  ][1L, , drop = FALSE]
  source$commodity <- "Corn (maize)"
  source$season <- "summer"

  national <- source[rep(1L, 2L), , drop = FALSE]
  national$period <- c("2024-25", "2025-26")
  national$period_end <- as.Date(c("2025-06-30", "2026-06-30"))
  national$value <- c(50, 55)

  state <- national
  state$source_dataset <- "crop_report_state"
  state$source_asset <- "state"
  state$source_sheet <- "Australia"
  state$season <- "not_applicable"
  extension <- state[2L, , drop = FALSE]
  extension$period <- "2026-27"
  extension$period_end <- as.Date("2027-06-30")
  extension$value <- 60
  state <- rbind(state, extension)

  combined <- readagau:::agau_rekey_data(rbind(national, state))
  expect_equal(length(unique(combined$series_id)), 2L)

  harmonised <- readagau:::agau_harmonise_crop_identity(combined)
  expect_equal(nrow(harmonised), 3L)
  expect_equal(length(unique(harmonised$series_id)), 1L)
  expect_equal(unique(harmonised$season), "summer")
  expect_equal(max(harmonised$period_end), as.Date("2027-06-30"))
  expect_equal(
    harmonised$source_dataset[
      harmonised$period_end == as.Date("2027-06-30")
    ],
    "crop_report_state"
  )
})

test_that("conflicting crop lookalikes remain separate series", {
  fixture <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  got <- read_crop_report(
    release = c(national = fixture),
    assets = "national",
    view = "reported",
    release_id = "acr-2026-06-02-no-218",
    release_date = as.Date("2026-06-02"),
    cache_dir = withr::local_tempdir()
  )
  national <- got[
    got$commodity == "Wheat" &
      tolower(got$concept) == "area" &
      got$geography == "Australia",
    ,
    drop = FALSE
  ][1L, , drop = FALSE]
  national$commodity <- "Corn (maize)"
  national$season <- "summer"
  national$value <- 50

  state <- national
  state$source_dataset <- "crop_report_state"
  state$source_asset <- "state"
  state$source_sheet <- "Australia"
  state$season <- "not_applicable"
  state$value <- 51

  combined <- readagau:::agau_rekey_data(rbind(national, state))
  harmonised <- readagau:::agau_harmonise_crop_identity(combined)

  expect_equal(nrow(harmonised), 2L)
  expect_equal(length(unique(harmonised$series_id)), 2L)
  expect_setequal(unique(harmonised$season), c("summer", "not_applicable"))
  expect_equal(sort(harmonised$value), c(50, 51))
})

test_that("quarterly catalogue covers every edition from 2010", {
  releases <- readagau:::agau_bundled_releases()
  crop <- releases[releases$product == "crop_report", ]
  outlook <- releases[releases$product == "agricultural_commodities", ]

  expect_equal(nrow(crop), 66)
  expect_equal(nrow(outlook), 66)
  expect_equal(range(crop$release_date), as.Date(c(
    "2010-02-01", "2026-06-02"
  )))
  expect_equal(range(outlook$release_date), as.Date(c(
    "2010-03-01", "2026-06-02"
  )))
  expect_true(all(crop$support_status == "supported"))
  expect_true(all(outlook$support_status == "supported"))
  expect_false(any(grepl("-no-(?:NA)?$", crop$release_id)))
  expect_false(any(is.na(crop$report_number) | !nzchar(crop$report_number)))
  expect_setequal(crop$report_number, as.character(153:218))
  expect_equal(
    crop$report_number[crop$edition == "June 2022"],
    "202"
  )

  expect_true(all(lengths(crop$asset_urls) >= 1L))
  expect_true(all(lengths(outlook$asset_urls) >= 1L))
  expect_true(all(vapply(
    c(crop$asset_urls, outlook$asset_urls),
    function(urls) all(grepl(
      "^https://daff[.]ent[.]sirsidynix[.]net[.]au/client/en_AU/search/asset/",
      urls
    )),
    logical(1)
  )))
  expect_equal(sum(vapply(
    outlook$asset_roles, function(x) "outlook" %in% x, logical(1)
  )), 64)
  expect_setequal(
    outlook$release_id[vapply(
      outlook$asset_roles, function(x) "report" %in% x, logical(1)
    )],
    c("ac-2010-03-01", "ac-2010-06-01")
  )
})

test_that("report-backed outlook role survives exact release resolution", {
  expect_equal(
    readagau:::agau_ac_dataset_role(c("outlook", "report", "statistics")),
    c("outlook", "outlook", "statistics")
  )
  cache <- withr::local_tempdir()
  path <- system.file("fixtures", "html", "report.pdf", package = "readagau")
  release_id <- "ac-2010-03-01"
  row <- quarterly_cache_row(
    "agricultural_commodities", release_id, "report", path,
    paste0(
      "https://daff.ent.sirsidynix.net.au/client/en_AU/search/asset/",
      "1027644/0"
    )
  )
  readagau:::agau_write_asset_index(
    row, cache, "agricultural_commodities", release_id
  )
  got <- readagau:::agau_resolve_reader_assets(
    "agricultural_commodities", release_id, "outlook", cache, FALSE
  )
  expect_equal(got$asset_type, "report")
})

test_that("exact historical release IDs parse end-to-end from immutable cache", {
  cases <- list(
    list(
      product = "crop_report", release = "acr-2010-02-01-no-153",
      role = "national", fixture = "crop-national.xlsx"
    ),
    list(
      product = "agricultural_commodities", release = "ac-2020-03-01",
      role = "outlook", fixture = "ac-march-outlook.xlsx"
    ),
    list(
      product = "crop_report", release = "acr-2024-03-05-no-209",
      role = "national", fixture = "crop-national.xlsx"
    )
  )
  for (case in cases) {
    cache <- withr::local_tempdir()
    path <- system.file(
      "fixtures", "workbooks", case$fixture, package = "readagau"
    )
    releases <- readagau:::agau_bundled_releases()
    hit <- releases[releases$release_id == case$release, ]
    source_url <- hit$asset_urls[[1]][[case$role]]
    row <- quarterly_cache_row(
      case$product, case$release, case$role, path, source_url
    )
    readagau:::agau_write_asset_index(
      row, cache, case$product, case$release
    )
    got <- if (case$product == "crop_report") {
      read_crop_report(
        case$release, assets = case$role, view = "reported",
        cache_dir = cache
      )
    } else {
      read_agricultural_commodities(
        case$release, datasets = case$role, view = "reported",
        cache_dir = cache
      )
    }
    expect_gt(nrow(got), 0)
    expect_true(validate_agau_release(got)$valid, info = case$release)
    expect_equal(unique(got$release_id), case$release)
  }
})

test_that("statistics-only request rejects report-only outlook editions", {
  expect_error(
    readagau:::agau_resolve_reader_assets(
      "agricultural_commodities", "ac-2010-03-01", "statistics",
      withr::local_tempdir(), FALSE
    ),
    "not available",
    class = "agau_validation_error"
  )
})

test_that("2010 report-backed Major indicators profiles retain real levels", {
  march_page <- paste(
    "Major indicators of Australia's commodities sector",
    "                         2007       2008       2009       2010       2011       2012       2013       2014",
    "               unit       -08        -09      -10 f      -11 f      -12 z      -13 z      -14 z      -15 z",
    "Commodity exports",
    "Exchange rate  US$/A$     0.90       0.75       0.88       0.88       0.86       0.84       0.82       0.80",
    sep = "\n"
  )
  june_page <- paste(
    "Major indicators of Australia's commodity sector",
    "                         2005       2006       2007       2008       2009       2010",
    "               unit       -06        -07        -08        -09      -10 s      -11 f",
    "Commodity exports",
    "Exchange rate  US$/A$     0.75       0.78       0.90       0.75       0.88       0.87       17.3       -1.1",
    sep = "\n"
  )
  fixture <- system.file(
    "fixtures", "workbooks", "ac-march-outlook.xlsx", package = "readagau"
  )
  make_meta <- function(date) readagau:::agau_local_meta(
    fixture, "agricultural_commodities", "report",
    release_id = paste0("ac-", date), release_date = as.Date(date)
  )
  march <- readagau:::agau_bind_observations(
    readagau:::agau_parse_2010_outlook_indicators(
      march_page, make_meta("2010-03-01")
    ),
    "agricultural_commodities_data"
  )
  june <- readagau:::agau_bind_observations(
    readagau:::agau_parse_2010_outlook_indicators(
      june_page, make_meta("2010-06-01")
    ),
    "agricultural_commodities_data"
  )

  expect_equal(march$value, c(0.90, 0.75, 0.88, 0.88, 0.86, 0.84, 0.82, 0.80))
  expect_equal(march$period_status[3:8], c(
    "forecast", "forecast", rep("projection", 4)
  ))
  expect_equal(june$value, c(0.75, 0.78, 0.90, 0.75, 0.88, 0.87, 17.3, -1.1))
  expect_equal(tail(june$concept, 2), rep("change from previous year", 2))
  expect_true(validate_agau_release(march)$valid)
  expect_true(validate_agau_release(june)$valid)
})
