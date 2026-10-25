# Final independent Phase 5 review

<!-- Development evidence; excluded from the package tarball. -->

Date: 2026-07-27  
Package: `readagau` 0.1.0  
Authoritative plan: `IMPLEMENTATION_PLAN.md`  
First-round review: `INDEPENDENT_REVIEW.md`  
Implementation code changed by reviewer: none  
Status: **FINAL — functional/source correctness accepted; public release gate failed**

This file preserves the evidence from each frozen final-review profile. A
later remediation round does not erase a failure observed against an earlier
profile.

## Round 1 — parser profile `2026.07.27.12`

### Frozen-source identity

The source tree, excluding this final-review output and `.git`, was
fingerprinted before execution:

```text
2aa489ef5fa8ee37bb29915903ff04705165faee62abb8bf181f0521a05c671a
```

Command:

```sh
find . -type f -not -path './.git/*' \
  -not -name 'FINAL_INDEPENDENT_REVIEW.md' -print0 |
  sort -z |
  xargs -0 shasum -a 256 |
  shasum -a 256
```

`R/utils.R` reported parser/cache profile `2026.07.27.12`.

### Full offline suite — PASS

Command:

```sh
Rscript -e \
  'testthat::test_local("/path/to/user/dev/readagau",
    reporter = "summary")'
```

Result:

```text
contracts: ....................
discovery-cache: .........................................
hafd-validation: .........
live: S
parsers: ...................................................
real-semantics: ..........................................
schema-gates: ..........
vintage-api: .......................
vintages-rights: ................

Skipped: opt-in live discovery; READAGAU_LIVE_TESTS was not "true"
DONE
```

The reported groups comprise 20 contract, 41 discovery/cache, 9 HAFD,
51 parser, 42 real-semantic, 10 schema-gate, 23 vintage-API and 16
vintage/rights expectations.

### Independent adversarial gates — PASS

Fresh-cache reads produced `agau_schema_error` for all of:

```text
crop-national-unknown-table.xlsx
crop-national-missing-table.xlsx
crop-national-moved-header.xlsx
crop-national-unlabeled-column.xlsx
crop-national-unlabeled-row.xlsx
crop-national-unlabeled-matrix.xlsx
crop-national-extra-payload.xlsx
crop-national-extra-marker-payload.xlsx
```

The numeric fixture contains `999` under an `Unmapped payload` column and
failed because payload existed outside the admitted period grid.

All provider markers were classified as payload and retained with a controlled
missing reason:

```text
na              provider_na
n/a             not_applicable
not applicable  not_applicable
not available   unavailable
unavailable     unavailable
nr              unavailable
not reported    unavailable
confidential    confidential
c               confidential
suppressed      suppressed
..              suppressed
-               suppressed
—               suppressed
```

### Cache, release status, rights and local provenance — PASS

Independent output:

```text
partial-to-all roles: national|report|state
all paths valid: TRUE
manifest roles: national|report|state
lock absent after write: TRUE

quarterly releases: 20
supported: 4
discovered-unverified: 16

local identity: local-2ecc72975b43d827
local release date is NA: TRUE
partial official metadata: agau_validation_error

weekly_commodity_prices:
  rows 8, all values NA, status review-required,
  permitted path agau_rights_error

fertiliser:
  rows 2, all values NA, status review-required,
  permitted path agau_rights_error
```

Thus the partial-cache defect, stale-manifest merge lock and local
filename/mtime provenance defect from the first review are remediated in this
profile.

### Historical Forecast Database — PASS

Independent output:

```text
cache replay with absent landing: identical, 2 rows
wrong workbook: agau_schema_error
bad numeric forecast token: agau_schema_error
```

The wrong workbook failed the required field fingerprint and the malformed CSV
failed at `original_forecast` row 1.

### Explicit-data vintage semantics — PASS

Binding the two real reported Agricultural Commodities golden series produced:

| Period | Old | New | Old horizon | New horizon | Old round | New round |
|---|---:|---:|---:|---:|---:|---:|
| 2025–26 | 80,456.408 | 81,815.978 | 3 months | 0 months | 1 | 2 |
| 2026–27 | 72,844.562 | 74,815.698 | 15 months | 12 months | 1 | 2 |

Changing the unit between the two rows raised `agau_validation_error` with a
structural-break table identifying `unit`.

### P1 blocker — March canonical and package-driven vintages fail

The full offline suite did not exercise the March 2026 canonical outlook.
Independent execution did:

```r
read_agricultural_commodities(
  c(outlook = "/private/tmp/readagau_ac_202603_outlook.xlsx"),
  datasets = "outlook",
  view = "canonical",
  cache_dir = tempfile("can-")
)
```

Result:

```text
agau_validation_error:
Ambiguous canonical collision contains different top-priority values.
series_id: agau_075fd61cf451aa0cc2377380
```

The reported March outlook has:

```text
rows: 2,664
duplicate observation keys: 336
equal-priority conflicting groups: 228
```

Representative collision:

```text
source_sheet: Key macro
table_id:     ac_outlook_key_macro
commodity:    Advanced economies
concept:      Advanced economies
period:       2024
unit:         %
values:       1.78 and 1.20
market:       not_applicable
series_id:    agau_075fd61cf451aa0cc2377380
```

The values are different macro measures whose hierarchy has been discarded.
The same collision recurs across subsequent periods.

This also breaks the approved package-driven API:

```r
compare_agau_vintages(
  "agricultural_commodities",
  data = NULL,
  releases = list(
    `ac-2026-03-03` =
      c(outlook = "/private/tmp/readagau_ac_202603_outlook.xlsx"),
    `ac-2026-06-02` =
      c(outlook = "/private/tmp/readagau_ac_202606_outlook.xlsx")
  ),
  comparison = "forecast_revision",
  cache_dir = tempfile("vintage-")
)
```

Result:

```text
agau_validation_error:
Ambiguous canonical collision contains different top-priority values.
```

June 2026 outlook canonicalisation independently passed with 936 rows and zero
duplicate keys. The defect is specifically exposed by the March medium-term
shape.

### Round 1 verdict

**FAIL.** Profile `2026.07.27.12` cannot be accepted because a supported real
release fails the default canonical reader and package-driven vintage API.
Remaining real-matrix, performance, build and check gates are intentionally
paused until a new frozen parser profile is supplied.

## Round 2 — parser profile `2026.07.27.13`

### Frozen-source and package identity

The first v13 source boundary was
`16fbe2d9efd02b2de0618bd5087af04ae240f8c0907664be2d3c3a340cd68cef`.
Before packaging review, it was discovered that the historical
`INDEPENDENT_REVIEW.md` was not excluded from the tarball. No functional file
changed; `.Rbuildignore` was corrected and the refreshed boundary became:

```text
31f1442e7d2533489bdddc5c28096b61f9b8a18552cba513365c20ded7d95d2e
```

The deterministic scope is `.Rbuildignore`, `DESCRIPTION`, `NAMESPACE`,
`NEWS.md`, `README.md`, `LICENSE`, and every regular file under `R/`, `inst/`,
`man/`, `tests/` and `vignettes/`.

Command:

```sh
scope_files=(
  .Rbuildignore DESCRIPTION NAMESPACE NEWS.md README.md LICENSE
  R inst man tests vignettes
)
find "${scope_files[@]}" -type f |
  LC_ALL=C sort |
  while IFS= read -r f; do shasum -a 256 "$f"; done |
  shasum -a 256
```

The reconciled tarball was:

```text
/private/tmp/readagau_0.1.0.tar.gz
SHA-256:
45c71274e57019c9dbdd2b8277061cc7acb730b221316b524ee6218593dd9e99
```

Listing the archive found neither independent-review file nor either phase
evidence record.

### Round 1 March blocker — remediated

The exact March reproducer was rerun first:

```text
March outlook reported rows:       2,664
duplicate observation keys:        0
equal-priority conflicting groups: 0

March outlook canonical rows:      2,664
duplicate observation keys:        0
validation valid:                  TRUE
```

Package-driven loading also passed:

```r
compare_agau_vintages(
  "agricultural_commodities",
  data = NULL,
  releases = list(
    `ac-2026-03-03` =
      c(outlook = "/private/tmp/readagau_ac_202603_outlook.xlsx"),
    `ac-2026-06-02` =
      c(outlook = "/private/tmp/readagau_ac_202606_outlook.xlsx")
  ),
  comparison = "forecast_revision",
  cache_dir = tempfile("final-v13-vintage-")
)
```

It returned 96 forecast-revision rows. The two required export revisions were:

| Period | Old | New | Old horizon | New horizon |
|---|---:|---:|---:|---:|
| 2025–26 | 80,456.408 | 81,815.978 | 3 months | 0 months |
| 2026–27 | 72,844.562 | 74,815.698 | 15 months | 12 months |

Thus the Round 1 March macro-hierarchy blocker is closed in v13.

### Real matrix and raw goldens — PASS

`Rscript tools/validate-real.R` returned:

| Object | Rows | Semantic tables |
|---|---:|---:|
| March Crop national | 7,162 | 17 |
| June Crop national/state | 16,421 | 24 |
| March AC outlook/statistics | 32,959 | 33 |
| June AC outlook/statistics | 31,231 | 31 |
| Productivity | 5,750 | 26 |

All eight source hashes matched the first-round checksum list. All five
goldens retained their exact release, period, status and value:

```text
March Crop wheat production     2025-26 estimate 35,985
March AC agricultural exports   2025-26 forecast 80,456.408
March AC agricultural exports   2026-27 forecast 72,844.562
June AC agricultural exports    2025-26 forecast 81,815.978
June AC agricultural exports    2026-27 forecast 74,815.698
```

Direct `readxl` inspection located the Crop value once at trimmed source
matrix row 41, column 3 beside `2025–26 s`, followed by the ABARES estimate,
notes and sources cell. It located the AC values under the exact `2025–26 f`
and `2026–27 f` headers. The raw floating-point representations round to the
five published values above.

The focused real-semantic suite passed every assertion.

### Notes, ACS semantics and non-productivity canonical views — PASS

The consolidated full-workbook pass returned:

```text
crop_march:
  reported 7,162; 17 tables; blank notes 0; footnote rows 3,838
  canonical 7,162; duplicate keys 0; valid TRUE

crop_june:
  reported 16,421; 24 tables; blank notes 0; footnote rows 5,255
  canonical 16,169; duplicate keys 0; valid TRUE

ac_march:
  reported 32,959; 33 tables; blank notes 0; footnote rows 9,415
  canonical 32,959; duplicate keys 0; valid TRUE

ac_june:
  reported 31,231; 31 tables; blank notes 0; footnote rows 8,380
  canonical 31,231; duplicate keys 0; valid TRUE
```

Representative ACS values retained:

```text
Table 5 Wheat 2024-25:
  title        5 Annual world indicator prices of selected commodities
  geography    World
  market       world_indicator
  period basis published_year
  currency     USD
  price basis  nominal

Table 7:
  Cotton       august_july
  Sugar        october_september
  Meat         calendar_year

Table 15:
  rows          49
  geography     Australia
  period basis  financial_year
  currency      AUD
  price basis   nominal
```

Productivity reported-view method counts were also correct:

```text
conventional          3,926
climate_adjusted      1,680
interim_adjustment      144
```

The 144 interim records cover 2022–23, 2023–24 and 2024–25, with no blank
source notes. The reported productivity validation result was `TRUE`.

### P1 blocker — Productivity default canonical view fails

The consolidated pass failed when it reached productivity canonicalisation:

```r
read_farm_productivity(
  "/private/tmp/readagau_productivity_202606.xls",
  view = "canonical",
  cache_dir = "/private/tmp/readagau-final-review-v13-cache",
  release_id = "productivity-2026-06",
  release_date = as.Date("2026-06-30")
)
```

Result:

```text
agau_validation_error:
Ambiguous canonical collision contains different top-priority values.
```

The reported productivity object contains:

```text
rows:                       5,750
duplicate observation keys: 77
conflicting groups:          5
```

Every conflicting group is in `productivity_table_18`. Representative group:

```text
source sheet: table_18
geography:    Capital
commodity:    Dairy input growth rates
concept:      input growth rate Capital
period:       1978-79 to 2024-25
unit:         %
method:       conventional
values:       -1.1, -1.7, -0.6, -4.0, -1.7, -1.8, 0.2
series_id:    agau_4dd5bdb55c45429ee9c9662f
```

The other collapsed concepts are Labour, Services, Land and Materials. The
seven distinct source values in each group have lost a necessary semantic
dimension.

The real-semantic test covered productivity only with `view = "reported"`;
therefore the broad offline suite did not expose this public default-view
failure.

### Round 2 verdict

**FAIL.** Profile `2026.07.27.13` closes the March canonical/vintage defect but
cannot be accepted because the supported real Productivity workbook fails the
public default canonical reader. Remaining benchmark, source build, package
check and final documentation gates are paused for the next frozen profile.

## Round 3 — parser profile `2026.07.27.14`

### Frozen source and declared package identity

The deterministic source boundary is:

```text
2675d1a6981240813643a4bba40355090083f624e5d45f22d859d367c70a0379
```

It uses the same declared scope as Round 2:

```text
.Rbuildignore DESCRIPTION NAMESPACE NEWS.md README.md LICENSE
R/ inst/ man/ tests/ vignettes/
```

The implementation-provided package archive is:

```text
/private/tmp/readagau_0.1.0.tar.gz
SHA-256:
675330e8fcf167c7c2ac0e52902d2c7c829b914578bc5ea6157d6eddb49d6fc7
```

Both hashes were independently reproduced. Archive inspection found none of
`INDEPENDENT_REVIEW.md`, `FINAL_INDEPENDENT_REVIEW.md`,
`PHASE0_EVIDENCE.md`, or `PHASES_1_6_EVIDENCE.md`.

### Round 2 Productivity blocker — remediated

Direct raw inspection of `table_18` found a 9 by 6 source matrix: one title
row, one header row with five input columns, and seven state rows. The parser
now retains those seven states as geography, rather than collapsing them into
an input label:

```text
reported rows:                 5,750
reported duplicate keys:      0
reported conflicting groups:  0
canonical rows:                5,750
canonical duplicate keys:     0
reported/canonical identical: TRUE
validation valid:             TRUE

table_18 rows:                 35
table_18 series:               35
table_18 geographies:          7
table_18 concepts:             5
```

The seven distinct Capital values are:

```text
Australia          -1.1
New South Wales    -1.7
Victoria           -0.6
Queensland         -4.0
South Australia    -1.7
Western Australia  -1.8
Tasmania             0.2
```

Each belongs to a distinct series. Related table checks also passed:

```text
table_16:
  49 rows per state
  All Australia concept "total factor productivity index - by state"
  47 All Australia observations in one series

table_19:
  49 rows per region
  All Australia concept "total factor productivity index - by region"
  47 All Australia observations in a different series

table_10:
  30 rows
  geography Australia
  geography_type country
  commodities All industries, Cropping, Mixed, Sheep, Beef, Sheep-Beef
  concepts Capital, Labour, Land, Materials and Services input growth rate
```

Thus the Round 2 semantic-dimension blocker is closed in v14.

### Public default canonical matrix — PASS

Every supported real default reader returned a valid canonical object with no
duplicate observation keys:

| Object | Canonical rows | Tables | Duplicate keys | Blank notes |
|---|---:|---:|---:|---:|
| March Crop | 7,162 | 17 | 0 | 0 |
| June Crop | 16,169 | 24 | 0 | 0 |
| March Agricultural Commodities | 32,959 | 33 | 0 | 0 |
| June Agricultural Commodities | 31,231 | 31 | 0 | 0 |
| Farm Productivity | 5,750 | 26 | 0 | 0 |

The package-driven Agricultural Commodities vintage comparison also passed,
returning 96 forecast-revision rows. The required export revisions retained
their exact values and semantic timing:

| Period | Old | New | Old horizon | New horizon | Old round | New round |
|---|---:|---:|---:|---:|---:|---:|
| 2025–26 | 80,456.408 | 81,815.978 | 3 months | 0 months | 1 | 2 |
| 2026–27 | 72,844.562 | 74,815.698 | 15 months | 12 months | 1 | 2 |

### Full offline suite — PASS

Command:

```sh
Rscript -e \
  'testthat::test_local("/path/to/user/dev/readagau",
    reporter = "summary")'
```

Result:

```text
contracts: ....................
discovery-cache: .........................................
hafd-validation: .........
live: S
parsers: ...................................................
real-semantics: ......................................................................
schema-gates: ..........
vintage-api: ................................
vintages-rights: ................

Skipped:
opt-in live discovery preserves exact official metadata
Reason: READAGAU_LIVE_TESTS was not "true"

DONE
```

### Independent schema, cache, provenance and rights gates — PASS

All eight adversarial Crop fixtures raised `agau_schema_error`: unknown table,
missing table, moved header, unlabeled column, unlabeled row, unlabeled matrix,
unmapped numeric payload and unmapped marker payload. The raw extra-payload
cell was independently confirmed as `999`.

All declared provider markers were treated as payload and mapped to their
controlled missing reasons: `provider_na`, `not_applicable`, `unavailable`,
`confidential` or `suppressed`.

Independent cache and provenance checks returned:

```text
partial-to-all asset roles: national|report|state
all paths valid:            TRUE
offline exact hash replay:  identical after source removal
concurrent manifest roles:  national|state
write lock absent:          TRUE

quarterly releases:         20
supported:                   4
discovered-unverified:      16

local identity:             local-2ecc72975b43d827
local release date all NA:  TRUE
partial official metadata:  agau_validation_error

HAFD cached replay with absent landing: TRUE
HAFD wrong schema:                   agau_schema_error
```

Weekly commodity prices returned eight metadata-only rows and fertiliser
returned two. In each case all values were absent, rights status was
`review-required`, and requesting permitted redistribution raised
`agau_rights_error`.

### Real source matrix and semantic goldens — PASS

`Rscript tools/validate-real.R` returned:

| Object | Rows | Semantic tables |
|---|---:|---:|
| March Crop national | 7,162 | 17 |
| June Crop national/state | 16,421 | 24 |
| March AC outlook/statistics | 32,959 | 33 |
| June AC outlook/statistics | 31,231 | 31 |
| Productivity | 5,750 | 26 |

All eight manager-supplied source hashes matched the frozen evidence and none
matched any committed fixture. Direct `readxl` inspection again located the
five required goldens in their raw workbook contexts:

```text
March Crop wheat production     2025-26 estimate 35,985
March AC agricultural exports   2025-26 forecast 80,456.408
March AC agricultural exports   2026-27 forecast 72,844.562
June AC agricultural exports    2025-26 forecast 81,815.978
June AC agricultural exports    2026-27 forecast 74,815.698
```

ACS semantic checks passed for Table 5 world-indicator price semantics,
Table 7 commodity-specific period bases and Table 15 Australian
financial-year nominal AUD semantics.

Productivity reported methods were:

```text
conventional          3,926
climate_adjusted      1,680
interim_adjustment      144
```

The interim records cover 2022–23 through 2024–25. Reported validation passed
and no observation had a blank source note.

### Fixture redistribution audit — PASS

Committed fixtures are small synthetic structural fixtures:

- the largest is 16,470 bytes;
- no fixture hash matches a manager-supplied official workbook hash;
- no workbook contains media, embedded objects, VBA or custom UI assets;
- the 40-byte PDF contains only a synthetic-fixture comment;
- binary/text scans found no logo, Coat of Arms or copyright asset.

The README and attribution guide distinguish the package's MIT licence from
source-data rights, and the public rights paths fail closed.

### Build and checks

An independent source build succeeded:

```sh
R CMD build /path/to/user/dev/readagau
```

The fresh build produced
`/private/tmp/readagau-independent-final-build-v14/readagau_0.1.0.tar.gz`
with SHA-256
`d5eb9a87d3ca2fdfc6136c8f5c370b156a9ad81371f1a02c30c2c8827c7cd100`.
Its different byte hash from the declared archive is attributable to normal
build metadata/timestamps; source identity and archive exclusions were
separately verified.

Ordinary source-package checking passed:

```text
R CMD check --no-manual ...
Status: OK
```

The separate CRAN-mode check completed all tests but reported:

```text
Status: 1 WARNING, 1 NOTE
WARNING: qpdf unavailable
NOTE: unable to verify current time
```

Dependency-index DNS warnings were also emitted. These observations are
environmental; the final check status nevertheless means this run is not
evidence of a clean public CRAN gate.

### Release blocker — cold performance targets all fail

Independent execution of `Rscript tools/benchmark-real.R` reproduced:

| Reader | Cold seconds | Target | Result |
|---|---|---:|---|
| Crop | 7.395, 7.161, 7.229 | < 5 s | **FAIL** |
| Agricultural Commodities | 12.368, 11.954, 11.972 | < 5 s | **FAIL** |
| Productivity | 4.222, 4.239, 4.230 | < 3 s | **FAIL** |

Warm restore and listing gates passed:

```text
Crop restores:          0.111, 0.111, 0.108 seconds
AC restores:            0.177, 0.174, 0.175 seconds
Productivity restores:  0.045, 0.045, 0.045 seconds
Listing:                 0.001, 0.010, 0.002 seconds
Peak RSS:                102.32812 MiB (< 200 MiB)
```

These are explicit plan targets. Passing correctness, restore and memory gates
does not waive three independent cold-target failures.

### Release blocker — maintainer metadata is unconfirmed

`DESCRIPTION` declares `chartwellmacro@gmail.com` and the implementation
evidence explicitly identifies it as a placeholder used to satisfy package
metadata. It must be replaced with a confirmed maintainer address before any
public release, upstream submission or CRAN submission.

### Scope limitations and editorial observations

- Only the four March/June 2026 quarterly release entries are supported; 16
  older entries remain truthfully labelled `discovered-unverified`.
- The live network test was not run because its opt-in flag was not enabled.
  Full supplied official workbooks, offline discovery fixtures and cache replay
  were tested.
- `PHASES_1_6_EVIDENCE.md` records the implementation run's live-test skip
  reason as `On CRAN`, whereas the independent run skipped because
  `READAGAU_LIVE_TESTS` was not true. This is a non-functional evidence
  editorial issue to reconcile before handoff.
- The package was intentionally built outside `data_viewer`; the final
  `data_viewer` status exactly matched the review-start baseline.

### Final verdict

**Functional and source-correctness acceptance: PASS.** Parser profile
`2026.07.27.14` closes both earlier P1 canonicalization defects. The supported
March/June 2026 quarterly matrix, Productivity, HAFD, canonical defaults,
vintage APIs, cache immutability/concurrency, provenance, schema rejection,
rights refusal, real semantics, offline suite, source build and ordinary
package check all pass.

**Public release, tag and Chartwell integration: NOT READY / FAIL.** All three
cold-parse performance targets fail, and the maintainer email remains an
explicitly unconfirmed placeholder. Do not create a public release or tag and
do not integrate Chartwell against this package until both blockers are
resolved and independently rechecked. The 16 older quarterly editions are not
accepted as supported by this review.

A local immutable review commit may be created after final evidence
reconciliation. This review does not claim a remote repository, remote push or
tag.
