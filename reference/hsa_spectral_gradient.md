# RMS Spectral Slope

An experimental descriptive image of the nonnegative RMS magnitude of
the wavelength derivative of each pixel's piecewise-linear spectrum.

## Usage

``` r
hsa_spectral_gradient(
  cube,
  palette = "inferno",
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

A ggplot object with raw values and original-rendering provenance.

## Details

For interval widths h = diff(wavelengths) and endpoint span L, G =
sqrt(sum(h \* (diff(x)/h)^2)/L). Values have input-value units per nm.
This is neither a signed derivative, a spatial gradient, nor
uncertainty. Short intervals and measurement noise can dominate the
result. Gaps in sampling bridge unresolved structure; no smoothing or
noise correction is applied. Physical wavelength metadata in nm and at
least two bands are required, with finite positive representable
intervals and span. A masked or incomplete spectrum is transparent;
missing bands are never bridged. Nonrepresentable requested arithmetic
raises an error.

## Examples

``` r
hsa_spectral_gradient(hsa_demo_cube())
```
