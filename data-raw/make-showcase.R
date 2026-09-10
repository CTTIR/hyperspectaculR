# Regenerate public synthetic figures from the checked-out package.
# Run from the repository root: Rscript data-raw/make-showcase.R
# Optional local inputs are explicit paths, never discovered automatically.
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(hyperspectaculR)
}

write_provenance <- function(value, path) {
  text <- utils::capture.output(dput(value))
  writeLines(sub("[[:blank:]]+$", "", text), path)
}

save_gallery <- function(cube, directory, prefix = "gallery", label = "Synthetic demo") {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  plots <- list(
    mandala = hsa_mandala(cube, n_rings = 12, interpolate = FALSE),
    flux = hsa_spectral_flux(cube, interpolate = FALSE),
    fusion = hsa_fusion(cube, interpolate = FALSE),
    density = hsa_spectral_density(cube, nbins = 64, show_limits = TRUE),
    gradient = hsa_spectral_gradient(cube, interpolate = FALSE),
    quartiles = hsa_spectral_quartiles(cube, interpolate = FALSE)
  )
  for (name in names(plots)) {
    ggplot2::ggsave(
      file.path(directory, paste0(prefix, "-", name, ".png")), plots[[name]],
      width = if (name == "quartiles") 9 else 7.2,
      height = switch(name, density = 4.6, quartiles = 4.2, 5.4),
      dpi = 140, bg = "#101014"
    )
  }
  records <- list(
    source = label,
    seed = if (identical(label, "Synthetic demo")) 42L else NULL,
    package_version = as.character(utils::packageVersion("hyperspectaculR")),
    export = list(dpi = 140, ordinary_inches = c(7.2, 5.4),
                  density_inches = c(7.2, 4.6), quartiles_inches = c(9, 4.2)),
    renderings = lapply(plots, hsa_provenance)
  )
  write_provenance(records, file.path(directory, paste0(prefix, "-provenance.R")))
  invisible(plots)
}

# Public outputs always use the same synthetic fixture, including studies.
cube <- hsa_demo_cube(rows = 48, cols = 64, bands = 24, seed = 42)
save_gallery(cube, "man/figures")
studies <- list(
  density_shares = hsa_spectral_density(cube, nbins = 64, normalise = "band"),
  raw_domain = hsa_mandala(cube, n_rings = 8, stretch = "none",
                          display_limits = c(-1, 1), interpolate = FALSE),
  physical_flux = hsa_spectral_flux(cube, normalization = "wavelength_span",
                                   interpolate = FALSE)
)
dir.create("showcase", showWarnings = FALSE)
for (name in names(studies)) {
  ggplot2::ggsave(file.path("showcase", paste0("synthetic-", name, ".png")),
                  studies[[name]], width = 7.2,
                  height = if (name == "density_shares") 4.6 else 5.4, dpi = 140)
}
write_provenance(lapply(studies, hsa_provenance), "showcase/synthetic-study-provenance.R")

# Real integration is local and optional. Range is not proof of calibration.
load_optional <- function(path, reader) {
  tryCatch({
    if (reader == "rds") return(readRDS(path))
    if (!requireNamespace("hyperspectR", quietly = TRUE)) {
      cli::cli_abort("Optional recording reader hyperspectR is unavailable.")
    }
    quiet <- TRUE
    switch(reader,
      cubert = hyperspectR::hs_read_cubert(path, verbose = !quiet),
      tivita = hyperspectR::hs_read_tivita(path, verbose = !quiet)
    )
  }, error = function(error) {
    message("Optional local input skipped: ", conditionMessage(error))
    NULL
  })
}
render_optional <- function(path, reader, directory, label) {
  if (!nzchar(path)) return(invisible(NULL))
  optional <- load_optional(path, reader)
  if (is.null(optional)) return(invisible(NULL))
  tryCatch(save_gallery(optional, directory, prefix = "local", label = label),
           error = function(error) message("Optional rendering skipped: ", conditionMessage(error)))
}
render_optional(Sys.getenv("HSA_SHOWCASE_LAB_RDS"), "rds", "showcase/laboratory",
                "Optional nonclinical laboratory input; calibration unspecified")
render_optional(Sys.getenv("HSA_SHOWCASE_CUBERT_PATH"), "cubert", "showcase/laboratory",
                "Optional nonclinical Cubert input; calibration unspecified")
# Both an exact opt-in and an explicit path are required for local clinical use.
if (identical(Sys.getenv("HSA_SHOWCASE_CLINICAL"), "1")) {
  render_optional(Sys.getenv("HSA_SHOWCASE_CLINICAL_PATH"), "tivita", "showcase/clinical",
                  "Local clinical review; calibration unspecified")
}
message("Synthetic gallery and studies regenerated.")
