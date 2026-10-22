# Boring shell

## GitHub contribution grid

`GithubContributions.qml` displays the latest 10 weeks of GitHub contributions
in a 10×7 grid at the top-left of the desktop. It uses the Wayland bottom layer,
stays underneath application windows, and does not reserve workspace or take
keyboard focus.

Set `githubUsername` in `shell.qml` to change the account (default: `melovink`).
The top-right toggle bar's GitHub icon shows or hides the grid.
The grid is inset 12 px from the top-left screen edges to match Hyprland's
`gaps_out` setting, and stays beneath the top bar. Its `cellSize` (7) and
`cellSpacing` (2) control its size.

`github_contributions.py` uses Python's standard library to read GitHub's public
calendar, including daily counts and contribution levels. No token is required.
The grid refreshes every 30 minutes and keeps the last successful response in
Quickshell's cache for offline use.

Check the calendar parser and offline fallback with
`python3 -B -m unittest discover -s boring -p 'test_github_contributions.py'`
from the parent Quickshell directory.
