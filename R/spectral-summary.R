.spectral_intervals <- function(cube) {
  if (!cube$has_wavelengths) {
    cli::cli_abort("Physical spectral slopes require wavelength metadata in nm.")
  }
  nb <- dim(cube$data)[3L]
  if (nb < 2L) cli::cli_abort("Need at least 2 bands to measure spectral slope.")
  span <- cube$coordinates[nb] - cube$coordinates[1L]
  intervals <- diff(cube$coordinates)
  if (!is.finite(span) || span <= 0 || any(!is.finite(intervals) | intervals <= 0)) {
    cli::cli_abort("Wavelength intervals and span must be finite, positive and representable.")
  }
  list(intervals = intervals, span = span)
}

# Keep a separate binary exponent so normalization and aggregation do not
# prematurely round subnormal contributions or overflow large differences.
.spectral_binary_parts <- function(x) {
  exponent <- numeric(length(x))
  nonzero <- x > 0
  # log2(double.xmax) rounds to 1024; cap before constructing the power of two.
  exponent[nonzero] <- pmin(floor(log2(x[nonzero])), 1023)
  mantissa <- x / 2^exponent
  rounded_up <- nonzero & mantissa < 1
  mantissa[rounded_up] <- mantissa[rounded_up] * 2
  exponent[rounded_up] <- exponent[rounded_up] - 1
  list(mantissa = mantissa, exponent = exponent)
}

.scaled_spectral_difference <- function(next_value, previous_value, denominator) {
  next_value <- as.double(next_value)
  previous_value <- as.double(previous_value)
  difference <- abs(next_value - previous_value)
  overflow <- is.infinite(difference)
  # Ordinary differences must be formed first to preserve close huge operands.
  # Overflowing differences have opposite-sign operands and can be halved safely.
  difference[overflow] <- abs(next_value[overflow] / 2 - previous_value[overflow] / 2)
  numerator <- .spectral_binary_parts(difference)
  divisor <- .spectral_binary_parts(denominator)
  list(mantissa = numerator$mantissa / divisor$mantissa,
       exponent = numerator$exponent + as.integer(overflow) - divisor$exponent)
}

# A conservative normal-range path avoids exponent decomposition for ordinary
# flux values. Outside these bounds the complete binary calculation is used;
# in particular, tiny contributions are never rounded before aggregation.
.spectral_change_ordinary <- function(cube, denominator, valid) {
  if (any(denominator < 1e-100 | denominator > 1e100)) return(NULL)
  acc <- numeric(sum(valid))
  previous <- as.double(.cube_band(cube, 1L)[valid])
  for (b in seq_len(dim(cube$data)[3L] - 1L)) {
    next_value <- as.double(.cube_band(cube, b + 1L)[valid])
    difference <- abs(next_value - previous)
    if (any(!is.finite(difference) | difference > 1e100 |
            (difference > 0 & difference < 1e-100))) return(NULL)
    divisor <- if (length(denominator) == 1L) denominator else denominator[b]
    acc <- acc + difference / divisor
    previous <- next_value
  }
  acc
}

.spectral_change <- function(cube, denominator, rms = FALSE) {
  d <- dim(cube$data)
  valid <- matrix(TRUE, d[1L], d[2L])
  for (b in seq_len(d[3L])) valid <- valid & is.finite(.cube_band(cube, b))
  out <- matrix(NA_real_, d[1L], d[2L])
  if (!rms) {
    ordinary <- .spectral_change_ordinary(cube, denominator, valid)
    if (!is.null(ordinary)) {
      out[valid] <- ordinary
      return(out)
    }
  }
  acc <- numeric(sum(valid))
  exponent <- numeric(length(acc))
  previous <- .cube_band(cube, 1L)[valid]
  for (b in seq_len(d[3L] - 1L)) {
    next_value <- .cube_band(cube, b + 1L)[valid]
    divisor <- if (length(denominator) == 1L) denominator else denominator[b]
    contribution <- .scaled_spectral_difference(next_value, previous, divisor)
    # Zero terms must not set the common exponent: that could erase an entire
    # subnormal aggregate before any nonzero term has been accumulated.
    exponent[acc == 0] <- contribution$exponent[acc == 0]
    contribution$exponent[contribution$mantissa == 0] <- exponent[contribution$mantissa == 0]
    common <- pmax(exponent, contribution$exponent)
    a <- acc * 2^(exponent - common)
    z <- contribution$mantissa * 2^(contribution$exponent - common)
    combined <- .spectral_binary_parts(if (rms) sqrt(a^2 + z^2) else a + z)
    acc <- combined$mantissa
    exponent <- common + combined$exponent
    previous <- next_value
  }
  # Apply the subnormal power in two stages, rounding only the final product.
  # For normal values the exponent itself is representable as a power of two.
  small <- exponent < -1022
  result <- acc * 2^pmax(exponent, -1022)
  result[small] <- (acc[small] * 2^(exponent[small] + 1022)) * 2^-1022
  result[acc == 0] <- 0
  if (any(!is.finite(result))) {
    cli::cli_abort("Requested spectral quantity is not representable with finite numeric arithmetic.")
  }
  out[valid] <- result
  out
}

#' RMS Spectral Slope
#'
#' An experimental descriptive image of the nonnegative RMS magnitude of the
#' wavelength derivative of each pixel's piecewise-linear spectrum.
#'
#' @inheritParams hsa_mandala
#' @details For interval widths h = diff(wavelengths) and endpoint span L,
#'   G = sqrt(sum(h * (diff(x)/h)^2)/L). Values have input-value units per nm.
#'   This is neither a signed derivative, a spatial gradient, nor uncertainty.
#'   Short intervals and measurement noise can dominate the result. Gaps in
#'   sampling bridge unresolved structure; no smoothing or noise correction is
#'   applied. Physical wavelength metadata in nm and at least two bands are
#'   required, with finite positive representable intervals and span. A masked
#'   or incomplete spectrum is transparent; missing bands are never bridged.
#'   Nonrepresentable requested arithmetic raises an error.
#' @return A ggplot object with raw values and original-rendering provenance.
#' @examples
#' hsa_spectral_gradient(hsa_demo_cube())
#' @export
hsa_spectral_gradient <- function(cube, palette = "inferno",
                                  stretch = c("percentile", "range", "none"),
                                  probs = c(0.02, 0.98),
                                  display_limits = c(0, 1),
                                  value_label = "input value", interpolate = TRUE) {
  cb <- .as_cube(cube)
  stretch <- match.arg(stretch)
  probs <- .validate_probs(probs)
  display_limits <- .validate_display_limits(display_limits)
  value_label <- .validate_value_label(value_label)
  interpolate <- .validate_flag(interpolate, "interpolate")
  geometry <- .spectral_intervals(cb)
  denominator <- sqrt(geometry$intervals) * sqrt(geometry$span)
  raw <- .spectral_change(cb, denominator, rms = TRUE)
  st <- .stretch(raw, stretch, probs, display_limits)
  df <- .as_long(st$values)
  df$raw_value <- as.vector(raw)
  units <- paste(value_label, "per nm")
  formula <- "sqrt(sum(h * (diff(x)/h)^2)/L)"
  caption <- .wrap_caption(paste(
    paste0("G = ", formula),
    sprintf("h = wavelength intervals; L = %g nm", geometry$span),
    paste("Units:", units),
    "RMS magnitude of the piecewise-linear spectral derivative; short intervals and noise are amplified",
    "Not a spatial gradient, signed derivative or uncertainty; incomplete spectra are transparent",
    .stretch_caption(st, value_label = units), sep = "; "
  ))
  p <- .render_scalar_image(df, palette, st$display_limits, interpolate,
                            "RMS spectral slope", "Experimental descriptive spectral summary", caption)
  .attach_provenance(
    p, cb,
    quantity = list(name = "RMS spectral slope", experimental = TRUE,
                    formula = formula, units = units, value_label = value_label,
                    interpolant = "piecewise linear", span = geometry$span,
                    interval_widths = geometry$intervals),
    selection = list(band_indices = seq_len(dim(cb$data)[3L]), coordinates = cb$coordinates),
    missingness = list(policy = "propagate", valid_pixels = st$finite_count,
                       excluded_pixels = st$excluded_count),
    enhancement = .enhancement_record(st), palette = palette,
    interpolation = interpolate, value_label = value_label
  )
}

.render_quartile_image <- function(data, palette, domain, interpolate, legend_label, caption) {
  force(data)
  force(palette)
  force(domain)
  force(interpolate)
  force(legend_label)
  force(caption)
  ggplot2::ggplot(data, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster(interpolate = interpolate) +
    ggplot2::facet_wrap(ggplot2::vars(.data$panel), nrow = 1L) +
    ggplot2::scale_fill_gradientn(
      colours = hsa_palette(palette), limits = domain,
      rescaler = .scale_rescaler, oob = scales::squish,
      na.value = "transparent", name = legend_label
    ) +
    ggplot2::scale_y_reverse(expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(title = "Within-pixel spectral quartiles",
                  subtitle = "Experimental descriptive spectral summary", caption = caption) +
    hsa_theme() + ggplot2::theme(legend.position = "right",
                               plot.caption.position = "plot",
                               plot.caption = ggplot2::element_text(hjust = 0),
                               strip.text = ggplot2::element_text(colour = "#E8E8EC"))
}

#' Within-Pixel Spectral Quartiles
#'
#' An experimental descriptive composition with equal-band type-7 quartiles
#' computed over the measured bands within each spatial pixel.
#'
#' @inheritParams hsa_mandala
#' @details The panels are the 25th percentile, median and 75th percentile.
#'   Every band must be finite and the pixel unmasked; validity is shared by all
#'   panels. One band is allowed and gives three identical values. Bands have
#'   equal weight, regardless of wavelength spacing. These summaries omit
#'   spectral ordering, depend on sampling density, and are not confidence
#'   intervals or uncertainty estimates. A single stretch pools the three
#'   rendered raw panel values; all panels share its domain and legend. With a
#'   stretch the legend labels display values on 0-1; with `stretch = "none"`
#'   it labels raw input values in the supplied `display_limits` domain.
#' @return One faceted ggplot object, retaining raw panel values and provenance.
#' @examples
#' hsa_spectral_quartiles(hsa_demo_cube())
#' @export
hsa_spectral_quartiles <- function(cube, palette = "magma",
                                   stretch = c("percentile", "range", "none"),
                                   probs = c(0.02, 0.98),
                                   display_limits = c(0, 1),
                                   value_label = "input value", interpolate = TRUE) {
  cb <- .as_cube(cube)
  stretch <- match.arg(stretch)
  probs <- .validate_probs(probs)
  display_limits <- .validate_display_limits(display_limits)
  value_label <- .validate_value_label(value_label)
  interpolate <- .validate_flag(interpolate, "interpolate")
  d <- dim(cb$data)
  probabilities <- c(.25, .5, .75)
  panel_labels <- c("25th percentile", "Median", "75th percentile")
  values <- vapply(seq_len(d[3L]), function(b) as.vector(.cube_band(cb, b)),
                   numeric(d[1L] * d[2L]))
  dim(values) <- c(d[1L] * d[2L], d[3L])
  valid <- rowSums(is.finite(values)) == d[3L]
  raw <- matrix(NA_real_, nrow(values), 3L)
  for (i in which(valid)) {
    raw[i, ] <- stats::quantile(values[i, ], probabilities, type = 7L, names = FALSE)
  }
  st <- .stretch(raw, stretch, probs, display_limits)
  df <- .as_long(matrix(st$values[, 1L], d[1L], d[2L]))
  df <- df[rep(seq_len(nrow(df)), 3L), , drop = FALSE]
  df$value <- as.vector(st$values)
  df$raw_value <- as.vector(raw)
  df$panel <- factor(rep(panel_labels, each = nrow(raw)), levels = panel_labels)
  legend_label <- if (st$effective_method == "none") value_label else "display value (0-1)"
  caption <- .wrap_caption(paste(
    "Within-pixel, equal-band spectral quantiles (type 7); shared stretch pools all three raw panel values",
    "Omit spectral ordering; sampling-density dependent; not confidence intervals",
    if (d[3L] == 1L) "One measured band: all three panels equal that value" else
      sprintf("%d measured bands; complete spectra required in every panel", d[3L]),
    .stretch_caption(st, value_label = value_label), sep = "; "
  ))
  p <- .render_quartile_image(df, palette, st$display_limits, interpolate, legend_label, caption)
  enhancement <- .enhancement_record(st)
  enhancement$population <- "pooled three rendered raw panel values"
  enhancement$shared_limits <- st$limits
  .attach_provenance(
    p, cb,
    quantity = list(name = "within-pixel spectral quartiles", experimental = TRUE,
                    probabilities = probabilities, quantile_type = 7L,
                    population = "equally weighted measured bands within each pixel",
                    units = value_label, value_label = value_label),
    selection = list(band_indices = seq_len(d[3L]), coordinates = cb$coordinates,
                     panel_labels = panel_labels),
    missingness = list(policy = "propagate", valid_pixels = as.integer(sum(valid)),
                       excluded_pixels = as.integer(sum(!valid)),
                       shared_panel_validity = TRUE,
                       panel_valid_pixels = stats::setNames(rep(as.integer(sum(valid)), 3L), panel_labels)),
    enhancement = enhancement, palette = palette,
    interpolation = interpolate, value_label = value_label
  )
}
