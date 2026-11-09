pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: root

    property color nord0: "#2E3440"
    property color nord1: "#3B4252"
    property color nord4: "#D8DEE9"
    property color nord6: "#ECEFF4"
    property color nord8: "#88C0D0"
    property color nord9: "#81A1C1"
    property string fontPrimary: "Inter"
    property string fontMono: "JetBrains Mono"
    property string wifiText: ""
    property bool wifiEnabled: true
    property bool focusEnabled: false
    property real volumeLevel: 0
    property real brightnessLevel: 0
    property bool brightnessAvailable: false
    property bool widgetsEnabled: true
    property bool microphoneMuted: false
    property bool microphoneAvailable: false
    property bool clockEnabled: true
    property string trackTitle: "Nothing playing"
    property string trackArtist: ""
    property string albumArtSource: ""
    property bool playing: false

    signal volumeRequested(real value)
    signal brightnessRequested(real value)
    signal wifiToggled()
    signal focusToggled()
    signal playbackToggled()
    signal widgetsToggled()
    signal microphoneToggled()
    signal clockToggled()
    signal wallpaperRequested()
    signal musicRequested()

    implicitWidth: 244
    implicitHeight: 238

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 12

        Row {
            width: parent.width
            height: 52
            spacing: 12

            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 24
                color: root.wifiEnabled ? "#4D6073" : Qt.alpha(root.nord1, 0.86)
                border.width: 1
                border.color: Qt.alpha(root.nord6, 0.10)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 9

                    SvgIcon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        path: "M5 9a11 11 0 0 1 14 0 M8 12a6.5 6.5 0 0 1 8 0 M11 15a2 2 0 0 1 2 0 M12 19h.01"
                        iconColor: root.nord6
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.wifiEnabled
                            ? (root.wifiText.length > 0 ? root.wifiText : "Connected")
                            : "Wi-Fi off"
                        color: root.nord6
                        font.family: root.fontPrimary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wifiToggled()
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 24
                color: root.focusEnabled ? "#665963" : "#514B55"
                border.width: 1
                border.color: Qt.alpha(root.nord6, 0.10)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    SvgIcon {
                        Layout.preferredWidth: 17
                        Layout.preferredHeight: 17
                        path: "M20.5 15.2A8.5 8.5 0 0 1 8.8 3.5 8.6 8.6 0 1 0 20.5 15.2z"
                        iconColor: root.nord6
                        fill: true
                    }
                    Text {
                        text: root.focusEnabled ? "Focus on" : "Focus"
                        color: root.nord6
                        font.family: root.fontPrimary
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusToggled()
                }
            }
        }

        Row {
            width: parent.width
            height: 116
            spacing: 12

            Column {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 20
                    color: Qt.alpha(root.nord1, 0.78)
                    border.width: 1
                    border.color: Qt.alpha(root.nord6, 0.09)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        SvgIcon {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            path: "M11 5 6 9H3v6h3l5 4z M16 9a5 5 0 0 1 0 6 M18.5 6.5a9 9 0 0 1 0 11"
                            iconColor: root.nord6
                        }

                        Slider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            from: 0
                            to: 1
                            value: root.volumeLevel
                            onMoved: root.volumeRequested(value)
                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                                width: volumeSlider.availableWidth
                                height: 4
                                radius: 2
                                color: Qt.alpha(root.nord6, 0.22)
                                Rectangle {
                                    width: parent.width * volumeSlider.visualPosition
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.nord8
                                }
                            }
                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition
                                    * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                                width: 12
                                height: 12
                                radius: 6
                                color: root.nord6
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 20
                    color: Qt.alpha(root.nord1, 0.78)
                    border.width: 1
                    border.color: Qt.alpha(root.nord6, 0.09)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        SvgIcon {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            path: "M12 2v3 M12 19v3 M4.9 4.9 7 7 M17 17l2.1 2.1 M2 12h3 M19 12h3 M4.9 19.1 7 17 M17 7l2.1-2.1 M12 8a4 4 0 1 0 0 8a4 4 0 0 0 0-8"
                            iconColor: root.nord6
                        }

                        Slider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            enabled: root.brightnessAvailable
                            opacity: enabled ? 1 : 0.4
                            from: 0
                            to: 1
                            value: root.brightnessLevel
                            onMoved: root.brightnessRequested(value)
                            background: Rectangle {
                                x: brightnessSlider.leftPadding
                                y: brightnessSlider.topPadding + (brightnessSlider.availableHeight - height) / 2
                                width: brightnessSlider.availableWidth
                                height: 4
                                radius: 2
                                color: Qt.alpha(root.nord6, 0.22)
                                Rectangle {
                                    width: parent.width * brightnessSlider.visualPosition
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.nord9
                                }
                            }
                            handle: Rectangle {
                                x: brightnessSlider.leftPadding + brightnessSlider.visualPosition
                                    * (brightnessSlider.availableWidth - width)
                                y: brightnessSlider.topPadding + (brightnessSlider.availableHeight - height) / 2
                                width: 12
                                height: 12
                                radius: 6
                                color: root.nord6
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: mediaTile
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 22
                color: Qt.alpha(root.nord1, 0.82)
                border.width: 1
                border.color: Qt.alpha(root.nord6, 0.16)
                clip: true

                Row {
                    z: 1
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    spacing: 7

                    Rectangle {
                        width: 58
                        height: 58
                        radius: 12
                        color: Qt.alpha(root.nord0, 0.65)
                        clip: true

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 23
                            height: 23
                            visible: albumArt.status !== Image.Ready
                            path: "M9 18V5l12-2v13 M9 18a3 3 0 1 1-6 0a3 3 0 0 1 6 0 M21 16a3 3 0 1 1-6 0a3 3 0 0 1 6 0"
                            iconColor: root.nord8
                        }

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: root.albumArtSource
                            visible: status === Image.Ready
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(128, 128)
                        }
                    }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(root.nord6, 0.12)

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            path: root.playing ? "M7 5h4v14H7z M15 5h4v14h-4z" : "M8 5v14l11-7z"
                            iconColor: root.nord6
                            fill: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playbackToggled()
                        }
                    }
                }

                Text {
                    z: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 74
                    text: root.trackTitle
                    color: root.nord6
                    font.family: root.fontPrimary
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    z: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 91
                    text: root.trackArtist
                    color: Qt.alpha(root.nord4, 0.78)
                    font.family: root.fontPrimary
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.musicRequested()
                }
            }
        }

        Row {
            width: parent.width
            height: 46
            spacing: (width - 4 * height) / 3

            Repeater {
                model: [
                    { action: "widgets", label: "Desktop widgets", icon: "M4 18a8 8 0 1 1 16 0 M12 14l4-4 M7 18h.01 M17 18h.01" },
                    { action: "microphone", label: "Mute microphone", icon: "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1-6 0z M5 10v2a7 7 0 0 0 14 0v-2 M12 19v3 M8 22h8" },
                    { action: "clock", label: "Floating clock", icon: "M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z M9 12a3 3 0 1 0 6 0a3 3 0 0 0-6 0z" },
                    { action: "wallpaper", label: "Open wallpaper picker", icon: "M4 5h16v14H4z M4 15l4-4 4 4 3-3 5 5 M9 9h.01" }
                ]

                Rectangle {
                    id: actionButton
                    required property var modelData
                    width: 46
                    height: 46
                    radius: 23
                    color: modelData.action === "widgets" && root.widgetsEnabled
                        || modelData.action === "microphone" && root.microphoneMuted
                        || modelData.action === "clock" && root.clockEnabled
                        ? Qt.alpha(root.nord8, 0.26) : Qt.alpha(root.nord1, 0.7)
                    border.width: 1
                    border.color: Qt.alpha(root.nord6, 0.10)
                    opacity: modelData.action === "microphone" && !root.microphoneAvailable ? 0.45 : 1
                    Accessible.name: modelData.label

                    SvgIcon {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        path: actionButton.modelData.icon
                        iconColor: root.nord6
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: actionButton.modelData.action !== "microphone" || root.microphoneAvailable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (actionButton.modelData.action === "widgets") root.widgetsToggled();
                            else if (actionButton.modelData.action === "microphone") root.microphoneToggled();
                            else if (actionButton.modelData.action === "clock") root.clockToggled();
                            else if (actionButton.modelData.action === "wallpaper") root.wallpaperRequested();
                        }
                    }
                }
            }
        }
    }
}
