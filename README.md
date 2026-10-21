# Boring shell

A Quickshell desktop shell with an integrated Spotlight application launcher.

Run both components from this directory:

```sh
quickshell -p .
```

- [`boring/`](boring/README.md) contains the desktop shell and its widgets.
- [`spotlight/`](spotlight/README.md) contains the application launcher, toggled
  with `Alt+Space`.
- `shell.qml` starts both components in one Quickshell process.

This directory is the root of the `melovink/boring-shell` Git repository.

Run the existing checks from this directory:

```sh
python3 -B -m unittest discover -s boring -p 'test_github_contributions.py'
node spotlight/lib/fuzzy.test.mjs
```
