#!/bin/bash
# ValekOS Sound Swapper
# Script to allow users to switch notification sounds

SOUNDS_DIR="/usr/share/sounds/valekos"
CONFIG_FILE="$HOME/.config/valekos/sounds.conf"

show_help() {
    echo "ValekOS Sound Swapper"
    echo "Usage: valekos-sounds [option] [file]"
    echo ""
    echo "Options:"
    echo "  --set <file.mp3>   Set a custom mp3 as the notification sound"
    echo "  --reset            Reset to default HyperOS sounds"
    echo "  --gui              Open file dialog to select sound"
    echo "  --list             List available default sounds"
}

set_sound() {
    local file=$1
    if [[ -f "$file" ]]; then
        echo "Setting notification sound to $file..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "CUSTOM_SOUND=$file" > "$CONFIG_FILE"
        if command -v kwriteconfig5 &>/dev/null; then
            kwriteconfig5 --file plasmanotifyrc --group Sounds --key NotificationCustom "$file"
        else
            echo "Warning: kwriteconfig5 not found."
        fi
    else
        echo "Error: File $file not found."
    fi
}

if [[ $1 == "--set" ]]; then
    set_sound "$2"
elif [[ $1 == "--reset" ]]; then
    echo "Resetting to defaults..."
    rm -f "$CONFIG_FILE"
    kwriteconfig5 --file plasmanotifyrc --group Sounds --key NotificationCustom ""
elif [[ $1 == "--gui" ]]; then
    if command -v kdialog &>/dev/null; then
        FILE=$(kdialog --getopenfilename "$HOME" "*.mp3 *.wav *.ogg" --title "Select Notification Sound")
        if [[ -n "$FILE" ]]; then
            set_sound "$FILE"
        fi
    else
        echo "Error: kdialog not found."
    fi
else
    show_help
fi
