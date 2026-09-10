test_that("the demo cube is well formed and deterministic", {
  a <- hsa_demo_cube()
  b <- hsa_demo_cube()

  expect_s3_class(a, "hsi_cube")
  expect_equal(dim(a$data), c(48L, 64L, 24L))
  expect_length(a$wavelengths, 24L)
  expect_equal(a$data, b$data)
  expect_true(all(is.finite(a$data)))
})

test_that("the demo cube leaves the caller's RNG stream alone", {
  set.seed(99)
  before <- runif(1)
  set.seed(99)
  invisible(hsa_demo_cube())
  after <- runif(1)
  expect_equal(before, after)
})

test_that("art functions return ggplot objects", {
  cube <- hsa_demo_cube()
  for (fn in c("hsa_mandala", "hsa_spectral_flux", "hsa_fusion")) {
    p <- do.call(fn, list(cube))
    expect_s3_class(p, "ggplot")
    expect_true(nzchar(p$labels$title), info = fn)
  }
})

test_that("every rendering states its contrast stretch", {
  cube <- hsa_demo_cube()
  # A striking image produced by an undisclosed enhancement is not a
  # defensible figure, so the caption must always say what was applied.
  for (fn in c("hsa_mandala", "hsa_spectral_flux", "hsa_fusion")) {
    p <- do.call(fn, list(cube))
    expect_match(p$labels$caption, "stretch", info = fn)
  }
  p <- hsa_mandala(cube, stretch = "none")
  expect_match(p$labels$caption, "No contrast stretch")
})

test_that("plain 3-D arrays are accepted, with band indices as wavelengths", {
  arr <- hsa_demo_cube()$data
  p <- hsa_spectral_flux(arr)
  expect_s3_class(p, "ggplot")
})

test_that("bad input is rejected with a pointer to how to build a cube", {
  expect_error(hsa_mandala("not a cube"), "hsi_cube")
  expect_error(hsa_mandala(matrix(1:4, 2)), "hsi_cube")
})

test_that("spectral flux needs at least two bands", {
  cube <- hsa_demo_cube(bands = 1L)
  expect_error(hsa_spectral_flux(cube), "at least 2 bands")
})

test_that("fusion accepts wavelengths as well as indices", {
  cube <- hsa_demo_cube()
  wl <- cube$wavelengths
  p <- hsa_fusion(cube,
                  red = wl[20], green = wl[12], blue = wl[3],
                  by = "wavelength")
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$subtitle, "nm")
})

test_that("fusion rejects out-of-range band indices", {
  cube <- hsa_demo_cube()
  expect_error(hsa_fusion(cube, red = 999L, green = 1L, blue = 2L),
               "outside 1:")
})

test_that("mandala ring count changes the reported sampling", {
  cube <- hsa_demo_cube()
  expect_match(hsa_mandala(cube, n_rings = 8L)$labels$subtitle, "8 rings")
  expect_match(hsa_mandala(cube, n_rings = 40L)$labels$subtitle, "40 rings")
})

test_that("mandala rejects a malformed centre", {
  cube <- hsa_demo_cube()
  expect_error(hsa_mandala(cube, centre = 5), "centre")
})

test_that("the theme paints its own background", {
  th <- hsa_theme()
  expect_s3_class(th, "theme")
  # a transparent background would inherit whatever is behind the figure
  expect_false(is.null(th$plot.background$fill))
})

test_that("palettes return colours and warn about non-monotonic ones", {
  expect_length(hsa_palette("viridis", n = 12L), 12L)
  expect_match(hsa_palette("magma", n = 3L)[1], "^#")
  expect_equal(hsa_palette("viridis", n = 5L, direction = -1),
               rev(hsa_palette("viridis", n = 5L)))
  expect_warning(hsa_palette("turbo", n = 4L), "greyscale")
})

test_that("the stretch helper reports the limits it used", {
  x <- c(0, 1, 2, 3, 100)
  st <- hyperspectaculR:::.stretch(x, "percentile", c(0.1, 0.9))
  expect_true(all(st$values >= 0 & st$values <= 1))
  expect_length(st$limits, 2L)

  none <- hyperspectaculR:::.stretch(x, "none", display_limits = c(0, 100))
  expect_equal(none$values, x)
})


test_that("spectral density returns a ggplot and reports the pixel count", {
  cube <- hsa_demo_cube()
  p <- hsa_spectral_density(cube)
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$subtitle, "pixel values over 24 bands")
  expect_match(p$labels$x, "wavelength")
})

test_that("out-of-range values are dropped rather than clipped", {
  # Clipping would pile outlier mass into the end bins and manufacture a
  # bright edge -- precisely the artefact this figure exists to expose.
  cube <- hsa_demo_cube()
  lim <- range(cube$data)

  spiked <- cube
  spiked$data[1, 1, 1] <- 1000

  base <- hsa_spectral_density(cube, limits = lim)$data
  with_outlier <- hsa_spectral_density(spiked, limits = lim)$data

  expect_lte(sum(with_outlier$density), sum(base$density) + 1e-9)
})

test_that("the caption states bins, limits and the count transform", {
  cube <- hsa_demo_cube()
  cap <- hsa_spectral_density(cube, nbins = 64L)$labels$caption
  expect_match(cap, "64 bins")
  expect_match(cap, "dropped, not clipped")
  expect_match(cap, "log1p")
  expect_match(cap, "White binned mean")
  expect_match(cap, "dashed binned 5-95% pixel envelope")
  expect_match(hsa_spectral_density(cube, transform = "identity")$labels$caption,
               "linear")
})

test_that("per-band normalisation is reported and rescales each band", {
  cube <- hsa_demo_cube()
  p <- hsa_spectral_density(cube, normalise = "band", transform = "identity")
  expect_match(p$labels$caption, "normalised per band")
  # each band's column should now sum to about 1
  by_band <- tapply(p$data$density, p$data$wavelength, sum)
  expect_true(all(abs(by_band - 1) < 1e-8))
})

test_that("degenerate input is rejected clearly", {
  cube <- hsa_demo_cube()
  expect_error(hsa_spectral_density(cube, limits = c(1, 1)), "increasing")
  expect_error(hsa_spectral_density(cube, limits = c(500, 600)), "No values")

  empty <- cube
  empty$data[] <- NA_real_
  expect_error(hsa_spectral_density(empty), "no finite values")
})
