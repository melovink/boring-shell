pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property url imageSource: Qt.resolvedUrl("../forDisplayOnly/dialyn.jpeg")
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

    BackgroundEffect.blurRegion: Region {
        item: surface
        radius: surface.radius
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.cornerRadius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: "#FF2E3440" }
            GradientStop { position: 1; color: "#737787A6" }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#40000000"
            blurMax: 8
            shadowBlur: 1.0
            shadowVerticalOffset: 4
        }

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
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: "#20FFFFFF" }
                GradientStop { position: 0.38; color: "#08FFFFFF" }
                GradientStop { position: 1; color: "#167B95C0" }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            color: "transparent"
            border.width: root.borderWidth
            border.color: Qt.alpha(root.nord4, 0.22)
        }
    }
}
