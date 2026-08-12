#' @keywords internal
#' @noRd
NULL

# Accept an hsi_cube without requiring hyperspectR to be installed.
#
# An hsi_cube is a list carrying `data` (rows x cols x bands) and
# `wavelengths`. Validating that structure directly, rather than importing
# hyperspectR, keeps this package usable wherever a cube can be obtained --
# and keeps hyperspectR in Suggests, which matters because it is not on CRAN.
.as_cube <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (inherits(x, "hsi_cube")) {
    if (is.null(x$data) || is.null(x$wavelengths)) {
      cli::cli_abort(
        "{.arg {arg}} is an {.cls hsi_cube} but lacks {.field data} or {.field wavelengths}.",
        call = call
      )
    }
    return(list(data = x$data, wavelengths = as.numeric(x$wavelengths)))
  }

  if (is.array(x) && length(dim(x)) == 3L) {
    wl <- attr(x, "wavelengths")
    if (is.null(wl)) wl <- seq_len(dim(x)[3L])
    return(list(data = unclass(x), wavelengths = as.numeric(wl)))
  }

  cli::cli_abort(c(
    "{.arg {arg}} must be an {.cls hsi_cube} or a 3-D array.",
    "x" = "Got {.cls {class(x)}}.",
    "i" = "Create one with {.fn hyperspectR::hs_read_tivita},
           {.fn hyperspectR::hs_read_cubert} or {.fn hyperspectR::hsi_cube}."
  ), call = call)
}


# Resolve a band given either an index or a wavelength in nm.
.band_index <- function(cube, band = NULL, wavelength = NULL,
                        call = rlang::caller_env()) {
  nb <- dim(cube$data)[3L]

  if (!is.null(wavelength)) {
    if (!is.null(band)) {
      cli::cli_abort("Give either {.arg band} or {.arg wavelength}, not both.",
                     call = call)
    }
    return(which.min(abs(cube$wavelengths - wavelength)))
  }

  if (is.null(band)) return(max(1L, round(nb / 2)))

  band <- as.integer(band)
  if (is.na(band) || band < 1L || band > nb) {
    cli::cli_abort(c(
      "{.arg band} out of range.",
      "x" = "Requested {.val {band}}, but the cube has {nb} bands."
    ), call = call)
  }
  band
}


# Rescale to [0, 1] using a stated contrast stretch.
#
# Every rendering in this package declares its stretch, because a visually
# striking image produced by an undisclosed enhancement is not a defensible
# scientific figure. The chosen limits are returned so callers can caption them.
.stretch <- function(x, method = c("percentile", "range", "none"),
                     probs = c(0.02, 0.98)) {
  method <- match.arg(method)
  finite <- x[is.finite(x)]
  if (!length(finite)) return(list(values = x, limits = c(NA_real_, NA_real_)))

  lim <- switch(method,
    percentile = unname(stats::quantile(finite, probs = probs, na.rm = TRUE)),
    range      = range(finite),
    none       = range(finite)
  )
  if (identical(method, "none")) {
    return(list(values = x, limits = lim))
  }
  if (!is.finite(diff(lim)) || diff(lim) <= 0) lim <- range(finite)
  if (diff(lim) <= 0) return(list(values = x * 0, limits = lim))

  list(values = pmin(pmax((x - lim[1]) / diff(lim), 0), 1), limits = lim)
}


# Long data frame for one matrix, ready for geom_raster.
.as_long <- function(m, value = "value") {
  d <- dim(m)
  out <- data.frame(
    x = rep(seq_len(d[2]), each = d[1]),
    y = rep(seq_len(d[1]), times = d[2]),
    v = as.vector(m)
  )
  names(out)[3] <- value
  out
}
