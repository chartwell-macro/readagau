suppressPackageStartupMessages(pkgload::load_all(
  "/path/to/user/dev/readagau", quiet = TRUE
))

cache <- tempfile("readagau-real-validation-")
dir.create(cache)

crop_march <- read_crop_report(
  c(national = "/private/tmp/readagau_acr_202603_national.xlsx"),
  assets = "national", view = "reported", cache_dir = cache,
  release_id = "acr-2026-03-03-no-217",
  release_date = as.Date("2026-03-03")
)
crop_june <- read_crop_report(
  c(
    national = "/private/tmp/readagau_acr_202606_national.xlsx",
    state = "/private/tmp/readagau_acr_202606_state.xlsx"
  ),
  view = "reported", cache_dir = cache,
  release_id = "acr-2026-06-02-no-218",
  release_date = as.Date("2026-06-02")
)
ac_march <- read_agricultural_commodities(
  c(
    outlook = "/private/tmp/readagau_ac_202603_outlook.xlsx",
    statistics = "/private/tmp/readagau_ac_202603_stats.xlsx"
  ),
  view = "reported", cache_dir = cache,
  release_id = "ac-2026-03-03",
  release_date = as.Date("2026-03-03")
)
ac_june <- read_agricultural_commodities(
  c(
    outlook = "/private/tmp/readagau_ac_202606_outlook.xlsx",
    statistics = "/private/tmp/readagau_ac_202606_stats.xlsx"
  ),
  view = "reported", cache_dir = cache,
  release_id = "ac-2026-06-02",
  release_date = as.Date("2026-06-02")
)
productivity <- read_farm_productivity(
  "/private/tmp/readagau_productivity_202606.xls",
  view = "reported", cache_dir = cache,
  release_id = "productivity-2026-06",
  release_date = as.Date("2026-06-30")
)

summary <- data.frame(
  object = c(
    "crop_march_national", "crop_june_national_state",
    "commodities_march_outlook_stats", "commodities_june_outlook_stats",
    "productivity"
  ),
  rows = c(nrow(crop_march), nrow(crop_june), nrow(ac_march), nrow(ac_june), nrow(productivity)),
  tables = c(
    length(unique(crop_march$table_id)), length(unique(crop_june$table_id)),
    length(unique(ac_march$table_id)), length(unique(ac_june$table_id)),
    length(unique(productivity$table_id))
  ),
  stringsAsFactors = FALSE
)
print(summary, row.names = FALSE)

golden <- rbind(
  transform(
    crop_march[
      crop_march$table_id == "crop_national_table_11" &
        tolower(crop_march$commodity) == "wheat" &
        tolower(crop_march$concept) == "production" &
        crop_march$period == "2025-26",
      c("product", "release_id", "table_id", "period", "period_status", "value")
    ],
    golden = "March Crop Table 11 wheat production"
  ),
  transform(
    ac_march[
      ac_march$table_id == "ac_outlook_major_indicators" &
        ac_march$concept == "Value of agricultural exports" &
        ac_march$period %in% c("2025-26", "2026-27"),
      c("product", "release_id", "table_id", "period", "period_status", "value")
    ],
    golden = "March Major indicators agricultural exports"
  ),
  transform(
    ac_june[
      ac_june$table_id == "ac_outlook_major_indicators" &
        ac_june$concept == "Value of agricultural exports" &
        ac_june$period %in% c("2025-26", "2026-27"),
      c("product", "release_id", "table_id", "period", "period_status", "value")
    ],
    golden = "June Major Indicators agricultural exports"
  )
)
print(golden[, c(
  "golden", "release_id", "period", "period_status", "value"
)], row.names = FALSE, digits = 12)

hashes <- data.frame(
  file = basename(c(
    "/private/tmp/readagau_ac_202603_outlook.xlsx",
    "/private/tmp/readagau_ac_202603_stats.xlsx",
    "/private/tmp/readagau_acr_202603_national.xlsx",
    "/private/tmp/readagau_ac_202606_outlook.xlsx",
    "/private/tmp/readagau_ac_202606_stats.xlsx",
    "/private/tmp/readagau_acr_202606_national.xlsx",
    "/private/tmp/readagau_acr_202606_state.xlsx",
    "/private/tmp/readagau_productivity_202606.xls"
  )),
  sha256 = vapply(c(
    "/private/tmp/readagau_ac_202603_outlook.xlsx",
    "/private/tmp/readagau_ac_202603_stats.xlsx",
    "/private/tmp/readagau_acr_202603_national.xlsx",
    "/private/tmp/readagau_ac_202606_outlook.xlsx",
    "/private/tmp/readagau_ac_202606_stats.xlsx",
    "/private/tmp/readagau_acr_202606_national.xlsx",
    "/private/tmp/readagau_acr_202606_state.xlsx",
    "/private/tmp/readagau_productivity_202606.xls"
  ), readagau:::agau_sha256, ""),
  stringsAsFactors = FALSE
)
print(hashes, row.names = FALSE)
write.csv(summary, "/private/tmp/readagau-real-summary.csv", row.names = FALSE)
write.csv(golden, "/private/tmp/readagau-real-goldens.csv", row.names = FALSE)
write.csv(hashes, "/private/tmp/readagau-real-hashes.csv", row.names = FALSE)
