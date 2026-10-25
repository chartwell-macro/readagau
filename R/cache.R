#' Return the managed readagau cache directory
#'
#' `readagau` keeps downloaded raw assets and parsed intermediates below the
#' directory returned by `tools::R_user_dir()`.  The location is platform
#' specific and is suitable for passing to the `cache_dir` argument of the
#' package readers and download helpers.
#'
#' @return A length-one character scalar containing the user-level cache path.
#' The directory is not created by this function.  Callers that need to write
#' to it should create it as part of their normal cache operation.
#' @seealso [download_agau_release()], [read_crop_report()]
#' @family cache and provenance helpers
#' @examples
#' cache <- agau_cache_dir()
#' stopifnot(is.character(cache), length(cache) == 1L, nzchar(cache))
#' @export
agau_cache_dir <- function() {
  tools::R_user_dir("readagau", "cache")
}
