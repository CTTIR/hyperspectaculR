# A Theme for Hyperspectral Figures

A dark, chrome-free theme for image-like panels. Axes, grids and panel
backgrounds are removed, because for a rendered scene they carry no
information and compete with the image.

## Usage

``` r
hsa_theme(
  base_size = 11,
  base_family = "",
  background = "#0B0B0F",
  ink = "#E8E8EC"
)
```

## Arguments

- base_size:

  Base font size in points. Default `11`.

- base_family:

  Font family. Default `""` (the device default), which keeps figures
  portable; set it explicitly when embedding fonts for a journal.

- background:

  Panel and plot background colour. Default `"#0B0B0F"`. A fixed-aspect
  image does not fill a device of another shape, and the remaining
  device area keeps the device background.
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
  uses this colour automatically; for other devices and for 'knitr'
  chunks (`dev.args = list(bg = "#0B0B0F")`), set the device background
  to the same colour.

- ink:

  Foreground colour for text. Default `"#E8E8EC"`.

## Value

A ggplot2 theme object.

## Details

Deliberately standalone: it does not require hyperspectR, so figures can
be produced anywhere a cube is available, while remaining visually
compatible with
[`hyperspectR::theme_hsi()`](https://cttir.github.io/hyperspectR/reference/theme_hsi.html).

## Examples

``` r
library(ggplot2)
ggplot(faithfuld, aes(waiting, eruptions, fill = density)) +
  geom_raster() +
  scale_fill_gradientn(colours = hsa_palette("magma")) +
  labs(title = "Old Faithful eruptions", caption = "Dark image-panel theme") +
  hsa_theme()

```
