# Data contract

<!-- Development reference; installed help contains the package-facing contract. -->

The machine-readable schemas under `inst/schema/` are authoritative.

## Observation identity

`series_id` represents semantic dimensions other than target period and
vintage. `observation_key` adds the target period. Retrieval time and source
hash are provenance, not semantic identity.

Core provenance includes product, release, physical dataset/asset, workbook
sheet, semantic table, source URL context, retrieval time, SHA-256 and parser
version.

## Agricultural extensions

The package adds explicit fields for report number, sector, season, market,
method, source provider, observation date, snapshot date and
source cadence. These fields prevent source distinctions from being encoded
only in display labels.

## Time, status and values

`period`, start/end and basis distinguish calendar, financial, crop and point
periods. Status uses the vocabulary returned by `agau_status()`.
Financial-year labels accept the source forms `YYYY-YY` and `YYYY-YYYY` only
when the end year is exactly one year after the start year. Both forms map to
1 July through 30 June. `YYYY` is any four-digit start year from `0000` through
`9998`; `9999` is rejected because its end date would require a five-digit
year. Incoherent or malformed simple ranges—including missing end years,
whitespace around the delimiter, wrong delimiters and unsupported year
widths, or concatenated start/end tokens—fail with `agau_validation_error`
instead of producing undated observations. The closed malformed grammar is:
two or more numeric runs separated only by punctuation or whitespace; an
incomplete numeric shape with leading or trailing punctuation; any all-digit
token longer than four characters; or a four-digit prefix followed by
punctuation and a non-summary tail. Token width, separator choice and numeric
run count are not enumerated. Exact `to`/`through` ranges and named
`average`/`index` summaries remain deliberately undated, as do other genuine
text-first summary labels. Bare years from 1900 through 2099 retain the
separate calendar-year contract; other exact four-digit bare tokens remain
undated.

`value` is numeric and `raw_value` retains the source token. Provider missing,
confidential and suppressed markers become numeric `NA` plus a controlled
`missing_reason`; they never become zero.

## Reported and canonical roles

`record_role` distinguishes source-reported and canonical observations.
Canonical selection uses a versioned policy. Necessary workbook hierarchy is
retained in geography, commodity, concept, sector, market or method rather
than discarded to force uniqueness.

## Source metadata

`source_provider`, `rights_status`, source URL, snapshot date and observation
date remain explicit provenance fields. Supported package routes populate
their values and retain provider distinctions in semantic identity.

## Compatibility

Field meaning and type remain stable within a major version. A removed,
renamed or semantically changed field requires a migration note and version
decision. Parser-profile changes invalidate stale parsed caches when needed.
