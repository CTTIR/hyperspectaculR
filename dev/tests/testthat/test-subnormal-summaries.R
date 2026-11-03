tiny_spectrum <- function(values, wavelengths = seq_along(values)) {
  structure(list(data = array(values, c(1L, 1L, length(values))),
                 wavelengths = wavelengths), class = "hsi_cube")
}

test_that("RMS slopes preserve joint value and wavelength unit changes", {
  cases <- list(
    list(values = c(0, 1, 0), wavelengths = c(0, 1, 2)),
    list(values = c(0, 1, 1), wavelengths = c(0, 1, 2)),
    list(values = c(-2, 3, -1, 4), wavelengths = c(0, 1, 3, 6))
  )
  for (case in cases) {
    # Compute the physical definition on small integers, independently of the
    # binary arithmetic used by the implementation at the requested scale.
    width <- diff(case$wavelengths)
    span <- tail(case$wavelengths, 1L) - case$wavelengths[1L]
    expected <- sqrt(sum(diff(case$values)^2 / width) / span)
    for (power in c(-1074, -1073, -1040, -1022, 0, 1000)) {
      scale <- 2^power
      cube <- tiny_spectrum(case$values * scale, case$wavelengths * scale)
      actual <- hsa_spectral_gradient(cube)$data$raw_value
      expect_equal(actual, expected, tolerance = 1e-14,
                   info = paste("joint binary exponent", power))
    }
  }
})

test_that("RMS normalization supports mixed subnormal and normal divisors", {
  coordinates <- c(0, 2^-1074, 4 * .Machine$double.xmin)
  plot <- hsa_spectral_gradient(tiny_spectrum(coordinates, coordinates))
  expect_equal(plot$data$raw_value, 1, tolerance = 1e-14)
  expect_identical(hsa_provenance(plot)$quantity$interval_widths,
                   diff(coordinates))
})

test_that("density uses representable tiny edges and exact boundary counts", {
  m <- 2^-1074
  values <- array((1:5) * m, c(5L, 1L, 1L))
  for (bins in c(2L, 4L)) {
    plot <- hsa_spectral_density(values, limits = c(m, 5 * m), nbins = bins,
                                 transform = "identity")
    record <- hsa_provenance(plot)$enhancement
    expected_edges <- if (bins == 2L) c(1, 3, 5) else 1:5
    expected_counts <- if (bins == 2L) c(3L, 2L) else c(2L, 1L, 1L, 1L)
    expect_identical(record$breaks, expected_edges * m)
    expect_identical(record$H[, 1L], expected_counts)
    expect_identical(record$overlay$mean, 3 * m)
    expect_equal(record$kept, 5)
    expect_equal(sum(plot$data$share), 1)
  }
})

test_that("density tiny coordinate midpoints round after interpolation", {
  m <- 2^-1074
  values <- array(rep(1:5, 3L), c(5L, 1L, 3L))
  attr(values, "wavelengths") <- c(1, 2, 5) * m
  plot <- hsa_spectral_density(values, limits = c(1, 5), nbins = 2)
  cells <- unique(plot$data[c("band", "xmin", "xmax")])
  expect_identical(cells$xmin, c(0, 2, 4) * m)
  expect_identical(cells$xmax, c(2, 4, 6) * m)
})

test_that("density reference quantiles and limits retain tiny values", {
  m <- 2^-1074
  plot <- hsa_spectral_density(
    array(c(m, 5 * m), c(2L, 1L, 1L)), nbins = 4,
    probs = c(.25, .5), show_limits = TRUE
  )
  record <- hsa_provenance(plot)$enhancement
  expect_identical(record$range, c(1, 5) * m)
  expect_identical(record$global_references$values, c(2, 3) * m)
  expect_identical(record$H[, 1L], c(1L, 0L, 0L, 1L))
})

test_that("spectral quartiles round tiny type-7 interpolants only once", {
  m <- 2^-1074
  cases <- list(
    list(values = c(1, 5), quartiles = c(2, 3, 4)),
    list(values = c(-5, 3), quartiles = c(-3, -1, 1)),
    list(values = c(-7, -2, 3, 11), quartiles = c(-3, 0, 5))
  )
  for (case in cases) {
    plot <- hsa_spectral_quartiles(tiny_spectrum(case$values * m))
    expect_identical(plot$data$raw_value, case$quartiles * m)
    expect_identical(hsa_provenance(plot)$quantity$quantile_type, 7L)
  }
  mixed <- hsa_spectral_quartiles(tiny_spectrum(c(m, 5 * m, 9 * m, 1)))
  expect_identical(mixed$data$raw_value[1L], 4 * m)
})
