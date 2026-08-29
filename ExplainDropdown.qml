import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Themed single-select dropdown like qs.Ui.Dropdown. Options carry a
// short `description`, rendered next to the label in the popup row, and a
// fuller `explanation` shown in a caption below the trigger once selected.
// `options` takes an array of { value, label, description, explanation }
// objects; plain string[] or { value, label } are accepted and simply get
// empty helper text.
Item {
  id: root

  property string label: ""
  property string value: ""
  property var options: []
  property bool showExplanation: true

  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property int rowHeight: Style.spacing.controlHeight
  property int popupRowHeight: Style.spacing.popupRowHeight
  property bool showLabel: true

  // Panel-cursor flag. When true, the trigger renders the shared
  // hover-cursor state. Active Qt focus defaults to the same visuals.
  property bool hasCursor: false

  readonly property bool popupOpen: popup.opened
  function open() { popup.open() }
  function close() { popup.close() }
  function toggle() { popup.opened ? popup.close() : popup.open() }

  signal changed(string value)
  signal hovered(bool isHovered)

  function optionValue(o) {
    return (o && typeof o === "object") ? String(o.value) : String(o)
  }
  function optionLabel(o) {
    return (o && typeof o === "object") ? String(o.label) : String(o)
  }
  function optionDescription(o) {
    return (o && typeof o === "object" && o.description !== undefined) ? String(o.description) : ""
  }
  function optionExplanation(o) {
    return (o && typeof o === "object" && o.explanation !== undefined) ? String(o.explanation) : ""
  }
  function currentLabel() {
    for (var i = 0; i < options.length; i++) {
      if (optionValue(options[i]) === value) return optionLabel(options[i])
    }
    return value
  }
  function currentExplanation() {
    for (var i = 0; i < options.length; i++) {
      if (optionValue(options[i]) === value) return optionExplanation(options[i])
    }
    return ""
  }
  function optionRowHeight(o) {
    return optionDescription(o) !== "" ? 44 : root.popupRowHeight
  }
  function hasLabel() {
    return showLabel && label !== ""
  }
  readonly property real labelHeight: hasLabel() ? Style.font.caption * 1.2 + Style.spacing.labelGap : 0
  readonly property real explanationHeight: explanation.visible ? explanation.implicitHeight + Style.spacing.labelGap : 0
  implicitWidth: Style.spacing.dropdownWidth
  implicitHeight: rowHeight + labelHeight + explanationHeight

  // Height of the open popup, capped to 8 rows so it scrolls on small
  // panes rather than covering the whole screen.
  function popupHeight() {
    var total = 0
    for (var i = 0; i < options.length; i++) total += optionRowHeight(options[i]) + Style.spacing.labelGap
    total -= Style.spacing.labelGap
    total += Style.spacing.xxs
    return Math.min(total, 8 * 44 + 7 * Style.spacing.labelGap + Style.spacing.xxs)
  }

  function triggerOpen() { popup.opened ? popup.close() : popup.open() }

  Column {
    anchors.fill: parent
    spacing: Style.spacing.labelGap

    Text {
      visible: root.hasLabel()
      text: root.label
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    BorderSurface {
      id: trigger
      width: parent.width
      height: root.rowHeight
      radius: Style.cornerRadius

      readonly property bool _focused: trigger.activeFocus
      readonly property bool _hot: triggerHover.hovered || root.hasCursor
      readonly property var _borderSpec: Border.controlSpec(trigger._focused ? "focus" : (trigger._hot ? "hover-cursor" : "normal"), root.foreground, root.accent)

      color: Style.controlFill(trigger._focused, trigger._hot, root.foreground, root.accent)
      borderSpec: _borderSpec

      activeFocusOnTab: true

      HoverHandler {
        id: triggerHover
        onHoveredChanged: root.hovered(hovered)
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
          root.triggerOpen()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape && popup.opened) {
          popup.close(); event.accepted = true
        }
      }

      Text {
        anchors.left: parent.left
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
        anchors.rightMargin: trigger.borderRight + Style.spacing.md
        text: root.currentLabel()
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
        text: "󰅀"
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          trigger.forceActiveFocus()
          root.triggerOpen()
        }
      }

      Popup {
        id: popup
        x: 0
        y: trigger.height + Style.spacing.xxs
        width: trigger.width
        implicitHeight: root.popupHeight()
        padding: Style.spacing.hairline
        leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
        rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
        topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
        bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
        focus: true

        background: BorderSurface {
          color: root.background
          borderSpec: root.popupBorderSpec
          radius: Style.cornerRadius
        }

        onOpened: {
          optionList.currentIndex = Math.max(0, optionList.indexOfValue(root.value))
          optionList.forceActiveFocus()
        }

        contentItem: ListView {
          id: optionList
          spacing: Style.spacing.labelGap

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { popup.close(); event.accepted = true }
            else if (event.key === Qt.Key_Down || event.text === "j") {
              optionList.currentIndex = Math.min(root.options.length - 1, optionList.currentIndex + 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.text === "k") {
              optionList.currentIndex = Math.max(0, optionList.currentIndex - 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              optionList.selectCurrent(); event.accepted = true
            }
          }
          implicitHeight: contentHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.options
          currentIndex: -1

          function indexOfValue(v) {
            for (var i = 0; i < root.options.length; i++)
              if (root.optionValue(root.options[i]) === v) return i
            return -1
          }

          function selectCurrent() {
            if (currentIndex < 0 || currentIndex >= root.options.length) return
            var v = root.optionValue(root.options[currentIndex])
            root.value = v
            root.changed(v)
            popup.close()
          }

          delegate: BorderSurface {
            required property var modelData
            required property int index
            width: optionList.width
            height: root.optionRowHeight(modelData)
            radius: Style.cornerRadius
            readonly property bool _cur: index === optionList.currentIndex
            color: _cur ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
            borderSpec: _cur ? Border.controlSpec("hover-cursor", root.foreground, root.accent) : Border.localOrSurfaceSpec("popups", "border", "transparent", "transparent", 0)

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.rightMargin: Style.spacing.controlPaddingX
              spacing: Style.spacing.xxs

              Text {
                width: parent.width
                text: root.optionLabel(modelData)
                color: index === optionList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: index === optionList.currentIndex
                elide: Text.ElideRight
              }

              Text {
                visible: root.optionDescription(modelData) !== ""
                width: parent.width
                text: root.optionDescription(modelData)
                color: Qt.darker(index === optionList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground, 1.45)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: optionList.currentIndex = parent.index
              onClicked: optionList.selectCurrent()
            }
          }
        }
      }
    }

    // Fuller explanation of the current selection, rendered below the
    // select and kept in sync with its value.
    Text {
      id: explanation
      visible: root.showExplanation && root.currentExplanation() !== ""
      width: parent.width
      text: root.currentExplanation()
      color: Qt.darker(root.foreground, 1.45)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }
}