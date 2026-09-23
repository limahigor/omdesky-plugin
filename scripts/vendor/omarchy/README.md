# Vendored Omarchy plugin validator

`omarchy-plugin-validate` is an unmodified copy of Omarchy's plugin manifest
validator, so CI can run the same checks as `omarchy plugin validate` and
`omarchy plugin add` without installing Omarchy or downloading code at build
time.

- Source: <https://github.com/basecamp/omarchy/blob/v4.0.4/bin/omarchy-plugin-validate>
- Tag: `v4.0.4` (commit `c668141e9c42b13c80c9ca4ea108e11708c5e8a5`)
- SHA-256: listed in `SHA256SUMS` and checked by CI before the script runs
- License: MIT, see `LICENSE` (Copyright (c) David Heinemeier Hansson)

To update it, copy `bin/omarchy-plugin-validate` from a newer Omarchy tag,
regenerate `SHA256SUMS` with `sha256sum omarchy-plugin-validate > SHA256SUMS`,
and update the tag and commit above.
