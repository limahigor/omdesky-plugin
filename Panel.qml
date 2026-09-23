import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omdesky.remote"
  ipcTarget: "omdesky.remote"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: barForeground

  readonly property string heroMeta: {
    if (!omdesky.installed) return "omdesky not found"
    if (omdesky.devices.length === 0) return omdesky.loading ? "Scanning…" : "No devices found"
    return omdesky.readyCount + " ready · " + omdesky.devices.length + " total"
  }

  function selectedDevice() {
    if (omdesky.devices.length === 0) return null
    return omdesky.devices[Math.max(0, Math.min(cursorIndex, omdesky.devices.length - 1))]
  }

  function ensureCursor() {
    if (cursorIndex < 0) cursorIndex = 0
    if (cursorIndex >= omdesky.devices.length) cursorIndex = Math.max(0, omdesky.devices.length - 1)
  }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = index
    ensureCursor()
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()

    if (dy !== 0 && omdesky.devices.length > 0) {
      cursorIndex = Math.max(0, Math.min(omdesky.devices.length - 1, cursorIndex + dy))
    }
  }

  function activateCursor() {
    if (!cursorActive) {
      cursorActive = true
      return
    }
    connectDevice(selectedDevice())
  }

  function connectDevice(device) {
    if (!device || !omdesky.isReady(device)) return

    omdesky.connect(device)
    root.close()
  }

  function openSettings() {
    omdesky.openSettings()
    root.close()
  }

  Service {
    id: omdesky
    settings: root.settings
  }

  Connections {
    target: omdesky
    function onDevicesChanged() { root.ensureCursor() }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { omdesky.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        OmdeskyIcon {
          anchors.centerIn: parent
          iconSize: Math.min(parent.width, parent.height) * 0.82
          color: root.barIconColor
          crossed: !omdesky.installed
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) omdesky.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text === "r" || text === "R") omdesky.refresh()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Omdesky"
            meta: root.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: omdesky.readyCount > 0 ? 1.0 : 0.6
            iconComponent: Component {
              OmdeskyIcon {
                iconSize: Style.font.display
                color: Color.accent
                crossed: !omdesky.installed
              }
            }

            trailingControl: Component {
              PanelActionButton {
                iconText: "󰒓"
                tooltipText: "Open settings"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.openSettings()
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: omdesky.actionStatus !== "" || omdesky.lastError !== ""
            width: parent.width
            text: omdesky.actionStatus !== "" ? omdesky.actionStatus : omdesky.lastError
            color: omdesky.lastError !== "" && omdesky.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
            visible: omdesky.devices.length > 0
          }

          PanelSectionHeader {
            width: parent.width
            text: "DEVICES"
            foreground: root.foreground
            fontFamily: root.fontFamily
            visible: omdesky.devices.length > 0
          }

          Text {
            textFormat: Text.PlainText
            visible: omdesky.devices.length === 0
            width: parent.width
            text: !omdesky.installed
              ? "Install omdesky to see your devices."
              : (omdesky.loading ? "Scanning your tailnet…" : "No Omdesky devices found. Press r to scan again.")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: omdesky.devices

              DeviceRow {
                width: parent.width
                device: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component DeviceRow: CursorSurface {
    id: deviceRow
    property var device: null
    property int rowIndex: 0

    readonly property string deviceName: device ? String(device.name || "Unknown") : "Unknown"
    readonly property var statusMeta: omdesky.statusMeta(device ? device.status : "")
    readonly property bool ready: statusMeta.ready

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground

    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: deviceRow.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) root.setCursor(deviceRow.rowIndex)
      onClicked: root.connectDevice(deviceRow.device)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: omdesky.osIcon(device ? device.status : "")
        color: deviceRow.ready ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: rowContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: deviceRow.deviceName
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: text !== ""
          text: omdesky.subtitle(deviceRow.device)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: !deviceRow.ready
        text: deviceRow.statusMeta.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      PanelActionButton {
        visible: deviceRow.ready
        iconText: "󰅂"
        tooltipText: "Connect"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.connectDevice(deviceRow.device)
      }
    }
  }
}
