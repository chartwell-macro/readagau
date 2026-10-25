#' Detect an ABARES asset format from its bytes
#'
#' `agau_detect_format()` uses a small signature read rather than trusting the
#' filename extension.  ZIP containers are inspected just enough to
#' distinguish OOXML workbooks (`xlsx`) and Word documents (`docx`) from a
#' generic `zip`; legacy OLE workbooks are returned as `xls`.
#'
#' @param path A length-one path to an existing local asset.  The filename
#'   extension is ignored.  The path is read but not modified.
#' @return A length-one character scalar, one of `"xlsx"`, `"docx"`,
#'   `"xls"`, `"zip"`, `"pdf"`, `"html"`, or `"unknown"`.
#' @details A missing path raises `agau_asset_missing_error`.  A readable file
#'   with no recognised signature is returned as `"unknown"`; the function does
#'   not attempt to parse its contents or make network requests.
#' @seealso [read_crop_report()], [read_agricultural_commodities()],
#'   [read_farm_productivity()]
#' @family asset and cache helpers
#' @examples
#' workbook <- system.file(
#'   "fixtures", "workbooks", "crop-national.xlsx", package = "readagau"
#' )
#' page <- system.file(
#'   "fixtures", "html", "crop-archive.html", package = "readagau"
#' )
#' stopifnot(agau_detect_format(workbook) == "xlsx")
#' agau_detect_format(page)
#' @export
agau_detect_format <- function(path) {
  if (!file.exists(path)) {
    agau_abort("agau_asset_missing_error", "Asset does not exist.",
      asset_type = NA_character_, remediation = "Supply an existing local path."
    )
  }
  con <- file(path, "rb"); on.exit(close(con), add = TRUE)
  sig <- readBin(con, "raw", n = min(16L, file.info(path)$size))
  if (length(sig) >= 4L &&
      all(as.integer(sig[1:4]) == as.integer(c(0x50, 0x4b, 0x03, 0x04)))) {
    listing <- tryCatch(utils::unzip(path, list = TRUE), error = function(e) NULL)
    is_xlsx <- !is.null(listing) &&
      "[Content_Types].xml" %in% listing$Name &&
      any(startsWith(listing$Name, "xl/"))
    is_docx <- !is.null(listing) &&
      "[Content_Types].xml" %in% listing$Name &&
      "word/document.xml" %in% listing$Name
    return(if (is_xlsx) "xlsx" else if (is_docx) "docx" else "zip")
  }
  if (length(sig) >= 8L && all(as.integer(sig[1:8]) == as.integer(c(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1)))) return("xls")
  txt <- paste(rawToChar(sig, multiple = TRUE), collapse = "")
  if (startsWith(txt, "%PDF")) return("pdf")
  if (grepl("^\\s*<(?:!doctype\\s+html|html)", txt, ignore.case = TRUE)) return("html")
  "unknown"
}

agau_readxl_path <- function(path) {
  format <- agau_detect_format(path)
  if (!format %in% c("xls", "xlsx")) {
    agau_abort("agau_asset_format_error",
      paste0("Expected a workbook but detected ", format, "."),
      remediation = "Use the official workbook asset and verify its bytes."
    )
  }
  ext <- tolower(tools::file_ext(path))
  if (identical(format, ext)) return(path)
  copied <- tempfile(fileext = paste0(".", format))
  if (!file.copy(path, copied, overwrite = FALSE)) {
    agau_abort("agau_asset_format_error", "Could not stage a byte-sniffed workbook.",
      remediation = "Check temporary-directory permissions."
    )
  }
  copied
}
