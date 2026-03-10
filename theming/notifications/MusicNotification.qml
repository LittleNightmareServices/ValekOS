/*
 * ValekOS Music Notification - HyperOS3 Style
 * Music player notification with album art and controls
 * Inspired by Xiaomi HyperOS3 music notification design
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

// Music notification card
Rectangle {
    id: musicNotification
    width: 380
    height: expanded ? 180 : 80
    radius: 20
    color: "#CC0F0F14"
    border.color: Qt.rgba(14/255, 165/255, 233/255, 0.3)
    border.width: 1

    // Properties
    property bool expanded: true
    property bool playing: false
    property string trackTitle: "Unknown Track"
    property string trackArtist: "Unknown Artist"
    property string trackAlbum: "Unknown Album"
    property string albumArt: ""
    property int trackPosition: 0
    property int trackDuration: 0
    property string playerName: ""

    // Animation for expand/collapse
    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // Background gradient
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 19
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Main content
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Album art
        Rectangle {
            Layout.preferredWidth: expanded ? 100 : 48
            Layout.preferredHeight: expanded ? 100 : 48
            radius: expanded ? 16 : 12
            color: "#1E1E25"
            clip: true

            Image {
                anchors.fill: parent
                source: albumArt
                fillMode: Image.PreserveAspectCrop
                visible: albumArt !== ""
            }

            // Placeholder icon when no album art
            PlasmaCore.IconItem {
                anchors.centerIn: parent
                width: expanded ? 48 : 24
                height: expanded ? 48 : 24
                source: "media-optical-audio"
                visible: albumArt === ""
            }

            // Playing animation overlay
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(14/255, 165/255, 233/255, 0.2)
                visible: playing

                SequentialAnimation on opacity {
                    running: playing
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 0.8; duration: 1000 }
                    NumberAnimation { from: 0.8; to: 0.3; duration: 1000 }
                }
            }

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        // Track info and controls
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: trackTitle
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: "#F8FAFC"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: trackArtist + (trackAlbum !== "" ? " • " + trackAlbum : "")
                    font.pixelSize: 13
                    color: "#94A3B8"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Progress bar (only when expanded)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: 2
                color: "#1E1E25"
                visible: expanded

                Rectangle {
                    width: parent.width * (trackDuration > 0 ? trackPosition / trackDuration : 0)
                    height: parent.height
                    radius: 2
                    color: "#0EA5E9"
                }
            }

            // Controls (only when expanded)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: expanded

                // Previous button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    PlasmaCore.IconItem {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: "media-skip-backward"
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Play/Pause button
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: "#0EA5E9"

                    PlasmaCore.IconItem {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: playing ? "media-playback-pause" : "media-playback-start"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Next button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    PlasmaCore.IconItem {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: "media-skip-forward"
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Item { Layout.fillWidth: true }

                // Volume button
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: volArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    PlasmaCore.IconItem {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: "audio-volume-high"
                    }

                    MouseArea {
                        id: volArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }

    // Click to expand/collapse
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: expanded = !expanded
    }
}
