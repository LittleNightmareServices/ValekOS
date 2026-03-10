/*
 * ValekOS Notification Theme - HyperOS3 Style
 * Inspired by Xiaomi HyperOS3 notification design
 * Features: Glassmorphism, rounded corners, music controls, floating island
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

// Main notification popup
PlasmaCore.Dialog {
    id: notificationPopup
    location: PlasmaCore.Types.Floating
    type: PlasmaCore.Dialog.Notification
    flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint

    // HyperOS3 color scheme
    readonly property color bgColor: "#CC0F0F14"        // Semi-transparent black
    readonly property color accentColor: "#0EA5E9"      // Blue accent
    readonly property color textPrimary: "#F8FAFC"      // White text
    readonly property color textSecondary: "#94A3B8"    // Gray text

    // Notification properties
    property string appName: ""
    property string appIcon: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property int timeout: 5000
    property bool hasAction: false
    property string actionLabel: ""

    width: 380
    height: notificationContent.implicitHeight + 24

    // Glassmorphism background
    background: Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: 20
        color: bgColor
        border.color: Qt.rgba(14/255, 165/255, 233/255, 0.3)
        border.width: 1

        // Inner glow
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 19
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Main content
    ColumnLayout {
        id: notificationContent
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // Header with app info
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // App icon
            Rectangle {
                width: 40
                height: 40
                radius: 12
                color: accentColor

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: appIcon || "applications-other"
                }
            }

            // App name and time
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents.Label {
                    text: appName || "Notification"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: textSecondary
                }

                PlasmaComponents.Label {
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.pixelSize: 11
                    color: textSecondary
                    opacity: 0.7
                }
            }

            // Close button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "window-close"
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: notificationPopup.visible = false
                }
            }
        }

        // Notification summary
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: summary
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: textPrimary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: summary !== ""
        }

        // Notification body
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: body
            font.pixelSize: 14
            color: textSecondary
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: body !== ""
        }

        // Notification image
        Image {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            source: image
            fillMode: Image.PreserveAspectCrop
            visible: image !== ""
            layer.enabled: true
        }

        // Action button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 12
            color: actionMouseArea.containsMouse ? Qt.rgba(14/255, 165/255, 233/255, 0.9) : accentColor
            visible: hasAction

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: actionLabel || "Open"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#0F0F14"
            }

            MouseArea {
                id: actionMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    // Auto-dismiss timer
    Timer {
        id: dismissTimer
        interval: timeout
        running: visible
        onTriggered: notificationPopup.visible = false
    }
}
