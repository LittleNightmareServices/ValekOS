var panel = new Panel
panel.location = "bottom"
panel.height = 40

var launcher = panel.addWidget("org.kde.plasma.kickoff")
launcher.currentConfigGroup = ["General"]
launcher.writeConfig("icon", "start-here-kde")

panel.addWidget("org.kde.plasma.pager")
panel.addWidget("org.kde.plasma.taskmanager")
panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.digitalclock")
panel.addWidget("org.kde.plasma.showdesktop")

// Add Hyper Island widget to the top center of the desktop
var island = desktop.addWidget("com.valekos.hyperisland")
island.geometry = Qt.rect(Screen.width/2 - 150, 20, 300, 36)

var desktop = new ConfigGroup(panel, "General")
desktop.writeConfig("alignment", "left")
