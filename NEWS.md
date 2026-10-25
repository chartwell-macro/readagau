# readagau 0.1.0

This is a development snapshot and has not been submitted to or accepted by
CRAN.

- Updated package metadata, citation files, and release documentation for
  publication-readiness. Bundled parser fixtures are package-owned synthetic
  test data; upstream data, source reports, names, and other provider materials
  remain subject to their respective terms.
- Added a rendered, end-to-end time-series chart workflow to the README and
  Getting Started article using the public Weekly series catalogue and reader
  with installed synthetic fixtures. The visible plotting step is a compact
  `ggplot2::geom_line()` workflow, and the synthetic PDF fixture extracts
  consistently across supported Poppler platforms.
- Standardised the package author, maintainer, and copyright-holder name as
  Chartwell Macro across package metadata, citation files, documentation, and licensing,
  while preserving source-data and upstream rights separately.
- Uses a non-personal GitHub noreply address only where package metadata
  requires maintainer contact, and omits email from optional public surfaces.
- Consolidated value-compatible national and state Crop Report streams under
  one semantic series identity, retaining the union of dates so the longer
  forecast horizon wins. Conflicting overlaps and distinct supply-and-disposal
  series remain separate. Parser/cache profile `2026.07.29.02` invalidates
  stale parses.
- Added the audited quarterly Agricultural Commodity Statistics workbook role
  for March 2024 through December 2025 and admitted its exact legacy 27-table
  schema alongside the current 18-table schema. Parser/cache profile
  `2026.07.28.01` invalidates stale parses.
- Added catalogue and parser support for 475 verified complete-table Weekly
  commodity-price snapshots from 13 October 2016 through 23 July 2026, plus
  all 33 current A1–A25/H1–H8 accessible chart observations, canonical series
  identities, provider provenance, exact missing-value semantics, and
  quarterly ZIP replay. Source snapshots are retrieved on demand; committed
  parser fixtures contain package-owned synthetic values only.
- Added catalogue and parser support for all 66 Australian Crop Report
  editions from February 2010 to June 2026, including official national
  workbooks for every edition and the 64 separately published state workbooks.
  Official assets are retrieved on demand and are not bundled as fixtures.
- Added all 66 Agricultural Commodities outlook editions from March 2010 to
  June 2026. March and June 2010 expose the audited report-backed Major
  indicators table; the 64 editions from September 2010 expose their audited
  outlook-workbook tables.
- Added direct, role-aligned official archive asset URLs, exact edition
  identities, full-history cache replay and cross-era validation goldens.
- Moved engineering plans, audits, architecture and governance material to
  organised `dev-docs/archive`, `dev-docs/evidence` and `dev-docs/reference`
  directories outside the package tarball; README, installed help and
  vignettes remain the package-facing documentation.
- Fixed financial-year date bounds for coherent full-end labels such as
  `1999-2000`, while retaining `1999-00` support and rejecting incoherent or
  malformed simple ranges, including whitespace around the delimiter. The
  grammar accepts any four-digit start year whose following year remains four
  digits, rather than silently restricting inputs to 1900–2099. The
  fail-closed grammar covers numeric runs separated only by punctuation or
  whitespace, incomplete punctuated numeric shapes, and concatenated numeric
  tokens longer than four digits, regardless of token width or run count.
  Parser/cache profile `2026.07.27.20` invalidates stale parses from either
  pre-merge parser branch; the package version remains 0.1.0.
- Added atomic, immutable SHA-256 raw caching and byte-signature detection,
  including OOXML workbooks published with `.xls` names.
- Added all 17 Crop Report national tables and all seven state-geography
  sheets, March/non-March layouts, reported and canonical views.
- Added March medium-term and non-March Agricultural Commodities outlook
  profiles plus all 18 Agricultural Commodity Statistics tables.
- Added 19 conventional and seven climate-adjusted Farm Productivity tables,
  retaining the 2022-23 to 2024-25 interim-adjustment regime explicitly.
- Added Historical Agricultural Forecast Database normalisation and separate
  history-revision, forecast-revision and forecast-error operations.
- Added typed conditions, release validation, catalogues, offline synthetic
  and adversarial fixtures, live-test gating, documentation, and benchmarks.
- Added checksum-qualified local-file provenance, explicit official local
  release metadata, and writer locks with stale-snapshot-safe manifest merges.
- Retained the complete March Agricultural Commodities row hierarchy in
  semantic identities, eliminating canonical collisions without dropping
  values and enabling package-driven March-to-June vintage comparisons.
- Retained Farm Productivity state, input-type and geographic-breakdown
  hierarchy in semantic identities, so all 5,750 reported observations remain
  distinct and the public canonical default preserves every source value.
