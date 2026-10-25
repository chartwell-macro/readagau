agau_source_priority <- function(data) {
  p <- rep(50L, nrow(data))
  if ("source_asset" %in% names(data)) p[data$source_asset == "state"] <- 10L
  p[grepl("crop_national_table_(11|12)$", data$table_id)] <- 10L
  p[grepl("crop_national_table_0[1-3]$", data$table_id)] <- 20L
  p[grepl("crop_national_table_(0[4-9]|10)$", data$table_id)] <- 30L
  p[grepl("crop_national_table_(13|14)$", data$table_id)] <- 40L
  p[data$product == "agricultural_commodities" &
      data$source_asset == "outlook" &
      data$period_status %in% c("estimate", "forecast", "projection")] <- 10L
  p[data$product == "agricultural_commodities" &
      data$source_asset == "statistics" &
      data$period_status %in% c("historical", "published-unclassified")] <- 10L
  p
}

agau_canonicalise <- function(data) {
  if (!nrow(data)) return(data)
  priority <- agau_source_priority(data)
  groups <- split(seq_len(nrow(data)), data$observation_key)
  keep <- integer()
  for (idx in groups) {
    best <- idx[priority[idx] == min(priority[idx])]
    finite <- unique(data$value[best][!is.na(data$value[best])])
    if (length(finite) > 1L) {
      agau_abort("agau_validation_error",
        "Ambiguous canonical collision contains different top-priority values.",
        product = data$product[best[1]], release_id = data$release_id[best[1]],
        series_id = data$series_id[best[1]],
        remediation = "Review and version the canonical precedence manifest."
      )
    }
    keep <- c(keep, best[1])
  }
  out <- data[sort(keep), , drop = FALSE]
  out$record_role <- "canonical"
  out
}

agau_filter_data <- function(data, tables = "all", geography = NULL,
                             commodities = NULL, concepts = NULL,
                             sectors = NULL, measures = NULL) {
  keep <- rep(TRUE, nrow(data))
  if (!identical(tables, "all")) keep <- keep & data$table_id %in% tables
  if (!is.null(geography)) keep <- keep & data$geography %in% geography
  if (!is.null(commodities)) keep <- keep & data$commodity %in% commodities
  if (!is.null(concepts)) keep <- keep & data$concept %in% concepts
  if (!is.null(sectors)) keep <- keep & data$sector %in% sectors
  if (!is.null(measures)) keep <- keep & data$concept %in% measures
  data[keep, , drop = FALSE]
}

