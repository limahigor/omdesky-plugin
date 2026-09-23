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
  property bool refreshPending: false
  property var devices: []
  property string lastError: ""
  property string actionStatus: ""
  property string connectingName: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 5, 3600)
  readonly property int readyCount: countReady()
  readonly property bool busy: helperProcess.running
  readonly property string helperPath: Qt.resolvedUrl("omdesky_runner.py").toString().replace("file://", "")
  readonly property var helperEnvironment: ({
    "PATH": "/usr/local/bin:/usr/bin",
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "HOME": Quickshell.env("HOME"),
    "USER": Quickshell.env("USER"),
    "LOGNAME": Quickshell.env("LOGNAME"),
    "XDG_CONFIG_HOME": Quickshell.env("XDG_CONFIG_HOME"),
    "XDG_DATA_HOME": Quickshell.env("XDG_DATA_HOME"),
    "XDG_CACHE_HOME": Quickshell.env("XDG_CACHE_HOME"),
    "XDG_STATE_HOME": Quickshell.env("XDG_STATE_HOME"),
    "XDG_RUNTIME_DIR": Quickshell.env("XDG_RUNTIME_DIR"),
    "DBUS_SESSION_BUS_ADDRESS": Quickshell.env("DBUS_SESSION_BUS_ADDRESS"),
    "WAYLAND_DISPLAY": Quickshell.env("WAYLAND_DISPLAY"),
    "DISPLAY": Quickshell.env("DISPLAY"),
    "HYPRLAND_INSTANCE_SIGNATURE": Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"),
    "XDG_CURRENT_DESKTOP": Quickshell.env("XDG_CURRENT_DESKTOP"),
    "XDG_SESSION_TYPE": Quickshell.env("XDG_SESSION_TYPE")
  })

  property string _operation: ""
  property string _helperOutput: ""
  property bool _timedOut: false

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

  function deviceStatus(device) {
    return Model.deviceStatus(device)
  }

  function osIcon(device) {
    return Model.osIcon(device)
  }

  function subtitle(device) {
    return Model.subtitle(device)
  }

  function countReady() {
    var total = 0
    for (var i = 0; i < devices.length; i++) {
      if (Model.deviceStatus(devices[i]).ready) total += 1
    }
    return total
  }

  function runHelper(operation, arguments) {
    if (helperProcess.running) {
      if (operation === "devices") refreshPending = true
      return
    }

    _operation = operation
    _helperOutput = ""
    _timedOut = false
    loading = operation === "probe" || operation === "devices"
    helperProcess.command = [helperPath, operation].concat(arguments || [])
    helperProcess.running = true
  }

  function refresh() {
    runHelper(installed ? "devices" : "probe", [])
  }

  function refreshDevices() {
    if (!installed) return
    runHelper("devices", [])
  }

  function finishHelper(exitCode) {
    loading = false

    if (_timedOut) {
      devices = []
      lastError = "Omdesky did not respond in time"
    } else {
      var response = null

      try {
        response = JSON.parse(String(helperStdout.text || _helperOutput || ""))
      } catch (error) {
        response = null
      }

      if (!response || response.ok !== true) {
        if (_operation === "probe") installed = false
        if (_operation === "devices") devices = []
        lastError = response && response.message ? String(response.message).slice(0, 256) : "Omdesky helper failed"
      } else if (_operation === "probe") {
        installed = response.installed === true
        lastError = installed ? "" : "Omdesky is not installed in a trusted location"
        if (installed) refreshDevices()
      } else if (_operation === "devices") {
        var parsed = Model.parseDevices(_helperOutput || helperStdout.text)
        if (parsed.ok) {
          devices = parsed.devices
          lastError = ""
        } else {
          devices = []
          lastError = parsed.error || "Failed to read devices"
        }
      }
    }

    if (refreshPending) {
      refreshPending = false
      refresh()
    }
  }

  function isReady(device) {
    return Model.deviceStatus(device).ready
  }

  function connect(device) {
    if (!device || !isReady(device)) return

    var name = String(device.name || "")
    if (name === "") return

    connectingName = name
    actionStatus = "Connecting to " + name + "…"
    launchProcess.command = [helperPath, "connect", name]
    launchProcess.startDetached()
    actionStatusTimer.restart()
  }

  function openSettings() {
    launchProcess.command = [helperPath, "open"]
    launchProcess.startDetached()
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
    id: helperWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (!helperProcess.running) return
      root._timedOut = true
      helperProcess.running = false
      killWatchdog.restart()
    }
  }

  Timer {
    id: killWatchdog
    interval: 1000
    repeat: false
    onTriggered: {
      if (helperProcess.running) helperProcess.signal(9)
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
    id: helperProcess
    running: false
    command: []
    clearEnvironment: true
    environment: root.helperEnvironment
    stdout: StdioCollector {
      id: helperStdout
      waitForEnd: true
      onStreamFinished: root._helperOutput = text
    }
    onStarted: helperWatchdog.restart()
    onExited: function(exitCode) {
      helperWatchdog.stop()
      killWatchdog.stop()
      root.finishHelper(exitCode)
    }
  }

  Process {
    id: launchProcess
    running: false
    command: []
    clearEnvironment: true
    environment: root.helperEnvironment
  }
}
