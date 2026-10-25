# Publication readiness

<!-- Development evidence; excluded from the package tarball. -->

## Current decision

Parser profile `2026.07.27.18` passes the implementer's functional and
source-correctness regressions for the supported scope. It fixes the
full-end-year productivity date defect, fails closed on malformed simple
financial-year candidates, and implements the documented generic four-digit
year grammar without changing official values or semantic identities.
Independent review of the round-four route-back is still pending. Public
release, tagging and downstream integration remain not ready.

## Open blockers

1. Independent cold parses miss all three initial targets:
   - Crop Report is about 7.2 seconds against a target below 5 seconds;
   - Agricultural Commodities is about 12.1 seconds against below 5 seconds;
   - Farm Productivity is about 4.23 seconds against below 3 seconds.
2. `DESCRIPTION` contains an unconfirmed placeholder maintainer email.
3. A public repository URL, issue tracker and private security contact are not
   configured.
4. CRAN-style checking must be repeated on a fully provisioned host.

Warm cache restores, listing and peak RSS pass. Performance targets must be
met or explicitly changed through a documented decision; they are not silently
waived.

## Completed gates

- all supported default canonical readers validate;
- exact real-workbook counts and source-cell goldens reproduce;
- all 125 `1999-2000` Farm Productivity rows now map to 1 July 1999 through
  30 June 2000, with other dates, values and series identities unchanged;
- malformed simple financial years such as `1999-`, `1999- 00` and
  `1999 - 2000` fail validation instead of becoming undated observations;
- punctuation delimiter substitutions, concatenated years and invalid
  start-year widths also raise the typed validation condition;
- the malformed grammar is closed over numeric run shape rather than an
  enumerated list of widths or separator characters;
- coherent `1899-00` and `1899-1900` labels share exact financial-year dates,
  while the four-digit upper boundary fails closed;
- March-to-June package-driven vintages pass;
- HAFD, cache concurrency, provenance and rights refusal pass;
- fixtures are synthetic and contain no official/logo assets;
- ordinary source-package check is clean; and
- an independent reviewer reproduced the functional evidence.

See `FINAL_INDEPENDENT_REVIEW.md` for all three review rounds.

## Documentation follow-up

The public documentation set was added on top of reviewed implementation
commit `7682c16859dbe15a34f6f77eea938cce0790fc3f`. It changes repository
guidance, package metadata, package-level help and citation files; it does not
change `R/`, parser fixtures or tests. After the documentation update, the
pkgdown site rendered all reference pages and vignettes, the installed
citation was evaluated, and an ordinary source-package check returned
`Status: OK`.
