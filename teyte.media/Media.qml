import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/teyte.media/config.json"

  readonly property var defaults: ({
    fontScale: 0.018,
    fontFamily: "JetBrainsMono Nerd Font",
    fontWeight: 400,
    color: "#ffffff",
    bgColor: "#05182e",
    bgOpacity: 0.85,
    padding: 18,
    opacity: 1.0,
    xRatio: 0.75,
    yRatio: 0.5,
    namespace: "teyte.media"
  })

  property var settings: root.defaults
  property string _lastRaw: ""

  function num(v, fallback) {
    if (v === null || v === undefined || v === "") return fallback
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  readonly property real specFontScale: root.num(root.settings.fontScale, 0.018)
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
  readonly property real yRatio: root.num(root.settings.yRatio, 0.5)
  readonly property real xOffset: root.num(root.settings.xOffset, 0)
  readonly property real yOffset: root.num(root.settings.yOffset, 0)

  property var activePlayer: null
  property string title: "Title"
  property string artist: "Artist"
  property string album: "Album"
  property bool isPlaying: true
  property real position: 0
  property real length: 200
  property string idleText: "Nothing playing"
  property bool idle: false

  function updateFromPlayer(p) {
    if (!p) return
    root.title = p.trackTitle || ""
    root.artist = p.trackArtist || ""
    root.album = p.trackAlbum || ""
    root.isPlaying = p.isPlaying
    root.position = p.position || 0
    root.length = p.length || 0
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

  function findActivePlayer() {
    var vals = Mpris.players.values
    if (!vals || vals.length === 0) return null
    for (var i = 0; i < vals.length; i++) {
      var p = vals[i]
      if (p && p.trackTitle && p.trackTitle.length > 0) return p
    }
    return null
  }

  function refresh() {
    var p = root.findActivePlayer()
    if (p) {
      if (p !== root.activePlayer) {
        root.activePlayer = p
        p.trackChanged.connect(() => root.updateFromPlayer(root.findActivePlayer()))
        p.isPlayingChanged.connect(() => root.updateFromPlayer(root.findActivePlayer()))
      }
      root.updateFromPlayer(root.activePlayer)
    }
    // Keep placeholders when nothing is playing
  }

  Component.onCompleted: root.refresh()

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
      root.refresh()
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.isPlaying
    onTriggered: {
      if (root.activePlayer && root.activePlayer.isPlaying) {
        root.position = root.activePlayer.position
      }
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

        Item {
          id: mediaContent
          x: root.xMargin + root.xOffset
          y: root.yRatio * surface.height - mediaCol.height / 2 + root.yOffset

          Column {
            id: mediaCol
            spacing: 4
            width: root.panelWidth

            Text {
              id: titleText
              text: root.title
              color: root.specColor
              font.family: root.specFont
              font.weight: Font.Bold
              font.pixelSize: Math.max(8, root.specFontSize)
              font.hintingPreference: Font.PreferFullHinting
              opacity: root.specOpacity * 1.0
              wrapMode: Text.NoWrap
              width: root.panelWidth
              elide: Text.ElideRight
            }

            Text {
              id: artistText
              text: root.artist
              visible: true
              color: root.specColor
              font.family: root.specFont
              font.pixelSize: Math.max(8, root.specFontSize)
              font.hintingPreference: Font.PreferFullHinting
              opacity: root.specOpacity * 0.7
              wrapMode: Text.NoWrap
              width: root.panelWidth
              elide: Text.ElideRight
            }

            Text {
              id: albumText
              text: root.album
              visible: true
              color: root.specColor
              font.family: root.specFont
              font.pixelSize: Math.max(8, root.specFontSize)
              font.hintingPreference: Font.PreferFullHinting
              opacity: root.specOpacity * 0.5
              wrapMode: Text.NoWrap
              width: root.panelWidth
              elide: Text.ElideRight
            }

            Item {
              id: progressTrack
              visible: root.length > 0
              width: Math.max(50, mediaCol.width)
              height: Math.max(2, Math.round(surface.height * root.specFontScale * 0.14))

              Rectangle {
                id: progressBg
                anchors.fill: parent
                color: root.specColor
                opacity: 0.25 * root.specOpacity
                radius: height / 2
              }

              Rectangle {
                id: progressFill
                width: progressTrack.width * Math.min(1, Math.max(0, root.length > 0 ? root.position / root.length : 0))
                height: progressTrack.height
                color: Qt.rgba(0.4, 0.8, 1.0, 1.0)
                opacity: root.specOpacity
                radius: height / 2
              }
            }
          }
        }

        Rectangle {
          color: root.specBgColor
          opacity: Math.min(1, Math.max(0, root.specBgOpacity))
          radius: 12
          x: mediaContent.x - root.specPadding + 8
          y: mediaContent.y - root.specPadding
          width: mediaCol.width + root.specPadding * 2
          height: mediaCol.height + root.specPadding * 2
          z: -1
        }
      }
    }
  }
}
