#!/usr/bin/python3

import ipaddress
import json
import math
import os
from pathlib import Path
import selectors
import signal
import stat
import subprocess
import sys
import time
import unicodedata


MAX_STDOUT_BYTES = 1024 * 1024
MAX_STDERR_BYTES = 64 * 1024
MAX_ENVELOPE_BYTES = 128 * 1024
MAX_DEVICES = 128
MAX_NAME_BYTES = 256
MAX_ADDRESS_BYTES = 64
MAX_STATUS_BYTES = 32
MAX_CONNECTION_BYTES = 32
MAX_VERSION_BYTES = 128
MAX_BLOCKERS = 4
MAX_BLOCKER_CODE_BYTES = 32
MAX_BLOCKER_FIX_BYTES = 256
SUPPORTED_SCHEMA = 1
TAILSCALE_NETWORKS = (
    ipaddress.ip_network("100.64.0.0/10"),
    ipaddress.ip_network("fd7a:115c:a1e0::/48"),
)
QUERY_TIMEOUT_SECONDS = 12
TERMINATE_GRACE_SECONDS = 1


def candidate_paths():
    home = Path.home()
    return [(Path("/usr/bin/omdesky"), 0), (home / ".local/bin/omdesky", os.getuid())]


def resolve_omdesky(candidates=None):
    for path, expected_owner in candidates or candidate_paths():
        try:
            metadata = path.stat()
            resolved = path.resolve(strict=True)
            resolved_metadata = resolved.stat()
        except (OSError, RuntimeError):
            continue

        valid = (
            stat.S_ISREG(metadata.st_mode)
            and stat.S_ISREG(resolved_metadata.st_mode)
            and os.access(resolved, os.X_OK)
            and metadata.st_uid == expected_owner
            and resolved_metadata.st_uid == expected_owner
            and metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH) == 0
            and resolved_metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH) == 0
        )

        if valid:
            return resolved

    return None


def closed_environment():
    environment = {
        "PATH": "/usr/local/bin:/usr/bin",
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }

    for name in (
        "HOME",
        "USER",
        "LOGNAME",
        "XDG_CONFIG_HOME",
        "XDG_DATA_HOME",
        "XDG_CACHE_HOME",
        "XDG_STATE_HOME",
        "XDG_RUNTIME_DIR",
        "DBUS_SESSION_BUS_ADDRESS",
        "WAYLAND_DISPLAY",
        "DISPLAY",
        "HYPRLAND_INSTANCE_SIGNATURE",
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE",
    ):
        value = os.environ.get(name)

        if value:
            environment[name] = value

    return environment


def clean_text(value):
    return "".join(
        character
        for character in value
        if unicodedata.category(character) not in {"Cc", "Cf", "Cs", "Co", "Cn"}
        and character not in "\u2028\u2029"
    )


def bounded_text(value, byte_limit):
    if not isinstance(value, str):
        value = "" if value is None else str(value)

    value = clean_text(value)

    encoded = value.encode("utf-8")

    if len(encoded) <= byte_limit:
        return value

    return encoded[:byte_limit].decode("utf-8", errors="ignore")


def tailscale_address(value):
    if not isinstance(value, str) or len(value) > MAX_ADDRESS_BYTES:
        return None

    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return None

    if not any(address in network for network in TAILSCALE_NETWORKS):
        return None

    return address


def normalize_blockers(value):
    if not isinstance(value, list):
        return []

    blockers = []

    for blocker in value[:MAX_BLOCKERS]:
        if not isinstance(blocker, dict):
            continue

        blockers.append(
            {
                "code": bounded_text(blocker.get("code"), MAX_BLOCKER_CODE_BYTES),
                "side": bounded_text(blocker.get("side"), MAX_BLOCKER_CODE_BYTES),
                "fix": bounded_text(blocker.get("fix"), MAX_BLOCKER_FIX_BYTES),
            }
        )

    return blockers


def normalize_device(entry):
    if not isinstance(entry, dict):
        return None

    latency = entry.get("latency_ms")

    if isinstance(latency, bool) or not isinstance(latency, (int, float)):
        latency = None
    elif not math.isfinite(latency) or latency < 0 or latency > 600000:
        latency = None
    else:
        latency = int(latency)

    return {
        "name": bounded_text(entry.get("name"), MAX_NAME_BYTES),
        "address": str(tailscale_address(entry.get("address")) or ""),
        "status": bounded_text(entry.get("status"), MAX_STATUS_BYTES),
        "blockers": normalize_blockers(entry.get("blockers")),
        "connection": bounded_text(entry.get("connection"), MAX_CONNECTION_BYTES),
        "latencyMs": latency,
        "isLocal": entry.get("is_local") is True,
        "agentVersion": bounded_text(entry.get("agent_version"), MAX_VERSION_BYTES),
        "omarchyVersion": bounded_text(entry.get("omarchy_version"), MAX_VERSION_BYTES),
    }


def terminate_and_reap(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass

    try:
        process.wait(timeout=TERMINATE_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        pass

    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass

    process.wait()


def close_streams(process):
    for stream in (process.stdout, process.stderr):
        if stream is not None and not stream.closed:
            stream.close()


def run_bounded(command, timeout_seconds, stdout_limit, stderr_limit):
    process = subprocess.Popen(
        [str(argument) for argument in command],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=closed_environment(),
        start_new_session=True,
    )
    selector = selectors.DefaultSelector()
    stdout = bytearray()
    stderr = bytearray()
    deadline = time.monotonic() + timeout_seconds

    selector.register(process.stdout, selectors.EVENT_READ, (stdout, stdout_limit))
    selector.register(process.stderr, selectors.EVENT_READ, (stderr, stderr_limit))

    try:
        while selector.get_map():
            remaining = deadline - time.monotonic()

            if remaining <= 0:
                terminate_and_reap(process)
                return None, None, "timeout"

            events = selector.select(min(remaining, 0.1))

            for key, _ in events:
                chunk = os.read(key.fileobj.fileno(), 8192)

                if not chunk:
                    selector.unregister(key.fileobj)
                    key.fileobj.close()
                    continue

                destination, limit = key.data

                if len(destination) + len(chunk) > limit:
                    terminate_and_reap(process)
                    return None, None, "output_limit"

                destination.extend(chunk)

        return_code = process.wait()
    except BaseException:
        terminate_and_reap(process)
        raise
    finally:
        selector.close()
        close_streams(process)

    return return_code, (bytes(stdout), bytes(stderr)), None


def error(code, message):
    return {"ok": False, "code": code, "message": bounded_text(message, 256)}


def query_devices(executable, stdout_limit=MAX_STDOUT_BYTES):
    return_code, output, failure = run_bounded(
        [executable, "devices", "--json"],
        QUERY_TIMEOUT_SECONDS,
        stdout_limit,
        MAX_STDERR_BYTES,
    )

    if failure == "timeout":
        return error("timeout", "Device query timed out")

    if failure == "output_limit":
        return error("output_limit", "Device query exceeded the safe output limit")

    stdout, stderr = output

    if return_code != 0:
        message = stderr.decode("utf-8", errors="replace").strip()
        return error("command_failed", message or "Could not list devices")

    try:
        data = json.loads(stdout)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return error("invalid_output", "Omdesky returned invalid device data")

    schema = data.get("schema") if isinstance(data, dict) else None

    if type(schema) is not int or schema != SUPPORTED_SCHEMA:
        return error(
            "unsupported_schema",
            "This Omdesky version is not supported by the plugin; update both",
        )

    entries = data.get("devices")

    if not isinstance(entries, list):
        return error("invalid_output", "Omdesky returned unexpected device data")

    devices = []

    for entry in entries[:MAX_DEVICES]:
        device = normalize_device(entry)

        if device is not None and not device["isLocal"]:
            devices.append(device)

    return {
        "ok": True,
        "devices": devices,
        "truncated": len(entries) > MAX_DEVICES,
    }


def trusted_launcher():
    candidate = Path("/usr/share/omarchy/bin/omarchy-launch-tui")

    try:
        resolved = candidate.resolve(strict=True)
        metadata = resolved.stat()
    except (OSError, RuntimeError):
        return None

    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_uid != 0
        or metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH)
        or not os.access(resolved, os.X_OK)
    ):
        return None

    return resolved


def launch(executable, target=None):
    launcher = trusted_launcher()

    if launcher is None:
        return error("launcher_unavailable", "Omarchy terminal launcher is unavailable")

    command = [
        str(launcher),
        "--app-id=org.omarchy.omdesky",
        str(executable),
    ]

    if target is not None:
        command.extend(["connect", "--input", "remote", "--", str(target)])

    try:
        subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=closed_environment(),
            start_new_session=True,
        )
    except OSError:
        return error("launch_failed", "Could not start Omdesky")

    return {"ok": True}


def emit(result):
    encoded = json.dumps(result, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    if len(encoded) > MAX_ENVELOPE_BYTES:
        encoded = json.dumps(
            error("output_limit", "Normalized device data exceeded the safe output limit"),
            separators=(",", ":"),
        ).encode("utf-8")

    sys.stdout.buffer.write(encoded + b"\n")


def main(arguments):
    if len(arguments) < 2 or arguments[1] not in {"probe", "devices", "open", "connect"}:
        emit(error("invalid_command", "Invalid plugin helper command"))
        return 2

    executable = resolve_omdesky()

    if arguments[1] == "probe":
        emit({"ok": True, "installed": executable is not None})
        return 0

    if executable is None:
        emit(error("not_installed", "Omdesky is not installed in a trusted location"))
        return 1

    if arguments[1] == "devices":
        result = query_devices(executable)
    elif arguments[1] == "open":
        result = launch(executable)
    elif len(arguments) != 3:
        result = error("invalid_command", "A device address is required")
    elif (address := tailscale_address(arguments[2])) is None:
        result = error("invalid_target", "The device address is not a Tailscale address")
    else:
        result = launch(executable, address)

    emit(result)
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
