# Boring shell

## Bar tools

The launcher and wallpaper picker replace the top bar's contents. Their shortcuts
morph the same surface directly into the selected tool in 180ms, including while
the bar is hidden. Search takes keyboard focus immediately; no bar reveal or
attached panel animation runs first. Closing returns to the normal bar if held
open, or hides the surface otherwise. Other bar menus keep their attached layout.

Both tools use the original launcher's borderless search row, 16px Outfit text,
magnifier and subtle gradient outline. The search row stays 46px tall, matching
the normal bar; results and wallpaper previews extend below it on the same surface.
Closing clears the compositor blur explicitly, then keeps the transparent layer
mapped for another 32ms before hiding it to avoid a stale blur flash.

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
surface uses the top bar's Nord palette, opacity, border and blur. Like the clock
and contribution grid, it stays behind application windows and passes clicks
through without reserving workspace or taking keyboard focus.

The widget is inset 12px from the screen edges while the bar is hidden. It follows
the normal bar's animation downward to keep 12px of clearance when it appears.
Launcher results and wallpaper previews do not change this position. The
GitHub contribution grid sits 12px below it and moves with it. Set
`systemMonitorEnabled` on `Boring` to hide the meters; the grid then uses the top
position with the same bar clearance.

The first top-right control toggles the CPU/RAM widget, replacing the GIF control.
The clock and GitHub grid retain their separate toggles. The GIF overlay is off
by default and is no longer loaded by the shell.

`SystemMetrics.qml` reads `/proc/stat` and `/proc/meminfo` directly once a second,
without spawning polling processes. CPU usage is calculated between consecutive
samples; RAM usage excludes available cache. Polling pauses while the widget is
hidden. Check the calculations with `node boring/lib/system_metrics.test.mjs`
from the parent Quickshell directory.

## GitHub contribution grid

`GithubContributions.qml` displays the latest 10 weeks of GitHub contributions
in a 10×7 grid at the top-left of the desktop. It uses the Wayland bottom layer,
stays underneath application windows, and does not reserve workspace or take
keyboard focus. The grid sits on the same translucent Nord surface as the system
monitor, with a soft border and background blur.

Set `githubUsername` in `shell.qml` to change the account (default: `melovink`).
The top-right toggle bar's GitHub icon shows or hides the grid.
The grid is inset 12px from the left screen edge and sits below the CPU/RAM
widget, matching Hyprland's `gaps_out` setting. Its `cellSize` (7) and
`cellSpacing` (2) control its size.

`github_contributions.py` uses Python's standard library to read GitHub's public
calendar, including daily counts and contribution levels. No token is required.
The grid refreshes every 30 minutes and keeps the last successful response in
Quickshell's cache for offline use.

Check the calendar parser and offline fallback with
`python3 -B -m unittest discover -s boring -p 'test_github_contributions.py'`
from the parent Quickshell directory.
