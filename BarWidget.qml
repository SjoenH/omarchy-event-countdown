import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "no.koka.event-countdown"

  implicitWidth: barContent.implicitWidth + 10
  implicitHeight: root.barSize

  // ---- data model -----------------------------------------------------------
  property string mode: root.setting("mode", "both")
  property var events: root.parseEvents(root.setting("events", []))

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool configured: root.events.length > 0

  function emptyEvent() {
    return { id: "", name: "", month: 1, day: 1, year: 0, repeats: true }
  }
  function newId() {
    return "e" + Date.now().toString(36)
  }
  function parseEvents(arr) {
    if (!Array.isArray(arr)) return []
    var out = []
    for (var i = 0; i < arr.length; i++) {
      var e = arr[i]
      if (!e || typeof e !== "object") continue
      var m = parseInt(e.month, 10), d = parseInt(e.day, 10)
      if (isNaN(m) || isNaN(d)) continue
      out.push({
        id: e.id || root.newId(),
        name: String(e.name || ""),
        month: m,
        day: d,
        year: parseInt(e.year, 10) || 0,
        repeats: e.repeats === true
      })
    }
    return out
  }

  function persist(patch) {
    if (patch) {
      if (patch.mode !== undefined) root.mode = patch.mode
      if (patch.events !== undefined) root.events = root.parseEvents(patch.events)
    }
    var entry = { id: root.moduleName, mode: root.mode, events: root.events }
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
    root.refresh()
  }

  function previewMode(v) { root.mode = v; root.refresh() }
  function previewEvents(v) { root.events = root.parseEvents(v); root.refresh() }

  // ---- date math ------------------------------------------------------------
  function dayIndex(d) { return Math.floor(d.getTime() / 86400000) }
  function dateFromIndex(i) { return new Date(i * 86400000) }
  function ydate(year, month, day) { return new Date(year, month - 1, day) }

  function todayIndex() { return root.dayIndex(new Date()) }

  // For an event compute its previous and next occurrence (local day indexes).
  // Recurring events span one year between consecutive occurrences; one-off
  // events use a one-year lead-in before the single date and stay "passed"
  // after it.
  function occurrences(evt) {
    var t = root.todayIndex()
    var m = evt.month, d = evt.day
    var yNow = new Date().getFullYear()
    var res = { prev: 0, next: 0, passed: true }

    if (evt.repeats) {
      // next occurrence is always upcoming (or today); a recurring event is
      // never "passed" because there is always another occurrence next year.
      var thisY = root.dayIndex(root.ydate(yNow, m, d))
      var next = thisY >= t ? thisY : root.dayIndex(root.ydate(yNow + 1, m, d))
      res.next = next
      res.prev = root.dayIndex(root.ydate(new Date(res.next * 86400000).getFullYear() - 1, m, d))
      res.passed = false
      return res
    }

    // one-off: month/day/year must form a valid future/past date
    var y = evt.year || yNow
    var occ = root.dayIndex(root.ydate(y, m, d))
    if (occ >= t) {
      res.next = occ
      res.prev = occ - 365
      res.passed = false
    } else {
      res.next = occ
      res.prev = occ - 365
      res.passed = true
    }
    return res
  }

  // 0..1 progress: how full the bar is as it fills toward the next occurrence.
  function fractionOf(evt) {
    var o = root.occurrences(evt)
    var span = o.next - o.prev
    if (span <= 0) return 1
    var f = (root.todayIndex() - o.prev) / span
    if (f < 0) f = 0
    if (f > 1) f = 1
    return f
  }

  function daysUntil(evt) { return root.occurrences(evt).next - root.todayIndex() }

  function countOf(evt) {
    var o = root.occurrences(evt)
    var days = Math.abs(o.next - root.todayIndex())
    var text
    if (o.passed) text = days === 0 ? "today" : (days + "d ago")
    else text = days === 0 ? "today" : ("in " + days + "d")
    return { text: text, upcoming: !o.passed, days: days }
  }

  // Which event does the bar emphasize, given the widget mode?
  function nearestEvent() {
    if (root.events.length === 0) return null
    if (root.mode === "countdown") {
      var bestUp = null, bestDaysUp = 1e9
      for (var i = 0; i < root.events.length; i++) {
        var e = root.events[i], c = root.countOf(e)
        if (!c.upcoming) continue
        if (c.days < bestDaysUp) { bestDaysUp = c.days; bestUp = e }
      }
      return bestUp
    }
    if (root.mode === "countup") {
      var bestP = null, bestDaysP = -1
      for (var j = 0; j < root.events.length; j++) {
        var e2 = root.events[j], c2 = root.countOf(e2)
        if (c2.upcoming) continue
        if (c2.days > bestDaysP) { bestDaysP = c2.days; bestP = e2 }
      }
      return bestP
    }
    // both: nearest in absolute terms
    var best = null, bestAbs = 1e9
    for (var k = 0; k < root.events.length; k++) {
      var e3 = root.events[k], c3 = root.countOf(e3)
      if (c3.days < bestAbs) { bestAbs = c3.days; best = e3 }
    }
    return best
  }

  function refresh() {
    var n = root.nearestEvent()
    barItem.barFrac = n ? root.fractionOf(n) : 0
    barItem.barName = n ? (n.name !== "" ? n.name : root.monthDayName(n)) : "no events"
    barItem.barCount = n ? root.countOf(n).text : ""
  }

  function monthDayName(evt) {
    var names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    var mn = names[(evt.month - 1 + 12) % 12] || evt.month
    return mn + " " + evt.day
  }

  Timer {
    id: refreshTimer
    interval: 60000
    repeat: true
    onTriggered: root.refresh()
  }

  // recompute on changes
  QtObject { id: trigger; property int t: 0 }
  function syncPanel() { if (panelLoader.item) panelLoader.item.syncFromWidget() }
  onModeChanged: { root.refresh(); refreshTimer.restart(); root.syncPanel() }
  onEventsChanged: { root.refresh(); refreshTimer.restart(); root.syncPanel() }
  onConfiguredChanged: root.refresh()
  Component.onCompleted: { refreshTimer.start(); Qt.callLater(root.refresh) }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = root
    panelLoader.item.hostWidget = root
  }

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    }
    onExited: {
      if (root.bar) root.bar.hideTooltip(root)
    }
    onClicked: root.toggle()

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: 6

      // compact progress fill
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 8
        radius: 4
        color: root.bar ? Qt.darker(root.bar.background, 1.2) : "#222222"

        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width * barItem.barFrac
          height: parent.height
          radius: 4
          color: root.bar ? root.bar.foreground : "#f8f8f2"
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: barItem.barName
        color: root.bar ? root.bar.foreground : "#f8f8f2"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: barItem.barCount !== ""
        text: barItem.barCount
        color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : "#999999"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  QtObject {
    id: barItem
    property real barFrac: 0
    property string barName: "no events"
    property string barCount: ""
  }

  function tooltipText() {
    if (root.events.length === 0) return "Event Countdown\nAdd an event to begin."
    var lines = ["Event Countdown"]
    for (var i = 0; i < root.events.length; i++) {
      var e = root.events[i]
      lines.push((e.name !== "" ? e.name : root.monthDayName(e)) + " — " + root.countOf(e).text)
    }
    return lines.join("\n")
  }
}
