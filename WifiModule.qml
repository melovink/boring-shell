import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Rectangle {
    property color nord1
    property color nord4
    property color nord6
    property string fontPrimary
    property string wifiText
    property string networkType
    property PopupWindow netPopup
    property var otherPopups: []
    property Process scanWifiProc
    readonly property bool hovered: wifiMouse.containsMouse

    width: wifiMouse.containsMouse ? 120 : 40; height: 28; color: nord1; radius: 12; anchors.verticalCenter: parent.verticalCenter
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Row {
        anchors.centerIn: parent; spacing: 8
        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18
            path: networkType === "ethernet" ? "M5 8h14v6H5z M12 14v6 M8 20h8 M9 11h1v1h-1z M11 11h1v1h-1z M13 11h1v1h-1z M15 11h1v1h-1z" : "M4 9.5C9 4.8 15 4.8 20 9.5 M7 13c3-2.8 7-2.8 10 0 M11 16.8a1.4 1.4 0 1 0 2 0a1.4 1.4 0 1 0-2 0"
            iconColor: networkType === "none" ? nord4 : nord6
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: wifiText; color: nord6; font.family: fontPrimary; font.pixelSize: 12
            visible: wifiMouse.containsMouse; elide: Text.ElideRight; width: visible ? 70 : 0
        }
    }
    MouseArea {
        id: wifiMouse
        anchors.fill: parent; hoverEnabled: true
        onClicked: {
            netPopup.visible = !netPopup.visible;
            for (var i = 0; i < otherPopups.length; i++) otherPopups[i].visible = false;
            scanWifiProc.running = true;
        }
        cursorShape: Qt.PointingHandCursor
    }
}
