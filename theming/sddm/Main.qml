/*
 * ValekOS SDDM Theme - HyperOS3 Inspired
 * A modern login screen with glassmorphism effects
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#0F0F14"

    // Background image with blur
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: config.Background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true

        // Blur overlay
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.6
        }

        // Gradient overlay
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 0.5; color: "#0F0F1480" }
                GradientStop { position: 1.0; color: "#0F0F14FF" }
            }
        }
    }

    // Time and Date
    Column {
        id: clockColumn
        anchors {
            left: parent.left
            leftMargin: 80
            top: parent.top
            topMargin: 80
        }

        Text {
            id: timeText
            text: Qt.formatTime(new Date(), "hh:mm")
            color: "#0EA5E9"
            font {
                family: "JetBrains Mono"
                pixelSize: 96
                weight: Font.Light
            }
            renderType: Text.NativeRendering
        }

        Text {
            id: dateText
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            color: "#94A3B8"
            font {
                family: "Inter"
                pixelSize: 24
            }
            renderType: Text.NativeRendering
        }
    }

    // Welcome text
    Text {
        id: welcomeText
        anchors {
            left: parent.left
            leftMargin: 80
            top: clockColumn.bottom
            topMargin: 40
        }
        text: config.WelcomeText || "Welcome to ValekOS"
        color: "#F8FAFC"
        font {
            family: "Inter"
            pixelSize: 32
            weight: Font.Bold
        }
        renderType: Text.NativeRendering
    }

    // Login form
    Rectangle {
        id: loginForm
        anchors {
            left: parent.left
            leftMargin: 80
            top: welcomeText.bottom
            topMargin: 60
        }
        width: 400
        height: 400
        color: "transparent"

        // User selector
        Column {
            id: userColumn
            spacing: 16
            anchors.fill: parent

            // User avatar and name
            Rectangle {
                id: userCard
                width: parent.width
                height: 80
                radius: 12
                color: "#1E1E25"

                Row {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // Avatar
                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#0EA5E9"

                        Text {
                            anchors.centerIn: parent
                            text: userListView.currentItem ? 
                                  userListView.currentItem.userNameText.text.charAt(0).toUpperCase() : "V"
                            color: "#0F0F14"
                            font {
                                family: "Inter"
                                pixelSize: 24
                                weight: Font.Bold
                            }
                        }
                    }

                    // Username
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: selectedUserName
                            text: userListView.currentItem ? 
                                  userListView.currentItem.userNameText.text : "valek"
                            color: "#F8FAFC"
                            font {
                                family: "Inter"
                                pixelSize: 18
                                weight: Font.Medium
                            }
                        }

                        Text {
                            text: "Local Account"
                            color: "#64748B"
                            font {
                                family: "Inter"
                                pixelSize: 14
                            }
                        }
                    }
                }
            }

            // Password field
            TextField {
                id: passwordField
                width: parent.width
                height: 52
                echoMode: TextInput.Password
                passwordCharacter: "•"
                placeholderText: "Password"
                color: "#F8FAFC"
                selectionColor: "#0EA5E9"
                selectedTextColor: "#0F0F14"
                font {
                    family: "Inter"
                    pixelSize: 16
                }

                background: Rectangle {
                    color: "#1E1E25"
                    radius: 8
                    border {
                        width: passwordField.activeFocus ? 2 : 1
                        color: passwordField.activeFocus ? "#0EA5E9" : "#334155"
                    }
                }

                Keys.onReturnPressed: {
                    sddm.login(userListView.currentItem ? 
                              userListView.currentItem.userNameText.text : "valek", 
                              passwordField.text, 
                              sessionListView.currentItem ? 
                              sessionListView.currentItem.sessionName : "")
                }
            }

            // Session selector
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "Session:"
                    color: "#64748B"
                    font {
                        family: "Inter"
                        pixelSize: 14
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                ComboBox {
                    id: sessionSelector
                    width: 250
                    model: sessionModel
                    textRole: "name"

                    background: Rectangle {
                        color: "#1E1E25"
                        radius: 8
                        border {
                            width: 1
                            color: "#334155"
                        }
                    }

                    contentItem: Text {
                        text: sessionSelector.displayText
                        color: "#F8FAFC"
                        font {
                            family: "Inter"
                            pixelSize: 14
                        }
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 12
                    }
                }
            }

            // Login button
            Button {
                id: loginButton
                width: parent.width
                height: 48

                contentItem: Text {
                    text: "Sign In"
                    color: "#0F0F14"
                    font {
                        family: "Inter"
                        pixelSize: 16
                        weight: Font.Bold
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: loginButton.down ? "#0284C7" : 
                           loginButton.hovered ? "#38BDF8" : "#0EA5E9"
                    radius: 8
                }

                onClicked: {
                    sddm.login(userListView.currentItem ? 
                              userListView.currentItem.userNameText.text : "valek", 
                              passwordField.text, 
                              sessionSelector.currentText)
                }
            }

            // Error message
            Text {
                id: errorMessage
                visible: false
                text: "Authentication failed. Please try again."
                color: "#EF4444"
                font {
                    family: "Inter"
                    pixelSize: 14
                }
            }
        }
    }

    // Power buttons
    Row {
        anchors {
            right: parent.right
            rightMargin: 40
            bottom: parent.bottom
            bottomMargin: 40
        }
        spacing: 16

        // Suspend
        IconButton {
            icon: "system-suspend"
            text: "Suspend"
            onClicked: sddm.suspend()
        }

        // Restart
        IconButton {
            icon: "system-reboot"
            text: "Restart"
            onClicked: sddm.reboot()
        }

        // Shutdown
        IconButton {
            icon: "system-shutdown"
            text: "Shutdown"
            onClicked: sddm.powerOff()
        }
    }

    // Keyboard layout
    Text {
        anchors {
            left: parent.left
            leftMargin: 40
            bottom: parent.bottom
            bottomMargin: 40
        }
        text: keyboard.layouts[keyboard.currentLayout].name
        color: "#64748B"
        font {
            family: "Inter"
            pixelSize: 12
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            errorMessage.visible = true
            passwordField.text = ""
            passwordField.focus = true
        }
    }

    // User list view (hidden, for selecting users)
    ListView {
        id: userListView
        model: userModel
        visible: false
    }

    // Session list view
    ListView {
        id: sessionListView
        model: sessionModel
        visible: false
    }

    Component.onCompleted: {
        passwordField.focus = true
    }
}
