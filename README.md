# Omdesky Omarchy plugin

Native Omarchy bar widget for [Omdesky](https://github.com/limahigor/omdesky).
It lists your Omdesky devices and lets you start a remote desktop session with
a single click, without leaving the bar.

## Features

- Shows the Omdesky mark in the bar, matching the TUI header
- Left click opens a keyboard-friendly panel with your devices
- Middle click refreshes the device list
- Click a ready device to start the connection in a terminal
- A settings button opens the full Omdesky terminal interface
- Offline, incompatible, and unavailable devices are shown but not clickable

## Keyboard shortcuts

Inside the panel:

- `j` / `k` or arrows: move the cursor
- `enter` / `space`: connect to the selected device
- `r`: refresh the device list
- `esc`: close

## Requirements

- The [`omdesky`](https://github.com/limahigor/omdesky) CLI installed by its Arch package in `/usr/bin`, or by its standalone installer in `~/.local/bin`

Omdesky 0.2 refuses control requests from devices that are not on its allowlist, so a device can be listed as ready and still reject the connection. Run `omdesky access allow <device>` on both computers; the terminal that opens on connect shows the refusal if one is missing.

The widget resolves only those trusted installation locations. It uses a supervised helper with bounded output, device and field limits, a closed environment, and enforced terminate, kill, and reap cleanup. Connections still launch `omdesky connect <name> --input remote` in the Omarchy terminal so you can follow progress and see any errors.

## Install

The plugin is a git repository with `manifest.json` at its root, so Omarchy can
install it directly:

```bash
omarchy plugin add https://github.com/limahigor/omdesky-plugin.git --enable
```

### Install by hand

1. Copy this directory to `~/.config/omarchy/plugins/omdesky.remote/`.
2. Reload the shell: `omarchy-shell shell rescanPlugins`.
3. Enable it: `omarchy plugin enable omdesky.remote`.

## Configuration

The helper requires `/usr/bin/python3`, included by the standard Omarchy installation.

The widget exposes one setting, editable from Setup > Plugins:

- `refreshIntervalSec` — how often the device list refreshes (default 30s).

## License

Available under the [MIT License](LICENSE).
