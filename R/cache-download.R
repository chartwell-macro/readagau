agau_sha256 <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)

agau_acquire_cache_lock <- function(path, attempts = 500L) {
  lock <- paste0(path, ".lock")
  dir.create(dirname(lock), recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(attempts)) {
    if (dir.create(lock, showWarnings = FALSE)) return(lock)
    Sys.sleep(0.01)
  }
  agau_abort(
    "agau_validation_error",
    paste("Timed out waiting for cache lock:", basename(path)),
    remediation = "Check for an interrupted writer and remove only its stale lock directory."
  )
}

agau_release_cache_lock <- function(lock) {
  if (dir.exists(lock)) unlink(lock, recursive = TRUE)
  invisible(NULL)
}

agau_atomic_promote <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(to)) {
    if (!identical(agau_sha256(from), agau_sha256(to))) {
      agau_abort("agau_validation_error", "Immutable cache collision.",
        remediation = "Inspect the cache; bytes under a hash path must never change."
      )
    }
    return(normalizePath(to, mustWork = TRUE))
  }
  stage <- tempfile(".agau-incoming-", tmpdir = dirname(to))
  on.exit(if (file.exists(stage)) unlink(stage), add = TRUE)
  if (!file.copy(from, stage, overwrite = FALSE) ||
      !identical(agau_sha256(from), agau_sha256(stage))) {
    agau_abort("agau_download_error", "Same-directory cache staging failed.",
      remediation = "Check cache permissions and available space."
    )
  }
  if (!file.rename(stage, to)) {
    agau_abort("agau_download_error", "Atomic cache rename failed.",
      remediation = "Ensure the cache directory supports atomic rename."
    )
  }
  normalizePath(to, mustWork = TRUE)
}

agau_asset_index_path <- function(cache_dir, product, release_id) {
  file.path(cache_dir, "manifests", product, release_id, "assets.rds")
}

agau_read_asset_index <- function(cache_dir, product, release_id) {
  path <- agau_asset_index_path(cache_dir, product, release_id)
  if (!file.exists(path)) return(NULL)
  tryCatch(readRDS(path), error = function(e) NULL)
}

agau_write_asset_index <- function(index, cache_dir, product, release_id) {
  path <- agau_asset_index_path(cache_dir, product, release_id)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lock <- agau_acquire_cache_lock(path)
  on.exit(agau_release_cache_lock(lock), add = TRUE)
  current <- if (file.exists(path)) {
    tryCatch(readRDS(path), error = function(e) NULL)
  } else {
    NULL
  }
  if (!is.null(current) && nrow(current)) {
    index <- rbind(current, index)
    key <- paste(
      index$product, index$release_id, index$asset_type,
      index$source_url, index$sha256, sep = "\u241f"
    )
    index <- index[!duplicated(key, fromLast = TRUE), , drop = FALSE]
  }
  stage <- tempfile(".agau-manifest-", tmpdir = dirname(path))
  on.exit(if (file.exists(stage)) unlink(stage), add = TRUE)
  saveRDS(index, stage, version = 3)
  readRDS(stage)
  if (file.exists(path)) {
    old <- paste0(path, ".previous")
    if (file.exists(old)) unlink(old)
    if (!file.rename(path, old)) {
      agau_abort("agau_validation_error", "Could not rotate asset manifest.",
        remediation = "Check cache manifest permissions."
      )
    }
    on.exit(if (file.exists(old) && !file.exists(path)) file.rename(old, path), add = TRUE)
  }
  if (!file.rename(stage, path)) {
    agau_abort("agau_validation_error", "Atomic asset-manifest write failed.",
      remediation = "Check cache manifest permissions."
    )
  }
  old <- paste0(path, ".previous")
  if (file.exists(old)) unlink(old)
  invisible(path)
}

agau_cached_asset <- function(cache_dir, product, release_id, asset_type, source_url) {
  index <- agau_read_asset_index(cache_dir, product, release_id)
  if (is.null(index) || !nrow(index)) return(NULL)
  hit <- index[
    index$asset_type == asset_type & index$source_url == source_url &
      index$validation_status == "valid",
    , drop = FALSE
  ]
  if (!nrow(hit)) return(NULL)
  hit <- hit[nrow(hit), , drop = FALSE]
  if (!file.exists(hit$local_path) ||
      !identical(agau_sha256(hit$local_path), hit$sha256)) return(NULL)
  hit
}

agau_valid_cached_rows <- function(index) {
  if (is.null(index) || !nrow(index)) return(index)
  valid <- index$validation_status == "valid" &
    file.exists(index$local_path)
  candidates <- index[valid, , drop = FALSE]
  if (!nrow(candidates)) return(candidates)
  hash_ok <- vapply(seq_len(nrow(candidates)), function(i) {
    identical(agau_sha256(candidates$local_path[[i]]), candidates$sha256[[i]])
  }, logical(1))
  candidates[hash_ok, , drop = FALSE]
}

agau_cached_release_assets <- function(cache_dir, product, release_id,
                                       assets = "all") {
  index <- agau_valid_cached_rows(
    agau_read_asset_index(cache_dir, product, release_id)
  )
  if (is.null(index) || !nrow(index)) return(NULL)
  roles <- if (identical(assets, "all")) {
    releases <- NULL
    discovery <- agau_discovery_path(cache_dir)
    if (file.exists(discovery)) {
      releases <- tryCatch(readRDS(discovery), error = function(e) NULL)
    }
    hit <- if (!is.null(releases)) {
      releases[
        releases$product == product & releases$release_id == release_id,
        , drop = FALSE
      ]
    } else NULL
    if (is.null(hit) || !nrow(hit)) {
      audited <- agau_bundled_releases()
      hit <- audited[
        audited$product == product & audited$release_id == release_id,
        , drop = FALSE
      ]
    }
    if (!nrow(hit)) return(NULL)
    hit$asset_roles[[1]]
  } else assets
  if (!all(roles %in% index$asset_type)) return(NULL)
  rows <- lapply(roles, function(role) {
    hit <- index[index$asset_type == role, , drop = FALSE]
    hit[nrow(hit), , drop = FALSE]
  })
  do.call(rbind, rows)
}

agau_find_cached_product_asset <- function(cache_dir, product, asset_type) {
  root <- file.path(cache_dir, "manifests", product)
  if (!dir.exists(root)) return(NULL)
  paths <- list.files(
    root, pattern = "^assets[.]rds$", recursive = TRUE, full.names = TRUE
  )
  if (!length(paths)) return(NULL)
  rows <- lapply(paths, function(path) {
    agau_valid_cached_rows(tryCatch(readRDS(path), error = function(e) NULL))
  })
  rows <- rows[vapply(rows, function(x) !is.null(x) && nrow(x), logical(1))]
  if (!length(rows)) return(NULL)
  index <- do.call(rbind, rows)
  index <- index[index$asset_type == asset_type, , drop = FALSE]
  if (!nrow(index)) return(NULL)
  index <- index[order(index$retrieved_at), , drop = FALSE]
  index[nrow(index), , drop = FALSE]
}

agau_fetch_to_temp <- function(source_url) {
  tmp <- tempfile("agau-download-")
  local_source <- source_url
  if (startsWith(local_source, "file://")) {
    local_source <- utils::URLdecode(sub("^file://", "", local_source))
  }
  if (file.exists(local_source)) {
    if (!file.copy(local_source, tmp, overwrite = FALSE)) {
      agau_abort("agau_download_error", "Could not copy local source asset.",
        remediation = "Check source permissions."
      )
    }
    return(list(path = tmp, content_type = NA_character_, etag = NA_character_, last_modified = NA_character_))
  }
  response <- tryCatch(
    httr2::request(source_url) |>
      httr2::req_user_agent(paste0("readagau/", agau_parser_version())) |>
      httr2::req_timeout(60) |>
      httr2::req_retry(max_tries = 3, max_seconds = 180) |>
      httr2::req_perform(path = tmp),
    error = function(e) {
      agau_abort("agau_download_error", conditionMessage(e),
        remediation = "Check connectivity and the official landing-page link."
      )
    }
  )
  list(
    path = tmp,
    content_type = httr2::resp_header(response, "content-type") %||% NA_character_,
    etag = httr2::resp_header(response, "etag") %||% NA_character_,
    last_modified = httr2::resp_header(response, "last-modified") %||% NA_character_
  )
}

agau_cache_asset <- function(product, release_id, asset_type, source_url,
                             source_filename = basename(source_url),
                             cache_dir = agau_cache_dir(), verify = TRUE,
                             refresh = FALSE) {
  if (!isTRUE(refresh)) {
    cached <- agau_cached_asset(cache_dir, product, release_id, asset_type, source_url)
    if (!is.null(cached)) return(cached)
  }
  fetched <- agau_fetch_to_temp(source_url)
  on.exit(if (file.exists(fetched$path)) unlink(fetched$path), add = TRUE)
  format <- agau_detect_format(fetched$path)
  if (format == "html" && asset_type != "page_snapshot") {
    agau_abort("agau_asset_format_error", "HTML was returned for a non-HTML asset.",
      product = product, release_id = release_id, asset_type = asset_type,
      remediation = "Refresh discovery from the official landing page."
    )
  }
  allowed <- switch(asset_type,
    report = "pdf", word_report = "docx",
    page_snapshot = "html", archive = "zip",
    c("xlsx", "xls")
  )
  status <- if (format %in% allowed) "valid" else "warning"
  if (isTRUE(verify) && !format %in% allowed) {
    agau_abort("agau_asset_format_error",
      paste0("Unexpected ", format, " bytes for asset role ", asset_type, "."),
      product = product, release_id = release_id, asset_type = asset_type,
      remediation = "Use the asset URL parsed from official page metadata."
    )
  }
  hash <- agau_sha256(fetched$path)
  safe_name <- source_filename
  if (!nzchar(safe_name)) safe_name <- paste0(asset_type, ".", format)
  safe_name <- gsub("[^A-Za-z0-9._-]", "_", safe_name)
  target <- file.path(cache_dir, "raw", product, release_id, hash, safe_name)
  local <- agau_atomic_promote(fetched$path, target)
  out <- data.frame(
    product = product, release_id = release_id, asset_type = asset_type,
    source_url = source_url, source_filename = source_filename,
    detected_format = format, content_type = fetched$content_type,
    retrieved_at = as.POSIXct(Sys.time(), tz = "UTC"), etag = fetched$etag,
    last_modified = fetched$last_modified, sha256 = hash,
    bytes = as.numeric(file.info(local)$size), local_path = local,
    validation_status = status, unsupported_reason = NA_character_,
    stringsAsFactors = FALSE
  )
  index <- agau_read_asset_index(cache_dir, product, release_id)
  if (is.null(index)) index <- out[0, , drop = FALSE]
  same <- index$asset_type == asset_type & index$source_url == source_url &
    index$sha256 == hash
  if (!any(same)) index <- rbind(index, out)
  agau_write_asset_index(index, cache_dir, product, release_id)
  out
}

#' Download release assets into the immutable cache
#'
#' Resolve an audited release and copy its requested source assets into the
#' content-addressed `readagau` cache. The default path reads the bundled
#' release catalogue and reuses an already validated cache entry; it contacts
#' the source publisher only when an exact asset is absent or `refresh = TRUE`.
#' The function downloads bytes and records their provenance. It does not
#' parse a workbook, PDF, ZIP archive, or HTML page; use a product reader (for
#' example [read_crop_report()] or [read_agau_prices()]) for parsing.
#'
#' Official catalogue URLs are HTTPS. A local path or `file://` URL can also
#' be used when an application has deliberately seeded a local discovery
#' record, which is useful for deterministic tests and offline workflows.
#'
#' @param product A stable product ID. Supported values are
#'   `"crop_report"`, `"agricultural_commodities"`, `"farm_productivity"`,
#'   and `"weekly_commodity_prices"`.
#' @param release Exact release ID returned by [list_agau_releases()], or
#'   `"latest"` (the default), which selects the most recent release by
#'   `release_date` for `product`.
#' @param assets Character vector of asset roles to retrieve, or `"all"` (the
#'   default). Roles are product-specific, for example `"national"` and
#'   `"state"` for Crop Report, `"outlook"` for Agricultural Commodities,
#'   and `"report"` or `"archive"` for Weekly prices. Unknown or unavailable
#'   roles raise an `agau_asset_missing_error`.
#' @param cache_dir Character path to the managed cache. Defaults to
#'   [agau_cache_dir()]. The function creates `raw/` and `manifests/`
#'   descendants as needed; use a path below `tempdir()` for an isolated
#'   example or test.
#' @param refresh Logical scalar, default `FALSE`. When `FALSE`, a valid
#'   content-addressed asset is replayed without network access. When `TRUE`,
#'   release discovery and selected asset bytes are refreshed from their source
#'   URLs and the resulting manifest is updated atomically.
#' @param verify Logical scalar, default `TRUE`. Validate the detected file
#'   format against the requested asset role before admitting the bytes to the
#'   cache. Set to `FALSE` only for a deliberate diagnostic workflow; the
#'   returned row still records `validation_status`.
#' @return A tibble with one row per retrieved asset and the 15 columns in
#'   [agau_raw_asset_manifest_schema()]: `product`, `release_id`,
#'   `asset_type`, `source_url`, `source_filename`, `detected_format`,
#'   `content_type`, `retrieved_at`, `etag`, `last_modified`, `sha256`,
#'   `bytes`, `local_path`, `validation_status`, and `unsupported_reason`.
#'   `retrieved_at` is UTC `POSIXct`; `bytes` is numeric; `sha256` is a
#'   lowercase SHA-256 checksum; and `local_path` is the normalized immutable
#'   cache path. A successful verified result has `validation_status =
#'   "valid"` and a file whose checksum agrees with `sha256`.
#' @details HTTPS requests use a 60-second request timeout and bounded retry
#'   policy (up to three attempts, subject to a 180-second retry window).
#'   Temporary download files are removed after promotion. Cache writes use
#'   content-addressed paths, a per-manifest lock, checksum verification, and
#'   atomic rename, so an existing hash path is never silently overwritten.
#'   A failed request raises `agau_download_error`; an unknown release or role
#'   raises `agau_asset_missing_error`; an unexpected file format raises
#'   `agau_asset_format_error`; and cache validation or lock failures raise
#'   `agau_validation_error`. The errors carry remediation fields and do not
#'   expose credentials. PDF and ZIP bytes are only stored here: Poppler is
#'   required later if [read_agau_prices()] parses a PDF, and ZIP member safety
#'   is checked by that reader.
#' @seealso [list_agau_releases()], [agau_cache_dir()],
#'   [agau_raw_asset_manifest_schema()], [read_crop_report()],
#'   [read_agau_prices()]
#' @family cache and provenance helpers
#' @examples
#' fixture <- system.file(
#'   "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
#' )
#' cache <- tempfile("readagau-download-example-")
#' dir.create(cache, recursive = TRUE)
#'
#' # Seed a temporary discovery record with a package-owned fixture. This
#' # keeps the example offline while exercising the public cache workflow.
#' release <- list_agau_releases(
#'   products = "crop_report", include_archive = FALSE, cache_dir = cache
#' )[1, , drop = FALSE]
#' release$asset_roles <- list("national")
#' release$asset_urls <- list(
#'   stats::setNames(paste0("file://", normalizePath(fixture)), "national")
#' )
#' release$asset_status <- "complete"
#' release$support_status <- "supported"
#' readagau:::agau_write_discovery(release, cache)
#'
#' assets <- download_agau_release(
#'   "crop_report", release = release$release_id, assets = "national",
#'   cache_dir = cache
#' )
#' stopifnot(
#'   inherits(assets, "tbl_df"), nrow(assets) == 1L,
#'   assets$detected_format == "xlsx", assets$validation_status == "valid",
#'   file.exists(assets$local_path), nchar(assets$sha256) == 64L
#' )
#' @export
download_agau_release <- function(product, release = "latest", assets = "all",
                                  cache_dir = agau_cache_dir(), refresh = FALSE,
                                  verify = TRUE) {
  if (!identical(release, "latest") && !isTRUE(refresh)) {
    cached <- agau_cached_release_assets(
      cache_dir, product, release, assets = assets
    )
    if (!is.null(cached)) return(tibble::as_tibble(cached))
  }
  releases <- list_agau_releases(products = product, refresh = refresh, cache_dir = cache_dir)
  if (identical(release, "latest")) {
    releases <- releases[order(releases$release_date, decreasing = TRUE), , drop = FALSE]
    release <- releases$release_id[[1]]
  }
  hit <- releases[releases$release_id == release, , drop = FALSE]
  if (!nrow(hit)) {
    agau_abort("agau_asset_missing_error", "Unknown exact release.",
      product = product, release_id = release,
      remediation = "Choose a release returned by list_agau_releases()."
    )
  }
  urls <- hit$asset_urls[[1]]
  if (!length(urls)) {
    exact <- agau_parse_release_page(
      hit$landing_url[[1]], product, landing_url = hit$landing_url[[1]]
    )
    exact <- exact[exact$release_id == release | nrow(exact) == 1L, , drop = FALSE]
    if (!nrow(exact) || !length(exact$asset_urls[[1]])) {
      agau_abort("agau_asset_missing_error",
        "Exact official release page contains no recognised asset URLs.",
        product = product, release_id = release,
        remediation = "Refresh the exact release page parser profile."
      )
    }
    exact$release_id <- release
    exact$report_number <- hit$report_number
    current <- list_agau_releases(products = product, refresh = FALSE, cache_dir = cache_dir)
    current <- current[current$release_id != release, , drop = FALSE]
    agau_write_discovery(rbind(current, exact), cache_dir)
    hit <- exact
    urls <- exact$asset_urls[[1]]
  }
  roles <- names(urls)
  if (!identical(assets, "all")) roles <- intersect(roles, assets)
  if (!length(roles)) {
    agau_abort("agau_asset_missing_error", "Requested asset role is absent.",
      product = product, release_id = release,
      remediation = "Inspect asset_roles in list_agau_releases()."
    )
  }
  out <- lapply(roles, function(role) agau_cache_asset(
    product, release, role, urls[[role]], basename(urls[[role]]),
    cache_dir, verify, refresh
  ))
  tibble::as_tibble(do.call(rbind, out))
}
