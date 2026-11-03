# Inspect Original Rendering Provenance

Returns the compact calculation and display record attached when a
hyperspectaculR plot was created. Later arbitrary ggplot modifications
may change the visible plot without updating this original-rendering
record. Ordinary `+ ggplot2::theme()` and `+ ggplot2::labs()` additions
preserve it. Inspect individual component plots before assembling a
patchwork; a combined patchwork has no single calculation record. Full
actual band selections, endpoints, fallback reasons, exclusions and
quantity definitions remain inspectable even when plot labels abbreviate
them. Source cubes and arbitrary input metadata are not retained in the
record.

## Usage

``` r
hsa_provenance(plot)
```

## Arguments

- plot:

  A plot returned by a hyperspectaculR renderer.

## Value

A compact named list describing the original rendering.
