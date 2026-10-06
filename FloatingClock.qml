import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: floatingClock

    // Span the full screen so we can center content freely,
    // but the window itself is input-transparent and stays behind everything.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Bottom layer → always behind regular windows
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Pass-through mask — only the text area receives input
    mask: Region {
        x: clockText.x
        y: clockText.y
        width: clockText.implicitWidth
        height: clockText.implicitHeight
    }

    // Bare text, no background, no shadow
    Text {
        id: clockText
        anchors.horizontalCenter: parent.horizontalCenter
        // Upper rule-of-thirds line: vertically centered on 1/3 from top
        y: Math.round(parent.height / 3 - height / 2)
        // "h:mm" → 12-hour, no leading zero, no AM/PM
        text: Qt.formatDateTime(new Date(), "h:mm")
        color: "#ECEFF4"        // nord6
        font.family: "Outfit"
        font.pixelSize: 108
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }

    // Tick every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "h:mm")
    }
}
