density_record <- function(plot) {
  hyperspectaculR:::hsa_provenance(plot)$enhancement
}

test_that("density preserves exact raw bin accounting and excludes the mask", {
  fixture <- array(c(-1, 0, .25, .5, .75, 1, 2, NA_real_), c(2, 4, 1))
  plot <- hsa_spectral_density(fixture, limits = c(0, 1), nbins = 2,
                               transform = "identity")
  record <- density_record(plot)

  expect_identical(record$H[, 1], c(3L, 2L))
  expect_type(record$H, "integer")
  expect_equal(record$below, 1)
  expect_equal(record$above, 1)
  expect_equal(record$nonfinite, 1)
  expect_equal(record$kept, 5)
  expect_equal(record$finite, record$below + record$kept + record$above)
  expect_equal(record$eligible, record$finite + record$nonfinite)

  edge <- .Machine$double.eps
  near_edge <- array(c(.5 - edge, .5, .5 + edge), c(3, 1, 1))
  near_record <- density_record(hsa_spectral_density(
    near_edge, limits = c(0, 1), nbins = 2, transform = "identity"
  ))
  expect_equal(near_record$H[, 1], c(2, 1))

  masked <- array(seq_len(12), c(2, 2, 3))
  attr(masked, "mask") <- matrix(c(TRUE, TRUE, TRUE, FALSE), 2, 2)
  changed <- masked
  changed[2, 2, ] <- c(-1e300, Inf, 1e300)
  base <- density_record(hsa_spectral_density(
    masked, limits = c(0, 20), nbins = 4, transform = "identity"
  ))
  perturbed <- density_record(hsa_spectral_density(
    changed, limits = c(0, 20), nbins = 4, transform = "identity"
  ))

  expect_equal(sum(base$H), 9)
  expect_equal(base$H, perturbed$H)
  expect_equal(base$eligible, rep(3, 3))
  expect_equal(base$nonfinite, rep(0, 3))
})

test_that("density validates controls and creates representable automatic ranges", {
  x <- array(1:8, c(2, 2, 2))
  expect_error(hsa_spectral_density(x, nbins = 1), "nbins")
  expect_error(hsa_spectral_density(x, nbins = 2.5), "nbins")
  expect_error(hsa_spectral_density(x, limits = c(1, 1)), "limits")
  expect_error(hsa_spectral_density(x, limits = c(2, 1)), "limits")
  expect_error(hsa_spectral_density(x, limits = c(1, Inf)), "limits")
  expect_error(hsa_spectral_density(
    array(1, c(1, 1, 1)),
    limits = c(1, 1 + .Machine$double.eps), nbins = 2
  ), "Cannot construct")
  expect_error(hsa_spectral_density(x, probs = c(.8, .2)), "probs")
  expect_error(hsa_spectral_density(x, show_limits = NA), "show_limits")
  expect_error(hsa_spectral_density(x, value_label = ""), "value_label")

  for (value in c(0, .25, 1e-300, -1e-300, 1e300, -1e300)) {
    record <- density_record(hsa_spectral_density(
      array(value, c(2, 2, 1)), nbins = 8, transform = "identity"
    ))
    expect_true(all(is.finite(record$breaks)), info = format(value))
    expect_true(all(diff(record$breaks) > 0), info = format(value))
    expect_lte(record$range[1], value)
    expect_gte(record$range[2], value)
    expect_match(record$fallback, "constant", info = format(value))
  }

  sparse <- array(c(rep(0, 1000), 1), c(1, 1001, 1))
  record <- density_record(hsa_spectral_density(
    sparse, nbins = 8, transform = "identity"
  ))
  expect_equal(record$range, c(0, 1))
  expect_match(record$fallback, "collapsed")

  automatic <- density_record(hsa_spectral_density(
    array(0:100, c(101, 1, 1)), nbins = 10, show_limits = TRUE,
    probs = c(.25, .75), transform = "identity"
  ))
  expect_equal(automatic$range, c(.1, 99.9))
  expect_equal(automatic$global_references$values, c(25, 75))
  expect_equal(automatic$global_references$population, 101)

  impossible_coordinates <- array(c(0, 1), c(1, 1, 2))
  attr(impossible_coordinates, "wavelengths") <-
    c(-.Machine$double.xmax, .Machine$double.xmax)
  expect_error(hsa_spectral_density(
    impossible_coordinates, limits = c(0, 1), nbins = 2
  ), "rectangle boundaries")

  empty <- array(NA_real_, c(1, 1, 1))
  expect_error(hsa_spectral_density(empty), "no finite eligible")
  expect_error(hsa_spectral_density(x, limits = c(20, 30)),
               "inside.*limits")
})

test_that("density uses exact wavelength rectangles and original overlay coordinates", {
  x <- array(seq_len(24) / 24, c(2, 2, 6))
  wavelengths <- c(500, 505, 511, 520, 540, 580)
  attr(x, "wavelengths") <- wavelengths
  plot <- hsa_spectral_density(x, limits = c(0, 1), nbins = 4,
                               transform = "identity")
  cells <- unique(plot$data[c("band", "coordinate", "xmin", "xmax")])

  expect_equal(cells$coordinate, wavelengths)
  expect_equal(cells$xmin, c(497.5, 502.5, 508, 515.5, 530, 560))
  expect_equal(cells$xmax, c(502.5, 508, 515.5, 530, 560, 600))
  expect_equal(density_record(plot)$overlay$coordinate, wavelengths)
  expect_false(any(vapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomRaster")
  }, logical(1))))
  expect_warning(ggplot2::ggplot_build(plot), NA)
})

test_that("density overlays do not bridge empty bands or warn for one band", {
  separated <- array(c(.25, 10, .75), c(1, 1, 3))
  plot <- hsa_spectral_density(separated, limits = c(0, 1), nbins = 4,
                               transform = "identity")
  overlay <- density_record(plot)$overlay
  expect_equal(overlay$group, c(1L, NA_integer_, 2L))
  expect_true(is.na(overlay$mean[2]))
  expect_false(any(vapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomLine")
  }, logical(1))))
  expect_warning(ggplot2::ggplot_build(plot), NA)

  one <- hsa_spectral_density(array(.25, c(1, 1, 1)), limits = c(0, 1),
                              nbins = 4, transform = "identity")
  expect_warning(ggplot2::ggplot_build(one), NA)
  expect_match(one$labels$caption, "single-band coordinate width of 1")
  expect_identical(one$labels$x, "band index")
  expect_match(one$labels$subtitle, "band-index coordinates")
})

test_that("raw counts survive normalisation and transformation", {
  x <- array(c(.2, .2, .2, .2), c(2, 2, 1))
  plots <- list(
    none_identity = hsa_spectral_density(x, limits = c(0, 1), nbins = 2,
                                         normalise = "none", transform = "identity"),
    none_log = hsa_spectral_density(x, limits = c(0, 1), nbins = 2,
                                    normalise = "none", transform = "log1p"),
    band_identity = hsa_spectral_density(x, limits = c(0, 1), nbins = 2,
                                         normalise = "band", transform = "identity"),
    band_log = hsa_spectral_density(x, limits = c(0, 1), nbins = 2,
                                    normalise = "band", transform = "log1p")
  )

  for (plot in plots) expect_equal(plot$data$count, c(4, 0))
  expect_equal(plots$band_identity$data$share, c(1, 0))
  expect_equal(plots$band_identity$data$density, c(1, 0))
  expect_equal(plots$band_log$data$density, c(log(2), 0))

  count_scale <- plots$none_log$scales$get_scales("fill")
  share_scale <- plots$band_log$scales$get_scales("fill")
  expect_equal(count_scale$limits, c(0, log(5)))
  expect_equal(share_scale$limits, c(0, log(2)))
  expect_identical(count_scale$labels(log(2)), "1")
  expect_identical(share_scale$labels(log(2)), "100%")
})

test_that("empty density bands have missing shares", {
  x <- array(c(.25, 10, .75), c(1, 1, 3))
  plot <- hsa_spectral_density(x, limits = c(0, 1), nbins = 2,
                               normalise = "band", transform = "identity")
  expect_true(all(is.na(plot$data$share[plot$data$band == 2])))
  expect_true(all(is.na(plot$data$density[plot$data$band == 2])))
  expect_equal(as.vector(tapply(plot$data$count, plot$data$band, sum)), c(1, 0, 1))
})

test_that("global references use independent masked finite quantiles", {
  x <- array(c(0, 1, 2, 100, 3, 4, 5, 200), c(2, 2, 2))
  attr(x, "mask") <- matrix(c(TRUE, TRUE, TRUE, FALSE), 2, 2)
  probs <- c(.25, .75)
  plot <- hsa_spectral_density(x, limits = c(1, 4), nbins = 3,
                               show_limits = TRUE, probs = probs,
                               transform = "identity", value_label = "signal")
  record <- density_record(plot)
  expected <- c(1.25, 3.75)

  expect_equal(record$global_references$values, expected)
  expect_equal(record$global_references$population, 6)
  expect_match(plot$labels$caption, "25-75%")
  expect_match(plot$labels$caption, "including values outside")
  expect_match(plot$labels$caption, "separate from image\\s+enhancement")

  changed <- x
  changed[2, 2, ] <- c(-1e300, 1e300)
  changed_plot <- hsa_spectral_density(changed, limits = c(1, 4), nbins = 3,
                                       show_limits = TRUE, probs = probs,
                                       transform = "identity")
  expect_equal(density_record(changed_plot)$global_references$values, expected)

  outside <- hsa_spectral_density(x, limits = c(1, 4), nbins = 3,
                                  show_limits = TRUE, probs = c(0, 1),
                                  transform = "identity")
  outside_build <- ggplot2::ggplot_build(outside)
  expect_equal(density_record(outside)$global_references$values, c(0, 5))
  expect_lte(outside_build$layout$panel_params[[1]]$y.range[1], 0)
  expect_gte(outside_build$layout$panel_params[[1]]$y.range[2], 5)

  coincident <- hsa_spectral_density(array(1, c(2, 2, 1)), limits = c(0, 2),
                                     nbins = 2, show_limits = TRUE,
                                     transform = "identity")
  expect_length(unique(density_record(coincident)$global_references$values), 1)
  expect_match(coincident$labels$caption, "share one line")
})

test_that("binned overlays describe retained pixels and are compact provenance", {
  x <- array(seq(0, 1, length.out = 101), c(101, 1, 1))
  plot <- hsa_spectral_density(x, limits = c(0, 1), nbins = 10,
                               transform = "identity", value_label = "signal")
  record <- density_record(plot)

  expect_lte(abs(record$overlay$mean - .5), .05 + 1e-12)
  expect_identical(plot$labels$y, "signal")
  expect_match(plot$labels$caption, "retained\\s+pixel\\s+distribution")
  expect_match(plot$labels$caption, "not confidence intervals")
  expect_identical(hyperspectaculR:::hsa_provenance(plot + ggplot2::labs(title = "x")),
                   hyperspectaculR:::hsa_provenance(plot))
  expect_identical(hyperspectaculR:::hsa_provenance(plot + ggplot2::theme_bw()),
                   hyperspectaculR:::hsa_provenance(plot))
  expect_false(any(vapply(hyperspectaculR:::hsa_provenance(plot),
                          identical, logical(1), x)))
  expect_false("finite_population" %in% names(record))
  expect_lte(max(nchar(strsplit(plot$labels$caption, "\n", fixed = TRUE)[[1]])),
             110)

  extreme <- hsa_spectral_density(
    array(c(-1e300, 1e300), c(2, 1, 1)),
    limits = c(-1e300, 1e300), nbins = 2, transform = "identity"
  )
  expect_true(is.finite(density_record(extreme)$overlay$mean))
  expect_equal(density_record(extreme)$overlay$mean, 0, tolerance = 1e-12)
})

test_that("density plots retain only compact rendering environments", {
  source <- array(seq_len(24) / 24, c(2, 4, 3))
  plots <- list(
    fixed = hsa_spectral_density(source, limits = c(0, 1), nbins = 4),
    automatic = hsa_spectral_density(source, nbins = 4),
    references = hsa_spectral_density(
      source, limits = c(0, 1), nbins = 4, show_limits = TRUE
    )
  )
  for (name in names(plots)) {
    expect_compact_render_environments(plots[[name]])
    expect_warning(ggplot2::ggplot_build(plots[[name]]), NA, info = name)
    expect_identical(
      hyperspectaculR:::hsa_provenance(plots[[name]] + ggplot2::labs(title = name)),
      hyperspectaculR:::hsa_provenance(plots[[name]])
    )
  }

  make_plot <- function(size) {
    values <- seq_len(size * size * 3) / (size * size * 3)
    hsa_spectral_density(array(values, c(size, size, 3)), nbins = 8,
                         show_limits = TRUE)
  }
  small_size <- length(serialize(make_plot(10), NULL))
  large_size <- length(serialize(make_plot(100), NULL))
  expect_lt(large_size - small_size, 100000)
})
