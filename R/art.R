#' Radial Spectral Mandala
#'
#' Renders the scene as concentric annuli, each drawn from a different
#' wavelength: the innermost ring shows the shortest wavelength, the outermost
#' the longest. The result is a single image that sweeps the spectral axis
#' outward from a chosen centre.
#'
#' This exploits the spectral dimension rather than decorating a single band,
#' which is what distinguishes it from an ordinary false-colour rendering. The
#' radius-to-wavelength mapping is linear and reported in the caption, so the
#' figure remains readable as data.
#'
#' @param cube An `hsi_cube` (from \pkg{hyperspectR}) or a 3-D array with
#'   dimensions `(rows, cols, bands)`.
#' @param centre Numeric length-2 vector `c(x, y)` in pixels. `NULL` (default)
#'   uses the image centre.
#' @param n_rings Number of annuli. Default `36`. More rings sample the
#'   spectrum more finely; fewer give bolder banding.
#' @param palette Palette name passed to [hsa_palette()].
#' @param stretch Contrast stretch: `"percentile"` (default), `"range"` or
#'   `"none"`.
#' @param probs Percentiles for `stretch = "percentile"`. Default
#'   `c(0.02, 0.98)`.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @examples
#' cube <- hsa_demo_cube()
#' hsa_mandala(cube, n_rings = 12)
#'
#' @export
hsa_mandala <- function(cube, centre = NULL, n_rings = 36L,
                        palette = "magma",
                        stretch = c("percentile", "range", "none"),
                        probs = c(0.02, 0.98)) {
  cb <- .as_cube(cube)
  stretch <- match.arg(stretch)
  d <- dim(cb$data)
  nrow_i <- d[1]; ncol_i <- d[2]; nb <- d[3]

  n_rings <- max(1L, as.integer(n_rings))
  if (is.null(centre)) centre <- c(ncol_i / 2, nrow_i / 2)
  if (length(centre) != 2L || anyNA(centre)) {
    cli::cli_abort("{.arg centre} must be a numeric vector {.code c(x, y)}.")
  }

  # radius of every pixel, then ring index, then the band that ring shows
  xg <- matrix(rep(seq_len(ncol_i), each = nrow_i), nrow_i, ncol_i)
  yg <- matrix(rep(seq_len(nrow_i), times = ncol_i), nrow_i, ncol_i)
  rad <- sqrt((xg - centre[1])^2 + (yg - centre[2])^2)
  ring <- pmin(floor(rad / (max(rad) + 1e-9) * n_rings) + 1L, n_rings)
  band_of_ring <- pmax(1L, pmin(nb, round(seq(1, nb, length.out = n_rings))))

  out <- matrix(NA_real_, nrow_i, ncol_i)
  for (k in seq_len(n_rings)) {
    sel <- ring == k
    if (any(sel)) out[sel] <- cb$data[, , band_of_ring[k]][sel]
  }

  st <- .stretch(out, stretch, probs)
  df <- .as_long(st$values)

  wl <- cb$wavelengths
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster(interpolate = TRUE) +
    ggplot2::scale_fill_gradientn(colours = hsa_palette(palette), na.value = "transparent",
                                  guide = "none") +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Spectral mandala",
      subtitle = sprintf("%d rings, %g-%g nm outward from the centre",
                         n_rings, min(wl), max(wl)),
      caption = .stretch_caption(stretch, st$limits, probs)
    ) +
    hsa_theme()
}


#' Cumulative Spectral Change
#'
#' Sums the absolute change between consecutive bands at every pixel, giving a
#' field of total spectral variability. Flat spectra appear dark; pixels whose
#' reflectance swings across the spectrum appear bright.
#'
#' Unlike a single-band image this cannot be produced from any one wavelength,
#' and unlike a variance map it is sensitive to the ordering of the bands, so
#' it responds to spectral shape rather than spread alone.
#'
#' @inheritParams hsa_mandala
#' @param normalise Logical. Divide by the number of band steps, so the value
#'   is a mean absolute step rather than a total. Default `TRUE`, which makes
#'   cubes with different band counts comparable.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @examples
#' cube <- hsa_demo_cube()
#' hsa_spectral_flux(cube)
#'
#' @export
hsa_spectral_flux <- function(cube, palette = "inferno", normalise = TRUE,
                              stretch = c("percentile", "range", "none"),
                              probs = c(0.02, 0.98)) {
  cb <- .as_cube(cube)
  stretch <- match.arg(stretch)
  d <- dim(cb$data)
  if (d[3] < 2L) {
    cli::cli_abort("Need at least 2 bands to measure spectral change; got {d[3]}.")
  }

  acc <- matrix(0, d[1], d[2])
  for (b in seq_len(d[3] - 1L)) {
    acc <- acc + abs(cb$data[, , b + 1L] - cb$data[, , b])
  }
  if (normalise) acc <- acc / (d[3] - 1L)

  st <- .stretch(acc, stretch, probs)
  df <- .as_long(st$values)

  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster(interpolate = TRUE) +
    ggplot2::scale_fill_gradientn(colours = hsa_palette(palette), na.value = "transparent",
                                  guide = "none") +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Cumulative spectral change",
      subtitle = sprintf("%s absolute step across %d bands",
                         if (normalise) "mean" else "total", d[3]),
      caption = .stretch_caption(stretch, st$limits, probs)
    ) +
    hsa_theme()
}


#' Multi-Band Spectral Fusion
#'
#' Builds a colour composite by averaging three *groups* of bands rather than
#' picking three single wavelengths. Averaging suppresses per-band sensor noise
#' and yields smoother, more saturated images than a three-band composite,
#' while remaining a straightforward and disclosable operation.
#'
#' @inheritParams hsa_mandala
#' @param red,green,blue Integer vectors of band indices, or numeric
#'   wavelengths in nm when `by = "wavelength"`. `NULL` (default) splits the
#'   spectrum into three contiguous thirds, long wavelengths to red.
#' @param by Either `"index"` (default) or `"wavelength"`.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @examples
#' cube <- hsa_demo_cube()
#' hsa_fusion(cube)
#'
#' @export
hsa_fusion <- function(cube, red = NULL, green = NULL, blue = NULL,
                       by = c("index", "wavelength"),
                       stretch = c("percentile", "range", "none"),
                       probs = c(0.02, 0.98)) {
  cb <- .as_cube(cube)
  by <- match.arg(by)
  stretch <- match.arg(stretch)
  d <- dim(cb$data)
  nb <- d[3]

  if (is.null(red) && is.null(green) && is.null(blue)) {
    cuts <- round(seq(1, nb + 1, length.out = 4))
    blue  <- seq(cuts[1], cuts[2] - 1)
    green <- seq(cuts[2], cuts[3] - 1)
    red   <- seq(cuts[3], nb)
  }

  to_idx <- function(v, nm) {
    if (is.null(v)) cli::cli_abort("{.arg {nm}} must be supplied when the others are.")
    if (identical(by, "wavelength")) {
      vapply(v, function(w) which.min(abs(cb$wavelengths - w)), integer(1))
    } else {
      idx <- as.integer(v)
      if (anyNA(idx) || any(idx < 1L) || any(idx > nb)) {
        cli::cli_abort("{.arg {nm}} contains band indices outside 1:{nb}.")
      }
      idx
    }
  }
  ri <- to_idx(red, "red"); gi <- to_idx(green, "green"); bi <- to_idx(blue, "blue")

  chan <- function(idx) {
    m <- if (length(idx) == 1L) cb$data[, , idx] else
      apply(cb$data[, , idx, drop = FALSE], c(1, 2), mean, na.rm = TRUE)
    .stretch(m, stretch, probs)$values
  }
  R <- chan(ri); G <- chan(gi); B <- chan(bi)

  df <- .as_long(R, "r")
  df$g <- as.vector(G)
  df$b <- as.vector(B)
  df$hex <- grDevices::rgb(
    ifelse(is.finite(df$r), df$r, 0),
    ifelse(is.finite(df$g), df$g, 0),
    ifelse(is.finite(df$b), df$b, 0)
  )

  wl <- cb$wavelengths
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$hex)) +
    ggplot2::geom_raster(interpolate = TRUE) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Spectral fusion",
      subtitle = sprintf("R %.0f-%.0f nm | G %.0f-%.0f nm | B %.0f-%.0f nm",
                         min(wl[ri]), max(wl[ri]), min(wl[gi]), max(wl[gi]),
                         min(wl[bi]), max(wl[bi])),
      caption = paste0(.stretch_caption(stretch, NULL, probs),
                       "; channels stretched independently")
    ) +
    hsa_theme()
}


# Caption text stating exactly what enhancement was applied. Kept in one place
# so no rendering can quietly omit it.
.stretch_caption <- function(method, limits = NULL, probs = c(0.02, 0.98)) {
  switch(method,
    none = "No contrast stretch applied",
    range = if (is.null(limits) || anyNA(limits)) "Linear stretch over the full data range"
            else sprintf("Linear stretch over [%.4g, %.4g]", limits[1], limits[2]),
    percentile = if (is.null(limits) || anyNA(limits))
      sprintf("Linear stretch between the %.0f%% and %.0f%% percentiles",
              probs[1] * 100, probs[2] * 100)
    else
      sprintf("Linear stretch between the %.0f%% and %.0f%% percentiles [%.4g, %.4g]",
              probs[1] * 100, probs[2] * 100, limits[1], limits[2])
  )
}


#' A Small Demonstration Cube
#'
#' A deterministic synthetic cube for examples and tests, shaped like an
#' `hsi_cube` so the art functions can be demonstrated without \pkg{hyperspectR}
#' or any recorded data.
#'
#' @param rows,cols Spatial dimensions. Default `48` by `64`.
#' @param bands Number of bands. Default `24`.
#' @param seed Random seed. Default `42`.
#'
#' @return A list with `data` and `wavelengths`, classed as `hsi_cube`.
#'
#' @examples
#' cube <- hsa_demo_cube()
#' dim(cube$data)
#'
#' @export
hsa_demo_cube <- function(rows = 48L, cols = 64L, bands = 24L, seed = 42L) {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  } else {
    on.exit(suppressWarnings(rm(".Random.seed", envir = globalenv())), add = TRUE)
  }
  set.seed(seed)

  xg <- matrix(rep(seq_len(cols), each = rows), rows, cols) / cols
  yg <- matrix(rep(seq_len(rows), times = cols), rows, cols) / rows
  disc <- ((xg - 0.5)^2 + (yg - 0.45)^2) < 0.045

  wl <- seq(500, by = 5, length.out = bands)
  arr <- array(0, dim = c(rows, cols, bands))
  for (b in seq_len(bands)) {
    spec <- 0.4 + 0.3 * sin(b / bands * pi)
    arr[, , b] <- (0.25 + 0.4 * xg + 0.2 * yg) * spec +
      ifelse(disc, 0.22 * cos(b / bands * 2 * pi), 0) +
      stats::rnorm(rows * cols, sd = 0.004)
  }

  structure(list(data = arr, wavelengths = wl,
                 metadata = list(source = "hsa_demo_cube")),
            class = "hsi_cube")
}
