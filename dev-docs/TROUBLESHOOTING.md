# Troubleshooting

<!-- Development reference; installed help contains package-facing guidance. -->

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

## Rights-gated data is refused

`agau_rights_error` is expected when a requested weekly-price or fertiliser
series is restricted or `review-required`. Use
`redistribution = "all_metadata"` to inspect provenance and the blocker.

## Offline replay reaches the network

Confirm the exact release has every requested asset and the same `cache_dir`
is used. Keep both the discovery manifest and content-addressed raw tree for a
fully offline environment.

## Reporting a problem

Follow `SUPPORT.md`. Do not attach official workbooks or restricted data;
provide source URLs, SHA-256 hashes and a reduced synthetic reproduction.
