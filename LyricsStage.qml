pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

// A lyric-first list: playback owns the centred line while the keyboard keeps
// an independent cursor. Manual navigation pauses following briefly so the
// view does not fight the person reading it.
Item {
  id: root

  property var rows: []
  property int activeIndex: -1
  property real activeProgress: 0
  property bool active: false
  property bool loading: false
  property string emptyText: "No synced embedded lyrics for this track"
  property string fontFamily: Style.font.family
  property int fontSize: Style.font.bodySmall
  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color accent: Color.accent

  property int currentIndex: 0
  property bool followSuspended: false
  property var marked: ({})
  property int markedCount: 0

  readonly property int count: rows ? rows.length : 0
  readonly property int effectiveIndex: !followSuspended && activeIndex >= 0
    ? activeIndex : currentIndex
  readonly property var currentRow: count > 0 && effectiveIndex >= 0 && effectiveIndex < count
    ? rows[effectiveIndex] : null

  signal activated(int index)
  signal rowClicked(int index)

  function clamp(index) {
    if (count === 0) return 0
    return Math.max(0, Math.min(count - 1, index))
  }

  function suspendFollow() {
    followSuspended = true
    followTimer.restart()
  }

  function resumeFollow() {
    followTimer.stop()
    followSuspended = false
    centerActive()
  }

  function centerActive() {
    if (activeIndex < 0 || activeIndex >= count) return
    var item = view.itemAtIndex(activeIndex)
    if (!item) {
      view.positionViewAtIndex(activeIndex, ListView.Center)
      scrollInitialized = true
      return
    }
    var target = Math.max(0, Math.min(Math.max(0, view.contentHeight - view.height),
                                      item.y + item.height / 2 - view.height / 2))
    if (!scrollInitialized) {
      view.contentY = target
      scrollInitialized = true
      return
    }
    centerAnimation.stop()
    centerAnimation.from = view.contentY
    centerAnimation.to = target
    centerAnimation.start()
  }

  function moveTo(index) {
    currentIndex = clamp(index)
    suspendFollow()
    view.positionViewAtIndex(currentIndex, ListView.Contain)
  }

  function move(delta) { moveTo(currentIndex + delta) }
  function toTop() { moveTo(0) }
  function toBottom() { moveTo(count - 1) }
  function pageUp() { moveTo(currentIndex - Math.max(1, Math.floor(view.height / (fontSize * 2.5)))) }
  function pageDown() { moveTo(currentIndex + Math.max(1, Math.floor(view.height / (fontSize * 2.5)))) }
  function halfPageUp() { moveTo(currentIndex - Math.max(1, Math.floor(view.height / (fontSize * 5)))) }
  function halfPageDown() { moveTo(currentIndex + Math.max(1, Math.floor(view.height / (fontSize * 5)))) }
  function centerCursor() { view.positionViewAtIndex(currentIndex, ListView.Center) }
  function cursorToTop() { view.positionViewAtIndex(currentIndex, ListView.Beginning) }
  function cursorToBottom() { view.positionViewAtIndex(currentIndex, ListView.End) }

  function findNext(needle, from, direction) {
    var wanted = String(needle || "").toLowerCase()
    if (wanted === "" || count === 0) return -1
    for (var step = 1; step <= count; step++) {
      var index = ((from + step * direction) % count + count) % count
      if (String(rows[index].text || "").toLowerCase().indexOf(wanted) !== -1) return index
    }
    return -1
  }

  // Lyrics cannot be marked, but the client calls these on any list.
  function toggleMark(index) {}
  function invertMarks() {}
  function clearMarks() {}

  onRowsChanged: {
    currentIndex = activeIndex >= 0 ? activeIndex : 0
    followSuspended = false
    scrollInitialized = false
    Qt.callLater(centerActive)
  }

  onActiveIndexChanged: {
    if (!followSuspended) currentIndex = activeIndex >= 0 ? activeIndex : 0
    if (!followSuspended && active) Qt.callLater(centerActive)
  }

  property bool scrollInitialized: false

  NumberAnimation {
    id: centerAnimation
    target: view
    property: "contentY"
    duration: 260
    easing.type: Easing.OutCubic
  }

  Timer {
    id: followTimer
    interval: 4000
    repeat: false
    onTriggered: root.resumeFollow()
  }

  ListView {
    id: view
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    clip: true
    model: root.rows
    spacing: Style.space(3)
    boundsBehavior: Flickable.StopAtBounds
    reuseItems: true
    cacheBuffer: Math.max(0, height)
    header: Item { width: 1; height: Math.max(0, view.height / 2 - Style.space(24)) }
    footer: Item { width: 1; height: Math.max(0, view.height / 2 - Style.space(24)) }

    WheelHandler {
      onWheel: function(event) {
        root.suspendFollow()
        centerAnimation.stop()
        var delta = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 * Style.space(65)
          : event.pixelDelta.y * 2
        view.cancelFlick()
        view.contentY = Math.max(0, Math.min(view.contentHeight - view.height,
                                             view.contentY - delta))
      }
    }

    delegate: Item {
      id: lyricRow
      required property var modelData
      required property int index

      readonly property bool current: index === root.activeIndex
      readonly property bool selected: root.followSuspended && index === root.currentIndex
      readonly property int distance: root.activeIndex < 0 ? 9 : Math.abs(index - root.activeIndex)
      readonly property string lyric: String(modelData.text || "")
      readonly property bool instrumental: lyric === ""
      property real instrumentalPulse: 1.0

      width: view.width
      height: Math.max(Style.space(34), lyricText.implicitHeight + Style.space(current ? 22 : 14))
      opacity: current || selected ? 1.0 : (distance === 1 ? 0.78 : (distance === 2 ? 0.56 : 0.32))

      Behavior on opacity { NumberAnimation { duration: 180 } }

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(58)
        anchors.rightMargin: Style.space(10)
        visible: lyricRow.current || lyricRow.selected
        radius: Style.cornerRadius
        color: lyricRow.current
          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.13)
          : Color.menu.selectedBackground
        border.width: lyricRow.current ? Math.max(1, Style.normalBorderWidth) : 0
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)
      }

      Text {
        id: timestamp
        anchors { left: parent.left; leftMargin: Style.space(3); verticalCenter: parent.verticalCenter }
        width: Style.space(48)
        horizontalAlignment: Text.AlignRight
        text: String(lyricRow.modelData.stamp || "")
        visible: hover.hovered || lyricRow.selected
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Math.max(9, root.fontSize - 2)
      }

      Text {
        id: lyricText
        anchors {
          left: parent.left
          leftMargin: Style.space(72)
          right: parent.right
          rightMargin: Style.space(46)
          verticalCenter: parent.verticalCenter
        }
        text: lyricRow.instrumental ? "·  ·  ·" : lyricRow.lyric
        color: lyricRow.current ? root.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: lyricRow.current ? Math.round(root.fontSize * 1.34)
          : (lyricRow.distance === 1 ? Math.round(root.fontSize * 1.08) : root.fontSize)
        font.bold: lyricRow.current || lyricRow.selected
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        horizontalAlignment: lyricRow.instrumental ? Text.AlignHCenter : Text.AlignLeft
        opacity: lyricRow.instrumentalPulse

        Behavior on font.pixelSize { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      }

      SequentialAnimation {
        running: lyricRow.current && lyricRow.instrumental
        loops: Animation.Infinite
        NumberAnimation {
          target: lyricRow
          property: "instrumentalPulse"
          to: 0.35
          duration: 650
          easing.type: Easing.InOutSine
        }
        NumberAnimation {
          target: lyricRow
          property: "instrumentalPulse"
          to: 1.0
          duration: 650
          easing.type: Easing.InOutSine
        }
      }

      Canvas {
        id: radialProgress
        visible: lyricRow.current && !lyricRow.instrumental
        anchors { right: parent.right; rightMargin: Style.space(22); verticalCenter: parent.verticalCenter }
        width: Style.space(16)
        height: width
        antialiasing: true
        property real progress: Math.max(0, Math.min(1, root.activeProgress))
        property color trackColor: Qt.rgba(root.foreground.r, root.foreground.g,
                                            root.foreground.b, 0.16)
        property color fillColor: root.accent

        onProgressChanged: requestPaint()
        onTrackColorChanged: requestPaint()
        onFillColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var cx = width / 2
          var cy = height / 2
          var radius = Math.max(0, Math.min(width, height) / 2 - 1)

          ctx.beginPath()
          ctx.arc(cx, cy, radius, 0, Math.PI * 2)
          ctx.fillStyle = trackColor
          ctx.fill()

          if (progress > 0) {
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.arc(cx, cy, radius, -Math.PI / 2,
                    -Math.PI / 2 + Math.PI * 2 * progress)
            ctx.closePath()
            ctx.fillStyle = fillColor
            ctx.fill()
          }

          ctx.beginPath()
          ctx.arc(cx, cy, radius, 0, Math.PI * 2)
          ctx.lineWidth = 1
          ctx.strokeStyle = fillColor
          ctx.stroke()
        }
      }

      HoverHandler { id: hover }

      TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
          root.currentIndex = lyricRow.index
          root.rowClicked(lyricRow.index)
          root.resumeFollow()
        }
        onDoubleTapped: root.activated(lyricRow.index)
      }
    }

    Text {
      anchors.centerIn: parent
      width: parent.width - Style.space(32)
      visible: root.count === 0
      text: root.loading ? "Loading lyrics…" : root.emptyText
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }

  // These masks soften the stage edges without affecting interaction.
  Rectangle {
    z: 3
    anchors { top: parent.top; left: parent.left; right: parent.right }
    height: Style.space(48)
    gradient: Gradient {
      GradientStop { position: 0; color: root.background }
      GradientStop { position: 1; color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0) }
    }
  }

  Rectangle {
    z: 3
    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
    height: Style.space(48)
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0) }
      GradientStop { position: 1; color: root.background }
    }
  }

  Rectangle {
    z: 4
    visible: root.followSuspended && root.activeIndex >= 0
    anchors { right: parent.right; bottom: parent.bottom; margins: Style.space(12) }
    width: returnLabel.implicitWidth + Style.space(20)
    height: returnLabel.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: Color.menu.selectedBackground
    border.width: Style.normalBorderWidth
    border.color: root.accent

    Text {
      id: returnLabel
      anchors.centerIn: parent
      text: "Return to current line"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Math.max(9, root.fontSize - 1)
      font.bold: true
    }

    TapHandler { onTapped: root.resumeFollow() }
  }
}
