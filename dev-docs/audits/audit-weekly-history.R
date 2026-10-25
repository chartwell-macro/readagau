args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop(
    paste(
      "Usage: Rscript dev-docs/audits/audit-weekly-history.R",
      "<archive-dir> <direct-pdf-dir> <fallback-dir> <output.csv>"
    )
  )
}

archive_dir <- normalizePath(args[[1]], mustWork = TRUE)
direct_dir <- normalizePath(args[[2]], mustWork = TRUE)
fallback_dir <- normalizePath(args[[3]], mustWork = TRUE)
output <- args[[4]]

pkgload::load_all(".", quiet = TRUE)
measures <- c(
  "latest_price", "previous_week", "weekly_change",
  "price_12_months_ago", "annual_change"
)
catalogue <- utils::read.csv(
  "inst/catalogue/weekly-release-catalog.csv",
  stringsAsFactors = FALSE
)
supported <- catalogue[catalogue$support_status == "supported", ]
stopifnot(
  nrow(catalogue) == 481L,
  nrow(supported) == 475L,
  !anyDuplicated(catalogue$release_id)
)

find_direct <- function(row) {
  date <- row$release_date[[1]]
  extension <- if (row$asset_type[[1]] == "word_report") "docx" else "pdf"
  candidates <- c(
    file.path(fallback_dir, basename(row$source_url[[1]])),
    file.path(fallback_dir, paste0("weekly-", date, ".", extension)),
    file.path(direct_dir, basename(row$source_url[[1]])),
    file.path(direct_dir, paste0(row$release_id[[1]], ".", extension))
  )
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) stop("No local bytes for ", row$release_id[[1]])
  hit[[1]]
}

audit_release <- function(row, path) {
  parsed <- readagau:::agau_parse_weekly_path(path, measures)
  data.frame(
    release_id = row$release_id[[1]],
    expected = row$release_date[[1]],
    actual = paste(unique(parsed$release_date), collapse = ";"),
    transport = row$asset_type[[1]],
    source_asset = basename(path),
    source_sha256 = readagau:::agau_sha256(path),
    rows = nrow(parsed),
    series = length(unique(parsed$table_id)),
    valid = validate_agau_release(parsed)$valid,
    error = "",
    stringsAsFactors = FALSE
  )
}

direct <- supported[supported$asset_type != "archive", ]
direct_audit <- do.call(rbind, lapply(seq_len(nrow(direct)), function(i) {
  row <- direct[i, , drop = FALSE]
  audit_release(row, find_direct(row))
}))

archive <- supported[supported$asset_type == "archive", ]
archive_groups <- split(seq_len(nrow(archive)), archive$source_url)
archive_audit <- do.call(rbind, lapply(archive_groups, function(index) {
  dates <- archive$release_date[index]
  quarter <- paste0(
    substr(dates[[1]], 1, 4), "q",
    (as.integer(substr(dates[[1]], 6, 7)) - 1L) %/% 3L + 1L
  )
  path <- file.path(archive_dir, paste0(quarter, ".zip"))
  parsed <- readagau:::agau_parse_weekly_path(
    path, measures, release_dates = as.Date(dates)
  )
  do.call(rbind, lapply(seq_along(index), function(j) {
    one <- parsed[parsed$release_date == as.Date(dates[[j]]), ]
    data.frame(
      release_id = archive$release_id[index[[j]]],
      expected = dates[[j]],
      actual = if (nrow(one)) as.character(unique(one$release_date)) else "",
      transport = "archive",
      source_asset = if (nrow(one)) unique(one$source_asset)[[1]] else "",
      source_sha256 = if (nrow(one)) unique(one$sha256)[[1]] else "",
      rows = nrow(one),
      series = length(unique(one$table_id)),
      valid = nrow(one) > 0L && validate_agau_release(one)$valid,
      error = "",
      stringsAsFactors = FALSE
    )
  }))
}))

audit <- rbind(archive_audit, direct_audit)
stopifnot(
  nrow(audit) == 475L,
  !anyDuplicated(audit$release_id),
  all(audit$expected == audit$actual),
  all(audit$valid),
  !anyDuplicated(paste(audit$actual, audit$source_sha256))
)
utils::write.csv(audit, output, row.names = FALSE, na = "")
cat(
  "475/475 exact-date releases valid;",
  sum(audit$rows), "canonical observations written to", output, "\n"
)
