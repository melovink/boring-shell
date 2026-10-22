pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../boring" as Boring

// Search and results only; the top bar supplies the surrounding surface.
Item {
    id: panel

    property bool shown: false
    property int maxRows: 9
    property int rowHeight: 48
    property int fieldHeight: 46
    property int listSpacing: 10
    property int listBottomMargin: 24
    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property string fontPrimary: "Outfit"
    property real surfaceOpacity: 0.78
    property var results: []
    property int selectedIndex: 0
    property int iconRevision: 0

    signal queryEdited(string text)
    signal moveSelection(int delta)
    signal selectIndex(int index)
    signal activate()
    signal activateIndex(int index)
    signal dismiss()

    implicitHeight: fieldHeight + (results.length > 0
        ? listSpacing + Math.min(results.length, maxRows) * rowHeight + listBottomMargin : 0)

    // Icon extraction can finish while results are already being displayed.
    function iconSource(item, revision): string {
        if (item.kind === "appimage" && item.iconFile) return "file://" + item.iconFile;
        var themed = item.icon ? Quickshell.iconPath(item.icon, true) : "";
        if (themed !== "") return themed;
        return Quickshell.iconPath("application-x-executable", true);
    }

    onShownChanged: {
        field.text = "";
        list.positionViewAtBeginning();
        if (!shown) field.focus = false;
    }

    onSelectedIndexChanged: revealSelection()
    onResultsChanged: Qt.callLater(revealSelection)

    function revealSelection(): void {
        if (list.count > 0) list.positionViewAtIndex(panel.selectedIndex, ListView.Contain);
    }

    Boring.SearchBar {
        id: field
        anchors.top: parent.top
        width: parent.width
        height: panel.fieldHeight
        placeholderText: "Search applications…"
        shown: panel.shown
        fontPrimary: panel.fontPrimary
        nord1: panel.nord1
        nord6: panel.nord6
        surfaceOpacity: panel.surfaceOpacity

        onTextChanged: panel.queryEdited(text)

        onKeyPressed: event => {
            if (event.key === Qt.Key_Escape) {
                panel.dismiss();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                panel.activate();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                panel.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                panel.moveSelection(1);
                event.accepted = true;
            } else if (panel.results.length > 0 && event.key === Qt.Key_Home) {
                panel.selectIndex(0);
                event.accepted = true;
            } else if (panel.results.length > 0 && event.key === Qt.Key_End) {
                panel.selectIndex(panel.results.length - 1);
                event.accepted = true;
            }
        }
    }

    Rectangle {
        x: field.horizontalPadding
        y: panel.fieldHeight
        width: Math.max(0, parent.width - x * 2)
        height: 1
        color: Qt.alpha("#434C5E", panel.surfaceOpacity)
        opacity: 0.75
        visible: panel.results.length > 0
    }

    ListView {
        id: list
        anchors.top: field.bottom
        anchors.topMargin: panel.listSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: panel.listBottomMargin
        visible: panel.results.length > 0
        model: panel.results
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3000
        maximumFlickVelocity: 6000

        delegate: SpotlightRow {
            required property var modelData
            required property int index
            width: list.width
            height: panel.rowHeight
            item: modelData
            selected: index === panel.selectedIndex
            iconSource: panel.iconSource(modelData, panel.iconRevision)
            nord1: panel.nord1
            nord6: panel.nord6
            surfaceOpacity: panel.surfaceOpacity
            fontPrimary: panel.fontPrimary
            onPicked: panel.activateIndex(index)
        }
    }
}
