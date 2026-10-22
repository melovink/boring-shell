import QtQuick
import QtQuick.Controls.Basic
import Qt.labs.folderlistmodel
import Quickshell.Io

Item {
    id: wallpaperUI
    anchors.fill: parent
    property color nord1
    property color nord4
    property color nord6
    property color nord8
    property real surfaceOpacity: 0.8
    property string fontPrimary
    property url wallpaperDirectory: "file:///home/melovink/Wallpapers"
    signal closeRequested()

    function focusSearch(): void { wallpaperSearch.forceActiveFocus(); }
    function resetSearch(): void { wallpaperSearch.text = ""; }

    TextField {
        id: wallpaperSearch
        anchors.top: parent.top
        width: parent.width
        height: 40
        color: wallpaperUI.nord6
        placeholderText: "Search wallpapers"
        placeholderTextColor: wallpaperUI.nord4
        font.pixelSize: 13
        font.family: wallpaperUI.fontPrimary
        selectByMouse: true
        leftPadding: 12; rightPadding: 12
        background: Rectangle {
            radius: 14
            color: Qt.alpha(wallpaperUI.nord1, wallpaperUI.surfaceOpacity)
            border.width: 1
            border.color: wallpaperSearch.activeFocus
                ? wallpaperUI.nord8 : Qt.alpha(wallpaperUI.nord4, 0.12)
        }
        Keys.onEscapePressed: {
            text = "";
            wallpaperUI.closeRequested();
        }
    }

    FolderListModel {
        id: folderModel
        folder: wallpaperUI.wallpaperDirectory
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
                wallpaperUI.closeRequested();
            }
        }
    }

    ListView {
        id: carousel
        anchors.top: wallpaperSearch.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        
        orientation: ListView.Horizontal
        spacing: 12
        model: folderModel
        clip: true
        
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5000
        maximumFlickVelocity: 8000
        
        delegate: Rectangle {
            width: Math.min(260, carousel.width)
            height: carousel.height
            radius: 12
            color: Qt.alpha(wallpaperUI.nord1, wallpaperUI.surfaceOpacity)
            clip: true
            
            Image {
                anchors.fill: parent
                source: fileUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            
            MouseArea {
                anchors.fill: parent
                enabled: !awwwProcess.running
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    awwwProcess.targetFile = filePath;
                    awwwProcess.running = true;
                }
            }
        }
    }

    Text {
        anchors.centerIn: carousel
        visible: folderModel.count === 0
        text: "No wallpapers found"
        color: wallpaperUI.nord4
        font.family: wallpaperUI.fontPrimary; font.pixelSize: 13
    }
}
