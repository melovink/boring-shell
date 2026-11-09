import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property color nord1
    property color nord6
    property string fontPrimary
    property string batteryText
    property string batteryStatus
    property real surfaceOpacity: 0.8
    property AnimatedPopup pwrPopup
    property var otherPopups: []

    readonly property bool hovered: batMouse.containsMouse
    readonly property real batteryPercentage: parseInt(batteryText, 10)
    readonly property real fillRatio: isNaN(batteryPercentage) ? 0
        : Math.max(0, Math.min(1, batteryPercentage / 100))
    readonly property color batteryTint: isNaN(batteryPercentage) ? "#7787A6"
        : batteryPercentage >= 40 ? "#A3BE8C"
        : batteryPercentage >= 20 ? "#D08770" : "#BF616A"

    width: implicitWidth
    height: 22
    implicitWidth: 46
    implicitHeight: 22
    anchors.verticalCenter: parent.verticalCenter

    GlassSurface {
        anchors.fill: parent
        radius: height / 2
        shadowEnabled: false
        fillStart: Qt.alpha(root.nord1, 0.45)
        fillEnd: Qt.alpha("#7787A6", 0.28)
        rimTint: root.nord6
        lightIntensity: 80
        refraction: 80
        dispersion: 50
        depth: 20
        splay: 0
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: height / 2
        color: "transparent"

        Rectangle {
            width: parent.width * root.fillRatio
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.alpha(root.batteryTint, root.surfaceOpacity) }
                GradientStop { position: 1; color: Qt.alpha(root.batteryTint, root.surfaceOpacity * 0.68) }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: "#24FFFFFF" }
            GradientStop { position: 0.45; color: "#00FFFFFF" }
            GradientStop { position: 1; color: "#0EAFC6E8" }
        }
        border.width: 1
        border.color: Qt.alpha(root.nord6, 0.20)
    }

    Text {
        anchors.centerIn: parent
        text: root.batteryText
        color: root.nord6
        font.family: root.fontPrimary
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            root.pwrPopup.visible = !root.pwrPopup.visible;
            for (var i = 0; i < root.otherPopups.length; i++) root.otherPopups[i].visible = false;
        }
        cursorShape: Qt.PointingHandCursor
    }
}
