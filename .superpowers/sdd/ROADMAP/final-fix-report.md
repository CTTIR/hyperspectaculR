# Final review fix report

Status: DONE. The three minor whole-branch review findings were corrected in
`9128b71a7165b88a9c48d0f9cd5d16c8cced4b16` (`Clarify density captions and
final evidence`). This report is committed separately so it can identify the
fix commit exactly.

## Changed files and outcomes

The fix commit contains exactly these 12 files:

* `planning/analysis-and-validation.md`, `planning/evidence/decisions.md`,
  `README.md` and `vignettes/hyperspectaculR.Rmd`: replaced the promise of full
  contributor counts with the exact retained summaries: selected-band count,
  minimum/maximum contributors, complete-pixel count and no-contributor-pixel
  count. The decision record states that individual pixel denominators cannot
  be recovered from provenance.
* `R/density.R`: the standalone caption now says `White binned mean and dashed
  binned 5-95% pixel envelope`, explicitly identifying both overlays as binned.
  No numerical calculation or provenance record changed.
* `tests/testthat/test-art.R`: added direct assertions for the two binned labels.
  `tests/testthat/test-density-foundation.R`: made two existing prose checks
  tolerant of caption wrapping between any adjacent words.
* `man/figures/gallery-density.png`,
  `showcase/synthetic-density_shares.png` and
  `tests/testthat/_snaps/visual-snapshots/irregular-density.svg`: regenerated
  the affected density visuals.
* `planning/evidence/benchmarks.csv`: replaced byte-for-byte with the reviewed
  26-record table. Only `baseline-density-auto`, `baseline-density-fixed` and
  `baseline-density-limits` changed relative to `4008008`; all now record
  revision `1df0bdde3762afd7e4f918c23c85250d512a59db` and clean source state.
* `planning/evidence/performance.md`: records that those three early rows were
  rerun with the same final harness rather than backfilled, identifies the
  separately preserved original records, and reports the refreshed audit
  medians/traffic/RSS with CSV precision: auto
  0.732 s/437.5005 MiB/652.5703 MiB, references
  1.219 s/1125.0012 MiB/837.9766 MiB, and fixed
  0.604 s/156.2502 MiB/568.8516 MiB. Large-input and image claims are unchanged.

## Caption assertions and rendering

The new caption assertions were first run against an archived `4008008` source
with the updated test copied in:

```sh
tmpdir=$(mktemp -d /tmp/hsa-final-red-XXXXXX)
git archive 4008008 | tar -x -C "$tmpdir"
cp tests/testthat/test-art.R "$tmpdir/tests/testthat/test-art.R"
NOT_CRAN=true HSA_REQUIRE_VDIFFR=1 Rscript -e '
  .libPaths(c("/tmp/hyperspectaculR-validation-library", .libPaths()))
  options(device=function(...) grDevices::pdf("/tmp/hsa-final-red-plots.pdf", ...))
  testthat::test_local(commandArgs(TRUE)[1], filter="art",
                       reporter="summary", stop_on_failure=TRUE)
' "$tmpdir"
```

Expected red result: exit 1, with two failures because the old caption contained
`White mean` and `dashed 5-95% pixel envelope`. The same filter on the corrected
worktree passed all 50 assertions.

Public synthetic artifacts were regenerated without optional recording input:

```sh
NOT_CRAN=true HSA_REQUIRE_VDIFFR=1 \
HSA_SHOWCASE_LAB_RDS= HSA_SHOWCASE_CUBERT_PATH= \
HSA_SHOWCASE_CLINICAL=0 HSA_SHOWCASE_CLINICAL_PATH= \
Rscript data-raw/make-showcase.R
```

SHA256 comparison with the pre-run artifacts found exactly two changes among
the 11 gallery/study PNGs and manifests: `gallery-density.png` and
`synthetic-density_shares.png`. Both manifests and all nine unrelated artifacts
were byte-identical. A second complete deterministic run reproduced all 11
post-change hashes byte-for-byte and created no optional laboratory/clinical
files. Both density PNGs are 1008 x 644 pixels, the expected 7.2 x 4.6 inches at
140 DPI. Direct visual inspection confirmed that the complete caption fits.

The rendering baseline was updated only after reviewing its textual SVG diff:

```sh
NOT_CRAN=true HSA_REQUIRE_VDIFFR=1 Rscript -e '
  .libPaths(c("/tmp/hyperspectaculR-validation-library", .libPaths()))
  options(device=function(...) grDevices::pdf("/tmp/hsa-final-visual-plots.pdf", ...))
  testthat::test_local(filter="visual-snapshots", reporter="summary",
                       stop_on_failure=TRUE)
'
Rscript -e '
  .libPaths(c("/tmp/hyperspectaculR-validation-library", .libPaths()))
  testthat::snapshot_accept("visual-snapshots/irregular-density.svg")
'
```

Before acceptance, the suite reported the one expected changed snapshot. The
reviewed diff changed only caption text and wrapping. After acceptance the four
visual assertions passed; `irregular-density.svg` changed and the other three
SVG baselines remained byte-identical.

## Evidence checks

An R comparison loaded the committed CSV, the supplied reviewed CSV and
`4008008:planning/evidence/benchmarks.csv`. It asserted exact equality with the
reviewed table, 26 rows, no missing revisions/source states, every
`source_dirty` value false, and exactly these changed records:

```sh
Rscript - <<'RS'
old_path <- tempfile(fileext = ".csv")
system2("git", c("show", "4008008:planning/evidence/benchmarks.csv"),
        stdout = old_path)
old <- read.csv(old_path, check.names = FALSE, na.strings = "NA")
new <- read.csv("planning/evidence/benchmarks.csv",
                check.names = FALSE, na.strings = "NA")
reviewed <- read.csv("/tmp/hyperspectaculR-benchmark-summary-reviewed.csv",
                     check.names = FALSE, na.strings = "NA")
stopifnot(identical(new, reviewed), nrow(new) == 26L,
          all(!is.na(new$revision)), all(!is.na(new$source_dirty)),
          all(!new$source_dirty))
changed <- old$record[vapply(seq_len(nrow(old)), function(i) {
  !identical(old[i, , drop = FALSE],
             new[match(old$record[i], new$record), , drop = FALSE])
}, logical(1))]
stopifnot(setequal(changed, c("baseline-density-auto",
                             "baseline-density-fixed",
                             "baseline-density-limits")))
cat("Records:", nrow(new), "; changed:", paste(changed, collapse = ", "), "\n")
RS
```

```text
baseline-density-auto, baseline-density-fixed, baseline-density-limits
```

The original early records remain in
`/tmp/hyperspectaculR-early-baseline-records`; their refreshed logs/RDS remain in
`/tmp/hyperspectaculR-benchmarks-final`. No unchanged benchmark or scientific
study was rerun. The only remaining CSV `NA` values are the older unrecorded
largest-allocation fields for baseline flux, fusion and mandala.

## Fresh verification

Full source suite, with rendering required rather than silently skipped:

```sh
NOT_CRAN=true HSA_REQUIRE_VDIFFR=1 Rscript -e '
  .libPaths(c("/tmp/hyperspectaculR-validation-library", .libPaths()))
  options(device=function(...) grDevices::pdf("/tmp/hsa-final-fix-test-plots.pdf", ...))
  testthat::test_local(reporter="summary", stop_on_failure=TRUE)
'
```

Result: `PASS 556 | FAIL 0 | WARN 0 | SKIP 0 | ERROR 0`.

The first full run after lengthening the caption found two failures in existing
checks whose regular expressions assumed spaces at particular wrap boundaries:
`separate from image enhancement` and `share one line`. The rendered text was
complete. The assertions were changed to accept whitespace between every word;
the counted full rerun above is the result after that correction.

House lint:

```sh
Rscript -e '
  .libPaths(c("/tmp/hyperspectaculR-validation-library", .libPaths()))
  source(".superpowers/sdd/ROADMAP/lint-cttir.R")
  lints <- lintr::lint_package(linters = cttir_linters())
  print(lints)
  if (length(lints)) quit(status = 1L)
'
```

Result: `No lints found`.

For the publication gate, the ignored existing `docs/` directory was moved to
`/tmp/hsa-final-fix-site-backup-o8uwHc/docs`. The candidate was installed into
the fresh isolated library `/tmp/hsa-final-fix-installed-xxcaYS`, and the site
was built into a clean generated output directory:

```sh
R CMD INSTALL --library=/tmp/hsa-final-fix-installed-xxcaYS .
Rscript -e '
  .libPaths(c("/tmp/hsa-final-fix-installed-xxcaYS",
              "/tmp/hyperspectaculR-validation-library", .libPaths()))
  Sys.setenv(R_LIBS=paste(.libPaths(), collapse=.Platform$path.sep),
             NOT_CRAN="true", HSA_REQUIRE_VDIFFR="1")
  pkgdown::build_site(new_process=FALSE, install=FALSE)
'
Rscript -e '
  .libPaths(c("/tmp/hsa-final-fix-installed-xxcaYS",
              "/tmp/hyperspectaculR-validation-library", .libPaths()))
  source("data-raw/prepare-site-evidence.R")
  source("data-raw/check-publication.R")
'
```

The source install and full pkgdown build completed. Publication results:

```text
Copied public evidence/source files: 53
Generated evidence links redirected to raw Markdown: 6
README local images resolved: 7
Built site local images resolved: 59 across 22 pages
Source Markdown links checked: 60; copied evidence links: 60; built page links: 483
```

Final `git diff --cached --check` passed. Effective Git configuration and the
fix commit both record author and committer as
`R. Heller <58561665+r-heller@users.noreply.github.com>`. No identity override,
service/model attribution or trailer was added.

No load-bearing local issue remains. All 11 hosted checks were green at
`4008008`; hosted checks and the scoped re-review of the corrected final head
remain coordinator-owned gates and are not claimed here.
