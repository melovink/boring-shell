import QtQuick

// The bar itself is the search field, matching the original Spotlight styling.
Item {
    id: root

    property alias text: field.text
    property string placeholderText: "Search…"
    property string fontPrimary: "Outfit"
    property color nord1: "#3B4252"
    property color nord6: "#ECEFF4"
    property real surfaceOpacity: 0.78
    property bool shown: false
    property int horizontalPadding: Math.min(46, Math.floor(width / 8))
    readonly property bool inputFocused: field.activeFocus

    signal keyPressed(var event)

    implicitHeight: 46

    function focusSearch(): void { field.forceActiveFocus(); }

    onShownChanged: if (!shown) field.focus = false

    Timer {
        interval: 50
        repeat: true
        triggeredOnStart: true
        running: root.shown && root.visible && root.enabled
            && field.width > 0 && !field.activeFocus
        onTriggered: root.focusSearch()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.focusSearch()
    }

    Image {
        x: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 21
        height: 21
        source: Qt.resolvedUrl("../spotlight/assets/search.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: field.text.length === 0 ? 0.4 : 0.75

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    TextInput {
        id: field
        x: root.horizontalPadding + 34
        width: Math.max(0, parent.width - root.horizontalPadding * 2 - 34)
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        color: root.nord6
        selectionColor: Qt.alpha(root.nord1, root.surfaceOpacity)
        selectedTextColor: root.nord6
        font.family: root.fontPrimary
        font.pixelSize: 16
        selectByMouse: true
        clip: true

        Keys.onPressed: event => root.keyPressed(event)
    }

    Text {
        x: field.x
        width: field.width
        anchors.verticalCenter: parent.verticalCenter
        visible: field.text.length === 0
        text: root.placeholderText
        color: Qt.alpha(root.nord6, 0.4)
        font.family: root.fontPrimary
        font.pixelSize: 16
        elide: Text.ElideRight
    }
}
