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

// Configure Desktops
for (var i = 0; i < desktops().length; i++) {
    var d = desktops()[i];
    d.wallpaperPlugin = "org.kde.image";

    // Add Hyper Island widget to the top center of each desktop
    var island = d.addWidget("com.valekos.hyperisland");
}

var desktopConfig = new ConfigGroup(panel, "General")
desktopConfig.writeConfig("alignment", "left")
