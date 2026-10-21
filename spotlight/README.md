# Spotlight - Project Documentation

A macOS-Spotlight-style launcher for applications and AppImages, hosted alongside
the `boring` shell in the unified Quickshell process. Application icons use
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
  launches, `Esc` or a click on the backdrop dismisses.
- Opening clears the query and refocuses the field.
- Every monitor gets the dimmed backdrop; only the focused monitor carries the
  panel and exclusive keyboard focus.
- The keyboard is released before an app maps, otherwise the new window would
  inherit focus from our exclusive-focus layer surface.

IPC target `spotlightWindow` exposes `toggle`, `show` and `hide`. Note that the
`quickshell ipc` CLI cannot call a function literally named `show` — it parses
it as the `ipc show` subcommand — so prefer `toggle`.

## Layout Notes

The panel is 680px wide and sits about 22% down the focused monitor. Its height
is driven by the result count: 88px with no rows, up to 448px at 9 visible rows
of 40px. The window is sized with extra padding on all sides so the shadow has
room and is not clipped at the screen edge.

The shadow is a `MultiEffect` on a layer that contains nothing but a rounded
black caster. Pointing `MultiEffect.source` at the panel body instead is a trap:
it re-renders that item stretched across the effect's whole rect, which shows up
as a large ghost panel behind the real one. A soft shadow also needs
`blurEnabled`, which would blur the text, so isolating the caster in its own
layer keeps the shadow soft and the content sharp and drawn only once.
