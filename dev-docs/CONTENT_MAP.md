# Documentation source-of-truth map

This short map prevents the excluded `dev-docs/` material from drifting into a
second public manual. It records where maintainers should update each kind of
information.

| Audience or job | Canonical source | Role of this repository guide |
|---|---|---|
| New user: install and first successful offline read | [`README.md`](../README.md), then [`vignettes/getting-started.Rmd`](../vignettes/getting-started.Rmd) | Link and review, not duplicate the workflow |
| Analyst: product-specific tasks, cache, source files and vintages | Task vignettes in [`vignettes/`](../vignettes/) | Keep implementation/evidence context |
| API user: signatures, defaults, returns, classes, conditions and examples | Roxygen comments in [`R/`](../R/) and generated [`man/`](../man/) | [`API_REFERENCE.md`](reference/API_REFERENCE.md) is only a navigation map |
| User: package changes and release notes | [`NEWS.md`](../NEWS.md) | Do not repeat mutable counts or changelog entries |
| Maintainer: supported source/release identity | `inst/catalogue/{release-catalog,weekly-release-catalog,source-catalog}.csv` and `inst/config/{supported-matrix,product-pages,weekly-series}.csv` | [`SUPPORTED_PRODUCTS.md`](reference/SUPPORTED_PRODUCTS.md) describes domains and points to these registries |
| Maintainer: observation and manifest schemas | `inst/schema/{observation,release-manifest,raw-asset-manifest}.csv` and `agau_*_schema()` help | Preserve schema rationale and test evidence here; do not copy columns into prose |
| User: source attribution, provider terms and package licence boundary | [`agau_attribution()`](../R/attribution.R), [`inst/CITATION`](../inst/CITATION), `LICENSE` and upstream source terms | [`ATTRIBUTION.md`](reference/ATTRIBUTION.md) records audit decisions |
| Maintainer: offline fixtures and provenance | [`inst/fixtures/README.md`](../inst/fixtures/README.md), generator/tooling and [Decision 0002](archive/decisions/0002-fixtures-and-licensing.md) | Keep fixtures deterministic, synthetic and rights-safe |
| Contributor: checks, issue and security workflow | [`CONTRIBUTING.md`](reference/CONTRIBUTING.md), [`SECURITY.md`](reference/SECURITY.md), [`SUPPORT.md`](reference/SUPPORT.md) | Keep repository process guidance current without promising support service levels |

The root README and installed help/vignettes are the package-facing contract.
If a development note differs from generated help or the registries, update
the Roxygen source or registry first, regenerate artifacts, and then revise the
note. Weekly readers return values with source-specific provenance and rights
fields; reuse of upstream data remains governed by its source terms.
