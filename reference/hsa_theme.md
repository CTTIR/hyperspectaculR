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

  Panel and plot background colour. Default `"#0B0B0F"`.

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
ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point() + hsa_theme()

```
