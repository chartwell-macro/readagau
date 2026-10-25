# Development records

This directory retains the package's engineering documentation. It is
excluded from the built R package by `.Rbuildignore`.

These files are maintainer-facing context, not a second user manual. Current
user-facing product support and examples are documented in the package root
[`README.md`](../README.md), generated installed help and the task-oriented
[`vignettes/`](../vignettes/) directory. The durable map of which source is
authoritative for each kind of information is [`CONTENT_MAP.md`](CONTENT_MAP.md).

- `reference/` contains current API, support, cache and release guidance.
- `evidence/` contains the quarterly-history and weekly-price audits.
- `archive/` contains historical plans, decisions and review records. Those
  files describe earlier implementation stages and are retained as evidence,
  rather than as statements of current package support.

Roxygen comments in `R/` are the source for exported API help; generated
`man/` pages and `NAMESPACE` should be regenerated rather than edited by hand.
`NEWS.md` records package changes, while this directory records the evidence
and decisions behind them.
