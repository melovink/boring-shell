pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// Search and results only; the top bar supplies the surrounding surface.
Item {
    id: panel

    property bool shown: false
    property int maxRows: 9
    property int rowHeight: 48
    property int fieldHeight: 40
    property int listSpacing: 12
    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property string fontPrimary: "Inter"
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
        ? listSpacing + Math.min(results.length, maxRows) * rowHeight : 0)

    // Icon extraction can finish while results are already being displayed.
    function iconSource(item, revision): string {
        if (item.kind === "appimage" && item.iconFile) return "file://" + item.iconFile;
        var themed = item.icon ? Quickshell.iconPath(item.icon, true) : "";
        if (themed !== "") return themed;
        return Quickshell.iconPath("application-x-executable", true);
    }

    onShownChanged: {
        focusTimer.stop();
        field.text = "";
        list.positionViewAtBeginning();
        if (shown) focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: if (panel.shown) field.forceActiveFocus()
    }

    onSelectedIndexChanged: revealSelection()
    onResultsChanged: Qt.callLater(revealSelection)

    function revealSelection(): void {
        if (list.count > 0) list.positionViewAtIndex(panel.selectedIndex, ListView.Contain);
    }

    TextField {
        id: field
        anchors.top: parent.top
        width: parent.width
        height: panel.fieldHeight
        color: panel.nord6
        placeholderText: "Search applications…"
        placeholderTextColor: panel.nord4
        font.family: panel.fontPrimary
        font.pixelSize: 13
        selectByMouse: true
        leftPadding: 42
        rightPadding: 12

        background: Rectangle {
            radius: 14
            color: Qt.alpha(panel.nord1, panel.surfaceOpacity)
            border.width: 1
            border.color: field.activeFocus
                ? panel.nord8 : Qt.alpha(panel.nord4, 0.12)
        }

        Image {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            source: Qt.resolvedUrl("assets/search.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: field.text.length === 0 ? 0.5 : 0.85
        }

        onTextChanged: panel.queryEdited(text)

        Keys.onPressed: event => {
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

    ListView {
        id: list
        anchors.top: field.bottom
        anchors.topMargin: panel.listSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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
            horizontalMargin: 0
            nord1: panel.nord1
            nord6: panel.nord6
            surfaceOpacity: panel.surfaceOpacity
            fontPrimary: panel.fontPrimary
            onPicked: panel.activateIndex(index)
        }
    }
}
