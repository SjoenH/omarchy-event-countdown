import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    // === 2. SIGNALS ===
    // === 7. STATES & TRANSITIONS ===
    // === 8. SIGNAL HANDLERS ===

    // === 1. METADATA ===
    id: root

    // === 3. PROPERTIES ===
    // 3a. State properties
    property QtObject anchorItem: null
    property QtObject hostWidget: null
    property int selIndex: -1
    property var workEvents: []
    property string edMode: "both"
    property string edPrecision: "units"
    property string edName: ""
    property int edMonth: 1
    property int edDay: 1
    property int edYear: 0
    property bool edRepeats: true

    // === 9. FUNCTIONS ===
    function modeW() {
        return root.hostWidget ? (root.hostWidget.mode || "both") : "both";
    }

    function precisionW() {
        return root.hostWidget ? (root.hostWidget.precision || "units") : "units";
    }

    function eventsW() {
        return root.hostWidget ? (root.hostWidget.events || []) : [];
    }

    function syncFromWidget() {
        root.workEvents = root.deepCopyEvents(root.eventsW());
        root.edMode = root.modeW();
        root.edPrecision = root.precisionW();
        if (root.selIndex >= root.workEvents.length)
            root.selIndex = -1;

        if (root.selIndex < 0 && root.workEvents.length > 0)
            root.selIndex = 0;

        root.loadSelection();
    }

    function deepCopyEvents(arr) {
        var out = [];
        for (var i = 0; i < arr.length; i++) {
            var e = arr[i];
            out.push({
                "id": e.id,
                "name": e.name,
                "month": e.month,
                "day": e.day,
                "year": e.year,
                "repeats": e.repeats
            });
        }
        return out;
    }

    function current() {
        if (root.selIndex < 0 || root.selIndex >= root.workEvents.length)
            return null;

        return root.workEvents[root.selIndex];
    }

    function loadSelection() {
        var e = root.current();
        root.edName = e ? e.name : "";
        root.edMonth = e ? e.month : 1;
        root.edDay = e ? e.day : 1;
        root.edYear = e ? e.year : 0;
        root.edRepeats = e ? e.repeats : true;
    }

    function applySelection() {
        var e = root.current();
        if (!e)
            return ;

        if (root.edName !== e.name) {
            e.name = root.edName;
            root.dirty();
        }
        if (root.edMonth !== e.month) {
            e.month = root.edMonth;
            root.dirty();
        }
        if (root.edDay !== e.day) {
            e.day = root.edDay;
            root.dirty();
        }
        if (root.edYear !== e.year) {
            e.year = root.edYear;
            root.dirty();
        }
        if (root.edRepeats !== e.repeats) {
            e.repeats = root.edRepeats;
            root.dirty();
        }
    }

    function dirty() {
        if (root.hostWidget)
            root.hostWidget.previewEvents(root.workEvents);

    }

    function canCommit() {
        var e = root.current();
        if (!e)
            return false;

        if (e.name.trim() === "")
            return false;

        if (e.month < 1 || e.month > 12)
            return false;

        if (e.day < 1 || e.day > 31)
            return false;

        if (!e.repeats && (e.year < 1 || e.year > 9999))
            return false;

        return true;
    }

    function commit() {
        if (!root.hostWidget)
            return ;

        root.applySelection();
        if (!root.canCommit())
            return ;

        root.hostWidget.persist({
            "events": root.workEvents
        });
    }

function switchMode(mode) {
        if (mode === root.edMode)
            return;

        root.edMode = mode;
        if (root.hostWidget)
            root.hostWidget.persist({
                "mode": mode
            });

    }

    function switchPrecision(precision) {
        if (precision === root.edPrecision)
            return;

        root.edPrecision = precision;
        if (root.hostWidget)
            root.hostWidget.persist({
                "precision": precision
            });

    }

    function addEvent() {
        if (root.hostWidget) {
            var e = root.hostWidget.emptyEvent();
            e.id = root.hostWidget.newId();
            var next = root.workEvents.slice();
            next.push(e);
            root.workEvents = next;
            root.selIndex = root.workEvents.length - 1;
            root.loadSelection();
            root.dirty();
        }
    }

    function removeSelected() {
        if (root.selIndex < 0 || root.selIndex >= root.workEvents.length)
            return ;

        var next = root.workEvents.slice();
        next.splice(root.selIndex, 1);
        root.workEvents = next;
        if (root.workEvents.length === 0)
            root.selIndex = -1;
        else if (root.selIndex >= root.workEvents.length)
            root.selIndex = root.workEvents.length - 1;
        root.loadSelection();
        root.dirty();
    }

    function open() {
        root.syncFromWidget();
        root.controller.show();
    }

    function close() {
        root.applySelection();
        if (root.canCommit())
            root.commit();

        root.controller.hide();
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction);

        return false;
    }

    function fracOf(e) {
        return root.hostWidget ? root.hostWidget.fractionOf(e) : 0;
    }

    function countOf(e) {
        return root.hostWidget ? root.hostWidget.countOf(e) : {
            "text": "",
            "upcoming": true
        };
    }

    function nameOf(e) {
        return root.hostWidget ? root.hostWidget.monthDayName(e) : "";
    }

    function barBg() {
        return root.bar ? root.bar.background : Color.background;
    }

    objectName: "eventCountdownPanel"
    moduleName: "no.koka.event-countdown"
    manageIpc: false
    // === 5. ATTACHED OBJECTS & BEHAVIORS ===
    Accessible.role: Accessible.Dialog
    Accessible.name: "Event Countdown Configuration"

    // === 6. CHILD OBJECTS ===
    KeyboardPanel {
        id: panel

        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(300))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher

            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                root.switchPanel(direction);
            }

            Column {
                id: content

                width: parent.width
                spacing: Style.space(12)
                padding: Style.space(4)

                Text {
                    width: parent.width
                    text: "Event Countdown"
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                        text: "Mode"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    ButtonGroup {
                        width: parent.width
                        options: [{
                            "value": "countdown",
                            "label": "Count down"
                        }, {
                            "value": "countup",
                            "label": "Count up"
                        }, {
                            "value": "both",
                            "label": "Both"
                        }]
                        value: root.edMode
                        foreground: root.barForeground
                        background: Color.background
                        accent: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        fontSize: Style.font.caption
                        onChanged: function(mode) {
                            root.switchMode(mode);
                        }
                    }

                    Text {
                        text: "Precision"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    ButtonGroup {
                        width: parent.width
                        options: [{
                            "value": "days",
                            "label": "Exact days"
                        }, {
                            "value": "units",
                            "label": "Fuzzy units"
                        }, {
                            "value": "date",
                            "label": "Show date"
                        }]
                        value: root.edPrecision
                        foreground: root.barForeground
                        background: Color.background
                        accent: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        fontSize: Style.font.caption
                        onChanged: function(precision) {
                            root.switchPrecision(precision);
                        }
                    }

                }

                // --- Events list ---
                Column {
                    width: parent.width
                    spacing: Style.space(4)

                    Text {
                        text: root.workEvents.length === 0 ? "No events yet" : "Events"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    Flickable {
                        width: parent.width
                        height: Math.min(root.workEvents.length, 5) * (Style.space(34)) + 4
                        contentHeight: listCol.implicitHeight
                        clip: true
                        interactive: root.workEvents.length > 5

                        Column {
                            id: listCol

                            width: parent.width
                            spacing: Style.space(6)

                            Repeater {
                                model: root.workEvents

                                BorderSurface {
                                    property bool selected: index === root.selIndex

                                    width: parent.width
                                    implicitHeight: Style.space(34)
                                    radius: Style.cornerRadius
                                    color: selected ? Qt.lighter(root.barBg(), 1.5) : root.barBg()

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Event item"
                                        onClicked: {
                                            root.applySelection();
                                            root.selIndex = index;
                                            root.loadSelection();
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: Style.space(8)
                                            anchors.rightMargin: Style.space(8)
                                            spacing: Style.space(8)

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - barRow.width - Style.space(16)
                                                spacing: Style.space(2)

                                                Text {
                                                    width: parent.width
                                                    elide: Text.ElideRight
                                                    text: modelData.name !== "" ? modelData.name : root.nameOf(modelData)
                                                    color: root.barForeground
                                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                    font.pixelSize: Style.font.body
                                                }

                                                Rectangle {
                                                    width: parent.width
                                                    height: 6
                                                    radius: 3
                                                    color: Qt.darker(root.barBg(), 1.3)

                                                    Rectangle {
                                                        width: parent.width * root.fracOf(modelData)
                                                        height: parent.height
                                                        radius: 3
                                                        color: selected ? Color.accent : root.barForeground
                                                    }

                                                }

                                            }

                                            Row {
                                                id: barRow

                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Style.space(6)

                                                Text {
                                                    text: root.countOf(modelData).text
                                                    color: Qt.darker(root.barForeground, 1.3)
                                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                    font.pixelSize: Style.font.caption
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 7
                                                    height: 7
                                                    radius: 4
                                                    color: root.countOf(modelData).upcoming ? Color.accent : Qt.lighter(Color.background, 1.3)
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // --- Edit form ---
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.current() !== null

                    Text {
                        text: "Edit event"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    Column {
                        width: parent.width
                        spacing: Style.space(2)

                        Text {
                            text: "Name"
                            color: Qt.darker(root.barForeground, 1.4)
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                        }

                        TextField {
                            width: parent.width
                            text: root.edName
                            placeholderText: "Birthday, Anniversary…"
                            foreground: root.barForeground
                            accent: Color.accent
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.body
                            onTextChanged: {
                                root.edName = text;
                                root.applySelection();
                            }
                            onAccepted: root.close()
                            Keys.onEscapePressed: root.close()
                        }

                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Column {
                            width: parent.width / 3
                            spacing: Style.space(2)

                            Text {
                                text: "Month"
                                color: Qt.darker(root.barForeground, 1.4)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            NumberField {
                                width: parent.width
                                fieldWidth: parent.width
                                value: root.edMonth
                                from: 1
                                to: 12
                                stepSize: 1
                                foreground: root.barForeground
                                accent: Color.accent
                                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                onModified: function(v) {
                                    root.edMonth = v;
                                    root.applySelection();
                                }
                            }

                        }

                        Column {
                            width: parent.width / 3
                            spacing: Style.space(2)

                            Text {
                                text: "Day"
                                color: Qt.darker(root.barForeground, 1.4)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            NumberField {
                                width: parent.width
                                fieldWidth: parent.width
                                value: root.edDay
                                from: 1
                                to: 31
                                stepSize: 1
                                foreground: root.barForeground
                                accent: Color.accent
                                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                onModified: function(v) {
                                    root.edDay = v;
                                    root.applySelection();
                                }
                            }

                        }

                        Column {
                            width: parent.width / 3
                            spacing: Style.space(2)
                            visible: !root.edRepeats

                            Text {
                                text: "Year"
                                color: Qt.darker(root.barForeground, 1.4)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            NumberField {
                                width: parent.width
                                fieldWidth: parent.width
                                value: root.edYear
                                from: 1
                                to: 9999
                                stepSize: 1
                                foreground: root.barForeground
                                accent: Color.accent
                                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                onModified: function(v) {
                                    root.edYear = v;
                                    root.applySelection();
                                }
                            }

                        }

                    }

                    Toggle {
                        width: parent.width
                        label: "Recurring event"
                        checked: root.edRepeats
                        foreground: root.barForeground
                        accent: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onClicked: {
                            root.edRepeats = !root.edRepeats;
                            root.applySelection();
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Button {
                            width: (parent.width - Style.space(16)) / 3
                            text: "Save"
                            focusable: true
                            foreground: root.barForeground
                            accent: Color.accent
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            fontSize: Style.font.body
                            enabled: root.canCommit()
                            onClicked: root.commit()
                        }

                        Button {
                            width: (parent.width - Style.space(16)) / 3
                            text: "Delete"
                            focusable: true
                            foreground: root.bar.urgent
                            accent: Color.accent
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            fontSize: Style.font.body
                            onClicked: root.removeSelected()
                        }

                        Button {
                            width: (parent.width - Style.space(16)) / 3
                            text: "Add"
                            focusable: true
                            foreground: root.barForeground
                            accent: Color.accent
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            fontSize: Style.font.body
                            onClicked: root.addEvent()
                        }

                    }

                }

                // --- Add-only row ---
                Button {
                    width: parent.width
                    visible: root.current() === null
                    text: "Add event"
                    focusable: true
                    foreground: root.barForeground
                    accent: Color.accent
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    fontSize: Style.font.body
                    onClicked: root.addEvent()
                }

            }

        }

    }

}
