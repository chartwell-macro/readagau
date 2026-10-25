suppressPackageStartupMessages(pkgload::load_all(
  "/path/to/user/dev/readagau", quiet = TRUE
))

monitor <- function(label, expr) {
  gc()
  process <- ps::ps_handle()
  baseline <- unname(ps::ps_memory_info(process)[["rss"]])
  done <- tempfile("readagau-monitor-")
  parent_pid <- Sys.getpid()
  watcher <- parallel::mcparallel({
    handle <- ps::ps_handle(parent_pid)
    peak <- unname(ps::ps_memory_info(handle)[["rss"]])
    while (!file.exists(done)) {
      current <- tryCatch(unname(ps::ps_memory_info(handle)[["rss"]]),
        error = function(e) peak
      )
      peak <- max(peak, current)
      Sys.sleep(0.02)
    }
    peak
  })
  timing <- system.time(value <- force(expr))
  file.create(done)
  peak <- unname(parallel::mccollect(watcher)[[1]])
  unlink(done)
  data.frame(
    benchmark = label,
    elapsed_seconds = unname(timing[["elapsed"]]),
    peak_rss_delta_mb = (peak - baseline) / 1024^2,
    rows = if (is.data.frame(value)) nrow(value) else length(value),
    stringsAsFactors = FALSE
  )
}

crop_paths <- c(
  national = "/private/tmp/readagau_acr_202606_national.xlsx",
  state = "/private/tmp/readagau_acr_202606_state.xlsx"
)
ac_paths <- c(
  outlook = "/private/tmp/readagau_ac_202606_outlook.xlsx",
  statistics = "/private/tmp/readagau_ac_202606_stats.xlsx"
)
productivity_path <- "/private/tmp/readagau_productivity_202606.xls"

results <- list()
for (i in 1:3) {
  cache <- tempfile("agau-cold-crop-"); dir.create(cache)
  results[[length(results) + 1L]] <- monitor(
    paste0("crop_complete_cold_", i),
    read_crop_report(crop_paths, view = "reported", cache_dir = cache)
  )
}
crop_warm_cache <- tempfile("agau-warm-crop-"); dir.create(crop_warm_cache)
invisible(read_crop_report(crop_paths, view = "reported", cache_dir = crop_warm_cache))
for (i in 1:3) {
  results[[length(results) + 1L]] <- monitor(
    paste0("crop_parsed_restore_", i),
    read_crop_report(crop_paths, view = "reported", cache_dir = crop_warm_cache)
  )
}

for (i in 1:3) {
  cache <- tempfile("agau-cold-ac-"); dir.create(cache)
  results[[length(results) + 1L]] <- monitor(
    paste0("commodities_complete_cold_", i),
    read_agricultural_commodities(ac_paths, view = "reported", cache_dir = cache)
  )
}
ac_warm_cache <- tempfile("agau-warm-ac-"); dir.create(ac_warm_cache)
invisible(read_agricultural_commodities(ac_paths, view = "reported", cache_dir = ac_warm_cache))
for (i in 1:3) {
  results[[length(results) + 1L]] <- monitor(
    paste0("commodities_parsed_restore_", i),
    read_agricultural_commodities(ac_paths, view = "reported", cache_dir = ac_warm_cache)
  )
}

for (i in 1:3) {
  cache <- tempfile("agau-cold-productivity-"); dir.create(cache)
  results[[length(results) + 1L]] <- monitor(
    paste0("productivity_complete_cold_", i),
    read_farm_productivity(productivity_path, view = "reported", cache_dir = cache)
  )
}
prod_warm_cache <- tempfile("agau-warm-prod-"); dir.create(prod_warm_cache)
invisible(read_farm_productivity(
  productivity_path, view = "reported", cache_dir = prod_warm_cache
))
for (i in 1:3) {
  results[[length(results) + 1L]] <- monitor(
    paste0("productivity_parsed_restore_", i),
    read_farm_productivity(
      productivity_path, view = "reported", cache_dir = prod_warm_cache
    )
  )
}

for (i in 1:3) {
  results[[length(results) + 1L]] <- monitor(
    paste0("release_listing_", i),
    list_agau_releases(c(
      "crop_report", "agricultural_commodities", "farm_productivity"
    ), cache_dir = tempfile("agau-list-cache-"))
  )
}

out <- do.call(rbind, results)
print(out, row.names = FALSE, digits = 4)
write.csv(out, "/private/tmp/readagau-benchmarks.csv", row.names = FALSE)

