render_environments <- function(plot) {
  environments <- list(plot$plot_env)
  add_mapping <- function(mapping) {
    if (is.null(mapping)) return(invisible(NULL))
    for (item in mapping) {
      if (rlang::is_quosure(item)) {
        environments[[length(environments) + 1L]] <<- rlang::get_env(item)
      }
    }
    invisible(NULL)
  }
  add_mapping(plot$mapping)
  for (layer in plot$layers) add_mapping(layer$mapping)

  callback_fields <- c("labels", "breaks", "minor_breaks", "rescaler",
                       "oob", "palette")
  for (scale in plot$scales$scales) {
    for (field in callback_fields) {
      callback <- scale[[field]]
      if (is.function(callback)) {
        environments[[length(environments) + 1L]] <- environment(callback)
      }
    }
  }

  environments <- Filter(is.environment, environments)
  retained <- list()
  for (environment in environments) {
    while (!identical(environment, emptyenv()) && !isNamespace(environment)) {
      if (!any(vapply(retained, identical, logical(1), environment))) {
        retained[[length(retained) + 1L]] <- environment
      }
      environment <- parent.env(environment)
    }
  }
  retained
}

render_binding_names <- function(plot) {
  unique(unlist(lapply(render_environments(plot), ls, all.names = TRUE),
                use.names = FALSE))
}

expect_compact_render_environments <- function(plot) {
  calculation_bindings <- c(
    "cube", "cb", "buffers", "finite_population", "out", "acc", "raw",
    "enhancement", "common_valid", "band_values", "values"
  )
  retained <- intersect(render_binding_names(plot), calculation_bindings)
  expect_true(!length(retained), info = paste(retained, collapse = ", "))
}
