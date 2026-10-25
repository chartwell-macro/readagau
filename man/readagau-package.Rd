\name{readagau-package}
\alias{readagau}
\alias{readagau-package}
\docType{package}
\title{Reproducible Australian Agricultural Data}
\description{
Discover, cache, parse, validate and compare versioned Australian agricultural
data releases published by ABARES.
}
\details{
\code{readagau} keeps official release discovery, immutable transport,
product-specific parsing, canonicalisation, provenance and vintage analysis
separate. Supported readers retain source, release, table, semantic,
content-hash and parser provenance.

Start with \code{\link{list_agau_releases}} and a product reader such as
\code{\link{read_crop_report}}. Use \code{\link{agau_attribution}} before
publishing derived results.
}
\seealso{
\code{\link{read_agricultural_commodities}},
\code{\link{read_farm_productivity}},
\code{\link{read_agau_forecast_history}},
\code{\link{compare_agau_vintages}}
}
\author{Chartwell Macro}
\keyword{package}
