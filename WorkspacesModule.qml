import QtQuick
import Quickshell.Hyprland

Row {
    property color nord1
    property color nord4
    property color nord8

    spacing: 8
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
        model: Hyprland.workspaces
        Rectangle {
            width: 12; height: 12; radius: 6
            color: modelData.focused ? nord8 : (modelData.active ? nord4 : nord1)
            MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
            }
        }
    }
}
