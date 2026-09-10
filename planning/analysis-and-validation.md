This document specifies the scientific and numerical work behind the [project roadmap](../ROADMAP.md). It is based on the 2026-09-10 audit of `1df0bdd`. The adopted contracts are implemented in the 0.2.0 candidate. [Recorded decisions](evidence/decisions.md), [audit regressions](evidence/audit-resolution.md), [sampling experiments](evidence/sampling.md), [histogram study](evidence/density-resolution.md), and [performance measurements](evidence/performance.md) distinguish completed evidence from future work. Current help pages define the exact public signatures; the requirements below remain the numerical validation specification.

The intended result is a figure whose source population, computed quantity, exclusion rules, coordinate system, and display enhancement can be recovered and tested. Descriptive summaries should help users understand their data and the rendering. The package should not infer a physiological interpretation or instrument failure from a visually unusual pattern alone.

**1. Input, coordinates, and validity**

Represent a cube as `X[row, col, band]`. Its spatial validity mask is `M[row, col]`, and optional physical band coordinates are `lambda[band]` in nanometres. A value is eligible for use only when its spatial mask is true and its numeric value is finite. An absent mask means all spatial positions are eligible; nonfinite values remain invalid.

Adopted input contract:

| Input | Adopted rule | Reason |
|---|---|---|
| `data` | Integer/double array with exactly three positive dimensions; reject complex, character, logical, and zero-length dimensions | Calculations need real-valued measurements and stable shapes |
| `mask` | NULL or logical matrix matching rows/columns; reject NA mask entries with an actionable error | Mask uncertainty must not silently turn into inclusion |
| Physical wavelengths | Exactly one finite numeric coordinate per band, strictly increasing and unique | Prevent recycling, ambiguous selections, and false spectral adjacency |
| Unordered coordinates | Reject with guidance to reorder the cube and metadata together upstream | Automatically sorting can change the meaning of explicit index selections |
| Missing wavelengths | Use a tagged band-index coordinate internally; display “band index” | Index numbers are not physical units |
| Wavelength requests | Require real wavelength metadata for explicitly supplied wavelength selections | A bare array cannot resolve nanometres |
| Index requests | Finite, nonempty, whole-number values in range; reject fractional values before conversion | Integer coercion should not change a request silently |
| Counts | Finite scalar integers: `n_rings >= 1`, `nbins >= 2`, positive demo dimensions/bands | Silent clamping hides malformed calls |
| `probs` | Two finite probabilities with `0 <= p_low < p_high <= 1` | Define percentile order before fallback logic |
| `centre` | Numeric finite length two in the documented pixel coordinate system | NA checks alone do not reject infinity or strings |

For explicit wavelength requests, retain nearest-band selection but specify a deterministic tie rule, report the actual selected coordinates, and reject out-of-range targets by default. If a permissive out-of-range mode is retained for compatibility, make it explicit and report the selected boundary. Do not interpret default fusion thirds through this conversion path. When every group is NULL, `by` has no supplied values to convert.

Duplicate selections within a fusion group should be rejected or explicitly represented as weights; silently repeating a band changes its contribution. Overlap between different colour groups is allowed when deliberately supplied. Default groups must be nonempty, disjoint, contiguous, and cover the available bands once; require at least three bands for that default.

The image missing-data default is **propagation**: if a quantity needs several selected measurements, every required measurement must be valid. This keeps its definition constant across pixels. The explicit **available-case** fusion mode averages valid contributors only, provided each channel has at least one contributor and the changing band counts are disclosed. Never replace a missing channel with zero. Fusion exposes these choices as `missing = "propagate"` (default) and `missing = "available"`; full channel contribution counts remain inspectable.

Density is a per-band distribution, so it uses finite eligible observations separately in each band. Entirely invalid spatial pixels are absent everywhere. An entirely invalid image or cube should produce an actionable error rather than an apparently measured blank/black image. A partly empty density band should remain visible as missing information, with a gap in its overlays.

Spatial mask application and temporary transformations must not mutate `cube$data`, its metadata, the mask, or the caller's RNG/options. A stored provenance record must not retain the original cube or create external files as a rendering side effect.

**2. Define each computed quantity before selecting its colours**

For a pixel with eligible values `x_1, ..., x_B`, the current spectral flux quantities are:

```text
total variation V = sum(|x_(b+1) - x_b|), b = 1, ..., B-1
mean absolute step S = V / (B-1)
```

These formulas require at least two bands. `V` has the input-value unit; `S` is conventionally described as input-value units per band step. Both depend on the selected wavelength range and sampling. A flat spectrum gives zero. A sequence `0, 1, 2, 3` gives `V = 3, S = 1`; permuting it to `0, 3, 1, 2` gives `V = 6, S = 2` despite the same spread.

The same monotonic change from zero to one gives `S = 0.5` at three samples and `S = 0.2` at six samples. Therefore mean-step division is not a band-count correction that makes instruments comparable. Fix that claim now while preserving the defined calculation.

The candidate implements `normalization = "wavelength_span"` as `V / (lambda_B - lambda_1)`, with input-value units per nm. For a sampled piecewise-linear spectrum this is its mean absolute slope over the span. It still depends on what spectral structure the sampling captures, and noise can increase variation as more bands are acquired. Compare a common physical interval and document any resampling; do not describe the quantity as universally sampling-invariant.

For fusion, define each channel as the arithmetic mean over its declared band group under the chosen missingness policy. Record the actual indices and wavelengths rather than only the minimum and maximum: a noncontiguous group cannot be reconstructed from its endpoints. Preserve the aggregate channel matrix before display enhancement. Averaging can reduce independent per-band noise, but avoid universal claims about saturation or noise suppression when bands contain different signal or correlated noise.

For mandala, the display selects one input band at each spatial pixel according to its annulus. The corrected centre is `c((cols + 1)/2, (rows + 1)/2)`. Default `sampling = "index"` retains index sampling, while `sampling = "wavelength"` targets evenly spaced physical coordinates and selects the nearest measured bands, resolving ties toward the shorter wavelength. Repeated selections and target errors are recorded. It does not interpolate spectra or provide spatially uniform spectral coverage. Do not imply that the image's value distribution represents every band at every pixel. With one ring or fewer sampled bands than source bands, describe the actual selections without claiming a full physical sweep.

The experimental `hsa_spectral_gradient()` is precisely an RMS spectral slope, not a spatial gradient or a signed derivative. With interval widths `h = diff(lambda)` and endpoint span `L`, it computes:

```text
G = sqrt(sum(h * (diff(x)/h)^2) / L)
```

This is the RMS magnitude of the piecewise-linear spectral derivative, in input-value units per nm. Complete spectra and finite, positive, representable physical intervals are required; missing bands are not bridged. Short intervals amplify noise. Calculation preserves representable extreme and subnormal final results and errors when the requested final quantity is not finite.

The experimental `hsa_spectral_quartiles()` computes type-7 25th, 50th and 75th percentiles across equally weighted measured bands within each pixel. It discards spectral order and depends on sampling density, including on irregular grids. These panels are not uncertainty intervals. They share full-spectrum validity, one stretch pooled over all three raw panels, and one visible scale; a singleton measured band produces three identical panels. [Sampling experiments](evidence/sampling.md) establish examples and counterexamples for both new summaries.

**3. Treat enhancement and the colour domain as separate operations**

For finite eligible image values and endpoints `L < U`, a linear stretch is:

```text
z = min(1, max(0, (x - L) / (U - L)))
```

Use the specified R `quantile(..., type = 7)` convention, and record the requested probabilities. The same missingness and validity policy must determine both the rendered values and the population used for limits.

| Case | Numerical behaviour | Required disclosure |
|---|---|---|
| Percentile endpoints differ | Apply the stated linear stretch and clamp finite tails | Requested/effective method, probabilities, endpoints, clipped counts |
| Requested quantiles coincide but finite data vary | Fall back to the finite range | “Full-range fallback: requested quantiles coincide”; actual endpoints |
| All eligible values are the same and a stretch is requested | Map to zero, the dark palette endpoint | Constant-data handling and the constant value; no division by zero |
| No eligible values | Reject before plotting | Clear no-valid-data error |
| `stretch = "none"` | Keep numeric values unchanged | Explicit colour domain and out-of-domain policy |

Every stretched scalar image should use a fixed fill domain `[0, 1]`. Constant zero flux must use the palette's low endpoint. Store enough information to show that the legend or caption corresponds to the same calculation as the data.

For `stretch = "none"`, the interface uses the explicit display-domain argument `display_limits`. A documented `[0, 1]` display default is suitable for normalized reflectance-style images, but it is a display convention, not proof of calibration. Values outside that domain require an explicit domain or a clear error; avoid hidden clipping. A raw total-variation field or digital-count cube may require a different domain. The adopted default is `display_limits = c(0, 1)`; raw values outside the supplied domain raise a clear error.

Explicit domains should also make comparisons possible: the same finite input value maps to the same colour in separate figures that use the same palette and domain. “No stretch” alone does not guarantee this when a plotting library learns a domain separately from each dataset.

For RGB, values passed to the colour constructor must be valid in its expected domain. In unscaled mode, reject unexplained out-of-domain intensities before invoking `rgb()`. If an explicit raw display domain differs from `[0, 1]`, map it to RGB intensities only during colour construction, preserve the raw aggregate values, and disclose that display mapping. In stretched mode, preserve channel-specific limits and exclusions, and give invalid pixels transparent output. Caption text can be concise while the complete numerical record remains inspectable.

**4. Define what the density plot counts**

For band `b`, let `F_b` be its finite eligible values, `H[k,b]` the histogram counts, and `n_kept[b] = sum_k H[k,b]`. Use explicit, documented boundary rules; the implementation uses exact right-closed bins with the lowest endpoint included.

```text
n_finite[b] = n_below[b] + n_kept[b] + n_above[b]
n_eligible_spatial = n_nonfinite[b] + n_finite[b]
```

The spatial mask exclusion count is tracked separately. Values exactly at either outer limit are retained. All accounting checks run before normalization or display transformation.

For per-band normalisation:

```text
share[k,b] = H[k,b] / n_kept[b], when n_kept[b] > 0
```

These are shares **among retained values within the selected limits**. They are not fractions of all recorded pixels or a continuous probability density per unit reflectance/wavelength. Report the retained fraction so that two normalized bands with very different exclusions are not mistaken for equally sampled populations. If `n_kept[b] = 0`, the share is undefined and the band must be represented accordingly.

Keep raw `H` for accounting and overlay calculations. If the display uses `z = log1p(H)` or `log1p(share)`, apply `expm1()` to legend coordinates and format counts as counts and shares as fractions or percentages. A raw or normalized empty cell with a valid denominator is zero; an empty band with no denominator is a different state.

The current mean and quantile overlay comes from histogram bin centres and retained counts. Label it as a **binned mean and binned 5–95% pixel envelope**, conditional on the displayed range. The mean can differ from the exact retained-data mean by at most half a bin width when all bins have equal width. For quantiles, test the declared histogram-CDF convention against known occupied bins; do not promise equivalence to interpolated sample quantiles. Neither curve is an inferential confidence interval.

When automatic percentiles collapse, use the finite data range if it has width. For constant data, choose a scale-aware positive padding around the constant and record the padding and fallback. Explicit invalid user limits remain errors. Specify and test floating-point behaviour for very small and large finite constants.

For irregular wavelengths, choose cells with boundaries derived from neighbouring band coordinates, without moving the supplied measurement coordinates. A midpoint-boundary rectangle policy is a practical default; single-band widths require an explicit documented convention. On an irregular grid, a cell's arithmetic centre need not equal its measured wavelength: keep markers and overlays at the original wavelength, and assign counts to the correct interval. The cells represent measurements at their labelled bands, not measurements of previously unobserved intervening spectra. Avoid smoothed interpolation in the diagnostic histogram by default; any optional smoothing should be disclosed. This follows the distinction between raster and arbitrary rectangle geometry in the [ggplot2 documentation](https://ggplot2.tidyverse.org/reference/geom_tile.html).

Keep global percentile rules distinct from limits calculated on fused channels, mandala-selected pixels, or spectral differences. `show_limits = TRUE` displays global finite raw-value percentile references with that population explicitly identified. A later comparison feature should require compatible quantities, domains, and source populations. A reflectance-density plot cannot validate the scale of spectral flux merely by overlaying its numerical endpoints.

**5. Make provenance inspectable without changing the plot workflow**

Use one compact, versioned internal metadata record to generate captions and support inspection. The exact attachment/accessor API is an implementation decision; validate it with the installed ggplot2 representation and addition/theming behaviour before exporting an accessor.

| Record field | Contents |
|---|---|
| Input summary | Dimensions, coordinate kind, physical wavelengths when available, known value unit/label, optional non-sensitive source identifier |
| Validity | Spatially excluded count, nonfinite counts, selected missingness policy, effective contributing counts |
| Quantity | Composition, actual band groups or ring selections, aggregation, normalization, coordinate mapping |
| Enhancement | Requested/effective method, quantile convention/probabilities, channel endpoints, fallback, clipping counts, display domain |
| Distribution | Histogram breaks, raw count matrix or compact summaries, kept/dropped totals, denominator definition, binned-overlay method |
| Presentation | Palette, direction, interpolation choice, display transform, reference-line meaning |
| Reproducibility | Package/version, metadata schema version, supplied generation seed or explicit sampling parameters when applicable |

A histogram of `nbins × bands` and short vectors are acceptable to retain; another full source cube is not. Avoid including personal identifiers or local patient paths in exported captions/provenance. Existing caller-provided metadata must not be published automatically. The public showcase already distinguishes laboratory data from clinical data; extend that existing discipline to reproducibility records.

User edits can change a plot after creation. State whether attached metadata describes the original numerical rendering or the final modified object. Test ordinary `+ labs()`, `+ theme()`, and supported composition, and do not promise immutable or automatically updated provenance for arbitrary ggplot edits.

**6. Independent validation fixtures**

Expected values should come from small hand-calculated tables or independent base-R reference calculations. Do not call the implementation's stretch/selection helper to calculate its own expected output. Parameterize cases where they share a meaningful invariant, rather than exhaustively snapshotting every option combination.

| Fixture | Input and independent expectation | Cases covered |
|---|---|---|
| F01 — Spatial validity | Three 2 × 2 bands each contain `c(0.1, 0.2, 0.3, 50)` in column-major order; mask the fourth pixel. Exactly 9 values remain; changing 50 to an arbitrary extreme does not change valid calculations | A01, A03 |
| F02 — Known channel means | Six 2 × 2 bands listed below; default blue/green/red groups are 1:2, 3:4, 5:6. Compare exact means in unscaled mode | A02, A12 |
| F03 — Missingness | Introduce NA, NaN, Inf, and -Inf separately into selected and unselected bands, plus a fully missing RGB pixel. Assert the selected policy, transparency, and contributing counts | A03; partial-band policy |
| F04 — Coordinate metadata | Test absent, short, extra-long, duplicated, unordered, and nonfinite wavelengths | A08, A09 |
| F05 — Narrow spatial inputs | 1 × 1 × 3, 1 × 10 × 6, 10 × 1 × 3, and ordinary 2 × 2 × 6 cubes; use explicit singleton and default groups | A10 |
| F06 — Flat and ordered spectra | Flat `0.2` gives zero flux; `0,1,2,3` gives total 3/mean 1; `0,3,1,2` gives total 6/mean 2 | Flux formulas, A04 |
| F07 — Fixed display domain | Two cubes contain the same scalar value but different extrema; a declared common domain gives that scalar the same colour | A04 |
| F08 — Quantile collapse | An image of zeros with one nonzero pixel has collapsed default quantiles and nonzero range. The effective method is a full-range fallback | A13 |
| F09 — Constant density | Constant zero, constant 0.25, a tiny/large finite constant, and a normal-sized cube with one nonzero sample render under automatic limits | A11 |
| F10 — Count boundaries | Put values below/at/inside/at/above the outer limits, including internal bin boundaries. Hand-count bins and exclusions exactly | Density counts and boundary convention |
| F11 — Share and legend inverse | Put all retained values of one band into one bin. Its share is 1; its transformed value is `log(2)`; its label is 1 or 100% | A06 |
| F12 — Irregular wavelengths | Use `c(500, 505, 511, 520, 540, 580)` with distinct occupied bins. Count columns occupy their expected intervals; overlays retain their coordinates; no raster shift warning | A07 |
| F13 — Reference population | Compare raw-cube percentiles with independently calculated fusion means, mandala selection, and flux. Only the declared raw population matches global lines | A05 |
| F14 — Empty band | One band has no eligible/retained data while adjacent bands do. Its denominator and overlays are missing, with no invented joining curve | Density missingness and overlays |
| F15 — Geometry | Odd/even rectangular images and an explicit centre; band-constant values let tests recover ring selections. Assert symmetry and actual selected bands | Mandala centre and sampling |
| F16 — Rendered provenance | Exercise range, percentile, none, constant, and fallback cases; actual numeric endpoints and domain agree with caption/record | A04, A12, A13 |
| F17 — User state | Compare input object, RNG state, and relevant options before/after each renderer and demo generator | Side-effect contract |
| F18 — Publication assets | Parse a fresh built site; every required local image target exists, public figures have alt text, and gallery links resolve in the intended environment | A14 |

F02's bands, each listed in column-major spatial order, are:

```text
b1 = [0.1, 0.2, 0.4, 0.8]   b2 = [0.2, 0.3, 0.5, 0.9]
b3 = [0.3, 0.6, 0.2, 0.1]   b4 = [0.4, 0.7, 0.3, 0.2]
b5 = [0.9, 0.4, 0.7, 0.2]   b6 = [0.8, 0.3, 0.6, 0.1]

expected blue  = [0.15, 0.25, 0.45, 0.85]
expected green = [0.35, 0.65, 0.25, 0.15]
expected red   = [0.85, 0.35, 0.65, 0.15]
```

For arithmetic on these small fixtures, use a stated tight numeric tolerance, initially absolute `1e-12`, revising it only where a documented operation or platform justifies a different bound. Count identities are exact. Check built ggplot layer colours/geometry rather than relying solely on the class of a returned plot. Do not impose bit-identical antialiasing or fonts across operating systems.

Add deterministic property checks for invariance under changes to excluded values, equivalence of default fusion groups across `by` modes, and monotonicity of a fixed finite stretch. Compare index selections with physically equivalent wavelength selections when valid metadata exists. Test both normalisation modes against both display transforms for density; include an empty-band case in that small matrix.

**7. Analytical experiments after stabilization**

Use synthetic ground truth to test claims before comparing attractive real images:

| Experiment | Vary | Hold fixed | Measure and interpret |
|---|---|---|---|
| Spectral sampling | Band count, spacing, omitted wavelength regions | Underlying continuous synthetic spectrum and common wavelength span | Change in total/mean-step/mean-slope measures; do not infer invariance from a monotonic-only example |
| Noise sensitivity | Independent noise, correlated noise, and isolated spikes | Underlying signal and calibration scale | Bias/dispersion of flux and fusion summaries; distinguish a visual effect from a robust signal summary |
| Exclusion sensitivity | Spatial masks, missing bands, retained-range limits | Known valid distributions | Denominators, valid pixel coverage, and summaries under propagation/available-case rules |
| Histogram resolution | Bin count and display limits | Finite eligible observations | Retained fractions, binned-mean error, envelope movement, and rendering cost |
| Interpolation sensitivity | Geometry and smoothing choices | Known band centres and histogram counts | Whether gaps and quantised peaks remain recognizable; disclose smoothing |
| Between-cube comparison | Independent vs shared display domains | Known scalar reference values and compatible units | Colour agreement and interpretation of apparent contrast changes |

Use declared seeds and report the number of repeated simulations when sampling uncertainty is evaluated. Provide distribution summaries across repetitions rather than one favourable realization. If real recordings are examined, record calibration/reader versions and validate the numerical pipeline first. A cluster of discrete reflectance values may motivate inspection of photon counts, calibration, and quantisation; the figure alone does not identify the cause.

Keep scientific inference outside the plotting layer. Pixel-level histograms describe sampled pixels; spatial dependence means their many observations are not automatically independent biological replicates. A future uncertainty estimate must define its sampling unit and statistical assumptions in the analysis package before being presented as an inferential result here.

**8. Performance measurements and targets**

The audit measured a 256 × 320 × 100 double cube at 62.5 MiB. Large-allocation traffic (allocations at least 1 MB) was about 437.5 MiB without density reference lines and 1,062.5 MiB with them; peak process RSS was approximately 512 versus 637 MiB. These measurements include different kinds of memory accounting and must not be interchanged. They are a baseline from one environment, not portable guarantees.

Benchmark at least the default 48 × 64 × 24 demo, the 256 × 320 × 100 audit fixture, and a representative larger cube when the test host has adequate memory. Use synthetic generation with fixed dimensions/seed; record setup separately from computation and drawing. Run performance comparisons sequentially on the same host with a warmup and at least three measured repetitions, reporting the median and observed range.

Adopted acceptance targets; measured outcomes and investigated tradeoffs are in the [performance report](evidence/performance.md):

- Reference lines allocate no discarded full-cube stretched-value arrays. Aim for no more than 25% additional large-allocation traffic over the equivalent no-lines call on the audit fixture, using joint/reused quantile work where possible. If the target cannot be met without changing exactness, retain exact results and report the remaining cost explicitly.
- With fixed density limits and no global references, extra working storage should scale with a band-sized buffer and the `nbins × bands` histogram, plus rendering output. The already supplied input cube is not counted as avoidable extra storage. Avoid a second array proportional to all cube elements in this path.
- Automatic exact percentiles may still require storage proportional to finite eligible observations. Document that cost. Chunked histogram construction does not, by itself, make global quantile selection a streaming operation.
- Keep numerical outputs equal to the reference within the declared tolerances. Investigate median elapsed-time regressions larger than 20% on unchanged fixtures, but avoid fragile absolute timing gates on shared CI.
- Any later approximate quantile mode must be opt-in, reproducible, report its sampling method, and demonstrate error across the sampling/noise/exclusion experiments. Never introduce silent downsampling to meet a benchmark.

**9. Release evidence and practical test tiers**

| Tier | Runs when | Required evidence |
|---|---|---|
| Fast calculation/contract tests | Every relevant change and every PR | A01–A13 mapped fixtures, invalid-input errors, exact count balance, stable caller state |
| Rendering and provenance tests | Every PR affecting plots, plus release | Built scales/geometry, transparent invalid pixels, captions/record agreement, selected visual snapshots |
| Package and compatibility | CI and release candidate | Supported platform/R/dependency combinations, including the fixed declared minimum or a corrected declaration; examples/vignettes/check results |
| Publication assets | Site build and release candidate | Required local assets/links, alt text, representative export-size review; deployed URLs checked after deployment |
| Performance | Changes to aggregation/histograms/quantiles and release candidate | Same-host comparison with versions, dimensions, repetitions, allocation method, and peak RSS |
| Optional instrument integration | Before claims about real-reader compatibility and when suitable local fixtures exist | Separate Cubert/TIVITA results with versions and known provenance; an unavailable SDK/recording is reported as untested |

The release evidence record should identify the source commit and the test environment, link each A01–A14 finding to its passing case, and list outstanding exclusions. Suggested aggregate gates are all primary findings resolved, no unexplained package errors/warnings/notes, a reproducible coverage floor of at least 90%, passing house lint, and no missing required site assets. A numerical correctness failure blocks release even when the aggregate metrics pass.

No instrument calibration, physiological validity, statistical uncertainty, or reader interoperability claim should exceed the evidence actually collected. The roadmap improves the figure calculations and their interpretation first; broader analysis features depend on explicit scientific definitions and reproducible experiments.
