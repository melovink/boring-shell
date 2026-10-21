import QtQuick

// Hyprland active_border equivalent:
// rgba(fff7ff00) -> rgba(e5e9f055), angle 90deg.
Item {
    id: root

    property color color: "transparent"
    property real radius: 0
    property real borderWidth: 1
    property color gradientStart: "#00fff7ff"
    property color gradientEnd: "#55e5e9f0"

    default property alias contentData: content.data

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.gradientStart }
            GradientStop { position: 1.0; color: root.gradientEnd }
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        anchors.margins: root.borderWidth
        radius: Math.max(0, root.radius - root.borderWidth)
        color: root.color
        clip: root.clip
    }
}
