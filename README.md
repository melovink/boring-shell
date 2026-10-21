# Boring shell

## GitHub contribution grid

`GithubContributions.qml` displays a year of GitHub contributions at the top-left
of the desktop. It uses the Wayland bottom layer, stays underneath application
windows, and does not reserve workspace or take keyboard focus.

Set `githubUsername` in `shell.qml` to change the account (default: `melovink`).
The top-right toggle bar's GitHub icon shows or hides the grid.
The component's `topMargin` (80), `edgeMargin` (24), `cellSize` (7), and
`cellSpacing` (2) control placement and size.

`github_contributions.py` uses Python's standard library to read GitHub's public
calendar, including daily counts and contribution levels. No token is required.
The grid refreshes every 30 minutes and keeps the last successful response in
Quickshell's cache for offline use. Hover a square to see its count and date in
the footer; click the header to open the GitHub profile.

Check the calendar parser and offline fallback with
`python3 -B -m unittest discover -s boring -p 'test_github_contributions.py'`
from the parent Quickshell directory.
