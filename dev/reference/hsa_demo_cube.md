# A Small Demonstration Cube

A deterministic synthetic cube for examples and tests, shaped like an
`hsi_cube` so the art functions can be demonstrated without hyperspectR
or any recorded data.

## Usage

``` r
hsa_demo_cube(rows = 48L, cols = 64L, bands = 24L, seed = 42L)
```

## Arguments

- rows, cols:

  Spatial dimensions. Default `48` by `64`.

- bands:

  Number of bands. Default `24`.

- seed:

  Random seed. Default `42`.

## Value

A list with `data` and `wavelengths`, classed as `hsi_cube`.

## Examples

``` r
cube <- hsa_demo_cube()
dim(cube$data)
#> [1] 48 64 24
```
