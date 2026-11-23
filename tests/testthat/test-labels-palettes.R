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
  expect_identical(width(c(64L, 16L)), 40L)
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
