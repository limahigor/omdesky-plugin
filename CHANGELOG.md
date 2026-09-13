# Changelog

All notable changes to the Omdesky Omarchy plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.1]: https://github.com/limahigor/omdesky-plugin/releases/tag/v0.1.1
[0.1.0]: https://github.com/limahigor/omdesky-plugin/releases/tag/v0.1.0
