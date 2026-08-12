# hyperspectaculR

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Publication-grade artistic visualisation of hyperspectral imagery.

Where [`hyperspectR`](https://github.com/CTTIR/hyperspectR) renders cubes for
*inspection* — quick looks, diagnostics, clinical index maps —
`hyperspectaculR` renders them for *display*: figures meant to be looked at, in
a paper or on a wall. It reads nothing and analyses nothing. It consumes the
`hsi_cube` class and returns `ggplot` objects.

## Design

**Compositions that use the spectral axis.** A false-colour picture of one band
is not interesting; anything in this package should be impossible to produce
from a single wavelength. A radial mandala sweeps the spectrum outward from a
centre; a flux field measures how much a pixel's reflectance moves across the
spectrum; a fusion averages band *groups* rather than picking three
wavelengths.

**Every figure states its own enhancement.** Contrast stretching is what makes
hyperspectral data legible, and also what makes it easy to mislead. Every
function captions the stretch it applied and the limits it used, so a striking
figure remains a defensible one.

**Perceptually uniform colour by default.** `hsa_palette()` offers only ramps
that are monotonic in lightness, so ordering survives greyscale printing and is
legible to colourblind readers. Asking for `turbo` warns you.

**Everything returns a ggplot.** Figures compose with `patchwork`, re-theme,
and export reproducibly. Nothing writes a file as a side effect.

## Installation

```r
# install.packages("remotes")
remotes::install_github("CTTIR/hyperspectaculR")
```

## Usage

```r
library(hyperspectaculR)

cube <- hsa_demo_cube()      # or any hyperspectR hsi_cube

hsa_mandala(cube)            # radial spectral sweep
hsa_spectral_flux(cube)      # cumulative change across the spectrum
hsa_fusion(cube)             # multi-band colour composite
```

With real data, via the reader packages:

```r
library(hyperspectR)

cube <- hs_read_cubert("session.cu3s")   # Cubert, via cuvis.r
# cube <- hs_read_tivita("..._SpecCube.dat")  # TIVITA, via tivis.r

hsa_fusion(cube, red = 750, green = 600, blue = 500, by = "wavelength")
```

## Functions

| | |
|---|---|
| `hsa_mandala()` | Concentric annuli, each drawn from a different wavelength |
| `hsa_spectral_flux()` | Cumulative absolute change between consecutive bands |
| `hsa_fusion()` | Colour composite from three averaged band groups |
| `hsa_theme()` | Dark, chrome-free theme for image panels |
| `hsa_palette()` | Perceptually uniform colour ramps |
| `hsa_demo_cube()` | Deterministic synthetic cube for examples and tests |

## Status

Early. The three compositions above are implemented and tested; more are
planned — spectral gradient fields, quartile panels, 3-D spectral surfaces and
band animations existed in an earlier draft of this package and are being
rewritten against the `hsi_cube` class rather than ported.

A note on provenance: an earlier version of this package shipped its own TIVITA
reader and a gallery of 54 images. That reader misparsed the container, so
every one of those images was rendered from meaningless bytes; both have been
removed. Reading now belongs to [`tivis.r`](https://github.com/CTTIR/tivis.r)
and [`cuvis.r`](https://github.com/CTTIR/cuvis.r), and the gallery will be
regenerated once the TIVITA sample ordering is settled.

## Related packages

| Package | Role |
|---|---|
| [`hyperspectR`](https://github.com/CTTIR/hyperspectR) | `hsi_cube` class, preprocessing, tissue indices |
| [`cuvis.r`](https://github.com/CTTIR/cuvis.r) | Cubert `.cu3s`, via the CUVIS SDK |
| [`tivis.r`](https://github.com/CTTIR/tivis.r) | TIVITA `SpecCube.dat`, pure R |

## License

MIT
