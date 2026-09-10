# Numeric contracts remain primary. Release validation sets both flags below;
# old-ggplot compatibility intentionally disables only this rendering baseline.
visual_snapshots_enabled <- function() {
  if (identical(Sys.getenv("HSA_REQUIRE_VDIFFR"), "1")) {
    if (!requireNamespace("vdiffr", quietly = TRUE)) {
      cli::cli_abort("Release rendering validation requires vdiffr.")
    }
    if (!identical(Sys.getenv("NOT_CRAN"), "true")) {
      cli::cli_abort("Release snapshots require NOT_CRAN=true to prevent automatic skips.")
    }
    if (identical(Sys.getenv("HSA_VDIFFR"), "0")) {
      cli::cli_abort("Release rendering validation cannot disable snapshots.")
    }
  }
  skip_if(identical(Sys.getenv("HSA_VDIFFR"), "0"),
          "Rendering baseline deliberately excluded on this compatibility leg")
  skip_if_not_installed("vdiffr")
}

visual_fixture <- function() {
  cube <- hsa_demo_cube(rows = 5, cols = 6, bands = 6, seed = 42)
  cube$wavelengths <- c(500, 502, 507, 520, 550, 600)
  cube$mask <- matrix(TRUE, 5, 6)
  cube$mask[2:3, 3:4] <- FALSE
  cube$data[4, 2, 3] <- NA_real_
  cube
}

snapshot_theme <- function(plot) {
  # Missing cells are deliberate; silence only the raster removal notification.
  plot$layers[[1L]]$geom_params$na.rm <- TRUE
  plot + ggplot2::theme(text = ggplot2::element_text(family = "sans"))
}

test_that("transparent scalar images retain their rendering", {
  visual_snapshots_enabled()
  vdiffr::expect_doppelganger("transparent mandala", snapshot_theme(
    hsa_mandala(visual_fixture(), n_rings = 4, interpolate = FALSE)))
})

test_that("fusion retains transparent pixels and compact labels", {
  visual_snapshots_enabled()
  vdiffr::expect_doppelganger("grouped fusion", snapshot_theme(
    hsa_fusion(visual_fixture(), interpolate = FALSE)))
})

test_that("irregular density and shared quartile geometry retain their rendering", {
  visual_snapshots_enabled()
  vdiffr::expect_doppelganger("irregular density", snapshot_theme(
    hsa_spectral_density(visual_fixture(), nbins = 8, show_limits = TRUE)))
  vdiffr::expect_doppelganger("shared quartile panels", snapshot_theme(
    hsa_spectral_quartiles(visual_fixture(), interpolate = FALSE)))
})
