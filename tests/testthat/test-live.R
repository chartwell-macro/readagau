test_that("opt-in live discovery preserves exact official metadata", {
  skip_on_cran()
  skip_if_not(identical(Sys.getenv("READAGAU_LIVE_TESTS"), "true"))
  cache <- withr::local_tempdir()
  releases <- list_agau_releases(
    c("crop_report", "agricultural_commodities", "farm_productivity"),
    refresh = TRUE, cache_dir = cache
  )
  expect_true(all(startsWith(releases$landing_url, "https://www.agriculture.gov.au/")))
  expect_true(all(vapply(releases$asset_urls, length, integer(1)) > 0L))
  expect_true(all(vapply(releases$asset_urls, function(x) {
    all(startsWith(unname(x), "https://www.agriculture.gov.au/"))
  }, logical(1))))
  audited <- readagau:::agau_bundled_releases()
  for (product in c("crop_report", "agricultural_commodities")) {
    expect_setequal(
      releases$release_id[releases$product == product],
      audited$release_id[audited$product == product]
    )
    expect_equal(
      releases$release_date[releases$product == product],
      audited$release_date[audited$product == product]
    )
  }
})
