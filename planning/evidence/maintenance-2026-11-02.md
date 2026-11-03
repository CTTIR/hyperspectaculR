# Maintenance candidate — 2 November 2026

Status: locally validated development candidate, not a published release. Baseline
`eb3067ad4e2101db0b1f2d820cf4d9d1715d9f5f`; original clean checkout and its
140 tracked files are preserved. Work occurs on an isolated maintenance branch.

## Purpose and acceptance criteria

Keep the package focused on descriptive, inspectable spectral figures. A user
must be able to install the package with its declared dependencies, pass a valid
cube without hidden metadata changing the calculation, inspect original plot
provenance, and export readable standalone or explicitly arranged compositions.
No recording reader, calibration, physiology or clinical qualification is added.

1. **Essential input repairs:** match fields exactly, require wavelength vectors,
   and compare unnamed dimension sizes. Reject malformed coordinates before
   selection; preserve supported masks, singleton geometry and caller data.
   Independent small-cube oracles and baseline-failing regressions are required.
2. **Numerical consistency:** repair reproducible subnormal interpolation and
   RMS-slope errors with bounded changes. Retain ordinary-scale definitions,
   histogram accounting and existing rendering snapshots. Validate exact tiny
   fixtures and rescaling comparisons rather than mirroring implementation.
3. **Dependable first use and publication:** document dependency installation,
   a visually checked two-panel layout, exact metadata contracts and current
   merged/publication status. Preserve prior provenance and published assets.
4. **Release evidence:** full/minimal package checks, numerical and rendering
   tests, existing 90% coverage floor, house lint, fresh gallery/site/manual,
   source-archive contents and executable first use. Distinguish local evidence
   from hosted candidate checks, exact minimum dependency qualification and
   scientific/instrument adoption.

New renderers, general plotting abstractions, a broad numerical rewrite and
additional readers remain outside this maintenance scope. Invalid theme-style
arguments are lower priority than the scientific input and arithmetic findings.

## Baseline observations

- Initial check: missing optional `vdiffr`; three rendering test errors were
  environment failures. Installing it into the isolated audit library restored
  **556 passing assertions, zero failures/errors/warnings/skips**, including all
  four SVG baselines, on macOS ARM/R 4.6.1 and ggplot2 4.0.3.
- Full baseline check after that installation: **0 errors, 0 warnings, 2 notes**.
  One note covers new-submission/non-mainstream Suggests and the unavailable DOI;
  the other identifies an audit-generated `Rplots.pdf`. That rendering artifact
  is preserved outside the source tree; source-build exclusion is added.
- The README `R CMD INSTALL .` succeeds when this machine's site library supplies
  dependencies, but fails with genuinely isolated empty user/site libraries:
  cli, ggplot2, rlang, scales and viridisLite are absent. The revised first-use
  path must install declared dependencies explicitly.
- Matrix-shaped wavelengths bypassed vector ordering checks; partial list field
  matching could apply unrelated masking metadata. Named dimensions caused
  valid masks to be rejected and malformed dimension names in provenance.
- Independent exact subnormal fixtures expose early-rounding errors in density
  interpolation, type-7 quantiles and RMS spectral slope. These are extreme-data
  defects, not observed ordinary hyperspectral acquisition failures.
- viridisLite 0.3.0 satisfied the old dependency declaration but warned and
  substituted viridis for mako, rocket and turbo while provenance retained the
  requested name. The new minimum is 0.4.0, independently exercised with all
  eight palettes and real plot builds.
- Ordinary side-by-side plots at 7.2 inches have overlapping fixed-width labels;
  an explicit, tested publication arrangement is needed.

The published baseline's hosted checks succeeded, with observed test coverage
95.43%. Those results do not describe this unpushed maintenance candidate.

## Publication metadata

The previously recorded identifier `10.5281/zenodo.21889974` returned HTTP 404
both through the DOI resolver and the public Zenodo records API on 2 November
2026. This does not establish whether a private draft or reservation exists.
It remains here as historical provenance; the candidate citation and README no
longer present it as a confirmed published DOI. Confirm a public record and its
version before restoring it to citation metadata. No DOI has been invented.

Pull request #3 merged on 3 October 2026. No release tag or GitHub release was
observed at the current check. Historical review records retain their original
checkpoint claims with a dated status clarification.

## Completed repairs and independent review

| Finding and impact | Priority | Change and evidence |
| --- | --- | --- |
| Partial list matching could silently use unrelated masking metadata; matrix wavelengths bypassed the vector ordering contract. | Essential | Exact field access and early vector validation in `R/cube-utils.R`; malformed inputs now fail before selection. Named dimensions retain valid geometry and stable provenance keys. |
| Early rounding at subnormal scales changed density midpoints, type-7 quantiles and RMS spectral slope. | Essential | Bounded interpolation and denominator repairs in `R/cube-utils.R`, `R/density.R` and `R/spectral-summary.R`. Independent exact arithmetic, ordinary-scale comparisons and baseline-failing public-API fixtures verify the definitions. |
| The old declared palette minimum could substitute a different palette while provenance named the requested one. | Essential | Require viridisLite 0.4.0; all eight palettes, reversal and actual plot fills were exercised with that exact minimum. |
| Dark website styling inverted scientific images, changing the palette and intensity ordering visible to users. | Essential | `pkgdown/extra.css` preserves R-plot and homepage gallery colors in both themes. Five actual figures in two themes pass 200 exact source-PNG pixel comparisons and 1,886 luminance-order checks. Logos and saved data images retain their original behavior. |
| Dependency-free first use failed; narrow compositions overlapped labels; article figures lacked alternatives. | Everyday use | Verified dependency-install commands, a rendered two-panel recipe with unchanged component provenance, and seven accurate figure descriptions. |
| Public citation and release claims exceeded observed publication state; local graphics output entered a source archive. | Release preparation | Corrected citation/status records and excluded default `Rplots.pdf` output at every directory depth. Prior DOI and historical records remain traceable. |

Core calculations, tests and all source changes received an independent review.
The numerical repair deliberately retains the ordinary arithmetic path. In a
one-million-value benchmark, ordinary input took 14.60 ms versus 14.95 ms before
the change, with the same 12 MB total measured R allocation. Zero-heavy input
took 14.25 ms versus 8.55 ms and 24 MB versus 12 MB total allocation because it
requires a second partial sort. These are individual benchmark observations,
not peak-memory guarantees. The bounded extra work is accepted to preserve
correct quantiles without changing the numerical definition or broadly
rescaling mixed populations.

## Final verification

Observed on macOS ARM, R 4.6.1 and ggplot2 4.0.3:

- Direct suite: **646 passing assertions, zero failures, errors, warnings or
  skips**, including the four rendering baselines. Separate independent probes
  include 11,025 exact interpolation cases, 132 input/geometry/RNG checks and
  284 gradient, quartile and density comparisons. Twenty-four ordinary workflows
  preserve baseline plot data, labels and full non-version provenance.
- Final source archive, full and optional-dependency-limited `R CMD check
  --as-cran`: **0 errors, 0 warnings, 1 note** each. The incoming note identifies
  a new/development submission and optional packages available through the
  declared additional repository. It is not an acceptance result.
- Test coverage: **1,236 / 1,291 lines = 95.74%**, above the existing 90% floor.
  Current shared house lint and workflow syntax checks pass. No useful checks,
  assertions or coverage requirements were removed or weakened.
- Fresh user and site libraries: exact documented installation commands install
  the package and all 17 required external dependencies. Four installed README
  plots render without warnings; all 51 installed function bodies/formals match
  the source. The source-install route used Apple clang 21, the macOS 27 SDK and
  make. Optional composition, article and recording-reader packages were absent.
- The full synthetic showcase runs with recording paths unset. Baseline and
  candidate under the same current environment produce **nine byte-identical
  PNGs** and matching non-version provenance. Historical published images differ
  from both new runs because the rendering environment changed; they and their
  original records are preserved rather than relabelled as new outputs.
- The actual final 13-page manual matches the independently inspected candidate
  in text, every word coordinate, navigation and fonts. All pages were visually
  reviewed. The development website passes seven real browser flows and 24
  desktop/mobile views without page, request, image or horizontal-overflow
  defects. Loaded-index search passes, subject to the limitation below.
- The archive contains 79 files, no default graphics-device output or local
  audit paths. Its 67 R/test/manual inputs match the reviewed candidate. Original
  checkout contents (140 tracked files) and 45 published image/provenance files
  are unchanged.

Final archive: `hyperspectaculR_0.2.0.9001.tar.gz`, 2,062,729 bytes,
SHA256 `68ec54bbe228f9897263cfbe55bf969d6840610b8b5e2cb3a903513623a8e4bc`.
The site CSS and this maintenance record are repository sources intentionally
excluded from the R distribution archive.

## First use

Use R >= 4.1.0 and the dependencies declared in `DESCRIPTION`. The commands
below were actually exercised on R 4.6.1 with a working source compiler; other
platforms may supply prebuilt R packages. From the candidate checkout:

```sh
Rscript -e 'install.packages("remotes", repos = "https://cloud.r-project.org")'
Rscript -e 'remotes::install_local(".", dependencies = NA, upgrade = "never", build_vignettes = FALSE)'
Rscript -e 'library(hyperspectaculR); p <- hsa_mandala(hsa_demo_cube(seed = 42)); ggplot2::ggsave("mandala.png", p, width = 8, height = 7)'
Rscript data-raw/make-showcase.R
```

Leave optional recording-path variables unset for synthetic reproduction.
Article rebuilding additionally requires knitr, rmarkdown and Pandoc;
two-panel composition requires patchwork. Inspect `hsa_provenance(p)` on an
individual plot to recover its original selection and display record.

## Remaining gates and deferred work

- Candidate hosted CI, Windows and exact minimum R/ggplot2 combinations have not
  run. The previous public baseline's passing matrix does not qualify these
  unpushed changes. Exact minimum viridisLite 0.4.0 was tested locally.
- A pkgdown first-focus/paste query can run before its asynchronous search index
  finishes loading; editing after loading produces results. Ordinary loaded-index
  search passed. Replacing shared search JavaScript is deferred to shared-site
  maintenance. The scientific-image inversion also requires a scoped assessment
  of other generated sites; this audit establishes the repair for this site.
- No clinical, calibrated-instrument or scientific-adoption qualification is
  implied. New renderers, additional readers and broad architecture changes
  remain outside this release. Theme-argument polish is lower-priority work.
- The candidate remains a development version. Before publication, run the
  candidate hosted matrix, select its distribution version, verify any DOI
  record and citation metadata, and prepare the release from that exact commit.
  Submission/deployment and external acceptance have not occurred.

Exact logs, commands, environment details and preserved hashes are in the
sibling local maintenance evidence directory, including `verification.json`,
`SITE-REVIEW.md`, `MANUAL-REVIEW.md`, the independent numerical reviews and the
clean first-use/gallery records. Original and excluded working sessions remain
untouched. No commit publication, release, submission or deployment occurred.

## Hosted-site follow-up, 2026-11-03

After publication of commit `690e4c3`, the hosted pkgdown run `41604995010`
failed on the ROADMAP link to this record. The development site was built in
`docs/dev`, while the subsequent evidence-copy and validation scripts defaulted
to `docs`. Earlier local verification supplied `docs/dev` explicitly, so it did
not exercise the hosted invocation.

Both scripts now resolve the default destination through pkgdown's project
configuration. Explicit command-line destinations retain their existing behavior.
A disposable-project regression exercises development, release and explicit
destinations through the workflow's `source()` calls; each also checks that a
genuinely missing link is rejected. The workflow runs this regression before
building the site.

The former failure was reproduced locally. The corrected complete hosted build
sequence passed, copying 60 public evidence/source files, correcting the one
evidence link and checking 507 built page links. House lint and workflow syntax
validation passed. These are local results; the subsequent exact-commit hosted
run must be observed separately. This fix changes site publication scripts and
their regression coverage, without changing rendering or numerical package APIs.
