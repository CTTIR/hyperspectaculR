test_that("percentile stretches round tiny brackets after interpolation", {
  unit <- 2^-1074
  cases <- list(
    list(values = c(1, 5), expected = c(3, 5)),
    list(values = c(-5, 3), expected = c(-1, 3)),
    list(values = c(-5, -1), expected = c(-3, -1))
  )
  for (fixture in cases) {
    cube <- array(fixture$values * unit, c(1, 2, 1))
    plot <- hsa_mandala(cube, n_rings = 1, probs = c(.5, 1))
    expect_identical(hsa_provenance(plot)$enhancement$limits,
                     fixture$expected * unit)
    expect_identical(plot$data$value, c(0, 1))
  }
})

test_that("tiny interpolation preserves endpoints, signs and vector recycling", {
  unit <- 2^-1074
  interpolate <- hyperspectaculR:::.stable_interpolate
  expect_identical(interpolate(unit, 5 * unit, c(0, .25, .5, .75, 1)),
                   c(1, 2, 3, 4, 5) * unit)
  expect_identical(interpolate(c(-5, 1) * unit, c(3, 5) * unit, .5),
                   c(-1, 3) * unit)
  expect_identical(interpolate(0, 0, c(0, .5, 1)), c(0, 0, 0))

  # Near the normal/subnormal boundary, the midpoint's exact value is the
  # even subnormal multiple two units below the smallest normal double.
  boundary <- .Machine$double.xmin
  expect_identical(interpolate(boundary - 4 * unit, boundary, .5),
                   boundary - 2 * unit)
  ordinary <- c(-1e200, -1, 0, 1, 1e200)
  expect_identical(interpolate(ordinary, rev(ordinary), .25),
                   .75 * ordinary + .25 * rev(ordinary))
})

test_that("type-7 quantiles correct only tiny selected brackets", {
  unit <- 2^-1074
  quantile7 <- hyperspectaculR:::.quantile_type7
  expect_identical(quantile7(c(1, 5) * unit, c(0, .25, .5, .75, 1)),
                   c(1, 2, 3, 4, 5) * unit)
  expect_identical(quantile7(c(-7, -2, 3, 11) * unit, c(.25, .5, .75)),
                   c(-3, 0, 5) * unit)
  mixed <- c(c(1, 5, 9) * unit, 1)
  expect_identical(quantile7(mixed, c(.25, .5, .75)),
                   c(4 * unit, 7 * unit, .25))
  ordinary <- c(-1e300, -.25, 0, .75, 1e300)
  probabilities <- c(0, .001, .25, .5, .75, .999, 1)
  expect_identical(quantile7(ordinary, probabilities),
                   stats::quantile(ordinary, probabilities, type = 7, names = FALSE))
  expect_identical(quantile7(unit, probabilities), rep(unit, length(probabilities)))
})
