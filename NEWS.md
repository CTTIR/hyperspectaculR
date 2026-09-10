# hyperspectaculR 0.2.0 (development candidate)

* Validate real numeric cubes, optional spatial masks and strictly increasing
  physical wavelengths; keep absent wavelengths as band indices.
* Preserve invalid image pixels as transparent. Correct default fusion thirds
  and expose explicit available-contributor fusion with recorded counts.
* Fix raw display domains, zero/constant dark endpoints and collapsed
  percentile fallbacks. Retain raw values and complete enhancement records.
* Expose `hsa_provenance()` for compact original-rendering records, including
  selections, exclusions, endpoints and fallbacks; inspect patchwork components.
* Make density histograms exact with irregular-coordinate rectangles, retained
  population accounting, missing-band overlay gaps and global raw references.
* Add wavelength-span flux normalization and wavelength-target mandala sampling.
  Preserve legacy argument order and `normalise`; reject contradictory options.
* Add experimental nonnegative RMS spectral slope and equal-band type-7
  quartiles, with explicit units, shared quartile geometry and sampling limits.
* Bound large selection labels while retaining full provenance; avoid redundant
  band-buffer copies and use a conservative ordinary-range flux path with the
  full exponent-based calculation retained for extreme arithmetic.
* Replace recording-dependent public figures with a deterministic synthetic
  gallery, regenerate help and add rendering/minimum-compatibility checks.
* Require ggplot2 >= 3.4.0; retain R >= 4.1.0. Invalid metadata, counts,
  probabilities, indices, groups and out-of-domain raw values now error.

# hyperspectaculR 0.1.0

First release. Publication-grade artistic visualisation of hyperspectral
imagery, built on the `hsi_cube` class from `hyperspectR`.

## Compositions

Each requires the spectral axis: none could be produced from a single
wavelength, which is the rule the package holds itself to.

* `hsa_spectral_density()` draws the joint distribution of reflectance against
  wavelength across every pixel, with the mean spectrum and a 5–95% envelope
  read back off the same binned matrix. The only non-image composition, and the
  one the others should be read against — every image applies a contrast
  stretch, and this shows the distribution that stretch is applied to.
  `show_limits = TRUE` draws those limits onto it.
* `hsa_mandala()` renders concentric annuli, each drawn from a different
  wavelength, sweeping the spectrum outward from a chosen centre.
* `hsa_spectral_flux()` sums the absolute change between consecutive bands,
  giving a field of spectral variability that responds to shape rather than
  spread — unlike a variance map, it is sensitive to band order.
* `hsa_fusion()` builds a colour composite from three averaged band groups,
  which suppresses per-band sensor noise relative to picking three wavelengths.

## Design decisions

* Every function returns a `ggplot`, so figures compose with `patchwork`,
  re-theme, and export reproducibly. Nothing writes a file as a side effect.
* Every rendering captions the contrast stretch and limits it applied.
  Stretching is what makes this data legible and also what makes it easy to
  mislead with, so it is never silent.
* `hsa_palette()` offers only ramps monotonic in lightness, so ordering
  survives greyscale printing and stays legible to colourblind readers. Asking
  for `turbo` warns that it does not.
* Cubes are duck-typed rather than imported, so `hyperspectR` stays in
  Suggests — it is not on CRAN — while the art functions work anywhere a cube
  can be obtained.

## Not included, deliberately

Two visualisations from an earlier draft were dropped rather than ported,
both failing the package's own rule. A 3-D height surface is one scalar per
pixel by definition, so its third dimension is a single band or a derived
index. A band animation is a sequence of single-band images, so it fails frame
by frame. Neither becomes defensible by being rendered more attractively.

Dropping them also removes any need for `rayshader`, `rgl` or `gifski`.
