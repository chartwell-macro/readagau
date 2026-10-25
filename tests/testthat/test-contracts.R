test_that("status suffixes are explicit and date position is not inferred", {
  got <- agau_status(c("2025-26s", "2026-27f", "2030-31z", "2023-24"))
  expect_equal(
    got$period_status,
    c("estimate", "forecast", "projection", "published-unclassified")
  )
  expect_equal(got$period, c("2025-26", "2026-27", "2030-31", "2023-24"))
})

test_that("financial-year bounds accept coherent short and full end years", {
  got <- readagau:::agau_period_bounds(c(
    "0000-01",
    "0000-0001",
    "1899-00",
    "1899-1900",
    "1998-99",
    "1999-00",
    "1999-2000",
    "1999-2000f",
    "2099-2100",
    "9998-99"
  ))

  expect_equal(
    got$period_start,
    as.Date(c(
      "0000-07-01",
      "0000-07-01",
      "1899-07-01",
      "1899-07-01",
      "1998-07-01",
      "1999-07-01",
      "1999-07-01",
      "1999-07-01",
      "2099-07-01",
      "9998-07-01"
    ))
  )
  expect_equal(
    got$period_end,
    as.Date(c(
      "0001-06-30",
      "0001-06-30",
      "1900-06-30",
      "1900-06-30",
      "1999-06-30",
      "2000-06-30",
      "2000-06-30",
      "2000-06-30",
      "2100-06-30",
      "9999-06-30"
    ))
  )
  expect_true(all(got$period_basis == "financial_year"))
  expect_true(readagau:::agau_period_like("0000-0001"))
  expect_true(readagau:::agau_period_like("1899-00"))
  expect_true(readagau:::agau_period_like("1899-1900"))
  expect_true(readagau:::agau_period_like("1999-2000"))
  expect_false(readagau:::agau_period_like("1999-000"))

  malformed_by_class <- list(
    incomplete = c("1999-", "-00"),
    whitespace = c(
      "1999- 00", "1999 -00", "1999 - 00", "1999 00",
      "1999 0", "1999 20000"
    ),
    arbitrary_punctuation = c(
      "1999/00", "1999:00", "1999_00", "1999.00", "1999\\00",
      "1999+00", "1999;00", "1999=00", "1999|00", "1999@00",
      "1999#00"
    ),
    multiple_numeric_runs = c(
      "1999--00", "1999::00", "1.2.3", "1999 / 00 / 01"
    ),
    start_width = c(
      "9-00", "1-0002", "99-00", "999-00", "199-2000",
      "01999-00", "19999-00", "10000-01", "10000-10001",
      "12345678901234567890-01"
    ),
    concatenated_lengths_5_6_8_9_10 = c(
      "19990", "199900", "19992000", "199920000", "1999200000"
    ),
    invalid_end_or_text = c(
      "1999-000", "1999-20000", "1999-xx", "1999-Q1"
    )
  )
  incoherent_or_unsupported <- c("1999-99", "1999-2001", "9999-00")
  for (label in c(unlist(malformed_by_class), incoherent_or_unsupported)) {
    condition <- tryCatch(
      readagau:::agau_period_bounds(label),
      error = identity
    )
    expect_s3_class(condition, "agau_validation_error")
  }

  bare_years <- readagau:::agau_period_bounds(c("1900", "1999", "2000", "2099"))
  expect_equal(
    bare_years$period_start,
    as.Date(c("1900-01-01", "1999-01-01", "2000-01-01", "2099-01-01"))
  )
  expect_equal(
    bare_years$period_end,
    as.Date(c("1900-12-31", "1999-12-31", "2000-12-31", "2099-12-31"))
  )
  expect_true(all(bare_years$period_basis == "calendar_year"))

  other_bare_years <- readagau:::agau_period_bounds(
    c("0000", "1899", "2100", "9999")
  )
  expect_true(all(is.na(other_bare_years$period_start)))
  expect_true(all(is.na(other_bare_years$period_end)))
  expect_true(all(other_bare_years$period_basis == "published_period"))

  summary_labels <- c(
    "1977-78 to 2024-25",
    "1899-00 through 2024-25",
    "Average 1899-1900",
    "Five-year average: 1999-2000",
    "1999-2000 average",
    "Rolling mean for 1999-2000",
    "Index (1999-2000 = 100)"
  )
  summaries <- readagau:::agau_period_bounds(
    summary_labels,
    basis = "financial_year_range"
  )
  expect_true(all(is.na(summaries$period_start)))
  expect_true(all(is.na(summaries$period_end)))
  expect_true(all(summaries$period_basis == "financial_year_range"))
})

test_that("missing markers preserve reasons and never become zero", {
  got <- agau_missing_reason(c(NA, "", "na", "n/a", "not available", "c", "..", "12"))
  expect_equal(
    got,
    c(
      "blank", "blank", "provider_na", "not_applicable", "unavailable",
      "confidential", "suppressed", NA_character_
    )
  )
  expect_error(
    agau_missing_reason("unexpected text"),
    class = "agau_validation_error"
  )
})

test_that("manifest and observation contracts contain frozen fields", {
  expect_true(all(c(
    "release_id", "release_date", "support_status", "unsupported_reason",
    "discovered_at", "discovery_version", "report_number"
  ) %in% agau_release_manifest_schema()$field))
  expect_true(all(c(
    "sha256", "bytes", "local_path", "validation_status"
  ) %in% agau_raw_asset_manifest_schema()$field))
  expect_true(all(c(
    "dataset", "source_dataset", "raw_value", "missing_reason", "series_id",
    "observation_key", "source_provider", "rights_status", "snapshot_date"
  ) %in% agau_observation_schema()$field))
})

test_that("catalogue covers the required admitted semantic families", {
  catalog <- agau_source_catalog()
  expect_equal(sum(catalog$dataset == "crop_report_national"), 17)
  expect_equal(sum(catalog$dataset == "crop_report_state"), 7)
  statistics <- catalog[catalog$dataset == "commodity_statistics", ]
  expect_equal(nrow(statistics), 45)
  expect_equal(
    sum(grepl("^acs_table_", statistics$table_id)),
    18
  )
  expect_equal(
    sum(grepl("^acs_legacy_table_", statistics$table_id)),
    27
  )
  expect_true(all(c(
    "Australia", "New South Wales", "Queensland", "South Australia",
    "Tasmania", "Victoria", "Western Australia"
  ) %in% catalog$source_label))
  expect_identical(anyDuplicated(catalog$table_id), 0L)
})

test_that("Weekly prices are an admitted canonical family", {
  catalog <- agau_source_catalog()
  weekly <- catalog$product == "weekly_commodity_prices"
  expect_equal(sum(weekly), 35)
  expect_true(all(catalog$admission_status[weekly] == "supported"))
  expect_true(all(
    is.na(catalog$unsupported_reason[weekly]) |
      !nzchar(catalog$unsupported_reason[weekly])
  ))
})

test_that("vintage operation signatures are separate and aligned", {
  common <- c("data", "releases", "series")
  expect_equal(names(formals(agau_history_revision)), common)
  expect_equal(names(formals(agau_forecast_revision)), common)
  expect_equal(
    names(formals(agau_forecast_error)),
    c(common, "realisation")
  )
})

test_that("condition catalogue contains every authoritative class", {
  expected <- c(
    "agau_release_discovery_error", "agau_asset_missing_error",
    "agau_download_error", "agau_dependency_error", "agau_asset_format_error",
    "agau_schema_error",
    "agau_table_parse_error", "agau_endpoint_error",
    "agau_status_warning", "agau_duplicate_warning", "agau_cadence_warning",
    "agau_validation_error"
  )
  expect_setequal(readagau:::agau_condition_catalog()$class, expected)
})

test_that("parsed cache identity changes with independent parser profile version", {
  one <- readagau:::agau_parsed_cache_key(
    "crop_report", "acr-test", paste(rep("a", 64), collapse = ""),
    "crop_report_national", "all", parser_profile = "profile-1"
  )
  two <- readagau:::agau_parsed_cache_key(
    "crop_report", "acr-test", paste(rep("a", 64), collapse = ""),
    "crop_report_national", "all", parser_profile = "profile-2"
  )
  expect_false(identical(one, two))
  expect_false(identical(
    readagau:::agau_parser_version(),
    as.character(utils::packageVersion("readagau"))
  ))
})
