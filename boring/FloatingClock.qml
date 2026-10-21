import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: floatingClock

    // Keep the layer surface limited to the clock glyph. A transparent full-screen
    // surface costs a screen-sized buffer even though it only draws this one line.
    anchors { top: true; left: true }
    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight
    margins.left: Math.round((screen.width - implicitWidth) / 2)
    margins.top: Math.round(screen.height / 3 - implicitHeight / 2)
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
        y: 0
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
