# Descriptive simulation of sampling and noise sensitivity.
# Run: Rscript data-raw/analyse-sampling.R <output-directory>
# Calculations here are independent reference formulas, not package helpers.
# The extension tests compare public results against these definitions.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) cli::cli_abort("Supply an output directory.")
out <- args[1L]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
set.seed(20260910)
repetitions <- 50L
band_counts <- c(6L, 12L, 24L, 48L, 96L)
noise_levels <- c(0, 0.002, 0.01)
records <- list()
index <- 0L

reference <- function(x, wavelength) {
  steps <- diff(x)
  widths <- diff(wavelength)
  span <- diff(range(wavelength))
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), type = 7, names = FALSE)
  c(total_variation = sum(abs(steps)), mean_step = mean(abs(steps)),
    mean_absolute_slope = sum(abs(steps)) / span,
    rms_slope = sqrt(sum(steps^2 / widths) / span),
    lower_quartile = q[1L], median = q[2L], upper_quartile = q[3L])
}

for (bands in band_counts) {
  for (spacing in c("regular", "irregular")) {
    position <- seq(0, 1, length.out = bands)
    if (spacing == "irregular") position <- position^1.7
    wavelength <- 500 + 400 * position
    for (signal in c("flat", "linear", "narrow_peak", "oscillatory")) {
      truth <- switch(signal,
        flat = rep(0.3, bands),
        linear = 0.1 + 0.6 * position,
        narrow_peak = 0.2 + 0.5 * exp(-((position - 0.43) / 0.035)^2),
        oscillatory = 0.4 + 0.15 * sin(12 * pi * position)
      )
      for (noise in noise_levels) {
        for (correlation in c("independent", "correlated")) {
          for (trial in seq_len(if (noise == 0) 1L else repetitions)) {
            error <- stats::rnorm(bands, sd = noise)
            if (correlation == "correlated" && noise > 0) {
              # Stationary AR(1) marginal SD stays equal to `noise`.
              for (b in seq.int(2L, bands)) {
                error[b] <- 0.8 * error[b - 1L] + sqrt(1 - 0.8^2) * error[b]
              }
            }
            index <- index + 1L
            records[[index]] <- data.frame(
              bands = bands, spacing = spacing, signal = signal,
              noise_sd = noise, correlation = correlation, repetition = trial,
              as.list(reference(truth + error, wavelength))
            )
          }
        }
      }
    }
  }
}
measurements <- do.call(rbind, records)
metrics <- c("total_variation", "mean_step", "mean_absolute_slope", "rms_slope",
             "lower_quartile", "median", "upper_quartile")
groups <- c("bands", "spacing", "signal", "noise_sd", "correlation")
summary <- stats::aggregate(measurements[metrics], measurements[groups],
                            function(x) c(mean = mean(x), sd = if (length(x) > 1) stats::sd(x) else NA_real_,
                                          min = min(x), max = max(x),
                                          stats::quantile(x, c(.05, .5, .95), type = 7)))
# Expand aggregate's matrix columns to ordinary CSV fields.
summary <- do.call(data.frame, summary)
utils::write.csv(measurements, file.path(out, "sampling-measurements.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(out, "sampling-summary.csv"), row.names = FALSE)

# Separate exact examples reveal what each summary discards.
examples <- list(
  linear_coarse = list(x = c(0, 0.5, 1), wavelength = c(500, 700, 900)),
  linear_fine = list(x = seq(0, 1, length.out = 6), wavelength = seq(500, 900, length.out = 6)),
  concentrated_slope = list(x = c(0, 2, 2), wavelength = c(500, 501, 505)),
  subdivided_interval = list(x = c(0, 2, 2, 2), wavelength = c(500, 501, 503, 505)),
  quartile_reference = list(x = c(0, 1, 4, 9), wavelength = c(500, 600, 700, 800)),
  quartile_permutation = list(x = c(9, 0, 4, 1), wavelength = c(500, 600, 700, 800))
)
exact <- do.call(rbind, lapply(names(examples), function(name) {
  e <- examples[[name]]
  data.frame(example = name, as.list(reference(e$x, e$wavelength)))
}))
utils::write.csv(exact, file.path(out, "exact-examples.csv"), row.names = FALSE)
# Resampling onto a denser common grid cannot recover an unobserved peak.
coarse_wavelength <- seq(500, 900, length.out = 6L)
common_wavelength <- sort(unique(c(coarse_wavelength, seq(500, 900, length.out = 401L))))
peak <- function(w) 0.2 + 0.5 * exp(-(((w - 500) / 400 - 0.43) / 0.035)^2)
coarse <- peak(coarse_wavelength)
interpolated <- stats::approx(coarse_wavelength, coarse, xout = common_wavelength)$y
common_grid <- rbind(
  data.frame(source = "six measured bands", as.list(reference(coarse, coarse_wavelength))),
  data.frame(source = "linear interpolation of six bands", as.list(reference(interpolated, common_wavelength))),
  data.frame(source = "dense known synthetic truth", as.list(reference(peak(common_wavelength), common_wavelength)))
)
utils::write.csv(common_grid, file.path(out, "common-grid.csv"), row.names = FALSE)
writeLines(c(
  "Seed: 20260910", paste("Repetitions per noisy configuration:", repetitions),
  paste("Measurement rows:", nrow(measurements)),
  "Wavelength span: 500–900 nm; no calibration or biological inference.",
  "Correlated noise: stationary AR(1), rho=0.8, marginal SD equal to noise_sd.",
  "Quartiles: type 7, equally weighted measured bands.",
  capture.output(utils::sessionInfo())
), file.path(out, "experiment-environment.txt"))
print(exact, row.names = FALSE)
cat("Wrote", nrow(measurements), "measurements to", out, "\n")
