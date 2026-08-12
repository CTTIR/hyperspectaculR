# Radial Spectral Mandala

Renders the scene as concentric annuli, each drawn from a different
wavelength: the innermost ring shows the shortest wavelength, the
outermost the longest. The result is a single image that sweeps the
spectral axis outward from a chosen centre.

## Usage

``` r
hsa_mandala(
  cube,
  centre = NULL,
  n_rings = 36L,
  palette = "magma",
  stretch = c("percentile", "range", "none"),
  probs = c(0.02, 0.98)
)
```

## Arguments

- cube:

  An `hsi_cube` (from hyperspectR) or a 3-D array with dimensions
  `(rows, cols, bands)`.

- centre:

  Numeric length-2 vector `c(x, y)` in pixels. `NULL` (default) uses the
  image centre.

- n_rings:

  Number of annuli. Default `36`. More rings sample the spectrum more
  finely; fewer give bolder banding.

- palette:

  Palette name passed to
  [`hsa_palette()`](https://cttir.github.io/hyperspectaculR/reference/hsa_palette.md).

- stretch:

  Contrast stretch: `"percentile"` (default), `"range"` or `"none"`.

- probs:

  Percentiles for `stretch = "percentile"`. Default `c(0.02, 0.98)`.

## Value

A ggplot2 object.

## Details

This exploits the spectral dimension rather than decorating a single
band, which is what distinguishes it from an ordinary false-colour
rendering. The radius-to-wavelength mapping is linear and reported in
the caption, so the figure remains readable as data.

## Examples

``` r
cube <- hsa_demo_cube()
hsa_mandala(cube, n_rings = 12)

```
