# Cache and offline use

<!-- Development reference; installed help contains the package-facing contract. -->

Raw files are content-addressed at
`raw/<product>/<release_id>/<sha256>/<asset>`. A download is staged in the
target directory, signature-checked, hashed and atomically renamed. A valid
persisted release/asset/source-URL manifest hit is returned without network
access. Refresh may append a new hash but never deletes or overwrites old raw
bytes.

For fully offline work, retain both `discovery/releases.rds` and the `raw`
tree, or pass local workbook paths to the readers. Parsing never performs a
network request. Invalid and HTML-masquerading downloads are not promoted.
