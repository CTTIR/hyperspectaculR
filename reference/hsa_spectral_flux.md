# Cumulative Spectral Change

Sums the absolute change between consecutive bands at every pixel,
giving a field of total spectral variability. Flat spectra appear dark;
pixels whose reflectance swings across the spectrum appear bright.

## Usage

``` r
hsa_spectral_flux(
  cube,
  palette = "inferno",
  normalise = TRUE,
  stretch = c("percentile", "range", "none"),
  probs = c(0.02, 0.98)
)
```

## Arguments

- cube:

  An `hsi_cube` (from hyperspectR) or a 3-D array with dimensions
  `(rows, cols, bands)`.

- palette:

  Palette name passed to
  [`hsa_palette()`](https://cttir.github.io/hyperspectaculR/reference/hsa_palette.md).

- normalise:

  Logical. Divide by the number of band steps, so the value is a mean
  absolute step rather than a total. Default `TRUE`, which makes cubes
  with different band counts comparable.

- stretch:

  Contrast stretch: `"percentile"` (default), `"range"` or `"none"`.

- probs:

  Percentiles for `stretch = "percentile"`. Default `c(0.02, 0.98)`.

## Value

A ggplot2 object.

## Details

Unlike a single-band image this cannot be produced from any one
wavelength, and unlike a variance map it is sensitive to the ordering of
the bands, so it responds to spectral shape rather than spread alone.

## Examples

``` r
cube <- hsa_demo_cube()
hsa_spectral_flux(cube)

```
