import QtQuick
import Quickshell.Io

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string mpdText
    property bool playing: false
    property Process toggleProcess

    width: Math.max(60, mpdTextItem.implicitWidth + 24); height: 28; color: nord1; radius: 12; anchors.verticalCenter: parent.verticalCenter
    // Dimmed while paused/stopped so the click result is visible at a glance.
    Text { id: mpdTextItem; anchors.centerIn: parent; text: mpdText; color: nord6; opacity: playing ? 1.0 : 0.55; font.family: fontPrimary; font.pixelSize: 12 }
    MouseArea { anchors.fill: parent; onClicked: toggleProcess.running = true; cursorShape: Qt.PointingHandCursor }
}
