import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.configuration 2.0

ColumnLayout {
    ConfigColorPicker {
        configKey: "backgroundColor"
        label: "Background Color"
    }
    ConfigColorPicker {
        configKey: "accentColor"
        label: "Accent Color"
    }
    CheckBox {
        id: showBattery
        text: "Show Battery Status"
        checked: Plasmoid.configuration.showBattery
        onCheckedChanged: Plasmoid.configuration.showBattery = checked
    }
}
