import QtQuick
import QtQuick.Effects
import Quickshell

// The floating Spotlight panel. Purely presentational: shell.qml owns the index,
// the selection and every side effect, and drives this through plain properties.
Item {
    id: panel

    property bool shown: false
    property int panelWidth: 580
    property int panelHeight: 48
    property int shadowPad: 46
    property real panelRadius: 45
    property real displayWidth: panelWidth
    property real displayRadius: panelRadius
    // QtQuick uses normalized spring values; these preserve the restrained,
    // slightly rubbery feel of Hyprland's mass 1 / stiffness 790 / dampening 45.
    readonly property real rubberSpring: 12.0
    readonly property real rubberDamping: 0.55
    readonly property real introDiameter: Math.max(panelHeight, listTop + listBottomMargin)
    property bool introSpringEnabled: false
    property int rowHeight: 48
    property int fieldTopMargin: 22
    property int fieldHeight: 30
    property int dividerTop: 66
    property int listTop: 76
    property int listBottomMargin: 12
    property int hPad: 46
    property int fieldIconGap: 34

    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord2: "#434C5E"
    property color nord6: "#ECEFF4"
    property string fontPrimary: "Outfit"
    property real surfaceOpacity: 0.8

    property var results: []
    property int selectedIndex: 0
    property int iconRevision: 0

    signal queryEdited(string text)
    signal moveSelection(int delta)
    signal selectIndex(int index)
    signal activate()
    signal activateIndex(int index)
    signal dismiss()

    width: displayWidth + shadowPad * 2
    height: panelHeight + shadowPad * 2

    // Reset to the circle first, then enable the spring for the target jump.
    // Behavior is used here because it tracks direct property changes reliably
    // even when the panel is reopened while a previous intro is being cancelled.
    Behavior on displayWidth {
        enabled: panel.introSpringEnabled
        SpringAnimation {
            spring: panel.rubberSpring
            damping: panel.rubberDamping
            mass: 1
            epsilon: 0.25
        }
    }

    Behavior on displayRadius {
        enabled: panel.introSpringEnabled
        SpringAnimation {
            spring: panel.rubberSpring
            damping: panel.rubberDamping
            mass: 1
            epsilon: 0.01
        }
    }

    Timer {
        id: introStartTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (!panel.shown) return;
            panel.introSpringEnabled = true;
            panel.displayWidth = panel.panelWidth;
            panel.displayRadius = panel.panelRadius;
        }
    }

    // Reads iconRevision so every row's Image re-resolves its source when an
    // AppImage extraction lands mid-session.
    function iconSource(item): string {
        panel.iconRevision;
        if (item.kind === "appimage" && item.iconFile) return "file://" + item.iconFile;
        var themed = item.icon ? Quickshell.iconPath(item.icon, true) : "";
        if (themed !== "") return themed;
        return Quickshell.iconPath("application-x-executable", true);
    }

    // Focus follows the launcher's open state, not this item's own `visible`:
    // `visible` is already true on the focused monitor when the panel is created,
    // so it never changes and would never trigger a reset.
    onShownChanged: {
        if (!shown) {
            focusTimer.stop();
            introStartTimer.stop();
            introSpringEnabled = false;
            return;
        }
        introStartTimer.stop();
        introSpringEnabled = false;
        displayWidth = introDiameter;
        displayRadius = introDiameter / 2;
        introStartTimer.restart();
        focusTimer.restart();
    }
    onVisibleChanged: {
        if (visible && shown) focusTimer.restart();
    }

    Timer {
        id: focusTimer
        // Deferred so the layer surface is exposed and can actually take focus.
        interval: 80
        onTriggered: {
            field.text = "";
            field.forceActiveFocus();
        }
    }

    onSelectedIndexChanged: revealSelection()

    function revealSelection(): void {
        if (list.count === 0) return;
        if (panel.selectedIndex < list.firstVisibleIndex) list.positionViewAtBeginning();
        else if (panel.selectedIndex > list.lastVisibleIndex) list.positionViewAtIndex(panel.selectedIndex);
    }

    // Low-alpha shadow. Keeping the shadow itself translucent prevents it from
    // becoming an opaque backing layer beneath the panel body.
    RectangularShadow {
        id: panelShadow
        x: panel.shadowPad
        y: panel.shadowPad
        width: panel.displayWidth
        height: panel.panelHeight
        radius: panel.displayRadius
        blur: 18
        color: "#30000000"
        offset: Qt.vector2d(0, 2)
    }

    GradientBorder {
        id: body
        x: panel.shadowPad
        y: panel.shadowPad
        width: panel.displayWidth
        height: panel.panelHeight
        radius: panel.displayRadius
        color: Qt.alpha(panel.nord0, panel.surfaceOpacity)
        clip: true

        Behavior on height {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }

        // Absorbs clicks on the panel's own padding so they do not fall through to
        // the backdrop. Declared first, so the results list still wins above it.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: {}
        }

        Image {
            id: magnifier
            width: 21
            height: 21
            x: panel.hPad
            y: panel.fieldTopMargin + Math.round((panel.fieldHeight - height) / 2)
            source: Qt.resolvedUrl("assets/search.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: field.text.length === 0 ? 0.4 : 0.75

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        TextInput {
            id: field
            x: panel.hPad + panel.fieldIconGap
            y: panel.fieldTopMargin
            width: parent.width - panel.hPad * 2 - panel.fieldIconGap
            height: panel.fieldHeight
            verticalAlignment: TextInput.AlignVCenter
            color: panel.nord6
            selectionColor: Qt.alpha(panel.nord1, panel.surfaceOpacity)
            selectedTextColor: panel.nord6
            font.family: panel.fontPrimary
            font.pixelSize: 21
            clip: true

            onTextChanged: panel.queryEdited(text)

            // One handler for every binding so accept order is explicit and modifiers
            // fall through untouched.
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

        // TextInput has no placeholderText in Qt Quick, so it is drawn alongside.
        Text {
            x: field.x
            anchors.verticalCenter: field.verticalCenter
            visible: field.text.length === 0
            text: "Search applications…"
            color: Qt.alpha(panel.nord6, 0.4)
            font.family: panel.fontPrimary
            font.pixelSize: 21
        }

        Rectangle {
            visible: panel.results.length > 0
            x: panel.hPad
            y: panel.dividerTop
            width: parent.width - panel.hPad * 2
            height: 1
            color: Qt.alpha(panel.nord2, panel.surfaceOpacity)
            opacity: 0.75
        }

        ListView {
            id: list
            x: 0
            y: panel.listTop
            width: parent.width
            // Track the animated body height so the list grows with the panel instead
            // of clipping against a height that has not caught up yet.
            height: Math.max(0, body.height - panel.listTop - panel.listBottomMargin)
            model: panel.results
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000
            maximumFlickVelocity: 6000

            delegate: SpotlightRow {
                width: list.width
                height: panel.rowHeight
                item: modelData
                selected: index === panel.selectedIndex
                iconSource: panel.iconSource(modelData)
                nord1: panel.nord1
                nord6: panel.nord6
                surfaceOpacity: panel.surfaceOpacity
                fontPrimary: panel.fontPrimary
                onPicked: panel.activateIndex(index)
            }
        }
    }
}
