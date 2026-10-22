import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: trayRoot
    required property AttachedSurface popupHost
    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord6: "#ECEFF4"
    property color nord9: "#81A1C1"
    property real surfaceOpacity: 0.8
    readonly property int trayItemCount: SystemTray.items.values.length
    readonly property int iconSize: 24
    readonly property int iconSpacing: 8
    property var panelWindow
    property bool isTrayMenuOpen: trayPopup.presented
    property var activeTrayData: null
    property var activeTrayItem: null
    property alias popup: trayPopup
    property var otherPopups: []

    visible: trayItemCount > 0
    width: trayItemCount > 0 ? trayItemCount * iconSize + (trayItemCount - 1) * iconSpacing : 0
    height: iconSize
    anchors.verticalCenter: parent.verticalCenter

    HoverHandler {
        id: trayHover
    }

    Row {
        id: trayIcons
        anchors.fill: parent
        spacing: trayRoot.iconSpacing

        Repeater {
            model: SystemTray.items
            Item {
                id: trayItemDel
                width: trayRoot.iconSize
                height: trayRoot.iconSize
                property var trayData: modelData

                IconImage {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: trayItemDel.trayData.icon
                    asynchronous: true
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            trayItemDel.trayData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (trayItemDel.trayData.hasMenu) {
                                if (trayRoot.activeTrayData === trayItemDel.trayData && trayPopup.visible) {
                                    trayPopup.visible = false;
                                } else {
                                    trayRoot.activeTrayData = trayItemDel.trayData;
                                    trayRoot.activeTrayItem = trayItemDel;
                                    trayPopup.visible = true;
                                    for (var i = 0; i < trayRoot.otherPopups.length; i++) {
                                        if (trayRoot.otherPopups[i])
                                            trayRoot.otherPopups[i].visible = false;
                                    }
                                }
                            } else {
                                trayItemDel.trayData.display(panelWindow, mouse.x, mouse.y);
                            }
                        }
                    }
                }
            }
        }
    }

    AnimatedPopup {
        id: trayPopup
        popupHost: trayRoot.popupHost
        anchorItem: trayRoot.activeTrayItem
        anchorHovered: trayHover.hovered
        panelWidth: 280
        panelHeight: Math.min(400, Math.max(36, menuListView.contentHeight)) + padding * 2

        QsMenuOpener {
            id: menuOpener
            menu: trayPopup.presented && trayRoot.activeTrayData ? trayRoot.activeTrayData.menu : null
        }

        ListView {
            id: menuListView
            anchors.fill: parent
            model: menuOpener.children
            interactive: contentHeight > height
            clip: true
            spacing: 4
            delegate: Rectangle {
                width: menuListView.width
                height: modelData.isSeparator ? 1 : 36
                color: modelData.isSeparator ? Qt.alpha(trayRoot.nord1, trayRoot.surfaceOpacity) : (hover.hovered ? Qt.alpha(trayRoot.nord1, trayRoot.surfaceOpacity) : "transparent")
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8
                    visible: !modelData.isSeparator
                    Image {
                        source: modelData.icon
                        width: 16
                        height: 16
                        Layout.alignment: Qt.AlignVCenter
                        sourceSize: Qt.size(16, 16)
                        visible: modelData.icon !== ""
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: modelData.enabled ? trayRoot.nord6 : trayRoot.nord9
                        font.pixelSize: 13
                        font.family: "Inter"
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
