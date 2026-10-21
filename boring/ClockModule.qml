import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    property color nord0
    property color nord1
    property color nord4
    property color nord6
    property color nord8
    property string fontPrimary
    property string fontMono
    property PopupWindow calPopup
    property var otherPopups: []
    readonly property bool hovered: clockMouse.containsMouse

    property alias timeText: clockText.text
    width: 80; height: 28; color: "transparent"; anchors.verticalCenter: parent.verticalCenter
    Text {
        id: clockText
        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), "hh:mm")
        color: nord6
        font.family: "Outfit"
        font.pixelSize: 14
    }
    MouseArea {
        id: clockMouse
        anchors.fill: parent; hoverEnabled: true
        onClicked: {
            calPopup.visible = !calPopup.visible;
            for (var i = 0; i < otherPopups.length; i++) otherPopups[i].visible = false;
        }
        cursorShape: Qt.PointingHandCursor
    }
}
