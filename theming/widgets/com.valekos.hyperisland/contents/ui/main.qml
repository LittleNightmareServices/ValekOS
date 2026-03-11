import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    width: island.width + 40
    height: island.height + 40

    readonly property color bgColor: Plasmoid.configuration.backgroundColor || "#CC000000"
    readonly property color accentColor: Plasmoid.configuration.accentColor || "#0EA5E9"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#94A3B8"
    readonly property bool showBattery: Plasmoid.configuration.showBattery || true

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

    PlasmaCore.DataSource {
        id: batterySource
        engine: "powermanagement"
        connectedSources: ["Battery"]
    }

    property var currentMetadata: mprisSource.data[mprisSource.connectedSources[0]]?.Metadata || {}
    property string trackTitle: currentMetadata["xesam:title"] || ""
    property string trackArtist: currentMetadata["xesam:artist"] ? currentMetadata["xesam:artist"][0] : ""
    property bool isPlaying: mprisSource.data[mprisSource.connectedSources[0]]?.PlaybackStatus === "Playing"

    property int batteryPercent: batterySource.data["Battery"]?.["Percent"] || 0
    property bool isCharging: batterySource.data["Battery"]?.["State"] === "Charging"

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

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: isPlaying ? accentColor : (isCharging ? "#22C55E" : "transparent")

                PlasmaCore.IconItem {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: isPlaying ? "media-playback-start" : (isCharging ? "battery-charging" : "notifications")
                    visible: !isPlaying
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: isPlaying
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 2
                            height: 10
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

            ColumnLayout {
                spacing: 0
                visible: island.expanded || trackTitle !== "" || (showBattery && batteryPercent < 20)

                PlasmaComponents.Label {
                    text: isPlaying ? trackTitle : (batteryPercent < 20 ? "Battery Low" : "ValekOS")
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: textPrimary
                    Layout.maximumWidth: 150
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    text: isPlaying ? trackArtist : (batteryPercent + "% remaining")
                    font.pixelSize: 10
                    color: textSecondary
                    visible: island.expanded || (batteryPercent < 20)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: island.expanded = !island.expanded
        }
    }
}
