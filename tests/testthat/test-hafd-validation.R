hafd_required_row <- function() {
  data.frame(
    Commodity = "Wheat",
    Estimate_type = "Production",
    Estimate_description = "Australian wheat production",
    Unit = "kt",
    Region = "Australia",
    issue_year = "2025",
    issue_month = "June",
    Year_Issued_FY = "2024-25",
    forecast_financial_year = "2025-26",
    original_forecast = "30,560",
    latest_actual = "..",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

test_that("historical forecast CSV fields are required and converted by type", {
  path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(hafd_required_row(), path, row.names = FALSE)

  got <- read_agau_forecast_history(path)
  expect_type(got$year_issued, "integer")
  expect_type(got$original_forecast, "double")
  expect_type(got$latest_actual, "double")
  expect_equal(got$original_forecast, 30560)
  expect_true(is.na(got$latest_actual))
})

test_that("historical forecast CSV rejects missing and malformed fields", {
  missing_path <- withr::local_tempfile(fileext = ".csv")
  missing <- hafd_required_row()
  missing$latest_actual <- NULL
  utils::write.csv(missing, missing_path, row.names = FALSE)
  expect_error(
    read_agau_forecast_history(missing_path),
    class = "agau_schema_error"
  )

  malformed_path <- withr::local_tempfile(fileext = ".csv")
  malformed <- hafd_required_row()
  malformed$original_forecast <- "not a published missing marker"
  utils::write.csv(malformed, malformed_path, row.names = FALSE)
  expect_error(
    read_agau_forecast_history(malformed_path),
    class = "agau_schema_error"
  )

  fractional_year_path <- withr::local_tempfile(fileext = ".csv")
  fractional_year <- hafd_required_row()
  fractional_year$issue_year <- "2025.5"
  utils::write.csv(fractional_year, fractional_year_path, row.names = FALSE)
  expect_error(
    read_agau_forecast_history(fractional_year_path),
    class = "agau_schema_error"
  )
})

test_that("historical forecast workbook requires one exact sheet fingerprint", {
  malformed <- system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  )
  expect_error(
    read_agau_forecast_history(malformed),
    class = "agau_schema_error"
  )
})
