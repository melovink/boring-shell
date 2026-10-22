import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string batteryText
    property string batteryStatus
    property real surfaceOpacity: 0.8
    property AnimatedPopup pwrPopup
    property var otherPopups: []
    readonly property bool hovered: batMouse.containsMouse
    readonly property real batteryPercentage: parseInt(batteryText, 10)

    width: batteryContent.implicitWidth + 24; height: 28; color: Qt.alpha(nord1, surfaceOpacity); radius: 12; anchors.verticalCenter: parent.verticalCenter
    Row {
        id: batteryContent
        anchors.centerIn: parent; spacing: 8
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4
            color: isNaN(batteryPercentage) ? nord6
                : batteryPercentage >= 40 ? "#A3BE8C"
                : batteryPercentage >= 20 ? "#D08770" : "#BF616A"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batteryText
            color: nord6; font.family: fontPrimary; font.pixelSize: 12
        }
    }
    MouseArea {
        id: batMouse
        anchors.fill: parent; hoverEnabled: true
        onClicked: {
            pwrPopup.visible = !pwrPopup.visible;
            for (var i = 0; i < otherPopups.length; i++) otherPopups[i].visible = false;
        }
        cursorShape: Qt.PointingHandCursor
    }
}
