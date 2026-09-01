import QtQuick
import Quickshell.Io

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string mpdText
    property Process mpdProcess

    width: Math.max(60, mpdTextItem.implicitWidth + 24); height: 28; color: nord1; radius: 12; anchors.verticalCenter: parent.verticalCenter
    Text { id: mpdTextItem; anchors.centerIn: parent; text: mpdText; color: nord6; font.family: fontPrimary; font.pixelSize: 12 }
    MouseArea { anchors.fill: parent; onClicked: mpdProcess.running = true; cursorShape: Qt.PointingHandCursor }
}
