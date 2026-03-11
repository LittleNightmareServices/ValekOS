import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    // Size constraints for the applet
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    width: island.width + 40
    height: island.height + 40

    // HyperOS3 Styling
    readonly property color bgColor: "#CC000000"
    readonly property color accentColor: "#0EA5E9"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#94A3B8"

    // Data Sources
    PlasmaCore.DataSource {
        id: mprisSource
        engine: "mpris2"
        connectedSources: sources
        onSourceAdded: {
            if (source.indexOf("org.mpris.MediaPlayer2.") === 0) {
                connectedSources.push(source);
            }
        }
    }

    property var currentMetadata: mprisSource.data[mprisSource.connectedSources[0]]?.Metadata || {}
    property string trackTitle: currentMetadata["xesam:title"] || ""
    property string trackArtist: currentMetadata["xesam:artist"] ? currentMetadata["xesam:artist"][0] : ""
    property bool isPlaying: mprisSource.data[mprisSource.connectedSources[0]]?.PlaybackStatus === "Playing"

    // Dynamic Island Container
    Rectangle {
        id: island
        anchors.centerIn: parent
        width: expanded ? 300 : Math.max(120, contentRow.implicitWidth + 32)
        height: expanded ? 80 : 36
        radius: height / 2
        color: bgColor
        clip: true

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        property bool expanded: false

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 12

            // Icon / Music Visualizer
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: isPlaying ? accentColor : "transparent"

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: isPlaying ? "media-playback-start" : "notifications"
                    visible: !isPlaying
                }

                // Simple Music "Animation"
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: isPlaying
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 2
                            height: 10 + Math.random() * 5
                            color: "white"
                            SequentialAnimation on height {
                                running: isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { to: 4; duration: 400 }
                                NumberAnimation { to: 14; duration: 400 }
                            }
                        }
                    }
                }
            }

            // Text info
            ColumnLayout {
                spacing: 0
                visible: island.expanded || trackTitle !== ""

                PlasmaComponents.Label {
                    text: trackTitle !== "" ? trackTitle : "ValekOS"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: textPrimary
                    Layout.maximumWidth: 150
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    text: trackArtist
                    font.pixelSize: 10
                    color: textSecondary
                    visible: island.expanded && trackArtist !== ""
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: island.expanded = !island.expanded
        }
    }
}
