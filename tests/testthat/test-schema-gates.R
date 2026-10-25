gate_fixture <- function(name) {
  system.file("fixtures", "workbooks", name, package = "readagau")
}

read_gate_fixture <- function(name) {
  read_crop_report(
    c(national = gate_fixture(name)),
    assets = "national", view = "reported",
    cache_dir = withr::local_tempdir()
  )
}

test_that("unknown, missing and moved admitted sheets fail closed", {
  expect_error(
    read_gate_fixture("crop-national-unknown-table.xlsx"),
    class = "agau_schema_error"
  )
  expect_error(
    read_gate_fixture("crop-national-missing-table.xlsx"),
    class = "agau_schema_error"
  )
  expect_error(
    read_gate_fixture("crop-national-moved-header.xlsx"),
    class = "agau_schema_error"
  )
})

test_that("unlabeled payloads fail across every parser family", {
  expect_error(
    read_gate_fixture("crop-national-unlabeled-column.xlsx"),
    class = "agau_schema_error"
  )
  expect_error(
    read_gate_fixture("crop-national-unlabeled-row.xlsx"),
    class = "agau_schema_error"
  )
  expect_error(
    read_gate_fixture("crop-national-unlabeled-matrix.xlsx"),
    class = "agau_schema_error"
  )
})

test_that("numeric payload outside a recognised period grid fails closed", {
  expect_error(
    read_gate_fixture("crop-national-extra-payload.xlsx"),
    regexp = "outside the admitted period grid",
    class = "agau_schema_error"
  )
})

test_that("provider missing markers outside a period grid also fail closed", {
  markers <- c(
    "na", "n/a", "not applicable", "not available", "unavailable",
    "nr", "not reported", "confidential", "c", "suppressed", "..",
    "-", "\u2014"
  )
  expect_true(all(readagau:::agau_payload_token(markers)))
  expect_false(any(readagau:::agau_payload_token(
    c("", "Source: synthetic fixture", "ordinary label")
  )))
  expect_error(
    read_gate_fixture("crop-national-extra-marker-payload.xlsx"),
    regexp = "outside the admitted period grid",
    class = "agau_schema_error"
  )
})
