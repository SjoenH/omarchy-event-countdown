import QtQuick
import qs.Commons
import qs.Ui
import "DateGrid.js" as DateGrid

// Month-grid date picker for the event editor. Follows the kit clock
// panel's calendar (same grid math, weekday ordering and quiet cell
// styling) shrunk to a form control: no week-number gutter, no year rail.
//
// The selection lives in the panel (year/month/day properties are bound
// from the editor state); the view (displayed month) lives here and
// follows the selection until the user navigates with the chevrons or
// the wheel. Clicking a day emits picked(year, month, day) with month
// in 1..12 — the panel decides what to write back, so a recurring event
// can keep ignoring the year.
Item {
    id: root

    // Selected date. year 0 means "unspecified" (recurring event); the
    // view then falls back to the current year so month/day still have a
    // grid to live on.
    property int year: 0
    property int month: 1
    property int day: 1

    property color foreground: Color.foreground
    property color accent: Color.accent
    property string fontFamily: Style.font.family

    signal picked(int year, int month, int day)

    readonly property string _todayKey: {
        var t = new Date();
        return DateGrid.dateKey(t.getFullYear(), t.getMonth(), t.getDate());
    }

    // The month the grid shows.
    property int viewYear: 0
    property int viewMonth: 1

    onYearChanged: _syncView()
    onMonthChanged: _syncView()
    Component.onCompleted: _syncView()

    readonly property int weekStart: DateGrid.normalizedWeekStart(Qt.locale().firstDayOfWeek, 1)
    readonly property var weekdays: DateGrid.weekdayOrder(weekStart)
    readonly property var weeks: DateGrid.monthGrid(viewYear, viewMonth - 1, weekStart, _todayKey)

    readonly property string selectedKey: DateGrid.dateKey(year > 0 ? year : viewYear, month - 1, day)

    readonly property real cellSpacing: Style.space(2)
    readonly property real cellWidth: (width - 6 * cellSpacing) / 7
    readonly property real cellHeight: Style.space(28)

    implicitHeight: nav.height + Style.space(8) + weekHeader.height + Style.space(2) + 6 * cellHeight + 5 * cellSpacing

    function _syncView() {
        viewYear = year > 0 ? year : new Date().getFullYear();
        viewMonth = month;
    }

    function moveMonth(delta) {
        var next = DateGrid.stepMonth(viewYear, viewMonth - 1, delta);
        viewYear = Math.max(1, Math.min(9999, next.year));
        viewMonth = next.month + 1;
    }

    function moveYear(delta) {
        viewYear = Math.max(1, Math.min(9999, viewYear + delta));
    }

    // ---- Month/year navigation ----
    Item {
        id: nav
        width: parent.width
        height: Style.space(26)

        Row {
            spacing: Style.space(2)

            PanelActionButton {
                iconText: "«"
                tooltipText: "Previous year"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: root.moveYear(-1)
            }

            PanelActionButton {
                iconText: "󰅁"
                tooltipText: "Previous month"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.moveMonth(-1)
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(130)
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(new Date(root.viewYear, root.viewMonth - 1, 1), "MMMM yyyy").toUpperCase()
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.letterSpacing: 1
        }

        Row {
            anchors.right: parent.right
            spacing: Style.space(2)

            PanelActionButton {
                iconText: "󰅂"
                tooltipText: "Next month"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.moveMonth(1)
            }

            PanelActionButton {
                iconText: "»"
                tooltipText: "Next year"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: root.moveYear(1)
            }

        }

    }

    // ---- Weekday header ----
    Row {
        id: weekHeader
        y: nav.height + Style.space(8)
        spacing: root.cellSpacing

        Repeater {
            model: root.weekdays

            Text {
                required property var modelData
                width: root.cellWidth
                height: Style.space(16)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Qt.locale().dayName(modelData, Locale.ShortFormat).substring(0, 2).toUpperCase()
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
            }

        }

    }

    // ---- Day grid: six fixed rows of seven ----
    Column {
        id: grid
        anchors.horizontalCenter: parent.horizontalCenter
        y: weekHeader.y + weekHeader.height + Style.space(2)
        spacing: root.cellSpacing

        Repeater {
            model: root.weeks

            Row {
                required property var modelData
                spacing: root.cellSpacing

                Repeater {
                    model: modelData

                    Rectangle {
                        id: cell
                        required property var modelData

                        width: root.cellWidth
                        height: root.cellHeight
                        radius: Style.cornerRadius
                        readonly property bool isSelected: modelData.key === root.selectedKey
                        readonly property bool hot: hover.containsMouse

                        color: isSelected ? Style.selectedFillFor(root.foreground, root.accent)
                            : hot ? Style.hoverFillFor(root.foreground, root.accent)
                            : "transparent"
                        border.width: isSelected || modelData.today ? Style.spacing.hairline : 0
                        border.color: isSelected ? Style.selectedStateColor(root.foreground, root.accent)
                            : Style.normalBorderFor(root.foreground, root.accent)

                        Behavior on color {
                            ColorAnimation {
                                duration: 60
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.inMonth
                                ? (modelData.weekend ? Qt.darker(root.foreground, 1.45) : root.foreground)
                                : Qt.darker(root.foreground, 2.2)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: cell.isSelected || modelData.today
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(modelData.year, modelData.month + 1, modelData.day)
                        }

                    }

                }

            }

        }

    }

    WheelHandler {
        onWheel: function(event) {
            if (event.angleDelta.y === 0)
                return ;
            root.moveMonth(event.angleDelta.y > 0 ? -1 : 1);
        }
    }

}
