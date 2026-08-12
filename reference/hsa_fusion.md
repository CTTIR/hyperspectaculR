# Multi-Band Spectral Fusion

Builds a colour composite by averaging three *groups* of bands rather
than picking three single wavelengths. Averaging suppresses per-band
sensor noise and yields smoother, more saturated images than a
three-band composite, while remaining a straightforward and disclosable
operation.

## Usage

``` r
hsa_fusion(
  cube,
  red = NULL,
  green = NULL,
  blue = NULL,
  by = c("index", "wavelength"),
  stretch = c("percentile", "range", "none"),
  probs = c(0.02, 0.98)
)
```

## Arguments

- cube:

  An `hsi_cube` (from hyperspectR) or a 3-D array with dimensions
  `(rows, cols, bands)`.

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

## Value

A ggplot2 object.

## Examples

``` r
cube <- hsa_demo_cube()
hsa_fusion(cube)

```
