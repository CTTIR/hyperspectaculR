#' Radial Spectral Mandala
#'
#' Renders the scene as concentric annuli, each drawn from a sampled spectral
#' band: the innermost ring uses the first band and the outermost uses the last.
#' The result is a single image that sweeps band indices outward from a chosen
#' centre.
#'
#' This exploits the spectral dimension rather than decorating a single band,
#' which is what distinguishes it from an ordinary false-colour rendering. The
#' radius-to-band-index mapping is linear and the actual selections are
#' reported in the caption, so the figure remains readable as data.
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
#' @param display_limits Two increasing finite endpoints used as the fixed
#'   colour domain for `stretch = "none"`. Default `c(0, 1)`.
#' @param value_label A truthful label for the input values. Default
#'   `"input value"`.
#' @param interpolate Logical; interpolate raster pixels. Default `TRUE`.
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
                        probs = c(0.02, 0.98), display_limits = c(0, 1),
                        value_label = "input value", interpolate = TRUE) {
  cb <- .as_cube(cube)
  stretch <- match.arg(stretch)
  probs <- .validate_probs(probs)
  display_limits <- .validate_display_limits(display_limits)
  value_label <- .validate_value_label(value_label)
  interpolate <- .validate_flag(interpolate, "interpolate")
  d <- dim(cb$data)
  nrow_i <- d[1]; ncol_i <- d[2]; nb <- d[3]

  n_rings <- .validate_count(n_rings, "n_rings")
  if (is.null(centre)) centre <- c((ncol_i + 1) / 2, (nrow_i + 1) / 2)
  if (!is.numeric(centre) || length(centre) != 2L || any(!is.finite(centre))) {
    cli::cli_abort("{.arg centre} must be a finite numeric vector {.code c(x, y)}.")
  }

  xg <- matrix(rep(seq_len(ncol_i), each = nrow_i), nrow_i, ncol_i)
  yg <- matrix(rep(seq_len(nrow_i), times = ncol_i), nrow_i, ncol_i)
  dx <- xg - centre[1L]
  dy <- yg - centre[2L]
  radius_scale <- max(abs(dx), abs(dy))
  if (radius_scale == 0) {
    radius_fraction <- matrix(0, nrow_i, ncol_i)
  } else {
    scaled_radius <- sqrt((dx / radius_scale)^2 + (dy / radius_scale)^2)
    radius_fraction <- scaled_radius / max(scaled_radius)
  }
  ring <- pmin(floor(radius_fraction * n_rings) + 1L, n_rings)
  band_of_ring <- pmax(1L, pmin(nb, round(seq(1, nb, length.out = n_rings))))

  out <- matrix(NA_real_, nrow_i, ncol_i)
  for (k in seq_len(n_rings)) {
    sel <- ring == k
    if (any(sel)) {
      band <- .cube_band(cb, band_of_ring[k])
      out[sel] <- band[sel]
    }
  }

  st <- .stretch(out, stretch, probs, display_limits)
  df <- .as_long(st$values)
  df$raw_value <- as.vector(out)
  domain <- if (identical(st$effective_method, "none")) display_limits else c(0, 1)

  selected <- unique(band_of_ring)
  coordinate_note <- if (identical(cb$coordinate_kind, "wavelength")) {
    sprintf("wavelength coordinates %g-%g", min(cb$coordinates[selected]),
            max(cb$coordinates[selected]))
  } else {
    "band-index coordinates"
  }
  subtitle <- sprintf("%d rings; linear band-index sampling (%s)",
                      n_rings, coordinate_note)
  caption <- .wrap_caption(paste(
    .stretch_caption(st, value_label = value_label),
    sprintf("Ring bands: %s", paste(band_of_ring, collapse = ", ")),
    sep = "; "
  ))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster(interpolate = interpolate) +
    ggplot2::scale_fill_gradientn(
      colours = hsa_palette(palette), limits = domain, oob = scales::squish,
      na.value = "transparent", guide = "none"
    ) +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Spectral mandala",
      subtitle = subtitle,
      caption = caption
    ) +
    hsa_theme()

  .attach_provenance(
    p, cb,
    quantity = list(name = "radial band sample", value_label = value_label),
    selection = list(centre = as.numeric(centre), n_rings = n_rings,
                     ring_band_indices = as.integer(band_of_ring),
                     ring_coordinates = cb$coordinates[band_of_ring]),
    missingness = list(policy = "propagate", valid_pixels = st$finite_count,
                       excluded_pixels = st$excluded_count),
    enhancement = .enhancement_record(st),
    palette = palette,
    interpolation = interpolate,
    value_label = value_label
  )
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
#'   is a mean absolute step rather than a total. Default `TRUE`.
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
                              probs = c(0.02, 0.98),
                              display_limits = c(0, 1),
                              value_label = "input value", interpolate = TRUE) {
  cb <- .as_cube(cube)
  stretch <- match.arg(stretch)
  normalise <- .validate_flag(normalise, "normalise")
  probs <- .validate_probs(probs)
  display_limits <- .validate_display_limits(display_limits)
  value_label <- .validate_value_label(value_label)
  interpolate <- .validate_flag(interpolate, "interpolate")
  d <- dim(cb$data)
  if (d[3] < 2L) {
    cli::cli_abort("Need at least 2 bands to measure spectral change; got {d[3]}.")
  }

  acc <- matrix(0, d[1], d[2])
  for (b in seq_len(d[3] - 1L)) {
    acc <- acc + abs(.cube_band(cb, b + 1L) - .cube_band(cb, b))
  }
  if (normalise) acc <- acc / (d[3] - 1L)

  st <- .stretch(acc, stretch, probs, display_limits)
  df <- .as_long(st$values)
  df$raw_value <- as.vector(acc)
  domain <- if (identical(st$effective_method, "none")) display_limits else c(0, 1)
  quantity <- if (normalise) "mean absolute band step" else "total absolute band step"

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster(interpolate = interpolate) +
    ggplot2::scale_fill_gradientn(
      colours = hsa_palette(palette), limits = domain, oob = scales::squish,
      na.value = "transparent", guide = "none"
    ) +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Cumulative spectral change",
      subtitle = sprintf("%s across %d bands", quantity, d[3]),
      caption = .wrap_caption(.stretch_caption(st, value_label = value_label))
    ) +
    hsa_theme()

  .attach_provenance(
    p, cb,
    quantity = list(name = quantity, normalised = normalise,
                    denominator = if (normalise) d[3] - 1L else 1L,
                    value_label = value_label),
    selection = list(band_indices = seq_len(d[3]),
                     coordinates = cb$coordinates),
    missingness = list(policy = "propagate", valid_pixels = st$finite_count,
                       excluded_pixels = st$excluded_count),
    enhancement = .enhancement_record(st),
    palette = palette,
    interpolation = interpolate,
    value_label = value_label
  )
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
#' @param missing Missing-band policy. `"propagate"` (default) requires every
#'   selected band; `"available"` averages the finite contributors in a group.
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
                       probs = c(0.02, 0.98), display_limits = c(0, 1),
                       value_label = "input value", interpolate = TRUE,
                       missing = c("propagate", "available")) {
  cb <- .as_cube(cube)
  by <- match.arg(by)
  stretch <- match.arg(stretch)
  missing <- match.arg(missing)
  probs <- .validate_probs(probs)
  display_limits <- .validate_display_limits(display_limits)
  value_label <- .validate_value_label(value_label)
  interpolate <- .validate_flag(interpolate, "interpolate")
  d <- dim(cb$data)
  nb <- d[3]

  if (is.null(red) && is.null(green) && is.null(blue)) {
    if (nb < 3L) {
      cli::cli_abort("Default fusion groups require at least 3 bands.")
    }
    blue <- seq_len(floor(nb / 3))
    green <- seq.int(floor(nb / 3) + 1L, floor(2 * nb / 3))
    red <- seq.int(floor(2 * nb / 3) + 1L, nb)
    default_groups <- TRUE
  } else {
    if (is.null(red) || is.null(green) || is.null(blue)) {
      cli::cli_abort("{.arg red}, {.arg green}, and {.arg blue} must all be supplied together.")
    }
    default_groups <- FALSE
  }

  to_idx <- function(v, nm) {
    if (!is.numeric(v) || !length(v) || any(!is.finite(v))) {
      cli::cli_abort("{.arg {nm}} must be a non-empty finite numeric vector.")
    }
    if (identical(by, "wavelength")) {
      if (!cb$has_wavelengths) {
        cli::cli_abort("Explicit wavelength selection requires wavelength metadata.")
      }
      if (any(v < cb$coordinates[1L] | v > cb$coordinates[nb])) {
        cli::cli_abort("{.arg {nm}} contains targets outside the wavelength range.")
      }
      idx <- vapply(v, function(w) which.min(abs(cb$coordinates - w)), integer(1))
      if (anyDuplicated(idx)) {
        cli::cli_abort("{.arg {nm}} contains targets that resolve to the same band.")
      }
      idx
    } else {
      if (any(v != floor(v))) {
        cli::cli_abort("{.arg {nm}} must contain whole band indices.")
      }
      if (any(v < 1L) || any(v > nb)) {
        cli::cli_abort("{.arg {nm}} contains band indices outside 1:{nb}.")
      }
      if (anyDuplicated(v)) {
        cli::cli_abort("{.arg {nm}} band indices must be unique.")
      }
      as.integer(v)
    }
  }
  if (default_groups) {
    ri <- as.integer(red); gi <- as.integer(green); bi <- as.integer(blue)
  } else {
    ri <- to_idx(red, "red"); gi <- to_idx(green, "green"); bi <- to_idx(blue, "blue")
  }

  chan <- function(idx) {
    values <- do.call(cbind, lapply(idx, function(b) as.vector(.cube_band(cb, b))))
    if (is.null(dim(values))) dim(values) <- c(length(values), 1L)
    contributors <- rowSums(is.finite(values))
    aggregate <- rowMeans(values, na.rm = TRUE)
    aggregate[contributors == 0L] <- NA_real_
    if (identical(missing, "propagate")) {
      aggregate[contributors != length(idx)] <- NA_real_
    }
    list(
      values = matrix(aggregate, nrow = d[1L], ncol = d[2L]),
      contributors = list(
        selected_bands = length(idx),
        minimum = as.integer(min(contributors)),
        maximum = as.integer(max(contributors)),
        complete_pixels = as.integer(sum(contributors == length(idx))),
        no_contributor_pixels = as.integer(sum(contributors == 0L))
      )
    )
  }
  raw <- list(red = chan(ri), green = chan(gi), blue = chan(bi))
  common_valid <- is.finite(raw$red$values) & is.finite(raw$green$values) &
    is.finite(raw$blue$values)
  if (!any(common_valid)) {
    cli::cli_abort("Fusion has no pixels with a finite contribution in all three channels.")
  }
  for (nm in names(raw)) raw[[nm]]$values[!common_valid] <- NA_real_

  enhancement <- lapply(raw, function(channel) {
    .stretch(channel$values, stretch, probs, display_limits)
  })

  df <- .as_long(enhancement$red$values, "r")
  df$g <- as.vector(enhancement$green$values)
  df$b <- as.vector(enhancement$blue$values)
  df$raw_r <- as.vector(raw$red$values)
  df$raw_g <- as.vector(raw$green$values)
  df$raw_b <- as.vector(raw$blue$values)
  valid_rgb <- is.finite(df$r) & is.finite(df$g) & is.finite(df$b)
  df$hex <- NA_character_
  if (any(valid_rgb)) {
    rgb_domain <- enhancement$red$display_limits
    rr <- .rescale_affine(df$r[valid_rgb], rgb_domain)
    gg <- .rescale_affine(df$g[valid_rgb], rgb_domain)
    bb <- .rescale_affine(df$b[valid_rgb], rgb_domain)
    df$hex[valid_rgb] <- grDevices::rgb(
      pmin(pmax(rr, 0), 1), pmin(pmax(gg, 0), 1), pmin(pmax(bb, 0), 1)
    )
  }

  describe_group <- function(name, idx) {
    if (cb$has_wavelengths) {
      sprintf("%s bands %s (%g-%g nm)", name, paste(idx, collapse = ","),
              min(cb$coordinates[idx]), max(cb$coordinates[idx]))
    } else {
      sprintf("%s bands %s", name, paste(idx, collapse = ","))
    }
  }
  subtitle <- paste(describe_group("R", ri), describe_group("G", gi),
                    describe_group("B", bi), sep = " | ")
  channel_captions <- vapply(c("red", "green", "blue"), function(nm) {
    paste0(toupper(substr(nm, 1, 1)), ": ",
           .stretch_caption(enhancement[[nm]], value_label = value_label))
  }, character(1))
  caption <- .wrap_caption(paste(
    paste(channel_captions, collapse = "; "),
    sprintf("RGB construction maps displayed channels from [%s, %s] to [0, 1]",
            format(enhancement$red$display_limits[1L], digits = 4),
            format(enhancement$red$display_limits[2L], digits = 4)),
    sprintf("missing=%s", missing), sep = "; "
  ))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$hex)) +
    ggplot2::geom_raster(interpolate = interpolate) +
    ggplot2::scale_fill_identity(na.value = "transparent") +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Spectral fusion",
      subtitle = subtitle,
      caption = caption
    ) +
    hsa_theme()

  selection_record <- function(requested, idx) {
    list(requested = requested, indices = idx, coordinates = cb$coordinates[idx])
  }
  .attach_provenance(
    p, cb,
    quantity = list(name = "mean selected-band RGB fusion", value_label = value_label),
    selection = list(
      by = if (default_groups) "index" else by,
      default = default_groups,
      red = selection_record(if (default_groups) ri else red, ri),
      green = selection_record(if (default_groups) gi else green, gi),
      blue = selection_record(if (default_groups) bi else blue, bi)
    ),
    missingness = list(
      strategy = missing,
      common_valid_pixels = as.integer(sum(common_valid)),
      excluded_pixels = as.integer(sum(!common_valid)),
      contributors = lapply(raw, `[[`, "contributors")
    ),
    enhancement = lapply(enhancement, .enhancement_record),
    palette = "RGB",
    interpolation = interpolate,
    value_label = value_label
  )
}


# Caption text stating exactly what enhancement was applied. Kept in one place
# so no rendering can quietly omit it.
.stretch_caption <- function(method, limits = NULL, probs = c(0.02, 0.98),
                             value_label = "input value") {
  if (is.list(method)) {
    record <- method
  } else {
    old_limits <- limits
    if (identical(method, "none") &&
        (is.null(old_limits) || length(old_limits) != 2L || anyNA(old_limits))) {
      old_limits <- c(0, 1)
    }
    if (!identical(method, "none") &&
        (is.null(old_limits) || length(old_limits) != 2L || anyNA(old_limits))) {
      return(switch(method,
        range = "Linear stretch over the full finite data range",
        percentile = sprintf(
          "Linear stretch between the %.0f%% and %.0f%% percentiles",
          probs[1L] * 100, probs[2L] * 100
        ),
        none = "No contrast stretch applied"
      ))
    }
    record <- list(
      requested_method = method,
      effective_method = method,
      limits = old_limits,
      probs = probs,
      fallback = NULL,
      display_limits = if (identical(method, "none")) old_limits else c(0, 1)
    )
  }
  fmt <- function(x) format(x, digits = 4, trim = TRUE)
  lim <- record$limits
  if (identical(record$effective_method, "none")) {
    return(sprintf(
      "No contrast stretch applied; raw %s preserved; fixed display domain [%s, %s]",
      value_label, fmt(record$display_limits[1L]), fmt(record$display_limits[2L])
    ))
  }
  if (identical(record$requested_method, "percentile") &&
      identical(record$effective_method, "range")) {
    constant_note <- if (lim[1L] == lim[2L]) {
      "; constant data map to the dark endpoint"
    } else {
      ""
    }
    return(sprintf(
      "Requested %.0f-%.0f%% percentile stretch collapsed; effective range stretch [%s, %s] to [0, 1]%s",
      record$probs[1L] * 100, record$probs[2L] * 100,
      fmt(lim[1L]), fmt(lim[2L]), constant_note
    ))
  }
  if (identical(record$effective_method, "percentile")) {
    return(sprintf(
      "Linear %.0f-%.0f%% percentile stretch of %s [%s, %s] to [0, 1]",
      record$probs[1L] * 100, record$probs[2L] * 100, value_label,
      fmt(lim[1L]), fmt(lim[2L])
    ))
  }
  suffix <- if (lim[1L] == lim[2L]) "; constant data map to the dark endpoint" else ""
  sprintf("Linear range stretch of %s [%s, %s] to [0, 1]%s",
          value_label, fmt(lim[1L]), fmt(lim[2L]), suffix)
}

.wrap_caption <- function(text, width = 110L) {
  paste(strwrap(text, width = width, simplify = TRUE), collapse = "\n")
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
  rows <- .validate_count(rows, "rows")
  cols <- .validate_count(cols, "cols")
  bands <- .validate_count(bands, "bands")
  seed <- .validate_count(seed, "seed", minimum = 0L)
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
