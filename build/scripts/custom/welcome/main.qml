import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: welcomeWindow
    width: 600
    height: 400
    visible: true
    title: "Welcome to ValekOS"
    color: "#1E1E2E"
    flags: Qt.Window | Qt.WindowTitleHint | Qt.CustomizeWindowHint

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "Welcome to ValekOS"
            font.pixelSize: 32
            font.bold: true
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }

        SwipeView {
            id: view
            currentIndex: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            clip: true

            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Windows 10 Design"; color: "white"; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "Familiar taskbar and start menu for easy navigation."; color: "#94A3B8"; Layout.alignment: Qt.AlignHCenter }
                }
            }

            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Hyper Island"; color: "white"; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "Dynamic notifications and music controls at the top."; color: "#94A3B8"; Layout.alignment: Qt.AlignHCenter }
                }
            }

            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Custom Sounds"; color: "white"; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "Use HyperOS sounds or your own MP3 files."; color: "#94A3B8"; Layout.alignment: Qt.AlignHCenter }
                }
            }
        }

        PageIndicator {
            id: indicator
            count: view.count
            currentIndex: view.currentIndex
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            text: view.currentIndex === view.count - 1 ? "Get Started" : "Next"
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                if (view.currentIndex === view.count - 1) {
                    welcomeWindow.close()
                } else {
                    view.currentIndex++
                }
            }
        }
    }
}
