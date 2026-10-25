# Phases 1–5 implementation evidence

<!-- Development evidence; excluded from the package tarball. -->

Date: 2026-07-27  
Package: `readagau` 0.1.0  
Repository: `/path/to/user/dev/readagau`  
App isolation: no implementation file was created under or copied into
`/path/to/user/dev/data_viewer`

## Result

The v0.1 file-backed scope is implemented:

- exact official edition-page discovery for ten Crop Report editions and ten
  Agricultural Commodities editions from March 2024 to June 2026;
- independently validated `supported` status for March/June 2026; the other
  16 quarterly product editions are truthfully `discovered-unverified`;
- Farm Productivity discovery and supporting-workbook parsing;
- Historical Agricultural Forecast Database landing-page discovery, immutable
  download and package-owned normalisation;
- exact/latest resolution, byte sniffing, atomic immutable SHA-256 raw caching,
  locked stale-snapshot-safe discovery/asset manifests and parsed caches;
- all 17 Crop Report national tables and seven state-geography sheets;
- March/non-March Agricultural Commodities outlook variants and all 18
  Agricultural Commodity Statistics tables;
- all 19 conventional and seven climate-adjusted productivity tables,
  including an explicit 144-observation interim-adjustment regime;
- reported/canonical views, series catalogue, validation, typed conditions,
  separate revision/error operations, offline fixtures, documentation and
  opt-in live tests.

Weekly commodity prices and fertiliser remain metadata-only, as required by
the frozen Stage 0 gate. No restricted values or brittle dashboard scraper was
implemented.

## Final-review remediation

The first v12 freeze did not satisfy the March 2026 Agricultural Commodities
canonical/vintage gate. Its 2,664-row reported outlook contained 336 duplicate
observation keys and 228 conflicting groups because the generic row mapping
discarded source hierarchy labels such as macroeconomic measure, nominal/real
parent, fisheries section and production/consumption parent. Canonicalisation
correctly failed rather than selecting one value.

Parser profile `2026.07.27.13` retained those raw workbook hierarchy cells in
the existing semantic dimensions: macro region in `geography`, source
subgroup/item in `commodity`, and the complete section/measure/modifier path in
`concept`. No value was removed or deduplicated. Its regressions proved:

- March outlook: 2,664 reported rows, zero duplicate keys, zero conflicting
  groups, 2,664 valid canonical rows;
- March full outlook plus ACS: 32,959 valid canonical rows and zero duplicate
  keys;
- Advanced economies / 2024 retains distinct `Real GDP growth = 1.78` and
  `GDP per person = 1.20` series;
- package-driven March→June loading: 3,600 canonical observations, zero
  within-release duplicates, zero structural-break diagnostics and 96
  forecast revisions;
- the agricultural-export revision goldens remain 80,456.408→81,815.978
  for 2025–26 and 72,844.562→74,815.698 for 2026–27.

A subsequent implementation-independent consolidated default-view audit found
that v13 still failed the supported real Farm Productivity canonical default.
The 5,750-row reported view contained 77 duplicate rows across 52 observation
keys and five conflicting groups:

- `productivity_table_18` had treated the five input-type column headers as
  geography and discarded the seven state row labels. This collapsed its 35
  published cells to five keys, producing 30 duplicate rows and five
  conflicting groups.
- `productivity_table_16` and `productivity_table_19` each published the same
  47-period `All Australia` Dairy index, respectively in by-state and
  by-region source hierarchies. Discarding that hierarchy produced 47
  additional same-valued duplicate keys.

Canonicalisation correctly aborted on the conflicting table 18 groups rather
than selecting one value.

Parser profile `2026.07.27.14` retains both missing hierarchies in the existing
semantic dimensions. Table 18 row labels are `geography`, input-type headers
extend `concept`, and the by-state/by-region source path extends the index
`concept`. Table 10's industry-by-input-type matrix also correctly remains
Australian geography. No row or value is removed. Final regressions prove:

- Farm Productivity: 5,750 reported rows, zero duplicate keys, zero
  conflicting groups, and 5,750 valid canonical rows from the public default
  reader;
- table 18: all 35 state × input-type cells have distinct series identities;
  its seven Capital values remain `-1.1, -1.7, -0.6, -4.0, -1.7, -1.8, 0.2`
  for All Australia, New South Wales, Victoria, Queensland, South Australia,
  Western Australia and Tasmania;
- every supported public default canonical reader succeeds and validates:
  March Crop 7,162 rows, June Crop 16,169 rows, March Agricultural Commodities
  32,959 rows, June Agricultural Commodities 31,231 rows, and Farm
  Productivity 5,750 rows;
- the March Agricultural Commodities and package-driven vintage regressions
  above remain unchanged, including all revision goldens.

## Post-freeze financial-year correctness route-back

Parser/cache profile `2026.07.27.18` fixes a central period-bounds defect found
after the v14 review and closes validation gaps found in the first three
route-back reviews.
`agau_period_like()` already admitted a full-end financial-year label, but
`agau_period_bounds()` assigned dates only to the short form. Consequently,
the official June 2026 Farm Productivity workbook's 125 canonical
`1999-2000` observations across 18 tables and two concepts had `NA` start/end
dates between correctly dated `1998-99` and `2000-01` rows.

The central contract now admits coherent `YYYY-YY` and `YYYY-YYYY` financial
years for four-digit start years `0000` through `9998` and maps both to 1 July
through 30 June. It rejects incoherent or malformed simple ranges, including
`1999-`, `1999- 00`, `1999 - 2000`, wrong delimiters and unsupported widths.
`1899-00` and `1899-1900` both map to 1 July 1899 through 30 June 1900;
`9999-00` fails closed because its endpoint would require a five-digit year.
Punctuation delimiter substitutions such as `1999:00`, concatenated forms
such as `199900`, and invalid-width forms such as `999-00` and `10000-01`
also raise `agau_validation_error`.
The v18 malformed classifier is a closed grammar rather than an enumerated
width list: numeric runs separated only by punctuation/whitespace, incomplete
punctuated numeric shapes, every all-digit token longer than four characters,
and a four-digit prefix followed by punctuation plus a non-summary tail fail
closed. Exact `to`/`through`, named `average`/`index`, and genuine text-first
summaries are excluded. Bare-year and quarter contracts remain independent.
Intentional multi-year `financial_year_range` summaries remain undated. The
parser-profile bump prevents old parsed caches from retaining the defect.

The uncommitted manager workbook
`/private/tmp/readagau_productivity_202606.xls` proves:

- all 125 affected rows now have `period_start = 1999-07-01` and
  `period_end = 2000-06-30`;
- row count remains 5,750, with 469 series identities and no duplicate
  observation keys;
- all non-date/parser fields are byte-for-byte identical to the pinned v14
  output (`SHA-256 ded4b5f47936029126ed62047bae03121df8bcc08ce73c2e964bc91ec8c7d7e9`);
- unaffected identity/period/date fields retain their v14 digest
  (`SHA-256 884b88db5605dd5898d932e61dd5e3ff6fc62f3ad0ec98d29d10c813b3736753`);
  and
- representative values remain 173.8 (Table 1, All Australia), 127.45
  (Table 6, All Australia), 134.42 (Table 14, Northern Beef), 117
  (Table C2, All Australia) and 82 (Table C6, All Australia).

A direct parent-vs-final parse using installed commit
`cc71a9f6634f0b524032e6f35d65be8794b9d230` as the parent proved that exactly
those 125 productivity rows changed dates. The changed row indices exactly
equalled the target set, all target dates became 1 July 1999 through 30 June
2000, and every unaffected date, value and semantic identity remained
identical. The other four official source assets were identical in every field
except the parser profile and retrieval timestamp:

- Agricultural Commodities outlook: 936 rows,
  `SHA-256 2ea967437a4a592c111e61a9b348d29b61678b105bb65b144621f0b721f51cc2`;
- Agricultural Commodity Statistics: 30,295 rows,
  `SHA-256 41f79e2f99b405b0414c9ffea7b7af004ffc6e55d560411e8b40963bb9b9e519`;
- Crop Report national: 7,377 rows,
  `SHA-256 ec2eadddd5d5cca8ea0b91c844a9695a9052c4155311a480493dd091c37435c0`;
  and
- Crop Report state: 9,044 rows,
  `SHA-256 e0c2bdb48f3a3cf3d269131922326e311ff7918e592f59b7e34f5a6f730f55dc`.

No official workbook is committed. Independent audit of this route-back
commit remains required before any downstream integration pin changes.

Route-back verification on 2026-07-27 produced:

- focused contract tests: 9 tests / 82 expectations, all passing in 0.519
  seconds;
- all 592 unique official period/basis pairs across the five source assets
  passed direct classification with zero false-positive validation errors;
- direct parent-vs-final parsing of all five official source assets: the four
  non-productivity assets were stable-identical after excluding
  `parser_version` and `retrieved_at`, while exactly the intended 125
  productivity rows changed dates;
- focused official real semantics: 4 tests / 99 expectations, all passing in
  57.011 seconds;
- complete offline suite: 51 tests / 341 expectations, zero failures, errors
  or warnings, with one opt-in live test skipped, in 68.090 seconds;
- `R CMD build`: successful in 2.52 seconds;
- `R CMD check --no-manual`: `Status: OK` in 66.05 seconds;
- fresh staged install/load: package 0.1.0, parser profile
  `2026.07.27.18`, successful in 1.11 seconds, with all 19 required malformed
  forms rejected by the installed package.

The round-four build invocation wrote
`/private/tmp/readagau-fy-build-round4.ojjAAr/readagau_0.1.0.tar.gz` and
reported SHA-256
`593d0f961d724a41ca3a62ca5c810859763f22cb108a18933e988282daa95926`;
the check above ran against that exact archive. This hash records only that
fresh command output. It is not claimed as a reproducible fixed-final identity
because `R CMD build` archives can contain nondeterministic metadata.

The v18 route-back source boundary under the deterministic command below is:

```text
SHA-256: e6614b922b8976e9058117a95b8e5793d47b545fe0d19801cea00274418fa6f6
```

The third-review v17 route-back boundary was
`19ae0484841a1ccaf814d3680444d96f6a873ee62b27ee0b9120166bebc7bc0a`;
it is retained as audit history rather than presented as final.
The second-review v16 route-back boundary was
`bd7bb4494d583992b347f48e285440f98f574bde417c5f8c7bf05a1721f1ab95`;
it is retained as audit history rather than presented as final.
The first-review v15 route-back boundary was
`86408ba63dc2fe3cd20aef2c9faa651ac6c1f25b2e026b83b7a0cc9a96665b99`;
it is retained as audit history rather than presented as final.

The historical v13 packaging-reconciled source boundary was
`31f1442e7d2533489bdddc5c28096b61f9b8a18552cba513365c20ded7d95d2e`.
Replacing only its `.Rbuildignore` hash with the earlier exclusion set
reproduces the pre-reconciliation v13 SHA-256
`16fbe2d9efd02b2de0618bd5087af04ae240f8c0907664be2d3c3a340cd68cef`.
Those hashes are retained as audit history, not presented as final.

The reviewed v14 source boundary was frozen at:

```text
SHA-256: 2675d1a6981240813643a4bba40355090083f624e5d45f22d859d367c70a0379
```

This deterministic hash covers `.Rbuildignore`, `DESCRIPTION`, `NAMESPACE`,
`NEWS.md`, `README.md`, `LICENSE`, and every regular file under `R/`, `inst/`,
`man/`, `tests/`, and `vignettes/`. It deliberately excludes evidence and
independent-review records so review annotations cannot change the code
boundary. Reproduction command:

```sh
(printf '%s\n' .Rbuildignore DESCRIPTION NAMESPACE NEWS.md README.md LICENSE; \
  find R inst man tests vignettes -type f -print) | LC_ALL=C sort | \
  while IFS= read -r source_file; do shasum -a 256 "$source_file"; done | \
  shasum -a 256
```

The historical v14 validation build produced
`/private/tmp/readagau_0.1.0.tar.gz` with the then-recorded SHA-256
`675330e8fcf167c7c2ac0e52902d2c7c829b914578bc5ea6157d6eddb49d6fc7`,
and its check ran against that exact invocation's archive. This is historical
command output, not a reproducible or fixed-final artifact identity: `R CMD
build` archives can vary because generated metadata and timestamps are not
guaranteed deterministic. The deterministic source-boundary hash above is the
reproducible code identity.

## Public API

The final `NAMESPACE` exports:

```text
agau_attribution
agau_cache_dir
agau_detect_format
agau_forecast_error
agau_forecast_revision
agau_history_revision
agau_missing_reason
agau_observation_schema
agau_raw_asset_manifest_schema
agau_release_manifest_schema
agau_series_catalog
agau_source_catalog
agau_status
compare_agau_vintages
crop_report_attribution
download_agau_release
list_agau_releases
read_agau_forecast_history
read_agau_prices
read_agricultural_commodities
read_crop_report
read_farm_productivity
validate_agau_release
```

Data classes are `crop_report_data`, `agricultural_commodities_data`,
`farm_productivity_data`, `agau_forecast_history`, `agau_price_metadata` and
`agau_validation_report`.

## Phase 1 — discovery, exact assets and immutable cache

`inst/catalogue/release-catalog.csv` contains ten product-qualified Crop
release IDs and ten Agricultural Commodities release IDs. Each row has an
exact edition landing page, for example:

```text
acr-2026-03-03-no-217
https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/australian-crop-report/march-2026

acr-2026-06-02-no-218
https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/australian-crop-report/june-2026

ac-2026-03-03
https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/march-2026

ac-2026-06-02
https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/june-2026
```

The archive parser follows those exact page links and only then classifies
asset URLs from link metadata. Offline archive/exact-page fixtures reproduce
all ten editions for both quarterly products. No asset filename convention is
used.

Cache invariants:

- current parser/cache profile: `2026.07.27.18`, intentionally independent of
  package version `0.1.0`;
- raw path: `raw/<product>/<release_id>/<sha256>/<asset>`;
- lookup key: product + exact release + asset role + exact source URL;
- a valid manifest hit verifies both local existence and SHA-256 and returns
  without fetching;
- incoming bytes are copied to a hidden temporary file in the final
  directory, verified, then atomically renamed;
- an existing hash path is never overwritten;
- refresh may append a new hash and retains the old snapshot;
- discovery and asset manifests use same-directory atomic RDS replacement;
- manifest writers use lock directories and merge stale snapshots under the
  lock, so concurrent writers cannot silently discard one another's rows;
- HTML masquerading as a workbook raises `agau_asset_format_error`;
- an OOXML ZIP signature wins over a misleading `.xls` suffix.

Arbitrary local workbook names and modification times never produce an
official release identity. Local reads default to `local-<sha256-prefix>` with
an unknown release date; callers may attach official identity only by
supplying both reviewed `release_id` and `release_date`.

Adversarial tests delete the source after the first cache fill and prove the
second exact read still succeeds from the validated manifest. A refresh test
puts different valid bytes at the same source path and proves both hash paths
remain present. Schema adversaries also prove that unknown/missing sheets,
moved headers, unlabeled payloads and `Unmapped payload` blocks containing
either numerics or provider missing/confidential markers outside a recognised
period grid fail closed with `agau_schema_error`.

## Phases 2–4 — real workbook mappings and counts

All counts below come from the eight manager-supplied workbooks in
`/private/tmp`. They are not committed.

| Object | Dataset/family | Rows |
|---|---|---:|
| March 2026 Crop national | Tables 1–3 national/state totals | 666 |
| March 2026 Crop national | Tables 4–10 current state snapshots | 130 |
| March 2026 Crop national | Tables 11–12 national crop history | 1,258 |
| March 2026 Crop national | Tables 13–14 recent state production | 1,008 |
| March 2026 Crop national | Tables 15–16 supply/disposal | 1,620 |
| March 2026 Crop national | Table 17 quarterly prices | 2,480 |
| **March Crop total** | **17 tables** | **7,162** |
| June 2026 Crop national | Tables 1–3 national/state totals | 678 |
| June 2026 Crop national | Tables 4–10 current state snapshots | 125 |
| June 2026 Crop national | Tables 11–12 national crop history | 1,278 |
| June 2026 Crop national | Tables 13–14 recent state production | 1,176 |
| June 2026 Crop national | Tables 15–16 supply/disposal | 1,620 |
| June 2026 Crop national | Table 17 quarterly prices | 2,500 |
| June 2026 Crop state | Australia + six state histories | 9,044 |
| **June Crop total** | **17 national + 7 geography IDs** | **16,421** |
| March 2026 outlook | macro assumptions | 160 |
| March 2026 outlook | major indicators | 248 |
| March 2026 outlook | crops | 1,232 |
| March 2026 outlook | livestock/products | 656 |
| March 2026 outlook | fisheries/forestry | 368 |
| March 2026 statistics | ACS Tables 1–18 | 30,295 |
| **March Commodities total** | **15 outlook + 18 ACS tables** | **32,959** |
| June 2026 outlook | macro assumptions | 63 |
| June 2026 outlook | major indicators | 105 |
| June 2026 outlook | crops | 404 |
| June 2026 outlook | livestock/products | 272 |
| June 2026 outlook | fisheries/forestry | 92 |
| June 2026 statistics | ACS Tables 1–18 | 30,295 |
| **June Commodities total** | **13 outlook + 18 ACS tables** | **31,231** |
| June 2026 productivity | 19 conventional tables | 3,926 |
| June 2026 productivity | climate-adjusted historical observations | 1,680 |
| June 2026 productivity | interim-adjusted 2022–23 to 2024–25 | 144 |
| **Productivity total** | **26 tables** | **5,750** |

The state geographies are exactly Australia, New South Wales, Queensland,
South Australia, Tasmania, Victoria and Western Australia.

The productivity byte-identification assertion is:

```text
/private/tmp/readagau_productivity_202606.xls -> xlsx
```

The misleading `.xls` and correctly suffixed `.xlsx` copies return identical
semantic observations.

### Raw golden cells

| Source | Period/status | Parsed value |
|---|---|---:|
| March Crop Table 11, wheat production | 2025–26 estimate | 35,985 |
| March Major indicators, agricultural exports | 2025–26 forecast | 80,456.408 |
| March Major indicators, agricultural exports | 2026–27 forecast | 72,844.562 |
| June Major Indicators, agricultural exports | 2025–26 forecast | 81,815.978 |
| June Major Indicators, agricultural exports | 2026–27 forecast | 74,815.698 |

Direct real-workbook semantic regressions additionally prove:

- ACS Table 5 wheat is `World` / `world_indicator` /
  `published_year` / `USD` / `nominal`;
- ACS Table 7 uses `august_july` for cotton, `october_september`
  for sugar and `calendar_year` for meat;
- ACS Table 15 is `Australia` / `financial_year` / `AUD` / `nominal`;
- Coarse Grains 2024–25 export values retain distinct Sorghum
  (935.983) and Barley (3,163.030) series;
- every observation in the final June AC (31,231), June Crop (16,421)
  and productivity (5,750) matrices carries a source note;
- canonical June AC has 31,231 rows and zero collisions; canonical June Crop
  validates with zero duplicate keys.

The reduced synthetic vintage test reproduces:

```text
June 2025       30,560 forecast
September 2025  33,765 forecast
December 2025   35,585 forecast
March 2026      35,985 estimate
```

`agau_forecast_revision()` returns all three changes and the final
`forecast -> estimate` transition. `agau_forecast_error()` separately labels
first realisation and latest revised values. Duplicate within-release joins
raise `agau_validation_error`.

### Canonical conflicts

The source-faithful view retains duplicate presentations. Canonical precedence
is state long history, national Tables 11–12 history, Tables 1–3 aggregates,
Tables 4–10 current snapshots, Tables 13–14 supporting presentations, then
unique Tables 15–17. Outlook owns estimate/forecast/projection records and ACS
owns long history. Canonical tests have zero duplicate observation keys.
Different equal-priority values fail rather than choosing by file order. No
unresolved collision occurred in the validation matrix. A regression with
legitimate numeric data values `2000` and `3000` proves that multi-value data
rows cannot be mistaken for repeated period headers.

## Historical Agricultural Forecast Database

The official landing page is:

```text
https://www.agriculture.gov.au/abares/research-topics/agricultural-outlook/historical-forecasts
```

`read_agau_forecast_history(path = NULL)` parses the landing page, identifies
the link labelled Historical agricultural forecast database, downloads it
through the same immutable cache and chooses the workbook sheet by reviewed
field fingerprints. It returns:

```text
commodity
estimate_type
estimate_description
unit
region
year_issued
month_issued
year_issued_fy
forecast_year_fy
original_forecast
latest_actual
release_id
source_url
retrieved_at
sha256
```

The offline fixture covers landing-page replay, path-NULL download/cache,
multi-sheet selection, required-field aliases, schema fingerprint rejection
and local CSV compatibility. Vintage comparisons report semantic structural
breaks (unit, currency, basis, geography, market or method) before joining,
and expose first/previous/latest forecast values, report rounds and issue-to-
target horizons. `read.abares` is not a runtime dependency.

## Phase 5 — admission and rights decisions

### Weekly commodity prices

Transport decision: official HTML is replayable.  
Value decision: not admitted; every value remains `review-required`.  
Reason: the intended public-value redistribution permission has not been
established for the identified third-party providers.

Complete checked-in list:

```text
IGC      review-required  metadata-only  No documented redistribution permission
USDA     review-required  metadata-only  No documented redistribution permission
Cotlook  review-required  metadata-only  No documented redistribution permission
ICE      review-required  metadata-only  No documented redistribution permission
AWEX     review-required  metadata-only  No documented redistribution permission
Jumbuk   review-required  metadata-only  No documented redistribution permission
MLA      review-required  metadata-only  No documented redistribution permission
GDT      review-required  metadata-only  No documented redistribution permission
```

`read_agau_prices(..., redistribution = "all_metadata")` returns provider,
official metadata URL, review date/evidence, rights status and
`unsupported_reason`, with `value = NA_real_`.
`redistribution = "permitted"` raises `agau_rights_error`.

### Fertiliser

Transport decision: not admitted.  
Reason: no documented stable public replayable structured endpoint or data
dictionary; the official surface is Fabric/Power BI.  
Rights decision: ICS and Argus are both `review-required`; no underlying
third-party redistribution permission was established.

```text
ICS    review-required  metadata-only  no stable public replayable endpoint and no documented permission
Argus  review-required  metadata-only  no stable public replayable endpoint and no documented permission
```

No chart pixels, inferred values, private undocumented endpoint, official
workbook, report art, logo, Coat of Arms or third-party value is committed.

## Fixtures

Committed fixtures are reduced/derived synthetic and structurally faithful.

| Fixture | Coverage |
|---|---|
| `html/crop-archive.html` + ten exact pages | exact Crop release following, 10 editions, roles |
| `html/commodities-archive.html` + ten exact pages | exact AC release following, 10 editions, roles |
| `html/historical-forecasts.html` | HAFD path-NULL discovery |
| `workbooks/crop-national.xlsx` | all 17 IDs and six parser families |
| `workbooks/crop-state.xlsx` | Australia plus six state sheets |
| `workbooks/ac-march-outlook.xlsx` | 15-sheet medium-term profile and `z` |
| `workbooks/ac-june-outlook.xlsx` | 13-sheet short profile and `% change` |
| `workbooks/commodity-statistics.xlsx` | all 18 ACS IDs |
| `workbooks/farm-productivity.xlsx` | conventional/climate-adjusted methods |
| `workbooks/farm-productivity-misnamed.xls` | OOXML bytes under `.xls` |
| `workbooks/historical-forecast.xlsx/.csv` | multi-sheet and local HAFD paths |
| negative Crop workbook variants | unknown/missing tables, moved headers, unlabeled column/row/matrix payloads and unmapped numeric/missing-marker blocks outside the period grid |
| synthetic HTML error file in test | HTML masquerading as workbook |
| synthetic rights manifest | review-required and metadata-only refusal |

No live network request occurs in the default suite.

## Real validation hashes

```text
readagau_ac_202603_outlook.xlsx
8c6ed0a2b1a7dcd8ea47f767cc9b45d10b3649ebf0b1c6964d0066cf258b7c10

readagau_ac_202603_stats.xlsx
f36dfecad0dc5b70102717a281a2fe761cba9c6f5d3830dd2f67df2a5ebc0970

readagau_acr_202603_national.xlsx
2f4543fa1d1105d7e4cdf134a8435ad274db1e7c21f971929adb80601308b002

readagau_ac_202606_outlook.xlsx
0b0a653435a5dac1507803024d943803066ca27c17bcd618d9a3f67e27ce7155

readagau_ac_202606_stats.xlsx
6fbbb3ac48a7bfcfa44220d45a7899ad0f445795af5529303161da81bfa375a2

readagau_acr_202606_national.xlsx
3fc8ec23a9d4343d9bebda557d6c0b7263505b8c67fcb5996d6ab83bd3cded6c

readagau_acr_202606_state.xlsx
1efa8d3296206a35a4aa79c33934f93b6fc2be6f21fa130409bbee163094d023

readagau_productivity_202606.xls
ca8e9c07eee4d336fb3658a977d128d2fb88acc813b0b1cd6b0ae255f817cd68
```

These are final validation hashes, not committed assets. The opt-in live test
is gated by `READAGAU_LIVE_TESTS=true`. The live request was not run because
that flag was not true in the network-restricted implementation environment.
Official manager-supplied workbook regressions did run, using the exact
workbooks and hashes above for final full-release validation.

## Performance and RSS

Command:

```sh
Rscript tools/benchmark-real.R
```

Three runs, seconds:

| Benchmark | Min | Median | Max |
|---|---:|---:|---:|
| release listing | 0.001 | 0.002 | 0.010 |
| complete June Crop cold parse | 7.256 | 7.316 | 7.564 |
| Crop parsed-cache restore | 0.110 | 0.110 | 0.110 |
| complete June AC cold parse | 11.956 | 12.010 | 12.485 |
| AC parsed-cache restore | 0.177 | 0.177 | 0.178 |
| complete productivity cold parse | 4.235 | 4.267 | 4.310 |
| productivity parsed-cache restore | 0.045 | 0.045 | 0.045 |

Maximum measured peak RSS delta was **97.91 MiB**, below the 200 MiB target.
Warm release listing and every parsed-object restore meet their targets.

The initial cold parser targets are not met for complete Crop, complete
Agricultural Commodities or median productivity. This is an explicit
release-candidate limitation, not hidden as a cache hit. The final performance
pass caches repeated scalar normalisation and hoists invariant ACS footnote and
period-basis work out of the period loop. Earlier profiling identified:

```text
agau_parse_workbook             97.61% total
agau_parse_column_periods       70.80% total
agau_observation_row            59.34% total
agau_norm_text                  45.20% total
sub                             22.34% self
```

The remaining optimisation seam is batch/vectorised observation construction.
Repeat use is within target because parsed-cache restore is 0.045–0.178
seconds.

## Test and check output

Offline tests:

```sh
Rscript -e 'testthat::test_local(".", reporter="summary")'
```

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
Reason: READAGAU_LIVE_TESTS was not true

DONE
```

Build:

```sh
R CMD build /path/to/user/dev/readagau
```

```text
* checking DESCRIPTION meta-information ... OK
* installing the package to build vignettes
* creating vignettes ... OK
* building ‘readagau_0.1.0.tar.gz’
```

Historical v14 normal check:

```sh
R CMD check --no-manual --output=/private/tmp/readagau-frozen-check-v14 \
  /private/tmp/readagau_0.1.0.tar.gz
```

```text
* checking tests ...
  Running ‘testthat.R’
 OK
* DONE
Status: OK
```

CRAN/Bioconductor index lookups emitted network warnings in the restricted
environment, but dependency checking completed `OK`; that historical v14
package check was `Status: OK`.

## Documentation delivered

- README with exact/latest and rights behavior;
- reference Rd for every exported function;
- six required vignettes;
- cache/offline guide;
- attribution/terms guide;
- `NEWS.md`;
- contribution guide and code of conduct;
- supported/unsupported matrix;
- Phase 0 and Phases 1–5 evidence.

## Chartwell compatibility

The package is standalone and did not modify Chartwell. A pinned install can
call `list_agau_releases()`, then the product reader with
`release = "latest"` or an exact release ID. Stable observation fields include
both `dataset` and `source_dataset`, all frozen provenance fields and
readagau-specific geography/sector/market/method/rights extensions. The package
requires R >= 4.1.0 and its runtime dependency set is non-geospatial.

No Chartwell provider code or dependency pin was changed because the plan
forbids integration before this review gate.

## Remaining limitations and release blockers

1. Cold parser timings miss several initial targets; parsed restores and RSS
   pass. Batch normalisation is the next performance work.
2. The opt-in live suite did not run because `READAGAU_LIVE_TESTS` was not true
   in the network-restricted environment; official manager-supplied workbook
   regressions ran instead.
3. Weekly prices and fertiliser are intentionally metadata-only.
4. Only March and June 2026 quarterly workbook editions are labelled
   `supported`; the 16 older exact edition pages remain discoverable as
   `discovered-unverified` until their workbook bytes and outputs are audited.
5. The implementation-independent review completed with a functional/source
   **PASS**. Public release, tagging and integration remain **NOT READY**
   because cold-parser targets are still missed and the maintainer address is
   still a placeholder.
6. `DESCRIPTION` contains `chartwellmacro@gmail.com` solely to satisfy required
   package metadata. It is unconfirmed and must be replaced with a real
   maintainer address before public release, upstream submission or CRAN.

These limitations are truthful and do not weaken cache immutability, semantic
provenance, rights refusal or the validated March/June 2026 parser matrix.

## Upstream recommendation

Do not add a mandatory `read.abares` dependency. Offer the HAFD field
normalisation and the complete quarterly release readers upstream after this
API has survived at least two new quarterly releases and observation
construction is further vectorised. If upstream accepts the functionality without importing its
geospatial stack into this lightweight runtime, the companion package can then
be reconsidered. Until then, pin `readagau` 0.1.0 by an immutable commit only
after repository review.

## Final handoff

The coordinator creates the reviewed local immutable commit. This handoff
claims no remote push, tag or publication.
