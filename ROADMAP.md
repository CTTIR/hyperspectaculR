This roadmap turns the 2026-09-10 audit of commit `1df0bdd` into a delivery plan for trustworthy hyperspectral figures and stronger analytical validation. The immediate objective is to correct the four existing compositions, make their transformations inspectable, and establish evidence that their outputs are scientifically interpretable.

Implementation has produced a **0.2.0 release candidate** on the feature branch. All implementation tasks, including publication assets and validation gates, have passed scoped reviews. The final whole-branch review and hosted-platform checks complete the release-evidence gate. The status tables below track delivery against the original specification. No release has been published.

Detailed definitions, recommended behaviour, numerical examples, and test fixtures are in [the analysis and validation plan](planning/analysis-and-validation.md). Adopted public arguments are implemented and documented; [decisions](planning/evidence/decisions.md), [audit closure](planning/evidence/audit-resolution.md), [sampling evidence](planning/evidence/sampling.md) and [performance evidence](planning/evidence/performance.md) record the outcome.

**Baseline and project direction**

The audit found 14 primary defects: one P1 and thirteen P2 findings. The existing 19 test blocks passed 48 assertions, and test coverage was 91.11%. `R CMD check --no-manual` passed with zero errors, warnings, or notes, including vignette rebuilding. Optional `vdiffr` was unavailable during that check. These are baseline observations, not evidence that the identified defects are fixed.

The project already has a useful scope: consume an `hsi_cube` or numeric array, use its spectral dimension, return a composable ggplot, and disclose image enhancement. Investment should make that contract reliable. Descriptive diagnostics that explain a rendering belong here; readers, calibration algorithms, tissue indices, and inferential models remain responsibilities of the related reader and analysis packages.

The strategic change is to move spectral gradient fields and spectral quartiles behind the correction and validation work. Their implementation should reuse a proven numerical and provenance foundation. The previously removed 3-D surfaces and band animations remain outside the planned product scope.

| Horizon | Outcome | Completion evidence |
|---|---|---|
| Now: M0–M2 | Correct inputs, validity handling, selection, and image enhancement | Small-cube regression tests establish the numerical and colour-scale contracts |
| Next: M3–M5 | Trustworthy diagnostics, reproducible figures, and a releasable package/site | All audit defects closed, rendering checks passing, memory benchmark recorded, package/site checks passing |
| Later: E1–E3 | Better comparisons and new spectral compositions | Each experiment proves its scientific meaning and user value before entering the release scope |

**Original capacity assumptions and delivery status**

The original planning estimates assumed one maintainer familiar with R and ggplot2, plus access to a domain reviewer for the scientific contracts. They include implementation, focused tests, and accompanying documentation. They exclude acquisition of recordings and vendor SDK troubleshooting. Owners below are roles to be assigned, not claims that a particular person has accepted work.

The original stabilization estimate was **15–25 focused engineering days**, or **18–30 days with a 20% contingency**. At three focused days per week, that is approximately **6–10 calendar weeks**. These were capacity hypotheses, not measured implementation time; future scheduling should use available capacity and the evidence collected here. Later experiments have separate estimates and are not included in these totals.

| Milestone | Owner | Effort | Dependencies | Status |
|---|---|---:|---|---|
| M0 — Record contracts and executable regression cases | Maintainer, with scientific review | 1–2 days | Audit baseline | Done |
| M1 — Validate cubes and preserve invalidity | Maintainer | 3–5 days | M0 | Done |
| M2 — Correct image calculations, geometry, and enhancement | Maintainer | 4–6 days | M1 | Done |
| M3 — Correct density diagnostics and expose provenance | Maintainer, with scientific review | 3–5 days | M1; M2 for shared enhancement metadata | Done |
| M4 — Bound memory, enforce checks, and repair documentation/site | Maintainer; shared-workflow owner where needed | 3–5 days | M2–M3 for final baselines | Done |
| M5 — Validate and prepare the release candidate | Maintainer | 1–2 days | M0–M4 | In Progress |

The critical sequence is **input/validity contract → calculations and display domains → trustworthy diagnostics → release evidence**. The gallery asset fix can be prepared after M0 without waiting for numerical changes; regenerated figures must use the final corrected implementation. CI test structure can also be prepared early, while final thresholds and snapshots wait for corrected behaviour.

**M0 — Turn the audit into a stable specification**

Deliverables:

- Assign the A01–A14 defect IDs below to focused regression cases. Preserve small deterministic inputs and observed failures in version control rather than depending on temporary audit files.
- Adopt the recommended contracts in the analysis plan, recording deviations and their compatibility consequences. Resolve the display-domain and partial-missing-band decisions before writing dependent rendering code.
- Split test responsibilities into validation, calculations, scales/geometry, and publication assets. Create only the files/helpers needed for these checks; avoid a broad source reorganisation.
- Capture installed dependency versions and baseline benchmark commands. Record the reviewed commit, fixture dimensions, seed, and measurement method with every numerical or memory comparison.
- Name the implementation owner and scientific reviewer. If only one maintainer is available, separate implementation and review passes and document that limitation.

Acceptance: every audit defect has a durable regression specification and a milestone; proposed behavioural changes are explicit; no new functionality is implied to exist. Regression cases should accompany their fixes on the main branch so the baseline remains usable.

**M1 — Establish a reliable input and validity contract**

Primary files: [R/cube-utils.R](R/cube-utils.R), validation at the public entry points in [R/art.R](R/art.R), and new focused tests under `tests/testthat/`.

- Validate numeric three-dimensional data, positive spatial/band dimensions, mask shape and type, and wavelength length/finiteness/order. Reject malformed metadata before any recycling, extraction, or plotting can occur.
- Preserve a distinction between physical wavelengths and fallback band indices. Wavelength selection requires physical coordinates; ordinary index-based plots remain available for arrays without metadata.
- Preserve the cube validity mask. Exclude invalid pixels from calculations, enhancement limits, density denominators, and image output. Do not mutate the caller's cube to apply the mask.
- Carry nonfinite validity through calculations and colour conversion. A missing pixel must not become an opaque RGB zero or a saturated endpoint.
- Implement and document a partial-band policy. The proposed default is propagation for image quantities requiring a complete selected spectrum; an explicitly selected available-case fusion mode may be retained with contribution counts. Density uses per-band finite observations and reports its denominators.
- Validate ordered two-element `probs`, nonempty integer band groups, finite two-element centres, and scalar positive integer counts. Produce argument-specific errors instead of downstream `seq_len()`, `rgb()`, or logical-condition failures.

Acceptance: A01, A03, A08, and A09 regressions pass; validated narrow inputs retain their dimensional metadata; excluded values cannot affect derived values or stretch limits; malformed metadata never silently recycles. Tests confirm unchanged caller data and RNG state. The fusion-specific extraction fix follows in M2.

Compatibility note: stricter errors and a stricter missing-data default can change previously accepted results. Document those changes with before/after examples in the 0.2.0 migration notes. Avoid silently changing the meaning of existing index selections by sorting data inside the adapter.

**M2 — Correct image calculations and disclose enhancement**

Primary files: [R/art.R](R/art.R), [R/cube-utils.R](R/cube-utils.R), their roxygen documentation, and calculation/rendering tests.

- Resolve default fusion thirds directly as indices. Apply wavelength-to-index conversion only to explicitly supplied wavelength vectors. Preserve rows-by-columns matrices for every channel, including singleton band selections and one-pixel-wide crops.
- Require at least three bands for automatically generated disjoint fusion groups. Continue allowing explicit overlapping groups when valid, and describe them accurately. Reject empty groups and fractional index values rather than truncating them.
- Correct the default mandala centre to `c((cols + 1) / 2, (rows + 1) / 2)`. Preserve the current band-index sampling in the stabilization release and describe it honestly. A later wavelength-target sampling option can be added separately.
- Keep spectral flux's existing total and mean-step calculations, while removing the claim that dividing by step count establishes comparability across different spectral samplings. Define the quantity and units in its caption.
- Separate stretch-limit calculation from value transformation. Return requested method, effective method, numerical endpoints, fallback reason, and clipped counts. Handle constant finite images and all-invalid images explicitly.
- Set explicit fill domains. Stretched values use `[0, 1]`; unscaled values use a declared display domain. Preserve raw values for `stretch = "none"` and disclose any colour mapping. Do not imply that preserving numeric values prevents ggplot from applying a visual range mapping.
- Retain the three fusion channels' numerical limits. Generate captions from the same structured enhancement record used to create the displayed values.

Acceptance: A02, A04, A10, A12, and A13 regressions pass; zero flux uses the dark endpoint; fixed-domain colours agree across figures; singleton selections work; every fallback is correctly described. Tests independently calculate band means, spectral steps, and clipping counts.

The source can gain small private helpers for selection, aggregation, and enhancement. Keep the existing exported plotting functions and ggplot return values; a general processing framework is unnecessary for four compositions.

**M3 — Make the density plot and analytical evidence trustworthy**

Primary files: density calculation and rendering in [R/art.R](R/art.R), private diagnostic helpers as needed, and [vignettes/hyperspectaculR.Rmd](vignettes/hyperspectaculR.Rmd).

- Preserve an integer count matrix before normalisation or display transforms. Record counts of masked, nonfinite, below-range, retained, and above-range observations, with per-band denominators.
- Define per-band shares as fractions of retained observations, and disclose that conditioning. An empty band has an undefined share, not evidence of a measured zero distribution.
- Back-transform legend labels for both raw counts and shares. Check both `identity` and `log1p` modes through the built scale's breaks and labels.
- Give irregular wavelengths truthful cell boundaries without shifting values. Preserve original band centres for overlays and avoid connecting the mean/envelope across completely invalid bands.
- Recover from collapsed automatically selected limits: use the finite range when nonconstant, or a disclosed narrow display interval for a constant cube. Continue rejecting malformed explicit limits.
- Keep `show_limits = TRUE` as global raw-value percentile references and rename its caption/documentation accordingly. Do not describe these lines as fusion, mandala, or flux stretch limits. A future image-specific comparison must use the distribution of the transformed quantity it describes.
- State that the mean and 5–95% envelope are calculated from the retained histogram and bin centres. The envelope describes the pixel distribution; it is not a confidence interval for the mean.
- Attach compact numerical provenance to each plot and provide a tested way to inspect it. Keep it independent of the visible caption and avoid retaining the original cube. Define behaviour after plot addition, theming, and composition before promising persistence.
- Explain calibrated reflectance assumptions. Where input units are unknown or are digital counts, support a truthful value label rather than inferring reflectance from a numeric array.

Acceptance: A05, A06, A07, and A11 regressions pass; histogram totals balance exactly; shares and legend inverses agree; the irregular-grid fixture renders without a shift warning; reference-line labels identify their actual source population. The scientific review checks the worked examples in the analysis plan.

**M4 — Improve memory use, regression protection, and publication assets**

Performance work:

- Compute percentile endpoints without constructing a discarded stretched cube. Reuse valid finite observations and, where practical, request automatic-range and reference-line quantiles together.
- When explicit density limits are supplied and reference lines are disabled, process bands without collecting another full-cube finite vector. State the different memory costs of explicit and automatic limits.
- Benchmark numeric computation and plot rendering separately. Record elapsed time, peak resident memory, large-allocation traffic, input dimensions, and versions. Preserve exact numerical results before attempting approximation or parallel execution.
- Inspect fusion aggregation and mandala selection only after the density allocation fix is measured. Optimise demonstrated costs without obscuring the simple formulas.

Regression and compatibility work:

- Add independent small-cube numerical assertions and a small set of stable rendering checks. Include transparency, colour domains, irregular geometry, and one-pixel dimensions. Use visual snapshots for a few representative layouts, with numerical assertions as the primary oracle.
- Set the shared coverage input to an initial **90% floor** after the corrected suite establishes a reproducible baseline. This is a guard against large losses, not the definition of analytical correctness. Investigate the unused `.band_index()` helper instead of adding tests solely to increase its reachability.
- Resolve the current house-linter findings and enable blocking lint. Keep numerical repairs separate from unnecessary formatting changes.
- Test the actual declared R minimum, currently `R >= 4.1.0`, and the dependency minimums needed by the implementation. If that combination is not supportable, update the declaration with evidence and migration notes. A moving `oldrel` job does not prove a fixed minimum.
- Continue using the shared CTTIR check/lint/coverage workflows. Cross-repository matrix or linter changes belong in the shared workflow; record that dependency. Package-specific rendering and asset checks can live in the package tests or its site workflow as appropriate.

Publication work:

- Move or explicitly copy the three public gallery images into a pkgdown-supported asset location and repair the website gallery link. Add useful alt text and a built-site assertion that local image/link targets exist.
- Regenerate public figures from the corrected version using deterministic recipes. Record the recording identifier/checksum, reader/version, selected bands, dimensions, and rendering arguments for reproducibility. Public examples and CI must remain usable with synthetic fixtures; private clinical recordings are not a release prerequisite.
- Correct the README, vignette, generated help, NEWS, DESCRIPTION, and Zenodo metadata together. Describe only implemented capabilities. Preserve the existing public/clinical separation in the showcase script.
- Check the independent showcase problems: `HSA_SHOWCASE_CLINICAL=1` should have an explicit documented interpretation, and unavailable recordings/readers should fall back to a synthetic example where the script promises one. Cover those small control-flow cases without accessing private recordings.

Acceptance: A14 is closed; gallery assets resolve in a fresh build; captions fit supported export sizes; exact diagnostic results survive the memory changes; tests, lint, and coverage enforcement pass. Relative benchmark targets and the compatibility matrix are specified in the analysis plan.

**M5 — Prepare a release supported by evidence**

- Reconcile the A01–A14 ledger and the supplementary items below. A defect is closed only when its numerical or rendering acceptance case passes and its relevant documentation agrees.
- Run the corrected suite, coverage, supported-platform/minimum-version checks, package examples, vignettes, and `R CMD check`. Include PDF manual generation in an environment with the required tooling. Explain any external-tool exclusion rather than reporting it as passed.
- Build the site from a clean output directory. Verify local assets before deployment and verify the three gallery URLs after an authorized deployment.
- Review changed figures at their intended export sizes and resolutions. Record deliberate appearance changes from validity masks, fixed colour domains, and corrected geometry.
- Prepare release notes and a migration guide covering missingness, input validation, constant data, wavelength assumptions, and `stretch = "none"`. Update version/citation metadata consistently when creating the actual release candidate.
- Assemble an evidence record containing the tested commit, environment, test/check results, benchmark comparison, and resolved defect IDs. Tag or publish only from that verified state using the maintainer's configured identity.

Acceptance: all stabilization release gates in the analysis plan pass, documentation reflects the final implementation, and there are no unresolved P1/P2 findings from this audit in the release scope. Release publication is a later action, not part of creating this roadmap.

**Audit traceability**

The identifiers retain the ordering of the original audit. Counts and memory figures below are dated observations, not future performance promises.

| ID | Priority | Defect and affected code | Owner milestone | Required evidence |
|---|---|---|---|---|
| A01 | P1 | `.as_cube()` discards the spatial mask | M1 | 2 × 2 × 3 fixture with one invalid spatial pixel contributes 9 observations, and its pixel is transparent |
| A02 | P2 | Default fusion indices are reinterpreted as wavelengths | M2 | Default groups are identical for either `by` value; hand-calculated RGB means agree |
| A03 | P2 | Inf clips to endpoints and missing RGB becomes zero | M1 | Nonfinite/masked pixels cannot produce a saturated or opaque false measurement |
| A04 | P2 | Automatic fill scaling contradicts enhancement claims | M2 | Explicit domains, consistent cross-figure mapping, dark zero flux, honest raw-value captions |
| A05 | P2 | Density reference lines are misidentified as image stretch limits | M3 | Global references are labelled as global; transformed quantities are not conflated |
| A06 | P2 | Log-transformed shares receive untransformed legend labels | M3 | A retained share of 1 is labelled 1 or 100%, not `log(2)` |
| A07 | P2 | Irregular wavelengths shift density raster columns | M3 | Counts occupy the correct band intervals, overlays retain the supplied coordinates, and no raster shift warning occurs |
| A08 | P2 | Invalid wavelength metadata silently recycles | M1 | Short, nonfinite, duplicate, and unordered wavelength vectors are rejected clearly |
| A09 | P2 | Fallback band indices are labelled as nanometres | M1 | Unannotated arrays display band indices and cannot use explicit wavelength selections |
| A10 | P2 | Singleton fusion extraction drops spatial dimensions | M2 | 1 × N, N × 1, and 1 × 1 inputs work with single-band channel selections |
| A11 | P2 | Automatic density limits reject constant/sparse finite cubes | M3 | Constant and nearly all-zero cubes render with disclosed fallback intervals |
| A12 | P2 | Fusion loses all six numerical stretch endpoints | M2 | Caption/provenance contains the actual R/G/B endpoints |
| A13 | P2 | Full-range fallback is called a percentile stretch | M2 | Collapsed-quantile fixture reports the effective method and fallback reason |
| A14 | P2 | Three public gallery images return 404 | M4 | Assets exist in fresh site output and resolve after deployment |

| Supplementary item | Planned treatment | Milestone |
|---|---|---|
| Default mandala centre is half a pixel off | Correct centre and test symmetry on odd/even dimensions | M2 |
| Mandala is linear in index rather than wavelength | Document current index sampling; reserve a separate option for wavelength targets | M2, E2 |
| Mean spectral step is falsely claimed comparable across band counts | Correct claim, give worked counterexample, evaluate a separate wavelength-aware measure | M2, E1 |
| Weak validation of `probs`, groups, centres, and counts | Add explicit contracts and argument-specific errors | M1 |
| RGB with `stretch = "none"` has an undocumented domain | Make domain explicit and reject unhandled out-of-domain data clearly | M2 |
| Density allocates a discarded stretched cube for reference lines | Compute limits alone; benchmark allocation traffic and peak memory separately | M4 |
| Release metadata describes removed capabilities | Rewrite metadata to match the corrected package | M4–M5 |

**Proposed review units**

Each unit should include its own focused regression tests and relevant documentation. Avoid merging an expectation of known failure into the shared main branch. PR creation is not part of this planning change.

| Order | Reviewable change | Depends on | Main acceptance cases |
|---|---|---|---|
| 1 | Cube/argument validation and explicit coordinate kind | M0 contracts | A08, A09, malformed arguments |
| 2 | Mask, nonfinite, and partial-missing policy | 1 | A01, A03, caller-state invariance |
| 3 | Fusion selection and dimension preservation | 2 | A02, A10, known channel means |
| 4 | Enhancement metadata, colour domains, truthful captions | 2–3 | A04, A12, A13, RGB range |
| 5 | Mandala centring and flux/sampling documentation | 2, 4 | Symmetry, step formulas, units |
| 6 | Density counts, geometry, limits, legends, and provenance | 2, 4 | A05–A07, A11, denominator balance |
| 7 | Allocation improvements and benchmark evidence | 6 | Numerical equivalence and allocation targets |
| 8 | Site assets, docs, and enforceable CI/compatibility checks | Numerical contracts stable; asset paths can be fixed earlier | A14, local assets, coverage/lint/check matrix |
| 9 | Migration notes and release candidate evidence | 1–8 | Complete defect ledger and release gates |

**Later analytical and product improvements**

The requested full implementation evaluated these initiatives after the core contracts and independent definitions were stable. The candidate includes E1/E2 as explicitly limited descriptive APIs and resolves E3 with the exact fixed-limit path; no approximate quantile mode is introduced.

| Initiative | Purpose and proposed deliverable | Effort hypothesis | Dependency | Success criterion | Status |
|---|---|---:|---|---|---|
| E1 — Comparable spectral summaries | Evaluate total variation per wavelength span, explicit common-grid comparisons, and shared display domains across recordings | 3–5 days | M1–M5 | Synthetic examples establish units, sampling assumptions, and failure cases; no claim of sampling invariance without evidence | Done |
| E2 — New compositions | Prototype wavelength-target mandalas, a precisely defined spectral-gradient composition, and spectral quartile displays | 5–10 days | M1–M5; define quantities first | Each candidate defines its multispectral quantity, discloses degenerate single-band cases, and passes numerical/geometry tests; export decisions are recorded | Done |
| E3 — Larger-data diagnostic path | Evaluate chunked exact histograms with fixed limits; consider explicit reproducible approximate quantiles only if measured need remains | 3–5 days | M4 benchmarks | Demonstrated memory improvement with documented exactness or measured approximation error and sampling provenance | Done |

For E2, define whether “gradient” means differentiation along wavelength or a spatial gradient of a spectral summary before designing a figure. For “quartiles”, define whether the population is wavelengths within a pixel or pixels within a band. These are different quantities and must not share an ambiguous label.

**Risks, decisions, and maintenance cadence**

| Risk/dependency | Consequence | Response and owner |
|---|---|---|
| Missingness/display-domain defaults change appearance | Existing figures and scripts can change despite valid input | Maintainer records proposed defaults in M0; version and migration notes explain changes; retain explicit alternatives where meaningful |
| Scientific reviewer unavailable | A numerical implementation can still carry misleading semantics | Ship only quantities with documented, independently checked definitions; keep E1/E2 exploratory until reviewed |
| Shared CI changes require cross-repository coordination | Fixed-minimum R or blocking rules may not be available immediately | Shared-workflow owner supplies reusable support; maintainer records local evidence and does not claim missing CI coverage |
| Exact quantiles require memory proportional to valid observations | Default automatic limits can remain expensive on large cubes | Improve avoidable copies first; document exact cost; add an explicit approximate path only after E3 evidence |
| Snapshot differences across platforms/devices | Fragile visual tests can become routinely ignored | Use numerical scale/geometry assertions first and a small, controlled snapshot set |
| No distributable real fixture for an instrument | Instrument integration cannot be independently reproduced in CI | Use realistic synthetic fixtures; run optional local integration checks and report their coverage separately |
| Scope growth from new compositions or a broad refactor | Correctness fixes slip | Include only the reviewed descriptive extensions requested here; extract calculation helpers required by the numerical contracts |

Review progress after each review unit and at least weekly during implementation. Update status from **Not Started** to **In Progress**, **Blocked**, or **Done**, with the evidence or dependency beside it. A test passing because it reproduces the implementation's own calculation is insufficient evidence. Reopen a closed defect if later rendering or integration checks invalidate its contract.

The release decision should follow corrected behaviour and reproducible evidence. Coverage percentages, attractive gallery images, and successful workflow badges are supporting signals rather than substitutes for that evidence.
