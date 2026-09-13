import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool installed: false
  property bool loading: false
  property var devices: []
  property string lastError: ""
  property string actionStatus: ""
  property string connectingName: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 5, 3600)
  readonly property int readyCount: countReady()
  readonly property bool busy: whichProcess.running || devicesProcess.running

  property string _devicesOutput: ""
  property string _devicesError: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var parsed = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(parsed)) parsed = fallback
    if (parsed < min) parsed = min
    if (parsed > max) parsed = max
    return parsed
  }

  function statusMeta(status) {
    return Model.statusMeta(status)
  }

  function osIcon(status) {
    return Model.osIcon(status)
  }

  function subtitle(device) {
    return Model.subtitle(device)
  }

  function countReady() {
    var total = 0
    for (var i = 0; i < devices.length; i++) {
      if (Model.statusMeta(devices[i].status).ready) total += 1
    }
    return total
  }

  function refresh() {
    if (installed) {
      refreshDevices()
      return
    }

    if (!whichProcess.running) {
      loading = true
      whichProcess.command = ["which", "omdesky"]
      whichProcess.running = true
    }
  }

  function refreshDevices() {
    if (!installed || devicesProcess.running) return

    _devicesOutput = ""
    _devicesError = ""
    loading = true
    devicesProcess.command = ["omdesky", "devices", "--json"]
    devicesProcess.running = true

    if (!pollWatchdog.running) pollWatchdog.start()
  }

  function parseDevices(raw) {
    var parsed = Model.parseDevices(raw)
    if (!parsed.ok) {
      lastError = parsed.error || "Failed to read devices"
      return
    }

    devices = parsed.devices
    lastError = ""
  }

  function isReady(device) {
    return device ? Model.statusMeta(device.status).ready : false
  }

  function connect(device) {
    if (!device || !isReady(device)) return

    var name = String(device.name || "")
    if (name === "") return

    connectingName = name
    actionStatus = "Connecting to " + name + "…"
    Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.omdesky", "omdesky", "connect", name, "--input", "remote"])
    actionStatusTimer.restart()
  }

  function openSettings() {
    Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.omdesky", "omdesky"])
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: pollWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (whichProcess.running) whichProcess.running = false
      if (devicesProcess.running) devicesProcess.running = false
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 3000
    repeat: false
    onTriggered: {
      root.actionStatus = ""
      root.connectingName = ""
    }
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      if (root.installed) {
        root.refreshDevices()
      } else {
        root.loading = false
        root.devices = []
        root.lastError = "omdesky is not installed"
      }
    }
  }

  Process {
    id: devicesProcess
    running: false
    command: []
    stdout: StdioCollector { id: devicesStdout; waitForEnd: true; onStreamFinished: root._devicesOutput = text }
    stderr: StdioCollector { id: devicesStderr; waitForEnd: true; onStreamFinished: root._devicesError = text }
    onExited: function(exitCode) {
      root.loading = false

      var stdout = String(devicesStdout.text || root._devicesOutput || "")
      var stderr = String(devicesStderr.text || root._devicesError || "")

      if (exitCode === 0) {
        root.parseDevices(stdout)
      } else {
        root.devices = []
        root.lastError = stderr.trim() || "Could not list devices"
      }
    }
  }
}
