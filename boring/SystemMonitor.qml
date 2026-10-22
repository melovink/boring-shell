pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property color nord0: "#2E3440"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property color nord9: "#81A1C1"
    property real surfaceOpacity: 0.78
    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"
    property real sizeScale: 1.2
    property int edgeMargin: 12
    property int topMargin: 12
    property int refreshInterval: 2000

    anchors { top: true; left: true }
    margins.left: root.edgeMargin
    margins.top: root.topMargin
    implicitWidth: gauges.implicitWidth + 32 * root.sizeScale
    implicitHeight: gauges.implicitHeight + 32 * root.sizeScale
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "boring-system-monitor"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    BackgroundEffect.blurRegion: Region {
        item: surface
        radius: surface.radius
    }

    SystemMetrics {
        id: metrics
        active: root.visible
        refreshInterval: root.refreshInterval
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 28 * root.sizeScale
        color: Qt.alpha(root.nord0, root.surfaceOpacity)
        border.width: root.sizeScale
        border.color: Qt.alpha(root.nord4, 0.12)

        Row {
            id: gauges
            anchors.centerIn: parent
            spacing: 16 * root.sizeScale

            ResourceGauge {
                width: implicitWidth
                height: implicitHeight
                label: "CPU"
                sizeScale: root.sizeScale
                detail: "total usage"
                value: metrics.cpuUsage
                accent: root.nord8
                foreground: root.nord6
                secondary: root.nord4
                fontPrimary: root.fontPrimary
                fontMono: root.fontMono
            }

            ResourceGauge {
                width: implicitWidth
                height: implicitHeight
                label: "RAM"
                sizeScale: root.sizeScale
                detail: metrics.memoryTotal > 0
                    ? (metrics.memoryUsed / 1073741824).toFixed(1) + "/"
                        + (metrics.memoryTotal / 1073741824).toFixed(1) + " GiB"
                    : "— GiB"
                value: metrics.memoryUsage
                accent: root.nord9
                foreground: root.nord6
                secondary: root.nord4
                fontPrimary: root.fontPrimary
                fontMono: root.fontMono
            }
        }
    }
}
