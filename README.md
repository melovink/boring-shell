# Boring shell

A Quickshell desktop shell with an integrated Spotlight application launcher.

Run the shell from this directory:

```sh
quickshell -p .
```

- [`boring/`](boring/README.md) contains the desktop shell and its widgets.
- [`spotlight/`](spotlight/README.md) contains the application launcher, toggled
  with `Alt+Space`.
- The top bar transforms directly into the launcher or wallpaper picker, including
  when hidden. `shell.qml` starts the shell and launcher in one process.

This directory is the root of the `melovink/boring-shell` Git repository.

Run the existing checks from this directory:

```sh
python3 -B -m unittest discover -s boring -p 'test_github_contributions.py'
python3 -B -m unittest discover -s boring -p 'test_wallpaper_thumbnails.py'
node spotlight/lib/fuzzy.test.mjs
node boring/lib/system_metrics.test.mjs
```
