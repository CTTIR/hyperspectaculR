# Independent retained-population and histogram-resolution study.
# Run: Rscript data-raw/analyse-density.R <package-directory> <output-directory>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) cli::cli_abort("Supply package and output directories.")
pkgload::load_all(args[1L], quiet = TRUE)
dir.create(args[2L], recursive = TRUE, showWarnings = FALSE)

seed <- 20260910L
cube <- hsa_demo_cube(rows = 48L, cols = 64L, bands = 6L, seed = seed)
cube$wavelengths <- c(500, 505, 511, 520, 540, 580)
cube$data[1L, 1L, ] <- NA_real_
cube$data[2L, 2L, 3L] <- Inf
mask <- matrix(TRUE, 48L, 64L)
mask[seq_len(8L), ] <- FALSE
settings <- expand.grid(nbins = c(8L, 16L, 32L, 64L, 128L),
                        range = c("wide", "restricted"), masked = c(FALSE, TRUE),
                        stringsAsFactors = FALSE)
rows <- vector("list", nrow(settings))
for (i in seq_len(nrow(settings))) {
  setting <- settings[i, ]
  input <- cube
  input$mask <- if (setting$masked) mask else NULL
  limits <- if (setting$range == "wide") c(-0.1, 1) else c(0.2, 0.5)
  plot <- hsa_spectral_density(input, nbins = setting$nbins, limits = limits,
                               normalise = "band", transform = "log1p")
  record <- hsa_provenance(plot)$enhancement
  eligible <- if (setting$masked) mask else matrix(TRUE, 48L, 64L)
  bands <- lapply(seq_len(6L), function(b) {
    values <- input$data[, , b][eligible]
    finite <- values[is.finite(values)]
    retained <- finite[finite >= limits[1L] & finite <= limits[2L]]
    # Direct comparisons specify exact right-closed bins, independently of
    # the package's bin-code calculation and count accumulation.
    counts <- vapply(seq_len(setting$nbins), function(k) {
      lower <- if (k == 1L) retained >= record$breaks[k] else retained > record$breaks[k]
      sum(lower & retained <= record$breaks[k + 1L])
    }, integer(1))
    balanced <- c(identical(counts, record$H[, b]),
                  record$finite[b] == length(finite),
                  record$nonfinite[b] == sum(!is.finite(values)),
                  record$kept[b] == length(retained),
                  record$below[b] == sum(finite < limits[1L]),
                  record$above[b] == sum(finite > limits[2L]))
    if (!all(balanced)) {
      cli::cli_abort("Independent accounting failed for setting {i}, band {b}.",
                     class = "hsa_density_study_failure")
    }
    exact <- if (length(retained)) {
      c(mean(retained), stats::quantile(retained, c(0.05, 0.95), type = 1L, names = FALSE))
    } else rep(NA_real_, 3L)
    binned <- c(record$overlay$mean[b], record$overlay$lower[b], record$overlay$upper[b])
    error <- abs(binned - exact)
    bound <- diff(limits) / (2 * setting$nbins)
    if (!all(is.na(error) | error <= bound + 1e-12)) {
      cli::cli_abort("Half-bin error bound failed for setting {i}, band {b}.",
                     class = "hsa_density_study_failure")
    }
    data.frame(nbins = setting$nbins, range = setting$range, masked = setting$masked,
               band = b, wavelength = cube$wavelengths[b], eligible = length(values),
               nonfinite = sum(!is.finite(values)), finite = length(finite),
               retained = length(retained), retained_fraction = length(retained) / length(finite),
               exact_mean = exact[1L], binned_mean = binned[1L], mean_error = error[1L],
               lower_error = error[2L], upper_error = error[3L], half_bin_width = bound)
  })
  rows[[i]] <- do.call(rbind, bands)
}
result <- do.call(rbind, rows)
utils::write.csv(result, file.path(args[2L], "density-resolution.csv"), row.names = FALSE)
capture.output(list(seed = seed, dimensions = dim(cube$data),
                    masked_spatial = sum(!mask), settings = settings,
                    quantile_reference_type = 1L, tolerance = 1e-12,
                    package_version = as.character(utils::packageVersion("hyperspectaculR")),
                    session = utils::sessionInfo()),
               file = file.path(args[2L], "density-environment.txt"))
cat(nrow(result), "band/settings records pass exact accounting and half-bin error bounds.\n")
