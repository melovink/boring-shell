import QtQuick

// Do-not-disturb toggle. While muted, incoming notifications are dropped
// instead of being shown as the bar card.
Rectangle {
    id: notifMute
    property color nord1
    property color nord6
    property color nord11
    property bool muted: false
    property real surfaceOpacity: 0.8

    readonly property bool hovered: muteMouse.containsMouse

    signal toggled()

    width: 40; height: 28; color: Qt.alpha(nord1, surfaceOpacity); radius: 12; anchors.verticalCenter: parent.verticalCenter

    SvgIcon {
        anchors.centerIn: parent; width: 16; height: 16
        iconColor: notifMute.muted ? notifMute.nord11 : notifMute.nord6
        path: notifMute.muted
            ? "M13.73 21a2 2 0 0 1-3.46 0 M18.63 13A17.89 17.89 0 0 1 18 8 M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h14 M18 8a6 6 0 0 0-9.33-5 M3 3l18 18"
            : "M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9 M13.73 21a2 2 0 0 1-3.46 0"
    }

    MouseArea {
        id: muteMouse
        anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: notifMute.toggled()
    }
}
