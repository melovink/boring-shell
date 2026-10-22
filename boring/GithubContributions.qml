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
    property int edgeMargin: 12
    property int topMargin: 12
    property int refreshInterval: 30 * 60 * 1000
    readonly property int cellPitch: cellSize + cellSpacing
    readonly property int weeksToShow: 10
    readonly property var levelColors: ["#3B4252", "#4C566A", "#5E81AC", "#81A1C1", "#88C0D0"]

    anchors { top: true; left: true }
    margins.top: github.topMargin
    margins.left: github.edgeMargin
    implicitWidth: weeksToShow * cellPitch - cellSpacing
    implicitHeight: 7 * cellPitch - cellSpacing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "boring-github-contributions"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

            x: Math.floor(index / 7) * github.cellPitch
            y: (index % 7) * github.cellPitch
            width: github.cellSize
            height: github.cellSize
            radius: 1.5
            color: github.levelColors[contribution ? contribution.level : 0]
        }
    }
}
