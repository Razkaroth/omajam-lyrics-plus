pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

// Synced lyrics for the current local MPD track. The bridge reads the embedded
// tag because MPD's readcomments command omits multiline Vorbis comments.
Item {
  id: root

  property var service: null
  property bool active: false
  property string fontFamily: Style.font.family
  property int fontSize: Style.font.bodySmall
  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color accent: Color.accent

  property var rows: []
  property bool loading: false
  property string requestedFile: ""
  property string loadError: ""
  property real nowMs: 0
  readonly property var list: lyricList

  readonly property real preciseElapsed: {
    if (!service || !service.hasSong || !service.isPlaying) return service ? service.elapsed : 0
    var elapsed = service.reportedElapsed + Math.max(0, nowMs - service.elapsedAt) / 1000
    return service.duration > 0 ? Math.min(service.duration, elapsed) : elapsed
  }

  readonly property int activeLine: {
    var result = -1
    for (var i = 0; i < rows.length; i++) {
      if (Number(rows[i].time) <= preciseElapsed) result = i
      else break
    }
    return result
  }

  readonly property real activeProgress: {
    if (activeLine < 0 || activeLine >= rows.length) return 0
    var start = Number(rows[activeLine].time)
    var end = activeLine + 1 < rows.length ? Number(rows[activeLine + 1].time)
      : (service ? Number(service.duration) : start)
    if (!(end > start)) return 0
    return Math.max(0, Math.min(1, (preciseElapsed - start) / (end - start)))
  }

  function refresh() {
    if (!service || !service.connected || !service.hasSong) {
      rows = []
      loading = false
      requestedFile = ""
      return
    }
    var file = service.songFile
    requestedFile = file
    loading = true
    loadError = ""
    service.request("lyrics", { file: file, channel: "lyrics" }, function(result, error) {
      if (requestedFile !== file || !service || service.songFile !== file) return
      loading = false
      rows = result
      loadError = error
    })
  }

  function activate() {
    var row = lyricList.currentRow
    if (service && row && Number(row.time) >= 0) service.seek(Number(row.time))
  }

  onActiveChanged: if (active) refresh()
  Timer {
    interval: 100
    repeat: true
    running: root.active && root.service && root.service.isPlaying
    onTriggered: root.nowMs = Date.now()
  }

  Connections {
    target: root.service
    function onSongFileChanged() { if (root.active) root.refresh() }
    function onConnectedChanged() { if (root.active) root.refresh() }
  }

  readonly property bool showArt: width >= Style.space(760)

  Row {
    anchors.fill: parent

    Item {
      id: artPane
      visible: root.showArt
      width: visible ? Math.min(Math.round(root.width * 0.32), root.height * 0.72) : 0
      height: parent.height

      Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        anchors.rightMargin: Style.space(18)
        spacing: Style.space(10)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "NOW SINGING"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Math.max(9, root.fontSize - 2)
          font.bold: true
          font.letterSpacing: 1.5
        }

        Item {
          width: parent.width
          height: width

          Image {
            id: cover
            anchors.fill: parent
            source: root.service ? root.service.artSource : ""
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize.width: 700
          }

          Rectangle {
            anchors.fill: parent
            visible: !cover.visible
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
            border.width: Style.normalBorderWidth
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
            radius: Style.cornerRadius

            Text {
              anchors.centerIn: parent
              text: "󰝚"
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
              font.family: root.fontFamily
              font.pixelSize: Math.round(parent.height * 0.3)
            }
          }

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Style.normalBorderWidth
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
            radius: Style.cornerRadius
          }
        }

        Text {
          width: parent.width
          text: root.service && root.service.hasSong ? root.service.songTitle(root.service.song) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.round(root.fontSize * 1.15)
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: root.service ? String(root.service.song.artist || root.service.song.albumartist || "") : ""
          color: Qt.darker(root.foreground, 1.35)
          font.family: root.fontFamily
          font.pixelSize: root.fontSize
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        Rectangle {
          width: parent.width
          height: Math.max(3, Style.space(4))
          radius: height / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1,
              root.service && root.service.duration > 0 ? root.preciseElapsed / root.service.duration : 0))
            height: parent.height
            radius: height / 2
            color: root.accent
          }
        }
      }
    }

    Rectangle {
      visible: root.showArt
      width: visible ? Math.max(1, Style.normalBorderWidth) : 0
      height: parent.height
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    }

    LyricsStage {
      id: lyricList
      width: parent.width - artPane.width - (root.showArt ? Math.max(1, Style.normalBorderWidth) : 0)
      height: parent.height
      rows: root.rows
      activeIndex: root.activeLine
      activeProgress: root.activeProgress
      active: root.active
      loading: root.loading
      emptyText: root.loadError !== "" ? root.loadError
        : (!root.service || !root.service.connected ? "Not connected"
        : (!root.service.hasSong ? "Nothing is playing"
        : "No synced embedded lyrics for this track"))
      fontFamily: root.fontFamily
      fontSize: root.showArt ? root.fontSize : Math.round(root.fontSize * 1.08)
      foreground: root.foreground
      background: root.background
      accent: root.accent
      onRowClicked: function(index) {
        var row = root.rows[index]
        if (root.service && row && Number(row.time) >= 0) root.service.seek(Number(row.time))
      }
      onActivated: root.activate()
    }
  }
}
