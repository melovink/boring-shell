import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property string label
    property string detail: ""
    property real value: -1
    property color accent: "#88C0D0"
    property color foreground: "#ECEFF4"
    property color secondary: "#D8DEE9"
    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"
    property real sizeScale: 1.0
    readonly property bool ready: isFinite(value) && value >= 0
    property real progress: ready ? Math.max(0, Math.min(1, value)) : 0
    readonly property real ringSize: 80 * sizeScale
    readonly property real lineWidth: 3.5 * sizeScale
    readonly property real ringRadius: (ringSize - lineWidth) / 2

    implicitWidth: 92 * sizeScale
    implicitHeight: ringSize + 22 * sizeScale

    Behavior on progress {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.ringSize
        height: width

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(root.secondary, 0.12)
                strokeWidth: root.lineWidth
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.ringSize / 2
                    centerY: root.ringSize / 2
                    radiusX: root.ringRadius
                    radiusY: root.ringRadius
                    startAngle: -225
                    sweepAngle: 270
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.progress > 0 ? root.accent : "transparent"
                strokeWidth: root.lineWidth
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.ringSize / 2
                    centerY: root.ringSize / 2
                    radiusX: root.ringRadius
                    radiusY: root.ringRadius
                    startAngle: -225
                    sweepAngle: 270 * root.progress
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2 * root.sizeScale

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ready ? Math.round(root.progress * 100) + "%" : "—"
                color: root.foreground
                font.family: root.fontMono
                font.pixelSize: 18 * root.sizeScale
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                color: root.accent
                font.family: root.fontPrimary
                font.pixelSize: 10 * root.sizeScale
                font.weight: Font.Medium
                font.letterSpacing: 0.7 * root.sizeScale
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.ringSize + 5 * root.sizeScale
        text: root.detail
        color: Qt.alpha(root.secondary, 0.7)
        font.family: root.fontMono
        font.pixelSize: 10 * root.sizeScale
    }
}
