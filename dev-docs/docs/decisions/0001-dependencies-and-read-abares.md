# Decision 0001: dependencies and relationship to read.abares

Status: accepted, 2026-07-27

Stage 0 uses base R only at runtime. `testthat (>= 3.0.0)` is suggested for the
offline contract suite. The implementation plan's proposed transport and parser
dependencies remain approved candidates and are added only in the phase that
uses them.

`read.abares` remains useful prior art for Historical Agricultural Forecast
Database field semantics. It is not a mandatory runtime dependency and does not
define the broader `readagau` scope. Any future compatibility helper must
retain source URL, retrieval time and hash and must not copy the package's
geospatial dependency footprint into `readagau`.
