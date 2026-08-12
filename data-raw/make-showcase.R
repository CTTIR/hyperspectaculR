## Regenerate the showcase gallery.
##
## Run:  Rscript data-raw/make-showcase.R
##
## Requires local recordings, which are not distributed: TIVITA cubes under
## tivis.r/.data and Cubert sessions under cuvis.r/.data. Any subject that is
## missing is skipped with a note rather than failing, so the script still runs
## on a machine with only one instrument's data — or none, in which case it
## renders the synthetic demo cube alone.
##
## The previous gallery in this repository was rendered through a reader that
## misparsed the TIVITA container, so all 54 images were meaningless. It was
## deleted. This script exists so the gallery is reproducible and its
## provenance is checkable, rather than being a folder of images nobody can
## regenerate.

suppressMessages({
  library(ggplot2)
  devtools::load_all(".", quiet = TRUE)
})

OUT <- "showcase"
dir.create(OUT, showWarnings = FALSE)

WIDTH <- 7.2      # inches
HEIGHT <- 5.4
DPI <- 140        # ~1000 px wide: legible on a README, modest in a repository

save_fig <- function(plot, name, height = HEIGHT) {
  path <- file.path(OUT, paste0(name, ".png"))
  ggsave(path, plot, width = WIDTH, height = height, dpi = DPI)
  cat(sprintf("  %-34s %6.0f KB\n", basename(path), file.size(path) / 1024))
  invisible(path)
}

## ---- subjects -------------------------------------------------------------

subjects <- list()

tiv <- function(root, label) {
  f <- list.files(root, pattern = "SpecCube[.]dat$", recursive = TRUE,
                  full.names = TRUE)
  if (!length(f)) return(NULL)
  list(label = label, path = f[1], reader = "tivita")
}

cub <- function(root, label) {
  f <- list.files(root, pattern = "[.]cu3s$", recursive = TRUE, full.names = TRUE)
  f <- f[!grepl("dark|white|blank|_Dp_|_Dw_", basename(f), ignore.case = TRUE)]
  if (!length(f)) return(NULL)
  list(label = label, path = f[1], reader = "cubert")
}

## PUBLIC gallery subjects only.
##
## The TIVITA archives are clinical recordings — an open surgical field, a
## patient's foot. Rendering them to PNG does not make them publishable, so
## they are deliberately absent here: the committed gallery must not contain
## identifiable patient imagery. Set HSA_SHOWCASE_CLINICAL=1 to render them
## as well, for local review only; showcase/clinical/ is gitignored.
subjects$cubert <- cub("../cuvis.r/.data/lacie", "Cubert - laboratory scene")
subjects <- Filter(Negate(is.null), subjects)

clinical <- list()
if (nzchar(Sys.getenv("HSA_SHOWCASE_CLINICAL"))) {
  clinical$burn   <- tiv("../tivis.r/.data/burn",   "TIVITA - burn assessment")
  clinical$spinal <- tiv("../tivis.r/.data/spinal", "TIVITA - spinal cord")
  clinical <- Filter(Negate(is.null), clinical)
}

load_cube <- function(s) {
  if (!requireNamespace("hyperspectR", quietly = TRUE)) {
    cat("  ! hyperspectR is not installed; cannot read recordings.\n")
    return(NULL)
  }
  tryCatch(
    switch(s$reader,
      tivita = hyperspectR::hs_read_tivita(s$path, verbose = FALSE),
      cubert = hyperspectR::hs_read_cubert(s$path, verbose = FALSE)
    ),
    error = function(e) { cat("  ! skipped", s$label, "-", conditionMessage(e), "\n"); NULL }
  )
}

## ---- gallery --------------------------------------------------------------

cat("subjects found:", length(subjects), "\n\n")

for (nm in names(subjects)) {
  s <- subjects[[nm]]
  cat(s$label, "\n")
  cube <- load_cube(s)
  if (is.null(cube)) next

  save_fig(hsa_fusion(cube) + labs(title = paste0("Spectral fusion — ", s$label)),
           paste0(nm, "_fusion"))

  save_fig(hsa_spectral_flux(cube) + labs(title = paste0("Spectral flux — ", s$label)),
           paste0(nm, "_flux"))

  save_fig(hsa_mandala(cube, n_rings = 48) +
             labs(title = paste0("Spectral mandala — ", s$label)),
           paste0(nm, "_mandala"))

  # Shown with the stretch limits drawn on, because this is the figure the
  # others should be read against: it is the distribution their contrast
  # stretch is applied to. Shorter than the image panels -- it is a plot with
  # axes, not a square image.
  save_fig(hsa_spectral_density(cube, show_limits = TRUE) +
             labs(title = paste0("Spectral density — ", s$label)),
           paste0(nm, "_density"), height = 4.6)
}

## Clinical subjects, rendered locally only, never committed.
if (length(clinical)) {
  cdir <- file.path(OUT, "clinical")
  dir.create(cdir, showWarnings = FALSE)
  for (nm in names(clinical)) {
    s <- clinical[[nm]]
    cat(s$label, "(local only)\n")
    cube <- load_cube(s)
    if (is.null(cube)) next
    for (fn in c("hsa_fusion", "hsa_spectral_flux", "hsa_mandala")) {
      p <- do.call(fn, list(cube)) + labs(title = paste0(sub("^hsa_", "", fn), " - ", s$label))
      path <- file.path(cdir, sprintf("%s_%s.png", nm, sub("^hsa_", "", fn)))
      ggsave(path, p, width = WIDTH, height = HEIGHT, dpi = DPI)
      cat(sprintf("  %-34s %6.0f KB\n", file.path("clinical", basename(path)),
                  file.size(path) / 1024))
    }
  }
}

## Parameter studies on a non-clinical subject, so the gallery shows how the
## controls behave rather than only what the defaults produce.
ref <- if (length(subjects)) load_cube(subjects[[1]]) else hsa_demo_cube()
if (!is.null(ref)) {
  cat("parameter studies\n")
  save_fig(hsa_mandala(ref, n_rings = 6) + labs(subtitle = "6 rings - bold spectral banding"),
           "study_mandala_coarse")
  save_fig(hsa_mandala(ref, n_rings = 120) + labs(subtitle = "120 rings - continuous sweep"),
           "study_mandala_fine")
  save_fig(hsa_spectral_flux(ref, palette = "mako") + labs(subtitle = "mako palette"),
           "study_flux_mako")
  save_fig(hsa_fusion(ref, stretch = "range") +
             labs(subtitle = "full-range stretch rather than 2-98%"),
           "study_fusion_fullrange")
  save_fig(hsa_spectral_density(ref, normalise = "band") +
             labs(subtitle = "normalised per band, so sparsely sampled bands stay visible"),
           "study_density_perband", height = 4.6)
}

cat("\nwrote", length(list.files(OUT, pattern = "[.]png$")), "figures to", OUT, "\n")
cat("total", round(sum(file.size(list.files(OUT, full.names = TRUE))) / 1048576, 1), "MB\n")
