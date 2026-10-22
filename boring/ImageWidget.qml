pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property url imageSource: Qt.resolvedUrl("../forDisplayOnly/dracaene.jpg")
    property int sideLength: 112
    property real cornerRadius: 24
    property real borderWidth: 1
    property int edgeMargin: 12
    property int topMargin: 12
    property color nord0: "#2E3440"
    property color nord4: "#D8DEE9"
    property real surfaceOpacity: 0.78

    anchors { top: true; left: true }
    margins.left: root.edgeMargin
    margins.top: root.topMargin
    implicitWidth: root.sideLength
    implicitHeight: root.sideLength
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "boring-image-widget"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.alpha(root.nord0, root.surfaceOpacity)

        Image {
            id: photo
            anchors.fill: parent
            source: root.visible ? root.imageSource : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.sideLength * 2, root.sideLength * 2)
            asynchronous: true
            smooth: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: roundedMask
            }
        }

        Rectangle {
            id: roundedMask
            anchors.fill: photo
            radius: surface.radius
            color: "white"
            layer.enabled: true
            layer.smooth: true
            visible: false
        }

        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            color: "transparent"
            border.width: root.borderWidth
            border.color: Qt.alpha(root.nord4, 0.12)
        }
    }
}
