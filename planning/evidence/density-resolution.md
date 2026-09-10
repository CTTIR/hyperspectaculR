The density-resolution study checks what the histogram overlay estimates and how exclusions change its population. The reproducible recipe is [analyse-density.R](../../data-raw/analyse-density.R); complete [measurements](density-resolution.csv) and [environment](density-environment.txt) are recorded alongside this report. The initial run used source `6680af3`.

The synthetic cube has 48 × 64 × 6 values, seed 20260910, and irregular coordinates 500, 505, 511, 520, 540 and 580 nm. One spatial pixel is nonfinite in every band, with one additional nonfinite observation in band 3. The masked condition excludes the first eight rows (512 pixels); the unmasked condition retains those spatial positions. We vary 8, 16, 32, 64 and 128 bins over a wide range [-0.1, 1] or restricted range [0.2, 0.5], yielding 120 band/settings records. This is a deterministic numerical study, not repeated sampling inference.

All 120 records pass independent exact bin-count and exclusion accounting. Direct comparisons with bin boundaries specify right-closed bins and inclusion of the lowest endpoint. Expected finite/nonfinite, below-range, retained and above-range counts come directly from eligible input values. Narrowing the range changes the retained population; band normalisation consequently describes the restricted distribution.

The binned mean is compared with the exact mean of retained values. Envelope endpoints are compared with empirical type-1 5th/95th percentiles: these order-statistic references match the histogram-CDF convention, unlike the interpolated type-7 quantiles used for automatic range/reference lines and within-pixel quartiles. Mean and endpoint errors are bounded by half the bin width (absolute tolerance 1e-12). All checks pass; increasing bin count narrows this error bound but need not improve every realized error monotonically.

| Bins | Display range | Maximum absolute mean error | Maximum envelope endpoint error | Half-bin error bound |
|---:|---|---:|---:|---:|
| 8 | wide | 0.0103183 | 0.0669436 | 0.06875 |
| 8 | restricted | 0.000570562 | 0.0146367 | 0.01875 |
| 16 | wide | 0.000764554 | 0.0325686 | 0.034375 |
| 16 | restricted | 0.000279464 | 0.00933716 | 0.009375 |
| 32 | wide | 0.00023406 | 0.0165259 | 0.0171875 |
| 32 | restricted | 0.000114297 | 0.00464966 | 0.0046875 |
| 64 | wide | 6.92583e-05 | 0.00803566 | 0.00859375 |
| 64 | restricted | 4.27924e-05 | 0.00230591 | 0.00234375 |
| 128 | wide | 8.14364e-05 | 0.0041993 | 0.00429688 |
| 128 | restricted | 1.85809e-05 | 0.00113404 | 0.00117187 |

Maxima combine all six bands and both mask conditions. These bounds describe histogram discretization of the retained observations; they do not estimate measurement uncertainty or biological variation. Physical rectangle widths convey band locations, while counts remain counts of measured pixels at each band. No interpolation or approximation is used in histogram calculation.
