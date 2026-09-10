# Run one benchmark case in a fresh process so peak RSS is attributable to it.
# Example:
# /usr/bin/time -v Rscript data-raw/benchmark.R . density_limits audit result.rds
# Cases: density_auto, density_limits, density_fixed, fusion, flux, mandala,
# gradient, quartiles. Sizes: demo, audit, large. Three repetitions plus warmup.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  cli::cli_abort("Usage: benchmark.R <package directory> <case> <size> <output.rds>")
}
package_dir <- normalizePath(args[1L], mustWork = TRUE)
case <- match.arg(args[2L], c(
  "density_auto", "density_limits", "density_fixed", "fusion", "flux",
  "mandala", "gradient", "quartiles"
))
size <- match.arg(args[3L], c("demo", "audit", "large"))
output <- args[4L]
pkgload::load_all(package_dir, quiet = TRUE)

dimensions <- switch(size, demo = c(48L, 64L, 24L),
                     audit = c(256L, 320L, 100L), large = c(640L, 480L, 100L))
render <- switch(case,
  density_auto = function(x) hsa_spectral_density(x),
  density_limits = function(x) hsa_spectral_density(x, show_limits = TRUE),
  density_fixed = function(x) hsa_spectral_density(x, limits = c(-0.1, 1)),
  fusion = hsa_fusion,
  flux = hsa_spectral_flux,
  mandala = hsa_mandala,
  gradient = function(x) hsa_spectral_gradient(x),
  quartiles = function(x) hsa_spectral_quartiles(x)
)

profile_call <- function(expr) {
  profile <- tempfile(fileext = ".Rprofmem")
  on.exit(unlink(profile), add = TRUE)
  Rprofmem(profile, threshold = 1000000)
  on.exit(Rprofmem(NULL), add = TRUE)
  timing <- system.time(value <- force(expr), gcFirst = FALSE)
  Rprofmem(NULL)
  allocations <- suppressWarnings(as.numeric(sub(" .*", "", readLines(profile))))
  list(value = value, elapsed = unname(timing["elapsed"]),
       allocated_mib = sum(allocations, na.rm = TRUE) / 2^20)
}

pdf_file <- tempfile(fileext = ".pdf")
grDevices::pdf(pdf_file, width = 7.2, height = 5.4)
warm <- render(hsa_demo_cube(rows = 8L, cols = 10L, bands = 6L))
invisible(ggplot2::ggplotGrob(warm))
rm(warm)
cube <- hsa_demo_cube(rows = dimensions[1L], cols = dimensions[2L],
                      bands = dimensions[3L], seed = 42L)
results <- vector("list", 3L)
for (i in seq_len(3L)) {
  invisible(gc())
  preparation <- profile_call(render(cube))
  drawing <- profile_call({
    grob <- ggplot2::ggplotGrob(preparation$value)
    grid::grid.newpage()
    grid::grid.draw(grob)
    invisible(NULL)
  })
  results[[i]] <- data.frame(
    repetition = i, prepare_seconds = preparation$elapsed,
    prepare_allocated_mib = preparation$allocated_mib,
    draw_seconds = drawing$elapsed, draw_allocated_mib = drawing$allocated_mib
  )
  rm(preparation, drawing)
}
grDevices::dev.off()
unlink(pdf_file)
record <- list(
  case = case, size = size, dimensions = dimensions, seed = 42L,
  input_mib = as.numeric(object.size(cube$data)) / 2^20,
  package_version = as.character(utils::packageVersion("hyperspectaculR")),
  ggplot2_version = as.character(utils::packageVersion("ggplot2")),
  package_directory = package_dir,
  revision = system2("git", c("-C", shQuote(package_dir), "rev-parse", "HEAD"),
                     stdout = TRUE),
  source_status = system2("git", c("-C", shQuote(package_dir), "status", "--short",
                                   "--", "R", "DESCRIPTION", "NAMESPACE"),
                          stdout = TRUE),
  allocation_threshold_bytes = 1000000,
  measurements = do.call(rbind, results), session = utils::sessionInfo()
)
saveRDS(record, output)
cat(case, size, "input MiB", record$input_mib, "\n")
print(record$measurements, row.names = FALSE)
cat("Medians:\n")
print(vapply(record$measurements[-1L], stats::median, numeric(1)))
