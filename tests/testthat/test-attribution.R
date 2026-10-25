test_that("attribution guidance keeps its public structure and rights caveats", {
  expected_names <- c(
    "source", "source_licence", "exclusions", "weekly_prices",
    "fixture_policy", "package_code_licence"
  )
  guidance <- agau_attribution()

  expect_type(guidance, "list")
  expect_identical(class(guidance), "list")
  expect_identical(names(guidance), expected_names)
  expect_identical(attributes(guidance), list(names = expected_names))
  expect_identical(length(guidance), 6L)
  expect_true(all(vapply(guidance, is.character, logical(1))))
  expect_identical(length(guidance$source), 1L)
  expect_identical(length(guidance$source_licence), 1L)
  expect_identical(length(guidance$exclusions), 3L)
  expect_identical(length(guidance$weekly_prices), 1L)
  expect_identical(length(guidance$fixture_policy), 1L)
  expect_identical(length(guidance$package_code_licence), 1L)

  expect_setequal(
    guidance$exclusions,
    c("Commonwealth Coat of Arms", "trade marks", "third-party material")
  )
  expect_match(
    tolower(guidance$source_licence), "source-specific terms", fixed = TRUE
  )
  expect_match(guidance$source_licence, "CC BY 4.0", fixed = TRUE)
  expect_match(guidance$source_licence, "no package-wide", fixed = TRUE)
  expect_match(
    guidance$weekly_prices, "accessible chart provenance", fixed = TRUE
  )
  expect_match(
    guidance$weekly_prices, "no redistribution permission is asserted",
    fixed = TRUE
  )
  expect_match(
    guidance$fixture_policy,
    "package-owned reduced/derived synthetic structures",
    fixed = TRUE
  )
  expect_match(
    guidance$fixture_policy,
    "no official source bytes, logos, or third-party values",
    fixed = TRUE
  )
  expect_match(guidance$package_code_licence, "MIT", fixed = TRUE)
  expect_match(guidance$package_code_licence, "copyright Chartwell Macro", fixed = TRUE)
  expect_match(
    guidance$package_code_licence,
    "does not license source data or third-party material",
    fixed = TRUE
  )
})

test_that("Crop Report attribution is the same public guidance", {
  expect_identical(crop_report_attribution(), agau_attribution())
})
