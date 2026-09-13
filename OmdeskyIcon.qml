import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool crossed: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real squareSize: root.iconSize * 0.70
  readonly property real stroke: Math.max(1.5, root.iconSize * 0.10)
  readonly property real cornerRadius: root.squareSize * 0.30
  readonly property real offset: root.squareSize * 0.34
  readonly property real margin: (root.iconSize - (root.squareSize + root.offset)) / 2

  Rectangle {
    id: backSquare
    x: root.margin
    y: root.margin
    width: root.squareSize
    height: root.squareSize
    radius: root.cornerRadius
    color: "transparent"
    border.width: root.stroke
    border.color: root.color
  }

  Rectangle {
    id: frontSquare
    x: root.margin + root.offset
    y: root.margin + root.offset
    width: root.squareSize
    height: root.squareSize
    radius: root.cornerRadius
    color: Color.background
    border.width: root.stroke
    border.color: root.color
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: root.iconSize * 1.24
    height: Math.max(2, root.stroke)
    radius: height / 2
    color: root.color
    rotation: -45
  }
}
