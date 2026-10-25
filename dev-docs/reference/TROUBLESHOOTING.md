# Troubleshooting

<!-- Development reference; installed help contains package-facing guidance. -->

Use installed help and the task vignettes for user workflows. The typed
conditions below are the stable diagnostic families; exact text and fields are
defined by the Roxygen documentation and tests.

## Discovery or download fails

`agau_release_discovery_error` concerns official page discovery.
`agau_asset_missing_error` means an expected role is absent.
`agau_download_error` concerns transport or an incomplete exact cache.

Refreshing discovery never deletes a valid raw snapshot.

## A file has the wrong extension

Use `agau_detect_format()` to inspect bytes. The source sometimes publishes
OOXML with an `.xls` filename. Renaming is unnecessary; bytes determine the
reader.

## A workbook is rejected

`agau_schema_error` or `agau_table_parse_error` means the workbook no longer
matches an audited structural profile or contains unexplained payload. Do not
drop rows or weaken validation. Report the product, release, sheet/table,
source hash and parser version.

## Canonical view reports a collision

Use the reported view to inspect the conflicting hierarchy. A collision often
means a state, input type, section or other semantic label has not been
retained. The correct fix is to preserve that source dimension, not deduplicate
different values.

## Weekly-price input is rejected

Confirm the input is a supported dated table, PDF/Word report, text extract,
quarterly archive or current accessible-chart description. Report the
snapshot date, provider, source hash and parser version with any schema error.

## A weekly result needs a rights or attribution review

`read_agau_prices()` returns parsed weekly observations, including source URL,
provider, published-unit, hash and `rights_status`/provenance fields where
available. It does not make a legal reuse determination. Use
`agau_attribution()` and the upstream publication/provider terms before
publishing or reusing a result. Report the source identity and terms when
asking a rights question.

## Offline replay reaches the network

Confirm the exact release has every requested asset and the same `cache_dir`
is used. Keep both the discovery manifest and content-addressed raw tree for a
fully offline environment.

## Reporting a problem

Follow `SUPPORT.md` and provide source URLs, SHA-256 hashes and a focused
reproduction.
