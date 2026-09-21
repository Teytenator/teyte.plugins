import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Fastfetch-style system specs rendered on the bottom layer, behind every
// app window but above the wallpaper. Terminal-styled monospace text.
Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/teyte.specs/config.json"

  readonly property var defaults: ({
    fontScale: 0.03,
    fontFamily: "JetBrainsMono Nerd Font",
    fontWeight: 400,
    color: "#ffffff",
    bgColor: "#05182e",
    bgOpacity: 0.85,
    padding: 18,
    opacity: 1.0,
    position: "center",
    xRatio: null,
    yRatio: null,
    namespace: "teyte.specs"
  })

  property var settings: root.defaults
  property string _lastRaw: ""
  property string _lastWritten: ""
  property bool _configApplied: true

  property string specsText: ""

  function num(v, fallback) {
    if (v === null || v === undefined || v === "") return fallback
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  readonly property real xRatio: root.num(root.settings.xRatio, 0.5)
  readonly property real yRatio: !isNaN(Number(root.settings.yRatio)) && root.settings.yRatio !== null && root.settings.yRatio !== ""
    ? Number(root.settings.yRatio)
    : (root.settings.position === "top" ? 0.25
      : root.settings.position === "bottom" ? 0.75 : 0.5)
  readonly property real specFontScale: root.num(root.settings.fontScale, 0.03)
  readonly property real specFontSize: root.num(root.settings.fontSize, 14)
  readonly property real specOpacity: root.num(root.settings.opacity, 1.0)
  readonly property color specColor: Qt.color(root.settings.color || "#ffffff")
  readonly property color specBgColor: Qt.color(root.settings.bgColor || "#05182e")
  readonly property real specBgOpacity: root.num(root.settings.bgOpacity, 0.85)
  readonly property real specPadding: root.num(root.settings.padding, 18)
  readonly property real panelWidth: root.num(root.settings.width, 340)
  readonly property real xMargin: root.num(root.settings.xMargin, 30)
  readonly property string specFont: root.settings.fontFamily === "system"
    ? "" : (root.settings.fontFamily ? root.settings.fontFamily : "JetBrainsMono Nerd Font")

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
    root._configApplied = true
  }

  function gatherSpecs() {
    if (!gatherProc.running) {
      gatherProc.running = true
    }
  }

  Component.onCompleted: root.gatherSpecs()
  property string _lastGathered: ""
  function applyGathered(out) {
    if (out !== root._lastGathered) {
      root._lastGathered = out
      root.specsText = out
    }
  }

  Process {
    id: configProc
    command: ["cat", root.configPath]
    stdout: StdioCollector { onStreamFinished: root.applyRaw(text) }
    Component.onCompleted: running = true
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: {
      if (!configProc.running) configProc.running = true
      root.gatherSpecs()
    }
  }

  Process {
    id: gatherProc
    command: [Quickshell.env("HOME") + "/.local/bin/omarchy-specs-gather"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(text || "")
        if (out.length > 0) root.applyGathered(out)
      }
    }
    Component.onCompleted: running = true
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
      updatesEnabled: true
      mask: Region {}

      WlrLayershell.namespace: root.settings.namespace
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Item {
        id: surface
        anchors.fill: parent

        Rectangle {
          id: specsPanel
          visible: root._configApplied
          color: root.specBgColor
          opacity: Math.min(1, Math.max(0, root.specBgOpacity))
          radius: 12
          border { color: "#ffffff" ; width: 0 }
          x: specsTextDisplay.x - root.specPadding + 8
          y: specsTextDisplay.y - root.specPadding
          width: specsTextDisplay.width + root.specPadding * 2
          height: specsTextDisplay.height + root.specPadding * 2
        }

        Text {
          id: specsTextDisplay
          visible: root._configApplied
          color: root.specColor
          opacity: Math.min(1, Math.max(0, root.specOpacity))
          font.family: root.specFont
          font.weight: root.settings.fontWeight
          font.pixelSize: Math.max(8, root.specFontSize)
          font.hintingPreference: Font.PreferFullHinting
          lineHeight: 1.2
          lineHeightMode: Text.ProportionalHeight
          renderType: Text.QtRendering
          wrapMode: Text.NoWrap
          text: root.specsText
          width: root.panelWidth

          x: root.xMargin
          y: surface.height * root.yRatio - height / 2
        }
      }
    }
  }
}
