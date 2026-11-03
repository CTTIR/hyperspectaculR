Benchmarks compare audit baseline `1df0bdd` with the corrected numerical implementation at `12d7428`. Some candidate records identify the subsequent documentation-only commit `9c385c8`; R source, DESCRIPTION and NAMESPACE were unchanged. All 26 records identify their source revision and report a clean source state. The complete [measurement table](benchmarks.csv) includes medians, minima, maxima, versions, source revisions and dimensions.

The three early audit-density baseline records predated source-identity capture and were rerun with the same final harness. Their committed rows are fresh observations, not historical values with metadata backfilled; the original logs and RDS records are preserved separately. `NA` remains only where older auxiliary metrics were not recorded.

The host was an Intel Xeon w9-3475X (36 cores/72 threads), Ubuntu 26.04, R 4.6.1 and ggplot2 4.0.3. Each case runs in a fresh R process, constructs a seeded synthetic cube (seed 42), warms a small plot, then measures three repetitions. Garbage collection precedes each repetition. Calculation and ggplot/grid drawing are measured separately. Performance cases ran sequentially; the three short demo cases were rerun after a brief initial overlap with validation to keep the reported comparison free of that workload.

[benchmark.R](../../data-raw/benchmark.R) uses Rprofmem with a 1,000,000-byte threshold. Allocation traffic is the cumulative size of allocations meeting that threshold; zero means none met the threshold, not zero memory use. The largest allocation uses the same threshold. Peak RSS is the whole-process high-water mark from `/usr/bin/time -v`, including the runtime and input construction. It is not incremental renderer storage and cannot be equated with cumulative allocation traffic. Times are observations on this host, not portable service guarantees.

| Fixture | Dimensions | Input size |
|---|---|---:|
| Demo | 48 × 64 × 24 | 0.563 MiB |
| Audit | 256 × 320 × 100 | 62.5 MiB |
| Large | 640 × 480 × 100 | 234.375 MiB |

The table below shows median calculation seconds, profiled cumulative calculation allocation and whole-process peak RSS. Ranges and drawing measurements remain in the CSV. `auto` uses exact automatic limits; `references` adds global raw percentile lines; `fixed` supplies limits [-0.1, 1] and disables global references.

| Size / density mode | Time, baseline → candidate (s) | Allocation, baseline → candidate (MiB) | Peak RSS, baseline → candidate (MiB) |
|---|---:|---:|---:|
| demo / auto | 0.043 → 0.048 | 0.0 → 0.0 | 213.6 → 220.6 |
| demo / references | 0.048 → 0.050 | 0.0 → 0.0 | 221.8 → 218.4 |
| demo / fixed | 0.041 → 0.045 | 0.0 → 0.0 | 210.6 → 211.2 |
| audit / auto | 0.732 → 0.818 | 437.5005 → 156.2501 | 652.5703 → 645.4922 |
| audit / references | 1.219 → 0.851 | 1125.0012 → 156.2501 | 837.9766 → 641.4883 |
| audit / fixed | 0.604 → 0.411 | 156.2502 → 0.0000 | 568.8516 → 331.6289 |
| large / auto | 2.482 → 2.445 | 3398.0 → 3866.8 | 1847.7 → 1396.1 |
| large / references | 4.061 → 2.529 | 5976.2 → 3866.8 | 2285.3 → 1480.1 |
| large / fixed | 1.611 → 1.600 | 2343.8 → 2109.5 | 1370.3 → 660.9 |

Adding global references now adds **0%** profiled calculation allocation over automatic limits on both audit and large fixtures, meeting the proposed ceiling of 25%. Joint quantile work replaces the discarded stretched cube. At audit size, the reference case falls from 1,125.0012 to 156.2501 MiB of profiled traffic.

The fixed-limit path has no additional allocation proportional to all cube elements. At large size its largest profiled allocation falls from 234.375 to 2.344 MiB: one of 100 bands. Its peak RSS falls 51.8%. Repeated allocation of short-lived band buffers still produces cumulative traffic; bounded live working storage does not imply zero total allocation.

Exact automatic limits still gather eligible finite observations and need full-population temporary storage. Large automatic-limit traffic increases 13.8% (3,398.0 to 3,866.8 MiB), while its peak RSS falls 24.4% and median calculation time remains similar. Removing redundant matrix/vector copies reduced the preceding corrected checkpoint's traffic from 4,804.4 MiB. Remaining validity and gathering costs are documented instead of hiding them with approximation. The explicit-limit path meets the larger-data requirement; no approximate quantile API is introduced.

| Audit-size image | Median calculation time (s) | Median drawing time (s) | Peak RSS (MiB) |
|---|---:|---:|---:|
| Fusion | 1.413 → 0.226 | 0.152 | 392.1 |
| Mean-step flux | 0.137 → 0.348 | 0.176 | 332.2 |
| Index mandala | 0.062 → 0.080 | 0.168 | 321.2 |
| RMS spectral slope | 1.544 | 0.173 | 332.3 |
| Spectral quartiles | 4.411 | 0.757 | 484.1 |

Fusion preparation is 84.0% faster on this fixture after band-wise aggregation. Flux and mandala exceed the roadmap's 20% regression-investigation threshold: flux adds 0.211 s and mandala adds 0.018 s at audit size. Their revised path validates input/validity and records explicit display and selection semantics. Flux also guards extreme arithmetic: its first fully protected implementation took 1.374 s; a conservative ordinary-range path lowers that to 0.348 s (74.7% faster) while retaining the tested binary fallback for exceptional inputs. The remaining overhead is accepted to preserve correctness. RMS slope uses the protected arithmetic and has no baseline predecessor.

Exact quartiles materialize a pixel-by-band matrix and sort each pixel's measured values. Their 4.411 s calculation time and 484.1 MiB peak RSS on this fixture are an explicit cost of this experimental API, not a streaming-memory claim. Returned renderers retain final plot data and compact provenance, without source cubes or temporary quantile populations hidden in plotting environments.

To reproduce one case, run the current harness against separate baseline and candidate checkouts, then combine records with [summarise-benchmarks.R](../../data-raw/summarise-benchmarks.R):

```sh
/usr/bin/time -v Rscript data-raw/benchmark.R /path/to/checkout density_fixed large result.rds > result.log 2>&1
Rscript data-raw/summarise-benchmarks.R /path/to/records benchmarks.csv
```

Preserve the RDS records and matching logs for a new run. Compare the same seed, dimensions, plotting arguments, dependency versions and host load; do not compare these warmed three-repetition results directly with the audit's earlier single-run RSS measurements.
