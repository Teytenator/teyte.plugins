import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/teyte.prompt/config.json"

  readonly property var defaults: ({
    fontFamily: "JetBrainsMono Nerd Font",
    fontSize: 15,
    color: "#ffffff",
    bgColor: "#000000",
    bgOpacity: 1.0,
    accentColor: "#66ccff",
    radius: 0,
    padding: 14,
    opacity: 1.0,
    xRatio: 0.5,
    yRatio: 0.93,
    xOffset: 0,
    yOffset: 0,
    barLabel: "⌕ search web…",
    barNamespace: "teyte.prompt-bar"
  })

  property var settings: root.defaults
  property string _lastRaw: ""
  property bool hovered: false

  function num(v, fallback) {
    if (v === null || v === undefined || v === "") return fallback
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  function applyRaw(raw) {
    if (raw && String(raw).trim().length > 0 && raw !== root._lastRaw) {
      root._lastRaw = raw
      try {
        var parsed = JSON.parse(raw)
        var merged = {}
        for (var k in root.defaults) merged[k] = root.defaults[k]
        for (var p in parsed) if (parsed.hasOwnProperty(p)) merged[p] = parsed[p]
        root.settings = merged
      } catch (e) {}
    }
  }

  readonly property string specFont: root.settings.fontFamily === "system"
    ? "" : (root.settings.fontFamily ? root.settings.fontFamily : "JetBrainsMono Nerd Font")
  readonly property real specFontSize: Math.max(8, root.num(root.settings.fontSize, 15))
  readonly property real specOpacity: Math.min(1, Math.max(0, root.num(root.settings.opacity, 1.0)))
  readonly property color specColor: Qt.color(root.settings.color || "#ffffff")
  readonly property color specBgColor: Qt.color(root.settings.bgColor || "#000000")
  readonly property color specAccent: Qt.color(root.settings.accentColor || "#66ccff")
  readonly property real specBgOpacity: Math.min(1, Math.max(0, root.num(root.settings.bgOpacity, 1.0)))
  readonly property real specRadius: Math.max(0, root.num(root.settings.radius, 0))
  readonly property real specPadding: Math.max(0, root.num(root.settings.padding, 14))
  readonly property real xRatio: root.num(root.settings.xRatio, 0.5)
  readonly property real yRatio: root.num(root.settings.yRatio, 0.93)
  readonly property real xOffset: root.num(root.settings.xOffset, 0)
  readonly property real yOffset: root.num(root.settings.yOffset, 0)

  function openPalette() {
    if (root.shell && typeof root.shell.summon === "function") {
      if (root.shell.summon((root.manifest && root.manifest.id) || "teyte.prompt", "")) return
    }
    if (!fallback.running) fallback.running = true
  }

  Process {
    id: configProc
    command: ["cat", root.configPath]
    stdout: StdioCollector { onStreamFinished: root.applyRaw(text) }
    Component.onCompleted: running = true
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: {
      if (!configProc.running) configProc.running = true
    }
  }

  Process {
    id: fallback
    command: ["omarchy-shell", "shell", "summon", "teyte.prompt"]
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: true
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      mask: Region { item: bar }

      WlrLayershell.namespace: root.settings.barNamespace || "teyte.prompt-bar"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Item {
        id: surface
        anchors.fill: parent

        Rectangle {
          id: bar
          width: label.implicitWidth + root.specPadding * 2
          height: label.implicitHeight + root.specPadding * 2
          x: root.xRatio * surface.width - width / 2 + root.xOffset
          y: root.yRatio * surface.height - height / 2 + root.yOffset
          radius: root.specRadius
          color: root.specBgColor
          opacity: root.specOpacity * (root.hovered ? Math.max(0.85, root.specBgOpacity) : root.specBgOpacity)

          Text {
            id: label
            anchors.centerIn: parent
            text: root.settings.barLabel || "⌕ search web…"
            color: root.specColor
            font.family: root.specFont
            font.pixelSize: root.specFontSize
            font.bold: root.hovered
            opacity: root.specOpacity
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = true
            onExited: root.hovered = false
            onClicked: root.openPalette()
          }
        }
      }
    }
  }
}
