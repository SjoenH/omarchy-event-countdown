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
    property var workEvent: null
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

    function syncFromWidget() {
        root.edMode = root.modeW();
        root.edPrecision = root.precisionW();
        root.workEvent = root.currentW();
        root.loadEvent();
    }

    function currentW() {
        if (!root.hostWidget || !root.hostWidget.events || root.hostWidget.events.length === 0)
            return null;

        return root.hostWidget.events[0];
    }

    function loadEvent() {
        var e = root.workEvent;
        root.edName = e ? e.name : "";
        root.edMonth = e ? e.month : 1;
        root.edDay = e ? e.day : 1;
        root.edYear = e ? e.year : 0;
        root.edRepeats = e ? e.repeats : true;
    }

    function applyEditors() {
        var e = root.workEvent;
        if (!e)
            return ;

        if (root.edName !== e.name)
            e.name = root.edName;
        if (root.edMonth !== e.month)
            e.month = root.edMonth;
        if (root.edDay !== e.day)
            e.day = root.edDay;
        if (root.edYear !== e.year)
            e.year = root.edYear;
        if (root.edRepeats !== e.repeats)
            e.repeats = root.edRepeats;
    }

    // Every editor change applies and persists right away; there is no
    // Save step. A blank name is the "no event" state and clears the
    // slot, so removal is just emptying the name field.
    function applyChange() {
        var e = root.workEvent;
        if (!e)
            return ;

        root.applyEditors();
        if (e.name.trim() === "") {
            if (root.hostWidget)
                root.hostWidget.persist({
                    "events": []
                });
            return ;
        }

        if (root.canCommit())
            root.commit();
    }

    function canCommit() {
        var e = root.workEvent;
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

        root.applyEditors();
        if (!root.canCommit())
            return ;

        root.hostWidget.persist({
            "events": [root.workEvent]
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
            root.workEvent = e;
            root.loadEvent();
        }
    }

    function open() {
        root.syncFromWidget();
        root.controller.show();
    }

    function close() {
        root.applyEditors();
        if (root.canCommit())
            root.commit();

        root.controller.hide();
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction);

        return false;
    }

    function monthOptions() {
        var loc = Qt.locale();
        var out = [];
        for (var m = 1; m <= 12; m++)
            out.push({
                "value": String(m),
                "label": loc.monthName(m - 1, Locale.LongFormat)
            });
        return out;
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

                // --- Single event editor ---
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.workEvent === null

                    Text {
                        width: parent.width
                        text: "No event yet"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    Button {
                        width: parent.width
                        text: "Add event"
                        focusable: true
                        foreground: root.barForeground
                        accent: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        fontSize: Style.font.body
                        onClicked: root.addEvent()
                    }

                }

                // --- Edit form ---
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.workEvent !== null

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
                                // Keystrokes stay in preview; the name flushes
                                // on close or with the next discrete change.
                                // Clearing the name clears the event now.
                                if (text.trim() === "")
                                    root.applyChange();
                                else
                                    root.applyEditors();
                            }
                            onAccepted: root.close()
                            Keys.onEscapePressed: root.close()
                        }

                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Column {
                            width: !root.edRepeats ? (parent.width - Style.space(16)) / 3 : (parent.width - Style.space(8)) / 2
                            spacing: Style.space(2)

                            Text {
                                text: "Month"
                                color: Qt.darker(root.barForeground, 1.4)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            Dropdown {
                                width: parent.width
                                showLabel: false
                                value: String(root.edMonth)
                                options: root.monthOptions()
                                foreground: root.barForeground
                                accent: Color.accent
                                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                onChanged: function(v) {
                                    root.edMonth = parseInt(v, 10);
                                    root.applyChange();
                                }
                            }

                        }

                        Column {
                            width: !root.edRepeats ? (parent.width - Style.space(16)) / 3 : (parent.width - Style.space(8)) / 2
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
                                    root.applyChange();
                                }
                            }

                        }

                        Column {
                            width: (parent.width - Style.space(16)) / 3
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
                                // Plain digits: the kit SpinBox formats through the
                                // locale, which turns a year into "2,026".
                                Component.onCompleted: field.textFromValue = function(value, locale) {
                                    return String(value);
                                }
                                onModified: function(v) {
                                    root.edYear = v;
                                    root.applyChange();
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
                            if (!root.edRepeats && root.edYear < 1) {
                                var t = new Date();
                                root.edYear = t.getFullYear();
                            }
                            root.applyChange();
                        }
                    }

                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: root.workEvent !== null

                    Text {
                        text: "Count direction"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    ExplainDropdown {
                        width: parent.width
                        options: [{
                            "value": "countdown",
                            "label": "Count down",
                            "description": "until it happens",
                            "explanation": "Counts down the time remaining until the next occurrence of the event."
                        }, {
                            "value": "countup",
                            "label": "Count up",
                            "description": "since it happened",
                            "explanation": "Counts up the time elapsed since the last occurrence, for past events."
                        }, {
                            "value": "both",
                            "label": "Both",
                            "description": "either way",
                            "explanation": "Counts down when the event is upcoming, and up once it has passed."
                        }]
                        value: root.edMode
                        foreground: root.barForeground
                        accent: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onChanged: function(mode) {
                            root.switchMode(mode);
                        }
                    }

                    Text {
                        text: "Format"
                        color: Qt.darker(root.barForeground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    ExplainDropdown {
                        width: parent.width
                        options: [{
                            "value": "days",
                            "label": "Exact days",
                            "description": "e.g. 34d",
                            "explanation": "Always counts in whole days (e.g. 34d)."
                        }, {
                            "value": "units",
                            "label": "Fuzzy units",
                            "description": "e.g. 3mo",
                            "explanation": "Rounds to days, weeks, months, or years (e.g. 3mo) for easier reading."
                        }, {
                            "value": "date",
                            "label": "Show date",
                            "description": "e.g. Jan 1",
                            "explanation": "Shows the event's date itself (e.g. Jan 1) instead of a count."
                        }]
                        value: root.edPrecision
                        foreground: root.barForeground
                        accent: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onChanged: function(precision) {
                            root.switchPrecision(precision);
                        }
                    }

                }

            }

        }

    }

}