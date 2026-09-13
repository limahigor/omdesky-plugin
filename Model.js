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

function deviceFromJson(entry) {
  var source = entry || {}
  return {
    name: String(source.name || ""),
    address: String(source.address || ""),
    status: String(source.status || ""),
    connection: String(source.connection || ""),
    latencyMs: typeof source.latency_ms === "number" ? source.latency_ms : null,
    isLocal: source.is_local === true,
    agentVersion: String(source.agent_version || ""),
    omarchyVersion: String(source.omarchy_version || "")
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
    if (!(data && typeof data.length === "number")) {
      return { ok: false, devices: [], error: "Unexpected devices output" }
    }

    var out = []
    for (var i = 0; i < data.length; i++) {
      var device = deviceFromJson(data[i])
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
    deviceFromJson: deviceFromJson,
    subtitle: subtitle,
    parseDevices: parseDevices
  }
}
