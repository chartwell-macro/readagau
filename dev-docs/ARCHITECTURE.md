# Architecture

<!-- Development reference; excluded from the package tarball. -->

```text
official product/archive pages
    -> exact edition-page discovery
    -> release and rights manifests
    -> verified immutable raw assets
    -> product-specific structural parsers
    -> reported observations
    -> canonical policy and validation
    -> catalogues, revisions and forecast errors
```

## Discovery

Release identity and asset URLs come from official HTML metadata. Discovery
records supported, discovered-unverified and unsupported states separately.
It does not fabricate releases or URLs.

## Transport and cache

Downloads are staged, byte-signature checked, hashed and atomically promoted.
Content-addressed raw paths are immutable. Release and asset manifest writes
are locked and merge stale snapshots rather than losing concurrent updates.

## Parsing

Each parser accepts local files and uses semantic headers plus structural
fingerprints. File type is detected from bytes. Every admitted data-like cell
must map to a table or cause a typed schema error.

## Normalisation

Shared contracts normalise time, status, missingness and provenance.
Product-specific hierarchy is retained in explicit semantic fields. Reported
observations remain available even when a canonical view is requested.

## Rights-gated surfaces

Weekly prices and fertiliser are admitted through a separate metadata and
rights path. Endpoint and redistribution gates run before values can be
returned. A visual dashboard or image is not a production data contract.

## Analysis

Catalogues, validation, revision and forecast-error functions operate on the
stable observation model and cached vintages. They do not reinterpret raw
assets or silently cross structural breaks.
