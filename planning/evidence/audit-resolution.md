This ledger ties the 2026-09-10 audit findings to executable regressions. “Verified” identifies completed source checks; release, site and platform gates are recorded separately. The numerical tests use independently specified small-cube expectations.

| ID | Correction and regression | State |
|---|---|---|
| A01 | Spatial masks survive adaptation; extraction excludes masked values without mutating input. The image foundation suite checks invalid output and common RGB enhancement populations; density denominator checks follow. | Images verified; density pending |
| A02 | Automatically generated fusion thirds resolve directly as indices for either `by` setting. Independent six-band means verify channel calculations. | Verified |
| A03 | Required nonfinite observations propagate to transparent image output; available-case fusion is explicit and uses common final RGB validity. | Images verified; density pending |
| A04 | Scalar scales use explicit domains and robust rescaling. Built-fill tests cover shared raw-value colours, zero flux and extreme finite endpoints. | Verified |
| A05 | Density rules must represent global eligible raw-value percentiles, with their own population/endpoints. | Pending density gate |
| A06 | Density log-share legends must invert the display transform; retained share one must label as one/100%. | Pending density gate |
| A07 | Density cells must use midpoint wavelength boundaries and retain measurement coordinates for overlays. Empty bands must break overlay groups. | Pending density gate |
| A08 | Short, nonfinite, duplicate and unordered wavelength vectors fail before selection or recycling. | Verified |
| A09 | Missing physical coordinates are tagged as band indices; physical selections require wavelength metadata. | Images verified; density pending |
| A10 | Fusion retains rows-by-columns dimensions for singleton selections and 1-by-N, N-by-1 and 1-by-1 crops. | Verified |
| A11 | Automatic density limits must recover from constant/sparse finite inputs with an explicit fallback. | Pending density gate |
| A12 | Fusion records separate requested/effective enhancement and numerical endpoints for all three channels. | Verified |
| A13 | Collapsed percentile enhancement reports its full-range/constant fallback; fractional percentile probabilities remain accurate in captions. | Verified |
| A14 | Public gallery files must be regenerated and resolve in a fresh pkgdown build; live URL checks follow deployment. | Pending site gate |

Image regressions are in [test-image-foundation.R](../../tests/testthat/test-image-foundation.R), with the existing public behavior checks in [test-art.R](../../tests/testthat/test-art.R). The initial source check at `4601a3f` passed 173 assertions on R 4.6.1 and on exact R 4.1.0 with ggplot2 3.4.0. Review fixes at `7b87d97` passed 138 focused assertions, including overflow-safe built colour scales and accurate fractional-percentile captions. These checkpoints do not stand in for verification of later changes.

The associated [sampling experiments](sampling.md) provide independent definitions and limitations for physical slope and within-pixel spectral quartiles. The [analysis and validation plan](../analysis-and-validation.md) specifies the release gates.
