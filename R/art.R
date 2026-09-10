.render_scalar_image <- function(data, palette, domain, interpolate,
                                 title, subtitle, caption) {
  force(data)
  force(palette)
  force(domain)
  force(interpolate)
  force(title)
  force(subtitle)
  force(caption)

  ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)
  ) +
    ggplot2::geom_raster(interpolate = interpolate) +
    ggplot2::scale_fill_gradientn(
      colours = hsa_palette(palette), limits = domain,
      rescaler = .scale_rescaler, oob = scales::squish,
      na.value = "transparent", guide = "none"
    ) +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    hsa_theme()
}

.render_fusion <- function(data, interpolate, subtitle, caption) {
  force(data)
  force(interpolate)
  force(subtitle)
  force(caption)

  ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$x, y = .data$y, fill = .data$hex)
  ) +
    ggplot2::geom_raster(interpolate = interpolate) +
    ggplot2::scale_fill_identity(na.value = "transparent") +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Spectral fusion", subtitle = subtitle, caption = caption
    ) +
    hsa_theme()
}


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

  p <- .render_scalar_image(
    df, palette, domain, interpolate,
    title = "Spectral mandala", subtitle = subtitle, caption = caption
  )

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

  p <- .render_scalar_image(
    df, palette, domain, interpolate,
    title = "Cumulative spectral change",
    subtitle = sprintf("%s across %d bands", quantity, d[3]),
    caption = .wrap_caption(.stretch_caption(st, value_label = value_label))
  )

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

  p <- .render_fusion(df, interpolate, subtitle, caption)

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
  fmt_percent <- function(probability) {
    format(probability * 100, digits = 6, trim = TRUE, scientific = FALSE)
  }
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
          "Linear stretch between the %s%% and %s%% percentiles",
          fmt_percent(probs[1L]), fmt_percent(probs[2L])
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
      "Requested %s-%s%% percentile stretch collapsed; effective range stretch [%s, %s] to [0, 1]%s",
      fmt_percent(record$probs[1L]), fmt_percent(record$probs[2L]),
      fmt(lim[1L]), fmt(lim[2L]), constant_note
    ))
  }
  if (identical(record$effective_method, "percentile")) {
    return(sprintf(
      "Linear %s-%s%% percentile stretch of %s [%s, %s] to [0, 1]",
      fmt_percent(record$probs[1L]), fmt_percent(record$probs[2L]), value_label,
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
