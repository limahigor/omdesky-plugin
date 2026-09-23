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

assert.deepEqual(Model.statusMeta("ready", []), { label: "Ready", ready: true })
assert.deepEqual(Model.statusMeta("unavailable", []), { label: "Agent unavailable", ready: false })
assert.deepEqual(Model.statusMeta("blocked", [{ code: "denied" }]), { label: "Access denied", ready: false })
assert.deepEqual(Model.statusMeta("blocked", [{ code: "needs_access" }]), { label: "Allow it here", ready: false })
assert.deepEqual(Model.statusMeta("blocked", [{ code: "incompatible" }]), { label: "Incompatible", ready: false })
assert.deepEqual(Model.statusMeta("blocked", []), { label: "Blocked", ready: false })

const blocked = Model.deviceFromJson({
  name: "desk-b",
  status: "blocked",
  blockers: [
    { code: "needs_access", side: "local", fix: "omdesky access allow desk-b" },
    { code: "denied", side: "remote", fix: "omdesky access allow desk-a" },
    { code: "x" }, { code: "y" }, { code: "z" }
  ]
})
assert.equal(blocked.blockers.length, 4)
assert.equal(Model.deviceStatus(blocked).ready, false)
assert.equal(Model.subtitle(blocked), "Run omdesky access allow desk-b on this computer")

const outdated = Model.deviceFromJson({
  name: "desk-b",
  status: "blocked",
  blockers: [{ code: "incompatible", side: "remote", fix: "Install Omdesky 0.2.0" }]
})
assert.equal(Model.subtitle(outdated), "Install Omdesky 0.2.0 on desk-b")
