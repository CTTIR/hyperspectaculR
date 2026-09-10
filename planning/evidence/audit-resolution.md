This ledger ties the 2026-09-10 audit findings to executable regressions. “Verified” identifies completed source checks; release, site and platform gates are recorded separately. The numerical tests use independently specified small-cube expectations. The historical checkpoints below show how each correction was verified; the final candidate status is recorded in the release evidence.

| ID | Correction and regression | State |
|---|---|---|
| A01 | Spatial masks survive adaptation; extraction excludes masked values without mutating input. The image foundation suite checks invalid output and common RGB enhancement populations; density tests independently count the masked observations. | Verified |
| A02 | Automatically generated fusion thirds resolve directly as indices for either `by` setting. Independent six-band means verify channel calculations. | Verified |
| A03 | Required nonfinite observations propagate to transparent image output; available-case fusion is explicit and uses common final RGB validity. | Verified |
| A04 | Scalar scales use explicit domains and robust rescaling. Built-fill tests cover shared raw-value colours, zero flux and extreme finite endpoints. | Verified |
| A05 | Global reference lines use independently calculated eligible raw-value quantiles, including values outside the display limits; captions identify that population. | Verified |
| A06 | Built legends invert log1p for raw counts and retained shares; raw integer counts stay unchanged across both normalisation and transform choices. | Verified |
| A07 | Midpoint rectangles preserve irregular measurement coordinates, with overlay groups broken at empty bands. Singleton bands and isolated populated bands build without warnings. | Verified |
| A08 | Short, nonfinite, duplicate and unordered wavelength vectors fail before selection or recycling. | Verified |
| A09 | Missing physical coordinates are tagged as band indices; physical selections require wavelength metadata. | Verified |
| A10 | Fusion retains rows-by-columns dimensions for singleton selections and 1-by-N, N-by-1 and 1-by-1 crops. | Verified |
| A11 | Automatic limits recover from constant and sparse finite inputs with documented finite-range or representable-padding fallbacks. Boundary counts are exact. | Verified |
| A12 | Fusion records separate requested/effective enhancement and numerical endpoints for all three channels. | Verified |
| A13 | Collapsed percentile enhancement reports its full-range/constant fallback; fractional percentile probabilities remain accurate in captions. | Verified |
| A14 | Six corrected synthetic gallery figures and copied evidence resolve in fresh pkgdown output; live URL checks follow deployment. | Local site verified; deployment pending |

Image regressions are in [test-image-foundation.R](../../tests/testthat/test-image-foundation.R), with the existing public behavior checks in [test-art.R](../../tests/testthat/test-art.R). The initial source check at `4601a3f` passed 173 assertions on R 4.6.1 and on exact R 4.1.0 with ggplot2 3.4.0. Review fixes at `7b87d97` passed 138 focused assertions, including overflow-safe built colour scales and accurate fractional-percentile captions. These checkpoints do not stand in for verification of later changes.

The associated [sampling experiments](sampling.md) provide independent definitions and limitations for physical slope and within-pixel spectral quartiles. The [analysis and validation plan](../analysis-and-validation.md) specifies the release gates.


Density regressions are in [test-density-foundation.R](../../tests/testthat/test-density-foundation.R). At `76da6c7`, the full 315-assertion suite passed on R 4.1.0 with both ggplot2 3.4.0 and 4.0.3, including optional patchwork composition checks. Integer storage, exact boundary counts, masked/nonfinite accounting, retained-share denominators, binned overlays, global references and empty-band geometry all have independent expectations.

The supplementary geometry and sampling corrections are covered by the image foundation and [spectral summary tests](../../tests/testthat/test-spectral-summary.R). Physical flux, wavelength-target mandalas, RMS spectral slope and shared-scale quartiles have exact fixtures and explicit limitations. The `6680af3` full suite passed 509 assertions with no failures, warnings or skips. Regression checks preserve representable extreme results, including values as small as `2^-1074`, without treating an approximate zero as a pass.

A subsequent memory review extended the original audit: ggplot calculation environments retained source cubes even when the visible metadata was compact. Shared render builders now retain only the final render data and compact settings. [The environment probe](../../tests/testthat/helper-render-environments.R) inspects plot, aesthetic and scale callback environments. Increasing density input from 10 × 10 × 3 to 100 × 100 × 3 changed serialized plot size by 14 bytes in the reviewed fix, instead of about 1.07 MB before it. Exact global quantiles still need a temporary finite-value population during calculation; that temporary storage is a separate performance cost.

The earlier package checkpoint `d0baf4a` passes 554 assertions, including four unskipped SVG baselines, on both R 4.6.1 and exact R 4.1.0 with ggplot2 4.0.3. The selected ggplot2 3.4.0 combination passes all 550 numerical assertions with the modern SVG baseline explicitly excluded. Full release and review status is recorded in [release-candidate.md](release-candidate.md).

The final caption/evidence correction at `9128b71` passes 556 assertions with no failures, warnings or skips on R 4.6.1, including all four SVG baselines. Its standalone density caption explicitly identifies the binned mean and binned pixel envelope. All three minor whole-branch findings received one consolidated correction and a scoped verification; final platform and publication status is in [release-candidate.md](release-candidate.md).
