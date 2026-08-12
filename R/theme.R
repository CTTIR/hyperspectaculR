#' A Theme for Hyperspectral Figures
#'
#' A dark, chrome-free theme for image-like panels. Axes, grids and panel
#' backgrounds are removed, because for a rendered scene they carry no
#' information and compete with the image.
#'
#' Deliberately standalone: it does not require \pkg{hyperspectR}, so figures
#' can be produced anywhere a cube is available, while remaining visually
#' compatible with `hyperspectR::theme_hsi()`.
#'
#' @param base_size Base font size in points. Default `11`.
#' @param base_family Font family. Default `""` (the device default), which
#'   keeps figures portable; set it explicitly when embedding fonts for a
#'   journal.
#' @param background Panel and plot background colour. Default `"#0B0B0F"`.
#' @param ink Foreground colour for text. Default `"#E8E8EC"`.
#'
#' @return A \pkg{ggplot2} theme object.
#'
#' @examples
#' library(ggplot2)
#' ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point() + hsa_theme()
#'
#' @export
hsa_theme <- function(base_size = 11, base_family = "",
                      background = "#0B0B0F", ink = "#E8E8EC") {
  ggplot2::theme_void(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.background   = ggplot2::element_rect(fill = background, colour = NA),
      panel.background  = ggplot2::element_rect(fill = background, colour = NA),
      legend.background = ggplot2::element_rect(fill = background, colour = NA),
      legend.key        = ggplot2::element_rect(fill = background, colour = NA),
      text              = ggplot2::element_text(colour = ink),
      plot.title        = ggplot2::element_text(
        colour = ink, size = base_size * 1.25, hjust = 0,
        margin = ggplot2::margin(b = 4)
      ),
      plot.subtitle     = ggplot2::element_text(
        colour = scales::alpha(ink, 0.7), size = base_size * 0.9, hjust = 0,
        margin = ggplot2::margin(b = 8)
      ),
      plot.caption      = ggplot2::element_text(
        colour = scales::alpha(ink, 0.55), size = base_size * 0.75, hjust = 1,
        margin = ggplot2::margin(t = 8)
      ),
      legend.text       = ggplot2::element_text(colour = scales::alpha(ink, 0.8)),
      legend.title      = ggplot2::element_text(colour = ink),
      plot.margin       = ggplot2::margin(12, 12, 12, 12)
    )
}


#' Perceptually Uniform Palettes for Spectral Imagery
#'
#' Returns colour ramps suitable for scientific imagery. All options are
#' perceptually uniform and monotonic in lightness, so ordering survives
#' greyscale printing and is legible to colourblind readers — which rules out
#' the rainbow ramps that make striking but misleading figures.
#'
#' @param name Palette name. One of `"viridis"`, `"magma"`, `"inferno"`,
#'   `"plasma"`, `"cividis"`, `"mako"`, `"rocket"`, `"turbo"`.
#' @param n Number of colours. Default `256`.
#' @param direction `1` (default) or `-1` to reverse.
#'
#' @return A character vector of hex colours.
#'
#' @examples
#' head(hsa_palette("magma", n = 5))
#'
#' @export
hsa_palette <- function(name = c("viridis", "magma", "inferno", "plasma",
                                 "cividis", "mako", "rocket", "turbo"),
                        n = 256L, direction = 1) {
  name <- match.arg(name)
  if (identical(name, "turbo")) {
    cli::cli_warn(c(
      "{.val turbo} is not monotonic in lightness.",
      "i" = "It reads well on screen but loses ordering in greyscale; prefer
             {.val viridis} or {.val magma} for print."
    ))
  }
  cols <- viridisLite::viridis(n, option = name)
  if (direction < 0) rev(cols) else cols
}
