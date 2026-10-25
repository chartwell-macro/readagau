vintage_fixture <- function() {
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
  out$sha256 <- vapply(seq_len(4), function(i) paste(rep(i, 64), collapse = ""), "")
  out
}

test_that("forecast revisions reproduce the required four-release sequence", {
  x <- vintage_fixture()
  got <- agau_forecast_revision(x)
  expect_equal(got$old_value, c(30560, 33765, 35585))
  expect_equal(got$new_value, c(33765, 35585, 35985))
  expect_equal(tail(got$status_transition, 1), "forecast -> estimate")
})

test_that("first realisation and latest revised errors stay distinct", {
  x <- vintage_fixture()
  revised <- x[4, ]
  revised$release_id <- "acr-2026-06-02-no-218"
  revised$release_date <- as.Date("2026-06-02")
  revised$period_status <- "historical"
  revised$value <- 36010
  revised$raw_value <- "36010"
  revised$sha256 <- paste(rep("a", 64), collapse = "")
  x <- rbind(x, revised)
  first <- agau_forecast_error(x, realisation = "first")
  latest <- agau_forecast_error(x, realisation = "latest_revised")
  expect_true(all(first$new_value == 35985))
  expect_true(all(latest$new_value == 36010))
  expect_true(all(grepl("first_realisation", first$comparison)))
  expect_true(all(grepl("latest_revised", latest$comparison)))
  history <- agau_history_revision(x)
  expect_equal(history$old_value, 35985)
  expect_equal(history$new_value, 36010)
})

test_that("ambiguous vintage joins fail loudly", {
  x <- vintage_fixture()
  expect_error(
    agau_forecast_revision(rbind(x, x[1, ])),
    class = "agau_validation_error"
  )
})
