import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
    // === 1. METADATA ===
    id: root
    objectName: "eventCountdown"
    moduleName: "no.koka.event-countdown"

    // === 2. SIGNALS ===

    // === 3. PROPERTIES ===
    // 3a. State properties
    property string mode: "both"
    property var events: []

    // 3b. State/readonly
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool configured: root.events.length > 0

    // 3c. Layout
    implicitWidth: barContent.implicitWidth + 10
    implicitHeight: root.barSize

    // === 5. ATTACHED OBJECTS & BEHAVIORS ===
    Accessible.role: Accessible.Button
    Accessible.name: "Event Countdown"

    // === 6. CHILD OBJECTS ===
    Timer {
        id: refreshTimer
        interval: 60000
        repeat: true
        onTriggered: root.refresh()
    }

    QtObject { id: trigger; property int t: 0 }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: "Event Countdown widget — click to configure"

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

    // === 7. STATES & TRANSITIONS ===

    // === 8. SIGNAL HANDLERS ===
    onModeChanged: { root.refresh(); refreshTimer.restart(); root.syncPanel() }
    onEventsChanged: { root.refresh(); refreshTimer.restart(); root.syncPanel() }
    onConfiguredChanged: root.refresh()
    onBarChanged: injectPanel()

    Component.onCompleted: { reboot(); refreshTimer.start(); Qt.callLater(root.refresh) }
    onSettingsChanged: reboot()

    // Re-read this widget's layout entry straight from the bar host. The host
    // technically pushes the same data through `settings`, but injection can
    // race widget construction on slower shells, so deriving from the live
    // layout is the reliable path and keeps the panel and bar in sync.
    function reboot() {
        if (!root.bar || typeof root.bar.layoutEntries !== "function") return
        var found = null
        for (var s = 0; s < 3 && !found; s++) {
            var region = ["left", "center", "right"][s]
            var entries = root.bar.layoutEntries(region)
            for (var i = 0; i < entries.length; i++) {
                var e = entries[i]
                var id = typeof e === "object" && e ? e.id : e
                if (id === root.moduleName) { found = e; break }
            }
        }
        if (!found) return
        var entry = typeof found === "object" ? found : {}
        var nextMode = entry["mode"] !== undefined ? String(entry["mode"]) : root.mode
        var nextEvents = root.parseEvents(entry["events"])
        if (nextMode !== root.mode) root.mode = nextMode
        root.events = nextEvents
    }

    function open() { if (panelLoader.item) panelLoader.item.open() }
    function close() { if (panelLoader.item) panelLoader.item.close() }
    function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

    // === 9. FUNCTIONS (private first, then public) ===
    function _dayIndex(d) { return Math.floor(d.getTime() / 86400000) }
    function _ydate(year, month, day) { return new Date(year, month - 1, day) }
    function _todayIndex() { return _dayIndex(new Date()) }

    function _occurrences(evt) {
        var t = _todayIndex()
        var m = evt.month, d = evt.day
        var yNow = new Date().getFullYear()
        var res = { prev: 0, next: 0, passed: true }

        if (evt.repeats) {
            var thisY = _dayIndex(_ydate(yNow, m, d))
            var next = thisY >= t ? thisY : _dayIndex(_ydate(yNow + 1, m, d))
            res.next = next
            res.prev = _dayIndex(_ydate(new Date(res.next * 86400000).getFullYear() - 1, m, d))
            res.passed = false
            return res
        }

        var y = evt.year || yNow
        var occ = _dayIndex(_ydate(y, m, d))
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

    function _fractionOf(evt) {
        var o = _occurrences(evt)
        var span = o.next - o.prev
        if (span <= 0) return 1
        var f = (_todayIndex() - o.prev) / span
        if (f < 0) f = 0
        if (f > 1) f = 1
        return f
    }

    function _countOf(evt) {
        var o = _occurrences(evt)
        var days = Math.abs(o.next - _todayIndex())
        var text
        if (o.passed) text = days === 0 ? "today" : (days + "d ago")
        else text = days === 0 ? "today" : ("in " + days + "d")
        return { text: text, upcoming: !o.passed, days: days }
    }

    function _nearestEvent() {
        if (!root.events || root.events.length === 0) return null
        if (root.mode === "countdown") {
            var bestUp = null, bestDaysUp = 1e9
            for (var i = 0; i < root.events.length; i++) {
                var e = root.events[i], c = _countOf(e)
                if (!c.upcoming) continue
                if (c.days < bestDaysUp) { bestDaysUp = c.days; bestUp = e }
            }
            return bestUp
        }
        if (root.mode === "countup") {
            var bestP = null, bestDaysP = -1
            for (var j = 0; j < root.events.length; j++) {
                var e2 = root.events[j], c2 = _countOf(e2)
                if (c2.upcoming) continue
                if (c2.days > bestDaysP) { bestDaysP = c2.days; bestP = e2 }
            }
            return bestP
        }
        var best = null, bestAbs = 1e9
        for (var k = 0; k < root.events.length; k++) {
            var e3 = root.events[k], c3 = _countOf(e3)
            if (c3.days < bestAbs) { bestAbs = c3.days; best = e3 }
        }
        return best
    }

    function _monthDayName(evt) {
        var names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        var mn = names[(evt.month - 1 + 12) % 12] || evt.month
        return mn + " " + evt.day
    }

    function _refresh() {
        var n = _nearestEvent()
        barItem.barFrac = n ? _fractionOf(n) : 0
        barItem.barName = n ? (n.name !== "" ? n.name : _monthDayName(n)) : "no events"
        barItem.barCount = n ? _countOf(n).text : ""
    }

    function _tooltipText() {
        if (!root.events || root.events.length === 0) return "Event Countdown\nAdd an event to begin."
        var lines = ["Event Countdown"]
        for (var i = 0; i < root.events.length; i++) {
            var e = root.events[i]
            lines.push((e.name !== "" ? e.name : _monthDayName(e)) + " — " + _countOf(e).text)
        }
        return lines.join("\n")
    }

    function _parseEvents(arr) {
        if (!Array.isArray(arr)) return []
        var out = []
        for (var i = 0; i < arr.length; i++) {
            var e = arr[i]
            if (!e || typeof e !== "object") continue
            var m = parseInt(e.month, 10), d = parseInt(e.day, 10)
            if (isNaN(m) || isNaN(d)) continue
            out.push({
                id: e.id || _newId(),
                name: String(e.name || ""),
                month: m,
                day: d,
                year: parseInt(e.year, 10) || 0,
                repeats: e.repeats === true
            })
        }
        return out
    }

    function _newId() { return "e" + Date.now().toString(36) }

    // --- Public API ---
    function emptyEvent() { return { id: "", name: "", month: 1, day: 1, year: 0, repeats: true } }
    function newId() { return _newId() }
    function parseEvents(arr) { return _parseEvents(arr) }
    function refresh() { _refresh() }

    function persist(patch) {
        if (patch) {
            if (patch.mode !== undefined) root.mode = patch.mode
            if (patch.events !== undefined) root.events = parseEvents(patch.events)
        }
        var entry = { id: root.moduleName, mode: root.mode, events: root.events }
        root.settings = entry
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
            root.bar.shell.updateEntryInline(root.moduleName, entry)
        }
        root.refresh()
    }

    function previewMode(v) { root.mode = v; root.refresh() }
    function previewEvents(v) { root.events = parseEvents(v); root.refresh() }

    function syncPanel() { if (panelLoader.item) panelLoader.item.syncFromWidget() }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = root
        panelLoader.item.hostWidget = root
    }

    function tooltipText() { return _tooltipText() }
    function fractionOf(evt) { return _fractionOf(evt) }
    function countOf(evt) { return _countOf(evt) }
    function monthDayName(evt) { return _monthDayName(evt) }
}