# Changelog

All notable changes to the Omdesky Omarchy plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-23

### Changed

- **Breaking:** requires Omdesky 0.2. The helper reads the versioned `{"schema": 1, "devices": [...]}` output and reports an unsupported schema instead of guessing at another format.

### Added

- Blocked devices show why they cannot connect — "Incompatible", "Access denied" or "Allow it here" — and the row subtitle gives the command to run and on which computer.
- `scripts/validate-plugin.sh` and a CI workflow run the Omarchy manifest checks plus the plugin's own security checks and tests on every push.
- The README documents how to remove the plugin and lists its external dependencies.

### Security

- Connections target the device's validated Tailscale address, passed after `--`, instead of its name, so a hostile device name can neither become a command-line option nor select another device.
- Text from the CLI loses control, format and bidirectional characters before it reaches the bar.
- The helper runs through `/usr/bin/python3 -I`, so it depends neither on its executable bit nor on `PYTHON*` variables or user site packages.

### Fixed

- The front square of the bar icon is no longer filled with the background colour, so the mark stays an outline on any bar theme.
- The bar icon keeps the bar's full foreground colour instead of dimming when no device is ready.

## [0.1.1] - 2026-09-13

### Security

- Bound device command output, device count, and every retained field before data reaches QML.
- Resolve Omdesky only from trusted package or standalone installation paths and execute it with a closed environment.
- Supervise device queries with timeout, process-group termination, forced kill, and child reaping.

## [0.1.0] - 2026-09-12

First release. A native Omarchy bar widget for Omdesky.

### Added

- Bar widget showing the Omdesky mark, matching the TUI header.
- Keyboard-friendly panel that lists devices from `omdesky devices --json`.
- Click or press enter on a ready device to connect in the Omarchy terminal.
- Settings button that opens the full Omdesky terminal interface.
- Middle click and the `r` key refresh the device list.
- Configurable refresh interval.

[Unreleased]: https://github.com/limahigor/omdesky-plugin/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/limahigor/omdesky-plugin/releases/tag/v0.2.0
[0.1.1]: https://github.com/limahigor/omdesky-plugin/releases/tag/v0.1.1
[0.1.0]: https://github.com/limahigor/omdesky-plugin/releases/tag/v0.1.0
