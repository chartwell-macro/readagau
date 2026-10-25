# Contributing to readagau

<!-- Development reference; excluded from the package tarball. -->

Thank you for helping improve `readagau`. Contributions are evaluated for
source fidelity, reproducibility, rights safety and compatibility.

## Before opening a change

Use the [chartwellmacro@gmail.com](mailto:chartwellmacro@gmail.com)
for reproducible bugs, product-support requests and API proposals. Follow
[`SECURITY.md`](SECURITY.md) for vulnerabilities; do not put sensitive details
in a public issue.

A new product, release or parser profile must include:

- the exact official landing page and discovered asset roles;
- source hashes stored outside the repository;
- structural fingerprints and reduced synthetic fixtures;
- raw-cell goldens with sheet/table context;
- expected row, series and table counts;
- reported and public-default canonical validation;
- an audit for unexplained numeric and missing-marker payload;
- source rights, attribution and redistribution review; and
- an explicit support status or `unsupported_reason`.

Do not commit official workbooks, third-party values, report artwork, logos,
trademarks or the Commonwealth Coat of Arms.

## Development workflow

1. Work on a focused branch.
2. Keep discovery, transport/cache and parsing separate.
3. Add or update Rd help, vignettes and repository guides.
4. Add offline tests and reduced synthetic fixtures.
5. Run the required checks.
6. Explain API, schema, cache-key, rights and parser-version effects.

## Required checks

```sh
Rscript -e 'testthat::test_local(".", reporter = "summary")'
R CMD build .
R CMD check --no-manual readagau_0.1.0.tar.gz
```

Before public release:

```sh
_R_CHECK_CRAN_INCOMING_REMOTE_=false \
R CMD check --as-cran readagau_0.1.0.tar.gz
```

Live discovery must remain opt-in:

```sh
READAGAU_LIVE_TESTS=true Rscript -e \
  'testthat::test_local(".", reporter = "summary")'
```

Newly supported official releases also require the manager-workbook semantic
matrix, goldens, three-run benchmarks and independent reproduction.

## Compatibility and safety rules

- Never construct asset URLs from filename conventions.
- Never trust the filename extension instead of detected bytes.
- Never identify a sheet or table by position alone.
- Never convert missing, suppressed or confidential source cells to zero.
- Never overwrite a raw content hash or cached vintage.
- Never drop canonical conflicts or weaken validation to make a release pass.
- Never expose restricted values through an undocumented or unaudited path.
- Bump the parser/cache profile whenever stale output could hide a semantic
  change.

## Documentation style

Examples must be reproducible and state when they require network access,
local source files or an exact release. New exports require Rd help, an
API-map entry and a tested example or vignette use. New data surfaces require
source, support and rights documentation.

## Review expectations

Reviewers may inspect raw cells, mutate workbooks, poison network transport and
test concurrent cache writes. `R CMD check` is necessary but not sufficient
evidence that a parser is correct. See `GOVERNANCE.md` for release ownership.
