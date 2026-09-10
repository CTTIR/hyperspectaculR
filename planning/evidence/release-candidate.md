The prepared package is **hyperspectaculR 0.2.0**, available for review in [draft pull request #3](https://github.com/CTTIR/hyperspectaculR/pull/3). The final package-source correction is `9128b71`: it clarifies the density caption, regenerates only the affected density figures, makes contributor-summary documentation precise and refreshes three baseline benchmark records. No numerical calculation changed in that correction. A fresh full package check on the same packaged source at `e5f930a` passes with 0 errors, 0 warnings and 0 notes. Later handoff edits update evidence and remove process scratch. The release is not tagged, merged or published; public-site deployment and live-URL checks follow an authorized release/deployment action.

| Gate | Result and evidence |
|---|---|
| Numerical and rendering suite | 556 passing assertions at `9128b71`, zero failures/warnings/skips on R 4.6.1 with ggplot2 4.0.3; includes all four vdiffr SVG baselines. |
| Full package check | 0 errors, 0 warnings, 0 notes; package examples, rebuilt vignette and PDF manual included. |
| Coverage | 95.43% at the preceding numerical-source checkpoint; reusable CI now enforces a 90% floor. |
| House lint | Zero findings; reusable lint is blocking. |
| Exact R minimum, current plotting | Local checkpoint `d0baf4a`: R 4.1.0 + ggplot2 4.0.3 + patchwork 1.3.2: 554 passing assertions, all four SVG baselines, no failures/warnings/skips. |
| Exact R and selected ggplot minimum | Local checkpoint `d0baf4a`: R 4.1.0 + ggplot2 3.4.0 + patchwork 1.1.3: 550 passing numerical assertions, no failures/warnings; three rendering blocks (four SVG baselines) deliberately excluded. Enabled, disabled and unavailable-package gates preserve all four baseline files byte-for-byte. |
| Public figures | All 11 synthetic gallery/study artifacts reproduce byte-for-byte; six principal figures visually checked at intended export sizes. Captions and legends fit. |
| Site assets | Fresh pkgdown output resolves all required local images, page/file links and copied evidence/source links; final evidence refresh checked separately. |
| Scientific interpretation | Independent [sampling study](sampling.md) (8,080 realizations) and [histogram study](density-resolution.md) (120 band/settings records) preserve definitions, exclusions and limitations. |
| Performance | [26 benchmark records](benchmarks.csv), comprising 12 baseline and 14 candidate cases, compare time, allocation and RSS using the same protocol. [Tradeoffs are explicit](performance.md). |
| Optional instrument integration | [Eight local Cubert renderings](laboratory-integration.md) build without warnings and preserve the input object; reader diagnostic and unavailable instrument/clinical coverage are separately disclosed. |
| Scoped implementation review | All four implementation tasks passed scoped reviews; the final snapshot/site integration fixes were independently re-reviewed. |
| Whole-branch review | The complete `1df0bdd..4008008` change received 0 Critical, 0 Important and 3 Minor findings. One consolidated correction addressed contributor-summary wording, binned-density labels and benchmark source traceability; scoped re-review of `4008008..e5f930a` passed specification and quality checks, with all three findings addressed and no new breakage or residual observations. |
| Remote platforms | All 11 hosted checks passed at `4008008`: six shared R/platform checks, two exact-minimum combinations, lint, coverage and pkgdown. The corrected branch receives the same gates; its current head and results are visible in [the pull-request checks](https://github.com/CTTIR/hyperspectaculR/pull/3/checks). |

Hosted validation covers macOS release R, Windows release R, and Ubuntu development, release, oldrel-1 and oldrel-3 R. The two additional jobs use exact R 4.1.0 with current ggplot2 and ggplot2 3.4.0. A green earlier checkpoint is identified by its SHA above; the pull-request checks identify the tested current head.

The current rendering baseline uses vdiffr 1.0.9. It runs on both tested R versions without a rendering mismatch. The old ggplot2 leg tests built geometry, scales, numerical values and explicit patchwork composition support, while excluding the newer SVG layout baseline. This is a selected compatible dependency combination, not a promise that every historical package-version combination works. Current patchwork 1.3.2 cannot load with ggplot2 3.4.0; the old-ggplot leg therefore pins patchwork 1.1.3.

The main host was Ubuntu 26.04, x86_64, R 4.6.1, ggplot2 4.0.3, testthat 3.3.2, covr 3.6.5, lintr 3.4.0, pkgdown 2.2.1 and roxygen2 8.0.0. Exact-minimum checks used R 4.1.0 in an isolated Ubuntu 20.04.5 container based on `rocker/r-ver:4.1.0`, base image digest `sha256:d165d8e7da614a2b7182eb6f296417588e122e089235fe76cd67f85a0e62df21`. Dependencies were installed in separate libraries; no global host library was changed for these checks. The [minimum workflow](../../.github/workflows/minimum-compatibility.yaml) records the supported installation recipe.

Reproduction commands, run from the repository root with the stated dependencies installed:

```r
Sys.setenv(NOT_CRAN = "true", HSA_REQUIRE_VDIFFR = "1")
testthat::test_local(reporter = "summary", stop_on_failure = TRUE)
covr::percent_coverage(covr::package_coverage())
Sys.setenv(R_TEXI2DVICMD = "emulation")
rcmdcheck::rcmdcheck(path = ".", args = character(), error_on = "never")
```

`R_TEXI2DVICMD=emulation` selects R's internal TeX driver because this host has TinyTeX/pdflatex and makeindex but no external texi2dvi. The final check produced a PDF manual successfully. The initial check's namespace and worktree-.git NOTEs were fixed before the clean rebuild; they are not outstanding exclusions. House lint uses the same CTTIR linter definition as the reusable workflow.

For a fresh site, install the candidate into an isolated library and propagate that library to article child processes, then run:

```r
pkgdown::build_site(new_process = FALSE, install = FALSE)
source("data-raw/prepare-site-evidence.R")
source("data-raw/check-publication.R")
```

The explicit evidence-copy step includes only public text/SVG source paths and repairs pkgdown's unresolved evidence `.html` links to the copied Markdown. The checker validates target files rather than internal heading fragments. Private/optional recording output is excluded. [Audit resolution](audit-resolution.md), [adopted decisions](decisions.md) and the [migration guide](../../README.md#migrating-to-020) define the visible changes and compatibility consequences.

The existing published site remains outside this local candidate validation. No release tag, deployment, physiological validation, instrument calibration or TIVITA/clinical integration is represented as completed by these results.
