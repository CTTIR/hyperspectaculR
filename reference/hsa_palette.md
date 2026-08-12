# Perceptually Uniform Palettes for Spectral Imagery

Returns colour ramps suitable for scientific imagery. All options are
perceptually uniform and monotonic in lightness, so ordering survives
greyscale printing and is legible to colourblind readers — which rules
out the rainbow ramps that make striking but misleading figures.

## Usage

``` r
hsa_palette(
  name = c("viridis", "magma", "inferno", "plasma", "cividis", "mako", "rocket", "turbo"),
  n = 256L,
  direction = 1
)
```

## Arguments

- name:

  Palette name. One of `"viridis"`, `"magma"`, `"inferno"`, `"plasma"`,
  `"cividis"`, `"mako"`, `"rocket"`, `"turbo"`.

- n:

  Number of colours. Default `256`.

- direction:

  `1` (default) or `-1` to reverse.

## Value

A character vector of hex colours.

## Examples

``` r
head(hsa_palette("magma", n = 5))
#> [1] "#000004FF" "#51127CFF" "#B63679FF" "#FB8861FF" "#FCFDBFFF"
```
