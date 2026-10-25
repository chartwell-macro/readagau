test_that("dependency failures use the registered condition class", {
  condition <- tryCatch(
    readagau:::agau_abort("agau_dependency_error", "Dependency is unavailable."),
    error = identity
  )

  expect_s3_class(condition, "agau_dependency_error")
  expect_s3_class(condition, "agau_error")
  expect_true(
    "agau_dependency_error" %in% readagau:::agau_condition_catalog()$class
  )
})
