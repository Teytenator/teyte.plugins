import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/teyte.prompt/config.json"
  readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/teyte.prompt/history.txt"
  readonly property string cwdHelper: Quickshell.env("HOME") + "/.local/bin/teyte-prompt-cwd"

  readonly property var defaults: ({
    fontFamily: "JetBrainsMono Nerd Font",
    fontSize: 15,
    color: "#ffffff",
    bgColor: "#000000",
    bgOpacity: 1.0,
    accentColor: "#66ccff",
    radius: 0,
    padding: 16,
    width: 720,
    paletteYRatio: 0.28,
    opacity: 1.0,
    agent: "opencode",
    agentArgs: [],
    terminal: "foot",
    cwd: "auto",
    placeholder: "Ask the agent what to do or build…",
    historyLimit: 50,
    namespace: "teyte.prompt"
  })

  property var settings: root.defaults
  property string _lastRaw: ""

  property bool opened: false
  property string statusText: ""
  property var history: []
  property int historyIndex: -1
  property string pendingPrompt: ""
  property string resolvedCwd: ""
  property bool _historyLoaded: false

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
  readonly property real specPadding: Math.max(0, root.num(root.settings.padding, 16))
  readonly property real panelWidth: Math.max(240, root.num(root.settings.width, 720))
  readonly property real paletteYRatio: root.num(root.settings.paletteYRatio, 0.28)
  readonly property real hintHeight: Math.max(12, root.specFontSize * 1.4)
  readonly property color hintColor: Qt.rgba(root.specColor.r, root.specColor.g, root.specColor.b, 0.42)
  readonly property color accentSoft: Qt.rgba(root.specAccent.r, root.specAccent.g, root.specAccent.b, 0.42)

  function open(payloadJson) {
    root.opened = true
    root.statusText = ""
    root.historyIndex = -1
    root.loadHistory()
    input.text = ""
    Qt.callLater(function() { input.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "teyte.prompt")
  }

  function submit() {
    var text = String(input.text || "").trim()
    if (text.length === 0) {
      root.dismiss()
      return
    }
    root.pushHistory(text)
    root.launch(text)
    root.dismiss()
  }

  function cycleHistory(delta) {
    if (root.history.length === 0) return
    root.historyIndex = Math.max(-1, Math.min(root.history.length - 1, root.historyIndex + delta))
    input.text = root.historyIndex >= 0 ? String(root.history[root.historyIndex]) : ""
    input.cursorPosition = input.text.length
  }

  function applyHistory(raw) {
    var lines = String(raw || "").split("\n")
    var out = []
    for (var i = 0; i < lines.length; i++)
      if (String(lines[i]).trim().length > 0) out.push(String(lines[i]))
    var limit = Math.max(1, root.num(root.settings.historyLimit, 50))
    if (out.length > limit) out = out.slice(out.length - limit)
    out.reverse()
    root.history = out
    root._historyLoaded = true
  }

  function loadHistory() {
    if (historyProc.running) return
    historyProc.running = true
  }

  function pushHistory(text) {
    var next = [text]
    for (var i = 0; i < root.history.length; i++)
      if (root.history[i] !== text) next.push(root.history[i])
    var limit = Math.max(1, root.num(root.settings.historyLimit, 50))
    if (next.length > limit) next = next.slice(0, limit)
    root.history = next
    root.historyIndex = -1
    var dir = root.historyPath.substring(0, root.historyPath.lastIndexOf("/"))
    historyAddProc.command = [
      "bash", "-c",
      "mkdir -p \"$2\" && printf '%s\\n' \"$0\" >> \"$1\"",
      text, root.historyPath, dir
    ]
    historyAddProc.running = true
  }

  function launch(text) {
    root.pendingPrompt = text
    var cwd = String(root.settings.cwd || "auto")
    if (cwd === "auto") {
      cwdProc.used = false
      cwdProc.command = [
        root.cwdHelper,
        Quickshell.env("HOME") + "/Work",
        Quickshell.env("HOME")
      ]
      cwdProc.running = true
    } else if (cwd === "home") {
      root.launchIn(Quickshell.env("HOME"))
    } else {
      root.launchIn(cwd)
    }
  }

  function launchIn(dir) {
    var fallback = Quickshell.env("HOME") + "/Work"
    var target = (dir && String(dir).trim().length > 0) ? String(dir).trim() : fallback
    var terminal = String(root.settings.terminal || "foot")
    var agent = String(root.settings.agent || "opencode")
    var args = []
    args.push(terminal)
    args.push("-e")
    args.push(agent)
    var extra = root.settings.agentArgs
    if (extra && extra.length) {
      for (var i = 0; i < extra.length; i++) args.push(String(extra[i]))
    }
    args.push("--prompt")
    args.push(root.pendingPrompt)
    launcher.workingDirectory = target
    launcher.command = args
    launcher.running = true
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
    id: historyProc
    command: ["cat", root.historyPath]
    stdout: StdioCollector { onStreamFinished: root.applyHistory(text) }
    onExited: root._historyLoaded = true
  }

  Process {
    id: historyAddProc
    command: ["true"]
  }

  Process {
    id: cwdProc
    property bool used: false
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (cwdProc.used) return
        cwdProc.used = true
        root.launchIn(String(text || "").trim())
      }
    }
    onExited: {
      if (cwdProc.used) return
      cwdProc.used = true
      root.launchIn("")
    }
  }

  Process {
    id: launcher
    command: ["true"]
  }

  IpcHandler {
    target: "teyte.prompt"
    function open(): void { root.open("") }
    function close(): void { root.close() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: root.settings.namespace || "teyte.prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.45)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      width: Math.min(root.panelWidth, panel.width - 40)
      height: content.height + root.specPadding * 2
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.paletteYRatio * panel.height
      color: root.specBgColor
      opacity: root.specBgOpacity
      radius: root.specRadius
      border.width: 1
      border.color: root.accentSoft

      MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
      }

      Item {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.specPadding
        height: inputRow.height + 8 + root.hintHeight

        Item {
          id: inputRow
          width: parent.width
          height: Math.max(input.implicitHeight, glyph.implicitHeight)

          Text {
            id: glyph
            text: "❯"
            color: root.specAccent
            font.family: root.specFont
            font.pixelSize: root.specFontSize
            font.bold: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: placeholderText
            text: root.settings.placeholder || "Ask the agent what to do or build…"
            color: root.hintColor
            font.family: root.specFont
            font.pixelSize: root.specFontSize
            anchors.left: input.left
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
          }

          TextInput {
            id: input
            anchors.left: glyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: root.specColor
            font.family: root.specFont
            font.pixelSize: root.specFontSize
            selectByMouse: true
            clip: true
            focus: true
            cursorDelegate: Rectangle {
              width: Math.max(6, root.specFontSize * 0.5)
              height: root.specFontSize * 1.2
              color: root.specAccent
            }

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.dismiss()
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submit()
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.cycleHistory(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.cycleHistory(-1)
                event.accepted = true
              }
            }
          }
        }

        Text {
          id: hint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: inputRow.bottom
          anchors.topMargin: 8
          height: root.hintHeight
          verticalAlignment: Text.AlignVCenter
          text: "Enter ↵ launch   ·   Esc close   ·   ↑↓ history"
          color: root.hintColor
          font.family: root.specFont
          font.pixelSize: Math.max(9, root.specFontSize * 0.72)
          opacity: root.specOpacity
        }

        Text {
          anchors.right: parent.right
          anchors.top: inputRow.bottom
          anchors.topMargin: 8
          height: root.hintHeight
          verticalAlignment: Text.AlignVCenter
          text: {
            var agent = String(root.settings.agent || "opencode")
            var cwd = String(root.settings.cwd || "auto")
            return agent + " · " + (cwd === "auto" ? "focused dir" : cwd)
          }
          color: root.hintColor
          font.family: root.specFont
          font.pixelSize: Math.max(9, root.specFontSize * 0.72)
          opacity: root.specOpacity
        }
      }
    }
  }
}
