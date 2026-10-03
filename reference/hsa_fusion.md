# Multi-Band Spectral Fusion

Builds a colour composite by equally averaging three groups of measured
bands. Averaging may reduce independent band noise but does not
calibrate values. Explicit groups may overlap; singleton groups are
allowed, including identical channels from one band. Each channel uses
its own stretch.

## Usage

``` r
hsa_fusion(
  cube,
  red = NULL,
  green = NULL,
  blue = NULL,
  by = c("index", "wavelength"),
  stretch = c("percentile", "range", "none"),
  probs = c(0.02, 0.98),
  display_limits = c(0, 1),
  value_label = "input value",
  interpolate = TRUE,
  missing = c("propagate", "available")
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

- red, green, blue:

  Integer vectors of band indices, or numeric wavelengths in nm when
  `by = "wavelength"`. `NULL` (default) splits the spectrum into three
  contiguous thirds, long wavelengths to red.

- by:

  Either `"index"` (default) or `"wavelength"`.

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

- missing:

  Missing-band policy. `"propagate"` (default) requires every selected
  band; `"available"` averages the finite contributors in a group.

## Value

A ggplot2 object.

## Examples

``` r
cube <- hsa_demo_cube()
hsa_fusion(cube)

```
