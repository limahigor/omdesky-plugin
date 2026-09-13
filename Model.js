function statusMeta(status) {
  var value = String(status || "").toLowerCase()
  if (value === "ready") return { label: "Ready", ready: true }
  if (value === "offline") return { label: "Offline", ready: false }
  if (value === "agent_unknown") return { label: "Agent unavailable", ready: false }
  if (value === "incompatible") return { label: "Incompatible", ready: false }
  return { label: value === "" ? "Unknown" : value, ready: false }
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

function osIcon(status) {
  return statusMeta(status).ready ? "󰇄" : "󰢹"
}

function boundedString(value, limit) {
  return Array.from(String(value || "")).slice(0, limit).join("")
}

function deviceFromJson(entry) {
  var source = entry || {}
  var latency = source.latencyMs
  if (typeof latency !== "number" || !isFinite(latency) || latency < 0 || latency > 600000) latency = null
  return {
    name: boundedString(source.name, 256),
    address: boundedString(source.address, 64),
    status: boundedString(source.status, 32),
    connection: boundedString(source.connection, 32),
    latencyMs: latency === null ? null : Math.floor(latency),
    isLocal: source.isLocal === true,
    agentVersion: boundedString(source.agentVersion, 128),
    omarchyVersion: boundedString(source.omarchyVersion, 128)
  }
}

function subtitle(device) {
  if (!device) return ""
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
      var aReady = statusMeta(a.status).ready ? 0 : 1
      var bReady = statusMeta(b.status).ready ? 0 : 1
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
    connectionLabel: connectionLabel,
    latencyLabel: latencyLabel,
    osIcon: osIcon,
    boundedString: boundedString,
    deviceFromJson: deviceFromJson,
    subtitle: subtitle,
    parseDevices: parseDevices
  }
}
