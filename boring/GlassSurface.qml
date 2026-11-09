pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Reusable glass plate for widgets and compact controls. Backdrop frost is
// supplied by Quickshell's Wayland BackgroundEffect region around the surface;
// the remaining values shape the directional sheen, rim and drop shadow.
Item {
    id: root

    property color fillStart: "#FF2E3440"
    property color fillEnd: "#737787A6"
    property color rimTint: "#ECEFF4"
    property real radius: 18
    property real borderWidth: 1
    property bool shadowEnabled: true
    property real lightAngle: 180
    property real lightIntensity: 80
    property real refraction: 80
    property real depth: 20
    property real dispersion: 50
    property real splay: 0

    default property alias contentData: content.data

    readonly property real reflectionAlpha: (lightIntensity / 100) * (refraction / 100) * 0.18
    readonly property string outlinePath: {
        const w = width;
        const h = height;
        const r = Math.min(radius, w / 2, h / 2);
        return `M ${r} 0 H ${w - r} A ${r} ${r} 0 0 1 ${w} ${r} V ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h} H ${r} A ${r} ${r} 0 0 1 0 ${h - r} V ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`;
    }

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: root.fillStart }
            GradientStop { position: 1; color: root.fillEnd }
        }
        border.width: root.borderWidth
        border.color: Qt.alpha(root.rimTint, 0.13 + root.dispersion / 100 * 0.10)
        layer.enabled: root.shadowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: root.shadowEnabled
            shadowColor: "#40000000"
            blurMax: 8
            shadowBlur: 1.0
            shadowVerticalOffset: 4
        }
    }

    Rectangle {
        anchors.fill: plate
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: root.lightAngle >= 180 ? 0 : 1
                color: Qt.rgba(1, 1, 1, root.reflectionAlpha * 0.72)
            }
            GradientStop {
                position: 0.42
                color: Qt.rgba(1, 1, 1, root.reflectionAlpha * 0.08)
            }
            GradientStop {
                position: root.lightAngle >= 180
                    ? 1 - root.splay / 100 * 0.12
                    : root.splay / 100 * 0.12
                color: Qt.rgba(0.58, 0.70, 0.91, root.dispersion / 100 * 0.09)
            }
        }
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            fillColor: "transparent"
            strokeWidth: Math.max(0.65, root.borderWidth * (0.8 + root.depth / 100))
            strokeGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                GradientStop {
                    position: 0
                    color: Qt.alpha(root.rimTint, 0.16 + root.lightIntensity / 100 * 0.18)
                }
                GradientStop {
                    position: 0.52
                    color: Qt.alpha("#AFC6E8", root.dispersion / 100 * 0.11)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("#9EB1D0", 0.10 + root.dispersion / 100 * 0.14)
                }
            }
            PathSvg { path: root.outlinePath }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        clip: root.clip
    }
}
