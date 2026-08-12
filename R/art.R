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


#' Spectral Density
#'
#' The joint distribution of reflectance against wavelength across every pixel
#' in the cube, drawn as a two-dimensional histogram: a luminous band of
#' probability mass with the mean spectrum threaded through it.
#'
#' This is the only composition here that is not an image, and it is the one
#' the others should be read against. Every rendering in this package applies a
#' contrast stretch; this figure shows the distribution that stretch is being
#' applied to, so a reader can see whether the limits are reasonable or whether
#' a striking image is the product of an aggressive one. Passing
#' `show_limits = TRUE` draws those limits directly onto the distribution.
#'
#' Values outside `limits` are **dropped, not clipped**. Clipping would pile
#' their mass into the end bins and manufacture bright edges at the extremes,
#' which is exactly the kind of artefact this figure exists to expose.
#'
#' @inheritParams hsa_mandala
#' @param nbins Number of reflectance bins. Default `128`.
#' @param limits Numeric length-2 reflectance range to bin over. `NULL`
#'   (default) uses the 0.1st and 99.9th percentiles of the finite data, so a
#'   handful of saturated pixels cannot flatten the whole figure.
#' @param transform Count transform: `"log1p"` (default) or `"identity"`.
#'   Reflectance histograms are heavy-tailed, and on a linear count scale only
#'   the mode is visible. Colourbar labels are back-transformed, so the legend
#'   still reads true counts.
#' @param normalise `"none"` (default) or `"band"`. Per-band normalisation
#'   stops a band with many masked pixels from reading as empty.
#' @param show_limits Draw horizontal rules at the percentile limits the image
#'   functions would use. Default `FALSE`.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @examples
#' cube <- hsa_demo_cube()
#' hsa_spectral_density(cube)
#'
#' @export
hsa_spectral_density <- function(cube, nbins = 128L, limits = NULL,
                                 transform = c("log1p", "identity"),
                                 normalise = c("none", "band"),
                                 palette = "mako", show_limits = FALSE,
                                 probs = c(0.02, 0.98)) {
  cb <- .as_cube(cube)
  transform <- match.arg(transform)
  normalise <- match.arg(normalise)
  d <- dim(cb$data)
  nb <- d[3]
  wl <- cb$wavelengths
  nbins <- max(2L, as.integer(nbins))

  finite <- cb$data[is.finite(cb$data)]
  if (!length(finite)) cli::cli_abort("The cube contains no finite values.")
  if (is.null(limits)) {
    limits <- unname(stats::quantile(finite, c(0.001, 0.999), na.rm = TRUE))
  }
  if (!is.numeric(limits) || length(limits) != 2L || !all(is.finite(limits)) ||
      diff(limits) <= 0) {
    cli::cli_abort("{.arg limits} must be two increasing finite numbers.")
  }

  breaks <- seq(limits[1], limits[2], length.out = nbins + 1L)
  centres <- (breaks[-1] + breaks[-(nbins + 1L)]) / 2

  # One pass per band: bin, tabulate. Never materialises an N x B copy.
  H <- matrix(0, nrow = nbins, ncol = nb)
  kept <- 0L
  for (b in seq_len(nb)) {
    v <- as.vector(cb$data[, , b])
    v <- v[is.finite(v)]
    idx <- .bincode(v, breaks, include.lowest = TRUE)
    idx <- idx[!is.na(idx)]              # out of range: dropped, not clipped
    kept <- kept + length(idx)
    if (length(idx)) H[, b] <- tabulate(idx, nbins = nbins)
  }
  if (!sum(H)) cli::cli_abort("No values fell inside {.arg limits}.")

  if (identical(normalise, "band")) {
    cs <- colSums(H)
    H <- sweep(H, 2, ifelse(cs > 0, cs, 1), "/")
  }

  # Mean and envelope read back off the SAME binned matrix, so the overlay is
  # exactly consistent with the image behind it rather than a second quantity
  # computed a different way.
  wmean <- apply(H, 2, function(col) if (sum(col)) sum(col * centres) / sum(col) else NA_real_)
  wq <- function(col, p) {
    if (!sum(col)) return(NA_real_)
    centres[which.max(cumsum(col) / sum(col) >= p)]
  }
  lo <- apply(H, 2, wq, p = 0.05)
  hi <- apply(H, 2, wq, p = 0.95)

  z <- if (identical(transform, "log1p")) log1p(H) else H

  df <- data.frame(
    wavelength = rep(wl, each = nbins),
    reflectance = rep(centres, times = nb),
    density = as.vector(z)
  )
  overlay <- data.frame(wavelength = wl, mean = wmean, lo = lo, hi = hi)

  # Back-transform the legend so it reads real counts despite the log scale.
  lab_fn <- if (identical(transform, "log1p") && identical(normalise, "none")) {
    function(x) format(round(expm1(x)), big.mark = ",", trim = TRUE)
  } else {
    waiver_labels()
  }

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$wavelength, y = .data$reflectance)) +
    ggplot2::geom_raster(ggplot2::aes(fill = .data$density), interpolate = TRUE) +
    ggplot2::scale_fill_gradientn(
      colours = hsa_palette(palette), na.value = "transparent",
      name = if (identical(normalise, "band")) "share" else "pixels",
      labels = lab_fn
    ) +
    ggplot2::geom_ribbon(
      data = overlay,
      ggplot2::aes(x = .data$wavelength, ymin = .data$lo, ymax = .data$hi),
      inherit.aes = FALSE, fill = NA, colour = "#FFFFFF", linewidth = 0.25,
      linetype = "22", alpha = 0.9
    ) +
    ggplot2::geom_line(
      data = overlay,
      ggplot2::aes(x = .data$wavelength, y = .data$mean),
      inherit.aes = FALSE, colour = "#FFFFFF", linewidth = 0.6
    )

  if (isTRUE(show_limits)) {
    st <- .stretch(cb$data, "percentile", probs)
    p <- p + ggplot2::geom_hline(yintercept = st$limits, colour = "#F2C14E",
                                 linewidth = 0.3, linetype = "31")
  }

  p +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::labs(
      title = "Spectral density",
      subtitle = sprintf("%s pixel values over %d bands, %g-%g nm",
                         format(kept, big.mark = ","), nb, min(wl), max(wl)),
      x = "wavelength (nm)", y = "reflectance",
      caption = sprintf(
        "%d bins over [%.4g, %.4g]; values outside dropped, not clipped; %s counts%s. White line: mean; dashed: 5-95%%",
        nbins, limits[1], limits[2],
        if (identical(transform, "log1p")) "log1p" else "linear",
        if (identical(normalise, "band")) "; normalised per band" else ""
      )
    ) +
    hsa_theme() +
    ggplot2::theme(
      axis.title = ggplot2::element_text(colour = "#E8E8EC", size = 9),
      axis.text  = ggplot2::element_text(colour = "#9A9AA4", size = 8),
      axis.line  = ggplot2::element_line(colour = "#3A3A44", linewidth = 0.3)
    )
}


# ggplot2 changed how "use the default labels" is spelled; resolve at runtime.
waiver_labels <- function() ggplot2::waiver()
