import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: wallpaperUI
    anchors.fill: parent

    TextInput {
        id: wallpaperSearch
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: 300
        height: 30
        color: root.nord6
        font.pixelSize: 18
        font.family: root.fontPrimary
        horizontalAlignment: TextInput.AlignHCenter
        
        onVisibleChanged: {
            if (visible) {
                forceActiveFocus();
            }
        }
        Keys.onEscapePressed: {
            text = "";
            root.bottomBarMode = "cava";
            cavaBar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        }
    }

    Text {
        text: "Search Wallpaper..."
        color: root.nord6
        font.pixelSize: 18
        font.family: root.fontPrimary
        anchors.centerIn: wallpaperSearch
        opacity: wallpaperSearch.text === "" && !wallpaperSearch.activeFocus ? 0.5 : 0
    }

    FolderListModel {
        id: folderModel
        folder: "file:///home/melovink/Wallpapers"
        nameFilters: wallpaperSearch.text.trim() === "" ? ["*.png", "*.jpg", "*.jpeg", "*.gif"] : ["*" + wallpaperSearch.text + "*.png", "*" + wallpaperSearch.text + "*.jpg", "*" + wallpaperSearch.text + "*.jpeg", "*" + wallpaperSearch.text + "*.gif"]
        showDirs: false
    }

    Process {
        id: awwwProcess
        property string targetFile: ""
        command: ["awww", "img", "--transition-type", "wipe", "--transition-angle", "45", targetFile]
        onRunningChanged: {
            if (!running) {
                wallpaperSearch.text = "";
                root.bottomBarMode = "cava";
                cavaBar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
            }
        }
    }

    ListView {
        id: carousel
        anchors.top: parent.top
        anchors.topMargin: 50
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        
        orientation: ListView.Horizontal
        spacing: 20
        model: folderModel
        
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5000
        maximumFlickVelocity: 8000
        
        delegate: Rectangle {
            width: 320
            height: carousel.height
            radius: 12
            color: Qt.alpha(root.nord1, root.surfaceOpacity)
            clip: true
            
            Image {
                anchors.fill: parent
                source: fileUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    awwwProcess.targetFile = filePath;
                    awwwProcess.running = true;
                }
            }
        }
    }
}
