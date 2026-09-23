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

This version requires Omdesky 0.2 or later on the same release line; an older CLI is reported as unsupported.

Omdesky 0.2 requires each computer to list the other with `omdesky access allow <device>`. A blocked device cannot be clicked: its label says why ("Incompatible", "Access denied" or "Allow it here") and its subtitle gives the command to run and on which computer.

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

## Security

The widget runs inside `omarchy-shell`, so it treats everything it reads as untrusted. The QML starts processes only through `/usr/bin/python3 -I omdesky_runner.py` with a cleared environment and an argument vector, never a shell. The helper bounds output size, run time and every field, strips control and bidirectional characters, and connects only to a validated Tailscale address.

To check a working copy the way CI does:

```bash
scripts/validate-plugin.sh .
omarchy plugin validate .
python3 -I -m unittest discover -s tests
node tests/model.test.js
```

The widget exposes one setting, editable from Setup > Plugins:

- `refreshIntervalSec` — how often the device list refreshes (default 30s).

## License

Available under the [MIT License](LICENSE).
