#' Default readagau cache directory
#'
#' @return A platform-appropriate cache path.
#' @export
agau_cache_dir <- function() {
  tools::R_user_dir("readagau", "cache")
}
