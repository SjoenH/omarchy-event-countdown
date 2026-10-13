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
    // True while the editors are being loaded from the widget. Loading the
    // name fires the name field's onTextChanged before the date editors have
    // been loaded, so without this the stale date would be applied to the
    // event that was just read.
    property bool syncing: false
    readonly property color foreground: root.barForeground
    readonly property color dim: Qt.darker(root.foreground, 1.55)
    readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    // The event as the editors currently describe it, so the card previews
    // an edit before it is saved. Null while there is no event.
    readonly property var previewEvent: root.workEvent === null ? null : ({
        "name": root.edName,
        "month": root.edMonth,
        "day": root.edDay,
        "year": root.edYear,
        "repeats": root.edRepeats
    })
    // The moment the card counts from, refreshed whenever the panel opens.
    // Without it the card would keep the count from the day it was first shown.
    property double nowMs: Date.now()
    readonly property var previewCount: root.previewEvent && root.hostWidget ? root.hostWidget.countOf(root.previewEvent, new Date(root.nowMs), root.edPrecision, root.edMode) : null
    readonly property bool hasEvent: root.previewCount !== null

    // === 9. FUNCTIONS ===
    function modeW() {
        return root.hostWidget ? (root.hostWidget.mode || "both") : "both";
    }

    function precisionW() {
        return root.hostWidget ? (root.hostWidget.precision || "units") : "units";
    }

    function syncFromWidget() {
        root.syncing = true;
        root.edMode = root.modeW();
        root.edPrecision = root.precisionW();
        root.workEvent = root.copyEvent(root.currentW());
        root.loadEvent();
        root.syncing = false;
    }

    // The editors work on their own copy: the widget's event only changes
    // through persist(), never by editing the object it is displaying.
    function copyEvent(e) {
        if (!e)
            return null;

        return {
            "id": e.id,
            "name": e.name,
            "month": e.month,
            "day": e.day,
            "year": e.year,
            "repeats": e.repeats
        };
    }

    function isDirty() {
        var e = root.workEvent;
        if (!e)
            return false;

        var cur = root.currentW();
        if (!cur)
            return true;

        return e.name !== cur.name || e.month !== cur.month || e.day !== cur.day || e.year !== cur.year || e.repeats !== cur.repeats;
    }

    // Last valid day of the month being edited. A recurring event has no
    // year, so February allows the 29th.
    function maxDay() {
        if (root.hostWidget)
            return root.hostWidget.daysInMonth(root.edRepeats ? 2000 : root.edYear, root.edMonth);

        return 31;
    }

    function clampDay() {
        if (root.edDay > root.maxDay())
            root.edDay = root.maxDay();

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
            root.syncing = true;
            root.workEvent = e;
            root.loadEvent();
            root.syncing = false;
        }
    }

    function open() {
        root.nowMs = Date.now();
        root.syncFromWidget();
        root.controller.show();
    }

    function close() {
        root.applyEditors();
        // Only write when something was actually edited; closing an untouched
        // panel must leave shell.json alone.
        if (root.canCommit() && root.isDirty())
            root.commit();

        root.controller.hide();
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction);

        return false;
    }

    // The occurrence being counted, as a local date.
    function countedDate() {
        if (!root.previewCount)
            return null;

        var d = new Date(root.previewCount.anchor * 8.64e+07);
        return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    }

    // The arched line over the title: the day being counted to or from.
    function captionText() {
        var date = root.countedDate();
        if (!date)
            return "Nothing to count down to yet";

        return Qt.locale().toString(date, date.getFullYear() === new Date(root.nowMs).getFullYear() ? "dddd, MMMM d" : "dddd, MMMM d, yyyy");
    }

    function cardName() {
        if (root.edName.trim() !== "")
            return root.edName;

        return root.hostWidget ? root.hostWidget.monthDayName(root.previewEvent) : "";
    }

    function cardDetail() {
        var date = root.hostWidget.monthDayName(root.previewEvent);
        return root.edRepeats ? date + " \u00b7 every year" : date + ", " + root.edYear + " \u00b7 one-off";
    }

    function cardValue() {
        return root.previewCount.days === 0 ? "Today" : String(root.previewCount.days);
    }

    function cardUnit() {
        if (root.previewCount.days === 0)
            return "";

        return root.previewCount.days === 1 ? "day" : "days";
    }

    function cardNote() {
        if (root.previewCount.days === 0)
            return "";

        return root.previewCount.upcoming ? "to go" : "ago";
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
        contentWidth: panel.fittedContentWidth(Style.space(340))
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

                PanelTitle {
                    width: parent.width
                    caption: root.captionText()
                    leftWord: "Event"
                    rightWord: "Countdown"
                    foreground: root.foreground
                    fontFamily: root.fontFamily

                    // A calendar page showing the day being counted.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        radius: Math.min(Style.cornerRadius, Style.space(5))
                        color: "transparent"
                        border.width: Math.max(1, Style.space(2))
                        border.color: root.foreground

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: Math.round(parent.height * 0.3)
                            radius: parent.radius
                            color: root.foreground
                        }

                        Text {
                            objectName: "titleDay"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Style.space(2)
                            textFormat: Text.PlainText
                            text: root.countedDate() ? root.countedDate().getDate() : "\u2013"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.weight: Font.DemiBold
                        }

                    }

                }

                StatCard {
                    objectName: "eventCard"
                    width: parent.width
                    visible: root.hasEvent
                    name: root.hasEvent ? root.cardName() : ""
                    detail: root.hasEvent ? root.cardDetail() : ""
                    value: root.hasEvent ? root.cardValue() : ""
                    unit: root.hasEvent ? root.cardUnit() : ""
                    note: root.hasEvent ? root.cardNote() : ""
                    progress: root.hasEvent ? root.previewCount.progress : -1
                    markerColor: Color.accent
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                }

                ActionButton {
                    objectName: "addEventButton"
                    width: parent.width
                    visible: root.workEvent === null
                    text: "+  Add an event"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onClicked: root.addEvent()
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
                            textFormat: Text.PlainText
                            text: "Name"
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        TextField {
                            objectName: "nameField"
                            width: parent.width
                            text: root.edName
                            placeholderText: "Birthday, Anniversary\u2026"
                            foreground: root.foreground
                            accent: Color.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            Accessible.name: "Event name"
                            onTextChanged: {
                                if (root.syncing)
                                    return;

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
                                textFormat: Text.PlainText
                                text: "Month"
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            Dropdown {
                                objectName: "monthField"
                                width: parent.width
                                showLabel: false
                                value: String(root.edMonth)
                                options: root.monthOptions()
                                foreground: root.foreground
                                accent: Color.accent
                                fontFamily: root.fontFamily
                                onChanged: function(v) {
                                    root.edMonth = parseInt(v, 10);
                                    root.clampDay();
                                    root.applyChange();
                                }
                            }

                        }

                        Column {
                            width: !root.edRepeats ? (parent.width - Style.space(16)) / 3 : (parent.width - Style.space(8)) / 2
                            spacing: Style.space(2)

                            Text {
                                textFormat: Text.PlainText
                                text: "Day"
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            NumberField {
                                objectName: "dayField"
                                width: parent.width
                                fieldWidth: parent.width
                                value: root.edDay
                                from: 1
                                to: root.maxDay()
                                stepSize: 1
                                foreground: root.foreground
                                accent: Color.accent
                                fontFamily: root.fontFamily
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
                                textFormat: Text.PlainText
                                text: "Year"
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            NumberField {
                                objectName: "yearField"
                                width: parent.width
                                fieldWidth: parent.width
                                value: root.edYear
                                from: 1
                                to: 9999
                                stepSize: 1
                                foreground: root.foreground
                                accent: Color.accent
                                fontFamily: root.fontFamily
                                // Plain digits: the kit SpinBox formats through the
                                // locale, which turns a year into "2,026".
                                Component.onCompleted: field.textFromValue = function(value, locale) {
                                    return String(value);
                                }
                                onModified: function(v) {
                                    root.edYear = v;
                                    root.clampDay();
                                    root.applyChange();
                                }
                            }

                        }

                    }

                    Toggle {
                        objectName: "recurringToggle"
                        width: parent.width
                        label: "Every year"
                        description: root.edRepeats ? "Birthdays, anniversaries, holidays" : "A single date, with a year"
                        checked: root.edRepeats
                        foreground: root.foreground
                        accent: Color.accent
                        fontFamily: root.fontFamily
                        onClicked: {
                            root.edRepeats = !root.edRepeats;
                            if (!root.edRepeats && root.edYear < 1) {
                                var t = new Date();
                                root.edYear = t.getFullYear();
                            }
                            root.clampDay();
                            root.applyChange();
                        }
                    }

                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: root.workEvent !== null

                    Text {
                        textFormat: Text.PlainText
                        text: "Count direction"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    ExplainDropdown {
                        objectName: "modeField"
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
                        foreground: root.foreground
                        accent: Color.accent
                        fontFamily: root.fontFamily
                        onChanged: function(mode) {
                            root.switchMode(mode);
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: "Bar format"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    ExplainDropdown {
                        objectName: "formatField"
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
                        foreground: root.foreground
                        accent: Color.accent
                        fontFamily: root.fontFamily
                        onChanged: function(precision) {
                            root.switchPrecision(precision);
                        }
                    }

                }

            }

        }

    }

}
