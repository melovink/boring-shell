import QtQuick
import QtQuick.Shapes

Item {
    id: svgRoot
    property string path: ""
    property color iconColor: "#ECEFF4"
    property real strokeWidth: 1.8
    property bool fill: false

    Shape {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(svgRoot.width, svgRoot.height) / 24
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: svgRoot.fill ? "transparent" : svgRoot.iconColor
            fillColor: svgRoot.fill ? svgRoot.iconColor : "transparent"
            strokeWidth: svgRoot.strokeWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: svgRoot.path }
        }
    }
}
