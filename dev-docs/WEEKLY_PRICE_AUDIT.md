# Weekly commodity price history audit

Audit date: 27 July 2026

The admitted history contains 475 unique, exact-date, validated report
snapshots from 13 October 2016 through 23 July 2026:

- 208 reports from 17 official quarterly ZIP archives, producing 24,335
  canonical observations.
- 265 direct official PDF reports and two direct official Word reports,
  producing 30,815 canonical observations.
- 55,150 canonical observations in total.
- 475 unique release IDs and 475 unique release-date/source-hash identities.

Every supported source was parsed from its real bytes. The audit required the
parsed publication date to equal the catalogue date and
`validate_agau_release()` to pass. The resulting gate was 475/475 exact and
475/475 valid, with zero parser errors.

The catalogue also records six discovered-unverified releases. Two release
pages have no retrievable report asset, two indexed assets contain a different
edition, and two official tables are intrinsically malformed. Exact hashes and
the fail-closed dispositions are in
`dev-docs/audits/weekly-unverified-forensics.csv`.

The source-byte audit can be rerun with:

```sh
Rscript dev-docs/audits/audit-weekly-history.R \
  /tmp/agau-table-era-zips \
  /tmp/readagau-weekly-direct-pdfs \
  /tmp/readagau-weekly-fallbacks \
  /tmp/readagau-weekly-final-475-audit.csv
```

The fallback directory supplies the authoritative 13 January 2022 PDF and the
18 April 2024 and 18 September 2025 Word reports. The audit script asserts
catalogue uniqueness, exact date identity, canonical validation and unique
release-date/hash identity before writing evidence.
