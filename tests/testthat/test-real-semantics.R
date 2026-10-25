count_conflicting_observation_keys <- function(data) {
  by_key <- split(data$value, data$observation_key)
  sum(vapply(by_key, function(value) {
    length(unique(value[!is.na(value)])) > 1L
  }, logical(1)))
}

expect_official_period_pairs_valid <- function(data, source_asset = NULL) {
  if (!is.null(source_asset)) {
    data <- data[data$source_asset == source_asset, , drop = FALSE]
  }
  pairs <- unique(data.frame(
    period = as.character(data$period),
    period_basis = as.character(data$period_basis),
    stringsAsFactors = FALSE
  ))
  failures <- vapply(seq_len(nrow(pairs)), function(i) {
    tryCatch(
      {
        readagau:::agau_period_bounds(
          pairs$period[[i]],
          basis = pairs$period_basis[[i]]
        )
        ""
      },
      error = function(condition) {
        paste(
          pairs$period[[i]],
          pairs$period_basis[[i]],
          class(condition)[[1]],
          conditionMessage(condition),
          sep = " | "
        )
      }
    )
  }, character(1))
  expect_length(failures[nzchar(failures)], 0L)
}

test_that("official productivity full-end financial year dates are exact", {
  productivity_path <- "/private/tmp/readagau_productivity_202606.xls"
  skip_if_not(file.exists(productivity_path))

  productivity <- read_farm_productivity(
    c(supporting_data = productivity_path),
    cache_dir = withr::local_tempdir(),
    release_id = "productivity-2026-06",
    release_date = as.Date("2026-06-30")
  )
  affected <- productivity[
    productivity$period == "1999-2000" &
      productivity$period_basis == "financial_year",
    ,
    drop = FALSE
  ]

  expect_equal(nrow(productivity), 5750)
  expect_equal(nrow(affected), 125)
  expect_equal(length(unique(affected$table_id)), 18)
  expect_equal(length(unique(affected$concept)), 2)
  expect_true(all(affected$period_start == as.Date("1999-07-01")))
  expect_true(all(affected$period_end == as.Date("2000-06-30")))
  expect_false(anyNA(affected$period_start))
  expect_false(anyNA(affected$period_end))

  representative <- function(table_id, geography) {
    value <- affected$value[
      affected$table_id == table_id &
        affected$geography == geography
    ]
    expect_length(value, 1L)
    value
  }
  expect_equal(representative("productivity_table_1", "All Australia"), 173.8)
  expect_equal(representative("productivity_table_6", "All Australia"), 127.45)
  expect_equal(representative("productivity_table_14", "Northern Beef"), 134.42)
  expect_equal(representative("productivity_table_c2", "All Australia"), 117)
  expect_equal(representative("productivity_table_c6", "All Australia"), 82)

  stable_fields <- setdiff(
    names(productivity),
    c("period_start", "period_end", "parser_version", "retrieved_at")
  )
  expect_equal(
    digest::digest(
      as.data.frame(productivity[stable_fields], stringsAsFactors = FALSE),
      algo = "sha256"
    ),
    "c0d284e9ebb8a4600cdb097acd745790cd1b4676bb8f696f7850411282596e63"
  )
  target_identity_values <- affected[c(
    "table_id", "geography", "commodity", "concept", "series_id",
    "observation_key", "value", "raw_value"
  )]
  expect_equal(
    digest::digest(
      as.data.frame(target_identity_values, stringsAsFactors = FALSE),
      algo = "sha256"
    ),
    "5fe76c84c16c8f1d59092af4cf4b4c2a24076e112be00ebccba7a94dff5b0a15"
  )

  unaffected <- productivity[
    !(productivity$period == "1999-2000" &
      productivity$period_basis == "financial_year"),
    c(
      "series_id", "observation_key", "period", "period_basis",
      "period_start", "period_end"
    ),
    drop = FALSE
  ]
  expect_equal(
    digest::digest(
      as.data.frame(unaffected, stringsAsFactors = FALSE),
      algo = "sha256"
    ),
    "884b88db5605dd5898d932e61dd5e3ff6fc62f3ad0ec98d29d10c813b3736753"
  )
  expect_equal(length(unique(productivity$series_id)), 469)
  expect_identical(anyDuplicated(productivity$observation_key), 0L)
  expect_true(validate_agau_release(productivity)$valid)
  expect_official_period_pairs_valid(productivity)
})

test_that("June 2026 real Agricultural Commodities semantics are exact", {
  outlook_path <- "/private/tmp/readagau_ac_202606_outlook.xlsx"
  statistics_path <- "/private/tmp/readagau_ac_202606_stats.xlsx"
  skip_if_not(file.exists(outlook_path) && file.exists(statistics_path))

  cache <- withr::local_tempdir()
  reported <- read_agricultural_commodities(
    c(outlook = outlook_path, statistics = statistics_path),
    datasets = c("outlook", "statistics"), view = "reported",
    cache_dir = cache,
    release_id = "ac-2026-06-02",
    release_date = as.Date("2026-06-02")
  )
  expect_equal(nrow(reported), 31231)
  expect_equal(sum(reported$source_asset == "outlook"), 936)
  expect_equal(sum(reported$source_asset == "statistics"), 30295)
  expect_true(all(nzchar(reported$source_note)))
  expect_official_period_pairs_valid(reported, "outlook")
  expect_official_period_pairs_valid(reported, "statistics")

  table5 <- reported[
    reported$table_id == "acs_table_05" &
      reported$commodity == "Wheat" & reported$period == "2024-25",
  ]
  expect_equal(nrow(table5), 1)
  expect_match(table5$table_title, "^5 Annual world indicator prices")
  expect_equal(table5$geography, "World")
  expect_equal(table5$market, "world_indicator")
  expect_equal(table5$period_basis, "published_year")
  expect_equal(table5$currency, "USD")
  expect_equal(table5$price_basis, "nominal")

  table7 <- reported[reported$table_id == "acs_table_07", ]
  expect_setequal(
    unique(table7$period_basis[table7$commodity == "Cotton"]),
    "august_july"
  )
  expect_setequal(
    unique(table7$period_basis[table7$commodity == "Sugar"]),
    "october_september"
  )
  expect_setequal(
    unique(table7$period_basis[table7$commodity == "Meat"]),
    "calendar_year"
  )

  table15 <- reported[
    reported$table_id == "acs_table_15" &
      reported$period == "2024-25",
  ]
  expect_gt(nrow(table15), 0)
  expect_match(unique(table15$table_title), "^15 Value of fisheries")
  expect_setequal(unique(table15$geography), "Australia")
  expect_setequal(unique(table15$period_basis), "financial_year")
  expect_setequal(unique(table15$currency), "AUD")
  expect_setequal(unique(table15$price_basis), "nominal")

  coarse <- reported[
    reported$source_sheet == "Coarse Grains" &
      reported$concept == "Exports - value" &
      reported$period == "2024-25",
  ]
  expect_equal(
    coarse$value[coarse$commodity == "Sorghum"],
    935.983
  )
  expect_equal(
    coarse$value[coarse$commodity == "Barley"],
    3163.03
  )

  canonical <- read_agricultural_commodities(
    c(outlook = outlook_path, statistics = statistics_path),
    datasets = c("outlook", "statistics"),
    cache_dir = cache,
    release_id = "ac-2026-06-02",
    release_date = as.Date("2026-06-02")
  )
  expect_equal(nrow(canonical), 31231)
  expect_identical(anyDuplicated(canonical$observation_key), 0L)
  expect_true(validate_agau_release(canonical)$valid)
})

test_that("real Crop and productivity parser counts and semantics remain exact", {
  national_path <- "/private/tmp/readagau_acr_202606_national.xlsx"
  state_path <- "/private/tmp/readagau_acr_202606_state.xlsx"
  productivity_path <- "/private/tmp/readagau_productivity_202606.xlsx"
  skip_if_not(
    file.exists(national_path) && file.exists(state_path) &&
      file.exists(productivity_path)
  )

  crop_cache <- withr::local_tempdir()
  crop <- read_crop_report(
    c(national = national_path, state = state_path),
    assets = c("national", "state"), view = "reported",
    cache_dir = crop_cache,
    release_id = "acr-2026-06-02-no-218",
    release_date = as.Date("2026-06-02")
  )
  expect_equal(nrow(crop), 14268)
  expect_equal(sum(crop$source_asset == "national"), 6318)
  expect_equal(sum(crop$source_asset == "state"), 7950)
  expect_false("2000" %in% crop$period)
  expect_true(all(nzchar(crop$source_note)))
  expect_official_period_pairs_valid(crop, "national")
  expect_official_period_pairs_valid(crop, "state")
  crop_canonical <- read_crop_report(
    c(national = national_path, state = state_path),
    assets = c("national", "state"),
    cache_dir = crop_cache,
    release_id = "acr-2026-06-02-no-218",
    release_date = as.Date("2026-06-02")
  )
  expect_equal(nrow(crop_canonical), 13933)
  expect_identical(anyDuplicated(crop_canonical$observation_key), 0L)
  expect_true(validate_agau_release(crop_canonical)$valid)
  corn <- crop_canonical[
    crop_canonical$commodity == "Corn (maize)" &
      crop_canonical$geography == "Australia" &
      crop_canonical$concept %in% c("Area", "Production"),
    ,
    drop = FALSE
  ]
  corn_area <- corn[
    corn$concept == "Area" & corn$season == "summer",
    ,
    drop = FALSE
  ]
  expect_equal(length(unique(corn_area$series_id)), 1L)
  expect_equal(max(corn_area$period_end), as.Date("2027-06-30"))
  expect_true(all(c(
    "crop_report_national",
    "crop_report_state"
  ) %in% corn_area$source_dataset))
  expect_true(any(
    corn$concept == "Production" &
      corn$table_id == "crop_national_table_16" &
      corn$season == "not_applicable"
  ))

  productivity_cache <- withr::local_tempdir()
  productivity <- read_farm_productivity(
    productivity_path, view = "reported",
    cache_dir = productivity_cache,
    release_id = "productivity-2026-06",
    release_date = as.Date("2026-06-30")
  )
  expect_equal(nrow(productivity), 5750)
  expect_identical(anyDuplicated(productivity$observation_key), 0L)
  expect_equal(count_conflicting_observation_keys(productivity), 0)
  expect_true(all(nzchar(productivity$source_note)))
  expect_true("interim_adjustment" %in% productivity$method)
  expect_true("climate_adjusted" %in% productivity$method)
  expect_true(validate_agau_release(productivity)$valid)

  table18 <- productivity[
    productivity$table_id == "productivity_table_18",
  ]
  expect_equal(nrow(table18), 35)
  expect_setequal(
    unique(table18$geography),
    c(
      "All Australia", "New South Wales", "Victoria", "Queensland",
      "South Australia", "Western Australia", "Tasmania"
    )
  )
  expect_setequal(
    unique(table18$concept),
    paste(
      "input growth rate",
      c("Capital", "Labour", "Land", "Materials", "Services")
    )
  )
  expect_setequal(unique(table18$commodity), "Dairy input growth rates")
  expect_equal(length(unique(table18$series_id)), 35)

  capital <- table18[table18$concept == "input growth rate Capital", ]
  expect_equal(nrow(capital), 7)
  expect_equal(length(unique(capital$series_id)), 7)
  expect_equal(
    capital$value[
      match(
        c(
          "All Australia", "New South Wales", "Victoria", "Queensland",
          "South Australia", "Western Australia", "Tasmania"
        ),
        capital$geography
      )
    ],
    c(-1.1, -1.7, -0.6, -4, -1.7, -1.8, 0.2)
  )

  table10 <- productivity[
    productivity$table_id == "productivity_table_10",
  ]
  expect_setequal(unique(table10$geography), "Australia")

  canonical_productivity <- read_farm_productivity(
    productivity_path,
    cache_dir = productivity_cache,
    release_id = "productivity-2026-06",
    release_date = as.Date("2026-06-30")
  )
  expect_equal(nrow(canonical_productivity), 5750)
  expect_identical(
    canonical_productivity$value,
    productivity$value
  )
  expect_identical(
    anyDuplicated(canonical_productivity$observation_key),
    0L
  )
  expect_true(all(canonical_productivity$record_role == "canonical"))
  expect_true(validate_agau_release(canonical_productivity)$valid)
})

test_that("March 2026 real edition counts remain exact", {
  crop_path <- "/private/tmp/readagau_acr_202603_national.xlsx"
  outlook_path <- "/private/tmp/readagau_ac_202603_outlook.xlsx"
  statistics_path <- "/private/tmp/readagau_ac_202603_stats.xlsx"
  skip_if_not(
    file.exists(crop_path) && file.exists(outlook_path) &&
      file.exists(statistics_path)
  )

  crop_cache <- withr::local_tempdir()
  crop <- read_crop_report(
    c(national = crop_path), assets = "national", view = "reported",
    cache_dir = crop_cache,
    release_id = "acr-2026-03-03-no-217",
    release_date = as.Date("2026-03-03")
  )
  commodities_cache <- withr::local_tempdir()
  commodities <- read_agricultural_commodities(
    c(outlook = outlook_path, statistics = statistics_path),
    datasets = c("outlook", "statistics"), view = "reported",
    cache_dir = commodities_cache,
    release_id = "ac-2026-03-03",
    release_date = as.Date("2026-03-03")
  )
  expect_equal(nrow(crop), 7162)
  expect_equal(sum(commodities$source_asset == "outlook"), 2664)
  expect_equal(sum(commodities$source_asset == "statistics"), 30295)
  expect_true(all(nzchar(crop$source_note)))
  expect_true(all(nzchar(commodities$source_note)))

  outlook <- commodities[commodities$source_asset == "outlook", ]
  expect_identical(anyDuplicated(outlook$observation_key), 0L)
  expect_equal(
    sum(duplicated(outlook$observation_key)),
    0
  )
  macro <- outlook[
    outlook$source_sheet == "Key macro" &
      outlook$geography == "Advanced economies" &
      outlook$period == "2024",
  ]
  expect_setequal(
    macro$concept,
    c("Real GDP growth", "GDP per person")
  )
  expect_equal(
    macro$value[macro$concept == "Real GDP growth"],
    1.78
  )
  expect_equal(
    macro$value[macro$concept == "GDP per person"],
    1.2
  )

  crop_canonical <- read_crop_report(
    c(national = crop_path), assets = "national",
    cache_dir = crop_cache,
    release_id = "acr-2026-03-03-no-217",
    release_date = as.Date("2026-03-03")
  )
  expect_equal(nrow(crop_canonical), 7162)
  expect_identical(anyDuplicated(crop_canonical$observation_key), 0L)
  expect_true(validate_agau_release(crop_canonical)$valid)

  canonical <- read_agricultural_commodities(
    c(outlook = outlook_path, statistics = statistics_path),
    datasets = c("outlook", "statistics"),
    cache_dir = commodities_cache,
    release_id = "ac-2026-03-03",
    release_date = as.Date("2026-03-03")
  )
  expect_equal(nrow(canonical), 32959)
  expect_identical(anyDuplicated(canonical$observation_key), 0L)
  expect_true(validate_agau_release(canonical)$valid)
})
