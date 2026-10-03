# Within-Pixel Spectral Quartiles

An experimental descriptive composition with equal-band type-7 quartiles
computed over the measured bands within each spatial pixel.

## Usage

``` r
hsa_spectral_quartiles(
  cube,
  palette = "magma",
  stretch = c("percentile", "range", "none"),
  probs = c(0.02, 0.98),
  display_limits = c(0, 1),
  value_label = "input value",
  interpolate = TRUE
)
```

## Arguments

- cube:

  An `hsi_cube` (from hyperspectR) or a 3-D array with dimensions
  `(rows, cols, bands)`, of integer or double values. Optional
  `wavelengths` metadata must be finite, unique and strictly increasing
  in nm. Without it, coordinates are band indices. An optional logical
  spatial `mask` has dimensions `(rows, cols)` and no missing entries;
  `FALSE` excludes a pixel. Arrays may carry these as attributes; an
  `hsi_cube` may carry them as list fields. Nonfinite observations are
  excluded.

- palette:

  Palette name passed to
  [`hsa_palette()`](https://cttir.github.io/hyperspectaculR/reference/hsa_palette.md).

- stretch:

  Contrast stretch: `"percentile"` (default), `"range"` or `"none"`.

- probs:

  Percentiles for `stretch = "percentile"`. Default `c(0.02, 0.98)`.

- display_limits:

  Two increasing finite endpoints used as the fixed colour domain for
  `stretch = "none"`. Default `c(0, 1)`.

- value_label:

  A truthful label for the input values. Default `"input value"`. A
  reflectance label requires known upstream calibration; numeric range
  alone cannot establish calibration.

- interpolate:

  Logical; interpolate raster pixels. Default `TRUE`.

## Value

One faceted ggplot object, retaining raw panel values and provenance.

## Details

The panels are the 25th percentile, median and 75th percentile. Every
band must be finite and the pixel unmasked; validity is shared by all
panels. One band is allowed and gives three identical values. Bands have
equal weight, regardless of wavelength spacing. These summaries omit
spectral ordering, depend on sampling density, and are not confidence
intervals or uncertainty estimates. A single stretch pools the three
rendered raw panel values; all panels share its domain and legend. With
a stretch the legend labels display values on 0-1; with
`stretch = "none"` it labels raw input values in the supplied
`display_limits` domain.

## Examples

``` r
hsa_spectral_quartiles(hsa_demo_cube())
```
