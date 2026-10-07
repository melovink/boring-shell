import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Row {
    id: trayRoot
    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord6: "#ECEFF4"
    property color nord9: "#81A1C1"
    property real surfaceOpacity: 0.8
    property var panelWindow
    property bool isTrayMenuOpen: trayPopup.visible
    property var activeTrayData: null
    property var activeTrayItem: null
    property alias popup: trayPopup
    property var otherPopups: []

    spacing: 8
    anchors.verticalCenter: parent.verticalCenter

    HoverHandler { id: trayHover }
    
    Repeater {
        model: SystemTray.items
        Item {
            id: trayItemDel
            width: 24; height: 24
            property var trayData: modelData
            
            Image { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate();
                    } else if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                            if (trayRoot.activeTrayData === modelData && trayPopup.visible) {
                                trayPopup.visible = false;
                            } else {
                                trayRoot.activeTrayData = modelData;
                                trayRoot.activeTrayItem = trayItemDel;
                                trayPopup.visible = true;
                                for (var i = 0; i < trayRoot.otherPopups.length; i++) {
                                    if (trayRoot.otherPopups[i]) trayRoot.otherPopups[i].visible = false;
                                }
                            }
                        } else {
                            modelData.display(panelWindow, mouse.x, mouse.y);
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: trayPopup
        visible: false
        width: 200
        height: Math.min(400, menuListView.contentHeight + 20)
        color: "transparent"

        BackgroundEffect.blurRegion: Region {
            item: trayBackground
            radius: trayBackground.radius
        }

        anchor {
            item: activeTrayItem
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }

        QsMenuOpener {
            id: menuOpener
            menu: trayPopup.visible && activeTrayData ? activeTrayData.menu : null
        }

        PopupHoverArea {
            popup: trayPopup
            anchorHovered: trayHover.hovered

            GradientBorder {
                id: trayBackground
                anchors.fill: parent
                anchors.topMargin: 10
                color: Qt.alpha(trayRoot.nord0, trayRoot.surfaceOpacity)
                radius: 12

                ListView {
                    id: menuListView
                    anchors.fill: parent
                    anchors.margins: 10
                    model: menuOpener.children
                    interactive: contentHeight > height
                    clip: true
                    spacing: 4
                    delegate: Rectangle {
                        width: menuListView.width
                        height: modelData.isSeparator ? 1 : 32
                        color: modelData.isSeparator
                            ? Qt.alpha(trayRoot.nord1, trayRoot.surfaceOpacity)
                            : (hover.hovered ? Qt.alpha(trayRoot.nord1, trayRoot.surfaceOpacity) : "transparent")
                        radius: 6

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8
                            visible: !modelData.isSeparator
                            Image {
                                source: modelData.icon
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                sourceSize: Qt.size(16, 16)
                                visible: modelData.icon !== ""
                            }
                            Text {
                                text: modelData.text
                                color: modelData.enabled ? trayRoot.nord6 : trayRoot.nord9
                                font.pixelSize: 14
                                font.family: "Inter"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler {
                            id: hover
                            enabled: !modelData.isSeparator && modelData.enabled
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !modelData.isSeparator && modelData.enabled
                            onClicked: {
                                modelData.triggered();
                                trayPopup.visible = false;
                            }
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}
