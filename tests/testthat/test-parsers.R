fixture_book <- function(name) {
  system.file("fixtures", "workbooks", name, package = "readagau")
}

test_that("all Crop Report parser families and seven geographies run offline", {
  cache <- withr::local_tempdir()
  national <- read_crop_report(
    c(national = fixture_book("crop-national.xlsx")),
    assets = "national", view = "reported", cache_dir = cache
  )
  state <- read_crop_report(
    c(state = fixture_book("crop-state.xlsx")),
    assets = "state", view = "reported", cache_dir = cache
  )
  expect_equal(length(unique(national$table_id)), 17)
  expect_equal(length(unique(state$table_id)), 7)
  expect_setequal(unique(state$geography), c(
    "Australia", "New South Wales", "Queensland", "South Australia",
    "Tasmania", "Victoria", "Western Australia"
  ))
  golden <- state[
    state$geography == "Australia" & state$commodity == "Wheat" &
      tolower(state$concept) == "production" & state$period == "2025-26",
  ]
  expect_equal(golden$value, 35985)
  expect_equal(golden$period_status, "estimate")
  expect_true("crop_national_table_17" %in% national$table_id)
  expect_true(any(grepl("crop_national_table_1[56]", national$table_id)))
  supply <- national[
    national$table_id == "crop_national_table_15" &
      national$commodity == "Wheat" &
      tolower(national$concept) == "production",
  ]
  expect_equal(supply$period, c("2024-25", "2025-26"))
  expect_equal(supply$value, c(2000, 3000))
  expect_false("2000" %in% national$period)
  expect_true(all(nzchar(national$source_note)))
  expect_true(all(grepl("Source:", national$source_note, fixed = TRUE)))
  expect_true("a" %in% unlist(national$footnote_codes, use.names = FALSE))
})

test_that("local files never infer official identity from names or mtimes", {
  path <- fixture_book("crop-national.xlsx")
  local <- read_crop_report(
    c(national = path), assets = "national", view = "reported",
    cache_dir = withr::local_tempdir()
  )
  expect_match(unique(local$release_id), "^local-[a-f0-9]{16}$")
  expect_true(all(is.na(local$release_date)))

  official <- read_crop_report(
    c(national = path), assets = "national", view = "reported",
    cache_dir = withr::local_tempdir(),
    release_id = "acr-2026-06-02-no-218",
    release_date = as.Date("2026-06-02")
  )
  expect_equal(unique(official$release_id), "acr-2026-06-02-no-218")
  expect_equal(unique(official$release_date), as.Date("2026-06-02"))
  expect_error(
    read_crop_report(
      c(national = path), assets = "national", view = "reported",
      cache_dir = withr::local_tempdir(),
      release_id = "acr-2026-06-02-no-218"
    ),
    class = "agau_validation_error"
  )
})

test_that("March and June outlook profiles retain exact forecast goldens", {
  cache <- withr::local_tempdir()
  march <- read_agricultural_commodities(
    c(outlook = fixture_book("ac-march-outlook.xlsx")),
    datasets = "outlook", view = "reported", cache_dir = cache
  )
  june <- read_agricultural_commodities(
    c(outlook = fixture_book("ac-june-outlook.xlsx")),
    datasets = "outlook", view = "reported", cache_dir = cache
  )
  expect_equal(length(unique(march$table_id)), 15)
  expect_equal(length(unique(june$table_id)), 13)
  m <- march[march$concept == "Value of agricultural exports", ]
  j <- june[june$concept == "Value of agricultural exports", ]
  expect_equal(m$value[m$period == "2025-26"], 80456.408)
  expect_equal(m$value[m$period == "2026-27"], 72844.562)
  expect_equal(j$value[j$period == "2025-26"], 81815.978)
  expect_equal(j$value[j$period == "2026-27"], 74815.698)
  expect_true("projection" %in% march$period_status)
  expect_true(any(grepl("percentage change", june$concept)))
})

test_that("all 18 Agricultural Commodity Statistics tables parse", {
  x <- read_agricultural_commodities(
    c(statistics = fixture_book("commodity-statistics.xlsx")),
    datasets = "statistics", view = "reported",
    cache_dir = withr::local_tempdir()
  )
  expect_equal(length(unique(x$table_id)), 18)
  expect_setequal(
    unique(x$table_id), sprintf("acs_table_%02d", 1:18)
  )
  expect_false(any(x$value == 0 & x$raw_value %in% c("na", "..")))
})

test_that("legacy 27-table Agricultural Commodity Statistics profile is admitted exactly", {
  meta <- list(
    product = "agricultural_commodities",
    release_id = "ac-2024-03-05"
  )
  expect_no_error(readagau:::agau_validate_workbook_sheets(
    paste("Table", 1:27),
    meta,
    "agricultural_commodities",
    "commodity_statistics"
  ))
  expect_error(
    readagau:::agau_validate_workbook_sheets(
      paste("Table", c(1:26, 28)),
      meta,
      "agricultural_commodities",
      "commodity_statistics"
    ),
    class = "agau_schema_error"
  )
})

test_that("legacy monthly Statistics labels retain exact month bounds", {
  labels <- c("Jun-01", "Sep-2001", "Dec-99")
  expect_true(all(readagau:::agau_period_like(labels)))
  bounds <- readagau:::agau_period_bounds(labels)
  expect_equal(
    bounds$period_start,
    as.Date(c("2001-06-01", "2001-09-01", "1999-12-01"))
  )
  expect_equal(
    bounds$period_end,
    as.Date(c("2001-06-30", "2001-09-30", "1999-12-31"))
  )
})

test_that("misleading OOXML extension and productivity methods are supported", {
  cache <- withr::local_tempdir()
  wrong <- fixture_book("farm-productivity-misnamed.xls")
  right <- fixture_book("farm-productivity.xlsx")
  expect_equal(agau_detect_format(wrong), "xlsx")
  a <- read_farm_productivity(wrong, view = "reported", cache_dir = cache)
  b <- read_farm_productivity(right, view = "reported", cache_dir = cache)
  expect_setequal(
    unique(a$method),
    c("conventional", "climate_adjusted", "interim_adjustment")
  )
  expect_true(all(
    a$method[a$period %in% c("2023-24", "2024-25") &
      grepl("^productivity_table_c", a$table_id)] == "interim_adjustment"
  ))
  expect_true(all(
    a$method[a$period == "2021-22" &
      grepl("^productivity_table_c", a$table_id)] == "climate_adjusted"
  ))
  expect_true(all(nzchar(a$source_note)))
  expect_equal(
    a[, c("table_id", "geography", "period", "method", "value")],
    b[, c("table_id", "geography", "period", "method", "value")]
  )
})

test_that("historical forecast database normalises compatible fields", {
  x <- read_agau_forecast_history(fixture_book("historical-forecast.csv"))
  expect_equal(nrow(x), 2)
  expect_equal(x$original_forecast, c(30560, 35985))
  expect_true(all(grepl("^[a-f0-9]{64}$", x$sha256)))
})

test_that("historical forecast database discovers and caches path NULL", {
  landing <- system.file(
    "fixtures", "html", "historical-forecasts.html", package = "readagau"
  )
  withr::local_options(list(readagau.hafd_landing_url = landing))
  x <- read_agau_forecast_history(
    path = NULL, cache_dir = withr::local_tempdir()
  )
  expect_equal(nrow(x), 2)
  expect_equal(x$original_forecast, c(30560, 35985))
  expect_match(unique(x$release_id), "2023-02-22")
  expect_match(unique(x$source_url), "historical-forecast\\.xlsx$")
})

test_that("historical forecast database replays cached raw without its landing page", {
  landing <- system.file(
    "fixtures", "html", "historical-forecasts.html", package = "readagau"
  )
  cache <- withr::local_tempdir()
  withr::local_options(list(readagau.hafd_landing_url = landing))
  first <- read_agau_forecast_history(path = NULL, cache_dir = cache)
  withr::local_options(list(
    readagau.hafd_landing_url = file.path(cache, "missing-landing.html")
  ))
  second <- read_agau_forecast_history(path = NULL, cache_dir = cache)
  expect_identical(second$sha256, first$sha256)
  expect_equal(second$original_forecast, first$original_forecast)
})

test_that("canonical keys are unique and validation reports provenance", {
  reported <- read_crop_report(
    c(national = fixture_book("crop-national.xlsx")),
    assets = "national", view = "reported",
    cache_dir = withr::local_tempdir()
  )
  x <- readagau:::agau_canonicalise(reported)
  expect_identical(anyDuplicated(x$observation_key), 0L)
  report <- validate_agau_release(reported)
  expect_true(report$valid)
  expect_equal(length(report$matched_table_ids), 17)
})

test_that("validation rejects incomplete provenance, invalid enums and duplicate canonical keys", {
  reported <- read_crop_report(
    c(national = fixture_book("crop-national.xlsx")),
    assets = "national", view = "reported",
    cache_dir = withr::local_tempdir()
  )

  missing_note <- reported
  missing_note$source_note[1] <- ""
  expect_false(validate_agau_release(missing_note)$valid)

  invalid_method <- reported
  invalid_method$method[1] <- "unreviewed_method"
  expect_false(validate_agau_release(invalid_method)$valid)

  canonical <- reported[1, ]
  canonical$record_role <- "canonical"
  duplicates <- rbind(canonical, canonical)
  duplicate_report <- validate_agau_release(duplicates)
  expect_false(duplicate_report$valid)
  expect_equal(duplicate_report$duplicate_canonical_observation_keys, 1)
})
