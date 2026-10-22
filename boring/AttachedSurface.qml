import QtQuick
import QtQuick.Shapes

// A single path avoids overlapping translucency or a border seam at the join.
Item {
    id: root

    property color color: "transparent"
    property color outlineColor: "#22D8DEE9"
    property real radius: height / 2
    property var popups: []
    property bool barHovered: false
    readonly property var requestedPopup: popups.find(p => p && p.visible) || null
    property var currentPopup: null
    readonly property alias popupContentItem: panel
    readonly property bool popupVisible: requestedPopup !== null || revealAnimation.running || popupReveal > 0.001
    readonly property bool popupAnimating: revealAnimation.running || xAnimation.running || widthAnimation.running || heightAnimation.running
    readonly property real popupVisibleHeight: Math.max(0, popupHeight * popupReveal)
    readonly property real joinRadius: Math.min(20, popupVisibleHeight / 2)
    readonly property real popupRadius: Math.min(28, popupVisibleHeight / 2)
    default property alias contentData: content.data

    onRequestedPopupChanged: {
        if (requestedPopup) currentPopup = requestedPopup;
    }

    // Caelestia's expressive default spatial curve is shared by every menu:
    // https://github.com/caelestia-dots/shell/blob/main/plugin/src/Caelestia/Config/tokens.hpp
    property real popupReveal: requestedPopup ? 1 : 0
    readonly property real targetPopupWidth: currentPopup ? Math.min(currentPopup.panelWidth, Math.max(0, width - (radius + 20) * 2)) : 0
    readonly property real targetPopupX: currentPopup
        ? Math.max(radius + 20, Math.min(width - radius - 20 - targetPopupWidth, currentPopup.anchorCenter - targetPopupWidth / 2)) : 0
    property real popupWidth: targetPopupWidth
    property real popupHeight: currentPopup ? currentPopup.panelHeight : 0
    property real popupX: targetPopupX

    Behavior on popupReveal {
        NumberAnimation { id: revealAnimation; duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }
    Behavior on popupX {
        enabled: root.popupReveal > 0.001
        NumberAnimation { id: xAnimation; duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }
    Behavior on popupWidth {
        enabled: root.popupReveal > 0.001
        NumberAnimation { id: widthAnimation; duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }
    Behavior on popupHeight {
        enabled: root.popupReveal > 0.001
        NumberAnimation { id: heightAnimation; duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }

    readonly property string surfacePath: {
        const w = width;
        const h = height;
        const r = Math.min(radius, w / 2, h / 2);
        let path = `M ${r} 0 H ${w - r} A ${r} ${r} 0 0 1 ${w} ${r} V ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h}`;
        if (popupVisibleHeight > 0.01 && popupWidth > 0) {
            const left = popupX;
            const right = left + popupWidth;
            const bottom = h + popupVisibleHeight;
            const join = joinRadius;
            const corner = popupRadius;
            path += ` H ${right + join} A ${join} ${join} 0 0 0 ${right} ${h + join}`;
            path += ` V ${bottom - corner} A ${corner} ${corner} 0 0 1 ${right - corner} ${bottom}`;
            path += ` H ${left + corner} A ${corner} ${corner} 0 0 1 ${left} ${bottom - corner}`;
            path += ` V ${h + join} A ${join} ${join} 0 0 0 ${left - join} ${h}`;
        }
        return path + ` H ${r} A ${r} ${r} 0 0 1 0 ${h - r} V ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`;
    }

    Shape {
        width: root.width
        height: root.height + root.popupVisibleHeight
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeColor: root.outlineColor
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.surfacePath }
        }
    }

    Item { id: content; anchors.fill: parent }
    Item {
        id: panel
        x: root.popupX
        y: root.height
        width: root.popupWidth
        height: root.popupVisibleHeight
        visible: root.popupVisible
        clip: true
    }
}
