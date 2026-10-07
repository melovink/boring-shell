import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Io

ShellRoot {
    id: root

    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property color nord9: "#81A1C1"
    property color nord11: "#BF616A"

    // Match Kitty's background_opacity while keeping foreground content opaque.
    readonly property real surfaceOpacity: 0.78

    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"

    property string bottomBarMode: "cava"

    // ---- Notifications ----
    // boring owns the org.freedesktop.Notifications name, so this process is the
    // desktop's notification daemon. Nothing else claimed that name: dunst's
    // D-Bus service file is discarded in favour of a plasma_waitforname stub that
    // never takes the name and dies after a minute, which is why notify-send used
    // to hang. Registering here fixes that at the source instead of shadowing the
    // broken system service file.
    property var activeNotification: null
    property string notifTimestamp: ""
    property double notifDeadline: 0
    property bool notifHovered: false
    property int notifRevision: 0
    // Transient expanded state driven by holding the peek key. Kept separate from
    // the hover-driven expansion so the bind does not have to steal the pointer.
    property bool barHeld: false
    // Do-not-disturb, toggled from the bell button at the right end of the bar.
    property bool notifMuted: false

    NotificationServer {
        onNotification: n => root.showNotification(n)
    }

    // Urgency maps to lifetime so the bar is not monopolised by low-value noise
    // (no filtering was requested, so things like the touchpad toggle do arrive).
    function notificationDuration(n): number {
        if (n.urgency === NotificationUrgency.Critical) return 15000;
        if (n.urgency === NotificationUrgency.Low) return 2000;
        var t = n.expireTimeout;
        if (typeof t !== "number" || t <= 0) return 5000;
        return Math.max(2000, Math.min(15000, t));
    }

    function showNotification(n): void {
        // Muted: leave it untracked so Quickshell drops it right away.
        if (root.notifMuted) return;

        // The card replaces the modules the popups are anchored to, so leaving them
        // open would strand a floating menu against a hidden anchor.
        calPopup.visible = false;
        volPopup.visible = false;
        netPopup.visible = false;
        pwrPopup.visible = false;
        if (trayModule && trayModule.popup) trayModule.popup.visible = false;

        root.releaseNotification();

        root.notifTimestamp = Qt.formatDateTime(new Date(), "hh:mm");
        root.notifDeadline = Date.now() + root.notificationDuration(n);
        root.notifRevision++;

        // Quickshell frees a Notification as soon as onNotification returns unless
        // it is tracked, which nulled the card a frame after it arrived. Claiming
        // the one notification being displayed is what keeps its payload alive.
        n.tracked = true;
        root.activeNotification = n;
    }

    function dismissNotification(): void {
        if (root.activeNotification) root.activeNotification.dismiss();
        root.releaseNotification();
    }

    // Releases the payload without reporting a dismissal, so a notification that
    // was merely replaced does not tell its sender the user swiped it away.
    function releaseNotification(): void {
        var n = root.activeNotification;
        root.activeNotification = null;
        if (n) n.tracked = false;
    }

    // The sender retracted it, or the server expired it: drop the card.
    Connections {
        target: root.activeNotification
        function onClosed(): void { root.activeNotification = null; }
    }

    // A coarse tick rather than a single shot: hovering has to pause the deadline
    // and resuming should not restart the full duration, so the remaining time is
    // derived from an absolute deadline rather than from the timer itself.
    Timer {
        id: notifTimer
        interval: 150
        repeat: true
        running: root.activeNotification !== null
        onTriggered: {
            if (root.notifHovered) {
                root.notifDeadline = Date.now() + 150;
                return;
            }
            if (Date.now() >= root.notifDeadline) root.dismissNotification();
        }
    }


    IpcHandler {
        target: "bottomBar"
        function showLauncher(): void {
            root.bottomBarMode = root.bottomBarMode === "launcher" ? "cava" : "launcher";
            cavaBar.WlrLayershell.keyboardFocus = root.bottomBarMode !== "cava" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
        }
        function showWallpaper(): void {
            root.bottomBarMode = root.bottomBarMode === "wallpaper" ? "cava" : "wallpaper";
            cavaBar.WlrLayershell.keyboardFocus = root.bottomBarMode !== "cava" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
        }
        function toggleGif(): void {
            gifModule.isActive = !gifModule.isActive;
        }
        function holdBar(): void {
            root.barHeld = true;
        }
        function unholdBar(): void {
            root.barHeld = false;
        }
        function toggleBar(): void {
            root.barHeld = !root.barHeld;
        }
    }

    // Data Properties
    property string volumeText: "..."
    // Raw sink level (0..1), kept separately from volumeText so the slider still
    // knows the level while muted.
    property real volumeLevel: 0
    property string wifiText: "..."
    property string networkType: "none"
    property string batteryText: "..."
    property string batteryStatus: "Unknown"
    // TLP power profile from /run/tlp/last_pwr: performance, balanced or power-saver.
    property string tlpProfile: ""
    property string mpdRawText: "Stopped"
    property bool mpdPlaying: false
    property string mpdText: {
        if (mpdRawText.length <= 30) return mpdRawText;
        return mpdRawText.substring(0, 30) + "...";
    }
    
    // Processes for Polling Data
    // `mpc status` prints "<song>\n[playing|paused] ...\nvolume: ..." while a
    // song is loaded and only the "volume:" line when stopped. Untagged files
    // (e.g. plain .wav) have no artist/title, so the format falls back to the
    // file path, marked with "file:" so it can be trimmed to a bare name.
    Process {
        id: mpcProc
        command: ["mpc", "status", "-f", "[[%artist% - ]%title%]|file:%file%"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var state = lines.length >= 2 ? lines[1].match(/^\[(\w+)\]/) : null;
                if (state) {
                    var song = lines[0].trim();
                    if (song.startsWith("file:"))
                        song = song.substring(5).split("/").pop().replace(/\.[^.]+$/, "");
                    root.mpdRawText = song !== "" ? song : "Unknown";
                    root.mpdPlaying = state[1] === "playing";
                } else {
                    root.mpdRawText = "Stopped";
                    root.mpdPlaying = false;
                }
            }
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                // A poll that started before the latest slider write would report
                // the old level and yank the slider back, so drop it.
                if (setVolProc.running || setVolProc.pendingVol >= 0) return;
                var out = this.text.trim();
                var match = out.match(/Volume: ([\d\.]+)/);
                if (match && match[1]) root.volumeLevel = parseFloat(match[1]);
                if (out.includes("[MUTED]")) {
                    root.volumeText = "Muted";
                } else if (match && match[1]) {
                    root.volumeText = Math.round(root.volumeLevel * 100) + "%";
                }
            }
        }
    }

    // Slider writes are serialised through one wpctl process. While it runs, only
    // the newest requested level is remembered, so a fast drag never queues a
    // backlog and never drops the final position.
    Process {
        id: setVolProc
        property real targetVol: 0.5
        property real pendingVol: -1
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetVol.toFixed(2)]
        onRunningChanged: {
            if (running) return;
            if (pendingVol >= 0) Qt.callLater(root.flushVolume);
            else volProc.running = true;
        }
    }

    function setVolume(v: real): void {
        root.volumeLevel = v;
        if (root.volumeText !== "Muted") root.volumeText = Math.round(v * 100) + "%";
        setVolProc.pendingVol = v;
        if (!setVolProc.running) root.flushVolume();
    }

    function flushVolume(): void {
        if (setVolProc.running || setVolProc.pendingVol < 0) return;
        setVolProc.targetVol = setVolProc.pendingVol;
        setVolProc.pendingVol = -1;
        setVolProc.running = true;
    }

    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f type,state,connection dev | grep -E '^(ethernet|wifi):connected' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out !== "") {
                    var parts = out.split(":");
                    root.networkType = parts[0];
                    root.wifiText = parts[2] || "Connected";
                } else {
                    root.networkType = "none";
                    root.wifiText = "Disconnected";
                }
            }
        }
    }

    // TLP records its active profile as the first field of /run/tlp/last_pwr
    // (0 = performance, 1 = balanced, 2 = power-saver). The file is world
    // readable and far cheaper to poll than spawning tlp-stat.
    Process {
        id: batProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity /sys/class/power_supply/BAT*/status 2>/dev/null; echo \"tlp $(cut -d' ' -f1 /run/tlp/last_pwr 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var tlpLine = lines.length > 0 && lines[lines.length - 1].startsWith("tlp") ? lines.pop() : "tlp";
                var profiles = { "0": "performance", "1": "balanced", "2": "power-saver" };
                root.tlpProfile = profiles[tlpLine.substring(3).trim()] || "";
                if (lines.length >= 2) {
                    root.batteryText = lines[0] + "%";
                    root.batteryStatus = lines[1];
                } else {
                    root.batteryText = "N/A";
                    root.batteryStatus = "Unknown";
                }
            }
        }
    }

    Process {
        id: mpdToggleProc
        command: ["mpc", "toggle"]
        onRunningChanged: if (!running) mpcProc.running = true
    }



    Process {
        id: hyprlandEventProc
        command: ["sh", "-c", "socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var l = line.trim();
                if (l.startsWith("activewindow>>")) {
                    calPopup.visible = false;
                    volPopup.visible = false;
                    netPopup.visible = false;
                    pwrPopup.visible = false;
                    if (trayModule && trayModule.popup) trayModule.popup.visible = false;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            volProc.running = true;
            wifiProc.running = true;
            batProc.running = true;
            mpcProc.running = true;
        }
    }

    // Floating centered clock (stays behind all windows)
    FloatingClock {}

    PanelWindow {
        id: dynamicIsland
        anchors { top: true; left: true; right: true; }
        // Fixed at the tallest state rather than animated. Resizing a layer-shell
        // window reallocates the surface and input region every frame, which
        // stuttered badly; the Region mask already trims input to the bar itself,
        // so the extra room is never hit.
        height: 100
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay

        BackgroundEffect.blurRegion: Region {
            item: background
            radius: background.radius
        }

        mask: Region {
            x: background.x
            y: background.y
            width: background.width
            height: background.height
        }

        // A notification outranks hover: the card is only legible at full width, so
        // it never appears in the 120px collapsed sliver. Two thirds of the
        // expanded bar, so the bar grows into the card rather than jumping.
        readonly property bool notifActive: root.activeNotification !== null
        property bool isExpanded: root.barHeld || hoverHandler.hovered || calPopup.visible || volPopup.visible || netPopup.visible || pwrPopup.visible || trayModule.isTrayMenuOpen
        property real targetWidth: notifActive ? 520 : (isExpanded ? 780 : 120)

        GradientBorder {
            id: background
            anchors.top: parent.top
            anchors.topMargin: dynamicIsland.notifActive ? -16 : (dynamicIsland.isExpanded ? -16 : -55)

            Behavior on anchors.topMargin {
                NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            width: dynamicIsland.targetWidth
            height: dynamicIsland.notifActive ? 96 : 56
            color: Qt.alpha(root.nord0, root.surfaceOpacity)
            radius: 16
            // Place the lightest point one third up from the bottom edge, then
            // fade it back out before the clipped bottom edge.
            gradientEndPosition: 2 / 3
            gradientTail: "#00fff7ff"

            Behavior on width {
                NumberAnimation { duration: 380; easing.type: Easing.OutQuint }
            }

            Behavior on height {
                NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
            }

            HoverHandler {
                id: hoverHandler
                onHoveredChanged: root.notifHovered = hovered
            }

            NotificationCard {
                anchors.fill: parent
                notification: root.activeNotification
                timestamp: root.notifTimestamp
                revision: root.notifRevision
                opacity: dynamicIsland.notifActive ? 1.0 : 0.0
                visible: opacity > 0

                onDismissRequested: root.dismissNotification()

                Behavior on opacity {
                    NumberAnimation { duration: 190; easing.type: Easing.OutQuint }
                }

                nord1: root.nord1
                nord4: root.nord4
                nord6: root.nord6
                nord8: root.nord8
                nord9: root.nord9
                nord11: root.nord11
                fontPrimary: root.fontPrimary
                fontMono: root.fontMono
            }

            Row {
                id: expandedModules
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 8
                spacing: 16
                opacity: dynamicIsland.notifActive ? 0.0 : (dynamicIsland.isExpanded ? 1.0 : 0.0)
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                }

                // Workspaces
                WorkspacesModule {
                    nord1: root.nord1
                    nord4: root.nord4
                    nord8: root.nord8
                }
                
                // MPD
                MpdModule {
                    nord1: root.nord1
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                    mpdText: root.mpdText
                    playing: root.mpdPlaying
                    toggleProcess: mpdToggleProc
                }

                // Clock
                ClockModule {
                    id: clockRect
                    nord0: root.nord0
                    nord1: root.nord1
                    nord4: root.nord4
                    nord6: root.nord6
                    nord8: root.nord8
                    fontPrimary: root.fontPrimary
                    fontMono: root.fontMono
                    calPopup: calPopup
                    otherPopups: [volPopup, netPopup, pwrPopup, trayModule.popup]
                }

                // Volume
                VolumeModule {
                    id: volRect
                    nord1: root.nord1
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                    volumeText: root.volumeText
                    volPopup: volPopup
                    otherPopups: [calPopup, netPopup, pwrPopup, trayModule.popup]
                }
                
                // WiFi
                WifiModule {
                    id: wifiRect
                    nord1: root.nord1
                    nord4: root.nord4
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                    wifiText: root.wifiText
                    networkType: root.networkType
                    netPopup: netPopup
                    otherPopups: [calPopup, volPopup, pwrPopup, trayModule.popup]
                    scanWifiProc: scanWifiProc
                }
                
                // Battery
                BatteryModule {
                    id: batRect
                    nord1: root.nord1
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                    batteryText: root.batteryText
                    batteryStatus: root.batteryStatus
                    pwrPopup: pwrPopup
                    otherPopups: [calPopup, volPopup, netPopup, trayModule.popup]
                }
                
                // App Tray
                TrayModule {
                    id: trayModule
                    nord0: root.nord0
                    nord1: root.nord1
                    nord6: root.nord6
                    nord9: root.nord9
                    surfaceOpacity: root.surfaceOpacity
                    panelWindow: dynamicIsland
                    otherPopups: [calPopup, volPopup, netPopup, pwrPopup]
                }

                // GIF Toggle
                GifModule {
                    id: gifModule
                    nord1: root.nord1
                    nord4: root.nord4
                    nord6: root.nord6
                    nord8: root.nord8
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                }

                // Notification mute (kept last so it sits at the right edge)
                NotifMuteModule {
                    nord1: root.nord1
                    nord6: root.nord6
                    nord11: root.nord11
                    surfaceOpacity: root.surfaceOpacity
                    muted: root.notifMuted
                    onToggled: root.notifMuted = !root.notifMuted
                }
            }

            // Compact Clock
            Text {
                id: compactClock
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 8
                text: Qt.formatDateTime(new Date(), "hh:mm")
                color: root.nord6
                font.family: root.fontMono
                font.pixelSize: 14
                opacity: dynamicIsland.notifActive ? 0.0 : (dynamicIsland.isExpanded ? 0.0 : 1.0)
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
            }
        }
        
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                var timeString = Qt.formatDateTime(new Date(), "hh:mm")
                compactClock.text = timeString
                clockRect.timeText = timeString

            }
        }
    }

    // Phase 4: Popups
    // Every popup content tree is wrapped in PopupHoverArea, which closes the
    // popup once the pointer has left both the popup and its module.
    // Calendar Popup
    PopupWindow {
        id: calPopup
        anchor {
            item: clockRect
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }
        visible: false
        width: 280
        height: 280
        color: "transparent"

        BackgroundEffect.blurRegion: Region {
            item: calendarBackground
            radius: calendarBackground.radius
        }

        PopupHoverArea {
            popup: calPopup
            anchorHovered: clockRect.hovered

            GradientBorder {
                id: calendarBackground
                anchors.fill: parent
                anchors.topMargin: 10
                color: Qt.alpha(root.nord0, root.surfaceOpacity)
                radius: 12

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    Text { text: Qt.formatDateTime(new Date(), "MMMM yyyy"); color: root.nord8; font.family: root.fontPrimary; font.pixelSize: 16; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    
                    Grid {
                        columns: 7; spacing: 8
                        // Weekdays
                        Repeater {
                            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                            Text { text: modelData; color: root.nord4; font.family: root.fontPrimary; font.pixelSize: 12; width: 24; horizontalAlignment: Text.AlignHCenter }
                        }
                        // Simple representation of days 1-31
                        Repeater {
                            model: 31
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                color: (index + 1) === parseInt(Qt.formatDateTime(new Date(), "d")) ? root.nord8 : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: index + 1
                                    color: (index + 1) === parseInt(Qt.formatDateTime(new Date(), "d")) ? root.nord0 : root.nord6
                                    font.family: root.fontPrimary; font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Volume Popup
    PopupWindow {
        id: volPopup
        anchor { item: volRect; edges: Edges.Bottom; gravity: Edges.Bottom }
        visible: false; width: 200; height: 100; color: "transparent"

        BackgroundEffect.blurRegion: Region {
            item: volumeBackground
            radius: volumeBackground.radius
        }
        
        Process {
            id: toggleMuteProc
            command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
            onRunningChanged: if(!running) volProc.running = true
        }

        PopupHoverArea {
            popup: volPopup
            anchorHovered: volRect.hovered
            // The drag holds the pointer grab, so hover can read false mid-drag.
            hold: volSlider.pressed

            GradientBorder {
                id: volumeBackground
                anchors.fill: parent; anchors.topMargin: 10; color: Qt.alpha(root.nord0, root.surfaceOpacity); radius: 12
                
                Column {
                    anchors.centerIn: parent; spacing: 16; width: parent.width - 32
                    RowLayout {
                        width: parent.width; spacing: 8
                        Text { text: "Mute"; color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 14 }
                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            width: 40; height: 20; radius: 10
                            color: root.volumeText === "Muted"
                                ? Qt.alpha(root.nord11, root.surfaceOpacity)
                                : Qt.alpha(root.nord1, root.surfaceOpacity)
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: toggleMuteProc.running = true
                            }
                        }
                    }
                    // The level is only pushed into the slider while it is not being
                    // dragged. Binding it unconditionally let every 2s poll and every
                    // wpctl round-trip snap the handle back mid-drag.
                    Slider {
                        id: volSlider
                        width: parent.width
                        from: 0.0; to: 1.0
                        onMoved: root.setVolume(value)
                        Binding on value {
                            when: !volSlider.pressed
                            value: root.volumeLevel
                            restoreMode: Binding.RestoreNone
                        }
                    }
                }
            }
        }
    }

    // Network Popup
    // Each entry is { ssid, active }. The connected network is listed first.
    property var wifiList: []
    Process {
        id: scanWifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SSID", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var byName = {};
                for (var i = 0; i < lines.length; i++) {
                    // Terse rows look like "*:72:name". IN-USE and SIGNAL never
                    // contain ':', and nmcli escapes any ':' inside the SSID.
                    var m = lines[i].match(/^(.?):(\d*):(.*)$/);
                    if (!m) continue;
                    var ssid = m[3].replace(/\\:/g, ":").replace(/\\\\/g, "\\");
                    if (ssid === "") continue;
                    var signal = parseInt(m[2]) || 0;
                    var entry = byName[ssid] || { ssid: ssid, active: false, signal: 0 };
                    entry.active = entry.active || m[1] === "*";
                    entry.signal = Math.max(entry.signal, signal);
                    byName[ssid] = entry;
                }
                var list = Object.keys(byName).map(k => byName[k]);
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                if (list.length > 0) root.wifiList = list.slice(0, 8);
            }
        }
    }

    Process {
        id: connectWifiProc
        property string targetSsid: ""
        command: ["nmcli", "dev", "wifi", "connect", targetSsid]
        onRunningChanged: if (!running) { wifiProc.running = true; scanWifiProc.running = true; }
    }

    PopupWindow {
        id: netPopup
        anchor { item: wifiRect; edges: Edges.Bottom; gravity: Edges.Bottom }
        visible: false; width: 220; height: 260; color: "transparent"

        BackgroundEffect.blurRegion: Region {
            item: networkBackground
            radius: networkBackground.radius
        }

        PopupHoverArea {
            popup: netPopup
            anchorHovered: wifiRect.hovered

            GradientBorder {
                id: networkBackground
                anchors.fill: parent; anchors.topMargin: 10; color: Qt.alpha(root.nord0, root.surfaceOpacity); radius: 12
                
                ListView {
                    anchors.fill: parent
                    anchors.margins: 12
                    model: root.wifiList
                    spacing: 8
                    clip: true
                    delegate: Rectangle {
                        width: ListView.view.width; height: 32; radius: 8
                        color: modelData.active
                            ? Qt.alpha(root.nord8, root.surfaceOpacity)
                            : Qt.alpha(root.nord1, root.surfaceOpacity)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                            width: parent.width - 24 - (connectedLabel.visible ? connectedLabel.implicitWidth + 8 : 0)
                            text: modelData.ssid; elide: Text.ElideRight
                            color: modelData.active ? root.nord0 : root.nord6
                            font.family: root.fontPrimary; font.pixelSize: 12; font.bold: modelData.active
                        }
                        Text {
                            id: connectedLabel
                            visible: modelData.active
                            anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 12
                            text: "Connected"; color: root.nord0
                            font.family: root.fontPrimary; font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            // Re-running "connect" on the active network only drops it briefly.
                            enabled: !modelData.active
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { connectWifiProc.targetSsid = modelData.ssid; connectWifiProc.running = true; }
                        }
                    }
                }
            }
        }
    }

    // Power/TLP Popup
    // TLP 1.10 profiles: "ac" is an alias of performance, "bat" of balanced.
    Process {
        id: tlpSetProc
        property string profile: "performance"
        command: ["pkexec", "tlp", profile]
        onRunningChanged: if (!running) batProc.running = true
    }

    PopupWindow {
        id: pwrPopup
        anchor { item: batRect; edges: Edges.Bottom; gravity: Edges.Bottom }
        visible: false; width: 180; height: 196; color: "transparent"

        BackgroundEffect.blurRegion: Region {
            item: powerBackground
            radius: powerBackground.radius
        }

        PopupHoverArea {
            popup: pwrPopup
            anchorHovered: batRect.hovered

            GradientBorder {
                id: powerBackground
                anchors.fill: parent; anchors.topMargin: 10; color: Qt.alpha(root.nord0, root.surfaceOpacity); radius: 12
                
                Column {
                    anchors.centerIn: parent; spacing: 10; width: parent.width - 24
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: "TLP: " + (root.tlpProfile !== "" ? root.tlpProfile : "unknown")
                        color: root.nord4; font.family: root.fontPrimary; font.pixelSize: 12
                    }
                    Repeater {
                        model: [
                            { profile: "performance", label: "Performance (AC)" },
                            { profile: "balanced", label: "Balanced (BAT)" },
                            { profile: "power-saver", label: "Power Saver" }
                        ]
                        Rectangle {
                            readonly property bool current: root.tlpProfile === modelData.profile
                            width: parent.width; height: 36; radius: 8
                            color: current
                                ? Qt.alpha(root.nord8, root.surfaceOpacity)
                                : Qt.alpha(root.nord1, root.surfaceOpacity)
                            Text {
                                anchors.centerIn: parent; text: modelData.label
                                color: parent.current ? root.nord0 : root.nord6
                                font.family: root.fontPrimary; font.pixelSize: 14; font.bold: parent.current
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { tlpSetProc.profile = modelData.profile; tlpSetProc.running = true; pwrPopup.visible = false; }
                            }
                        }
                    }
                }
            }
        }
    }

    // Cava Process
    property var cavaValues: [0,0,0,0,0,0,0,0,0,0,0,0]
    property bool cavaQuiet: true
    Process {
        id: cavaProc
        running: cavaBar.isHovered
        command: ["cava", "-p", "/home/melovink/.config/quickshell/lock/assets/cava.conf"]
        onRunningChanged: {
            if (!running) root.cavaValues = [0,0,0,0,0,0,0,0,0,0,0,0];
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                var parts = line.split(";");
                var out = [];
                var peak = 0;
                for (var i = 0; i < 12; i++) {
                    var v = parseInt(parts[i]);
                    var f = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100));
                    if (f > peak) peak = f;
                    out.push(f);
                }
                root.cavaValues = out;
                root.cavaQuiet = (peak <= 0.01);
            }
        }
    }

    // (Apps model and process moved to LauncherModule.qml)

    // Phase 5: Cava Bottom Bar
    PanelWindow {
        id: cavaBar
        anchors { bottom: true; left: true; right: true }
            height: root.bottomBarMode === "wallpaper" ? 340 : (root.bottomBarMode === "launcher" ? 500 : 60)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay

            BackgroundEffect.blurRegion: Region {
                item: cavaBackground
                radius: cavaBackground.radius
            }

        property bool isHovered: cavaHoverHandler.hovered
        
        mask: Region {
            x: cavaBackground.x
            y: cavaBackground.y
            width: cavaBackground.width
            height: cavaBackground.height
        }

        GradientBorder {
            id: cavaBackground
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (root.bottomBarMode === "cava" && !cavaBar.isHovered) ? -75 : -16
            
            width: root.bottomBarMode === "wallpaper" ? 800 : (root.bottomBarMode === "launcher" ? 540 : 300)
            height: root.bottomBarMode === "wallpaper" ? 340 : (root.bottomBarMode === "launcher" ? 500 : 76)
            
            color: Qt.alpha(root.nord0, root.surfaceOpacity)
            radius: 16
            clip: true

            Behavior on anchors.bottomMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            HoverHandler {
                id: cavaHoverHandler
            }

            // Cava UI
            Row {
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                height: 40
                visible: root.bottomBarMode === "cava"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Repeater {
                    model: 12
                    Rectangle {
                        width: 12
                        height: root.cavaValues[index] !== undefined ? Math.max(4, root.cavaValues[index] * 40) : 4
                        color: root.nord8
                        radius: 6
                        anchors.bottom: parent.bottom
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }

            LauncherModule {
                visible: root.bottomBarMode === "launcher"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            WallpaperModule {
                visible: root.bottomBarMode === "wallpaper"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }
}
