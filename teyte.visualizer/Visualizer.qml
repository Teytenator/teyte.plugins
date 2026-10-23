import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/teyte.visualizer/config.json"

  readonly property var defaults: ({
    fontScale: 0.018,
    fontFamily: "JetBrainsMono Nerd Font",
    fontWeight: 400,
    color: "#ffffff",
    bgColor: "#05182e",
    bgOpacity: 0.85,
    padding: 18,
    opacity: 1.0,
    bars: 24,
    barWidth: 6,
    barGap: 4,
    maxBarHeight: 120,
    maxValue: 8000,
    xRatio: 0.25,
    yRatio: 0.5,
    namespace: "teyte.visualizer"
  })

  property var settings: root.defaults
  property string _lastRaw: ""

  function num(v, fallback) {
    if (v === null || v === undefined || v === "") return fallback
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  readonly property real specFontScale: root.num(root.settings.fontScale, 0.018)
  readonly property real specOpacity: root.num(root.settings.opacity, 1.0)
  readonly property color specColor: Qt.color(root.settings.color || "#ffffff")
  readonly property color specBgColor: Qt.color(root.settings.bgColor || "#05182e")
  readonly property real specBgOpacity: root.num(root.settings.bgOpacity, 0.85)
  readonly property real specPadding: root.num(root.settings.padding, 18)
  readonly property real panelWidth: root.num(root.settings.width, 340)
  readonly property real xMargin: root.num(root.settings.xMargin, 30)
  readonly property string specFont: root.settings.fontFamily === "system"
    ? "" : (root.settings.fontFamily ? root.settings.fontFamily : "JetBrainsMono Nerd Font")
  readonly property real xRatio: root.num(root.settings.xRatio, 0.25)
  readonly property real yRatio: root.num(root.settings.yRatio, 0.5)
  readonly property real xOffset: root.num(root.settings.xOffset, 0)
  readonly property real yOffset: root.num(root.settings.yOffset, 0)

  readonly property int barCount: Math.max(4, Math.round(root.num(root.settings.bars, 24)))
  readonly property real barWidth: root.num(root.settings.barWidth, 6)
  readonly property real barGap: root.num(root.settings.barGap, 4)
  readonly property real maxBarHeight: root.num(root.settings.maxBarHeight, 120)
  readonly property real barMaxValue: Math.max(100, root.num(root.settings.maxValue, 8000))
  property var barValues: []
  property var barHeights: []
  property real agcMax: 100

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
    }
  }

  Process {
    id: cavaProc
    command: [Quickshell.env("HOME") + "/.local/bin/omarchy-visualizer-helper",
               Quickshell.env("HOME") + "/.config/cava/config",
               String(root.barCount)]
    running: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        if (!data) return
        var parts = data.trim().split(/\s+/)
        var vals = []
        for (var i = 0; i < parts.length && i < root.barCount; i++) {
          var v = Number(parts[i])
          vals.push(isNaN(v) ? 0 : v)
        }
        root.barValues = vals

        var heights = []
        var target
        var frameMax = 1
        for (var h = 0; h < root.barCount; h++) {
          var raw = h < root.barValues.length ? root.barValues[h] : 0
          if (raw > frameMax) frameMax = raw
        }
        if (frameMax > root.agcMax) {
          root.agcMax = frameMax
        } else {
          root.agcMax = Math.max(100, root.agcMax * 0.98)
        }
        for (var h2 = 0; h2 < root.barCount; h2++) {
          var r = h2 < root.barValues.length ? root.barValues[h2] : 0
          target = Math.min(100, r / root.agcMax * 100)
          target = Math.max(0, target)
          var prev = h2 < root.barHeights.length ? root.barHeights[h2] : 0
          if (target > prev) {
            target = prev + (target - prev) * 0.6
          } else {
            target = prev + (target - prev) * 0.2
          }
          heights.push(target)
        }
        root.barHeights = heights
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.barValues.length > 0
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

        property real totalWidth: root.barCount * root.barWidth + (root.barCount - 1) * root.barGap

        Rectangle {
          id: bgPanel
          color: root.specBgColor
          opacity: Math.min(1, Math.max(0, root.specBgOpacity))
          radius: 12
          x: root.xMargin - root.specPadding + 8 + root.xOffset
          y: root.yRatio * surface.height - height / 2 + root.yOffset
          width: root.panelWidth + root.specPadding * 2
          height: root.maxBarHeight + root.specPadding * 2

          Repeater {
            model: root.barCount

            Rectangle {
              required property int index
              property real pct: index < root.barHeights.length ? root.barHeights[index] : 0
              property real targetHeight: root.maxBarHeight
              width: root.barWidth
              anchors.bottom: parent.bottom
              anchors.bottomMargin: root.specPadding
              color: root.specColor
              opacity: root.specOpacity
              radius: root.barWidth / 2

              x: root.specPadding + (parent.width - root.specPadding * 2 - surface.totalWidth) / 2
                 + index * (root.barWidth + root.barGap)
              height: Math.max(2, Math.min(root.maxBarHeight, pct / 100 * root.maxBarHeight))
            }
          }
        }
      }
    }
  }
}
