test_that("wavelength metadata must be a vector before coordinate validation", {
  x <- array(seq_len(24) / 24, c(2, 3, 4))
  malformed <- list(
    matrix(c(500, 520, 510, 530), 2),
    matrix(c(500, 510, 510, 520), 2),
    matrix(c(500, 530, 510, 520), 1),
    matrix(seq(500, 530, 10), 4),
    array(seq(500, 530, 10), c(1, 2, 2))
  )
  for (coordinates in malformed) {
    attr(x, "wavelengths") <- coordinates
    expect_error(hsa_mandala(x, n_rings = 2), "numeric vector")
    cube <- structure(list(data = x, wavelengths = coordinates), class = "hsi_cube")
    expect_error(hsa_fusion(cube, red = 515, green = 500, blue = 520,
                            by = "wavelength"), "numeric vector")
  }

  attr(x, "wavelengths") <- c(a = 500, b = 510, c = 520, d = 530)
  plot <- hsa_fusion(x, red = 515, green = 500, blue = 530,
                     by = "wavelength", stretch = "none")
  expect_identical(hsa_provenance(plot)$selection$red$indices, 2L)
  expect_equal(plot$data$raw_r, as.vector(x[, , 2]))
})

test_that("cube fields are exact and unrelated metadata cannot exclude pixels", {
  x <- array(seq_len(24) / 24, c(2, 3, 4))
  wrong_data <- structure(list(database = x), class = "hsi_cube")
  expect_error(hsa_mandala(wrong_data), "lacks data")

  cube <- structure(list(
    data = x,
    wavelengths_notes = c(500, 510, 520, 530),
    masking_notes = matrix(c(FALSE, rep(TRUE, 5)), 2, 3)
  ), class = "hsi_cube")
  plot <- hsa_fusion(cube, red = 4, green = 2, blue = 1, stretch = "none")
  expect_identical(hsa_provenance(plot)$cube$coordinate_kind, "band_index")
  expect_identical(hsa_provenance(plot)$cube$excluded_spatial, 0L)
  expect_equal(plot$data$raw_b, as.vector(x[, , 1]))
})

test_that("exact cube fields retain precedence over exact array attributes", {
  x <- array(seq_len(24) / 24, c(2, 3, 4))
  attr(x, "wavelengths") <- c(500, 510, 520, 530)
  attr(x, "mask") <- matrix(c(FALSE, rep(TRUE, 5)), 2, 3)
  cube <- structure(list(data = x, wavelengths_notes = "unrelated",
                         masking_notes = "unrelated"), class = "hsi_cube")
  inherited <- hsa_fusion(cube, red = 4, green = 2, blue = 1, stretch = "none")
  expect_identical(hsa_provenance(inherited)$cube$coordinates, c(500, 510, 520, 530))
  expect_identical(hsa_provenance(inherited)$cube$excluded_spatial, 1L)
  expect_true(is.na(inherited$data$hex[1]))

  cube$wavelengths <- c(600, 610, 620, 630)
  cube$mask <- matrix(TRUE, 2, 3)
  explicit <- hsa_fusion(cube, red = 4, green = 2, blue = 1, stretch = "none")
  expect_identical(hsa_provenance(explicit)$cube$coordinates, c(600, 610, 620, 630))
  expect_identical(hsa_provenance(explicit)$cube$excluded_spatial, 0L)
  expect_false(anyNA(explicit$data$hex))
})

test_that("dimension names preserve geometry, masks and provenance keys", {
  plain <- array(seq_len(24) / 24, c(2, 3, 4))
  attr(plain, "mask") <- matrix(c(FALSE, rep(TRUE, 5)), 2, 3)
  named <- plain
  dim(named) <- c(height = 2, width = 3, wavelength = 4)
  dim(attr(named, "mask")) <- c(mask_rows = 2, mask_columns = 3)
  before <- serialize(named, NULL)
  for (renderer in list(hsa_mandala, hsa_fusion, hsa_spectral_flux)) {
    expected <- renderer(plain)
    actual <- renderer(named)
    expect_equal(actual$data, expected$data)
    expect_identical(hsa_provenance(actual)$cube$dimensions,
                     c(rows = 2L, columns = 3L, bands = 4L))
    expect_identical(hsa_provenance(actual)$cube$excluded_spatial, 1L)
  }
  expect_identical(serialize(named, NULL), before)
})
