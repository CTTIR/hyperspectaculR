# Combine benchmark.R records and /usr/bin/time logs into a portable table.
# Run: Rscript data-raw/summarise-benchmarks.R <record-directory> <output.csv>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) cli::cli_abort("Supply a record directory and output CSV.")
paths <- Sys.glob(file.path(args[1L], "*.rds"))
if (!length(paths)) cli::cli_abort("No benchmark records found.")
rows <- lapply(paths, function(path) {
  x <- readRDS(path)
  log <- sub("[.]rds$", ".log", path)
  rss <- if (file.exists(log)) {
    line <- readLines(log, warn = FALSE)
    line <- line[grepl("Maximum resident set size", line, fixed = TRUE)]
    if (length(line)) as.numeric(sub(".*: *", "", tail(line, 1L))) / 1024 else NA_real_
  } else NA_real_
  row <- data.frame(
    record = sub("[.]rds$", "", basename(path)), case = x$case, size = x$size,
    rows = x$dimensions[1L], cols = x$dimensions[2L], bands = x$dimensions[3L],
    seed = x$seed, input_mib = x$input_mib, peak_process_rss_mib = rss,
    R = x$session$R.version$version.string, package = x$package_version,
    ggplot2 = x$ggplot2_version,
    revision = if (is.null(x$revision)) NA_character_ else x$revision,
    source_dirty = if (is.null(x$source_status)) NA else length(x$source_status) > 0L
  )
  for (name in names(x$measurements)[-1L]) {
    value <- x$measurements[[name]]
    row[[paste0(name, "_median")]] <- stats::median(value)
    row[[paste0(name, "_min")]] <- min(value)
    row[[paste0(name, "_max")]] <- max(value)
  }
  row
})
utils::write.csv(do.call(rbind, rows), args[2L], row.names = FALSE)
cat("Wrote", length(rows), "records to", args[2L], "\n")
