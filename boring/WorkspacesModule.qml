pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    property color nord1
    property color nord4
    property color nord8
    property real rubberSpring: 7.0
    property real rubberDamping: 0.45

    readonly property int dotSize: 12
    readonly property int workspaceSpacing: 8
    readonly property int workspacePitch: dotSize + workspaceSpacing
    readonly property int focusedIndex: Hyprland.workspaces.indexOf(Hyprland.focusedWorkspace)
    readonly property real focusedX: focusedIndex < 0 ? 0 : focusedIndex * workspacePitch
    property real transitionStartX: 0
    property real transitionDistance: 0
    readonly property real travelProgress: transitionDistance > 0
        ? Math.min(1, Math.abs(activeBall.x - transitionStartX) / transitionDistance)
        : 0
    readonly property real stretchAmount: 1 - Math.abs(2 * travelProgress - 1)

    onFocusedXChanged: {
        if (activeBall) {
            transitionStartX = activeBall.x
            transitionDistance = Math.abs(focusedX - activeBall.x)
        }
    }

    implicitWidth: workspaceRepeater.count > 0
        ? workspaceRepeater.count * workspacePitch - workspaceSpacing : 0
    implicitHeight: dotSize
    width: implicitWidth
    height: implicitHeight
    anchors.verticalCenter: parent.verticalCenter

    Row {
        id: workspaceDots
        spacing: root.workspaceSpacing

        Repeater {
            id: workspaceRepeater
            model: Hyprland.workspaces

            Item {
                id: workspaceDot
                required property var modelData
                width: root.dotSize
                height: root.dotSize

                Rectangle {
                    anchors.centerIn: parent
                    width: root.dotSize
                    height: root.dotSize
                    radius: root.dotSize / 2
                    color: workspaceDot.modelData.focused
                        ? "transparent"
                        : (workspaceDot.modelData.active ? root.nord4 : root.nord1)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: workspaceDot.modelData.activate()
                }
            }
        }
    }

    Item {
        id: activeBall
        x: root.focusedX
        width: root.dotSize
        height: root.dotSize
        visible: root.focusedIndex >= 0

        Behavior on x {
            SpringAnimation {
                spring: root.rubberSpring
                damping: root.rubberDamping
                mass: 1
                epsilon: 0.25
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.dotSize + 12 * root.stretchAmount
            height: root.dotSize
            radius: height / 2
            color: root.nord8
        }
    }
}
