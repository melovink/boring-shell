import QtQuick

// Desktop meters and the image share a control; GitHub keeps its separate toggle.
Rectangle {
    id: root

    property color nord1
    property real surfaceOpacity: 0.8
    property bool monitorEnabled: true

    signal toggled()

    width: 40
    height: 28
    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: Qt.alpha(nord1, surfaceOpacity)

    SvgIcon {
        anchors.centerIn: parent
        width: 16
        height: 16
        iconColor: root.monitorEnabled ? "#FFFFFF" : "#FF0000"
        path: "M3 3h18v14H3z M8 21h8 M12 17v4 M5 10h3l2-4 4 8 2-4h3"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
