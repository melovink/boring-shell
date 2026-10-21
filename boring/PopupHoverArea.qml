import QtQuick

// Wraps the contents of a PopupWindow and closes the popup once the pointer has
// been away from both the popup and the module that opened it. A short grace
// period lets the pointer cross the gap between the module and the popup, and
// `hold` keeps the popup open while a control inside it (e.g. a slider) owns
// the pointer grab and hover tracking is unreliable.
Item {
    id: hoverArea

    required property var popup
    property bool anchorHovered: false
    property bool hold: false
    property int closeDelay: 300

    readonly property bool hovered: hoverHandler.hovered

    anchors.fill: parent

    HoverHandler { id: hoverHandler }

    Timer {
        interval: hoverArea.closeDelay
        running: hoverArea.popup.visible && !hoverHandler.hovered && !hoverArea.anchorHovered && !hoverArea.hold
        onTriggered: hoverArea.popup.visible = false
    }
}
