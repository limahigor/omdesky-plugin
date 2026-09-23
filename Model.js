function blockerLabel(code) {
  var value = String(code || "").toLowerCase()
  if (value === "incompatible") return "Incompatible"
  if (value === "denied") return "Access denied"
  if (value === "needs_access") return "Allow it here"
  return "Blocked"
}

function statusMeta(status, blockers) {
  var value = String(status || "").toLowerCase()
  if (value === "ready") return { label: "Ready", ready: true }
  if (value === "offline") return { label: "Offline", ready: false }
  if (value === "unavailable") return { label: "Agent unavailable", ready: false }
  if (value === "blocked") {
    var first = Array.isArray(blockers) && blockers.length > 0 ? blockers[0] : null
    return { label: blockerLabel(first ? first.code : ""), ready: false }
  }
  return { label: value === "" ? "Unknown" : value, ready: false }
}

function deviceStatus(device) {
  if (!device) return statusMeta("", [])
  var meta = statusMeta(device.status, device.blockers)
  if (meta.ready && String(device.address || "") === "") return { label: "No address", ready: false }
  return meta
}

function connectionLabel(kind) {
  var value = String(kind || "").toLowerCase()
  if (value === "direct") return "Direct"
  if (value === "relay") return "Relay"
  return ""
}

function latencyLabel(ms) {
  return typeof ms === "number" ? String(ms) + "ms" : ""
}

function osIcon(device) {
  return deviceStatus(device).ready ? "󰇄" : "󰢹"
}

function boundedString(value, limit) {
  return Array.from(String(value || "")).slice(0, limit).join("")
}

function blockersFromJson(value) {
  if (!Array.isArray(value)) return []
  var out = []
  var count = Math.min(value.length, 4)
  for (var i = 0; i < count; i++) {
    var blocker = value[i]
    if (!blocker || typeof blocker !== "object") continue
    out.push({
      code: boundedString(blocker.code, 32),
      side: boundedString(blocker.side, 32),
      fix: boundedString(blocker.fix, 256)
    })
  }
  return out
}

function deviceFromJson(entry) {
  var source = entry || {}
  var latency = source.latencyMs
  if (typeof latency !== "number" || !isFinite(latency) || latency < 0 || latency > 600000) latency = null
  return {
    name: boundedString(source.name, 256),
    address: boundedString(source.address, 64),
    status: boundedString(source.status, 32),
    blockers: blockersFromJson(source.blockers),
    connection: boundedString(source.connection, 32),
    latencyMs: latency === null ? null : Math.floor(latency),
    isLocal: source.isLocal === true,
    agentVersion: boundedString(source.agentVersion, 128),
    omarchyVersion: boundedString(source.omarchyVersion, 128)
  }
}

function blockerHint(device) {
  if (!device || !Array.isArray(device.blockers) || device.blockers.length === 0) return ""
  var blocker = device.blockers[0]
  if (blocker.fix === "") return ""
  var place = blocker.side === "local" ? "on this computer" : "on " + device.name
  if (blocker.code === "incompatible") return blocker.fix + " " + place
  return "Run " + blocker.fix + " " + place
}

function subtitle(device) {
  if (!device) return ""
  var hint = blockerHint(device)
  if (hint !== "") return hint
  var parts = []
  var connection = connectionLabel(device.connection)
  if (connection !== "") parts.push(connection)
  var latency = latencyLabel(device.latencyMs)
  if (latency !== "") parts.push(latency)
  if (device.address !== "") parts.push(device.address)
  return parts.join(" · ")
}

function parseDevices(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: true, devices: [] }

  try {
    var data = JSON.parse(text)
    if (!(data && data.ok === true && Array.isArray(data.devices))) {
      var error = data && data.message ? boundedString(data.message, 256) : "Unexpected devices output"
      return { ok: false, devices: [], error: error }
    }

    var out = []
    var count = Math.min(data.devices.length, 128)
    for (var i = 0; i < count; i++) {
      if (!data.devices[i] || typeof data.devices[i] !== "object") continue
      var device = deviceFromJson(data.devices[i])
      if (device.isLocal) continue
      out.push(device)
    }

    out.sort(function(a, b) {
      var aReady = deviceStatus(a).ready ? 0 : 1
      var bReady = deviceStatus(b).ready ? 0 : 1
      if (aReady !== bReady) return aReady - bReady
      return String(a.name).localeCompare(String(b.name))
    })

    return { ok: true, devices: out }
  } catch (e) {
    return { ok: false, devices: [], error: "Failed to parse omdesky devices" }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    statusMeta: statusMeta,
    deviceStatus: deviceStatus,
    blockerLabel: blockerLabel,
    connectionLabel: connectionLabel,
    latencyLabel: latencyLabel,
    osIcon: osIcon,
    boundedString: boundedString,
    deviceFromJson: deviceFromJson,
    blockerHint: blockerHint,
    subtitle: subtitle,
    parseDevices: parseDevices
  }
}
