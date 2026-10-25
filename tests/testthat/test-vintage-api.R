vintage_api_fixture <- function() {
  state <- read_crop_report(
    c(state = system.file(
      "fixtures", "workbooks", "crop-state.xlsx", package = "readagau"
    )),
    assets = "state", view = "canonical",
    cache_dir = withr::local_tempdir()
  )
  base <- state[
    state$geography == "Australia" & state$commodity == "Wheat" &
      tolower(state$concept) == "production" & state$period == "2025-26",
  ][1, ]
  releases <- c(
    "acr-2025-06-03-no-214", "acr-2025-09-02-no-215",
    "acr-2025-12-02-no-216", "acr-2026-03-03-no-217"
  )
  out <- base[rep(1, 4), ]
  out$release_id <- releases
  out$release_date <- as.Date(c(
    "2025-06-03", "2025-09-02", "2025-12-02", "2026-03-03"
  ))
  out$period_status <- c("forecast", "forecast", "forecast", "estimate")
  out$status_source <- "suffix"
  out$value <- c(30560, 33765, 35585, 35985)
  out$raw_value <- as.character(out$value)
  out$sha256 <- vapply(
    seq_len(4), function(i) paste(rep(i, 64), collapse = ""), ""
  )
  out
}

test_that("forecast revisions expose horizon, round and selection semantics", {
  got <- agau_forecast_revision(vintage_api_fixture())

  expect_equal(got$old_issue_to_target_horizon_months, c(12L, 9L, 6L))
  expect_equal(got$new_issue_to_target_horizon_months, c(9L, 6L, 3L))
  expect_equal(got$old_report_round, 1:3)
  expect_equal(got$new_report_round, 2:4)
  expect_equal(got$revision_number, 1:3)
  expect_true(all(got$revision_count == 3L))
  expect_true(all(got$first_forecast_value == 30560))
  expect_equal(got$previous_forecast_value, c(30560, 33765, 35585))
  expect_true(all(got$latest_forecast_value == 35585))
  expect_true(all(got$first_forecast_status == "forecast"))
  expect_true(all(got$latest_forecast_status == "forecast"))
})

test_that("semantic metadata structural breaks fail with a diagnostic report", {
  broken <- vintage_api_fixture()
  broken$unit[4] <- "tonnes"
  broken <- readagau:::agau_rekey_data(broken)

  condition <- tryCatch(
    agau_forecast_revision(broken),
    agau_validation_error = identity
  )
  expect_s3_class(condition, "agau_validation_error")
  expect_s3_class(condition$structural_breaks, "tbl_df")
  expect_match(condition$structural_breaks$fields[[1]], "unit")
})

test_that("compare_agau_vintages loads exact releases through a test seam", {
  source <- vintage_api_fixture()
  calls <- character()
  loader <- function(product, release, release_id, cache_dir) {
    calls <<- c(calls, release_id)
    source[source$release_id == release_id, , drop = FALSE]
  }
  withr::local_options(list(readagau.vintage_loader = loader))

  got <- compare_agau_vintages(
    "crop_report", data = NULL, releases = source$release_id,
    comparison = "forecast_revision",
    cache_dir = withr::local_tempdir()
  )
  expect_equal(calls, source$release_id)
  expect_equal(got$old_value, c(30560, 33765, 35585))
  expect_equal(got$new_value, c(33765, 35585, 35985))
})

test_that("named local release assets load without discovery or network", {
  path <- system.file(
    "fixtures", "workbooks", "crop-state.xlsx", package = "readagau"
  )
  releases <- list(
    `acr-2026-03-03-no-217` = c(state = path),
    `acr-2026-06-02-no-218` = c(state = path)
  )
  loaded <- readagau:::agau_load_vintages(
    "crop_report", releases, withr::local_tempdir()
  )
  expect_setequal(unique(loaded$release_id), names(releases))
  expect_setequal(
    unique(loaded$release_date),
    as.Date(c("2026-03-03", "2026-06-02"))
  )
})

test_that("available real Agricultural Commodities vintages reproduce goldens", {
  march_path <- "/private/tmp/readagau_ac_202603_outlook.xlsx"
  june_path <- "/private/tmp/readagau_ac_202606_outlook.xlsx"
  skip_if_not(file.exists(march_path) && file.exists(june_path))
  cache <- withr::local_tempdir()
  march <- read_agricultural_commodities(
    c(outlook = march_path), datasets = "outlook", view = "reported",
    cache_dir = cache
  )
  june <- read_agricultural_commodities(
    c(outlook = june_path), datasets = "outlook", view = "reported",
    cache_dir = cache
  )
  select <- function(x, release_id, release_date) {
    out <- x[
      x$concept == "Value of agricultural exports" &
        x$period %in% c("2025-26", "2026-27"),
    ]
    out$release_id <- release_id
    out$release_date <- as.Date(release_date)
    out
  }
  data <- rbind(
    select(march, "ac-2026-03-03", "2026-03-03"),
    select(june, "ac-2026-06-02", "2026-06-02")
  )
  expect_equal(
    data$value[data$release_id == "ac-2026-03-03"],
    c(80456.408, 72844.562)
  )
  expect_equal(
    data$value[data$release_id == "ac-2026-06-02"],
    c(81815.978, 74815.698)
  )
  revisions <- agau_forecast_revision(data)
  expect_equal(revisions$old_value, c(80456.408, 72844.562))
  expect_equal(revisions$new_value, c(81815.978, 74815.698))
})

test_that("package-driven March to June Agricultural Commodities vintages load", {
  march_path <- "/private/tmp/readagau_ac_202603_outlook.xlsx"
  june_path <- "/private/tmp/readagau_ac_202606_outlook.xlsx"
  skip_if_not(file.exists(march_path) && file.exists(june_path))
  releases <- list(
    `ac-2026-03-03` = c(outlook = march_path),
    `ac-2026-06-02` = c(outlook = june_path)
  )
  cache <- withr::local_tempdir()

  loaded <- readagau:::agau_load_vintages(
    "agricultural_commodities", releases, cache
  )
  expect_equal(nrow(loaded), 3600)
  expect_identical(
    anyDuplicated(paste(loaded$release_id, loaded$observation_key)),
    0L
  )
  expect_equal(nrow(readagau:::agau_structural_breaks(loaded)), 0)

  revisions <- compare_agau_vintages(
    "agricultural_commodities", data = NULL, releases = releases,
    comparison = "forecast_revision", cache_dir = cache
  )
  expect_equal(nrow(revisions), 96)
  expect_setequal(revisions$old_release, "ac-2026-03-03")
  expect_setequal(revisions$new_release, "ac-2026-06-02")
  expect_identical(revisions$series_id_old, revisions$series_id_new)

  export_keys <- unique(loaded$observation_key[
    loaded$concept == "Value of agricultural exports" &
      loaded$period %in% c("2025-26", "2026-27")
  ])
  exports <- revisions[revisions$observation_key %in% export_keys, ]
  exports <- exports[order(exports$period), ]
  expect_equal(exports$old_value, c(80456.408, 72844.562))
  expect_equal(exports$new_value, c(81815.978, 74815.698))
})
