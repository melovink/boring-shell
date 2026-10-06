import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string batteryText
    property string batteryStatus
    property PopupWindow pwrPopup
    property var otherPopups: []
    readonly property bool hovered: batMouse.containsMouse

    width: batMouse.containsMouse ? 140 : 40; height: 28; color: nord1; radius: 12; anchors.verticalCenter: parent.verticalCenter
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Row {
        anchors.centerIn: parent; spacing: 8
        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; iconColor: nord6
            path: "M6 8h10a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M18 11h2v2h-2z M8 10h6v4H8z"
            fill: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batteryText + (batteryStatus === "Charging" ? " (Charging)" : batteryStatus === "Discharging" ? " (Unplugged)" : batteryStatus === "Full" ? " (Full)" : "")
            color: nord6; font.family: fontPrimary; font.pixelSize: 12
            visible: batMouse.containsMouse
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
