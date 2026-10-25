#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop(
    "Usage: audit-quarterly-history.R ",
    "<workbook-asset-dir> <report-asset-dir> <output.csv>"
  )
}
candidate_dir <- args[[1]]
report_dir <- args[[2]]
output <- args[[3]]

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("The source audit requires the suggested `pkgload` package.")
}
pkgload::load_all(".", quiet = TRUE)
catalogue <- readagau:::agau_bundled_releases()
catalogue <- catalogue[
  catalogue$product %in% c("crop_report", "agricultural_commodities"),
  , drop = FALSE
]

asset_identity <- function(url) {
  pieces <- strsplit(url, "/", fixed = TRUE)[[1]]
  list(
    asset_id = pieces[[length(pieces) - 1L]],
    index = as.integer(pieces[[length(pieces)]])
  )
}

local_asset <- function(product, edition, role, url) {
  identity <- asset_identity(url)
  if (role == "report") {
    month <- tolower(sub(" .*", "", edition))
    return(file.path(
      report_dir,
      sprintf("ac_2010_%s_%s.pdf", month, identity$asset_id)
    ))
  }
  prefix <- if (product == "crop_report") "crop" else "ac"
  file.path(
    candidate_dir,
    sprintf("%s_%s_%02d", prefix, identity$asset_id, identity$index)
  )
}

rows <- list()
for (i in seq_len(nrow(catalogue))) {
  release <- catalogue[i, , drop = FALSE]
  roles <- release$asset_roles[[1]]
  urls <- release$asset_urls[[1]]
  keep <- if (release$product[[1]] == "crop_report") {
    roles %in% c("national", "state")
  } else {
    roles %in% c("outlook", "report")
  }
  roles <- roles[keep]
  urls <- urls[keep]

  for (j in seq_along(roles)) {
    role <- roles[[j]]
    path <- local_asset(
      release$product[[1]], release$edition[[1]], role, urls[[j]]
    )
    started <- proc.time()[["elapsed"]]
    result <- tryCatch({
      stopifnot(file.exists(path))
      dataset <- if (release$product[[1]] == "crop_report") {
        paste0("crop_report_", role)
      } else {
        "commodities_outlook"
      }
      meta <- readagau:::agau_local_meta(
        path, release$product[[1]], role,
        release_id = release$release_id[[1]],
        release_date = release$release_date[[1]],
        report_number = release$report_number[[1]]
      )
      legacy <- release$release_date[[1]] < as.Date("2024-01-01") ||
        role == "report"
      parsed <- if (legacy) {
        if (role == "report") {
          readagau:::agau_parse_legacy_pdf(
            path, meta, release$product[[1]], dataset
          )
        } else {
          readagau:::agau_parse_legacy_workbook(
            path, meta, release$product[[1]], dataset
          )
        }
      } else {
        readagau:::agau_parse_workbook(
          path, meta, release$product[[1]], dataset
        )
      }
      validation <- validate_agau_release(parsed)
      list(
        rows = nrow(parsed),
        tables = length(unique(parsed$table_id)),
        valid = validation$valid,
        duplicates = validation$duplicate_canonical_observation_keys,
        error = ""
      )
    }, error = function(error) {
      list(
        rows = NA_integer_, tables = NA_integer_, valid = FALSE,
        duplicates = NA_integer_, error = conditionMessage(error)
      )
    })
    elapsed <- proc.time()[["elapsed"]] - started
    identity <- asset_identity(urls[[j]])
    rows[[length(rows) + 1L]] <- data.frame(
      product = release$product[[1]],
      release_id = release$release_id[[1]],
      edition = release$edition[[1]],
      release_date = as.character(release$release_date[[1]]),
      role = role,
      asset_id = identity$asset_id,
      asset_index = identity$index,
      sha256 = if (file.exists(path)) readagau:::agau_sha256(path) else "",
      rows = result$rows,
      tables = result$tables,
      valid = result$valid,
      duplicate_canonical_keys = result$duplicates,
      elapsed_seconds = round(elapsed, 3),
      error = result$error,
      stringsAsFactors = FALSE
    )
    message(
      sprintf(
        "[%03d] %s %s %s: %s rows, valid=%s, %.3fs%s",
        length(rows), release$product[[1]], release$edition[[1]], role,
        result$rows, result$valid, elapsed,
        if (nzchar(result$error)) paste0(" — ", result$error) else ""
      )
    )
  }
}

audit <- do.call(rbind, rows)
key <- paste(audit$product, audit$release_id, audit$role, sep = "\u241f")
expected_roles <- data.frame(
  product = c(
    "crop_report", "crop_report",
    "agricultural_commodities", "agricultural_commodities"
  ),
  role = c("national", "state", "outlook", "report"),
  expected = c(66L, 64L, 64L, 2L),
  stringsAsFactors = FALSE
)
actual_roles <- stats::aggregate(
  rep(1L, nrow(audit)),
  list(product = audit$product, role = audit$role),
  sum
)
names(actual_roles)[[3]] <- "expected"
actual_roles <- actual_roles[order(actual_roles$product, actual_roles$role), ]
expected_roles <- expected_roles[
  order(expected_roles$product, expected_roles$role),
]
if (nrow(audit) != 196L ||
    anyDuplicated(key) ||
    !isTRUE(all.equal(
      actual_roles, expected_roles, check.attributes = FALSE
    )) ||
    any(!grepl("^[a-f0-9]{64}$", audit$sha256)) ||
    any(audit$duplicate_canonical_keys != 0L, na.rm = TRUE)) {
  stop("Quarterly history audit cardinality, identity, hash, or key gate failed.")
}
write.csv(audit, output, row.names = FALSE, na = "")
if (!all(audit$valid)) {
  print(audit[!audit$valid, ], row.names = FALSE)
  stop("Quarterly history audit failed; see ", output)
}
message(
  sprintf(
    "PASS: %d assets, %d observations, %.3f seconds; %s",
    nrow(audit), sum(audit$rows), sum(audit$elapsed_seconds), output
  )
)
