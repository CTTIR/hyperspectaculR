.density_limits <- function(limits, call = rlang::caller_env()) {
  if (!is.numeric(limits) || length(limits) != 2L ||
      any(!is.finite(limits)) || limits[1L] >= limits[2L]) {
    cli::cli_abort("{.arg limits} must be two increasing finite numbers.",
                   call = call)
  }
  as.numeric(limits)
}

.density_midpoint <- function(left, right) {
  width <- right - left
  midpoint <- left / 2 + right / 2
  ordinary <- is.finite(width)
  midpoint[ordinary] <- left[ordinary] + width[ordinary] / 2
  midpoint
}

.density_breaks <- function(limits, nbins) {
  weight <- seq.int(0L, nbins) / nbins
  breaks <- (1 - weight) * limits[1L] + weight * limits[2L]
  breaks[c(1L, length(breaks))] <- limits
  if (any(!is.finite(breaks)) || any(diff(breaks) <= 0)) {
    cli::cli_abort(paste(
      "Cannot construct {nbins} finite, distinct bins inside {.arg limits}.",
      "Use fewer bins or a wider representable range."
    ))
  }
  breaks
}

.density_constant_range <- function(value, nbins) {
  if (value == 0) return(c(-0.5, 0.5))
  padding <- max(abs(value) * 0.01,
                 .Machine$double.xmin * (nbins + 1L))
  limits <- c(value - padding, value + padding)
  if (!is.finite(limits[1L])) limits <- c(value, value + padding)
  if (!is.finite(limits[2L])) limits <- c(value - padding, value)
  if (limits[1L] == limits[2L]) {
    limits <- if (value > 0) c(0, value) else c(value, 0)
  }
  limits
}

.density_coordinate_edges <- function(coordinates) {
  n <- length(coordinates)
  if (n == 1L) {
    edges <- c(coordinates - 0.5, coordinates + 0.5)
    fallback <- "single-band coordinate width of 1"
  } else {
    inside <- .density_midpoint(coordinates[-n], coordinates[-1L])
    edges <- c(
      coordinates[1L] - (inside[1L] - coordinates[1L]),
      inside,
      coordinates[n] + (coordinates[n] - inside[n - 1L])
    )
    fallback <- NULL
  }
  if (any(!is.finite(edges)) || any(diff(edges) <= 0)) {
    cli::cli_abort(paste(
      "Cannot construct finite, ordered rectangle boundaries from the band coordinates.",
      "Use representable coordinate spacing."
    ))
  }
  list(edges = edges, fallback = fallback)
}

.density_interpolate <- function(limits, weight) {
  (1 - weight) * limits[1L] + weight * limits[2L]
}

.density_overlay <- function(H, centres, limits, coordinates) {
  nb <- ncol(H)
  populated <- colSums(H) > 0
  mean <- lower <- upper <- rep(NA_real_, nb)
  scaled_centres <- .rescale_affine(centres, limits)
  for (band in which(populated)) {
    counts <- H[, band]
    total <- sum(counts)
    scaled_mean <- sum((counts / total) * scaled_centres)
    mean[band] <- .density_interpolate(limits, scaled_mean)
    cumulative <- cumsum(counts) / total
    lower[band] <- centres[which(cumulative >= 0.05)[1L]]
    upper[band] <- centres[which(cumulative >= 0.95)[1L]]
  }

  group <- rep(NA_integer_, nb)
  current <- 0L
  previous <- FALSE
  for (band in seq_len(nb)) {
    if (populated[band]) {
      if (!previous) current <- current + 1L
      group[band] <- current
      previous <- TRUE
    } else {
      previous <- FALSE
    }
  }
  data.frame(
    band = seq_len(nb), coordinate = coordinates,
    mean = mean, lower = lower, upper = upper, group = group
  )
}

.density_legend_labels <- function(transform, normalise) {
  force(transform)
  force(normalise)
  function(x) {
    raw <- if (identical(transform, "log1p")) expm1(x) else x
    if (identical(normalise, "band")) {
      paste0(format(100 * raw, digits = 4, trim = TRUE), "%")
    } else {
      format(round(raw), big.mark = ",", trim = TRUE, scientific = FALSE)
    }
  }
}

.render_density <- function(data, palette, display_domain, normalise,
                            transform, overlay, show_limits,
                            reference_values, subtitle, x_label, y_label,
                            caption) {
  force(data)
  force(palette)
  force(display_domain)
  force(normalise)
  force(transform)
  force(overlay)
  force(show_limits)
  force(reference_values)
  force(subtitle)
  force(x_label)
  force(y_label)
  force(caption)

  plot <- ggplot2::ggplot(data) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax,
                   ymin = .data$ymin, ymax = .data$ymax,
                   fill = .data$density)
    ) +
    ggplot2::scale_fill_gradientn(
      colours = hsa_palette(palette), limits = display_domain,
      rescaler = .scale_rescaler, oob = scales::squish,
      na.value = "transparent",
      name = if (identical(normalise, "band")) "share" else "pixels",
      labels = .density_legend_labels(transform, normalise)
    )

  populated_overlay <- overlay[!is.na(overlay$group), , drop = FALSE]
  group_sizes <- table(populated_overlay$group)
  multiple_groups <- as.integer(names(group_sizes[group_sizes >= 2L]))
  single_groups <- as.integer(names(group_sizes[group_sizes == 1L]))
  if (length(multiple_groups)) {
    multiple <- populated_overlay[
      populated_overlay$group %in% multiple_groups, , drop = FALSE
    ]
    plot <- plot +
      ggplot2::geom_ribbon(
        data = multiple,
        ggplot2::aes(x = .data$coordinate, ymin = .data$lower,
                     ymax = .data$upper, group = .data$group),
        inherit.aes = FALSE, fill = NA, colour = "#FFFFFF",
        linewidth = 0.25, linetype = "22", alpha = 0.9
      ) +
      ggplot2::geom_line(
        data = multiple,
        ggplot2::aes(x = .data$coordinate, y = .data$mean,
                     group = .data$group),
        inherit.aes = FALSE, colour = "#FFFFFF", linewidth = 0.6
      )
  }
  if (length(single_groups)) {
    single <- populated_overlay[
      populated_overlay$group %in% single_groups, , drop = FALSE
    ]
    plot <- plot +
      ggplot2::geom_segment(
        data = single,
        ggplot2::aes(x = .data$coordinate, xend = .data$coordinate,
                     y = .data$lower, yend = .data$upper),
        inherit.aes = FALSE, colour = "#FFFFFF", linewidth = 0.25,
        linetype = "22", alpha = 0.9
      ) +
      ggplot2::geom_point(
        data = single,
        ggplot2::aes(x = .data$coordinate, y = .data$mean),
        inherit.aes = FALSE, colour = "#FFFFFF", size = 1.2
      )
  }
  if (show_limits) {
    plot <- plot + ggplot2::geom_hline(
      yintercept = unique(reference_values), colour = "#F2C14E",
      linewidth = 0.3, linetype = "31"
    )
  }

  plot +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::coord_cartesian(expand = FALSE) +
    ggplot2::labs(
      title = "Spectral density", subtitle = subtitle,
      x = x_label, y = y_label, caption = caption
    ) +
    hsa_theme() +
    ggplot2::theme(
      axis.title = ggplot2::element_text(colour = "#E8E8EC", size = 9),
      axis.text = ggplot2::element_text(colour = "#9A9AA4", size = 8),
      axis.line = ggplot2::element_line(colour = "#3A3A44", linewidth = 0.3)
    )
}

.density_number <- function(x) {
  scientific <- any(abs(x) >= 1e6 | (x != 0 & abs(x) < 1e-4))
  format(x, digits = 6, trim = TRUE, scientific = scientific)
}

.density_percent <- function(x) {
  format(100 * x, digits = 6, trim = TRUE, scientific = FALSE)
}

.density_finite_values <- function(cube) {
  force(cube)
  nb <- dim(cube$data)[3L]
  buffers <- vector("list", nb)
  for (band in seq_len(nb)) {
    values <- .cube_band(cube, band)
    buffers[[band]] <- values[is.finite(values)]
  }
  unlist(buffers, use.names = FALSE)
}


#' Spectral Density
#'
#' Draws the joint distribution of input values and spectral coordinates as an
#' exact two-dimensional histogram. A binned mean and binned 5--95% pixel
#' envelope are calculated from the retained histogram counts.
#'
#' Values outside `limits` are dropped rather than clipped into the end bins.
#' Masks and nonfinite values are excluded. The overlay describes the retained
#' pixel distribution; it is not a confidence interval.
#'
#' @inheritParams hsa_mandala
#' @param nbins Number of value bins. Must be an integer of at least two.
#'   Default `128`.
#' @param limits Numeric length-two value range to bin over. `NULL` (default)
#'   uses the 0.1st and 99.9th percentiles of all finite eligible values.
#' @param transform Display transform: `"log1p"` (default) or `"identity"`.
#'   Legend labels are returned to raw counts or shares.
#' @param normalise `"none"` (default) displays raw counts; `"band"` displays
#'   shares of the retained count in each band. Empty bands remain missing.
#' @param probs Two increasing finite probabilities between zero and one for
#'   the global raw eligible-value references when `show_limits = TRUE`.
#'   These do not set the histogram range or image enhancement limits.
#' @param show_limits Logical. Draw global raw eligible-value percentiles using
#'   `probs`. These references include finite observations outside `limits` and
#'   are separate from image enhancement limits. Default `FALSE`.
#'
#' @return A \pkg{ggplot2} object with compact original-rendering provenance.
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
                                 probs = c(0.02, 0.98),
                                 value_label = "input value") {
  cb <- .as_cube(cube)
  nbins <- .validate_count(nbins, "nbins", minimum = 2L)
  transform <- match.arg(transform)
  normalise <- match.arg(normalise)
  show_limits <- .validate_flag(show_limits, "show_limits")
  probs <- .validate_probs(probs)
  value_label <- .validate_value_label(value_label)
  explicit_limits <- !is.null(limits)
  if (explicit_limits) limits <- .density_limits(limits)

  dimensions <- dim(cb$data)
  nb <- dimensions[3L]
  eligible_per_band <- if (is.null(cb$mask)) {
    prod(dimensions[1:2])
  } else {
    sum(cb$mask)
  }
  needs_global <- !explicit_limits || show_limits
  finite_population <- NULL
  quantiles <- NULL
  global_population <- 0L
  range_fallback <- NULL
  range_probs <- if (explicit_limits) NULL else c(0.001, 0.999)

  if (needs_global) {
    finite_population <- .density_finite_values(cb)
    if (!length(finite_population)) {
      cli::cli_abort(paste(
        "The cube contains no finite eligible values",
        "(no finite values after mask exclusion)."
      ))
    }
    global_population <- length(finite_population)
    requested_probs <- sort(unique(c(
      if (!explicit_limits) range_probs,
      if (show_limits) probs
    )))
    quantiles <- unname(stats::quantile(
      finite_population, probs = requested_probs, type = 7L, names = FALSE
    ))
    take_quantile <- function(probability) {
      quantiles[match(probability, requested_probs)]
    }

    if (!explicit_limits) {
      limits <- vapply(range_probs, take_quantile, numeric(1))
      if (limits[1L] == limits[2L]) {
        finite_range <- range(finite_population)
        if (finite_range[1L] < finite_range[2L]) {
          limits <- finite_range
          range_fallback <- paste(
            "automatic 0.1-99.9% limits collapsed; used the full finite range"
          )
        } else {
          limits <- .density_constant_range(finite_range[1L], nbins)
          range_fallback <- paste(
            "automatic 0.1-99.9% limits collapsed on constant data;",
            "used a finite padded interval"
          )
        }
      }
    }
    reference_values <- if (show_limits) {
      vapply(probs, take_quantile, numeric(1))
    } else {
      numeric()
    }
    rm(finite_population)
  } else {
    reference_values <- numeric()
  }

  breaks <- .density_breaks(limits, nbins)
  centres <- .density_midpoint(breaks[-length(breaks)], breaks[-1L])
  coordinate_geometry <- .density_coordinate_edges(cb$coordinates)

  H <- matrix(0L, nrow = nbins, ncol = nb)
  below <- above <- nonfinite <- finite <- kept <- numeric(nb)
  eligible <- rep(eligible_per_band, nb)
  for (band in seq_len(nb)) {
    band_values <- .cube_band(cb, band)
    values <- band_values[is.finite(band_values)]
    finite[band] <- length(values)
    nonfinite[band] <- eligible[band] - finite[band]
    below[band] <- sum(values < limits[1L])
    above[band] <- sum(values > limits[2L])
    index <- .bincode(values, breaks, right = TRUE, include.lowest = TRUE)
    index <- index[!is.na(index)]
    kept[band] <- length(index)
    if (length(index)) H[, band] <- tabulate(index, nbins = nbins)
  }
  if (!sum(finite)) {
    cli::cli_abort(paste(
      "The cube contains no finite eligible values",
      "(no finite values after mask exclusion)."
    ))
  }
  if (!sum(kept)) {
    cli::cli_abort(
      "No values: no finite eligible values fell inside {.arg limits}."
    )
  }
  if (any(finite != below + kept + above) ||
      any(eligible != finite + nonfinite)) {
    cli::cli_abort("Internal density accounting failed.")
  }

  shares <- matrix(NA_real_, nrow = nbins, ncol = nb)
  populated <- kept > 0
  shares[, populated] <- sweep(H[, populated, drop = FALSE], 2,
                               kept[populated], "/")
  displayed <- if (identical(normalise, "band")) shares else H
  density <- if (identical(transform, "log1p")) log1p(displayed) else displayed
  display_domain <- c(0, max(density, na.rm = TRUE))
  overlay <- .density_overlay(H, centres, limits, cb$coordinates)

  df <- data.frame(
    band = rep(seq_len(nb), each = nbins),
    coordinate = rep(cb$coordinates, each = nbins),
    wavelength = rep(cb$coordinates, each = nbins),
    xmin = rep(coordinate_geometry$edges[-length(coordinate_geometry$edges)],
               each = nbins),
    xmax = rep(coordinate_geometry$edges[-1L], each = nbins),
    value = rep(centres, times = nb),
    reflectance = rep(centres, times = nb),
    ymin = rep(breaks[-length(breaks)], times = nb),
    ymax = rep(breaks[-1L], times = nb),
    count = as.vector(H),
    share = as.vector(shares),
    density = as.vector(density)
  )

  coordinate_description <- if (cb$has_wavelengths) {
    sprintf("%s-%s nm", .density_number(min(cb$coordinates)),
            .density_number(max(cb$coordinates)))
  } else {
    sprintf("band-index coordinates 1-%d", nb)
  }
  range_note <- if (is.null(range_fallback)) {
    if (explicit_limits) "explicit range" else "automatic 0.1-99.9% range"
  } else {
    range_fallback
  }
  display_note <- if (identical(normalise, "band")) {
    sprintf(
      "%s display; normalised per band to retained shares; empty bands are missing",
      if (identical(transform, "identity")) "linear (identity)" else "log1p"
    )
  } else {
    sprintf("%s raw counts",
            if (identical(transform, "identity")) "linear (identity)" else "log1p")
  }
  reference_note <- if (show_limits) {
    coincident <- if (length(unique(reference_values)) == 1L) {
      "; coincident references share one line"
    } else {
      ""
    }
    sprintf(
      paste0(
        "Gold line(s): global raw eligible %s %s-%s%% percentiles [%s, %s] ",
        "from %s finite observations, including values outside the displayed ",
        "range; separate from image enhancement limits%s"
      ),
      value_label, .density_percent(probs[1L]), .density_percent(probs[2L]),
      .density_number(reference_values[1L]),
      .density_number(reference_values[2L]),
      format(global_population, big.mark = ","), coincident
    )
  } else {
    NULL
  }
  geometry_note <- coordinate_geometry$fallback
  caption <- .wrap_caption(paste(c(
    sprintf(
      "%d bins over [%s, %s] (%s); values outside dropped, not clipped; below %s, above %s, nonfinite %s",
      nbins, .density_number(limits[1L]), .density_number(limits[2L]),
      range_note, format(sum(below), big.mark = ","),
      format(sum(above), big.mark = ","),
      format(sum(nonfinite), big.mark = ",")
    ),
    sprintf("Display: %s", display_note),
    paste(
      "White binned mean and dashed binned 5-95% pixel envelope describe the retained pixel",
      "distribution and are not confidence intervals"
    ),
    geometry_note, reference_note
  ), collapse = ". "))

  subtitle <- sprintf(
    "%s retained pixel values over %d bands, %s",
    format(sum(kept), big.mark = ","), nb, coordinate_description
  )
  x_label <- if (cb$has_wavelengths) "wavelength (nm)" else "band index"
  plot <- .render_density(
    df, palette, display_domain, normalise, transform, overlay, show_limits,
    reference_values, subtitle, x_label, value_label, caption
  )

  provenance_overlay <- list(
    coordinate = overlay$coordinate, mean = overlay$mean,
    lower = overlay$lower, upper = overlay$upper, group = overlay$group,
    probabilities = c(0.05, 0.95),
    description = paste(
      "Binned mean and 5-95% envelope of the retained pixel distribution;",
      "not confidence intervals"
    )
  )
  global_references <- list(
    shown = show_limits, probs = probs, values = reference_values,
    population = if (show_limits) global_population else 0L,
    quantile_type = 7L,
    description = paste(
      "Global raw eligible input-value percentiles, including finite values",
      "outside the displayed range; separate from image enhancement limits"
    )
  )
  enhancement <- list(
    H = H, breaks = breaks, range = limits,
    range_source = if (explicit_limits) "explicit" else "automatic",
    range_probs = range_probs, fallback = range_fallback, quantile_type = 7L,
    eligible = eligible, finite = finite, nonfinite = nonfinite,
    below = below, kept = kept, above = above,
    overlay = provenance_overlay, global_references = global_references,
    normalisation = normalise, transform = transform,
    display_domain = display_domain
  )

  .attach_provenance(
    plot, cb,
    quantity = list(name = "spectral density", value_label = value_label),
    selection = list(
      band_indices = seq_len(nb), coordinates = cb$coordinates,
      coordinate_edges = coordinate_geometry$edges,
      coordinate_fallback = coordinate_geometry$fallback
    ),
    missingness = list(
      masked_spatial = .cube_info(cb)$excluded_spatial,
      eligible = eligible, finite = finite, nonfinite = nonfinite,
      below = below, kept = kept, above = above
    ),
    enhancement = enhancement, palette = palette,
    interpolation = FALSE, value_label = value_label
  )
}
