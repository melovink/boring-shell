import QtQuick

Rectangle {
    property color nord1
    property color nord6
    property string fontPrimary
    property string mpdText
    property bool playing: false
    property real surfaceOpacity: 0.8
    property AnimatedPopup mediaPopup
    property var otherPopups: []
    readonly property bool hovered: mpdMouse.containsMouse

    width: Math.max(60, mpdTextItem.implicitWidth + 24); height: 28; color: Qt.alpha(nord1, surfaceOpacity); radius: 12; anchors.verticalCenter: parent.verticalCenter
    // Dimmed while paused/stopped so the click result is visible at a glance.
    Text { id: mpdTextItem; anchors.centerIn: parent; text: mpdText; textFormat: Text.PlainText; color: nord6; opacity: playing ? 1.0 : 0.55; font.family: fontPrimary; font.pixelSize: 12 }
    MouseArea {
        id: mpdMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            mediaPopup.visible = !mediaPopup.visible;
            for (var i = 0; i < otherPopups.length; i++) otherPopups[i].visible = false;
        }
    }
}
