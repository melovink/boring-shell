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
import Quickshell.Services.Pipewire
import Quickshell.Io

Item {
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
    // Keep the bar's geometry motion in sync with Spotlight's rubber spring.
    readonly property real rubberSpring: 7.0
    readonly property real rubberDamping: 0.45
    // Blur can start when geometry is visually settled, without waiting for the
    // spring's last sub-pixel oscillations to finish.
    readonly property real blurTolerance: 3.0

    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"

    property bool wallpaperPickerVisible: false

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
    // Do-not-disturb, toggled from the bell button in the corner controls.
    property bool notifMuted: false
    // The floating clock is visible by default, and can be hidden from the
    // top-right controls bar.
    property bool floatingClockEnabled: true

    // Public GitHub account shown by the desktop contribution grid.
    property string githubUsername: "melovink"
    property bool githubContributionsEnabled: true

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
        mpdPopup.visible = false;
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
        function showWallpaper(): void {
            root.wallpaperPickerVisible = !root.wallpaperPickerVisible;
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
    property string pendingTlpProfile: ""
    property string mpdRawText: "Stopped"
    property bool mpdPlaying: false
    property string mpdTitle: "No track playing"
    property string mpdAlbumArtist: ""
    property string mpdFile: ""
    property real mpdElapsed: 0
    property real mpdDuration: 0
    property int mpdSeekRevision: 0
    property double mpdStatusAt: Date.now()
    property double mpdProgressNow: Date.now()
    readonly property string mpdArtPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/quickshell-mpd-albumart-" + Quickshell.processId
    property bool mpdArtAvailable: false
    property int mpdArtRevision: 0
    readonly property real mpdDisplayedElapsed: {
        var now = mpdProgressNow;
        if (!mpdPlaying) return mpdElapsed;
        return Math.min(mpdDuration, mpdElapsed + Math.max(0, now - mpdStatusAt) / 1000);
    }
    property string mpdText: {
        if (mpdRawText.length <= 30) return mpdRawText;
        return mpdRawText.substring(0, 30) + "...";
    }

    function mpdTimeToSeconds(value: string): number {
        var parts = value.split(":");
        if (parts.length < 2 || parts.length > 3) return 0;
        var total = 0;
        for (var i = 0; i < parts.length; i++) {
            var part = parseInt(parts[i]);
            if (isNaN(part)) return 0;
            total = total * 60 + part;
        }
        return total;
    }

    function formatMpdTime(value: real): string {
        var total = Math.max(0, Math.floor(value));
        var seconds = total % 60;
        var minutes = Math.floor(total / 60) % 60;
        var hours = Math.floor(total / 3600);
        var paddedSeconds = seconds < 10 ? "0" + seconds : "" + seconds;
        if (hours > 0) {
            var paddedMinutes = minutes < 10 ? "0" + minutes : "" + minutes;
            return hours + ":" + paddedMinutes + ":" + paddedSeconds;
        }
        return Math.floor(total / 60) + ":" + paddedSeconds;
    }

    function requestMpdAlbumArt(uri: string): void {
        mpdArtAvailable = false;
        mpdAlbumArtProc.requestedUri = uri;
        if (uri !== "") mpdAlbumArtProc.startRequested();
    }
    
    // Processes for Polling Data
    Process {
        id: mpcProc
        property int seekRevision: 0
        command: ["mpc", "status", "-f", "%title%\t%album%\t%artist%\t%file%"]
        onStarted: seekRevision = root.mpdSeekRevision
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.replace(/\r/g, "").split("\n");
                var state = lines.length >= 2 ? lines[1].match(/^\[(\w+)\]/) : null;
                if (state) {
                    var fields = lines[0].split("\t");
                    var title = fields[0] ? fields[0].trim() : "";
                    var album = fields[1] ? fields[1].trim() : "";
                    var artist = fields[2] ? fields[2].trim() : "";
                    var file = fields[3] ? fields[3].trim() : "";
                    var fileName = file.split("/").pop().replace(/\.[^.]+$/, "");
                    if (title === "") title = fileName || "Unknown title";
                    root.mpdTitle = title;
                    root.mpdAlbumArtist = (album || "Unknown album") + " - " + (artist || "Unknown artist");
                    root.mpdRawText = artist ? artist + " - " + title : title;
                    root.mpdPlaying = state[1] === "playing";
                    var progress = lines[1].match(/(\d+(?::\d+){1,2})\/(\d+(?::\d+){1,2})/);
                    if (mpcProc.seekRevision === root.mpdSeekRevision && !mpdSeekProc.running) {
                        root.mpdElapsed = progress ? root.mpdTimeToSeconds(progress[1]) : 0;
                        root.mpdDuration = progress ? root.mpdTimeToSeconds(progress[2]) : 0;
                        root.mpdStatusAt = Date.now();
                        root.mpdProgressNow = root.mpdStatusAt;
                    }
                    if (file !== root.mpdFile) {
                        root.mpdFile = file;
                        root.requestMpdAlbumArt(file);
                    }
                } else {
                    root.mpdRawText = "Stopped";
                    root.mpdTitle = "No track playing";
                    root.mpdAlbumArtist = "";
                    root.mpdPlaying = false;
                    root.mpdElapsed = 0;
                    root.mpdDuration = 0;
                    root.mpdStatusAt = Date.now();
                    root.mpdProgressNow = root.mpdStatusAt;
                    if (root.mpdFile !== "") {
                        root.mpdFile = "";
                        root.requestMpdAlbumArt("");
                    }
                }
            }
        }
    }

    Process {
        id: mpdAlbumArtProc
        property string activeUri: ""
        property string requestedUri: ""
        function startRequested(): void {
            if (running || requestedUri === "") return;
            activeUri = requestedUri;
            requestedUri = "";
            running = true;
        }
        command: [
            "sh", "-c",
            "mpc albumart \"$1\" > \"$2\" 2>/dev/null || mpc readpicture \"$1\" > \"$2\" 2>/dev/null",
            "mpd-albumart", activeUri, root.mpdArtPath
        ]
        onExited: (exitCode, exitStatus) => {
            if (activeUri === root.mpdFile) {
                if (exitCode === 0) {
                    root.mpdArtRevision++;
                    root.mpdArtAvailable = true;
                } else {
                    root.mpdArtAvailable = false;
                }
            }
            Qt.callLater(function() { mpdAlbumArtProc.startRequested(); });
        }
    }

    Process {
        id: mpdPreviousProc
        command: ["mpc", "prev"]
        onRunningChanged: if (!running) mpcProc.running = true
    }

    Process {
        id: mpdNextProc
        command: ["mpc", "next"]
        onRunningChanged: if (!running) mpcProc.running = true
    }

    Process {
        id: mpdSeekProc
        property int percent: 0
        command: ["mpc", "seek", percent + "%"]
        onRunningChanged: if (!running) mpcProc.running = true
    }

    Timer {
        interval: 250
        running: root.mpdPlaying && mpdPopup.visible
        repeat: true
        onTriggered: root.mpdProgressNow = Date.now()
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

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumesChanged(): void { root.syncVolumeFromPipewire(); }
        function onMutedChanged(): void { root.syncVolumeFromPipewire(); }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged(): void { root.syncVolumeFromPipewire(); }
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

    function syncVolumeFromPipewire(): void {
        if (setVolProc.running || setVolProc.pendingVol >= 0) return;
        var sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio) return;
        root.volumeLevel = sink.audio.volume;
        root.volumeText = sink.audio.muted ? "Muted" : Math.round(root.volumeLevel * 100) + "%";
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
                if (root.pendingTlpProfile !== "" && root.pendingTlpProfile === root.tlpProfile) {
                    root.pendingTlpProfile = "";
                    tlpPendingTimer.stop();
                }
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
                    mpdPopup.visible = false;
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
    FloatingClock { visible: root.floatingClockEnabled }

    GithubContributions {
        visible: root.githubContributionsEnabled
        username: root.githubUsername
    }

    PanelWindow {
        id: dynamicIsland
        anchors { top: true; left: true; right: true; }
        // One fixed surface holds the bar and attached menus. The mask passes
        // input through everywhere else without resizing the window each frame.
        height: screen.height
        // Reserve only the visible portion of the expanded bar so application
        // windows move below it instead of being covered by the overlay layer.
        readonly property int edgeMargin: 8
        readonly property int windowMargin: 8
        readonly property int hiddenTopMargin: -56
        readonly property int revealDelay: 280
        readonly property int expandedExclusiveZone: edgeMargin + 46
        exclusiveZone: dynamicIsland.notifActive
            ? dynamicIsland.notificationExclusiveZone
            : ((dynamicIsland.isExpanded || !dynamicIsland.barHideComplete)
                ? dynamicIsland.expandedExclusiveZone
                : 0)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: netPopup.selectedWifi !== null
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Keep blur active as the attached region follows popup animations.
        BackgroundEffect.blurRegion: AttachedRegion {
            surface: background
            active: dynamicIsland.blurReady
        }

        mask: AttachedRegion { surface: background }

        // A notification outranks hover: the card is only legible at full width, so
        // it never appears in the 120px collapsed sliver. Two thirds of the
        // expanded bar, so the bar grows into the card rather than jumping.
        readonly property bool notifActive: root.activeNotification !== null
        property bool isExpanded: root.barHeld || hoverHandler.hovered || background.popupVisible
        property bool barRevealComplete: false
        property bool barHideComplete: true
        readonly property real targetHeight: notifActive ? 76 : 46
        property real targetWidth: notifActive ? 520
            : (barRevealComplete ? expandedModules.implicitWidth + 40 : 120)
        readonly property real targetTopMargin: notifActive
            ? edgeMargin
            : ((isExpanded || !barHideComplete) ? edgeMargin : hiddenTopMargin)
        property bool blurReady: false

        function updateBlurReady(): void {
            var destinationReady = dynamicIsland.notifActive
                || (dynamicIsland.isExpanded && dynamicIsland.barRevealComplete);
            if (!destinationReady) return;
            var targetX = (dynamicIsland.width - dynamicIsland.targetWidth) / 2;
            if (Math.abs(background.x - targetX) > root.blurTolerance
                || Math.abs(background.y - dynamicIsland.targetTopMargin) > root.blurTolerance
                || Math.abs(background.width - dynamicIsland.targetWidth) > root.blurTolerance
                || Math.abs(background.height - dynamicIsland.targetHeight) > root.blurTolerance) return;
            dynamicIsland.blurReady = true;
        }

        onIsExpandedChanged: {
            blurReady = false;
            if (isExpanded) {
                barHideComplete = false;
                collapseTimer.stop();
                revealTimer.restart();
            } else {
                revealTimer.stop();
                barRevealComplete = false;
                collapseTimer.restart();
            }
        }

        onNotifActiveChanged: {
            blurReady = false;
            Qt.callLater(dynamicIsland.updateBlurReady);
        }

        Timer {
            id: revealTimer
            interval: dynamicIsland.revealDelay
            repeat: false
            onTriggered: {
                if (dynamicIsland.isExpanded) dynamicIsland.barRevealComplete = true;
            }
        }

        Timer {
            id: collapseTimer
            interval: dynamicIsland.revealDelay
            repeat: false
            onTriggered: {
                if (!dynamicIsland.isExpanded) dynamicIsland.barHideComplete = true;
            }
        }

        AttachedSurface {
            id: background
            anchors.top: parent.top
            anchors.topMargin: dynamicIsland.targetTopMargin

            Behavior on anchors.topMargin {
                SpringAnimation {
                    spring: root.rubberSpring
                    damping: root.rubberDamping
                    mass: 1
                    epsilon: 0.25
                }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            width: dynamicIsland.targetWidth
            height: dynamicIsland.targetHeight
            color: Qt.alpha(root.nord0, root.surfaceOpacity)
            outlineColor: Qt.alpha(root.nord4, 0.12)
            radius: height / 2
            popups: [calPopup, volPopup, netPopup, pwrPopup, mpdPopup, trayModule.popup]
            barHovered: hoverHandler.hovered

            Behavior on width {
                SpringAnimation {
                    spring: root.rubberSpring
                    damping: root.rubberDamping
                    mass: 1
                    epsilon: 0.25
                }
            }

            Behavior on height {
                SpringAnimation {
                    spring: root.rubberSpring
                    damping: root.rubberDamping
                    mass: 1
                    epsilon: 0.25
                }
            }

            onXChanged: dynamicIsland.updateBlurReady()
            onYChanged: dynamicIsland.updateBlurReady()
            onWidthChanged: dynamicIsland.updateBlurReady()
            onHeightChanged: dynamicIsland.updateBlurReady()

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
                anchors.verticalCenterOffset: 0
                spacing: 16
                opacity: dynamicIsland.notifActive ? 0.0 : (dynamicIsland.barRevealComplete ? 1.0 : 0.0)
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                }

                // Workspaces
                WorkspacesModule {
                    nord1: root.nord1
                    nord4: root.nord4
                    nord8: root.nord8
                    rubberSpring: root.rubberSpring
                    rubberDamping: root.rubberDamping
                }
                
                // MPD
                MpdModule {
                    id: mpdRect
                    nord1: root.nord1
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                    mpdText: root.mpdText
                    playing: root.mpdPlaying
                    mediaPopup: mpdPopup
                    otherPopups: [calPopup, volPopup, netPopup, pwrPopup, trayModule.popup]
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
                    otherPopups: [volPopup, netPopup, pwrPopup, mpdPopup, trayModule.popup]
                }

                // Volume
                VolumeModule {
                    id: volRect
                    nord1: root.nord1
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    fontPrimary: root.fontPrimary
                    volumeText: root.volumeText
                    volumeLevel: root.volumeLevel
                    volPopup: volPopup
                    otherPopups: [calPopup, netPopup, pwrPopup, mpdPopup, trayModule.popup]
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
                    otherPopups: [calPopup, volPopup, pwrPopup, mpdPopup, trayModule.popup]
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
                    otherPopups: [calPopup, volPopup, netPopup, mpdPopup, trayModule.popup]
                }
                
                // App Tray
                TrayModule {
                    id: trayModule
                    popupHost: background
                    nord0: root.nord0
                    nord1: root.nord1
                    nord6: root.nord6
                    nord9: root.nord9
                    surfaceOpacity: root.surfaceOpacity
                    panelWindow: dynamicIsland
                    otherPopups: [calPopup, volPopup, netPopup, pwrPopup, mpdPopup]
                }

            }

            // Compact Clock
            Text {
                id: compactClock
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0
                text: Qt.formatDateTime(new Date(), "hh:mm")
                color: root.nord6
                font.family: "Outfit"
                font.pixelSize: 14
                opacity: dynamicIsland.notifActive ? 0.0 : (dynamicIsland.barRevealComplete ? 0.0 : 1.0)
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

    // Corner controls reveal from the top-right edge and use the same blurred,
    // gradient-bordered surface as the main bar.
    PanelWindow {
        id: cornerControls
        anchors { top: true; right: true }
        width: 220
        height: 64
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property bool isExpanded: cornerHover.hovered || cornerHitHover.hovered
        readonly property real expandedX: width - cornerBackground.width - 8
        readonly property real collapsedX: width - 24

        mask: Region { item: cornerHitArea }

        BackgroundEffect.blurRegion: Region {
            item: cornerBackground
            radius: cornerBackground.radius
        }

        // This hit area stays attached to the screen edge while the pill slides
        // underneath it, so the pointer can enter at the corner and move onto
        // either toggle without interrupting the animation.
        Rectangle {
            id: cornerHitArea
            x: cornerBackground.x
            y: 0
            width: cornerControls.width - x
            height: cornerControls.height
            color: "transparent"

            HoverHandler { id: cornerHitHover }
        }

        GradientBorder {
            id: cornerBackground
            x: cornerControls.isExpanded ? cornerControls.expandedX : cornerControls.collapsedX
            y: 8
            width: 208
            height: 46
            color: Qt.alpha(root.nord0, root.surfaceOpacity)
            radius: height / 2
            gradientEndPosition: 1 / 3
            gradientTail: "#00fff7ff"

            Behavior on x {
                SpringAnimation {
                    spring: root.rubberSpring
                    damping: root.rubberDamping
                    mass: 1
                    epsilon: 0.25
                }
            }

            HoverHandler { id: cornerHover }

            Row {
                anchors.centerIn: parent
                spacing: 8

                GifModule {
                    id: gifModule
                    nord1: root.nord1
                    nord6: root.nord6
                    surfaceOpacity: root.surfaceOpacity
                    onToggled: gifModule.isActive = !gifModule.isActive
                }

                NotifMuteModule {
                    nord1: root.nord1
                    surfaceOpacity: root.surfaceOpacity
                    muted: root.notifMuted
                    onToggled: root.notifMuted = !root.notifMuted
                }

                FloatingClockToggleModule {
                    nord1: root.nord1
                    surfaceOpacity: root.surfaceOpacity
                    clockEnabled: root.floatingClockEnabled
                    onToggled: root.floatingClockEnabled = !root.floatingClockEnabled
                }

                GithubContributionsToggleModule {
                    nord1: root.nord1
                    surfaceOpacity: root.surfaceOpacity
                    contributionsEnabled: root.githubContributionsEnabled
                    onToggled: root.githubContributionsEnabled = !root.githubContributionsEnabled
                }
            }
        }
    }

    // Phase 4: Popups
    // Menus share the bar surface and close after the pointer leaves the bar
    // and menu; active slider drags keep the volume menu open.
    // Calendar Popup
    AnimatedPopup {
        id: calPopup
        property var calendarDate: new Date()
        readonly property int firstWeekday: new Date(
            calendarDate.getFullYear(), calendarDate.getMonth(), 1).getDay()
        readonly property int daysInMonth: new Date(
            calendarDate.getFullYear(), calendarDate.getMonth() + 1, 0).getDate()

        popupHost: background
        anchorItem: clockRect
        anchorHovered: clockRect.hovered
        panelWidth: 280
        panelHeight: calendarControls.implicitHeight + padding * 2

        Timer {
            interval: 60000
            repeat: true
            running: true
            onTriggered: calPopup.calendarDate = new Date()
        }

        Column {
            id: calendarControls
            width: parent.width
            anchors.centerIn: parent
            spacing: 16
            Text { text: Qt.formatDateTime(calPopup.calendarDate, "MMMM yyyy"); color: root.nord8; font.family: root.fontPrimary; font.pixelSize: 16; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 7; spacing: 8
                // Weekdays
                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Text { text: modelData; color: root.nord4; font.family: root.fontPrimary; font.pixelSize: 12; width: 28; horizontalAlignment: Text.AlignHCenter }
                }
                // Six weeks keep the calendar aligned for every month layout.
                Repeater {
                    model: 42
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        readonly property int dayNumber: index - calPopup.firstWeekday + 1
                        readonly property bool hasDate: dayNumber > 0 && dayNumber <= calPopup.daysInMonth
                        readonly property bool isToday: hasDate && dayNumber === calPopup.calendarDate.getDate()
                        color: isToday ? root.nord8 : "transparent"
                        Text {
                            anchors.centerIn: parent
                            visible: parent.hasDate
                            text: parent.hasDate ? parent.dayNumber : ""
                            color: parent.isToday ? root.nord0 : root.nord6
                            font.family: root.fontPrimary; font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }

    // MPD Popup
    AnimatedPopup {
        id: mpdPopup
        popupHost: background
        anchorItem: mpdRect
        anchorHovered: mpdRect.hovered
        hold: mpdProgress.pressed
        panelWidth: 400
        panelHeight: mpdControls.height + padding * 2
        onVisibleChanged: if (visible) mpcProc.running = true

        Row {
            id: mpdControls
            width: parent.width
            height: 132
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                id: mpdCover
                width: 116; height: 116; radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(root.nord1, root.surfaceOpacity)
                clip: true

                SvgIcon {
                    anchors.centerIn: parent
                    width: 38; height: 38
                    visible: mpdCoverImage.status !== Image.Ready
                    path: "M9 18V5l12-2v13 M9 18a3 3 0 1 1-6 0a3 3 0 0 1 6 0 M21 16a3 3 0 1 1-6 0a3 3 0 0 1 6 0"
                    iconColor: root.nord8
                }
                Image {
                    id: mpdCoverImage
                    anchors.fill: parent
                    source: root.mpdArtAvailable
                        ? "file://" + root.mpdArtPath + "?rev=" + root.mpdArtRevision
                        : ""
                    visible: status === Image.Ready
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 256; sourceSize.height: 256
                    onStatusChanged: if (status === Image.Error) root.mpdArtAvailable = false
                }
            }

            Column {
                width: mpdControls.width - mpdCover.width - mpdControls.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: root.mpdTitle
                    textFormat: Text.PlainText
                    color: root.nord6
                    font.family: root.fontPrimary; font.pixelSize: 15; font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.mpdAlbumArtist
                    textFormat: Text.PlainText
                    color: root.nord4
                    font.family: root.fontPrimary; font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 38
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: previousMouse.containsMouse
                            ? Qt.alpha(root.nord8, 0.2) : "transparent"
                        Accessible.name: "Previous track"
                        SvgIcon {
                            anchors.centerIn: parent
                            width: 18; height: 18
                            path: "M6 5v14 M18 5 8 12l10 7z"
                            iconColor: root.nord6
                        }
                        MouseArea {
                            id: previousMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpdPreviousProc.running = true
                        }
                    }
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: Qt.alpha(root.nord8, 0.9)
                        anchors.verticalCenter: parent.verticalCenter
                        Accessible.name: root.mpdPlaying ? "Pause" : "Play"
                        SvgIcon {
                            anchors.centerIn: parent
                            width: 19; height: 19
                            path: root.mpdPlaying
                                ? "M7 5h4v14H7z M15 5h4v14h-4z"
                                : "M8 5v14l11-7z"
                            iconColor: root.nord0
                            fill: true
                        }
                        MouseArea {
                            id: togglePlaybackMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpdToggleProc.running = true
                        }
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextMouse.containsMouse
                            ? Qt.alpha(root.nord8, 0.2) : "transparent"
                        Accessible.name: "Next track"
                        SvgIcon {
                            anchors.centerIn: parent
                            width: 18; height: 18
                            path: "M18 5v14 M6 5l10 7-10 7z"
                            iconColor: root.nord6
                        }
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpdNextProc.running = true
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 6

                    Text {
                        Layout.preferredWidth: 30
                        text: root.formatMpdTime(root.mpdDisplayedElapsed)
                        color: root.nord4
                        font.family: root.fontMono; font.pixelSize: 9
                    }
                    Slider {
                        id: mpdProgress
                        Layout.fillWidth: true
                        implicitHeight: 16
                        padding: 0
                        from: 0; to: 1
                        enabled: root.mpdDuration > 0 && !mpdSeekProc.running
                        property bool userMoved: false
                        property real seekValue: 0
                        Binding on value {
                            when: !mpdProgress.pressed
                            value: root.mpdDuration > 0
                                ? root.mpdDisplayedElapsed / root.mpdDuration : 0
                            restoreMode: Binding.RestoreNone
                        }
                        onMoved: {
                            seekValue = value;
                            userMoved = true;
                        }
                        onPressedChanged: {
                            if (!pressed && userMoved) {
                                userMoved = false;
                                var target = Math.round(seekValue * 100);
                                root.mpdSeekRevision++;
                                root.mpdElapsed = root.mpdDuration * target / 100;
                                root.mpdStatusAt = Date.now();
                                root.mpdProgressNow = root.mpdStatusAt;
                                mpdSeekProc.percent = target;
                                mpdSeekProc.running = true;
                            }
                        }
                        background: Item {
                            x: mpdProgress.leftPadding
                            y: mpdProgress.topPadding + (mpdProgress.availableHeight - height) / 2
                            width: mpdProgress.availableWidth
                            height: 5
                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: Qt.alpha(root.nord1, root.surfaceOpacity)
                            }
                            Rectangle {
                                width: parent.width * mpdProgress.visualPosition
                                height: parent.height
                                radius: 3
                                color: root.nord8
                            }
                        }
                        handle: Item { width: 0; height: 0 }
                    }
                    Text {
                        Layout.preferredWidth: 30
                        text: root.formatMpdTime(root.mpdDuration)
                        color: root.nord4
                        font.family: root.fontMono; font.pixelSize: 9
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // Volume Popup
    AnimatedPopup {
        id: volPopup
        readonly property PwNode outputDevice: Pipewire.defaultAudioSink
        readonly property PwNode inputDevice: Pipewire.defaultAudioSource

        anchorItem: volRect
        popupHost: background
        anchorHovered: volRect.hovered
        hold: volSlider.pressed
        panelHeight: volumeControls.implicitHeight + padding * 2
        
        Process {
            id: toggleMuteProc
            command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
            onRunningChanged: if(!running) volProc.running = true
        }

        Process {
            id: toggleMicMuteProc
            command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        }

        Column {
            id: volumeControls
            width: parent.width
            spacing: 16

            Repeater {
                model: [
                    { label: "Output device", device: volPopup.outputDevice, input: false },
                    { label: "Input device", device: volPopup.inputDevice, input: true }
                ]
                Column {
                    id: deviceSection
                    required property var modelData
                    width: volumeControls.width
                    spacing: 8

                    Text {
                        text: deviceSection.modelData.label
                        color: root.nord4
                        font.family: root.fontPrimary; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.max(52, deviceName.implicitHeight + 24)
                        radius: 16
                        color: Qt.alpha(root.nord1, root.surfaceOpacity)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            SvgIcon {
                                Layout.alignment: Qt.AlignVCenter
                                width: 20; height: 20; iconColor: root.nord8
                                path: deviceSection.modelData.input
                                    ? "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1-6 0z M5 10v2a7 7 0 0 0 14 0v-2 M12 19v3 M8 22h8"
                                    : "M3 14v-3a9 9 0 0 1 18 0v3 M3 13h3v8H5a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2 M21 13h-3v8h1a2 2 0 0 0 2-2v-4a2 2 0 0 0-2-2"
                            }
                            Text {
                                id: deviceName
                                Layout.fillWidth: true
                                text: deviceSection.modelData.device
                                    ? (deviceSection.modelData.device.description || deviceSection.modelData.device.nickname || deviceSection.modelData.device.name)
                                    : "No device"
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                RowLayout {
                    width: parent.width
                    Text {
                        Layout.fillWidth: true
                        text: root.volumeText === "Muted" ? "Volume (muted)" : "Volume"
                        color: root.nord4; font.family: root.fontPrimary; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Text {
                        text: Math.round(root.volumeLevel * 100) + "%"
                        color: root.nord8; font.family: root.fontPrimary; font.pixelSize: 13; font.weight: Font.Medium
                    }
                }
                Slider {
                    id: volSlider
                    width: parent.width
                    implicitHeight: 36
                    padding: 0
                    from: 0.0; to: 1.0
                    onMoved: root.setVolume(value)
                    // Polls must not reset the slider while it is being dragged.
                    Binding on value {
                        when: !volSlider.pressed
                        value: root.volumeLevel
                        restoreMode: Binding.RestoreNone
                    }
                    background: Item {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + (volSlider.availableHeight - height) / 2
                        width: volSlider.availableWidth
                        height: 12

                        Rectangle {
                            radius: 6
                            color: Qt.alpha(root.nord1, root.surfaceOpacity)
                            anchors.fill: parent
                        }
                        Rectangle {
                            width: parent.width * volSlider.visualPosition
                            height: parent.height; radius: 6
                            color: root.nord8
                        }
                    }
                    handle: Item {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + (volSlider.availableHeight - height) / 2
                        width: 4; height: 28
                    }
                }
            }

            RowLayout {
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: "Mute output"
                    color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 13
                }
                Switch {
                    id: muteSwitch
                    padding: 0
                    implicitWidth: 44; implicitHeight: 24
                    checked: root.volumeText === "Muted"
                    Accessible.name: "Mute output"
                    onToggled: toggleMuteProc.running = true
                    indicator: Rectangle {
                        width: 44; height: 24; radius: 12
                        color: muteSwitch.checked ? root.nord8 : root.nord1
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            x: muteSwitch.checked ? 24 : 4; y: 4
                            width: 16; height: 16; radius: 8
                            color: muteSwitch.checked ? root.nord0 : root.nord4
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: "Mute microphone"
                    color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 13
                }
                Switch {
                    id: micMuteSwitch
                    padding: 0
                    implicitWidth: 44; implicitHeight: 24
                    enabled: Pipewire.defaultAudioSource !== null && !toggleMicMuteProc.running
                    checked: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio
                        ? Pipewire.defaultAudioSource.audio.muted : false
                    Accessible.name: "Mute microphone"
                    onToggled: toggleMicMuteProc.running = true
                    indicator: Rectangle {
                        width: 44; height: 24; radius: 12
                        color: micMuteSwitch.checked ? root.nord8 : root.nord1
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            x: micMuteSwitch.checked ? 24 : 4; y: 4
                            width: 16; height: 16; radius: 8
                            color: micMuteSwitch.checked ? root.nord0 : root.nord4
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }
            }

        }
    }

    // Network Popup
    // Each entry is { ssid, active, secured, signal }. The connected network is listed first.
    property var wifiList: []
    Process {
        id: scanWifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var byName = {};
                for (var i = 0; i < lines.length; i++) {
                    // IN-USE, SIGNAL, and SECURITY cannot contain ':'. nmcli
                    // escapes colons in the SSID, which remains the final field.
                    var m = lines[i].match(/^([^:]*):(\d*):([^:]*):(.*)$/);
                    if (!m) continue;
                    var ssid = m[4].replace(/\\:/g, ":").replace(/\\\\/g, "\\");
                    if (ssid === "") continue;
                    var signal = parseInt(m[2]) || 0;
                    var entry = byName[ssid] || { ssid: ssid, active: false, secured: false, signal: 0 };
                    entry.active = entry.active || m[1] === "*";
                    entry.signal = Math.max(entry.signal, signal);
                    entry.secured = entry.secured || m[3].trim() !== "";
                    byName[ssid] = entry;
                }
                var list = Object.keys(byName).map(k => byName[k]);
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.wifiList = list.slice(0, 8);
            }
        }
    }

    Process {
        id: connectWifiProc
        property string targetSsid: ""
        property string targetPassword: ""
        property bool passwordAttempt: false
        command: passwordAttempt
            ? ["nmcli", "dev", "wifi", "connect", targetSsid, "password", targetPassword]
            : ["nmcli", "dev", "wifi", "connect", targetSsid]
        onRunningChanged: if (!running) { wifiProc.running = true; scanWifiProc.running = true; }
        onExited: (exitCode, exitStatus) => {
            if (passwordAttempt) {
                if (exitCode === 0) {
                    netPopup.clearPasswordEntry();
                } else {
                    netPopup.passwordError = "Connection failed. Check the password and try again.";
                }
            }
            targetPassword = "";
            passwordAttempt = false;
        }
    }

    AnimatedPopup {
        id: netPopup
        property var selectedWifi: null
        property string passwordError: ""
        property bool returningToWifiList: false
        onVisibleChanged: if (!visible) clearPasswordEntry()
        function clearPasswordEntry(): void {
            selectedWifi = null;
            passwordError = "";
            returningToWifiList = false;
            wifiPasswordField.text = "";
        }
        function returnToNetworkList(): void {
            clearPasswordEntry();
            returningToWifiList = true;
        }
        function connectSelectedWifi(): void {
            if (!selectedWifi || wifiPasswordField.text.length === 0 || connectWifiProc.running) return;
            connectWifiProc.targetSsid = selectedWifi.ssid;
            connectWifiProc.targetPassword = wifiPasswordField.text;
            connectWifiProc.passwordAttempt = true;
            passwordError = "";
            wifiPasswordField.text = "";
            connectWifiProc.running = true;
        }
        popupHost: background
        anchorItem: wifiRect
        anchorHovered: wifiRect.hovered
        hold: selectedWifi !== null || returningToWifiList
        panelWidth: 320
        panelHeight: selectedWifi
            ? wifiPasswordControls.implicitHeight + padding * 2
            : Math.min(392, Math.max(44, networkList.contentHeight)) + padding * 2

        ListView {
            id: networkList
            anchors.fill: parent
            visible: netPopup.selectedWifi === null
            model: root.wifiList
            spacing: 8
            clip: true
            HoverHandler {
                onHoveredChanged: if (hovered) netPopup.returningToWifiList = false
            }
            delegate: Rectangle {
                width: ListView.view.width; height: 44; radius: 16
                color: modelData.active
                    ? Qt.alpha(root.nord8, root.surfaceOpacity)
                    : Qt.alpha(root.nord1, root.surfaceOpacity)
                Text {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                    width: parent.width - 24 - (stateLabel.visible ? stateLabel.implicitWidth + 8 : 0)
                    text: modelData.ssid; elide: Text.ElideRight
                    color: modelData.active ? root.nord0 : root.nord6
                    font.family: root.fontPrimary; font.pixelSize: 13; font.bold: modelData.active
                }
                Text {
                    id: stateLabel
                    visible: modelData.active || modelData.secured
                    anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 12
                    text: modelData.active ? "Connected" : "Secured"
                    color: modelData.active ? root.nord0 : root.nord4
                    font.family: root.fontPrimary; font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent
                    // Re-running "connect" on the active network only drops it briefly.
                    enabled: !modelData.active && !connectWifiProc.running
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        netPopup.returningToWifiList = false;
                        if (modelData.secured) {
                            netPopup.selectedWifi = modelData;
                            netPopup.passwordError = "";
                            wifiPasswordField.text = "";
                            Qt.callLater(function() { wifiPasswordField.forceActiveFocus(); });
                        } else {
                            connectWifiProc.targetSsid = modelData.ssid;
                            connectWifiProc.targetPassword = "";
                            connectWifiProc.passwordAttempt = false;
                            connectWifiProc.running = true;
                        }
                    }
                }
            }
        }

        Column {
            id: wifiPasswordControls
            width: parent.width
            anchors.centerIn: parent
            visible: netPopup.selectedWifi !== null
            spacing: 10

            Text {
                width: parent.width
                text: netPopup.selectedWifi ? netPopup.selectedWifi.ssid : ""
                color: root.nord8
                font.family: root.fontPrimary; font.pixelSize: 14; font.bold: true
                elide: Text.ElideRight
            }

            TextField {
                id: wifiPasswordField
                width: parent.width
                implicitHeight: 44
                placeholderText: "Network password"
                echoMode: TextInput.Password
                selectByMouse: true
                enabled: !connectWifiProc.running
                color: root.nord6
                placeholderTextColor: root.nord4
                font.family: root.fontPrimary; font.pixelSize: 13
                leftPadding: 12; rightPadding: 12
                background: Rectangle {
                    radius: 14
                    color: Qt.alpha(root.nord1, root.surfaceOpacity)
                    border.width: 1
                    border.color: wifiPasswordField.activeFocus ? root.nord8 : Qt.alpha(root.nord4, 0.12)
                }
                onAccepted: netPopup.connectSelectedWifi()
            }

            Text {
                width: parent.width
                visible: netPopup.passwordError !== ""
                text: netPopup.passwordError
                color: root.nord11
                wrapMode: Text.Wrap
                font.family: root.fontPrimary; font.pixelSize: 11
            }

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: 40; radius: 14
                    color: Qt.alpha(root.nord1, root.surfaceOpacity)
                    Text {
                        anchors.centerIn: parent
                        text: "Back"
                        color: root.nord6
                        font.family: root.fontPrimary; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !connectWifiProc.running
                        cursorShape: Qt.PointingHandCursor
                        onClicked: netPopup.returnToNetworkList()
                    }
                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: 40; radius: 14
                    color: wifiPasswordField.text.length > 0 && !connectWifiProc.running
                        ? root.nord8 : Qt.alpha(root.nord8, 0.35)
                    Text {
                        anchors.centerIn: parent
                        text: connectWifiProc.running ? "Connecting…" : "Connect"
                        color: root.nord0
                        font.family: root.fontPrimary; font.pixelSize: 12; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: wifiPasswordField.text.length > 0 && !connectWifiProc.running
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: netPopup.connectSelectedWifi()
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
        // Use TLP's user-session profile interface when tlp-pd is installed.
        // Keep the authenticated command available until that service is set up.
        command: [
            "sh", "-c",
            "if command -v tlpctl >/dev/null 2>&1; then exec tlpctl \"$1\"; else exec pkexec tlp \"$1\"; fi",
            "tlp-profile", profile
        ]
        onRunningChanged: if (!running) batProc.running = true
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.pendingTlpProfile = "";
                tlpPendingTimer.stop();
            }
        }
    }

    Timer {
        id: tlpPendingTimer
        interval: 10000
        repeat: false
        onTriggered: root.pendingTlpProfile = ""
    }

    AnimatedPopup {
        id: pwrPopup
        popupHost: background
        anchorItem: batRect
        anchorHovered: batRect.hovered
        panelWidth: 256
        panelHeight: powerControls.implicitHeight + padding * 2

        Column {
            id: powerControls
            anchors.centerIn: parent; width: parent.width
            Row {
                id: powerProfileGrid
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        {
                            profile: "power-saver",
                            label: "Power saver",
                            icon: "M20 4c-9 0-15 3-15 9a6 6 0 0 0 6 6c6 0 9-6 9-15z M5 19c2-4 6-7 11-9",
                            filled: false
                        },
                        {
                            profile: "balanced",
                            label: "Balanced",
                            icon: "M12 4v16 M5 7h14 M5 7l-3 6h6L5 7z M19 7l-3 6h6L19 7z M8 21h8",
                            filled: false
                        },
                        {
                            profile: "performance",
                            label: "Performance",
                            icon: "M13.3 2 5.5 13h5.7l-.6 9 7.9-12h-5.8z",
                            filled: true
                        }
                    ]
                    Rectangle {
                        readonly property bool current: (root.pendingTlpProfile !== ""
                            ? root.pendingTlpProfile : root.tlpProfile) === modelData.profile
                        Accessible.name: modelData.label
                        width: (powerProfileGrid.width - powerProfileGrid.spacing * 2) / 3
                        height: 64
                        radius: 16
                        color: current
                            ? Qt.alpha(root.nord8, root.surfaceOpacity)
                            : Qt.alpha(root.nord1, root.surfaceOpacity)

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 28; height: 28
                            path: modelData.icon
                            fill: modelData.filled
                            iconColor: parent.current ? root.nord0 : root.nord6
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pendingTlpProfile = modelData.profile;
                                tlpPendingTimer.restart();
                                tlpSetProc.profile = modelData.profile;
                                tlpSetProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }

    // Wallpaper picker, opened on demand from the wallpaper keybind.
    PanelWindow {
        id: wallpaperBar
        visible: root.wallpaperPickerVisible
        anchors { bottom: true; left: true; right: true }
        height: 500
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wallpaperPickerVisible
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        BackgroundEffect.blurRegion: Region {
            item: wallpaperBackground
            radius: wallpaperBackground.radius
        }

        mask: Region {
            item: wallpaperBackground
            radius: wallpaperBackground.radius
        }

        GradientBorder {
            id: wallpaperBackground
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -16
            width: 800
            height: 340
            color: Qt.alpha(root.nord0, root.surfaceOpacity)
            radius: 16
            clip: true

            WallpaperModule {
            }
        }
    }
}
