pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: github

    required property string username
    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"
    property real surfaceOpacity: 0.78
    property int cellSize: 7
    property int cellSpacing: 2
    property int edgeMargin: 24
    // Leave room for the top-right corner controls to reveal above the widget.
    property int topMargin: 80
    property int refreshInterval: 30 * 60 * 1000

    property var calendar: null
    property var hoveredDay: null
    property string errorText: ""
    readonly property int cellPitch: cellSize + cellSpacing
    readonly property int weeks: calendar ? calendar.weeks : 53
    readonly property int graphWidth: weeks * cellPitch - cellSpacing
    // Nord's darker slate progresses into its blue and turquoise accents.
    readonly property var levelColors: [Qt.alpha(nord1, 0.9), "#4C566A", "#5E81AC", "#81A1C1", "#88C0D0"]

    anchors { top: true; left: true }
    margins.top: github.topMargin
    margins.left: github.edgeMargin
    implicitWidth: graphWidth + 28 + 36
    implicitHeight: 115 + 7 * cellPitch - cellSpacing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "boring-github-contributions"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: card; radius: card.radius }

    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
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
                    if (result.cells) {
                        github.calendar = result;
                        github.errorText = "";
                    } else {
                        github.errorText = result.error || "Could not load contributions";
                    }
                } catch (error) {
                    github.errorText = "Could not load contributions";
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) github.errorText = "Could not load contributions";
        }
    }

    Timer {
        interval: github.refreshInterval
        running: github.visible
        repeat: true
        onTriggered: github.refresh()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(github.nord0, github.surfaceOpacity)
        border.width: 1
        border.color: Qt.alpha(github.nord4, 0.12)

        Item {
            id: header
            x: 18
            y: 16
            width: parent.width - 36
            height: 22

            SvgIcon {
                id: githubIcon
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                iconColor: github.nord6
                path: "M9 19c-4.3 1.3-4.3-2.5-6-3 M15 22v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 19 4.77 5.07 5.07 0 0 0 18.91 1S17.73.65 15 2.48a13.38 13.38 0 0 0-7 0C5.27.65 4.09 1 4.09 1A5.07 5.07 0 0 0 4 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 8 18.13V22"
            }

            Text {
                anchors.left: githubIcon.right
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: "GitHub"
                color: github.nord6
                font.family: github.fontPrimary
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "@" + github.username
                color: Qt.alpha(github.nord4, 0.7)
                font.family: github.fontMono
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://github.com/" + github.username)
            }
        }

        Item {
            id: chart
            x: 18
            y: 52
            width: parent.width - 36
            height: 19 + 7 * github.cellPitch - github.cellSpacing
            opacity: github.calendar ? 1 : 0.35

            Repeater {
                model: github.calendar ? github.calendar.months : []
                Text {
                    required property var modelData
                    x: 28 + modelData.week * github.cellPitch
                    text: modelData.name
                    color: Qt.alpha(github.nord4, 0.7)
                    font.family: github.fontPrimary
                    font.pixelSize: 10
                }
            }

            Repeater {
                model: ["", "Mon", "", "Wed", "", "Fri", ""]
                Text {
                    required property int index
                    required property string modelData
                    y: 19 + index * github.cellPitch + (github.cellSize - height) / 2
                    text: modelData
                    color: Qt.alpha(github.nord4, 0.65)
                    font.family: github.fontPrimary
                    font.pixelSize: 9
                }
            }

            Repeater {
                model: github.calendar ? github.calendar.cells : 53 * 7
                Rectangle {
                    id: dayCell
                    required property int index
                    required property var modelData
                    x: 28 + Math.floor(index / 7) * github.cellPitch
                    y: 19 + (index % 7) * github.cellPitch
                    width: github.cellSize
                    height: github.cellSize
                    radius: 1.5
                    visible: !github.calendar || modelData !== null
                    color: github.levelColors[github.calendar && modelData ? modelData.level : 0]
                    border.width: dayHover.hovered ? 1 : 0
                    border.color: github.nord6

                    HoverHandler {
                        id: dayHover
                        enabled: github.calendar !== null && dayCell.modelData !== null
                        onHoveredChanged: {
                            if (hovered) github.hoveredDay = dayCell.modelData;
                            else if (github.hoveredDay === dayCell.modelData) github.hoveredDay = null;
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 15
            width: legend.x - x - 12
            elide: Text.ElideRight
            text: {
                if (github.hoveredDay) {
                    const count = github.hoveredDay.count;
                    return count + (count === 1 ? " contribution on " : " contributions on ")
                        + Qt.formatDate(new Date(github.hoveredDay.date + "T12:00:00"), "MMM d, yyyy");
                }
                if (github.errorText) return github.errorText;
                if (!github.calendar) return "Loading contributions…";
                return github.calendar.total + " contributions in the last year"
                    + (github.calendar.stale ? " · offline" : "");
            }
            color: Qt.alpha(github.nord4, 0.8)
            font.family: github.fontPrimary
            font.pixelSize: 10
        }

        Row {
            id: legend
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 4

            Text {
                text: "Less"
                color: Qt.alpha(github.nord4, 0.6)
                font.family: github.fontPrimary
                font.pixelSize: 9
            }

            Repeater {
                model: github.levelColors
                Rectangle {
                    required property color modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: github.cellSize
                    height: github.cellSize
                    radius: 1.5
                    color: modelData
                }
            }

            Text {
                text: "More"
                color: Qt.alpha(github.nord4, 0.6)
                font.family: github.fontPrimary
                font.pixelSize: 9
            }
        }
    }
}
