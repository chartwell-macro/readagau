# Release process

<!-- Development reference; excluded from the package tarball. -->

## Metadata

- Confirm version, maintainer name and monitored email.
- Add public repository and `BugReports` URLs to `DESCRIPTION`.
- Configure private security and conduct-reporting channels.
- Update citation files, `NEWS.md` and support policies.

## Product and parser evidence

- Audit each newly supported official edition or product.
- Record exact pages, asset roles and SHA-256 hashes.
- Update table mappings, counts and raw-cell goldens.
- Test reported and public-default canonical views.
- Run duplicate, conflict, missing-marker and structural-break gates.
- Bump the parser/cache profile when cached semantics change.

## Attribution and fixtures

- Reconfirm ABARES and named-provider attribution.
- Verify weekly table, report, archive and accessible-chart source mappings.
- Verify fixtures and retained source evidence have stable hashes.

## Verification

```sh
Rscript -e 'testthat::test_local(".", reporter = "summary")'
R CMD build .
R CMD check --no-manual readagau_<version>.tar.gz
R CMD check --as-cran readagau_<version>.tar.gz
```

Also run official-workbook semantic validation, every supported canonical
default, three cold/warm benchmark repetitions, peak RSS and independent
review.

## Documentation and website

- Render all examples and vignettes.
- Build the pkgdown site with `pkgdown::build_site()`.
- Check links and API grouping.
- Confirm product support, attribution, troubleshooting and release
  pages match the release.

## Publish

Create an immutable tag only after every gate passes. Record the commit and
artifact hashes, publish release notes and never move the tag.
