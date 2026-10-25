# Security policy

<!-- Development reference; excluded from the package tarball. -->

## Supported versions

Until the first public release, only the current default branch is eligible
for security fixes. Supported public versions will be listed here and in
release notes.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities involving arbitrary file
writes, path traversal, cache poisoning, credential exposure, unsafe content
handling or leakage of rights-restricted values.

Use the repository's private security-advisory channel after the public remote
is configured. The `example.com` address in `DESCRIPTION` is a known
placeholder and is not a valid security contact. A monitored private contact
is mandatory before publication.

Include the affected commit/version, a synthetic reproduction, impact,
preconditions and any suggested remediation.

## Security and rights boundaries

Source files and HTML are untrusted input. Downloads are staged,
signature-checked and hashed before promotion. Workbook macros and scripts are
not executed. Rights statuses fail closed: unknown or review-required data
cannot be returned through the permitted public-value path.
