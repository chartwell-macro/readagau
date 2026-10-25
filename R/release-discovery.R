agau_product_pages <- function() {
  path <- system.file("config", "product-pages.csv", package = "readagau")
  if (!nzchar(path)) {
    agau_abort("agau_validation_error", "Product page configuration is missing.",
      remediation = "Reinstall from a complete readagau source tree."
    )
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

agau_page_input <- function(page) {
  if (startsWith(page, "file://")) utils::URLdecode(sub("^file://", "", page)) else page
}

agau_read_html_page <- function(page) {
  input <- agau_page_input(page)
  remote <- grepl("^[A-Za-z][A-Za-z0-9+.-]*://", page) &&
    !startsWith(tolower(page), "file://")
  if (!remote || file.exists(input)) return(rvest::read_html(input))
  fetched <- agau_fetch_to_temp(page)
  on.exit(if (file.exists(fetched$path)) unlink(fetched$path), add = TRUE)
  rvest::read_html(fetched$path)
}

agau_parse_english_date_one <- function(value) {
  if (length(value) != 1L || is.na(value)) return(NA_character_)
  key <- paste0("english-date\u241f", enc2utf8(as.character(value)))
  cached <- .agau_runtime[[key]]
  if (!is.null(cached)) return(cached[[1L]])
  remember <- function(result) {
    .agau_runtime[[key]] <- list(result)
    result
  }
  value <- trimws(gsub(",", "", agau_norm_scalar(value), fixed = TRUE))
  if (!nzchar(value)) return(remember(NA_character_))
  if (grepl("^[12][0-9]{3}-[01][0-9]-[0-3][0-9]$", value)) {
    date <- suppressWarnings(as.Date(value))
    return(remember(if (is.na(date)) NA_character_ else value))
  }
  if (grepl("^(?:19|20)[0-9]{2}[ -]", value, perl = TRUE)) {
    matched <- regmatches(
      value,
      regexec(
        "^((?:19|20)[0-9]{2})[ -]+([0-3]?[0-9])[ -]+([A-Za-z]+)$",
        value,
        perl = TRUE
      )
    )[[1]]
    parts <- if (length(matched) == 4L) {
      c(matched[[3]], matched[[4]], matched[[2]])
    } else {
      NULL
    }
  } else {
    matched <- regmatches(
      value,
      regexec(
        "^([0-3]?[0-9])[ -]+([A-Za-z]+)[ -]+([0-9]{2,4})$",
        value,
        perl = TRUE
      )
    )[[1]]
    parts <- if (length(matched) == 4L) matched[2:4] else NULL
  }
  if (is.null(parts)) return(remember(NA_character_))
  month <- match(
    tolower(parts[[2]]),
    c(tolower(month.name), tolower(month.abb))
  )
  if (is.na(month)) return(remember(NA_character_))
  if (month > length(month.name)) month <- month - length(month.name)
  year <- as.integer(parts[[3]])
  if (nchar(parts[[3]]) == 2L) {
    year <- if (year >= 69L) 1900L + year else 2000L + year
  }
  date <- suppressWarnings(as.Date(sprintf(
    "%04d-%02d-%02d", year, month, as.integer(parts[[1]])
  )))
  remember(if (is.na(date)) NA_character_ else format(date, "%Y-%m-%d"))
}

agau_parse_english_date <- function(value) {
  if (length(value) == 1L) {
    return(unname(as.Date(agau_parse_english_date_one(value))))
  }
  values <- unique(value)
  parsed <- vapply(values, agau_parse_english_date_one, character(1))
  unname(as.Date(parsed[match(value, values)]))
}

agau_english_month_year <- function(date) {
  date <- as.Date(date)
  out <- paste(
    month.name[as.integer(format(date, "%m"))],
    format(date, "%Y")
  )
  out[is.na(date)] <- NA_character_
  out
}

agau_english_day_month_year <- function(date) {
  date <- as.Date(date)
  out <- paste(
    as.integer(format(date, "%d")),
    month.name[as.integer(format(date, "%m"))],
    format(date, "%Y")
  )
  out[is.na(date)] <- NA_character_
  out
}

agau_asset_role <- function(product, label, href) {
  x <- tolower(paste(label, href))
  if (product == "crop_report") {
    if (grepl("state", x) && grepl("\\.xls", x)) return("state")
    if (grepl("data|national|tables", x) && grepl("\\.xls", x)) return("national")
    if (grepl("\\.pdf|report pdf|download report", x)) return("report")
  }
  if (product == "agricultural_commodities") {
    if (grepl("statistic|historical", x) && grepl("\\.xls", x)) return("statistics")
    if (grepl("outlook|data", x) && grepl("\\.xls", x)) return("outlook")
    if (grepl("\\.pdf|report pdf|download report", x)) return("report")
  }
  if (product == "farm_productivity") {
    if (grepl("support|data|estimate", x) && grepl("\\.xls", x)) return("supporting_data")
    if (grepl("method", x)) return("methodology")
    if (grepl("\\.pdf|report", x)) return("report")
  }
  if (product == "historical_forecast_database" &&
      grepl("historical agricultural forecast database", x) &&
      grepl("\\.xls", x)) return("supporting_data")
  if (product == "weekly_commodity_prices") {
    if (grepl("\\.pdf", x)) return("report")
    if (grepl("\\.zip", x)) return("archive")
    if (grepl("weekly commodity price|current indicator", x)) {
      return("page_snapshot")
    }
  }
  NA_character_
}

agau_release_id <- function(product, date, text) {
  date_text <- format(as.Date(date), "%Y-%m-%d")
  if (product == "crop_report") {
    no <- regmatches(text, regexpr("(?:No\\.?|number)\\s*[0-9]+", text, ignore.case = TRUE))
    no <- regmatches(no, regexpr("[0-9]+", no))
    paste0("acr-", date_text, if (length(no) && nzchar(no)) paste0("-no-", no) else "")
  } else if (product == "agricultural_commodities") {
    paste0("ac-", date_text)
  } else if (product == "farm_productivity") {
    paste0("productivity-", format(as.Date(date), "%Y-%m"))
  } else {
    paste0(agau_slug(product), "-", date_text)
  }
}

agau_parse_date <- function(text) {
  month <- paste(month.name, collapse = "|")
  pat <- paste0("(?:[0-3]?[0-9]\\s+(?:", month, ")\\s+[12][0-9]{3}|[12][0-9]{3}-[01][0-9]-[0-3][0-9])")
  got <- regmatches(text, regexpr(pat, text, ignore.case = TRUE))
  if (!length(got) || !nzchar(got)) return(as.Date(NA))
  agau_parse_english_date(got)
}

agau_release_edition <- function(doc, page, product) {
  candidates <- c(
    rvest::html_text2(rvest::html_elements(doc, "h1")),
    rvest::html_text2(rvest::html_elements(doc, "title")),
    gsub("[-_]+", " ", basename(sub("[?#].*$", "", page)))
  )
  candidates <- agau_norm_text(candidates)
  month <- paste(month.name, collapse = "|")
  pat <- paste0("\\b(", month, ")\\s+((?:19|20)[0-9]{2})\\b")
  for (candidate in candidates) {
    hit <- regmatches(candidate, regexec(pat, candidate, ignore.case = TRUE))[[1]]
    if (length(hit) == 3L) {
      month <- month.name[match(tolower(hit[2]), tolower(month.name))]
      return(paste(month, hit[3]))
    }
  }
  NA_character_
}

agau_audited_release_identity <- function(doc, page, product, base) {
  if (!product %in% c("crop_report", "agricultural_commodities")) return(NULL)
  catalogue <- agau_bundled_releases()
  catalogue <- catalogue[catalogue$product == product, , drop = FALSE]
  norm_url <- function(x) sub("/+$", "", sub("[?#].*$", "", x))
  exact <- which(norm_url(catalogue$landing_url) == norm_url(base))
  edition <- agau_release_edition(doc, page, product)
  by_edition <- if (is.na(edition)) integer() else {
    which(tolower(catalogue$edition) == tolower(edition))
  }
  hit <- if (length(exact) == 1L) exact else by_edition
  if (length(hit) != 1L) {
    agau_abort(
      "agau_release_discovery_error",
      "Release page does not match one audited product/edition identity.",
      product = product,
      remediation = paste(
        "Add and review the exact release date in the bundled catalogue;",
        "narrative or page-update dates are never used as release identity."
      )
    )
  }
  catalogue[hit, , drop = FALSE]
}

agau_parse_release_page <- function(page, product, landing_url = NULL,
                                    discovered_at = Sys.time()) {
  doc <- tryCatch(agau_read_html_page(page), error = function(e) {
    agau_abort("agau_release_discovery_error", conditionMessage(e),
      product = product, remediation = "Use a saved official HTML page or check connectivity."
    )
  })
  base <- landing_url %||% if (file.exists(page)) paste0("file://", normalizePath(page)) else page
  text <- agau_norm_text(rvest::html_text2(doc))
  profile <- agau_audited_release_identity(doc, page, product, base)
  date <- if (is.null(profile)) agau_parse_date(text) else profile$release_date[[1]]
  if (is.na(date)) {
    agau_abort("agau_release_discovery_error", "No release metadata found.",
      product = product,
      remediation = "Inspect official page date markup and update the discovery profile."
    )
  }
  anchors <- rvest::html_elements(doc, "a[href]")
  href <- rvest::html_attr(anchors, "href")
  labels <- rvest::html_text2(anchors)
  roles <- vapply(seq_along(href), function(i) {
    agau_asset_role(product, labels[i], href[i])
  }, "")
  keep <- !is.na(roles)
  urls <- stats::setNames(xml2::url_absolute(href[keep], base), roles[keep])
  urls <- urls[!duplicated(names(urls))]
  report_number <- if (is.null(profile)) {
    got <- regmatches(text, regexpr("(?:No\\.?|number)\\s*[0-9]+", text, ignore.case = TRUE))
    regmatches(got, regexpr("[0-9]+", got))
  } else {
    as.character(profile$report_number[[1]])
  }
  release_id <- if (is.null(profile)) {
    agau_release_id(product, date, text)
  } else {
    profile$release_id[[1]]
  }
  edition <- if (is.null(profile)) agau_english_month_year(date) else profile$edition[[1]]
  out <- data.frame(
    product = product, release_id = release_id,
    report_number = if (length(report_number)) report_number else NA_character_,
    release_date = date, edition = edition, landing_url = base,
    asset_status = if (length(urls)) "complete" else "partial",
    support_status = if (is.null(profile)) {
      "discovered-unverified"
    } else {
      profile$support_status[[1]]
    },
    unsupported_reason = if (is.null(profile)) {
      "Release identity or workbook profile has not been independently reviewed"
    } else {
      profile$unsupported_reason[[1]]
    },
    discovered_at = as.POSIXct(discovered_at, tz = "UTC"),
    discovery_version = agau_parser_version(),
    warning = if (length(urls)) "" else "No recognised assets on exact release page",
    stringsAsFactors = FALSE
  )
  out$asset_roles <- I(list(names(urls)))
  out$asset_urls <- I(list(urls))
  out
}

agau_parse_archive_links <- function(page, product, landing_url = NULL) {
  doc <- tryCatch(agau_read_html_page(page), error = function(e) {
    agau_abort("agau_release_discovery_error", conditionMessage(e),
      product = product, remediation = "Use the official archive page or a saved fixture."
    )
  })
  base <- landing_url %||% if (file.exists(page)) paste0("file://", normalizePath(page)) else page
  anchors <- rvest::html_elements(doc, "a[href]")
  href <- rvest::html_attr(anchors, "href")
  label <- agau_norm_text(rvest::html_text2(anchors))
  edition <- grepl(
    "(march|june|september|december)[-/ ]20[0-9]{2}",
    paste(label, href), ignore.case = TRUE
  )
  href <- href[edition]; label <- label[edition]
  if (!length(href)) return(tibble::tibble())
  urls <- xml2::url_absolute(href, base)
  data.frame(
    product = product, edition_label = label, landing_url = urls,
    stringsAsFactors = FALSE
  )[!duplicated(urls), , drop = FALSE]
}

agau_discover_product <- function(archive_page, product, landing_url = NULL) {
  if (identical(product, "weekly_commodity_prices")) {
    return(agau_bundled_releases()[
      agau_bundled_releases()$product == product, , drop = FALSE
    ])
  }
  links <- agau_parse_archive_links(archive_page, product, landing_url)
  if (!nrow(links)) {
    return(agau_parse_release_page(
      archive_page, product, landing_url = landing_url %||% archive_page
    ))
  }
  rows <- lapply(links$landing_url, function(url) {
    agau_parse_release_page(url, product, landing_url = url)
  })
  out <- do.call(rbind, rows)
  out[!duplicated(out$release_id), , drop = FALSE]
}

agau_bundled_releases <- function() {
  path <- system.file("catalogue", "release-catalog.csv", package = "readagau")
  x <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
  x$release_date <- as.Date(x$release_date)
  x$report_number <- as.character(x$report_number)
  x$discovered_at <- as.POSIXct(x$discovered_at, tz = "UTC")
  x$asset_roles <- lapply(strsplit(x$asset_roles, "\\|", fixed = FALSE), function(z) z[nzchar(z)])
  if ("asset_urls" %in% names(x)) {
    x$asset_urls <- Map(function(urls, roles) {
      values <- strsplit(urls %||% "", "\\|", fixed = FALSE)[[1]]
      values <- values[nzchar(values)]
      if (!length(values)) return(character())
      if (length(values) != length(roles)) {
        agau_abort(
          "agau_validation_error",
          "Bundled release asset roles and URLs are not aligned.",
          remediation = "Repair the audited release catalogue row."
        )
      }
      stats::setNames(values, roles)
    }, x$asset_urls, x$asset_roles)
  } else {
    x$asset_urls <- rep(list(character()), nrow(x))
  }
  weekly_path <- system.file(
    "catalogue", "weekly-release-catalog.csv", package = "readagau"
  )
  if (!nzchar(weekly_path)) return(tibble::as_tibble(x))
  weekly <- utils::read.csv(
    weekly_path, stringsAsFactors = FALSE, na.strings = ""
  )
  weekly$release_date <- as.Date(weekly$release_date)
  out <- data.frame(
    product = "weekly_commodity_prices",
    release_id = weekly$release_id,
    report_number = NA_character_,
    release_date = weekly$release_date,
    edition = sprintf(
      "%02d %s %s",
      as.integer(format(weekly$release_date, "%d")),
      month.name[as.integer(format(weekly$release_date, "%m"))],
      format(weekly$release_date, "%Y")
    ),
    landing_url = weekly$landing_url,
    asset_status = ifelse(
      weekly$support_status == "supported", "complete", "partial"
    ),
    support_status = weekly$support_status,
    unsupported_reason = weekly$unsupported_reason,
    discovered_at = as.POSIXct("2026-07-27 00:00:00", tz = "UTC"),
    discovery_version = agau_parser_version(),
    warning = ifelse(
      weekly$support_status == "supported",
      "", "Official report asset is not retrievable"
    ),
    stringsAsFactors = FALSE
  )
  out$asset_roles <- lapply(seq_len(nrow(weekly)), function(i) {
    if (weekly$support_status[[i]] == "supported") weekly$asset_type[[i]] else character()
  })
  out$asset_urls <- lapply(seq_len(nrow(weekly)), function(i) {
    if (weekly$support_status[[i]] != "supported") return(character())
    stats::setNames(weekly$source_url[[i]], weekly$asset_type[[i]])
  })
  tibble::as_tibble(rbind(x, out))
}

agau_discovery_path <- function(cache_dir) {
  file.path(cache_dir, "discovery", "releases.rds")
}

agau_write_discovery <- function(x, cache_dir) {
  path <- agau_discovery_path(cache_dir)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lock <- agau_acquire_cache_lock(path)
  on.exit(agau_release_cache_lock(lock), add = TRUE)
  current <- if (file.exists(path)) {
    tryCatch(readRDS(path), error = function(e) NULL)
  } else {
    NULL
  }
  if (!is.null(current) && nrow(current)) {
    x <- rbind(current, x)
    key <- paste(x$product, x$release_id, sep = "\u241f")
    x <- x[!duplicated(key, fromLast = TRUE), , drop = FALSE]
  }
  stage <- tempfile(".agau-discovery-", tmpdir = dirname(path))
  on.exit(if (file.exists(stage)) unlink(stage), add = TRUE)
  saveRDS(x, stage, version = 3)
  readRDS(stage)
  if (file.exists(path)) {
    backup <- paste0(path, ".previous")
    if (file.exists(backup)) unlink(backup)
    if (!file.rename(path, backup)) {
      agau_abort("agau_validation_error", "Could not rotate discovery cache.",
        remediation = "Check cache discovery permissions."
      )
    }
    on.exit(if (file.exists(backup) && !file.exists(path)) file.rename(backup, path), add = TRUE)
  }
  if (!file.rename(stage, path)) {
    agau_abort("agau_validation_error", "Atomic discovery-cache write failed.",
      remediation = "Check cache discovery permissions."
    )
  }
  backup <- paste0(path, ".previous")
  if (file.exists(backup)) unlink(backup)
  invisible(path)
}

#' List audited ABARES product releases
#'
#' Return the package's release manifest for one or more supported products.
#' With the default `refresh = FALSE`, the function reads the local discovery
#' cache when available and otherwise the versioned catalogue shipped with the
#' package; it does not contact the network. Set `refresh = TRUE` explicitly
#' when current official landing pages should be inspected. Weekly commodity
#' price rows are catalogue metadata and retain the publisher's support status;
#' they are not a claim that upstream values may be redistributed.
#'
#' @param products Character vector of product IDs. The default requests
#'   `"crop_report"`, `"agricultural_commodities"`, `"farm_productivity"`,
#'   and `"weekly_commodity_prices"`. Supported values are validated before
#'   any discovery work.
#' @param refresh Logical scalar, default `FALSE`. If `FALSE`, use the
#'   immutable discovery cache or bundled catalogue without network access. If
#'   `TRUE`, re-read the configured official landing pages for products whose
#'   discovery profile supports refresh, merge catalogue metadata for gated
#'   products, and write the resulting discovery manifest below `cache_dir`.
#' @param include_archive Logical scalar, default `TRUE`. When `TRUE`, return
#'   every audited edition. When `FALSE`, retain only the row with the latest
#'   `release_date` for each requested product.
#' @param cache_dir Character path to the discovery cache. Defaults to
#'   [agau_cache_dir()]. A non-refreshing call reads but does not create or
#'   modify this directory; a refreshing call writes
#'   `discovery/releases.rds` using an atomic, locked update.
#' @return A tibble with one row per release and these 14 columns, in order:
#'   `product`, `release_id`, `report_number`, `release_date`, `edition`,
#'   `landing_url`, `asset_roles`, `asset_urls`, `asset_status`,
#'   `support_status`, `unsupported_reason`, `discovered_at`,
#'   `discovery_version`, and `warning`. Identifier, label, URL, status, and
#'   warning columns are character; `release_date` is `Date`; and
#'   `discovered_at` is UTC `POSIXct`. `asset_roles` is a list-column of
#'   character role IDs and `asset_urls` is a named list-column whose names
#'   align with those roles. Rows are sorted by `product` and
#'   `release_date`; `release_id` is unique within the returned manifest.
#'   `unsupported_reason` and `report_number` may be `NA_character_`.
#' @details A product with no recognised assets is retained with a partial or
#'   unsupported status rather than silently dropped. A malformed or missing
#'   bundled catalogue raises `agau_validation_error`; an unknown product or
#'   failed landing-page parse raises `agau_release_discovery_error`. Network
#'   requests made during refresh use the package's bounded 60-second request
#'   timeout and retry policy. This function only discovers metadata and URLs;
#'   it does not download bytes, invoke Poppler, parse PDFs/ZIPs, or write raw
#'   assets. Pass an exact `release_id` to [download_agau_release()] when the
#'   selected asset should be cached.
#' @seealso [agau_release_manifest_schema()], [agau_source_catalog()],
#'   [download_agau_release()], [agau_cache_dir()]
#' @family catalogue and schema helpers
#' @examples
#' cache <- tempfile("readagau-release-example-")
#' releases <- list_agau_releases(
#'   products = c("crop_report", "weekly_commodity_prices"),
#'   include_archive = FALSE, cache_dir = cache
#' )
#' stopifnot(
#'   inherits(releases, "tbl_df"),
#'   all(c("product", "release_id", "release_date", "asset_urls") %in%
#'     names(releases)),
#'   all(releases$product %in% c("crop_report", "weekly_commodity_prices")),
#'   all(!duplicated(releases$release_id))
#' )
#' releases[, c("product", "release_id", "release_date", "support_status")]
#' @export
list_agau_releases <- function(
    products = c("crop_report", "agricultural_commodities", "farm_productivity",
                 "weekly_commodity_prices"),
    refresh = FALSE, include_archive = TRUE, cache_dir = agau_cache_dir()) {
  known <- c("crop_report", "agricultural_commodities", "farm_productivity",
             "weekly_commodity_prices")
  bad <- setdiff(products, known)
  if (length(bad)) {
    agau_abort("agau_release_discovery_error",
      paste("Unknown product:", paste(bad, collapse = ", ")),
      remediation = "Use a product documented by list_agau_releases()."
    )
  }
  if (!isTRUE(refresh)) {
    saved <- agau_discovery_path(cache_dir)
    out <- if (file.exists(saved)) tryCatch(readRDS(saved), error = function(e) agau_bundled_releases()) else agau_bundled_releases()
    out <- out[out$product %in% products, , drop = FALSE]
  } else {
    pages <- agau_product_pages()
    supported <- intersect(products, pages$product[pages$refresh_supported])
    found <- lapply(supported, function(product) {
      url <- pages$landing_url[match(product, pages$product)]
      agau_discover_product(url, product, landing_url = url)
    })
    out <- if (length(found)) tibble::as_tibble(do.call(rbind, found)) else agau_bundled_releases()[0, ]
    gated <- setdiff(products, supported)
    if (length(gated)) {
      meta <- agau_bundled_releases()
      out <- rbind(out, meta[meta$product %in% gated, ])
    }
    agau_write_discovery(out, cache_dir)
  }
  if (!isTRUE(include_archive)) {
    latest <- stats::ave(as.numeric(out$release_date), out$product, FUN = max)
    out <- out[as.numeric(out$release_date) == latest, , drop = FALSE]
  }
  out[order(out$product, out$release_date), , drop = FALSE]
}
