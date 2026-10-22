import QtQuick
import Quickshell

// Preserve the buttons' visibility API while sharing the bar's attached surface.
Scope {
    id: root

    required property AttachedSurface popupHost
    required property Item anchorItem
    property bool visible: false
    property bool anchorHovered: false
    property bool hold: false
    property int panelWidth: 352
    property real panelHeight: 240
    property int padding: 16
    readonly property bool presented: visible || contentOpacity > 0.001
        || (popupHost.currentPopup === root && popupHost.popupVisible)
    default property alias contentData: content.data

    // Track ancestor geometry as song titles and tray items change row widths.
    readonly property real anchorCenter: {
        if (!anchorItem) return popupHost.width / 2;
        let center = anchorItem.width / 2;
        let item = anchorItem;
        while (item && item !== popupHost) {
            center += item.x;
            item = item.parent;
        }
        return item === popupHost ? center : anchorItem.mapToItem(popupHost, anchorItem.width / 2, 0).x;
    }

    property real contentOpacity: visible ? 1 : 0
    Behavior on contentOpacity {
        NumberAnimation {
            duration: root.visible ? 300 : 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.visible
                ? [0.34, 0.88, 0.34, 1, 1, 1]
                : [0.34, 0.8, 0.34, 1, 1, 1]
        }
    }

    Item {
        parent: root.popupHost.popupContentItem
        anchors.fill: parent
        visible: root.presented

        HoverHandler { id: popupHover }
        Timer {
            interval: 300
            running: root.visible && !root.anchorHovered && !root.popupHost.barHovered && !popupHover.hovered && !root.hold
            onTriggered: root.visible = false
        }

        Item {
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.padding - 8 * (1 - Math.min(1, Math.max(0, root.popupHost.popupReveal)))
            width: root.panelWidth - root.padding * 2
            height: root.panelHeight - root.padding * 2
            opacity: root.contentOpacity
            enabled: root.visible
        }
    }
}
