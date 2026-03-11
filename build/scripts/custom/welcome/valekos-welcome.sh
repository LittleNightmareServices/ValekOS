#!/bin/bash
# ValekOS Welcome Launcher

CONFIG_FILE="$HOME/.config/valekos/welcome_done"

if [ ! -f "$CONFIG_FILE" ]; then
    qmlscene /usr/share/valekos/welcome/main.qml
    touch "$CONFIG_FILE"
fi
