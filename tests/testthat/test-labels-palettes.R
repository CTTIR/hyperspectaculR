test_that("palette requests are resolved before calculation and recorded truthfully", {
  cube <- hsa_demo_cube(rows = 4, cols = 5, bands = 6)
  renderers <- list(hsa_mandala, hsa_spectral_flux, hsa_spectral_density,
                    hsa_spectral_gradient, hsa_spectral_quartiles)
  for (renderer in renderers) {
    error <- expect_error(renderer(cube, palette = "nope"), "palette")
    expect_match(conditionMessage(error), "magma")
    expect_s3_class(error, "rlang_error")
    expect_error(renderer(cube, palette = c("magma", "viridis")), "palette")
    expect_error(renderer(cube, palette = 1), "palette")
    expect_error(renderer(cube, palette = NA_character_), "palette")
    # "m" matches both magma and mako.
    expect_error(renderer(cube, palette = "m"), "palette")
    expect_identical(hsa_provenance(renderer(cube, palette = "mag"))$palette,
                     "magma")
    expect_identical(hsa_provenance(renderer(cube, palette = NULL))$palette,
                     "viridis")
  }
  # The request is rejected before the cube is validated as displayable.
  empty <- array(NA_real_, c(2, 2, 3))
  expect_error(hsa_mandala(empty, palette = "nope"), "palette")

  expect_identical(hsa_palette(n = 3L), hsa_palette("viridis", n = 3L))
  expect_identical(hsa_palette("mag", n = 3L), hsa_palette("magma", n = 3L))
  expect_error(hsa_palette("nope"), "name")
  expect_error(hsa_palette(c("magma", "mako")), "name")
  expect_error(hsa_palette(3), "name")

  warnings <- character()
  withCallingHandlers(
    ggplot2::ggplot_build(hsa_mandala(cube, palette = "turbo")),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("greyscale", warnings), 1L)
})

test_that("validation errors name the user's function and arguments", {
  called <- function(error) as.character(conditionCall(error)[[1L]])
  cube <- hsa_demo_cube(rows = 4, cols = 5, bands = 6)
  empty <- array(NA_real_, c(2, 2, 3))

  error <- expect_error(hsa_mandala(empty), "no finite values")
  expect_identical(called(error), "hsa_mandala")
  expect_no_match(conditionMessage(error), "`x`", fixed = TRUE)
  error <- expect_error(hsa_spectral_quartiles(empty), "no finite values")
  expect_identical(called(error), "hsa_spectral_quartiles")

  error <- expect_error(
    hsa_spectral_flux(cube, stretch = "none", display_limits = c(5, 6)),
    "display_limits"
  )
  expect_identical(called(error), "hsa_spectral_flux")
  expect_match(conditionMessage(error), "`stretch`", fixed = TRUE)
  expect_no_match(conditionMessage(error), "`method`", fixed = TRUE)
  expect_match(conditionMessage(error), "span")

  error <- expect_error(hsa_fusion(cube, red = 1.5, green = 2, blue = 3), "whole")
  expect_identical(called(error), "hsa_fusion")
  error <- expect_error(
    hsa_fusion(cube, red = 1, green = 2, blue = 3, stretch = "none",
               display_limits = c(5, 6)),
    "display_limits"
  )
  expect_identical(called(error), "hsa_fusion")

  error <- expect_error(hsa_spectral_gradient(cube$data), "wavelength metadata")
  expect_identical(called(error), "hsa_spectral_gradient")
  error <- expect_error(
    hsa_spectral_flux(cube$data, normalization = "wavelength_span"),
    "wavelength metadata"
  )
  expect_identical(called(error), "hsa_spectral_flux")
})

test_that("image labels are wrapped to the width of the panel", {
  width <- hyperspectaculR:::.label_width
  expect_identical(width(c(48L, 64L)), 74L)
  expect_identical(width(c(48L, 64L, 24L)), 74L)
  expect_identical(width(c(64L, 64L)), 56L)
  expect_identical(width(c(64L, 16L)), 36L)
  expect_identical(width(c(64L, 16L), scale = 0.5), 18L)
  expect_identical(width(c(16L, 640L)), 110L)
  expect_lt(width(c(48L, 64L), scale = 0.83), width(c(48L, 64L)))

  longest <- function(label) max(nchar(strsplit(label, "\n", fixed = TRUE)[[1L]]))
  for (dimensions in list(c(48L, 64L), c(40L, 40L), c(60L, 30L))) {
    cube <- hsa_demo_cube(rows = dimensions[1L], cols = dimensions[2L])
    limit <- width(dimensions)
    plots <- list(
      hsa_mandala(cube, n_rings = 12),
      hsa_mandala(cube, n_rings = 12, sampling = "wavelength"),
      hsa_spectral_flux(cube, normalization = "wavelength_span"),
      hsa_fusion(cube),
      hsa_spectral_gradient(cube)
    )
    for (plot in plots) {
      expect_lte(longest(plot$labels$caption), limit)
    }
    expect_lte(longest(plots[[2L]]$labels$subtitle),
               width(dimensions, scale = 0.83))
    selected <- seq.int(1L, 23L, by = 2L)
    long <- hsa_fusion(cube, red = selected, green = 1:3, blue = 4:6)
    expect_lte(longest(long$labels$subtitle), width(dimensions, scale = 0.83))
  }
})

test_that("density axis titles and quartile strips keep clear of the panels", {
  cube <- hsa_demo_cube(rows = 4, cols = 5, bands = 6)
  density <- hsa_spectral_density(cube, nbins = 8)
  expect_equal(density$theme$axis.title.y$angle, 90)
  expect_gt(as.numeric(density$theme$axis.title.x$margin[1L]), 0)
  quartiles <- hsa_spectral_quartiles(cube)
  expect_gt(as.numeric(quartiles$theme$strip.text$margin[3L]), 0)
  expect_warning(ggplot2::ggplotGrob(density), NA)
  expect_warning(ggplot2::ggplotGrob(quartiles), NA)
})

test_that("row quantiles equal one type-7 quantile call per row", {
  per_row <- function(values, probs) {
    out <- matrix(NA_real_, nrow(values), length(probs))
    for (i in seq_len(nrow(values))) {
      out[i, ] <- hyperspectaculR:::.quantile_type7(values[i, ], probs)
    }
    out
  }
  row_quantiles <- hyperspectaculR:::.row_quantiles_type7
  withr::local_seed(20261123)
  tiny <- c(0, 4.9e-324, 1e-320, -3e-315, 2e-310, .Machine$double.xmin)
  cases <- list(
    ordinary = matrix(stats::rnorm(600), 100, 6),
    tied = matrix(sample(c(0, 1, 2), 500, replace = TRUE), 100, 5),
    single_band = matrix(stats::rnorm(20), 20, 1),
    two_bands = matrix(stats::rnorm(40), 20, 2),
    subnormal = matrix(sample(tiny, 500, replace = TRUE), 100, 5),
    mixed = matrix(sample(c(tiny, 1, -1), 400, replace = TRUE), 100, 4),
    extreme = matrix(sample(c(-1, 1) * .Machine$double.xmax, 400, replace = TRUE),
                     100, 4)
  )
  for (values in cases) {
    for (probs in list(c(.25, .5, .75), c(0, 1), .5)) {
      expected <- per_row(values, probs)
      expect_identical(row_quantiles(values, probs), expected)
      # Several small blocks give the same result as one block.
      expect_identical(row_quantiles(values, probs, block_cells = 7), expected)
    }
  }
  expect_identical(dim(row_quantiles(matrix(numeric(), 0, 3), c(.25, .75))),
                   c(0L, 2L))

  cube <- hsa_demo_cube(rows = 5, cols = 6, bands = 7)
  cube$data[2, 3, 4] <- NA_real_
  plot <- hsa_spectral_quartiles(cube)
  expected <- apply(cube$data, c(1, 2), function(spectrum) {
    if (anyNA(spectrum)) return(rep(NA_real_, 3L))
    stats::quantile(spectrum, c(.25, .5, .75), type = 7L, names = FALSE)
  })
  expect_identical(plot$data$raw_value, as.vector(aperm(expected, c(2, 3, 1))))
})
