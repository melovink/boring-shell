pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: wallpaperUI
    anchors.fill: parent
    property color nord1
    property color nord4
    property color nord6
    property color nord8
    property real surfaceOpacity: 0.8
    property string fontPrimary: "Outfit"
    property int searchHeight: 46
    property int previewHeight: 176
    property bool active: false
    property bool shown: active
    property url wallpaperDirectory: "file:///home/melovink/Wallpapers"
    property string thumbnailScript: Quickshell.shellPath("boring/wallpaper_thumbnails.py")
    property var entries: []
    property var thumbnails: ({})
    property bool refreshPending: false
    implicitHeight: searchHeight + 12 + previewHeight + 16
    readonly property string directoryPath: decodeURIComponent(
        wallpaperDirectory.toString().replace(/^file:\/\//, ""))
    readonly property var filteredEntries: {
        const query = wallpaperSearch.text.trim().toLowerCase();
        return query === "" ? entries
            : entries.filter(entry => entry.name.toLowerCase().includes(query));
    }
    signal closeRequested()

    function focusSearch(): void { wallpaperSearch.focusSearch(); }
    function resetSearch(): void { wallpaperSearch.text = ""; }

    function applyIndex(items): void {
        const previews = {};
        for (const item of items) {
            if (item.thumbnail) previews[item.path] = item.thumbnail;
        }
        thumbnails = previews;
        // Thumbnail updates should not rebuild the carousel or reset its scroll.
        if (items.length !== entries.length
            || items.some((item, i) => item.path !== entries[i].path || item.name !== entries[i].name)) {
            entries = items;
        }
    }

    function refreshThumbnails(): void {
        if (thumbnailProcess.running) {
            refreshPending = true;
            return;
        }
        refreshPending = false;
        thumbnailProcess.running = true;
    }

    function consumeThumbnailEvent(line): void {
        try {
            const event = JSON.parse(line);
            if (event.type === "index") applyIndex(event.entries);
            else if (event.type === "thumbnail") {
                const previews = Object.assign({}, thumbnails);
                previews[event.path] = event.thumbnail;
                thumbnails = previews;
            } else if (event.type === "error") {
                console.warn("Wallpaper preview:", event.message);
            }
        } catch (error) {
            console.warn("Invalid wallpaper preview response:", error);
        }
    }

    // Persisted entries are ready before the picker opens or a new scan finishes.
    FileView {
        id: cachedIndex
        path: wallpaperUI.directoryPath + "/thumbnail/index.json"
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const index = JSON.parse(cachedIndex.text());
                if (index.version === 1 && Array.isArray(index.entries))
                    wallpaperUI.applyIndex(index.entries);
            } catch (error) {}
        }
    }

    Process {
        id: thumbnailProcess
        command: ["python3", "-B", wallpaperUI.thumbnailScript, wallpaperUI.directoryPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => wallpaperUI.consumeThumbnailEvent(line)
        }
        onExited: {
            if (wallpaperUI.refreshPending && wallpaperUI.active)
                Qt.callLater(wallpaperUI.refreshThumbnails);
            else wallpaperUI.refreshPending = false;
        }
    }

    SearchBar {
        id: wallpaperSearch
        anchors.top: parent.top
        width: parent.width
        height: wallpaperUI.searchHeight
        placeholderText: "Search wallpapers"
        shown: wallpaperUI.shown
        fontPrimary: wallpaperUI.fontPrimary
        nord1: wallpaperUI.nord1
        nord6: wallpaperUI.nord6
        surfaceOpacity: wallpaperUI.surfaceOpacity
        onKeyPressed: event => {
            if (event.key === Qt.Key_Escape) {
                text = "";
                wallpaperUI.closeRequested();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        x: wallpaperSearch.horizontalPadding
        y: wallpaperUI.searchHeight
        width: Math.max(0, parent.width - x * 2)
        height: 1
        color: Qt.alpha("#434C5E", wallpaperUI.surfaceOpacity)
        opacity: 0.75
    }

    Process {
        id: awwwProcess
        property string targetFile: ""
        command: ["awww", "img", "--transition-type", "wipe", "--transition-angle", "45", targetFile]
        onRunningChanged: {
            if (!running) {
                wallpaperSearch.text = "";
                wallpaperUI.closeRequested();
            }
        }
    }

    ListView {
        id: carousel
        anchors.top: wallpaperSearch.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        
        orientation: ListView.Horizontal
        spacing: 12
        // Keep the index warm while releasing hidden image delegates.
        model: wallpaperUI.active ? wallpaperUI.filteredEntries : null
        cacheBuffer: 260
        clip: true
        
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5000
        maximumFlickVelocity: 8000
        
        delegate: Rectangle {
            required property var modelData
            id: tile
            // Keep a stable tile width while the bar contracts; tiny delegates
            // otherwise cause ListView to populate dozens of cached images.
            width: 260
            height: carousel.height
            radius: 12
            color: Qt.alpha(wallpaperUI.nord1, wallpaperUI.surfaceOpacity)
            clip: true
            
            Image {
                anchors.fill: parent
                source: wallpaperUI.thumbnails[tile.modelData.path] || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(520, 384)
                cache: true
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: !wallpaperUI.thumbnails[tile.modelData.path]
                text: tile.modelData.name
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: wallpaperUI.nord4
                font.family: wallpaperUI.fontPrimary
                font.pixelSize: 12
            }
            
            MouseArea {
                anchors.fill: parent
                enabled: !awwwProcess.running
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    awwwProcess.targetFile = tile.modelData.path;
                    awwwProcess.running = true;
                }
            }
        }
    }

    Text {
        anchors.centerIn: carousel
        visible: wallpaperUI.filteredEntries.length === 0
        text: thumbnailProcess.running && wallpaperUI.entries.length === 0
            ? "Loading wallpapers…" : "No wallpapers found"
        color: wallpaperUI.nord4
        font.family: wallpaperUI.fontPrimary; font.pixelSize: 13
    }
}
