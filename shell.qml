import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
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

    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"

    property string bottomBarMode: "cava"

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
    }

    // Data Properties
    property string volumeText: "..."
    property string wifiText: "..."
    property string networkType: "none"
    property string batteryText: "..."
    property string batteryStatus: "Unknown"
    property string mpdRawText: "Stopped"
    property string mpdText: {
        if (mpdRawText.length <= 30) return mpdRawText;
        return mpdRawText.substring(0, 30) + "...";
    }
    
    // Processes for Polling Data
    Process {
        id: mpcProc
        command: ["mpc", "current", "-f", "%artist% - %title%"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                root.mpdRawText = out !== "" ? out : "Stopped";
            }
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out.includes("[MUTED]")) {
                    root.volumeText = "Muted";
                } else {
                    var match = out.match(/Volume: ([\d\.]+)/);
                    if (match && match[1]) {
                        root.volumeText = Math.round(parseFloat(match[1]) * 100) + "%";
                    }
                }
            }
        }
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

    Process {
        id: batProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity /sys/class/power_supply/BAT*/status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
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
        id: mpdProcess
        command: ["systemd-run", "--user", "--", "kitty", "-e", "rmpc"]
    }

    property bool isFullscreen: false

    Process {
        id: syncFullscreenProc
        command: ["sh", "-c", "hyprctl activewindow -j | grep -q '\"fullscreen\": [12]'"]
        onRunningChanged: {
            if (!running && this.exitCode !== undefined) root.isFullscreen = (this.exitCode === 0);
        }
    }

    Process {
        id: hyprlandEventProc
        command: ["sh", "-c", "socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var l = line.trim();
                if (l.startsWith("fullscreen>>")) {
                    root.isFullscreen = l.substring(12) === "1";
                } else if (l.startsWith("activewindow>>")) {
                    syncFullscreenProc.running = true;
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
            syncFullscreenProc.running = true;
        }
    }

    PanelWindow {
        id: dynamicIsland
        anchors { top: true; left: true; right: true }
        height: 60
        exclusiveZone: 40
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        
        mask: Region {
            x: background.x
            y: background.y
            width: background.width
            height: background.height
        }
        
        property bool isExpanded: hoverHandler.hovered || calPopup.visible || volPopup.visible || netPopup.visible || pwrPopup.visible || trayModule.isTrayMenuOpen
        property real targetWidth: isExpanded ? 780 : 120

        Rectangle {
            id: background
            anchors.top: parent.top
            anchors.topMargin: root.isFullscreen && !dynamicIsland.isExpanded ? -54 : -16
            
            Behavior on anchors.topMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            width: dynamicIsland.targetWidth
            height: 56
            color: root.nord0
            radius: 16
            border.color: root.nord1
            border.width: 1

            Behavior on width {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            HoverHandler {
                id: hoverHandler
            }

            Row {
                id: expandedModules
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 8
                spacing: 16
                opacity: dynamicIsland.isExpanded ? 1.0 : 0.0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
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
                    fontPrimary: root.fontPrimary
                    mpdText: root.mpdText
                    mpdProcess: mpdProcess
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
                    fontPrimary: root.fontPrimary
                    batteryText: root.batteryText
                    batteryStatus: root.batteryStatus
                    pwrPopup: pwrPopup
                    otherPopups: [calPopup, volPopup, netPopup, trayModule.popup]
                }
                
                // App Tray
                TrayModule {
                    id: trayModule
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
                    fontPrimary: root.fontPrimary
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
                opacity: dynamicIsland.isExpanded ? 0.0 : 1.0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 10
            color: root.nord0
            radius: 12
            border.color: root.nord1
            border.width: 1

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

    // Volume Popup
    PopupWindow {
        id: volPopup
        anchor { item: volRect; edges: Edges.Bottom; gravity: Edges.Bottom }
        visible: false; width: 200; height: 100; color: "transparent"
        
        Process {
            id: toggleMuteProc
            command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
            onRunningChanged: if(!running) volProc.running = true
        }

        Process {
            id: setVolProc
            property double targetVol: 0.5
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetVol.toFixed(2)]
            onRunningChanged: if(!running) volProc.running = true
        }

        Rectangle {
            anchors.fill: parent; anchors.topMargin: 10; color: root.nord0; radius: 12; border.color: root.nord1
            
            Column {
                anchors.centerIn: parent; spacing: 16; width: parent.width - 32
                RowLayout {
                    width: parent.width; spacing: 8
                    Text { text: "Mute"; color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 14 }
                    Rectangle {
                        Layout.alignment: Qt.AlignRight
                        width: 40; height: 20; radius: 10
                        color: root.volumeText === "Muted" ? root.nord11 : root.nord1
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: toggleMuteProc.running = true
                        }
                    }
                }
                Slider {
                    width: parent.width
                    from: 0.0; to: 1.0; value: root.volumeText === "Muted" ? 0.0 : parseInt(root.volumeText) / 100.0
                    onValueChanged: {
                        if (pressed) {
                            setVolProc.targetVol = value
                            setVolProc.running = true
                        }
                    }
                }
            }
        }
    }

    // Network Popup
    property var wifiList: []
    Process {
        id: scanWifiProc
        command: ["sh", "-c", "nmcli -t -f ssid dev wifi | sort -u | grep -v '^$' | head -n 8"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out !== "") {
                    root.wifiList = out.split("\n");
                }
            }
        }
    }

    Process {
        id: connectWifiProc
        property string targetSsid: ""
        command: ["nmcli", "dev", "wifi", "connect", targetSsid]
        onRunningChanged: if(!running) wifiProc.running = true
    }

    PopupWindow {
        id: netPopup
        anchor { item: wifiRect; edges: Edges.Bottom; gravity: Edges.Bottom }
        visible: false; width: 220; height: 260; color: "transparent"

        Rectangle {
            anchors.fill: parent; anchors.topMargin: 10; color: root.nord0; radius: 12; border.color: root.nord1
            
            ListView {
                anchors.fill: parent
                anchors.margins: 12
                model: root.wifiList
                spacing: 8
                delegate: Rectangle {
                    width: parent.width; height: 32; radius: 8; color: root.nord1
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12; text: modelData; color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width - 24 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { connectWifiProc.targetSsid = modelData; connectWifiProc.running = true; }
                    }
                }
            }
        }
    }

    // Power/TLP Popup
    Process { id: tlpAcProc; command: ["pkexec", "tlp", "ac"] }
    Process { id: tlpBatProc; command: ["pkexec", "tlp", "bat"] }

    PopupWindow {
        id: pwrPopup
        anchor { item: batRect; edges: Edges.Bottom; gravity: Edges.Bottom }
        visible: false; width: 160; height: 120; color: "transparent"

        Rectangle {
            anchors.fill: parent; anchors.topMargin: 10; color: root.nord0; radius: 12; border.color: root.nord1
            
            Column {
                anchors.centerIn: parent; spacing: 12; width: parent.width - 24
                Rectangle {
                    width: parent.width; height: 36; radius: 8; color: root.nord1
                    Text { anchors.centerIn: parent; text: "AC Mode"; color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { tlpAcProc.running = true; pwrPopup.visible = false; } }
                }
                Rectangle {
                    width: parent.width; height: 36; radius: 8; color: root.nord1
                    Text { anchors.centerIn: parent; text: "Battery Mode"; color: root.nord6; font.family: root.fontPrimary; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { tlpBatProc.running = true; pwrPopup.visible = false; } }
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

        property bool isHovered: cavaHoverHandler.hovered
        
        mask: Region {
            x: cavaBackground.x
            y: cavaBackground.y
            width: cavaBackground.width
            height: cavaBackground.height
        }

        Rectangle {
            id: cavaBackground
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (root.bottomBarMode === "cava" && !cavaBar.isHovered) ? -66 : -16
            
            width: root.bottomBarMode === "wallpaper" ? 800 : (root.bottomBarMode === "launcher" ? 540 : 300)
            height: root.bottomBarMode === "wallpaper" ? 340 : (root.bottomBarMode === "launcher" ? 500 : 76)
            
            color: root.nord0
            radius: 16
            border.color: root.nord1
            border.width: 1
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
