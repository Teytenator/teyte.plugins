import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/teyte.weather/config.json"

  readonly property var defaults: ({
    fontScale: 0.016,
    fontFamily: "JetBrainsMono Nerd Font",
    fontWeight: 400,
    color: "#ffffff",
    bgColor: "#05182e",
    bgOpacity: 0.85,
    padding: 18,
    opacity: 1.0,
    city: "auto",
    units: "metric",
    refreshMinutes: 15,
    xRatio: 0.75,
    yRatio: 0.75,
    namespace: "teyte.weather"
  })

  property var settings: root.defaults
  property string _lastRaw: ""

  function num(v, fallback) {
    if (v === null || v === undefined || v === "") return fallback
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  readonly property real specFontScale: root.num(root.settings.fontScale, 0.016)
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
  readonly property real xRatio: root.num(root.settings.xRatio, 0.75)
  readonly property real yRatio: root.num(root.settings.yRatio, 0.75)
  readonly property real xOffset: root.num(root.settings.xOffset, 0)
  readonly property real yOffset: root.num(root.settings.yOffset, 0)

  readonly property string weatherCity: root.settings.city && root.settings.city.trim().length > 0 ? root.settings.city.trim() : "auto"
  readonly property string weatherUnits: root.settings.units === "imperial" ? "imperial" : "metric"

  property string weatherText: ""

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

  function gatherWeather() {
    if (!weatherProc.running) weatherProc.running = true
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

  Timer {
    interval: Math.max(60000, root.num(root.settings.refreshMinutes, 15) * 60000)
    repeat: true
    running: true
    onTriggered: {
      root.gatherWeather()
    }
  }

  Process {
    id: weatherProc
    command: [Quickshell.env("HOME") + "/.local/bin/omarchy-weather-gather",
               root.weatherCity, root.weatherUnits]
    stdout: StdioCollector {
      onStreamFinished: root.weatherText = String(text || "").trim()
    }
    Component.onCompleted: running = true
  }

  // Retry until we get data (e.g. network not up yet right after boot)
  Timer {
    interval: 30000
    repeat: true
    running: root.weatherText.length === 0
    onTriggered: root.gatherWeather()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.weatherText.length > 0
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

        Text {
          id: weatherTextDisplay
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
          text: root.weatherText
          width: root.panelWidth

          x: root.xMargin + root.xOffset
          y: root.yRatio * surface.height - height / 2 + root.yOffset
        }

        Rectangle {
          id: weatherPanel
          color: root.specBgColor
          opacity: Math.min(1, Math.max(0, root.specBgOpacity))
          radius: 12
          x: weatherTextDisplay.x - root.specPadding + 8
          y: weatherTextDisplay.y - root.specPadding
          width: weatherTextDisplay.width + root.specPadding * 2
          height: weatherTextDisplay.height + root.specPadding * 2
          z: -1
        }
      }
    }
  }
}