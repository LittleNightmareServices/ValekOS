import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Rectangle {
    id: notificationRoot
    width: 350
    height: 70
    radius: 35
    color: "#CC000000"

    property string summary: model.summary || ""
    property string body: model.body || ""
    property var icon: model.icon || "preferences-desktop-notification"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        Rectangle {
            width: 50
            height: 50
            radius: 25
            color: "#0EA5E9"
            PlasmaCore.IconItem {
                anchors.centerIn: parent
                width: 30
                height: 30
                source: notificationRoot.icon
            }
        }

        ColumnLayout {
            spacing: 2
            PlasmaComponents.Label {
                text: notificationRoot.summary
                font.weight: Font.Bold
                color: "white"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                text: notificationRoot.body
                font.pixelSize: 12
                color: "#94A3B8"
                Layout.maximumWidth: 240
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }
}
