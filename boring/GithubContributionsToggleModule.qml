import QtQuick

// Toggles the desktop GitHub contribution grid.
Rectangle {
    id: githubToggle

    property color nord1
    property bool contributionsEnabled: true
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
        iconColor: githubToggle.contributionsEnabled ? "#FFFFFF" : "#FF0000"
        path: "M9 19c-4.3 1.3-4.3-2.5-6-3 M15 22v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 19 4.77 5.07 5.07 0 0 0 18.91 1S17.73.65 15 2.48a13.38 13.38 0 0 0-7 0C5.27.65 4.09 1 4.09 1A5.07 5.07 0 0 0 4 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 8 18.13V22"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: githubToggle.toggled()
    }
}
