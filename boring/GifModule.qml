import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: rootItem
    property color nord1
    property color nord6
    property real surfaceOpacity: 0.8
    signal toggled()
    
    // Configurable GIF path
    property string gifPath: "file:///home/melovink/gifs/ellen.gif" // User can change this

    width: 40
    height: 28
    color: Qt.alpha(nord1, surfaceOpacity)
    radius: 12
    anchors.verticalCenter: parent.verticalCenter

    property bool isActive: false

    SvgIcon {
        anchors.centerIn: parent
        width: 16
        height: 16
        iconColor: rootItem.isActive ? "#FFFFFF" : "#FF0000"
        path: "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z M2 9h20 M2 15h20 M8 4v5 M16 4v5 M8 15v5 M16 15v5"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rootItem.toggled()
    }

    // anchoring to botleft
    PanelWindow {
        id: gifWindow
        visible: rootItem.isActive
        anchors { bottom: true; left: true; }
        exclusiveZone: -1

        width: 300
        height: 300
        color: "transparent"
        
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {}
        
        AnimatedImage {
            anchors.fill: parent
            // Don't keep decoded frames around after the overlay is toggled off.
            source: rootItem.isActive ? rootItem.gifPath : ""
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(300, 300)
            cache: false
            playing: rootItem.isActive
        }
    }
}
