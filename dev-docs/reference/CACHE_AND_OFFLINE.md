# Cache and offline use

<!-- Development reference; installed help contains the package-facing contract. -->

This is maintainer guidance. The package root README, installed help and
source-files vignette are the user-facing instructions; this page records the
cache invariants used by tests and release review.

Raw files are content-addressed at
`raw/<product>/<release_id>/<sha256>/<asset>`. A download is staged in the
target directory, signature-checked, hashed and atomically renamed. A valid
persisted release/asset/source-URL manifest hit is returned without network
access. Refresh may append a new hash but never deletes or overwrites old raw
bytes.

For fully offline work, retain both `discovery/releases.rds` and the `raw`
tree, or pass local workbook paths to the readers. Parsing never performs a
network request. Invalid and HTML-masquerading downloads are not promoted.

`agau_cache_dir()` uses the managed `tools::R_user_dir()` location by default;
tests and examples should use a temporary `cache_dir`. An exact release ID,
source URL and SHA-256 hash should travel with derived output. Weekly local
snapshots likewise return values with their source and rights/provenance
fields; a cache hit does not change the source's terms.
