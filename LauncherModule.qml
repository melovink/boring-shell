import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: launcherUI
    anchors.fill: parent

    property var allApps: []
    ListModel {
        id: appsModel
    }

    Process {
        id: appsProc
        command: ["python3", "/home/melovink/.config/quickshell/boring/get_apps.py"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim() !== "") {
                    try {
                        var app = JSON.parse(line);
                        launcherUI.allApps.push(app);
                        appsModel.append(app);
                    } catch(e) {}
                }
            }
        }
    }

    Process {
        id: launcherProc
        property string appId: ""
        command: ["sh", "-c", "gtk-launch \"$1\" >/dev/null 2>&1 &", "sh", appId]
    }

    TextInput {
        id: launcherInput
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 40
        height: 40
        color: root.nord6
        font.pixelSize: 16
        font.family: root.fontPrimary
        
        onVisibleChanged: {
            if (visible) {
                forceActiveFocus();
            }
        }
        
        onTextChanged: {
            appsModel.clear();
            var query = text.toLowerCase();
            for (var i = 0; i < launcherUI.allApps.length; i++) {
                var app = launcherUI.allApps[i];
                if (app.name.toLowerCase().indexOf(query) !== -1 || app.exec.toLowerCase().indexOf(query) !== -1) {
                    appsModel.append(app);
                }
            }
        }
        
        onAccepted: {
            if (appsModel.count > 0) {
                launcherProc.appId = appsModel.get(0).id;
                launcherProc.running = true;
            }
            // Quit the launcher immediately
            launcherInput.text = "";
            root.bottomBarMode = "cava";
            cavaBar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        }
        
        Keys.onEscapePressed: {
            text = "";
            root.bottomBarMode = "cava";
            cavaBar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        }
    }

    ListView {
        id: appListView
        anchors.top: launcherInput.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        clip: true
        
        model: appsModel
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5000
        maximumFlickVelocity: 8000
        
        delegate: ItemDelegate {
            width: ListView.view.width
            height: 50
            
            contentItem: Row {
                spacing: 16
                Image {
                    id: appIcon
                    width: 26
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: model.icon ? Quickshell.iconPath(model.icon, true) : ""
                }
                Text {
                    text: model.name
                    color: root.nord6
                    font.pixelSize: 15
                    font.family: root.fontPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            background: Rectangle {
                color: parent.hovered ? root.nord1 : "transparent"
                radius: 8
            }
            
            onClicked: {
                launcherProc.appId = model.id;
                launcherProc.running = true;
                // Quit the launcher immediately
                launcherInput.text = "";
                root.bottomBarMode = "cava";
                cavaBar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
            }
        }
    }
}
