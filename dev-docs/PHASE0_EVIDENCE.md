# Phase 0 evidence

<!-- Development evidence; excluded from the package tarball. -->

Date: 2026-07-27  
Scope: skeleton and contract freeze only

## Authoritative inputs

- `IMPLEMENTATION_PLAN.md` was read in full and left unchanged.
- `docs/shared_conventions.md` reconciles the plan's observation schema with
  `readreq` while preserving all plan-required fields.
- The copied plan contains zero `readcropau` occurrences and consistently uses
  `readagau`; the known rename defect is already corrected.

## Frozen decisions

- Status: `s` estimate, `f` forecast, `z` projection; no date-position
  inference.
- Missing values: retained as numeric `NA` with raw value and controlled
  reason; never zero.
- Release and asset identities: official metadata plus SHA-256, not filenames
  or workbook-internal labels.
- Cache: atomic, content-addressed and immutable; refresh never deletes raw.
- Vintage APIs: separate history revision, forecast revision and forecast
  error signatures; first realisation remains distinct from latest revised.
- Fixtures: reduced/derived synthetic structurally faithful only.

## Catalogue evidence

- 17 Crop Report national table semantic IDs.
- Seven state-history geography IDs: Australia and six states.
- Agricultural Commodities outlook families cover macro assumptions, major
  indicators, crops, livestock/products and fisheries/forestry variants.
- 18 Agricultural Commodity Statistics semantic table IDs.
- Farm Productivity covers conventional/climate-adjusted TFP, inputs, outputs
  and growth by industry/geography/method regime.
- Historical Agricultural Forecast Database has an explicit supporting ID.

## Weekly-price and fertiliser gates

- Weekly HTML is replayable, but named third-party provider redistribution
  rights are not documented as permitted. All value series are
  `review-required` and not admitted.
- Fertiliser is an embedded Fabric/Power BI surface with ICS/Argus underlying
  sources. No stable public replayable structured endpoint/data dictionary or
  reviewed reuse rights are established. It is not admitted.
- Both remain metadata-only with explicit `unsupported_reason`. v0.1
  file-backed products are unaffected.

## Intentional exclusions

No discovery network calls, downloads, workbook parsers, canonicalisation,
rights-filter implementation or comparison calculations are implemented. The
exported vintage functions are typed Stage 0 stubs whose signatures are frozen.

## Validation commands

Run:

```sh
Rscript -e 'testthat::test_local("/path/to/user/dev/readagau")'
R CMD build /path/to/user/dev/readagau
R CMD check --no-manual readagau_0.0.0.9000.tar.gz
```

Actual output is recorded at the end of this file after execution.

## Chartwell isolation

No file under `/path/to/user/dev/data_viewer` is created or modified by
this package work. The exact before/after `git status --porcelain` comparison is
recorded after validation.

## Actual validation output

```text
testthat::test_local:
contracts: ...................
DONE

R CMD build:
* checking DESCRIPTION meta-information ... OK
* building ‘readagau_0.0.0.9000.tar.gz’

R CMD check --no-manual --no-vignettes:
* checking tests ...
  Running ‘testthat.R’
 OK
* DONE
Status: OK

catalogue:
readagau rows: 66 crop national: 17 state: 7 ACS: 18
gated metadata: 2 unique IDs: 66

shared convention SHA-256:
bce518693242c6987edc7a9d93f23cdd7b09e4feb5353b1078f696808b1a7c83

authoritative plan obsolete-name search:
0 readcropau occurrences
```

The check emitted transient repository-index access messages from the
network-restricted environment while dependency metadata was checked; these
did not produce a package NOTE, WARNING or ERROR. The final check status is
`OK`.

The post-validation Chartwell `git status --porcelain` is byte-for-byte
identical to the pre-existing baseline captured before package work.
