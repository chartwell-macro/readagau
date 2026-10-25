# CRAN comments

This file records validation of the development branch
`codex/readagau-docs-cran-20260824`. It is not a CRAN submission and does not
claim CRAN acceptance.

## Test environment

- R 4.5.1 (2025-06-13), aarch64-apple-darwin24.4.0
- macOS Sequoia 15.6, Apple clang 17.0.0, GNU Fortran from GCC 15.1.0
- UTF-8 locale
- qpdf, HTML Tidy, Poppler `pdftotext`, and Pandoc available from Homebrew

## Local validation

- The complete package test suite passed from the source tree. Seven tests
  that require opt-in live or unbundled official source files were skipped as
  designed; deterministic packaged-fixture coverage passed.
- The final source tarball, including all nine vignettes, was built and
  installed in an isolated library. Its SHA-256 digest is
  `a242430d7a861ab6edb881ca02c066d943428df31c5af10d855569d95fc1dee6`.
- `R CMD check --as-cran --timings --no-manual` completed with 0 ERRORs,
  0 WARNINGs, and 1 NOTE. The NOTE combines new-submission status with the
  private GitHub and unpublished GitHub Pages URLs returning 404 to
  unauthenticated checks.
- `pkgdown::check_pkgdown()` passed. A disposable site build produced 46 HTML
  pages containing all 26 reference topics and nine articles. A local crawl
  found no missing targets or fragments, and no visible rendering warnings.
  The README and Getting Started time-series charts rendered from installed
  synthetic fixtures with responsive markup and meaningful alternative text.
- The README was rendered twice against an isolated installation with
  byte-identical Markdown and PNG output. All nine vignettes rendered from
  source, including the deterministic end-to-end chart workflow.
- `Authors@R` parses with Chartwell Macro as `aut`/`cre`/`cph` and uses the required
  non-personal GitHub noreply address. Built Author and Maintainer fields,
  package help, and citation metadata consistently identify Chartwell Macro.
- The package-name audit found no case-insensitive `readagau` match in the
  current CRAN package index, CRAN Archive, or Bioconductor release index on
  24 August 2026.

## Compatibility and performance

- An isolated, fixture-backed comparison against the published integration
  pin `pre-publication baseline` matched reader values, names,
  order, classes, attributes, dates, warnings, errors, and cache side-effect
  structure. Intentional changes are limited to attribution text, bounded
  network behavior, locale-independent date handling, a typed missing-Poppler
  condition, and rejection of unsafe ZIP member paths.
- Balanced same-host benchmarks alternated candidate and baseline order and
  used 30-100 paired batches per workflow. The stable cached Crop Report path
  changed by +1.20% at the median and +0.35% at p95 (+0.89% user-CPU p95).
  Weekly HTML parsing changed by -1.22% at the median and -6.00% at p95;
  release-catalogue construction changed by +0.18% and +0.40%; cached
  Agricultural Commodities parsing changed by -1.99% and +7.60%. All are
  within the 5% median and 10% p95 budgets. Every compared output digest
  matched, no warning was emitted, and no network request was made.
- Read-only Chartwell provider contract validation against an isolated
  installation of the settled source passed 458 expectations across 53 test
  blocks, with no failure, error, warning, or skip. Chartwell itself and its
  package SHA pin were not changed.

## Notes

- The repository and GitHub Pages site are private or unpublished before this
  branch push. Consequently, unauthenticated URL checks currently return 404
  for the repository, issue tracker, and pkgdown URLs. This is an external
  publication blocker and is not described as a clean URL check.
- GitHub Actions runs triggered for the pushed documentation branch were
  rejected before any job step by an account billing/spending-limit block.
  Multi-platform CI is therefore not claimed until that external account
  issue is resolved and the workflows are rerun.
- Poppler is required only for PDF input. All other documented first-success
  workflows run offline using package-owned synthetic fixtures.
- Package code and package-owned synthetic fixtures are licensed under MIT,
  copyright Chartwell Macro. Upstream data, provider names, and source URLs remain
  subject to their own terms; no upstream source values or official source
  bytes are bundled.
- Before a CRAN submission, the maintainer must confirm that the non-personal
  address in `Authors@R` is monitored and deliverable, and recheck package-name
  availability and public URL reachability.
