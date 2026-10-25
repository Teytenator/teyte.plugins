import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/teyte.todo/config.json"
  readonly property string toggleHelper: Quickshell.env("HOME") + "/.local/bin/teyte-todo-toggle"

  readonly property var defaults: ({
    path: "~/todo.md",
    maxItems: 12,
    showCompleted: true,
    fontFamily: "JetBrainsMono Nerd Font",
    fontSize: 14,
    color: "#ffffff",
    accentColor: "#66ccff",
    bgColor: "#000000",
    bgOpacity: 1.0,
    opacity: 1.0,
    padding: 16,
    width: 320,
    xRatio: 0.25,
    yRatio: 0.2,
    xOffset: 0,
    yOffset: 0,
    namespace: "teyte.todo"
  })

  property var settings: root.defaults
  property string _lastRaw: ""
  property var tasks: []
  property bool fileMissing: false

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
  readonly property real specFontSize: Math.max(8, root.num(root.settings.fontSize, 14))
  readonly property real specOpacity: Math.min(1, Math.max(0, root.num(root.settings.opacity, 1.0)))
  readonly property color specColor: Qt.color(root.settings.color || "#ffffff")
  readonly property color specAccent: Qt.color(root.settings.accentColor || "#66ccff")
  readonly property color specBgColor: Qt.color(root.settings.bgColor || "#000000")
  readonly property real specBgOpacity: Math.min(1, Math.max(0, root.num(root.settings.bgOpacity, 1.0)))
  readonly property real specPadding: Math.max(0, root.num(root.settings.padding, 16))
  readonly property real panelWidth: Math.max(160, root.num(root.settings.width, 320))
  readonly property int maxItems: Math.max(1, root.num(root.settings.maxItems, 12))
  readonly property bool showCompleted: root.settings.showCompleted !== false
  readonly property real xRatio: root.num(root.settings.xRatio, 0.25)
  readonly property real yRatio: root.num(root.settings.yRatio, 0.2)
  readonly property real xOffset: root.num(root.settings.xOffset, 0)
  readonly property real yOffset: root.num(root.settings.yOffset, 0)
  readonly property real rowHeight: Math.max(12, root.specFontSize * 1.55)
  readonly property real headerSize: Math.max(9, root.specFontSize * 0.74)
  readonly property color dimColor: Qt.rgba(root.specColor.r, root.specColor.g, root.specColor.b, 0.45)
  readonly property color faintColor: Qt.rgba(root.specColor.r, root.specColor.g, root.specColor.b, 0.3)

  readonly property string todoPath: {
    var p = String(root.settings.path || "~/todo.md")
    if (p === "~") return Quickshell.env("HOME")
    if (p.indexOf("~/") === 0) return Quickshell.env("HOME") + p.substring(1)
    return p
  }

  readonly property var visibleTasks: {
    var out = []
    for (var i = 0; i < root.tasks.length; i++) {
      if (!root.showCompleted && root.tasks[i].done) continue
      out.push(root.tasks[i])
      if (out.length >= root.maxItems) break
    }
    return out
  }

  readonly property int openCount: {
    var n = 0
    for (var i = 0; i < root.tasks.length; i++) if (!root.tasks[i].done) n++
    return n
  }

  function parseTasks(raw) {
    var out = []
    var lines = String(raw || "").split("\n")
    var re = /^\s*[-*]\s+\[([ xX])\]\s+(.*)$/
    for (var i = 0; i < lines.length; i++) {
      var m = re.exec(lines[i])
      if (!m) continue
      var text = String(m[2]).trim()
      if (text.length === 0) continue
      out.push({ text: text, done: String(m[1]).toLowerCase() === "x" })
    }
    return out
  }

  function loadTasks() {
    if (tasksProc.running) return
    tasksProc.running = true
  }

  function toggle(task) {
    if (toggleProc.running) return
    toggleProc.command = [root.toggleHelper, root.todoPath, task]
    toggleProc.running = true
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
    id: tasksProc
    command: ["cat", root.todoPath]
    stdout: StdioCollector { onStreamFinished: root.tasks = root.parseTasks(text) }
    onExited: function(exitCode) { root.fileMissing = exitCode !== 0 }
  }

  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: root.loadTasks()
    Component.onCompleted: root.loadTasks()
  }

  Timer {
    id: refreshSoon
    interval: 400
    repeat: false
    onTriggered: root.loadTasks()
  }

  Process {
    id: toggleProc
    command: ["true"]
    onExited: refreshSoon.restart()
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
      mask: Region { item: card }

      WlrLayershell.namespace: root.settings.namespace || "teyte.todo"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Item {
        id: surface
        anchors.fill: parent

        Rectangle {
          id: card
          width: root.panelWidth
          height: content.implicitHeight + root.specPadding * 2
          x: root.xRatio * surface.width - width / 2 + root.xOffset
          y: root.yRatio * surface.height - height / 2 + root.yOffset
          color: root.specBgColor
          opacity: root.specBgOpacity
          radius: 0

          Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.specPadding
            spacing: 6

            Item {
              width: parent.width
              height: root.headerSize * 1.6

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "TASKS"
                color: root.dimColor
                font.family: root.specFont
                font.pixelSize: root.headerSize
                font.letterSpacing: 1.5
                opacity: root.specOpacity
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.openCount + " open"
                color: root.faintColor
                font.family: root.specFont
                font.pixelSize: root.headerSize
                opacity: root.specOpacity
              }
            }

            Text {
              width: parent.width
              visible: root.tasks.length === 0
              text: root.fileMissing
                ? "no tasks — create " + root.todoPath
                : "no tasks"
              color: root.dimColor
              font.family: root.specFont
              font.pixelSize: Math.max(10, root.specFontSize * 0.86)
              elide: Text.ElideMiddle
              opacity: root.specOpacity
            }

            Repeater {
              model: root.visibleTasks

              Item {
                required property var modelData
                width: content.width
                height: root.rowHeight

                property bool rowHovered: rowMouse.containsMouse

                Text {
                  id: marker
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.done ? "[x]" : "[ ]"
                  color: modelData.done ? root.faintColor : root.specAccent
                  font.family: root.specFont
                  font.pixelSize: root.specFontSize
                  opacity: root.specOpacity
                }

                Text {
                  anchors.left: marker.right
                  anchors.leftMargin: 8
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.text
                  color: modelData.done
                    ? root.dimColor
                    : (rowMouse.containsMouse ? root.specAccent : root.specColor)
                  font.family: root.specFont
                  font.pixelSize: root.specFontSize
                  font.strikeout: modelData.done
                  elide: Text.ElideRight
                  opacity: root.specOpacity
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggle(modelData.text)
                }
              }
            }
          }
        }
      }
    }
  }
}
