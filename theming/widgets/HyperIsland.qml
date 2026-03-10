/*
 * ValekOS HyperIsland Widget
 * Inspired by Xiaomi HyperOS HyperIsland feature
 * A floating glassmorphic island that displays notifications, music, and status
 *
 * Features:
 * - Dynamic sizing based on content
 * - Music player controls
 * - Timer/Stopwatch display
 * - Call notifications
 * - File transfer progress
 * - System status indicators
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

// Floating Island Container
Rectangle {
    id: hyperIsland
    width: islandContent.implicitWidth + 32
    height: islandContent.implicitHeight + 16
    radius: 28
    color: "#CC0F0F14"

    // Position - top center of screen
    x: parent ? (parent.width - width) / 2 : 100
    y: 20

    // Island modes
    property string mode: "idle"  // idle, music, timer, call, transfer, notification
    property bool expanded: false
    property bool hovered: false

    // HyperOS3 Colors
    readonly property color accentBlue: "#0EA5E9"
    readonly property color accentGreen: "#22C55E"
    readonly property color accentRed: "#EF4444"
    readonly property color accentOrange: "#F97316"
    readonly property color textPrimary: "#F8FAFC"
    readonly property color textSecondary: "#94A3B8"
    readonly property color cardBg: "#1E1E25"

    // Border with subtle glow
    border.color: Qt.rgba(14/255, 165/255, 233/255, hovered ? 0.5 : 0.2)
    border.width: 1

    // Inner glow effect
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 27
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Smooth animations
    Behavior on width {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on radius {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // Content based on mode
    RowLayout {
        id: islandContent
        anchors.centerIn: parent
        spacing: 12

        // IDLE MODE - Time and Status
        RowLayout {
            spacing: 12
            visible: mode === "idle"

            // Clock
            PlasmaComponents.Label {
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: 16
                font.weight: Font.Bold
                color: textPrimary
            }

            // Separator
            Rectangle {
                width: 1
                height: 20
                color: textSecondary
                opacity: 0.3
            }

            // Battery indicator
            RowLayout {
                spacing: 4

                PlasmaCore.IconItem {
                    width: 16
                    height: 16
                    source: "battery-good"
                }

                PlasmaComponents.Label {
                    text: "85%"
                    font.pixelSize: 13
                    color: textSecondary
                }
            }
        }

        // MUSIC MODE - Now Playing
        RowLayout {
            spacing: 12
            visible: mode === "music"

            // Album art mini
            Rectangle {
                width: 40
                height: 40
                radius: 10
                color: cardBg

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: "media-optical-audio"
                }

                // Playing animation
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Qt.rgba(14/255, 165/255, 233/255, 0.2)
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.2; to: 0.6; duration: 800 }
                        NumberAnimation { from: 0.6; to: 0.2; duration: 800 }
                    }
                }
            }

            // Track info
            ColumnLayout {
                spacing: 2

                PlasmaComponents.Label {
                    text: "Now Playing"
                    font.pixelSize: 11
                    color: textSecondary
                }

                PlasmaComponents.Label {
                    text: "Artist - Track Name"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: textPrimary
                }
            }

            // Play/Pause button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: accentBlue

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "media-playback-pause"
                }
            }
        }

        // TIMER MODE
        RowLayout {
            spacing: 12
            visible: mode === "timer"

            PlasmaCore.IconItem {
                width: 20
                height: 20
                source: "chronometer"
            }

            PlasmaComponents.Label {
                text: "05:32"
                font.pixelSize: 18
                font.weight: Font.Bold
                font.family: "JetBrains Mono"
                color: textPrimary
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: accentRed

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "media-playback-stop"
                }
            }
        }

        // CALL MODE
        RowLayout {
            spacing: 12
            visible: mode === "call"

            // Avatar
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: accentGreen

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: "call-start"
                }
            }

            ColumnLayout {
                spacing: 2

                PlasmaComponents.Label {
                    text: "Incoming Call"
                    font.pixelSize: 11
                    color: textSecondary
                }

                PlasmaComponents.Label {
                    text: "Contact Name"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: textPrimary
                }
            }

            // Accept/Reject buttons
            RowLayout {
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: accentGreen

                    PlasmaCore.IconItem {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "call-start"
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: accentRed

                    PlasmaCore.IconItem {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "call-stop"
                    }
                }
            }
        }

        // FILE TRANSFER MODE
        RowLayout {
            spacing: 12
            visible: mode === "transfer"

            PlasmaCore.IconItem {
                width: 20
                height: 20
                source: "folder-download"
            }

            ColumnLayout {
                spacing: 4

                PlasmaComponents.Label {
                    text: "Downloading..."
                    font.pixelSize: 12
                    color: textSecondary
                }

                // Progress bar
                Rectangle {
                    width: 120
                    height: 4
                    radius: 2
                    color: cardBg

                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height
                        radius: 2
                        color: accentBlue
                    }
                }

                PlasmaComponents.Label {
                    text: "65% • 2:30 remaining"
                    font.pixelSize: 11
                    color: textSecondary
                }
            }
        }

        // NOTIFICATION MODE
        RowLayout {
            spacing: 12
            visible: mode === "notification"

            // App icon
            Rectangle {
                width: 32
                height: 32
                radius: 10
                color: accentBlue

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: "notifications"
                }
            }

            ColumnLayout {
                spacing: 2

                PlasmaComponents.Label {
                    text: "New Message"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: textPrimary
                }

                PlasmaComponents.Label {
                    text: "Tap to view"
                    font.pixelSize: 11
                    color: textSecondary
                }
            }
        }
    }

    // Hover detection
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: hovered = true
        onExited: hovered = false

        // Click to expand
        onClicked: {
            expanded = !expanded
        }
    }

    // Demo mode cycling
    Timer {
        running: true
        interval: 3000
        repeat: true
        onTriggered: {
            var modes = ["idle", "music", "timer", "notification"]
            var currentIndex = modes.indexOf(mode)
            var nextIndex = (currentIndex + 1) % modes.length
            mode = modes[nextIndex]
        }
    }
}
