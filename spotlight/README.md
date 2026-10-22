# Spotlight - Project Documentation

A Spotlight-style launcher for applications and AppImages, integrated into the
`boring` shell's top bar in the unified Quickshell process. Application icons use
the installed `yet-another-monochrome-icon-set` theme, matching the GTK icon
theme configured on the desktop.

## What It Launches

Applications only. Files, folders and shell commands are deliberately **not**
indexed, which keeps the result list short and predictable.

- Every entry from `Quickshell.DesktopEntries.applications` (`NoDisplay` excluded).
- Every executable `~/AppImage/*.AppImage`, named from its prettified filename
  (each word capitalised). Re-scanned on every open, so new images appear
  immediately without a restart.

Desktop-entry names are de-duplicated first-wins. Quickshell does not expose the
`.desktop` file a `DesktopEntry` came from, so a user-local entry cannot be
preferred over a system one with the same name.

## Search

`lib/fuzzy.js` ranks each token of the query against an entry:

| Tier | Match |
| ---- | ----- |
| 0 | query prefixes the entry name |
| 1 | substring of name, generic name or a keyword |
| 2 | loose subsequence of those fields |
| 3 | `Exec=`/`command`, or an AppImage path |

Tokens are AND-ed and tier scores summed, so `fire fox` still finds Firefox and
tighter matches stay above looser ones. Ties break alphabetically. `Exec=` sits
in its own bottom tier: typing a command fragment surfaces an app without long
exec strings crowding out real name matches.

An empty query shows only the search field, never the whole catalogue.

Run the tests with `node lib/fuzzy.test.mjs`.

## AppImage Icons

Each image's embedded `.DirIcon` is unpacked once into
`Quickshell.cacheDir/appimages`, keyed on filename plus size and mtime so a
rebuilt image re-extracts while a cleared cache simply redoes the work.

Extraction always runs in a throwaway working directory, so `~/AppImage` is
never written to. `.DirIcon` is usually a symlink into the image root and
frequently a *chain* of them (`darktable.AppImage` goes `.DirIcon ->
darktable.svg -> usr/share/icons/.../darktable.svg`), so the script walks the
chain and extracts each hop before dereferencing the link. Images without a
usable `.DirIcon` fall back to `application-x-executable`.

## Behaviour

- `ALT+SPACE` toggles the launcher through the unified Quickshell process.
- `Up`/`Down` move without wrapping, `Home`/`End` jump to the ends, `Enter`
  launches, `Esc` or a click outside the bar dismisses.
- Opening clears the query and refocuses the field.
- The bar transforms directly into the launcher in 180ms, even while hidden.
  The launcher shares its surface, blur and input mask.
  Opening another bar menu or receiving a notification dismisses it.
- The keyboard is released before an app maps, otherwise the new window would
  inherit focus from our exclusive-focus layer surface.

IPC target `spotlightWindow` exposes `toggle`, `show` and `hide`. Note that the
`quickshell ipc` CLI cannot call a function literally named `show` — it parses
it as the `ipc show` subcommand — so prefer `toggle`.

## Layout Notes

The launcher replaces the top bar's modules, matching the wallpaper picker.
Its width is up to 400px. The borderless search row uses 16px Outfit
text and magnifier, and stays 46px tall to match the normal bar. Up to nine visible
48px result rows extend below a divider, with 24px of bottom clearance. Additional
results scroll within the panel. Desktop widgets keep their normal bar placement
as results resize the launcher.

`Spotlight.qml` extends the shell's `AnimatedPopup` and owns indexing and selection;
`SpotlightPanel.qml` supplies the search field and result list. The bar supplies
the background and border. Running `quickshell -p spotlight` also starts
the bar that hosts the launcher.
