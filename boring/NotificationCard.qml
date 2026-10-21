import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The top bar's notification state. Purely presentational: shell.qml owns the
// active notification, the dismissal deadline and every side effect, and drives
// this through plain properties.
//
// There is deliberately no interactive region. Activation and action buttons
// were both dropped during design, so the whole surface just dismisses.
Item {
    id: card

    property var notification: null
    property string timestamp: ""
    // Bumped by shell.qml on every arrival so replacing notifications cross-fades
    // instead of snapping, which is what makes a burst of messages legible.
    property int revision: 0

    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property color nord9: "#81A1C1"
    property color nord11: "#BF616A"
    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"

    signal dismissRequested()

    readonly property color urgencyColor: {
        if (!notification) return card.nord8;
        if (notification.urgency === NotificationUrgency.Critical) return card.nord11;
        if (notification.urgency === NotificationUrgency.Low) return card.nord9;
        return card.nord8;
    }

    // Web notifications send anything from an icon name to a data URL, and often
    // nothing usable at all, so this always resolves to something drawable.
    // Theme lookups cannot be relied on here: no QT_ICON_THEME is set, so QIcon
    // falls back to hicolor, which ships no application icons at all. Senders that
    // pass an absolute path (nearly all of them) are resolved directly, and
    // anything else falls through to the theme and then to a drawn badge.
    readonly property string iconSource: {
        if (!notification) return "";
        var icon = notification.appIcon;
        if (!icon) return "";
        if (icon.indexOf("file://") === 0) return icon;
        if (icon.charAt(0) === "/") return "file://" + icon;
        return Quickshell.iconPath(icon);
    }

    readonly property string iconInitial: {
        var app = card.senderName;
        return app.length > 0 ? app.charAt(0).toUpperCase() : "?";
    }

    // Chromium based browsers often put their branded desktop id in the
    // desktop-entry hint while reporting a generic appName such as Chromium.
    // Resolve that id so browser notifications retain the actual browser name.
    readonly property string senderName: {
        if (!notification) return "";

        var appName = notification.appName || "";
        var entryId = (notification.desktopEntry || "").toLowerCase();
        var entryKey = entryId.replace(/\.desktop$/, "");
        var entryName = "";

        if (entryKey.length > 0) {
            var entries = DesktopEntries.applications.values;
            for (var i = 0; i < entries.length; i++) {
                var candidate = entries[i];
                if (!candidate || !candidate.id) continue;
                var candidateId = candidate.id.toLowerCase();
                if (candidateId === entryId || candidateId.replace(/\.desktop$/, "") === entryKey) {
                    entryName = candidate.name || "";
                    break;
                }
            }

            // Some browser packages do not install a matching desktop entry.
            if (!entryName && entryKey.indexOf("helium") !== -1) entryName = "Helium";
        }

        var genericBrowserNames = ["chromium", "chrome", "google chrome"];
        if (entryName && (!appName || genericBrowserNames.indexOf(appName.toLowerCase()) !== -1)) {
            return entryName;
        }
        // Helium can report Chromium as appName and omit its desktop-entry hint.
        if (genericBrowserNames.indexOf(appName.toLowerCase()) !== -1) return "Helium";
        return appName || entryName;
    }

    onRevisionChanged: swap.restart()

    SequentialAnimation {
        id: swap
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 70; easing.type: Easing.InQuad }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutQuint }
    }

    Item {
        id: content
        anchors.fill: parent

        // Keep the notification layout vertically centered inside the 76px
        // pill, including room for a two-line body.
        Column {
            id: text
            anchors.left: parent.left
            anchors.leftMargin: 66
            anchors.right: stamp.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                id: labelRow
                spacing: 7

                // Subdued label rather than the headline: Chromium reports the
                // browser as the sender for web notifications, so this only ever
                // identifies the source.
                Text {
                    id: appLabel
                    text: card.senderName
                    color: card.nord9
                    font.family: card.fontPrimary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: 150
                }
            }

            Text {
                id: summary
                width: parent.width
                text: card.notification ? card.notification.summary : ""
                color: card.nord6
                font.family: card.fontPrimary
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: body
                width: parent.width
                height: 28
                text: card.notification ? card.notification.body : ""
                color: card.nord4
                font.family: card.fontPrimary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                clip: true
            }
        }

        Image {
            id: icon
            x: 20
            width: 32
            height: 32
            visible: card.iconSource !== ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            source: card.iconSource
            anchors.verticalCenter: parent.verticalCenter
        }

        // Drawn rather than themed: with no icon theme configured, a named glyph
        // would silently render nothing and leave a hole where the icon belongs.
        Rectangle {
            id: iconBadge
            x: 20
            width: 32
            height: 32
            radius: 8
            visible: card.iconSource === ""
            color: "transparent"
            border.color: card.nord4
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: card.iconInitial
                color: card.nord4
                font.family: card.fontPrimary
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        // Absolute arrival time, not relative: the card lives at most 15 seconds,
        // so a relative stamp could never show anything but "now".
        Text {
            id: stamp
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: text.y
            text: card.timestamp
            color: card.nord9
            font.family: card.fontMono
            font.pixelSize: 11
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.dismissRequested()
    }
}
