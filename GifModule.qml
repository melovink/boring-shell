import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: rootItem
    property color nord1
    property color nord4
    property color nord6
    property color nord8
    property string fontPrimary
    property real surfaceOpacity: 0.8
    
    // Configurable GIF path
    property string gifPath: "file:///home/melovink/gifs/ellen.gif" // User can change this

    width: gifMouse.containsMouse ? 120 : 40
    height: 28
    color: Qt.alpha(nord1, surfaceOpacity)
    radius: 12
    anchors.verticalCenter: parent.verticalCenter
    
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    property bool isActive: true

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
            source: rootItem.gifPath
            fillMode: Image.PreserveAspectFit
            playing: rootItem.isActive
        }

        GradientBorder {
            anchors.fill: parent
            radius: 12
        }
    }
}
