.package_version <- function() {
  tryCatch(as.character(utils::packageVersion("hyperspectaculR")),
           error = function(...) "development")
}

.enhancement_record <- function(stretch) {
  stretch[setdiff(names(stretch), "values")]
}

.attach_provenance <- function(plot, cube, quantity, selection, missingness,
                               enhancement, palette, interpolation,
                               value_label) {
  record <- list(
    schema_version = "1.0",
    package_version = .package_version(),
    cube = .cube_info(cube),
    quantity = quantity,
    selection = selection,
    missingness = missingness,
    enhancement = enhancement,
    palette = palette,
    interpolation = interpolation,
    value_label = value_label
  )
  attr(plot, "hsa_provenance") <- record
  plot
}

#' Inspect Original Rendering Provenance
#'
#' Returns the compact calculation and display record attached when a
#' hyperspectaculR plot was created. Later arbitrary ggplot modifications may
#' change the visible plot without updating this original-rendering record.
#' Ordinary `+ ggplot2::theme()` and `+ ggplot2::labs()` additions preserve it.
#' Inspect individual component plots before assembling a patchwork; a combined
#' patchwork has no single calculation record. Full actual band selections,
#' endpoints, fallback reasons, exclusions and quantity definitions remain
#' inspectable even when plot labels abbreviate them. Source cubes and arbitrary
#' input metadata are not retained in the record.
#'
#' @param plot A plot returned by a hyperspectaculR renderer.
#'
#' @return A compact named list describing the original rendering.
#' @export
hsa_provenance <- function(plot) {
  if (inherits(plot, "patchwork")) {
    cli::cli_abort(
      "A patchwork combines plots; inspect provenance on each individual component plot."
    )
  }
  record <- attr(plot, "hsa_provenance", exact = TRUE)
  if (is.null(record)) {
    cli::cli_abort("{.arg plot} has no hyperspectaculR provenance record.")
  }
  record
}
