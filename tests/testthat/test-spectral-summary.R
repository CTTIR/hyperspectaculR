spectral_fixture <- function(x, wl = seq_along(x)) {
  structure(list(data = array(x, c(1L, 1L, length(x))), wavelengths = wl), class = "hsi_cube")
}

physical_flux <- function(cube, ...) {
  hsa_spectral_flux(cube, normalization = "wavelength_span", ...)
}

test_that("physical summaries match independent exact fixtures", {
  cases <- list(
    list(c(1, 3, 11), c(500, 501, 505), 2, 2),
    list(c(0, 2, 2), c(500, 501, 505), .4, sqrt(.8)),
    list(c(0, 2, 2, 2), c(500, 501, 503, 505), .4, sqrt(.8)),
    list(c(7, 7, 7), c(500, 501, 505), 0, 0),
    list(c(0, 1, 0), c(500, 550, 600), .02, .02),
    list(c(0, 0), c(500, 600), 0, 0)
  )
  for (case in cases) {
    cube <- spectral_fixture(case[[1]], case[[2]])
    expect_equal(physical_flux(cube)$data$raw_value, case[[3]], tolerance = 1e-12)
    expect_equal(hsa_spectral_gradient(cube)$data$raw_value, case[[4]], tolerance = 1e-12)
  }
  ramp <- spectral_fixture(c(1, 3, 11), c(500, 501, 505))
  expect_equal(hsa_spectral_flux(ramp, normalization = "total")$data$raw_value, 10)
  expect_equal(hsa_spectral_flux(ramp, normalization = "mean_step")$data$raw_value, 5)
  expect_equal(hsa_spectral_flux(ramp)$data$raw_value, 5)
  expect_equal(hsa_spectral_flux(ramp, normalise = FALSE)$data$raw_value, 10)
  for (fun in list(physical_flux, hsa_spectral_gradient)) {
    base <- fun(ramp)$data$raw_value
    expect_equal(fun(spectral_fixture(c(-1, -3, -11), ramp$wavelengths))$data$raw_value, base, tolerance = 1e-12)
    expect_equal(fun(spectral_fixture(c(6, 8, 16), ramp$wavelengths))$data$raw_value, base, tolerance = 1e-12)
    expect_equal(fun(spectral_fixture(c(3, 9, 33), ramp$wavelengths))$data$raw_value, 3 * base, tolerance = 1e-12)
    expect_equal(fun(spectral_fixture(c(1, 3, 11), 4 * ramp$wavelengths))$data$raw_value, base / 4, tolerance = 1e-12)
  }
})

test_that("normalization is explicit and physical requests reject index coordinates", {
  cube <- spectral_fixture(c(1, 3), c(500, 502))
  expect_error(hsa_spectral_flux(cube, normalise = TRUE, normalization = "total"), "conflict")
  expect_error(hsa_spectral_flux(cube, normalise = FALSE, normalization = "mean_step"), "conflict")
  expect_error(hsa_spectral_flux(cube, normalise = TRUE, normalization = "wavelength_span"), "conflict")
  expect_equal(hsa_spectral_flux(cube, normalise = FALSE, normalization = "total")$data$raw_value, 2)
  expect_equal(hsa_spectral_flux(cube, normalise = TRUE, normalization = "mean_step")$data$raw_value, 2)
  expect_error(hsa_spectral_flux(cube, normalization = "nonsense"), "arg")
  index <- cube$data
  expect_error(physical_flux(index), "wavelength metadata")
  expect_error(hsa_spectral_gradient(index), "wavelength metadata")
  expect_error(hsa_mandala(index, sampling = "wavelength"), "wavelength metadata")
  singleton <- spectral_fixture(4)
  expect_error(physical_flux(singleton), "at least 2 bands")
  expect_error(hsa_spectral_gradient(singleton), "at least 2 bands")
  expect_identical(tail(names(formals(hsa_spectral_flux)), 1L), "normalization")
  expect_identical(tail(names(formals(hsa_mandala)), 1L), "sampling")
})

test_that("scaled arithmetic retains representable extreme physical quantities", {
  integer_cube <- spectral_fixture(c(-2000000000L, 2000000000L), c(0, 2))
  expect_equal(physical_flux(integer_cube)$data$raw_value, 2e9)
  expect_equal(hsa_spectral_gradient(integer_cube)$data$raw_value, 2e9)
  expect_equal(hsa_spectral_flux(integer_cube, normalization = "total")$data$raw_value, 4e9)
  largest <- .Machine$double.xmax
  for (fun in list(physical_flux, hsa_spectral_gradient)) {
    plot <- fun(spectral_fixture(c(-largest, largest), c(0, 2)))
    expect_equal(plot$data$raw_value / largest, 1, tolerance = 1e-14)
    expect_equal(fun(spectral_fixture(c(0, 1e-300), c(0, 1e-300)))$data$raw_value, 1, tolerance = 1e-14)
    expect_equal(fun(spectral_fixture(c(0, 1e300), c(0, 1e300)))$data$raw_value, 1, tolerance = 1e-14)
    close <- c(1e300, 1e300 + 1e285)
    expected <- (close[2] - close[1]) / 1e-10
    expect_equal(fun(spectral_fixture(close, c(0, 1e-10)))$data$raw_value / expected, 1, tolerance = 1e-14)
    expect_error(fun(spectral_fixture(c(-largest, largest), c(0, 1))), "not representable")
    expect_error(fun(spectral_fixture(c(0, 1), c(-largest, largest))), "span.*representable")
    expect_error(fun(spectral_fixture(c(0, 1), c(0, 1e-320))), "not representable")
  }
  underflow <- spectral_fixture(c(0, 1, 1), c(0, 1e-300, 1e300))
  expect_equal(hsa_spectral_gradient(underflow)$data$raw_value, 1, tolerance = 1e-14)
  expect_equal(physical_flux(underflow)$data$raw_value / 1e-300, 1, tolerance = 1e-14)
  expect_error(hsa_spectral_flux(spectral_fixture(c(-largest, largest)), normalization = "total"), "not representable")
  mean <- hsa_spectral_flux(spectral_fixture(c(-largest, 0, largest)), normalization = "mean_step")
  expect_equal(mean$data$raw_value / largest, 1, tolerance = 1e-14)
  expect_error(hsa_spectral_flux(spectral_fixture(c(-largest, 0, largest)), normalization = "total"), "not representable")
})

test_that("normalized aggregates round only after subnormal contributions combine", {
  m <- 2^-1074
  cube <- spectral_fixture(c(0, m, 0, m, 0), 0:4)
  for (fun in list(hsa_spectral_flux, physical_flux, hsa_spectral_gradient)) {
    actual <- fun(cube)$data$raw_value
    expect_gt(actual, 0)
    expect_identical(actual, m)
  }
  expect_identical(hsa_spectral_flux(cube, normalization = "total")$data$raw_value, 4 * m)
  # Zero intervals at either end cannot erase the exponent of tiny terms.
  with_zeros <- spectral_fixture(c(0, 0, m, 0, m, m), 0:5)
  for (fun in list(hsa_spectral_flux, physical_flux, hsa_spectral_gradient)) {
    expect_identical(fun(with_zeros)$data$raw_value, m)
  }
  near_max <- spectral_fixture(c(0, .Machine$double.xmax, 0), 0:2)
  for (fun in list(hsa_spectral_flux, physical_flux, hsa_spectral_gradient)) {
    expect_equal(fun(near_max)$data$raw_value / .Machine$double.xmax, 1, tolerance = 1e-14)
  }
})

test_that("wavelength-target mandalas retain selection and ring geometry", {
  cube <- spectral_fixture(1:4, c(500, 510, 550, 600))
  p <- hsa_mandala(cube, n_rings = 5, sampling = "wavelength")
  s <- hsa_provenance(p)$selection
  expect_identical(s$ring_band_indices, c(1L, 2L, 3L, 3L, 4L))
  expect_equal(s$requested_targets, c(500, 525, 550, 575, 600))
  expect_equal(s$target_errors, c(0, -15, 0, -25, 0))
  expect_identical(s$ring_pixel_counts, c(1L, 0L, 0L, 0L, 0L))
  expect_identical(s$empty_rings, 2:5)
  expect_identical(s$repeated_rings, 4L)
  expect_match(p$labels$caption, "Spatial composition")
  expect_match(p$labels$caption, "1 repeated selections; 4 empty rings")
  cube$wavelengths <- c(500, 501, 502, 600)
  s <- hsa_provenance(hsa_mandala(cube, n_rings = 3, sampling = "wavelength"))$selection
  expect_equal(s$ring_coordinates, c(500, 502, 600))
  expect_equal(s$target_errors, c(0, -48, 0))
  for (sampling in c("index", "wavelength")) {
    s <- hsa_provenance(hsa_mandala(cube, n_rings = 1, sampling = sampling))$selection
    expect_identical(s$ring_band_indices, 1L)
    expect_equal(sum(s$ring_pixel_counts), 1)
  }
  cube$data <- array(rep(1:4, each = 6), c(2, 3, 4))
  s <- hsa_provenance(hsa_mandala(cube, n_rings = 12, sampling = "wavelength"))$selection
  expect_length(s$ring_pixel_counts, 12)
  expect_equal(sum(s$ring_pixel_counts), 6)
  expect_identical(s$ring_band_indices[c(1, 12)], c(1L, 4L))
  cube$data <- array(c(1, NA, NA, NA), c(1, 1, 4))
  expect_equal(hsa_mandala(cube, n_rings = 1, sampling = "wavelength")$data$raw_value, 1)
})

test_that("quartiles use equal-band type-7 definitions including a singleton", {
  cases <- list(
    list(c(0, 1, 4, 9), c(.75, 2.5, 5.25)),
    list(c(0, 4), c(1, 2, 3)), list(4, c(4, 4, 4)),
    list(c(0, .5, 1), c(.25, .5, .75)),
    list(c(0, .01, .02, 1), c(.0075, .015, .265)),
    list(c(-.Machine$double.xmax, .Machine$double.xmax),
         c(-.Machine$double.xmax / 2, 0, .Machine$double.xmax / 2))
  )
  for (case in cases) {
    p <- hsa_spectral_quartiles(spectral_fixture(case[[1]]))
    expect_equal(p$data$raw_value, case[[2]], tolerance = 1e-12)
    expect_identical(levels(p$data$panel), c("25th percentile", "Median", "75th percentile"))
  }
  p <- hsa_spectral_quartiles(spectral_fixture(4))
  expect_match(p$labels$caption, "One measured band")
  expect_equal(hsa_spectral_quartiles(spectral_fixture(c(9, 0, 4, 1)))$data$raw_value,
               c(.75, 2.5, 5.25), tolerance = 1e-12)
  expect_equal(hsa_spectral_flux(spectral_fixture(c(9, 0, 4, 1)), normalization = "total")$data$raw_value, 16)
})

test_that("full-spectrum validity is common and masked values cannot affect summaries", {
  for (invalid in c(NA_real_, NaN, Inf, -Inf)) {
    cube <- structure(list(data = array(c(0, 0, 1, invalid, 4, 4), c(1, 2, 3)),
                           wavelengths = c(500, 501, 505)), class = "hsi_cube")
    for (fun in list(physical_flux, hsa_spectral_gradient, hsa_spectral_quartiles)) {
      p <- fun(cube)
      expect_true(all(is.na(p$data$raw_value[p$data$x == 2])))
      expect_true(all(is.finite(p$data$raw_value[p$data$x == 1])))
      expect_equal(hsa_provenance(p)$missingness$valid_pixels, 1)
      expect_true(all(ggplot2::ggplot_build(p)$data[[1]]$fill[p$data$x == 2] == "transparent"))
    }
  }
  cube$mask <- matrix(c(TRUE, FALSE), 1, 2)
  for (fun in list(physical_flux, hsa_spectral_gradient, hsa_spectral_quartiles)) {
    before <- fun(cube)
    cube$data[1, 2, ] <- c(-.Machine$double.xmax, .Machine$double.xmax, 0)
    after <- fun(cube)
    expect_equal(after$data, before$data)
    expect_identical(hsa_provenance(after)$enhancement, hsa_provenance(before)$enhancement)
  }
  # A later missing band excludes the whole spectrum before arithmetic.
  cube$mask <- NULL
  cube$data[1, 2, ] <- c(-.Machine$double.xmax, .Machine$double.xmax, NA)
  expect_no_error(physical_flux(cube))
  expect_no_error(hsa_spectral_gradient(cube))
})

test_that("quartile facets have one pooled enhancement and a truthful visible legend", {
  cube <- structure(list(data = array(c(0, 1, 0, 1, 4, 1, 4, 1), c(1, 2, 4))), class = "hsi_cube")
  p <- hsa_spectral_quartiles(cube, stretch = "range", interpolate = FALSE)
  expect_equal(p$data$raw_value, c(0, 1, 2, 1, 4, 1))
  expect_equal(p$data$value, c(0, .25, .5, .25, 1, .25))
  expect_identical(p$theme$legend.position, "right")
  expect_identical(p$scales$get_scales("fill")$name, "display value (0-1)")
  expect_equal(p$scales$get_scales("fill")$limits, c(0, 1))
  built <- ggplot2::ggplot_build(p)$data[[1]]
  expect_length(unique(built$fill[p$data$raw_value == 1]), 1)
  expect_true(all(apply(matrix(p$data$value, 2, 3), 1, function(x) all(diff(x) >= 0))))
  provenance <- hsa_provenance(p)
  expect_equal(provenance$enhancement$shared_limits, c(0, 4))
  expect_equal(provenance$quantity$probabilities, c(.25, .5, .75))
  expect_identical(provenance$quantity$quantile_type, 7L)
  expect_true(provenance$missingness$shared_panel_validity)
  raw <- hsa_spectral_quartiles(cube, stretch = "none", display_limits = c(0, 4), value_label = "radiance")
  expect_identical(raw$scales$get_scales("fill")$name, "radiance")
  expect_equal(raw$scales$get_scales("fill")$limits, c(0, 4))
  expect_equal(raw$data$value, raw$data$raw_value)
  pooled <- hsa_spectral_quartiles(cube, probs = c(.25, .75))
  expect_equal(hsa_provenance(pooled)$enhancement$limits, c(1, 1.75))
})

test_that("new original-rendering records and compact rendering scopes survive additions", {
  cube <- hsa_demo_cube(rows = 2, cols = 3, bands = 4)
  plots <- list(hsa_spectral_gradient(cube), hsa_spectral_quartiles(cube),
                physical_flux(cube), hsa_mandala(cube, sampling = "wavelength"))
  for (p in plots) {
    expect_identical(hsa_provenance(p + ggplot2::labs(title = "changed") +
                                     ggplot2::theme(plot.margin = ggplot2::margin(0))), hsa_provenance(p))
    expect_compact_render_environments(p)
    expect_no_warning(ggplot2::ggplot_build(p))
  }
  expect_identical(plots[[1]]$labels$title, "RMS spectral slope")
  expect_identical(hsa_provenance(plots[[1]])$quantity$units, "input value per nm")
  expect_match(plots[[1]]$labels$caption, "short intervals and noise")
  expect_identical(hsa_provenance(plots[[3]])$quantity$normalization, "wavelength_span")
  expect_identical(hsa_provenance(plots[[3]])$quantity$denominator, 15)
  expect_match(plots[[3]]$labels$caption, "V/L")
})
