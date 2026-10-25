test_that("offline discovery follows all exact release pages", {
  html <- system.file("fixtures", "html", package = "readagau")
  crop <- readagau:::agau_discover_product(
    file.path(html, "crop-archive.html"), "crop_report"
  )
  ac <- readagau:::agau_discover_product(
    file.path(html, "commodities-archive.html"), "agricultural_commodities"
  )
  expect_equal(nrow(crop), 10)
  expect_equal(nrow(ac), 10)
  expect_equal(length(unique(crop$landing_url)), 10)
  expect_equal(length(unique(ac$landing_url)), 10)
  expect_true(all(vapply(crop$asset_urls, function(x) {
    all(c("national", "state", "report") %in% names(x))
  }, logical(1))))
  expect_true(all(vapply(ac$asset_urls, function(x) {
    all(c("outlook", "statistics", "report") %in% names(x))
  }, logical(1))))
  expect_match(crop$landing_url[10], "june-2026\\.html$")
  audited <- readagau:::agau_bundled_releases()
  expect_setequal(
    crop$release_id,
    audited$release_id[
      audited$product == "crop_report" &
        audited$edition %in% crop$edition
    ]
  )
  expect_setequal(
    ac$release_id,
    audited$release_id[
      audited$product == "agricultural_commodities" &
        audited$edition %in% ac$edition
    ]
  )
})

test_that("release identity comes from audited edition profile, not narrative dates", {
  page <- system.file(
    "fixtures", "html", "crop-june-2026-real-page-excerpt.html",
    package = "readagau"
  )
  url <- paste0(
    "https://www.agriculture.gov.au/abares/research-topics/",
    "agricultural-outlook/australian-crop-report/june-2026"
  )
  got <- readagau:::agau_parse_release_page(
    page, "crop_report", landing_url = url
  )
  expect_equal(got$release_id, "acr-2026-06-02-no-218")
  expect_equal(got$release_date, as.Date("2026-06-02"))
  expect_equal(got$report_number, "218")
  expect_equal(got$edition, "June 2026")
})

test_that("bundled releases use exact product-qualified landing pages", {
  releases <- list_agau_releases(c("crop_report", "agricultural_commodities"))
  expect_equal(sum(releases$product == "crop_report"), 66)
  expect_equal(sum(releases$product == "agricultural_commodities"), 66)
  expect_false(any(endsWith(releases$landing_url, "australian-crop-report")))
  expect_false(any(endsWith(releases$landing_url, "agricultural-outlook")))
  supported <- releases[releases$support_status == "supported", ]
  expect_equal(nrow(supported), 132)
  expect_equal(range(supported$release_date), as.Date(c(
    "2010-02-01", "2026-06-02"
  )))
  expect_false(any(grepl("-no-(?:NA)?$", supported$release_id)))
  statistics_vintages <- releases[
    releases$product == "agricultural_commodities" &
      releases$release_date >= as.Date("2024-03-05"),
    ,
    drop = FALSE
  ]
  expect_equal(nrow(statistics_vintages), 10)
  expect_true(all(vapply(
    statistics_vintages$asset_roles,
    function(roles) "statistics" %in% roles,
    logical(1)
  )))
})

test_that("stale discovery and asset snapshots merge under writer locks", {
  cache <- withr::local_tempdir()
  releases <- readagau:::agau_bundled_releases()[1:2, ]
  readagau:::agau_write_discovery(releases[1, ], cache)
  readagau:::agau_write_discovery(releases[2, ], cache)
  expect_setequal(
    readRDS(readagau:::agau_discovery_path(cache))$release_id,
    releases$release_id
  )

  one_cache <- withr::local_tempdir()
  two_cache <- withr::local_tempdir()
  one <- readagau:::agau_cache_asset(
    "crop_report", "acr-lock-test", "national",
    system.file(
      "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
    ),
    cache_dir = one_cache
  )
  two <- readagau:::agau_cache_asset(
    "crop_report", "acr-lock-test", "state",
    system.file(
      "fixtures", "workbooks", "crop-state.xlsx", package = "readagau"
    ),
    cache_dir = two_cache
  )
  readagau:::agau_write_asset_index(
    one, cache, "crop_report", "acr-lock-test"
  )
  readagau:::agau_write_asset_index(
    two, cache, "crop_report", "acr-lock-test"
  )
  index <- readagau:::agau_read_asset_index(
    cache, "crop_report", "acr-lock-test"
  )
  expect_setequal(index$asset_type, c("national", "state"))
  expect_false(any(file.exists(c(
    paste0(readagau:::agau_discovery_path(cache), ".lock"),
    paste0(
      readagau:::agau_asset_index_path(
        cache, "crop_report", "acr-lock-test"
      ),
      ".lock"
    )
  ))))
})

test_that("exact download resolves only page-discovered URLs", {
  cache <- withr::local_tempdir()
  archive <- system.file("fixtures", "html", "crop-archive.html", package = "readagau")
  releases <- readagau:::agau_discover_product(archive, "crop_report")
  readagau:::agau_write_discovery(releases, cache)
  got <- download_agau_release(
    "crop_report", "acr-2025-03-04-no-213", assets = "national",
    cache_dir = cache
  )
  expect_equal(got$asset_type, "national")
  expect_equal(got$detected_format, "xlsx")
  expect_match(got$source_url, "crop-national\\.xlsx$")
  expect_false(grepl("acr-2025|national-2025", got$source_url))
})

test_that("cached exact assets need no second source access", {
  cache <- withr::local_tempdir()
  source <- tempfile(fileext = ".xlsx")
  file.copy(
    system.file("fixtures", "workbooks", "crop-national.xlsx", package = "readagau"),
    source
  )
  first <- readagau:::agau_cache_asset(
    "crop_report", "acr-test", "national", source,
    cache_dir = cache
  )
  unlink(source)
  second <- readagau:::agau_cache_asset(
    "crop_report", "acr-test", "national", source,
    cache_dir = cache
  )
  expect_identical(first$sha256, second$sha256)
  expect_true(file.exists(second$local_path))
  expect_identical(
    readagau:::agau_sha256(second$local_path), second$sha256
  )
  expect_length(list.files(dirname(second$local_path), pattern = "incoming"), 0)
})

test_that("public exact cached retrieval performs no discovery or source access", {
  cache <- withr::local_tempdir()
  source <- tempfile(fileext = ".xlsx")
  file.copy(
    system.file("fixtures", "workbooks", "crop-national.xlsx", package = "readagau"),
    source
  )
  first <- readagau:::agau_cache_asset(
    "crop_report", "acr-cache-only", "national", source, cache_dir = cache
  )
  unlink(source)
  got <- download_agau_release(
    "crop_report", "acr-cache-only", assets = "national", cache_dir = cache
  )
  expect_identical(got$sha256, first$sha256)
  expect_true(file.exists(got$local_path))
})

test_that("assets all fills a partial cache while an explicit complete subset replays", {
  cache <- withr::local_tempdir()
  archive <- system.file("fixtures", "html", "crop-archive.html", package = "readagau")
  releases <- readagau:::agau_discover_product(archive, "crop_report")
  readagau:::agau_write_discovery(releases, cache)
  release <- "acr-2026-06-02-no-218"
  hit <- releases[releases$release_id == release, ]
  national <- readagau:::agau_cache_asset(
    "crop_report", release, "national", hit$asset_urls[[1]][["national"]],
    cache_dir = cache
  )
  subset <- download_agau_release(
    "crop_report", release, assets = "national", cache_dir = cache
  )
  expect_identical(subset$sha256, national$sha256)
  expect_equal(subset$asset_type, "national")

  all <- download_agau_release(
    "crop_report", release, assets = "all", cache_dir = cache
  )
  expect_setequal(all$asset_type, c("national", "state", "report"))
  expect_true(all(file.exists(all$local_path)))
})
test_that("refresh appends changed bytes and retains old immutable raw", {
  cache <- withr::local_tempdir()
  source <- tempfile(fileext = ".xlsx")
  file.copy(system.file(
    "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
  ), source)
  one <- readagau:::agau_cache_asset(
    "crop_report", "acr-refresh", "national", source, cache_dir = cache
  )
  file.copy(system.file(
    "fixtures", "workbooks", "crop-state.xlsx", package = "readagau"
  ), source, overwrite = TRUE)
  two <- readagau:::agau_cache_asset(
    "crop_report", "acr-refresh", "national", source,
    cache_dir = cache, refresh = TRUE
  )
  expect_false(identical(one$sha256, two$sha256))
  expect_true(file.exists(one$local_path))
  expect_true(file.exists(two$local_path))
})

test_that("HTML masquerading as a workbook is rejected", {
  bad <- tempfile(fileext = ".xlsx")
  writeLines("<!doctype html><html><body>error</body></html>", bad)
  expect_error(
    readagau:::agau_cache_asset(
      "crop_report", "acr-bad", "national", bad,
      cache_dir = withr::local_tempdir()
    ),
    class = "agau_asset_format_error"
  )
})
