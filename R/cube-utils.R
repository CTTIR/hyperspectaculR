#' @keywords internal
#' @noRd
NULL

.validate_count <- function(x, arg, minimum = 1L,
                            call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
      x != floor(x) || x < minimum || x > .Machine$integer.max) {
    cli::cli_abort(
      "{.arg {arg}} must be one whole finite number greater than or equal to {minimum}.",
      call = call
    )
  }
  as.integer(x)
}

.validate_flag <- function(x, arg, call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be either {.val TRUE} or {.val FALSE}.",
                   call = call)
  }
  x
}

.validate_probs <- function(probs, call = rlang::caller_env()) {
  if (!is.numeric(probs) || length(probs) != 2L ||
      any(!is.finite(probs)) || probs[1] < 0 || probs[2] > 1 ||
      probs[1] >= probs[2]) {
    cli::cli_abort(
      "{.arg probs} must be two finite probabilities with 0 <= probs[1] < probs[2] <= 1.",
      call = call
    )
  }
  as.numeric(probs)
}

.validate_display_limits <- function(display_limits,
                                     call = rlang::caller_env()) {
  if (!is.numeric(display_limits) || length(display_limits) != 2L ||
      any(!is.finite(display_limits)) ||
      !(display_limits[1] < display_limits[2])) {
    cli::cli_abort(
      "{.arg display_limits} must be two increasing finite numbers.",
      call = call
    )
  }
  as.numeric(display_limits)
}

.validate_value_label <- function(value_label, call = rlang::caller_env()) {
  if (!is.character(value_label) || length(value_label) != 1L ||
      is.na(value_label) || !nzchar(value_label)) {
    cli::cli_abort("{.arg value_label} must be one non-empty string.", call = call)
  }
  value_label
}

# Accept an hsi_cube without requiring hyperspectR to be installed.
.as_cube <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  is_hsi <- inherits(x, "hsi_cube")
  if (is_hsi) {
    if (!is.list(x)) {
      cli::cli_abort("{.arg {arg}} is an {.cls hsi_cube} but is not a list.",
                     call = call)
    }
    if (is.null(x$data)) {
      cli::cli_abort("{.arg {arg}} is an {.cls hsi_cube} but lacks {.field data}.",
                     call = call)
    }
    data <- x$data
    wavelengths <- x$wavelengths
    if (is.null(wavelengths)) wavelengths <- attr(data, "wavelengths", exact = TRUE)
    mask <- x$mask
    if (is.null(mask)) mask <- attr(data, "mask", exact = TRUE)
  } else if (is.array(x)) {
    data <- x
    wavelengths <- attr(x, "wavelengths", exact = TRUE)
    mask <- attr(x, "mask", exact = TRUE)
  } else {
    cli::cli_abort(c(
      "{.arg {arg}} must be an {.cls hsi_cube} or a numeric 3-D array.",
      "x" = "Got {.cls {class(x)}}."
    ), call = call)
  }

  d <- dim(data)
  if (!is.array(data) || length(d) != 3L) {
    cli::cli_abort("{.arg {arg}} must be an {.cls hsi_cube} or a numeric 3-D array.",
                   call = call)
  }
  if (!typeof(data) %in% c("integer", "double") || is.complex(data)) {
    cli::cli_abort("The data in {.arg {arg}} must be a real numeric array.",
                   call = call)
  }
  if (any(d <= 0L)) {
    cli::cli_abort("Every dimension of {.arg {arg}} must be positive.", call = call)
  }

  has_wavelengths <- !is.null(wavelengths)
  if (has_wavelengths) {
    if (!is.numeric(wavelengths) || length(wavelengths) != d[3L] ||
        any(!is.finite(wavelengths)) || anyDuplicated(wavelengths) ||
        any(diff(wavelengths) <= 0)) {
      cli::cli_abort(
        "The wavelength metadata for {.arg {arg}} must be a finite, unique, strictly increasing numeric vector with one value per band.",
        call = call
      )
    }
    coordinates <- as.numeric(wavelengths)
    coordinate_kind <- "wavelength"
  } else {
    coordinates <- seq_len(d[3L])
    coordinate_kind <- "band_index"
  }

  if (!is.null(mask)) {
    if (!is.logical(mask) || !is.matrix(mask) ||
        !identical(dim(mask), d[1:2]) || anyNA(mask)) {
      cli::cli_abort(
        "The spatial {.field mask} for {.arg {arg}} must be a logical matrix matching rows and columns, without missing values.",
        call = call
      )
    }
  }

  list(
    data = data,
    coordinates = coordinates,
    wavelengths = coordinates,
    coordinate_kind = coordinate_kind,
    has_wavelengths = has_wavelengths,
    mask = mask
  )
}

.cube_band <- function(cube, band, call = rlang::caller_env()) {
  nb <- dim(cube$data)[3L]
  if (!is.numeric(band) || length(band) != 1L || !is.finite(band) ||
      band != floor(band) || band < 1L || band > nb) {
    cli::cli_abort("{.arg band} must be one whole index in 1:{nb}.", call = call)
  }
  d <- dim(cube$data)
  out <- matrix(cube$data[, , as.integer(band)], nrow = d[1L], ncol = d[2L])
  out[!is.finite(out)] <- NA_real_
  if (!is.null(cube$mask)) out[!cube$mask] <- NA_real_
  out
}

.cube_info <- function(cube) {
  d <- dim(cube$data)
  list(
    dimensions = c(rows = d[1L], columns = d[2L], bands = d[3L]),
    coordinate_kind = cube$coordinate_kind,
    coordinates = cube$coordinates,
    excluded_spatial = if (is.null(cube$mask)) 0L else as.integer(sum(!cube$mask))
  )
}

# Resolve a band given either an index or a wavelength coordinate.
.band_index <- function(cube, band = NULL, wavelength = NULL,
                        call = rlang::caller_env()) {
  nb <- dim(cube$data)[3L]
  if (!is.null(wavelength)) {
    if (!is.null(band)) {
      cli::cli_abort("Give either {.arg band} or {.arg wavelength}, not both.",
                     call = call)
    }
    if (!cube$has_wavelengths) {
      cli::cli_abort("Wavelength selection requires wavelength metadata.", call = call)
    }
    if (!is.numeric(wavelength) || length(wavelength) != 1L ||
        !is.finite(wavelength) || wavelength < cube$coordinates[1L] ||
        wavelength > cube$coordinates[nb]) {
      cli::cli_abort("{.arg wavelength} must be one finite value inside the wavelength range.",
                     call = call)
    }
    return(which.min(abs(cube$coordinates - wavelength)))
  }
  if (is.null(band)) return(max(1L, round(nb / 2)))
  if (!is.numeric(band) || length(band) != 1L || !is.finite(band) ||
      band != floor(band) || band < 1L || band > nb) {
    cli::cli_abort("{.arg band} must be one whole index in 1:{nb}.", call = call)
  }
  as.integer(band)
}

.rescale_affine <- function(x, limits) {
  width <- limits[2L] - limits[1L]
  if (is.finite(width)) return((x - limits[1L]) / width)
  scale <- max(abs(limits))
  lo <- limits[1L] / scale
  hi <- limits[2L] / scale
  (x / scale - lo) / (hi - lo)
}

.scale_rescaler <- function(x, to = c(0, 1),
                            from = range(x, na.rm = TRUE)) {
  scaled <- .rescale_affine(x, from)
  if (identical(to, c(0, 1))) return(scaled)
  to[1L] + scaled * (to[2L] - to[1L])
}

# Rescale finite observations to [0, 1] using a stated contrast stretch.
.stretch <- function(x, method = c("percentile", "range", "none"),
                     probs = c(0.02, 0.98), display_limits = c(0, 1)) {
  method <- match.arg(method)
  probs <- .validate_probs(probs)
  display_limits <- .validate_display_limits(display_limits)
  if (!typeof(x) %in% c("integer", "double") || is.complex(x)) {
    cli::cli_abort("{.arg x} must be real numeric data.")
  }

  valid <- is.finite(x)
  finite <- x[valid]
  if (!length(finite)) cli::cli_abort("{.arg x} contains no finite values.")
  out <- x
  out[!valid] <- NA_real_
  fallback <- NULL

  if (identical(method, "none")) {
    if (any(finite < display_limits[1L] | finite > display_limits[2L])) {
      cli::cli_abort(
        "Finite values must lie within {.arg display_limits} when {.arg method} is {.val none}."
      )
    }
    limits <- display_limits
    effective <- "none"
    clipped_below <- 0L
    clipped_above <- 0L
    output_domain <- display_limits
  } else {
    limits <- if (identical(method, "percentile")) {
      unname(stats::quantile(finite, probs = probs, na.rm = TRUE, type = 7L))
    } else {
      range(finite)
    }
    effective <- method
    if (identical(method, "percentile") && limits[1L] == limits[2L]) {
      limits <- range(finite)
      effective <- "range"
      fallback <- "percentile limits collapsed; used the full finite range"
    }
    clipped_below <- as.integer(sum(finite < limits[1L]))
    clipped_above <- as.integer(sum(finite > limits[2L]))
    if (limits[1L] == limits[2L]) {
      out[valid] <- 0
    } else {
      out[valid] <- pmin(pmax(.rescale_affine(finite, limits), 0), 1)
    }
    output_domain <- c(0, 1)
  }

  list(
    values = out,
    limits = as.numeric(limits),
    requested_method = method,
    effective_method = effective,
    fallback = fallback,
    probs = probs,
    quantile_type = 7L,
    clipped_below = clipped_below,
    clipped_above = clipped_above,
    finite_count = as.integer(length(finite)),
    excluded_count = as.integer(length(x) - length(finite)),
    display_limits = output_domain
  )
}

.as_long <- function(m, value = "value") {
  d <- dim(m)
  if (length(d) != 2L) cli::cli_abort("Internal image data must be a matrix.")
  out <- data.frame(
    x = rep(seq_len(d[2L]), each = d[1L]),
    y = rep(seq_len(d[1L]), times = d[2L]),
    v = as.vector(m)
  )
  names(out)[3L] <- value
  out
}
