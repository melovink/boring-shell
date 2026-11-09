pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: github

    required property string username
    property var calendar: null
    property int cellSize: 7
    property int cellSpacing: 2
    property int padding: 16
    property real sizeScale: 1.2
    property int edgeMargin: 12
    property int topMargin: 12
    property int refreshInterval: 30 * 60 * 1000
    property color nord0: "#2E3440"
    property color nord4: "#D8DEE9"
    property real surfaceOpacity: 0.78
    readonly property real cellPitch: (cellSize + cellSpacing) * sizeScale
    readonly property real scaledCellSize: cellSize * sizeScale
    readonly property real scaledPadding: padding * sizeScale
    readonly property int weeksToShow: 10
    readonly property var levelColors: ["#3B4252", "#4B596E", "#5C6C84", "#7787A6", "#A6B1C4"]
    readonly property real gridWidth: weeksToShow * cellPitch - cellSpacing * sizeScale
    readonly property real gridHeight: 7 * cellPitch - cellSpacing * sizeScale

    anchors { top: true; left: true }
    margins.top: github.topMargin
    margins.left: github.edgeMargin
    implicitWidth: Math.round(github.gridWidth + github.scaledPadding * 2)
    implicitHeight: Math.round(github.gridHeight + github.scaledPadding * 2)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "boring-github-contributions"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    BackgroundEffect.blurRegion: Region {
        item: surface
        radius: surface.radius
    }

    GlassSurface {
        id: surface
        anchors.fill: parent
        radius: 24 * github.sizeScale
        borderWidth: github.sizeScale
        fillStart: "#FF2E3440"
        fillEnd: "#737787A6"
        rimTint: github.nord4
        lightAngle: 180
        lightIntensity: 80
        refraction: 80
        depth: 20
        dispersion: 50
        splay: 0
    }

    function refresh(): void {
        if (!contributionsProcess.running) contributionsProcess.running = true;
    }

    Component.onCompleted: {
        if (visible) refresh();
    }

    onVisibleChanged: {
        if (visible) refresh();
        else contributionsProcess.running = false;
    }

    Process {
        id: contributionsProcess
        command: ["python3", Quickshell.shellPath("boring/github_contributions.py"), github.username,
            "--cache-dir", Quickshell.cachePath("github-contributions")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text);
                    if (result.cells) github.calendar = result;
                } catch (error) {
                    // Keep the last displayed calendar if a refresh fails.
                }
            }
        }
    }

    Timer {
        interval: github.refreshInterval
        running: github.visible
        repeat: true
        onTriggered: github.refresh()
    }

    Repeater {
        model: github.weeksToShow * 7

        Rectangle {
            required property int index
            readonly property var contribution: {
                if (!github.calendar) return null;
                const firstWeek = Math.max(0, github.calendar.weeks - github.weeksToShow);
                return github.calendar.cells[firstWeek * 7 + index] ?? null;
            }

            x: github.scaledPadding + Math.floor(index / 7) * github.cellPitch
            y: github.scaledPadding + (index % 7) * github.cellPitch
            width: github.scaledCellSize
            height: github.scaledCellSize
            radius: 1.5 * github.sizeScale
            color: github.levelColors[contribution ? contribution.level : 0]
        }
    }
}
