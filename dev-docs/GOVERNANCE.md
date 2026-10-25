# Governance

<!-- Development reference; excluded from the package tarball. -->

`readagau` is currently maintainer-led.

## Roles

- Maintainers approve releases, APIs, product admission, rights decisions and
  security responses.
- Contributors propose code, documentation, fixtures and evidence.
- Independent reviewers reproduce parser and source evidence before a support
  claim or public release.

## Decisions

Routine fixes are decided through review. Changes to the observation schema,
status vocabulary, cache immutability, canonical policy, rights posture or
support definition require a decision record under `docs/decisions/`.

An ambiguous source, unstable endpoint or unresolved rights condition is
recorded explicitly. It is not resolved through guessed semantics or an
unreviewed scraper.

## Releases

A maintainer owns the release checklist. Releases require clean package
checks, documentation, source and fixture audits, performance evidence,
independent reproduction and a pinned commit. Tags are immutable.

## Deprecation

Public functions and stable schema fields receive a documented deprecation
period before removal unless continued behaviour would be unsafe or materially
incorrect. Parser, rights and supported-release changes are recorded in
`NEWS.md`.
