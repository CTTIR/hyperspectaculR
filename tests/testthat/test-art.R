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

  none <- hyperspectaculR:::.stretch(x, "none")
  expect_equal(none$values, x)
})
