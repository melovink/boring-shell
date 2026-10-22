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
    property int edgeMargin: 12
    property int topMargin: 12
    property int refreshInterval: 30 * 60 * 1000
    property color nord0: "#2E3440"
    property color nord4: "#D8DEE9"
    property real surfaceOpacity: 0.78
    readonly property int cellPitch: cellSize + cellSpacing
    readonly property int weeksToShow: 10
    readonly property var levelColors: ["#3B4252", "#4C566A", "#5E81AC", "#81A1C1", "#88C0D0"]
    readonly property int gridWidth: weeksToShow * cellPitch - cellSpacing
    readonly property int gridHeight: 7 * cellPitch - cellSpacing

    anchors { top: true; left: true }
    margins.top: github.topMargin
    margins.left: github.edgeMargin
    implicitWidth: github.gridWidth + github.padding * 2
    implicitHeight: github.gridHeight + github.padding * 2
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

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 24
        color: Qt.alpha(github.nord0, github.surfaceOpacity)
        border.width: 1
        border.color: Qt.alpha(github.nord4, 0.12)
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

            x: github.padding + Math.floor(index / 7) * github.cellPitch
            y: github.padding + (index % 7) * github.cellPitch
            width: github.cellSize
            height: github.cellSize
            radius: 1.5
            color: github.levelColors[contribution ? contribution.level : 0]
        }
    }
}
