const assert = require("node:assert/strict")
const Model = require("../Model.js")

const devices = Array.from({ length: 200 }, (_, index) => ({
  name: "x".repeat(400) + index,
  address: "100.64.0.1",
  status: "ready",
  connection: "direct",
  latencyMs: 12,
  isLocal: false,
  agentVersion: "1.0.0",
  omarchyVersion: "4.0.0"
}))

const parsed = Model.parseDevices(JSON.stringify({ ok: true, devices }))
assert.equal(parsed.ok, true)
assert.equal(parsed.devices.length, 128)
assert.ok(parsed.devices[0].name.length <= 256)

const arrayLike = Model.parseDevices(JSON.stringify({ ok: true, devices: { 0: {}, length: 1 } }))
assert.equal(arrayLike.ok, false)

const failed = Model.parseDevices(JSON.stringify({ ok: false, message: "safe failure" }))
assert.equal(failed.ok, false)
assert.equal(failed.error, "safe failure")
