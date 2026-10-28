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
  readonly property string calcHelper: Quickshell.env("HOME") + "/.local/bin/teyte-prompt-calc"
  readonly property string noteHelper: Quickshell.env("HOME") + "/.local/bin/teyte-prompt-note"

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
    placeholder: "Search the web or @ for the agent…",
    historyLimit: 50,
    modesEnabled: true,
    defaultMode: "search",
    searchUrl: "https://www.google.com/search?q=%s",
    notePath: "~/inbox.md",
    namespace: "teyte.prompt"
  })

  property var settings: root.defaults
  property string _lastRaw: ""

  property bool opened: false
  property string statusText: ""
  property var history: []
  property int historyIndex: -1
  property string pendingPrompt: ""
  property string pendingKind: "agent"
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
  readonly property color errorColor: Qt.rgba(1.0, 0.45, 0.4, 0.95)

  readonly property bool modesEnabled: root.settings.modesEnabled !== false
  readonly property string defaultMode: String(root.settings.defaultMode || "search") === "agent" ? "agent" : "search"
  readonly property string searchUrl: String(root.settings.searchUrl || "https://www.google.com/search?q=%s")
  readonly property string notePath: {
    var p = String(root.settings.notePath || "~/inbox.md")
    if (p === "~") return Quickshell.env("HOME")
    if (p.indexOf("~/") === 0) return Quickshell.env("HOME") + p.substring(1)
    return p
  }
  readonly property string searchHost: {
    var m = root.searchUrl.match(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/([^\/?#]+)/)
    return m ? String(m[1]).replace(/^www\./i, "") : "default browser"
  }
  readonly property string activeMode: root.modeOf(input.text)
  readonly property string modeGlyph: root.activeMode === "shell" ? "$"
    : root.activeMode === "note" ? "✎"
    : root.activeMode === "calc" ? "="
    : root.activeMode === "agent" ? "@"
    : "⌕"
  readonly property string modeHint: {
    if (root.statusText.length > 0) return root.statusText
    if (root.activeMode === "shell") return "Enter ↵ run   ·   Esc close"
    if (root.activeMode === "note") return "Enter ↵ save note   ·   Esc close"
    if (root.activeMode === "calc") return "Enter ↵ copy result   ·   Esc close"
    if (root.activeMode === "search") return "Enter ↵ search in browser   ·   Esc close   ·   ↑↓ history"
    return "Enter ↵ launch agent   ·   Esc close   ·   ↑↓ history"
  }
  readonly property string modeSummary: {
    if (root.activeMode === "note") return "note · " + root.notePath
    if (root.activeMode === "calc") return "calc · + − * / ** sqrt() pi"
    if (root.activeMode === "search") return "web · " + root.searchHost
    var cwd = String(root.settings.cwd || "auto")
    if (root.activeMode === "shell") return "shell · " + (cwd === "auto" ? "focused dir" : cwd)
    var agent = String(root.settings.agent || "opencode")
    return agent + " · " + (cwd === "auto" ? "focused dir" : cwd)
  }

  function modeOf(raw) {
    var t = String(raw === undefined || raw === null ? "" : raw)
    if (t.length === 0) return root.defaultMode
    if (!root.modesEnabled) return root.defaultMode
    var c = t.charAt(0)
    if (c === ">") return "shell"
    if (c === ":") return "note"
    if (c === "=") return "calc"
    if (c === "?") return "search"
    if (c === "@") return "agent"
    return root.defaultMode
  }

  function queryOf(raw) {
    var t = String(raw === undefined || raw === null ? "" : raw).trim()
    var mode = root.modeOf(t)
    if (!root.modesEnabled) return t
    if (mode === "search" && t.charAt(0) === "?") return t.substring(1).trim()
    if (mode === "agent" && t.charAt(0) === "@") return t.substring(1).trim()
    if (mode !== "search" && mode !== "agent") return t.substring(1).trim()
    return t
  }

  function searchUrlFor(query) {
    var encoded = encodeURIComponent(String(query || ""))
    if (root.searchUrl.indexOf("%s") !== -1) return root.searchUrl.replace("%s", encoded)
    if (root.searchUrl.indexOf("{query}") !== -1) return root.searchUrl.replace("{query}", encoded)
    return root.searchUrl + encoded
  }

  function open(payloadJson) {
    var prefill = ""
    if (payloadJson) {
      try {
        var payload = typeof payloadJson === "string" ? JSON.parse(payloadJson) : payloadJson
        if (payload && typeof payload.text === "string") prefill = payload.text
      } catch (e) {}
    }
    root.opened = true
    root.statusText = ""
    root.historyIndex = -1
    root.loadHistory()
    input.text = prefill
    input.cursorPosition = prefill.length
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
    var raw = String(input.text || "").trim()
    if (raw.length === 0) {
      root.dismiss()
      return
    }
    var mode = root.modeOf(raw)
    var query = root.queryOf(raw)
    if (query.length === 0) {
      root.statusText = "Type something after " + raw.charAt(0)
      return
    }
    root.pushHistory(String(input.text || ""))
    if (mode === "search") {
      root.openSearch(query)
      return
    }
    if (mode === "calc") {
      root.runCalc(query)
      return
    }
    if (mode === "note") {
      root.saveNote(query)
      return
    }
    root.resolveAndLaunch(mode, query)
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

  function openSearch(query) {
    root.statusText = ""
    searchProc.command = ["xdg-open", root.searchUrlFor(query)]
    searchProc.running = true
    root.dismiss()
  }

  function resolveAndLaunch(kind, text) {
    root.pendingKind = kind
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
    var args = []
    args.push(terminal)
    args.push("-e")
    if (root.pendingKind === "shell") {
      args.push("bash")
      args.push("-lc")
      args.push(root.pendingPrompt + "\nexec bash")
    } else {
      var agent = String(root.settings.agent || "opencode")
      args.push(agent)
      var extra = root.settings.agentArgs
      if (extra && extra.length) {
        for (var i = 0; i < extra.length; i++) args.push(String(extra[i]))
      }
      args.push("--prompt")
      args.push(root.pendingPrompt)
    }
    launcher.workingDirectory = target
    launcher.command = args
    launcher.running = true
  }

  function runCalc(expr) {
    root.statusText = ""
    calcProc.used = false
    calcProc.command = [root.calcHelper, expr]
    calcProc.running = true
  }

  function finishCalc(result) {
    root.statusText = ""
    copyProc.command = ["wl-copy", result]
    copyProc.running = true
    root.notify("Calc: " + result)
    root.dismiss()
  }

  function failCalc() {
    root.statusText = "Invalid expression — try 12*8+3, sqrt(2), or pi"
  }

  function saveNote(text) {
    root.statusText = ""
    noteProc.command = [root.noteHelper, root.notePath, text]
    noteProc.running = true
    root.dismiss()
  }

  function notify(headline, body) {
    if (notifyProc.running) return
    notifyProc.command = body
      ? ["omarchy-notification-send", "-u", "low", headline, body]
      : ["omarchy-notification-send", "-u", "low", headline]
    notifyProc.running = true
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

  Process {
    id: searchProc
    command: ["true"]
  }

  Process {
    id: calcProc
    property bool used: false
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (calcProc.used) return
        calcProc.used = true
        var result = String(text || "").trim()
        if (result.length > 0) root.finishCalc(result)
        else root.failCalc()
      }
    }
  }

  Process {
    id: copyProc
    command: ["true"]
  }

  Process {
    id: noteProc
    command: ["true"]
    onExited: function(exitCode) {
      if (exitCode === 0) root.notify("Note saved", root.notePath)
    }
  }

  Process {
    id: notifyProc
    command: ["true"]
  }

  IpcHandler {
    target: "teyte.prompt"
    function open() { root.open("") }
    function close() { root.close() }
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
            text: root.modeGlyph
            color: root.specAccent
            font.family: root.specFont
            font.pixelSize: root.specFontSize
            font.bold: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, root.specFontSize * 1.2)
          }

          Text {
            id: placeholderText
            text: root.settings.placeholder || "Search the web or @ for the agent…"
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
            onTextEdited: root.statusText = ""
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
          anchors.right: summary.left
          anchors.rightMargin: 12
          anchors.top: inputRow.bottom
          anchors.topMargin: 8
          height: root.hintHeight
          verticalAlignment: Text.AlignVCenter
          text: root.modeHint
          color: root.statusText.length > 0 ? root.errorColor : root.hintColor
          font.family: root.specFont
          font.pixelSize: Math.max(9, root.specFontSize * 0.72)
          opacity: root.specOpacity
          elide: Text.ElideRight
        }

        Text {
          id: summary
          anchors.right: parent.right
          anchors.top: inputRow.bottom
          anchors.topMargin: 8
          height: root.hintHeight
          verticalAlignment: Text.AlignVCenter
          text: root.modeSummary
          color: root.hintColor
          font.family: root.specFont
          font.pixelSize: Math.max(9, root.specFontSize * 0.72)
          opacity: root.specOpacity
        }
      }
    }
  }
}
