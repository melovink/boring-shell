import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string volumeText
    property PopupWindow volPopup
    property var otherPopups: []
    readonly property bool hovered: volMouse.containsMouse

    width: volMouse.containsMouse ? 80 : 40; height: 28; color: nord1; radius: 12; anchors.verticalCenter: parent.verticalCenter
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Row {
        anchors.centerIn: parent; spacing: 8
        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; iconColor: nord6
            path: volumeText === "Muted" ? "M4 9v6h4l5 4V5L8 9z M16.2 9.8l4.4 4.4 M20.6 9.8l-4.4 4.4" : "M4 9v6h4l5 4V5L8 9z M16 9.5a3 3 0 0 1 0 5 M18.5 7.5a6 6 0 0 1 0 9"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: volumeText; color: nord6; font.family: fontPrimary; font.pixelSize: 12
            visible: volMouse.containsMouse
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
