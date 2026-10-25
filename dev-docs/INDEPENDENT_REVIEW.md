# Independent Phase 6 review

<!-- Development evidence; excluded from the package tarball. -->

Date: 2026-07-27  
Reviewer: independent Codex reviewer; no package implementation code changed  
Package: `readagau` 0.1.0  
Authoritative specification: `IMPLEMENTATION_PLAN.md`  
Manager-supplied full workbooks: `/private/tmp/readagau_*`  
Review result: **FAIL — not ready for a v0.1.0 release candidate**

This is the first-round independent review. It records the stable evidence
reproduced before the implementation parser was reopened for remediation, plus
the real-workbook regressions observed after the first schema-gate patch. A
final clean-room run of every command below is still required after the
implementer declares the parser matrix stable.

## Executive result

The package has a sound starting contract, correct audited identities for the
three saved real release pages, byte-signature detection, content-addressed raw
storage, five verified raw-cell goldens, explicit weekly/fertiliser refusal,
fast parsed-cache restores and acceptable measured RSS.

It does not yet satisfy the authoritative release gates. The principal
blockers are:

1. the latest schema/silent-drop patch fails on the actual Crop national,
   Agricultural Commodities outlook, ACS and Productivity workbooks;
2. the default canonical view aborts on the real June Crop and Agricultural
   Commodities releases because distinct source rows collapse to the same
   semantic key;
3. ACS period basis, geography/market, currency and price-basis semantics are
   materially incorrect on real tables;
4. source notes and footnotes are absent from most real observations,
   including the Crop golden;
5. the productivity output does not identify the interim 2022–23 to 2024–25
   climate-adjustment methodology regime;
6. the vintage API is incomplete relative to the approved plan;
7. cold parser performance misses every complete-release target; and
8. all-edition support is claimed without the required representative
   workbook matrix or a completed Phase 0 source audit.

## Inputs and immutable source evidence

The following manager-supplied files were inspected directly:

| File | SHA-256 |
|---|---|
| `readagau_ac_202603_outlook.xlsx` | `8c6ed0a2b1a7dcd8ea47f767cc9b45d10b3649ebf0b1c6964d0066cf258b7c10` |
| `readagau_ac_202603_stats.xlsx` | `f36dfecad0dc5b70102717a281a2fe761cba9c6f5d3830dd2f67df2a5ebc0970` |
| `readagau_acr_202603_national.xlsx` | `2f4543fa1d1105d7e4cdf134a8435ad274db1e7c21f971929adb80601308b002` |
| `readagau_ac_202606_outlook.xlsx` | `0b0a653435a5dac1507803024d943803066ca27c17bcd618d9a3f67e27ce7155` |
| `readagau_ac_202606_stats.xlsx` | `6fbbb3ac48a7bfcfa44220d45a7899ad0f445795af5529303161da81bfa375a2` |
| `readagau_acr_202606_national.xlsx` | `3fc8ec23a9d4343d9bebda557d6c0b7263505b8c67fcb5996d6ab83bd3cded6c` |
| `readagau_acr_202606_state.xlsx` | `1efa8d3296206a35a4aa79c33934f93b6fc2be6f21fa130409bbee163094d023` |
| `readagau_productivity_202606.xls` | `ca8e9c07eee4d336fb3658a977d128d2fb88acc813b0b1cd6b0ae255f817cd68` |

The real `.xls` productivity file and its `.xlsx` copy have identical hashes
and both are detected as OOXML:

```text
agau_detect_format(real .xls)  = xlsx
agau_detect_format(real .xlsx) = xlsx
hash equal                     = TRUE
```

## Verified raw-cell goldens

The following values were located independently with `readxl`, not inferred
from parser output:

| Workbook/sheet/cell | Raw context | Expected parser identity | Value |
|---|---|---|---:|
| March Crop, `Table 11`, `C41` | row `2025–26 s`, wheat production | estimate | 35,985 |
| March AC, `Major indicators`, `E4` | `2025–26 f`, Agriculture, `A$m` | forecast | 80,456.408 |
| March AC, `Major indicators`, `F4` | `2026–27 f`, Agriculture, `A$m` | forecast | 72,844.562 |
| June AC, `Major Indicators`, `E4` | `2025–26 f`, Agriculture, `A$m` | forecast | 81,815.978 |
| June AC, `Major Indicators`, `F4` | `2026–27 f`, Agriculture, `A$m` | forecast | 74,815.698 |

Before the parser was reopened, `tools/validate-real.R` reproduced all five
values with the correct release IDs:

```text
acr-2026-03-03-no-217
ac-2026-03-03
ac-2026-06-02
```

This is a useful cell-level pass, but five matching values do not establish
correct semantics or complete payload accounting across tens of thousands of
cells.

## Findings

### P1 — Current real-workbook parser matrix is broken

After the first schema/silent-drop remediation was applied, fresh-cache reads
against the exact manager assets produced:

```text
Crop national:
agau_schema_error
Unlabeled numeric-region payload found on row 3 of Table 15

Crop state:
OK, 8,930 rows

Agricultural Commodities June outlook:
agau_schema_error
Workbook sheet set does not match an admitted commodities_outlook profile.

Agricultural Commodity Statistics June:
agau_schema_error
Statistics sheet Table 6 has no admitted numbered title.

Farm Productivity:
agau_schema_error
Period header for table_7 is absent or outside the admitted header region.
```

These failures are on supported, manager-supplied official workbooks, not
synthetic adversarial files. They block every downstream release gate. The
sheet and payload gates must be made faithful to the real workbook controls,
then the complete eight-file matrix must be rerun from an empty parsed cache.

### P1 — Real canonical views abort

With the last stable real parses, `agau_canonicalise()` failed for both June
core products:

```text
Crop reported rows: 16,307
Ambiguous canonical groups: 16

Agricultural Commodities reported rows: 31,037
Ambiguous canonical groups: 1,202
```

Representative Crop collision:

```text
table_id:    crop_state_south_australia
geography:   South Australia
commodity:   Oats
concept:     Area
period:      2000
unit:        '000 ha
values:      80, 90
priority:    10, 10
series_id:   agau_0929bd3499e735ed84110ceb
```

Representative AC collision:

```text
table_id:    ac_outlook_coarse_grains
commodity:   Coarse Grains
concept:     Exports - value
period:      2024-25
unit:        A$m
values:      935.983, 3163.030
priority:    10, 10
series_id:   agau_103582211232ffc4b8b31327
```

The Crop state parser is collapsing distinct source rows/period axes; the AC
parser is dropping nested subseries such as individual grains. These are not
duplicates that a precedence rule may safely select. Distinct row paths must
be retained as semantic dimensions or concepts. The current README example
uses the default canonical path, so this is also a public API failure.

### P1 — ACS semantics are not source-faithful

The generic ACS parser produced materially false semantics on the real June
statistics workbook:

- most table titles were the literal `STATISTICS`, because the actual numbered
  title is in the next row;
- every ACS period was hard-coded to `financial_year`;
- Tables 5 and 7 world data were labelled `geography = Australia` and
  `market = not_applicable`;
- Table 15 export values in `$'000` had
  `currency = not_applicable` and `price_basis = not_applicable`.

The raw Table 7 note explicitly mixes calendar-year and commodity-specific
marketing-year regimes. The raw Table 5 sources include ABARES, ABS, AWEX,
Cotlook, ICE, IGC, MLA and USDA. Table 15 cites ABS. Those notes and source
contexts are essential to period, market, currency and price semantics.

The plan explicitly forbids inferring one generic basis from period shape.
Each ACS family needs a reviewed semantic profile covering row hierarchy,
geography/market, basis, units, currency and nominal/real/index meaning.

### P1 — Source notes and footnotes are missing

On a fresh real March Crop parse after the first note patch:

```text
rows:                         7,162
blank source_note:            7,032
rows with footnote codes:     2,668
Table 11 wheat golden note:   blank
Table 11 wheat footnotes:     empty
```

The real note cell begins with an estimate code before `Notes:` and `Sources:`.
Whitespace/newline normalisation occurs before extraction, so the easy
fixture case does not cover the real cell structure. Notes must be extracted
from the uncollapsed cell content or by matching note/source markers anywhere
in the cell, then attached by relevant table/row/column scope. Validation
should prove required note coverage on the real matrix.

### P1 — Productivity methodology regime is absent

The real productivity output contained only:

```text
method = conventional
method = climate_adjusted
```

No field or explicit concept/note identifies the 2022–23 to 2024–25 interim
climate-adjustment regime. The approved plan requires that regime to remain
distinguishable because ABARES states it will be revised when the enhanced
method enters production.

### P1 — Schema drift and silent payload handling need a real-safe design

Before the latest hardening patch, two adversarial workbooks demonstrated:

1. an unknown `Table 99` with period-shaped values was accepted and returned
   as `crop_national_table_99`;
2. a known `Table 1` row with numeric values but an empty label returned zero
   observations without error.

The current patch correctly attempts hard failure, but the real-workbook
regressions above show that control/header/note cells are being confused with
data payload. The correct gate must combine:

- admitted sheet-set aliases;
- title and header fingerprints;
- explicit control/header/note regions per family;
- count of every non-empty numeric-region cell;
- an explained disposition for skipped cells; and
- a typed error only for genuinely unexplained cells.

Synthetic easy-shape tests are not sufficient for this gate.

### P1 — Partial caches incorrectly satisfy `assets = "all"`

Independent reproduction:

1. cache only the `national` role for `acr-2026-06-02-no-218`;
2. call `download_agau_release(..., assets = "all")`;
3. observe a one-row manifest containing only `national`.

`agau_cached_release_assets()` currently defines `all` as the roles already
present in the cache. It must compare the cache against the expected roles for
the product and exact release (`national`, `state`, `report` for Crop) before
returning. A partial cache must trigger resolution of only the missing roles.

### P1 — Vintage comparison surface is incomplete

The approved signature includes `data = NULL`, but
`compare_agau_vintages()` always aborts when data is omitted instead of
loading the requested exact releases.

`agau_forecast_revision()` returns adjacent revisions and a revision number,
but does not return:

- issue-to-target horizon in months or report rounds;
- first/previous/latest forecast selection where requested; or
- explicit metadata/structural-break records.

Metadata changes currently create a different observation key and disappear
from a comparison rather than being flagged as a break. The four-release
wheat test copies one synthetic fixture row and manually assigns all four
values/statuses/hashes; it does not verify real cross-release workbook
mappings.

### P1 — HAFD malformed schemas can be silently accepted

After choosing the maximum-scoring workbook sheet, the HAFD reader does not
require a minimum fingerprint or mandatory field set. Missing aliases are
filled with vectors of `NA`, and `original_forecast`/`latest_actual` are
coerced with unguarded `as.numeric()`.

A workbook or CSV with moved/missing fields can therefore produce an
apparently valid all-`NA` result, and unexplained numeric tokens can be lost.
The reader needs required-field and minimum-score checks plus typed conversion
failures. Cache-first replay itself was fixed and passed focused tests.

### P1 — Advertised all-edition coverage is unsubstantiated

The package advertises all ten Crop and all ten Agricultural Commodities
editions as supported. Full real-workbook parsing was validated only for
March/June 2026. Committed workbook fixtures comprise one Crop national/state,
March/June outlook, one ACS and one productivity shape.

There are no distinct parser regression workbooks for the plan-required:

- March 2024 earliest digital shape;
- March 2025 misleading `.xls` link and March table layout;
- September 2025 weak filename and non-March layout; or
- 2024/2025 Agricultural Commodities editions.

`PHASE0_EVIDENCE.md` describes only the skeleton/contract and explicitly says
workbook parsers and discovery were not implemented in that phase. It does not
contain the required audit of every digitally linked AC edition. Static
release-page fixtures prove link enumeration, not workbook compatibility.

Support should be narrowed to validated releases or the representative source
matrix and full-release regression evidence must be completed.

### P1 — Cold performance gates fail

The recorded three-run results are:

| Benchmark | Min | Median | Max | Target | Result |
|---|---:|---:|---:|---:|---|
| warm release listing | 0.002 | 0.002 | 0.013 | <0.100 s | pass |
| complete June Crop cold parse | 9.727 | 9.819 | 9.828 | <5 s | **fail** |
| Crop parsed restore | 0.101 | 0.103 | 0.104 | <0.500 s | pass |
| complete June AC cold parse | 18.251 | 22.491 | 25.587 | <5 s | **fail** |
| AC parsed restore | 0.217 | 0.222 | 0.230 | <0.500 s | pass |
| complete Productivity cold parse | 4.237 | 6.043 | 7.567 | <3 s | **fail** |
| Productivity parsed restore | 0.032 | 0.032 | 0.032 | <0.500 s | pass |
| single raw-cached Crop Table 11 | 0.759 | 0.774 | 0.833 | <0.500 s | **fail** |

Maximum measured peak RSS delta was 74.25 MiB, which passes the 200 MiB
target. The misses are explicitly acknowledged in
`PHASES_1_6_EVIDENCE.md`, but the approved definition of done does not waive
them. The final matrix must be benchmarked again after correctness fixes.

### P2 — Local-file release identity can be fabricated from filename/mtime

For a supplied local file, `agau_local_meta()` maps a `YYYYMM` basename to the
catalogue, otherwise derives `release_date` from file modification time and
constructs a release ID. Renaming an official workbook to an arbitrary name
can therefore change its reported release provenance. Official release
identity must not come from a local filename or mtime. Require explicit
release metadata for ambiguous local files, or identify the asset by a
reviewed checksum manifest.

### P2 — Manifest updates have no concurrent-writer protection

Raw bytes are promoted atomically, but discovery and asset-index updates use
rotate-and-rename without a lock or safe merge protocol. Two writers can read
the same old index and publish different replacements, losing one manifest
row. This does not overwrite content-addressed raw bytes, but it can make
valid assets undiscoverable. The plan requires a lock or safe single-writer
protocol.

### P2 — Documentation and evidence overstate current behavior

Examples and vignettes assert:

- stable default canonical reads;
- structural-fingerprint selection;
- correct nested headings, market, period basis, currency and price basis;
- retained notes and the interim productivity method; and
- no unresolved canonical collision in the real validation matrix.

Those claims conflict with the reproduced findings. The evidence file must be
updated after remediation and must not state that the release candidate
passes while performance, canonical, semantic or coverage gates remain open.
There is also no repository URL, commit, tag or pinned install, and
`DESCRIPTION` still contains an unconfirmed example maintainer address.

## Closed or provisionally passing items

The following items passed independent first-round checks. They must still be
included in the final clean-room run because parser and cache code remained in
motion after these checks.

### Audited release identity

Saved real official pages now resolve:

```text
Crop June:
acr-2026-06-02-no-218 | 2026-06-02 | June 2026
roles: report, national, state

AC March:
ac-2026-03-03 | 2026-03-03 | March 2026
roles: report, outlook, statistics

AC June:
ac-2026-06-02 | 2026-06-02 | June 2026
roles: report, outlook, statistics
```

This closes the earlier defect where narrative page-update dates were used as
release identity.

### Cache-first exact asset and HAFD replay

Focused tests proved that an individually requested exact asset can be
returned after its original source is removed, and that HAFD `path = NULL`
replays a valid cached raw asset without reopening the landing page. This pass
does not close the separate partial-`assets = "all"` defect.

### File detection and immutable raw paths

- OOXML under `.xls` is detected as `xlsx`.
- HTML masquerading as a workbook raises `agau_asset_format_error`.
- different refreshed bytes receive different hash paths;
- prior raw paths remain present; and
- cache hits re-hash the local file before reuse.

### Status suffixes and rights gates

Focused tests cover `s -> estimate`, `f -> forecast`, `z -> projection`.
Unmarked periods remain `published-unclassified`.

Weekly prices and fertiliser return metadata with `value = NA_real_`;
`redistribution = "permitted"` raises `agau_rights_error`. The checked-in
rights rows are all `review-required`, so no value leak was observed.

### Package build/check before the latest parser patch

The independent pre-remediation run completed:

```text
testthat:
contracts: ..................
discovery-cache: .......................
live: S
parsers: ...............................
vintages-rights: ................
DONE

R CMD build:
* building ‘readagau_0.1.0.tar.gz’

R CMD check --as-cran:
tests and vignettes OK
Status: 1 WARNING, 2 NOTEs
```

The warning was the unavailable environmental `qpdf` executable. Notes
included inability to verify current time and old HTML tidying. Network index
access was unavailable in the restricted environment. These environmental
items are not parser defects, but the check must be rerun from the final
source state.

## Exact review commands

The following commands or equivalent clean temporary-directory variants were
used:

```sh
Rscript -e \
  'testthat::test_local("/path/to/user/dev/readagau", reporter="summary")'

Rscript -e \
  'testthat::test_local("/path/to/user/dev/readagau",
    filter="discovery-cache", reporter="summary")'

Rscript -e \
  'testthat::test_local("/path/to/user/dev/readagau",
    filter="parsers", reporter="summary")'

R CMD build /path/to/user/dev/readagau

R CMD check --as-cran \
  /private/tmp/readagau-independent-review-build/readagau_0.1.0.tar.gz

Rscript /path/to/user/dev/readagau/tools/validate-real.R

Rscript /path/to/user/dev/readagau/tools/benchmark-real.R
```

Real canonical collisions were inspected by parsing the June local assets
with `view = "reported"`, grouping by `observation_key`, applying
`agau_source_priority()`, and printing equal-priority groups with more than
one distinct non-missing value.

Raw goldens were read from the exact sheet/cell coordinates with
`readxl::read_excel(..., col_names = FALSE)`.

## Required final clean-room retest

After the implementation is declared stable:

1. remove or use a new empty parsed cache;
2. run the entire offline suite;
3. build a fresh tarball and run normal plus `--as-cran` checks;
4. parse all eight manager files, not just the five golden cells;
5. validate row counts, expected sheets, exact payload accounting, notes and
   all semantic enums;
6. run both `reported` and default `canonical` views for March and June;
7. inspect representative raw-to-output mappings from every Crop family,
   every outlook family, all 18 ACS tables and all 26 productivity tables;
8. reproduce a real four-release wheat sequence or explicitly narrow the
   claim until those workbooks are available;
9. test exact offline replay with a complete and deliberately partial cache;
10. test HAFD valid, malformed-schema and bad-numeric inputs;
11. rerun three-repetition cold/warm/RSS benchmarks; and
12. reconcile README, vignettes, NEWS and evidence with the actual result.

The release candidate should not be tagged while any P1 finding remains open.

## Chartwell isolation

The independent reviewer made no changes under
`/path/to/user/dev/data_viewer`. The package was created and reviewed at
`/path/to/user/dev/readagau`, as requested.
