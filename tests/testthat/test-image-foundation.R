cube_array <- function(rows = 2L, cols = 2L, bands = 3L) {
  array(seq_len(rows * cols * bands) / 10, c(rows, cols, bands))
}

fusion_fixture <- function() {
  array(c(
    .1, .2, .4, .8,
    .2, .3, .5, .9,
    .3, .6, .2, .1,
    .4, .7, .3, .2,
    .9, .4, .7, .2,
    .8, .3, .6, .1
  ), c(2, 2, 6))
}

test_that("cube validation preserves coordinates, dimensions, and spatial mask", {
  x <- cube_array()
  attr(x, "mask") <- matrix(c(TRUE, TRUE, TRUE, FALSE), 2, 2)
  cb <- hyperspectaculR:::.as_cube(x)

  expect_identical(dim(cb$data), c(2L, 2L, 3L))
  expect_identical(cb$coordinate_kind, "band_index")
  expect_identical(cb$coordinates, 1:3)
  expect_identical(dim(hyperspectaculR:::.cube_band(cb, 1L)), c(2L, 2L))
  expect_true(is.na(hyperspectaculR:::.cube_band(cb, 1L)[2, 2]))
  expect_identical(sum(vapply(1:3, function(b) {
    sum(is.finite(hyperspectaculR:::.cube_band(cb, b)))
  }, integer(1))), 9L)
  expect_identical(hyperspectaculR:::.cube_info(cb)$excluded_spatial, 1L)
})

test_that("cube validation rejects malformed data, wavelengths, and masks", {
  bad_class <- structure(1:3, class = "hsi_cube")
  expect_error(hyperspectaculR:::.as_cube(bad_class), "list")
  expect_error(hyperspectaculR:::.as_cube(array("x", c(1, 1, 1))), "numeric")
  expect_error(hyperspectaculR:::.as_cube(array(numeric(), c(0, 1, 1))), "positive")
  expect_error(hyperspectaculR:::.as_cube(matrix(1:4, 2)), "3-D")

  for (wl in list(1:2, c(1, NA, 3), c(1, 1, 2), c(1, 3, 2), c("1", "2", "3"))) {
    x <- cube_array()
    attr(x, "wavelengths") <- wl
    expect_error(hyperspectaculR:::.as_cube(x), "wavelength")
  }

  for (mask in list(matrix(1, 2, 2), matrix(TRUE, 1, 4),
                    matrix(c(TRUE, TRUE, TRUE, NA), 2, 2))) {
    x <- cube_array()
    attr(x, "mask") <- mask
    expect_error(hyperspectaculR:::.as_cube(x), "mask")
  }
})

test_that("hsi_cube wavelengths are optional and arbitrary metadata is not retained", {
  source <- structure(list(data = cube_array(), metadata = list(secret = 42)),
                      class = "hsi_cube")
  cb <- hyperspectaculR:::.as_cube(source)
  info <- hyperspectaculR:::.cube_info(cb)

  expect_identical(info$dimensions, c(rows = 2L, columns = 2L, bands = 3L))
  expect_identical(info$coordinate_kind, "band_index")
  expect_false("metadata" %in% names(info))
  expect_false(any(vapply(info, identical, logical(1), source)))
})

test_that("band extraction excludes every nonfinite value without mutating input", {
  values <- c(1, NA, NaN, Inf, -Inf, 6, 7, 8)
  x <- array(values, c(2, 2, 2))
  before <- x
  cb <- hyperspectaculR:::.as_cube(x)

  expect_equal(as.vector(hyperspectaculR:::.cube_band(cb, 1L)),
               c(1, NA, NA, NA))
  expect_identical(x, before)
})

test_that("stretch records independent limits, clipping, fallback, and invalidity", {
  x <- matrix(c(0, 1, 2, 3, 100, NA, Inf, -Inf), 2, 4)
  st <- hyperspectaculR:::.stretch(x, "percentile", c(.25, .75))

  expect_identical(dim(st$values), c(2L, 4L))
  expect_equal(st$limits, c(1, 3))
  expect_identical(st$requested_method, "percentile")
  expect_identical(st$effective_method, "percentile")
  expect_null(st$fallback)
  expect_identical(st$quantile_type, 7L)
  expect_identical(st$clipped_below, 1L)
  expect_identical(st$clipped_above, 1L)
  expect_identical(st$finite_count, 5L)
  expect_identical(st$excluded_count, 3L)
  expect_true(all(is.na(st$values[!is.finite(x)])))

  collapsed <- hyperspectaculR:::.stretch(c(0, 0, 0, 1), "percentile", c(.1, .5))
  expect_equal(collapsed$limits, c(0, 1))
  expect_identical(collapsed$effective_method, "range")
  expect_match(collapsed$fallback, "collapsed")
  expect_match(hyperspectaculR:::.stretch_caption(collapsed),
               "collapsed; effective range stretch")

  constant <- hyperspectaculR:::.stretch(matrix(4, 2, 2), "range")
  expect_equal(constant$values, matrix(0, 2, 2))
  expect_equal(constant$limits, c(4, 4))
})

test_that("stretch validates domains and rescales representable extremes", {
  expect_error(hyperspectaculR:::.stretch(c(0, 2), "none"), "display_limits")
  expect_error(hyperspectaculR:::.stretch(NA_real_, "range"), "no finite")
  expect_error(hyperspectaculR:::.stretch(1:3, "range", c(0, 1, 2)), "probs")
  expect_error(hyperspectaculR:::.stretch(1:3, "range", c(.8, .2)), "probs")
  expect_error(hyperspectaculR:::.stretch(1:3, "none", display_limits = c(1, 1)),
               "display_limits")

  extreme <- hyperspectaculR:::.stretch(c(-.Machine$double.xmax, 0, .Machine$double.xmax),
                                        "range")
  expect_equal(extreme$values, c(0, .5, 1), tolerance = 1e-15)
})

test_that("fusion returns the independently calculated six-band channel means", {
  p <- hsa_fusion(fusion_fixture(), red = 5:6, green = 3:4, blue = 1:2,
                  stretch = "none", display_limits = c(0, 1))

  expect_equal(p$data$raw_b, c(.15, .25, .45, .85))
  expect_equal(p$data$raw_g, c(.35, .65, .25, .15))
  expect_equal(p$data$raw_r, c(.85, .35, .65, .15))
  expect_equal(p$data$b, p$data$raw_b)
  expect_true(all(grepl("^#[0-9A-F]{6}$", p$data$hex)))
})

test_that("default fusion groups are index thirds regardless of by", {
  x <- fusion_fixture()
  a <- hsa_fusion(x, by = "index", stretch = "none")
  b <- hsa_fusion(x, by = "wavelength", stretch = "none")

  expect_equal(a$data[c("raw_r", "raw_g", "raw_b")],
               b$data[c("raw_r", "raw_g", "raw_b")])
  expect_equal(a$data$raw_r, c(.85, .35, .65, .15))
})

test_that("fusion validates explicit groups and wavelength selection", {
  x <- fusion_fixture()
  expect_error(hsa_fusion(x, red = 1, green = NULL, blue = 2), "all")
  expect_error(hsa_fusion(x, red = numeric(), green = 2, blue = 3), "red")
  expect_error(hsa_fusion(x, red = c(1, 1), green = 2, blue = 3), "unique")
  expect_error(hsa_fusion(x, red = 1.5, green = 2, blue = 3), "whole")
  expect_error(hsa_fusion(x, red = 7, green = 2, blue = 3), "outside")
  expect_error(hsa_fusion(x, red = 500, green = 510, blue = 520,
                          by = "wavelength"), "wavelength metadata")

  attr(x, "wavelengths") <- seq(500, 550, by = 10)
  expect_error(hsa_fusion(x, red = 499, green = 520, blue = 530,
                          by = "wavelength"), "range")
  expect_error(hsa_fusion(x, red = c(504, 505), green = 520, blue = 530,
                          by = "wavelength"), "same band")

  tied <- hsa_fusion(x, red = 505, green = 525, blue = 545,
                     by = "wavelength", stretch = "none")
  provenance <- hyperspectaculR:::hsa_provenance(tied)
  expect_identical(provenance$selection$red$indices, 1L)
})

test_that("fusion preserves narrow geometry and allows groups to overlap", {
  for (dims in list(c(1, 4, 3), c(4, 1, 3), c(1, 1, 3))) {
    x <- array(seq_len(prod(dims)) / prod(dims), dims)
    p <- hsa_fusion(x, red = 1, green = 1, blue = 1, stretch = "none")
    expect_equal(nrow(p$data), dims[1] * dims[2])
    expect_equal(p$data$raw_r, as.vector(x[, , 1, drop = FALSE]))
  }
})

test_that("fusion missing policy is transparent and uses a common stretch population", {
  x <- array(rep(c(.1, .2, .3, 50), 3), c(2, 2, 3))
  attr(x, "mask") <- matrix(c(TRUE, TRUE, TRUE, FALSE), 2, 2)
  masked <- hsa_fusion(x, red = 1, green = 2, blue = 3, stretch = "range")
  changed <- x
  changed[2, 2, ] <- -1e100
  masked_changed <- hsa_fusion(changed, red = 1, green = 2, blue = 3,
                               stretch = "range")
  expect_true(is.na(masked$data$hex[4]))
  expect_equal(masked$data$r[1:3], c(0, .5, 1))
  expect_equal(masked$data, masked_changed$data)

  y <- fusion_fixture()
  y[1, 1, 1] <- NA_real_
  strict <- hsa_fusion(y, red = 5:6, green = 3:4, blue = 1:2,
                       stretch = "none", missing = "propagate")
  available <- hsa_fusion(y, red = 5:6, green = 3:4, blue = 1:2,
                          stretch = "none", missing = "available")
  expect_true(is.na(strict$data$hex[1]))
  expect_false(is.na(available$data$hex[1]))
  expect_equal(available$data$raw_b[1], .2)

  z <- fusion_fixture()
  z[1, 1, 1] <- Inf
  z[1, 1, 5] <- NA_real_
  common <- hsa_fusion(z, red = 5:6, green = 3:4, blue = 1:2,
                       stretch = "range", missing = "propagate")
  expect_true(is.na(common$data$hex[1]))
  expect_equal(hyperspectaculR:::hsa_provenance(common)$enhancement$red$limits,
               c(.15, .65))
})

test_that("selected nonfinite bands propagate while unselected bands do not", {
  for (bad in list(NA_real_, NaN, Inf, -Inf)) {
    selected <- fusion_fixture()
    selected[1, 1, 1] <- bad
    p_selected <- hsa_fusion(selected, red = 5:6, green = 3:4, blue = 1:2,
                             stretch = "none")
    expect_true(is.na(p_selected$data$hex[1]))

    unselected <- fusion_fixture()
    unselected[1, 1, 2] <- bad
    p_unselected <- hsa_fusion(unselected, red = 5:6, green = 3:4, blue = 1,
                               stretch = "none")
    expect_false(is.na(p_unselected$data$hex[1]))
  }
})

test_that("mandala geometry and selected-band metadata are explicit", {
  odd <- array(rep(1:3, each = 25), c(5, 5, 3))
  p <- hsa_mandala(odd, n_rings = 3, stretch = "none", display_limits = c(1, 3))
  centre <- p$data[p$data$x == 3 & p$data$y == 3, ]
  expect_equal(centre$raw_value, 1)

  even <- hsa_mandala(array(rep(1:4, each = 24), c(4, 6, 4)), n_rings = 4,
                       stretch = "none", display_limits = c(1, 4))
  expect_identical(nrow(even$data), 24L)

  pixel <- hsa_mandala(array(2, c(1, 1, 1)), centre = c(1e300, -1e300),
                        n_rings = 1, stretch = "none", display_limits = c(0, 2))
  expect_equal(pixel$data$raw_value, 2)
  prov <- hyperspectaculR:::hsa_provenance(p)
  expect_identical(prov$selection$ring_band_indices, 1:3)
  expect_identical(prov$cube$coordinate_kind, "band_index")
})

test_that("mandala rejects invalid arguments and invalid selected output", {
  x <- cube_array()
  expect_error(hsa_mandala(x, n_rings = 0), "n_rings")
  expect_error(hsa_mandala(x, n_rings = 1.5), "n_rings")
  expect_error(hsa_mandala(x, centre = c(1, Inf)), "centre")
  x[] <- NA_real_
  expect_error(hsa_mandala(x), "no finite")
})

test_that("spectral flux uses total or mean absolute consecutive steps", {
  x <- array(c(0, 1, 2, 3), c(1, 1, 4))
  total <- hsa_spectral_flux(x, normalise = FALSE, stretch = "none",
                             display_limits = c(0, 6))
  mean <- hsa_spectral_flux(x, normalise = TRUE, stretch = "none",
                            display_limits = c(0, 6))
  expect_equal(total$data$raw_value, 3)
  expect_equal(mean$data$raw_value, 1)

  y <- array(c(0, 3, 1, 2), c(1, 1, 4))
  expect_equal(hsa_spectral_flux(y, normalise = FALSE, stretch = "none",
                                 display_limits = c(0, 6))$data$raw_value, 6)
  expect_equal(hsa_spectral_flux(y, normalise = TRUE, stretch = "none",
                                 display_limits = c(0, 6))$data$raw_value, 2)
  expect_match(total$labels$subtitle, "total absolute band step")
  expect_match(mean$labels$subtitle, "mean absolute band step")
})

test_that("flux propagates required invalidity and flat zero uses palette low colour", {
  x <- array(c(0, 0, 0, 0, 1, NA, 1, 1), c(2, 2, 2))
  p <- hsa_spectral_flux(x, stretch = "range")
  expect_true(is.na(p$data$value[2]))

  flat <- hsa_spectral_flux(array(1, c(2, 2, 2)), stretch = "range",
                            palette = "magma")
  built <- ggplot2::ggplot_build(flat)$data[[1]]
  expect_true(all(toupper(built$fill) == toupper(substr(hsa_palette("magma", 256)[1], 1, 7))))
})

test_that("fixed scalar display domains give the same raw value the same fill", {
  a <- array(c(0, 0, 0, 0, 1, 2), c(1, 3, 2))
  b <- array(c(0, 0, 0, 1, 2, 3), c(1, 3, 2))
  pa <- hsa_spectral_flux(a, normalise = FALSE, stretch = "none",
                          display_limits = c(0, 3), palette = "viridis")
  pb <- hsa_spectral_flux(b, normalise = FALSE, stretch = "none",
                          display_limits = c(0, 3), palette = "viridis")
  fa <- ggplot2::ggplot_build(pa)$data[[1]]$fill[pa$data$raw_value == 1]
  fb <- ggplot2::ggplot_build(pb)$data[[1]]$fill[pb$data$raw_value == 1]
  expect_identical(fa, fb)
})

test_that("scalar renderers map extreme finite display domains without overflow", {
  maximum <- .Machine$double.xmax
  mandala <- hsa_mandala(
    array(c(-maximum, 0, maximum), c(1, 3, 1)),
    n_rings = 1, palette = "magma", stretch = "none",
    display_limits = c(-maximum, maximum)
  )
  mandala_fill <- ggplot2::ggplot_build(mandala)$data[[1]]$fill
  expect_equal(mandala$scales$get_scales("fill")$limits,
               c(-maximum, maximum))
  expect_false(any(mandala_fill == "transparent"))
  expect_length(unique(mandala_fill), 3L)
  expect_identical(toupper(mandala_fill[1]),
                   toupper(substr(hsa_palette("magma")[1], 1, 7)))
  expect_identical(toupper(mandala_fill[3]),
                   toupper(substr(hsa_palette("magma")[256], 1, 7)))

  flux <- hsa_spectral_flux(
    array(c(0, 0, 0, maximum), c(1, 2, 2)),
    normalise = FALSE, palette = "magma", stretch = "none",
    display_limits = c(-maximum, maximum)
  )
  flux_fill <- ggplot2::ggplot_build(flux)$data[[1]]$fill
  expect_equal(flux$scales$get_scales("fill")$limits,
               c(-maximum, maximum))
  expect_false(any(flux_fill == "transparent"))
  expect_length(unique(flux_fill), 2L)
  expect_identical(toupper(flux_fill[2]),
                   toupper(substr(hsa_palette("magma")[256], 1, 7)))
})

test_that("fractional percentile captions preserve the applied probabilities", {
  ordinary <- hyperspectaculR:::.stretch(0:100, "percentile", c(.001, .999))
  expect_match(hyperspectaculR:::.stretch_caption(ordinary), "0.1-99.9%")
  expect_false(grepl("0-100%", hyperspectaculR:::.stretch_caption(ordinary),
                     fixed = TRUE))

  fallback <- hyperspectaculR:::.stretch(c(0, 0, 0, 1), "percentile",
                                         c(.001, .5))
  expect_match(hyperspectaculR:::.stretch_caption(fallback), "0.1-50%")
  expect_match(hyperspectaculR:::.stretch_caption(fallback),
               "effective range stretch")
})

test_that("image provenance is compact, complete, and survives ggplot additions", {
  input <- fusion_fixture()
  before <- input
  p <- hsa_fusion(input, red = 5:6, green = 3:4, blue = 1:2,
                  stretch = "percentile", probs = c(.25, .75),
                  value_label = "signal", interpolate = FALSE)
  record <- hyperspectaculR:::hsa_provenance(p)

  expect_identical(record$schema_version, "1.0")
  expect_true(is.character(record$package_version))
  expect_identical(record$value_label, "signal")
  expect_identical(record$interpolation, FALSE)
  expect_length(record$enhancement, 3L)
  expect_true(all(vapply(record$enhancement, function(x) length(x$limits) == 2L,
                         logical(1))))
  expect_identical(input, before)
  expect_false(any(vapply(record, identical, logical(1), fusion_fixture())))
  expect_identical(hyperspectaculR:::hsa_provenance(p + ggplot2::labs(title = "changed")),
                   record)
  expect_identical(hyperspectaculR:::hsa_provenance(p + ggplot2::theme_bw()), record)
  expect_error(hyperspectaculR:::hsa_provenance(ggplot2::ggplot()), "provenance")

  if (requireNamespace("patchwork", quietly = TRUE)) {
    expect_error(hyperspectaculR:::hsa_provenance(p + p), "component")
  }
})

test_that("demo arguments and palette controls are strict and RNG absence is preserved", {
  invalid <- list(
    list(rows = 0),
    list(cols = 1.5),
    list(bands = NA),
    list(seed = Inf),
    list(seed = c(1, 2))
  )
  for (arg in invalid) {
    expect_error(do.call(hsa_demo_cube, arg), names(arg))
  }
  expect_error(hsa_palette("magma", n = 0), "n")
  expect_error(hsa_palette("magma", n = 2.5), "n")
  expect_error(hsa_palette("magma", direction = 0), "direction")

  seed_existed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (seed_existed) old_seed <- get(".Random.seed", envir = globalenv())
  on.exit({
    if (seed_existed) assign(".Random.seed", old_seed, envir = globalenv())
  }, add = TRUE)
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  invisible(hsa_demo_cube(rows = 1, cols = 1, bands = 1))
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})
