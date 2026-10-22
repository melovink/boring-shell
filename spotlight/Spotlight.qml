import QtQuick
import Quickshell
import Quickshell.Io
import "../boring" as Boring
import "lib/fuzzy.js" as Fuzzy

// The launcher shares the top bar's surface, animation, input mask and blur.
Boring.AnimatedPopup {
    id: root

    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property string fontPrimary: "Inter"
    property real surfaceOpacity: 0.78
    property var otherPopups: []

    hold: true
    panelWidth: 640
    panelHeight: launcherPanel.implicitHeight + padding * 2

    readonly property string appImageDir: (Quickshell.env("HOME") || "") + "/AppImage"
    readonly property string iconCacheDir: Quickshell.cacheDir + "/appimages"

    // ---- State ----
    property string query: ""
    property int selectedIndex: 0
    property var appImages: []
    property var iconMap: ({})
    property int iconRevision: 0
    property bool iconsBusy: false

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
    onVisibleChanged: {
        root.query = "";
        root.selectedIndex = 0;
        if (visible) {
            for (var i = 0; i < root.otherPopups.length; i++)
                root.otherPopups[i].visible = false;
            root.scanAppImages();
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
    function show(): void { root.visible = true; }
    function hide(): void { root.visible = false; }
    function toggle(): void { root.visible = !root.visible; }

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

    SpotlightPanel {
        id: launcherPanel
        anchors.fill: parent
        shown: root.visible
        results: root.results
        selectedIndex: root.selectedIndex
        iconRevision: root.iconRevision
        nord1: root.nord1
        nord4: root.nord4
        nord6: root.nord6
        nord8: root.nord8
        surfaceOpacity: root.surfaceOpacity
        fontPrimary: root.fontPrimary

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
