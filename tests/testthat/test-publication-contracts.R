test_that("band extraction preserves singleton geometry and numeric values", {
  for (dimensions in list(c(1L, 1L, 2L), c(1L, 3L, 2L), c(3L, 1L, 2L))) {
    for (storage in c("integer", "double")) {
      x <- array(seq_len(prod(dimensions)), dimensions)
      storage.mode(x) <- storage
      before <- x
      band <- hyperspectaculR:::.cube_band(hyperspectaculR:::.as_cube(x), 2L)
      expect_identical(dim(band), dimensions[1:2])
      expect_equal(as.vector(band), as.vector(x[, , 2L]))
      expect_identical(x, before)
    }
  }
})

test_that("selection labels stay bounded without concealing actual selections", {
  cube <- hsa_demo_cube(rows = 8, cols = 9, bands = 120)
  default <- hsa_fusion(cube)
  expect_match(default$labels$subtitle, "81-120 \\(40 bands\\)")
  expect_length(strsplit(default$labels$subtitle, "\n")[[1L]], 3L)
  selected <- seq.int(1L, 119L, by = 2L)
  custom <- hsa_fusion(cube, red = selected, green = 1:3, blue = 4:6)
  expect_match(custom$labels$subtitle, "60 selected within 1-119; indices in provenance")
  expect_identical(hsa_provenance(custom)$selection$red$indices, selected)
  expect_lte(max(nchar(strsplit(custom$labels$subtitle, "\n")[[1L]])), 85L)
  expect_identical(hyperspectaculR:::.compact_band_label(c(5L, 1L)), "1,5")
  expect_identical(hyperspectaculR:::.compact_band_label(5L), "5")

  many <- hsa_mandala(cube, n_rings = 1000)
  expect_match(many$labels$caption, "1000 selections[[:space:]]+spanning 1-120")
  expect_match(many$labels$caption, "full order in provenance")
  expect_length(hsa_provenance(many)$selection$ring_band_indices, 1000L)
  expect_lt(nchar(many$labels$caption), 600L)
  expect_lte(max(nchar(strsplit(many$labels$subtitle, "\n")[[1L]])), 80L)
})

test_that("quartile captions occupy the full figure width", {
  plot <- hsa_spectral_quartiles(hsa_demo_cube(rows = 4, cols = 5))
  expect_identical(plot$theme$plot.caption.position, "plot")
  expect_equal(plot$theme$plot.caption$hjust, 0)
  expect_warning(ggplot2::ggplotGrob(plot), NA)
})

test_that("ordinary flux agrees with direct formulas and falls back at extremes", {
  cube <- hsa_demo_cube(rows = 3, cols = 4, bands = 8)
  expected <- apply(cube$data, c(1, 2), function(x) sum(abs(diff(x))))
  for (normalization in c("total", "mean_step", "wavelength_span")) {
    denominator <- switch(normalization, total = 1, mean_step = 7, wavelength_span = 35)
    plot <- hsa_spectral_flux(cube, normalization = normalization)
    expect_equal(plot$data$raw_value, as.vector(expected / denominator), tolerance = 1e-14)
  }
  cb <- hyperspectaculR:::.as_cube(cube)
  valid <- matrix(TRUE, 3, 4)
  expect_null(hyperspectaculR:::.spectral_change_ordinary(cb, 1e101, valid))
  expect_null(hyperspectaculR:::.spectral_change_ordinary(cb, 1e-101, valid))
  for (values in list(c(0, 1e-101), c(0, 1e101),
                     c(-.Machine$double.xmax, .Machine$double.xmax))) {
    cb <- hyperspectaculR:::.as_cube(array(values, c(1, 1, 2)))
    expect_null(hyperspectaculR:::.spectral_change_ordinary(cb, 1, matrix(TRUE, 1, 1)))
  }
})
