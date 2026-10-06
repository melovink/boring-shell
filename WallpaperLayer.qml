import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaperLayer

    // Span the full screen so we can center content freely,
    // but the window itself is input-transparent and stays behind everything.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Bottom layer → always behind regular windows
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    }
