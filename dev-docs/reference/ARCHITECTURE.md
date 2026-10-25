# Architecture

<!-- Development reference; excluded from the package tarball. -->

```text
official product/archive pages
    -> exact edition-page discovery
    -> release and asset manifests
    -> verified immutable raw assets
    -> product-specific structural parsers
    -> reported observations
    -> canonical policy and validation
    -> catalogues, revisions and forecast errors
```

## Discovery

Release identity and asset URLs come from official HTML metadata. The
checked-in catalogue maps every supported edition to exact official assets.

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

## Weekly prices

Weekly tables, dated PDF/Word reports, text extracts, quarterly ZIP archives
and current accessible-chart descriptions share one canonical weekly-price
contract. Snapshot date, observation date, provider, unit, raw value and
source hash remain attached to every observation.

## Analysis

Catalogues, validation, revision and forecast-error functions operate on the
stable observation model and cached vintages while retaining structural
breaks explicitly.
