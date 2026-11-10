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

## Examples

``` r
p <- hsa_fusion(hsa_demo_cube())
record <- hsa_provenance(p)
names(record)
#>  [1] "schema_version"  "package_version" "cube"            "quantity"       
#>  [5] "selection"       "missingness"     "enhancement"     "palette"        
#>  [9] "interpolation"   "value_label"    
record$selection
#> $by
#> [1] "index"
#> 
#> $default
#> [1] TRUE
#> 
#> $red
#> $red$requested
#> [1] 17 18 19 20 21 22 23 24
#> 
#> $red$indices
#> [1] 17 18 19 20 21 22 23 24
#> 
#> $red$coordinates
#> [1] 580 585 590 595 600 605 610 615
#> 
#> 
#> $green
#> $green$requested
#> [1]  9 10 11 12 13 14 15 16
#> 
#> $green$indices
#> [1]  9 10 11 12 13 14 15 16
#> 
#> $green$coordinates
#> [1] 540 545 550 555 560 565 570 575
#> 
#> 
#> $blue
#> $blue$requested
#> [1] 1 2 3 4 5 6 7 8
#> 
#> $blue$indices
#> [1] 1 2 3 4 5 6 7 8
#> 
#> $blue$coordinates
#> [1] 500 505 510 515 520 525 530 535
#> 
#> 
```
