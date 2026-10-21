import QtQuick

// One result row: keyboard selection, pointer hover, icon and label.
Item {
    id: row

    property var item: null
    property bool selected: false
    property string iconSource: ""
    property color nord1: "#3B4252"
    property color nord6: "#ECEFF4"
    property real surfaceOpacity: 0.8
    property int horizontalMargin: 16
    property int verticalMargin: 2
    property string fontPrimary: "Outfit"

    signal picked()

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.horizontalMargin
        anchors.rightMargin: row.horizontalMargin
        anchors.topMargin: row.verticalMargin
        anchors.bottomMargin: row.verticalMargin
        radius: 6
        color: row.selected
            ? Qt.alpha(row.nord1, row.surfaceOpacity)
            : rowMouse.containsMouse
                ? Qt.alpha(row.nord1, row.surfaceOpacity * 0.45)
                : "transparent"

        Behavior on color {
            ColorAnimation { duration: 80 }
        }
    }

    Image {
        id: icon
        x: 16
        width: 32
        height: 32
        anchors.verticalCenter: parent.verticalCenter
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        source: row.iconSource
    }

    Text {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: row.item ? row.item.name : ""
        color: row.nord6
        elide: Text.ElideRight
        font.family: row.fontPrimary
        font.pixelSize: 15
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.picked()
    }
}
