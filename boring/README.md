# Boring shell

## Top bar states

The top bar uses a vertical slate gradient from `#2E3440` to `#7787A6` at 45%
opacity, compositor blur, a fine edge highlight, and a soft black shadow. Its idle
pill contains only the workspace dots and battery chip. It is 45.5px tall, with
20px horizontal padding and a 16px gap. Its width follows the workspace count:
four workspaces give a 174px bar, and each additional dot adds 20px. The battery
chip is fully rounded (`radius = height / 2`), with a translucent charge fill
running from left to right beneath the centered percentage label. At 80%, the
fill covers 80% of its inner section. Spotlight, music, and quick settings
replace the bar surface directly, including while it is hidden.

The glass surfaces and battery chip share directional sheen and cool rim
highlights tuned to the supplied reference: light 180° at 80%, refraction 80,
depth 20, dispersion 50, frost 4 and splay 0. These optical highlights are
approximations; Quickshell's native
Wayland effect exposes a blur region, while the compositor controls the actual
backdrop blur strength.

Bind these IPC methods independently in Hyprland:

- `topBar toggleSpotlight` / `showSpotlight` / `hideSpotlight`
- `topBar toggleMusic` / `showMusic` / `hideMusic`
- `topBar toggleControlPanel` / `showControlPanel` / `hideControlPanel`
- `topBar toggleBar` / `showBar` / `hideBar`
- `topBar toggleWallpaper` / `showWallpaper` / `hideWallpaper`
- `topBar toggleWidgets`
- `topBar toggleCalendar` / `showCalendar`
- `topBar toggleVolume` / `showVolume`
- `topBar toggleNetwork` / `showNetwork`

For the current `default` configuration, use commands such as
`qs ipc -c default call topBar toggleMusic` in Hyprland's exec bindings. Change
only the final method name to select another state. Spotlight expands its
results automatically as the query changes; it does not need a separate bind.

The older `spotlightWindow toggle` endpoint remains available. The music state is
268×140px and keeps MPD seek and the reference's bare, filled previous,
play/pause, and next icons. The quick settings state is 284×284px and includes
Wi-Fi radio, notification focus, volume,
brightness, MPD playback, microphone mute, desktop widget visibility, floating
clock visibility, and the wallpaper picker. Brightness controls use
`brightnessctl`; the slider disables itself when no usable brightness device is
available. Wi-Fi radio uses `nmcli`.

Spotlight is 268px wide, with a 46px search field and up to six compact results.
An empty query shows only the search field. Search takes keyboard focus as soon as
the state opens. The launcher keeps its existing fuzzy application and AppImage
index and keyboard navigation.

The calendar, volume, network and power menus keep their attached layout; the
surface temporarily widens to accommodate them. Closing a tool returns to the
normal bar if held open, or hides the surface otherwise. The compositor blur is
cleared before the layer unmaps to avoid a stale blur flash.

## Wallpaper previews

Opening the wallpaper picker scans `~/Wallpapers` and generates missing or stale
previews in `~/Wallpapers/thumbnail/`. Previews fit within 520×384 pixels. The
generator uses AVIF when Qt's AVIF image plugin is installed and WebP otherwise;
libvips handles encoding, with ImageMagick as a fallback.

`thumbnail/index.json` remembers previews across restarts. Cached images appear
immediately, then missing previews arrive individually from a background worker
without resetting the carousel. Changing an original's size or modification time
refreshes its preview. Selecting a preview still applies the original wallpaper.
The picker releases its image delegates when closed and retains only the small
cached previews for subsequent opens.

Check cold, warm, changed-file and failed-generation behavior with
`python3 -B -m unittest discover -s boring -p 'test_wallpaper_thumbnails.py'`
from the parent Quickshell directory.

## Desktop CPU and RAM meters

`SystemMonitor.qml` displays two animated circular meters at the top-left of the
desktop, with live CPU usage, RAM usage, and used/total memory in GiB. The rounded
surface uses the top bar's slate gradient, border highlight, compositor blur, and
shadow. Like the clock and contribution grid, it stays behind application windows
and passes clicks through without reserving workspace or taking keyboard focus.

The meters default to 1.2× their original size (about 278×161px), including rings,
text, padding and corner radius. Set `sizeScale` on `SystemMonitor` to adjust the scale.

The widget is inset 12px from the screen edges while the bar is hidden. It follows
the normal bar's animation downward to keep 12px of clearance when it appears.
Launcher results and wallpaper previews do not change this position. The
GitHub contribution grid sits 12px below it and moves with it. The quick settings
panel toggles the meters, image, and contribution grid together; the clock has a
separate toggle there. The GIF overlay is off by default and is no longer loaded
by the shell.

`SystemMetrics.qml` reads `/proc/stat` and `/proc/meminfo` directly every 2000ms,
without spawning polling processes. CPU usage is calculated between consecutive
samples; RAM usage excludes available cache. Polling pauses while the widget is
hidden. Check the calculations with `node boring/lib/system_metrics.test.mjs`
from the parent Quickshell directory.

## Desktop image

`ImageWidget.qml` displays `forDisplayOnly/uuberu.jpg` in a square beside the GitHub
grid, separated by 12px. The square follows the grid's height (112px by default).
The image zooms and crops to fill the frame, with rounded corners and the same
subtle border as the other widgets. Decoding is bounded to twice the display size.

It uses the desktop bottom layer and passes clicks through. Hiding GitHub moves
the image to the left edge; the widget toggle hides it together with the meters.
It follows the normal bar's widget placement without moving for launcher results
or wallpaper previews.

## GitHub contribution grid

`GithubContributions.qml` displays the latest 10 weeks of GitHub contributions
in a 10×7 grid at the top-left of the desktop. It uses the Wayland bottom layer,
stays underneath application windows, and does not reserve workspace or take
keyboard focus. The grid sits on the same slate gradient, blur, fine border, and
drop shadow as the system monitor.

Set `githubUsername` in `shell.qml` to change the account (default: `melovink`).
The quick settings panel's desktop widgets action shows or hides the grid with the
system monitor and desktop image.
The grid is inset 12px from the left screen edge and sits below the CPU/RAM
widget, matching Hyprland's `gaps_out` setting. Its `sizeScale` defaults to 1.2×,
giving a 144×112px card with proportionally larger cells, padding and corners.
Its base `cellSize` (7) and `cellSpacing` (2) remain configurable.

`github_contributions.py` uses Python's standard library to read GitHub's public
calendar, including daily counts and contribution levels. No token is required.
The grid refreshes every 30 minutes and keeps the last successful response in
Quickshell's cache for offline use.

Check the calendar parser and offline fallback with
`python3 -B -m unittest discover -s boring -p 'test_github_contributions.py'`
from the parent Quickshell directory.
