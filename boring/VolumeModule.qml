import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string volumeText
    property real volumeLevel: 0
    property real surfaceOpacity: 0.8
    property AnimatedPopup volPopup
    property var otherPopups: []
    readonly property bool hovered: volMouse.containsMouse

    width: volumeContent.implicitWidth + 24; height: 28; color: Qt.alpha(nord1, surfaceOpacity); radius: 12; anchors.verticalCenter: parent.verticalCenter
    Row {
        id: volumeContent
        anchors.centerIn: parent; spacing: 8
        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; iconColor: nord6
            path: "M3 14v-3a9 9 0 0 1 18 0v3 M3 13h3v8H5a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2 M21 13h-3v8h1a2 2 0 0 0 2-2v-4a2 2 0 0 0-2-2"
            opacity: volumeText === "Muted" ? 0.5 : 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(volumeLevel * 100); color: nord6; font.family: fontPrimary; font.pixelSize: 12
        }
    }
    MouseArea {
        id: volMouse
        anchors.fill: parent; hoverEnabled: true
        onClicked: {
            volPopup.visible = !volPopup.visible;
            for (var i = 0; i < otherPopups.length; i++) otherPopups[i].visible = false;
        }
        cursorShape: Qt.PointingHandCursor
    }
}
