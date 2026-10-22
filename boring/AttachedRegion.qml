import QtQuick
import Quickshell

// Match the surface's rounded body and concave joins for input and blur.
Region {
    id: root
    required property AttachedSurface surface
    property bool active: true

    x: surface.x
    y: surface.y
    width: active ? surface.width : 0
    height: active ? surface.height : 0
    radius: surface.radius

    Region {
        x: root.surface.x + root.surface.popupX
        y: root.surface.y + root.surface.height
        width: root.active && root.surface.popupVisible ? root.surface.popupWidth : 0
        height: root.active ? root.surface.popupVisibleHeight : 0
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: root.surface.popupRadius
        bottomRightRadius: root.surface.popupRadius
    }
    Region {
        id: leftJoin
        x: root.surface.x + root.surface.popupX - root.surface.joinRadius
        y: root.surface.y + root.surface.height
        width: root.active ? root.surface.joinRadius : 0
        height: width
        Region {
            intersection: Intersection.Subtract
            shape: RegionShape.Ellipse
            x: leftJoin.x - leftJoin.width
            y: leftJoin.y
            width: leftJoin.width * 2
            height: width
        }
    }
    Region {
        id: rightJoin
        x: root.surface.x + root.surface.popupX + root.surface.popupWidth
        y: root.surface.y + root.surface.height
        width: root.active ? root.surface.joinRadius : 0
        height: width
        Region {
            intersection: Intersection.Subtract
            shape: RegionShape.Ellipse
            x: rightJoin.x
            y: rightJoin.y
            width: rightJoin.width * 2
            height: width
        }
    }
}
