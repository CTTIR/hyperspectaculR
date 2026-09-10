The sampling experiments evaluate the proposed E1/E2 quantities against known synthetic signals. They use independent formulas in [analyse-sampling.R](../../data-raw/analyse-sampling.R), seed 20260910, a 500–900 nm interval, five band counts, regular and irregular grids, four signal shapes, three noise levels, and independent or correlated Gaussian noise. There are 8,080 realizations, including 50 repetitions for each noisy configuration. Results describe these simulations; they do not establish instrument calibration or biological validity.

Reproduce with:

```sh
Rscript data-raw/analyse-sampling.R /tmp/hyperspectaculR-sampling
```

The committed [summary](sampling-summary.csv), [exact examples](exact-examples.csv), [common-grid comparison](common-grid.csv), and [environment record](experiment-environment.txt) accompany the code. The command also writes individual simulation measurements for further inspection.

**Physical units help define a comparison, but do not correct undersampling.**

For an exact linear change from zero to one across 400 nm:

| Samples | Total variation | Mean band step | Mean absolute slope | RMS slope |
|---|---:|---:|---:|---:|
| 3 | 1 | 0.5 | 0.0025 / nm | 0.0025 / nm |
| 6 | 1 | 0.2 | 0.0025 / nm | 0.0025 / nm |

The mean step changes solely because of the number of samples. Span-normalized variation and RMS slope agree on this noiseless linear case. Their agreement is not universal: a narrow peak between coarse bands is not observed faithfully. Six regular measurements recover total variation 0.47965, compared with 1.0 in the dense known truth. Linear interpolation of those six measurements onto the common dense grid still gives 0.47965. More display samples cannot reconstruct information absent from the original capture.

**RMS slope distinguishes concentrated changes and is sensitive to noise.**

For wavelengths `(500, 501, 505)` and values `(0, 2, 2)`, mean absolute slope is 0.4 per nm and RMS slope is approximately 0.894427 per nm. Inserting a measurement `(503, 2)` on the same piecewise-linear curve leaves both physical-slope quantities unchanged. The RMS statistic gives greater weight to a change concentrated into a short interval. It is nonnegative and discards derivative sign.

For a flat signal with independent Gaussian noise of standard deviation `sigma`, interval widths `h`, and wavelength span `L`, the expected squared RMS slope is `2 * sigma^2 / L * sum(1 / h)`. On an equal grid it becomes `2 * sigma^2 * (B - 1)^2 / L^2`. More noisy bands can therefore increase the measured gradient sharply even when the underlying spectrum is flat.

With noise SD 0.01, the 50-repetition simulations gave:

| Bands | Mean squared RMS slope | Analytic expectation | Observed / expected |
|---|---:|---:|---:|
| 6 | 2.97225e-8 | 3.12500e-8 | 0.9511 |
| 12 | 1.41780e-7 | 1.51250e-7 | 0.9374 |
| 24 | 6.16005e-7 | 6.61250e-7 | 0.9316 |
| 48 | 2.69107e-6 | 2.76125e-6 | 0.9746 |
| 96 | 1.13547e-5 | 1.12813e-5 | 1.0065 |

These results support the predicted noise amplification. They are not a calibration of a noise-correction method, and no correction is applied by the plotting functions. The experiment also includes stationary AR(1) noise with correlation 0.8 and the same marginal SD; its results must not be compared with the independent-noise expectation as if the assumptions were unchanged.

**Quartiles describe the measured bands and discard their order.**

Type-7 quartiles of `(0, 1, 4, 9)` are `(0.75, 2.5, 5.25)`. Permuting the values to `(9, 0, 4, 1)` preserves those quartiles but changes total variation from 9 to 16. The quartile panels therefore show a different property from flux or slope: the within-pixel distribution of equally weighted measured bands. They are not an uncertainty interval and do not encode spectral ordering. Irregular sampling and interpolated additional bands can change their distribution even when physical endpoints stay fixed.

The common-grid experiment illustrates that last point. Interpolating the coarse narrow-peak spectrum moves its upper quartile from approximately 0.2 to 0.28993 because many interpolated values are introduced, while its physical total variation remains unchanged. A wavelength-weighted distribution would be a different statistic and needs a separate definition.

**Implementation decision.**

Proceed with an explicit wavelength-span normalization option, wavelength-target mandala selection, and experimental RMS-slope and equal-band-quartile compositions, with the definitions and limitations above in their help and captions. Their value is descriptive: RMS slope separates concentrated from gradual change, and quartiles reveal spectral level/spread without choosing individual bands. Public numerical tests must verify the independent exact examples and appropriate invariances before release. No claims of physiological interpretation, sampling independence, or noise robustness follow from these experiments.

For E3, exact fixed-limit histograms remain the first larger-data path. Sampling experiments demonstrate why silently interpolating, dropping bands, or approximating distributions would change interpretation. Approximate quantiles should remain out of the public interface unless the separate measured memory evidence establishes a need and an explicit error contract can be met.
