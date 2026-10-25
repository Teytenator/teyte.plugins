import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/teyte.calendar/config.json"

  readonly property var defaults: ({
    fontScale: 0.015,
    fontFamily: "JetBrainsMono Nerd Font",
    fontWeight: 400,
    color: "#ffffff",
    bgColor: "#000000",
    bgOpacity: 1.0,
    padding: 18,
    opacity: 1.0,
    xRatio: 0.25,
    yRatio: 0.75,
    yOffset: 0,
    namespace: "teyte.calendar"
  })

  property var settings: root.defaults
  property string _lastRaw: ""

  function num(v, fallback) {
    if (v === null || v === undefined || v === "") return fallback
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  readonly property real specFontScale: root.num(root.settings.fontScale, 0.015)
  readonly property real specFontSize: root.num(root.settings.fontSize, 14)
  readonly property real specOpacity: root.num(root.settings.opacity, 1.0)
  readonly property color specColor: Qt.color(root.settings.color || "#ffffff")
  readonly property color specBgColor: Qt.color(root.settings.bgColor || "#000000")
  readonly property real specBgOpacity: root.num(root.settings.bgOpacity, 1.0)
  readonly property real specPadding: root.num(root.settings.padding, 18)
  readonly property real panelWidth: root.num(root.settings.width, 340)
  readonly property real xMargin: root.num(root.settings.xMargin, 30)
  readonly property real calCellSize: root.num(root.settings.cellSize, 24)
  readonly property string specFont: root.settings.fontFamily === "system"
    ? "" : (root.settings.fontFamily ? root.settings.fontFamily : "JetBrainsMono Nerd Font")
  readonly property real xRatio: root.num(root.settings.xRatio, 0.25)
  readonly property real yRatio: root.num(root.settings.yRatio, 0.75)
  readonly property real xOffset: root.num(root.settings.xOffset, 0)
  readonly property real yOffset: root.num(root.settings.yOffset, 0)

  readonly property date today: new Date()
  readonly property int todayDay: root.today.getDate()
  readonly property string monthName: root.today.toLocaleString(Qt.locale(), "MMMM yyyy")
  readonly property int firstWeekday: new Date(root.today.getFullYear(), root.today.getMonth(), 1).getDay()
  readonly property int daysInMonth: new Date(root.today.getFullYear(), root.today.getMonth() + 1, 0).getDate()
  readonly property var dayLabels: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

  function pad(n) {
    return n < 10 ? "0" + n : String(n)
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

        property real cellSpacing: 2
        property real cellSize: Math.max(6, root.calCellSize)

        Grid {
          id: calendarGrid
          x: root.xMargin + (root.panelWidth - width) / 2 + root.xOffset
          y: root.yRatio * surface.height - height / 2 + root.yOffset
          columns: 7
          spacing: surface.cellSpacing

          Repeater {
            model: 42

            Item {
              required property int index
              width: surface.cellSize
              height: surface.cellSize

              property int labelIdx: index
              property int dayOffset: index - 7
              property bool isHeader: index < 7
              property int dayNumber: root.dayLabels.length > 0 && isHeader ? 0 : (index - 7 - root.firstWeekday + 1)
              property bool isBlank: !isHeader && (index < 7 || dayNumber < 1 || dayNumber > root.daysInMonth)
              property bool isToday: !isBlank && dayNumber === root.todayDay

              Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.dayLabels.length > 0 && isHeader ? root.dayLabels[labelIdx] : (isBlank ? "" : pad(dayNumber))
                color: {
                  if (isHeader) return Qt.rgba(0.4, 0.8, 1.0, 1.0)
                  if (isToday) return "#05182e"
                  return root.specColor
                }
                font.family: root.specFont
                font.weight: isHeader ? Font.Bold : (isToday ? Font.Bold : root.settings.fontWeight)
                font.pixelSize: Math.max(6, root.specFontSize)
                font.hintingPreference: Font.PreferFullHinting
                opacity: isToday ? 1.0 : (root.specOpacity * (isBlank ? 0.0 : 0.9))
                style: isToday ? Text.Sunken : Text.Normal
                styleColor: isToday ? Qt.rgba(0.4, 0.8, 1.0, 1.0) : "transparent"

                Rectangle {
                  visible: isToday
                  anchors.fill: parent
                  color: root.specColor
                  z: -1
                }
              }
            }
          }
        }

        Rectangle {
          color: root.specBgColor
          opacity: Math.min(1, Math.max(0, root.specBgOpacity))
          radius: 0
          x: root.xMargin - root.specPadding + 8 + root.xOffset
          y: calendarGrid.y - root.specPadding
          width: root.panelWidth + root.specPadding * 2
          height: calendarGrid.height + root.specPadding * 2
          z: -1
        }
      }
    }
  }
}
