import QtQuick

// Toggle for the full-screen floating clock layer.
Rectangle {
    id: clockToggle

    property color nord1
    property color nord6
    property color nord8
    property bool clockEnabled: true
    property real surfaceOpacity: 0.8

    signal toggled()

    width: 40
    height: 28
    color: Qt.alpha(nord1, surfaceOpacity)
    radius: 12
    anchors.verticalCenter: parent.verticalCenter

    SvgIcon {
        anchors.centerIn: parent
        width: 16
        height: 16
        iconColor: clockToggle.clockEnabled ? clockToggle.nord8 : clockToggle.nord6
        path: clockToggle.clockEnabled
            ? "M12 8v4l3 3 M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0"
            : "M12 8v4l2 2 M22 12a10 10 0 0 1-2.93 7.07 M16.24 5.76A9.97 9.97 0 0 0 12 2a10 10 0 1 0 10 10 M3 3l18 18"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: clockToggle.toggled()
    }
}
