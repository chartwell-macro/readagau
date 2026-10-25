suppressPackageStartupMessages(pkgload::load_all(
  ".", quiet = TRUE
))
cache <- "/private/tmp/readagau-evidence-cache"
dir.create(cache, recursive = TRUE, showWarnings = FALSE)

parse_crop <- function(path, role) read_crop_report(
  stats::setNames(path, role), assets = role, view = "reported", cache_dir = cache
)
parse_ac <- function(path, role) read_agricultural_commodities(
  stats::setNames(path, role), datasets = role, view = "reported", cache_dir = cache
)

objects <- list(
  crop_march_national = parse_crop(
    "/private/tmp/readagau_acr_202603_national.xlsx", "national"
  ),
  crop_june_national = parse_crop(
    "/private/tmp/readagau_acr_202606_national.xlsx", "national"
  ),
  crop_june_state = parse_crop(
    "/private/tmp/readagau_acr_202606_state.xlsx", "state"
  ),
  ac_march_outlook = parse_ac(
    "/private/tmp/readagau_ac_202603_outlook.xlsx", "outlook"
  ),
  ac_march_statistics = parse_ac(
    "/private/tmp/readagau_ac_202603_stats.xlsx", "statistics"
  ),
  ac_june_outlook = parse_ac(
    "/private/tmp/readagau_ac_202606_outlook.xlsx", "outlook"
  ),
  ac_june_statistics = parse_ac(
    "/private/tmp/readagau_ac_202606_stats.xlsx", "statistics"
  ),
  productivity = read_farm_productivity(
    "/private/tmp/readagau_productivity_202606.xls",
    view = "reported", cache_dir = cache
  )
)

classify <- function(name, x) {
  family <- if (startsWith(name, "crop")) {
    if (name == "crop_june_state") rep("state_history", nrow(x)) else {
      n <- as.integer(sub(".*_([0-9]+)$", "\\1", x$table_id))
      ifelse(n <= 3, "national_state_totals",
        ifelse(n <= 10, "current_state_snapshot",
          ifelse(n <= 12, "national_crop_history",
            ifelse(n <= 14, "recent_state_production",
              ifelse(n <= 16, "supply_disposal", "quarterly_prices")
            )
          )
        )
      )
    }
  } else if (grepl("outlook", name)) {
    ifelse(grepl("key_macro", x$table_id), "macroeconomic_assumptions",
      ifelse(grepl("major_indicators", x$table_id), "major_indicators",
        ifelse(grepl("beef|cattle|dairy|pig|poultry|chicken|lamb|sheep|wool", x$table_id),
          "livestock_products",
          ifelse(grepl("fisher", x$table_id), "fisheries_forestry", "crops")
        )
      )
    )
  } else if (grepl("statistics", name)) {
    "commodity_statistics_tables_01_18"
  } else {
    paste0("farm_productivity_", x$method)
  }
  if (length(family) == 1L) family <- rep(family, nrow(x))
  stopifnot(length(family) == nrow(x))
  aggregate(
    rep(1L, nrow(x)),
    list(
      object = rep(name, nrow(x)),
      dataset = rep(unique(x$dataset)[1], nrow(x)),
      family = family
    ),
    sum
  )
}

counts <- do.call(rbind, Map(classify, names(objects), objects))
names(counts)[4] <- "rows"
print(counts, row.names = FALSE)
write.csv(counts, "/private/tmp/readagau-family-counts.csv", row.names = FALSE)
