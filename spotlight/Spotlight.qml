import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "lib/fuzzy.js" as Fuzzy

Item {
    id: root

    // ---- Palette ----
    // Keep Spotlight's state local to this component while hosting it inside Boring's
    // Quickshell process.
    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord2: "#434C5E"
    property color nord6: "#ECEFF4"
    property string fontPrimary: "Outfit"
    readonly property real surfaceOpacity: 0.69

    // ---- Geometry ----
    // The panel is a fixed 680 wide and animates between a bare search bar and
    // panelMaxRows visible rows; nothing below ever exceeds the width.
    readonly property int panelWidth: 580
    readonly property int panelMaxRows: 9
    // Extra vertical breathing room keeps app names and icons legible.
    readonly property int rowHeight: 48
    readonly property int fieldTopMargin: 22
    readonly property int fieldHeight: 40
    readonly property int dividerTop: 66
    readonly property int listTop: 76
    // Keep the final row clear of the panel's large rounded bottom corners,
    // but keep the empty search bar compact.
    readonly property int listBottomMargin: results.length > 0 ? 24 : 12
    readonly property int listRows: Math.min(results.length, panelMaxRows)
    readonly property int panelHeight: listTop + listRows * rowHeight + listBottomMargin
    readonly property int shadowPad: 46
    // Visible top edge of the panel at ~22% down the screen, as macOS Spotlight sits.
    readonly property int panelTopMargin: 232
    // Tune the Spotlight fade here. The actual blur radius is controlled by
    // ../hypr/modules/decorations.lua under decoration.blur.size and passes.
    readonly property int fadeDuration: 180

    readonly property string appImageDir: (Quickshell.env("HOME") || "") + "/AppImage"
    readonly property string iconCacheDir: Quickshell.cacheDir + "/appimages"

    // ---- State ----
    property bool shown: false
    // Keep the transparent layer alive for one compositor frame while its blur
    // region is cleared. Hiding it immediately can leave one stale blurred frame.
    property bool surfaceVisible: false
    property bool blurActive: false
    property real visualOpacity: 0
    property string query: ""
    property int selectedIndex: 0
    property var appImages: []
    property var iconMap: ({})
    property int iconRevision: 0
    property bool iconsBusy: false
    readonly property string focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    // ---- Index ----
    // DesktopEntries.applications is already free of Hidden/NoDisplay entries.
    // Names are deduped first-wins because DesktopEntry does not expose which directory
    // its .desktop came from, so ordering in the model is the only priority signal there is.
    readonly property var allApps: {
        var out = [];
        var seen = {};
        var entries = DesktopEntries.applications.values;
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i];
            if (!e || !e.name) continue;
            var key = e.name.toLowerCase();
            if (seen[key]) continue;
            seen[key] = true;
            out.push({
                id: e.id,
                name: e.name,
                genericName: e.genericName || "",
                keywords: e.keywords || [],
                icon: e.icon || "",
                iconFile: "",
                kind: "desktop",
                entry: e
            });
        }
        // AppImages are appended verbatim and deliberately NOT deduped against native
        // entries: a name shared with a real desktop entry is meant to show two rows.
        for (var j = 0; j < root.appImages.length; j++) out.push(root.appImages[j]);
        return out;
    }

    // An empty query intentionally yields no rows at all, so this is only ever
    // non-empty while something has actually been typed.
    // A blank query deliberately yields nothing: an empty Spotlight shows only the
    // search bar, not the whole catalogue.
    property var results: root.query.trim().length === 0 ? [] : Fuzzy.rank(root.allApps, root.query, null)

    onResultsChanged: {
        if (root.selectedIndex >= root.results.length) root.selectedIndex = 0;
    }
    onShownChanged: {
        if (!root.shown) root.query = "";
    }

    Timer {
        id: blurTeardownTimer
        interval: 32
        onTriggered: {
            root.surfaceVisible = false;
            root.visualOpacity = 0;
        }
    }

    NumberAnimation {
        id: fadeAnimation
        target: root
        property: "visualOpacity"
        duration: root.fadeDuration
        easing.type: Easing.OutCubic
        onFinished: {
            // Keep the blur region active for the whole fade, then remove it and
            // leave the transparent layer up for one compositor frame.
            if (!root.shown) {
                root.blurActive = false;
                blurTeardownTimer.restart();
            }
        }
    }

    IpcHandler {
        target: "spotlightWindow"
        function toggle(): void { root.toggle(); }
        function show(): void { root.show(); }
        function hide(): void { root.hide(); }
    }

    // ---- Scanning ~/AppImage ----
    // A single find invocation yields path, size, mtime and mode for every AppImage.
    // %s/%T@ give the icon cache its invalidation key; %m lets us skip non-executables.
    Process {
        id: scanProc
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f -iname '*.appimage' -printf '%p|%s|%T@|%m\\n' 2>/dev/null", "sh", root.appImageDir]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.consumeScanLine(line)
        }
        onExited: root.scanFinished()
    }

    function scanAppImages(): void {
        root.appImages = [];
        scanProc.running = true;
    }

    function consumeScanLine(line): void {
        if (!line || line.trim() === "") return;
        var parts = line.split("|");
        if (parts.length < 4) return;
        // find -printf %m is octal; 0o111 is 73.
        var mode = parseInt(parts[3], 8);
        if (isNaN(mode) || (mode & 73) === 0) return;
        var path = parts[0];
        var base = path.substring(path.lastIndexOf("/") + 1);
        root.appImages = root.appImages.concat([{
            id: base,
            name: prettify(base),
            genericName: "",
            keywords: [],
            icon: "",
            iconFile: root.iconMap[path] || "",
            kind: "appimage",
            path: path
        }]);
    }

    function prettify(base): string {
        var stem = base.replace(/\.(AppImage|appimage)$/, "");
        stem = stem.replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim();
        var words = stem.split(" ");
        for (var i = 0; i < words.length; i++)
            if (words[i].length > 0) words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1);
        return words.join(" ");
    }

    function scanFinished(): void {
        // Only pay for extraction when something is genuinely uncached; the script
        // short-circuits on existing files, so this is cheap to re-run.
        for (var i = 0; i < root.appImages.length; i++)
            if (!root.appImages[i].iconFile) { root.extractIcons(); return; }
    }

    // ---- AppImage icon cache ----
    // Each AppImage's embedded .DirIcon is unpacked once into the cache dir, keyed on
    // size+mtime so a rebuilt image re-extracts and a cleared cache simply redoes the work.
    // Extraction runs in a throwaway working dir so ~/AppImage is never written to.
    // The v2 key prefix invalidates entries written by an earlier extraction strategy.
    readonly property string iconExtractScript:
        "CACHE=\"$1\"; DIR=\"$2\"\n" +
        "mkdir -p \"$CACHE\" || exit 0\n" +
        "for f in \"$DIR\"/*; do\n" +
        "  [ -f \"$f\" ] || continue\n" +
        "  case \"$f\" in *.AppImage|*.appimage) ;; *) continue ;; esac\n" +
        "  key=v2_$(stat -c '%s-%Y' \"$f\")_$(basename \"$f\" | tr -c 'a-zA-Z0-9' '_')\n" +
        "  dest=\"$CACHE/$key.icon\"\n" +
        "  if [ ! -f \"$dest\" ]; then\n" +
        "    tmp=\"$CACHE/.tmp\"\n" +
        "    rm -rf \"$tmp\"; mkdir -p \"$tmp\"\n" +
        "    ( cd \"$tmp\" && \"$f\" --appimage-extract .DirIcon >/dev/null 2>&1 )\n" +
        "    link=\"$tmp/squashfs-root/.DirIcon\"\n" +
        "    hops=0\n" +
        "    while [ -L \"$link\" ] && [ \"$hops\" -lt 6 ]; do\n" +
        "      tgt=$(readlink \"$link\")\n" +
        "      [ -n \"$tgt\" ] || break\n" +
        "      while [ \"${tgt#../}\" != \"$tgt\" ]; do tgt=\"${tgt#../}\"; done\n" +
        "      ( cd \"$tmp\" && \"$f\" --appimage-extract \"${tgt#/}\" >/dev/null 2>&1 )\n" +
        "      link=\"$tmp/squashfs-root/${tgt#/}\"\n" +
        "      hops=$((hops+1))\n" +
        "    done\n" +
        "    cp -L \"$link\" \"$dest\" >/dev/null 2>&1\n" +
        "    rm -rf \"$tmp\"\n" +
        "  fi\n" +
        "  [ -f \"$dest\" ] && echo \"$f|$key\"\n" +
        "done\nexit 0"

    Process {
        id: iconProc
        command: ["sh", "-c", root.iconExtractScript, "sh", root.iconCacheDir, root.appImageDir]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.consumeIconLine(line)
        }
        onExited: {
            root.iconsBusy = false;
            root.iconRevision++;
        }
    }

    function extractIcons(): void {
        if (root.iconsBusy) return;
        root.iconsBusy = true;
        iconProc.running = true;
    }

    function consumeIconLine(line): void {
        if (!line) return;
        var parts = line.split("|");
        if (parts.length < 2) return;
        var path = parts[0];
        var dest = root.iconCacheDir + "/" + parts[1] + ".icon";
        // iconMap is keyed by path and rebuilt rather than mutated so bindings re-evaluate.
        var map = {};
        for (var k in root.iconMap) map[k] = root.iconMap[k];
        map[path] = dest;
        root.iconMap = map;
        for (var i = 0; i < root.appImages.length; i++) {
            if (root.appImages[i].path !== path) continue;
            // Mutate in place: results holds the same object references, so the row's
            // icon source updates without re-running the fuzzy rank.
            root.appImages[i].iconFile = dest;
            break;
        }
        root.iconRevision++;
    }

    // ---- Actions ----
    function show(): void {
        blurTeardownTimer.stop();
        fadeAnimation.stop();
        root.surfaceVisible = true;
        root.blurActive = true;
        root.query = "";
        root.selectedIndex = 0;
        root.shown = true;
        fadeAnimation.from = root.visualOpacity;
        fadeAnimation.to = 1;
        fadeAnimation.restart();
        root.scanAppImages();
    }
    function hide(): void {
        fadeAnimation.stop();
        root.shown = false;
        if (!root.surfaceVisible) {
            root.blurActive = false;
            root.visualOpacity = 0;
            return;
        }
        fadeAnimation.from = root.visualOpacity;
        fadeAnimation.to = 0;
        fadeAnimation.restart();
    }
    function toggle(): void {
        if (root.shown) { root.hide(); return; }
        root.show();
    }

    function launch(item): void {
        if (!item) return;
        // Release the keyboard before the app maps, otherwise the new window inherits
        // focus from our exclusive-focus layer surface.
        root.hide();
        if (item.kind === "appimage") Quickshell.execDetached([item.path]);
        else if (item.entry) item.entry.execute();
    }

    function moveSelection(delta): void {
        var n = root.results.length;
        if (n === 0) return;
        var i = root.selectedIndex + delta;
        // No wrap: a filtered list should stop at its ends.
        if (i < 0) i = 0;
        if (i > n - 1) i = n - 1;
        root.selectedIndex = i;
    }

    function selectIndex(i): void {
        if (i < 0 || i >= root.results.length) return;
        root.selectedIndex = i;
    }

    function activateSelected(): void {
        if (root.results.length === 0) return;
        root.launch(root.results[root.selectedIndex]);
    }

    function activateIndex(index): void {
        if (index < 0 || index >= root.results.length) return;
        root.launch(root.results[index]);
    }

    Component.onCompleted: root.scanAppImages()

    // ---- Windows ----
    // One window per monitor: every screen gets the dim backdrop like Spotlight, but only
    // the focused monitor carries the panel and the exclusive keyboard focus.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: spotlightWindow
            required property var modelData
            screen: modelData

            visible: root.surfaceVisible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }
            HyprlandWindow.opacity: root.visualOpacity

            BackgroundEffect.blurRegion: Region {
                // Blur the desktop behind Spotlight, but remove it before the
                // layer is hidden so closing cannot flash a stale blurred frame.
                item: root.blurActive ? spotlightWindow.contentItem : null
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "spotlight"
            WlrLayershell.keyboardFocus: root.shown && modelData.name === root.focusedScreen
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

            // Transparent click-catcher: the compositor blur is the only full-screen
            // backdrop; the panel itself supplies the translucent surface.
            MouseArea {
                anchors.fill: parent
                visible: root.surfaceVisible
                enabled: root.shown
                onClicked: root.hide()
            }

            SpotlightPanel {
                id: panel
                visible: root.surfaceVisible && modelData.name === root.focusedScreen
                shown: root.shown
                x: Math.round((modelData.width - width) / 2)
                y: Math.max(0, Math.round(modelData.height * 0.22) - root.shadowPad)

                panelWidth: root.panelWidth
                panelHeight: root.panelHeight
                shadowPad: root.shadowPad
                rowHeight: root.rowHeight
                fieldTopMargin: root.fieldTopMargin
                fieldHeight: root.fieldHeight
                dividerTop: root.dividerTop
                listTop: root.listTop
                listBottomMargin: root.listBottomMargin
                iconRevision: root.iconRevision

                nord0: root.nord0
                nord1: root.nord1
                nord2: root.nord2
                nord6: root.nord6
                surfaceOpacity: root.surfaceOpacity
                fontPrimary: root.fontPrimary

                results: root.results
                selectedIndex: root.selectedIndex

                onQueryEdited: text => {
                    root.query = text;
                    root.selectedIndex = 0;
                }
                onMoveSelection: delta => root.moveSelection(delta)
                onSelectIndex: i => root.selectIndex(i)
                onActivate: root.activateSelected()
                onActivateIndex: i => root.activateIndex(i)
                onDismiss: root.hide()
            }
        }
    }
}
