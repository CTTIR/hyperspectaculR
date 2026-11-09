## Submission

This is a new submission.

## Test environments

* local: macOS (aarch64), R 4.6.1 — `R CMD check --as-cran --no-manual`
  (no LaTeX installation available locally, hence `--no-manual`; the PDF
  manual still needs to be checked, e.g. on win-builder, before submission)
* GitHub Actions (r-lib/actions v2, `--as-cran`):
  * macOS-latest (release)
  * windows-latest (release)
  * ubuntu-latest (devel, release, oldrel-1)
* GitHub Actions: R 4.1.0 (the declared minimum) with ggplot2 3.4.0 and with
  current ggplot2

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'R. Heller <raban.heller@uni-ulm.de>'

  New submission

  Suggests or Enhances not in mainstream repositories:
    hyperspectR, tivis.r
  Availability using Additional_repositories specification:
    hyperspectR   yes   https://cttir.r-universe.dev
    tivis.r       yes   https://cttir.r-universe.dev

  This is the first submission of this package. `hyperspectR` and `tivis.r`
  are optional companion packages (the data model and a camera reader of the
  same suite) published at <https://cttir.r-universe.dev>, which is declared
  in `Additional_repositories`. No code in the package, its examples, tests
  or vignette requires them; hyperspectaculR accepts their `hsi_cube`
  objects through a duck-typed adapter, and the package checks cleanly
  without them.

## Notes for the reviewer

* Visual regression tests use 'vdiffr', which skips them on CRAN.

## Downstream dependencies

There are currently no downstream dependencies on CRAN.
