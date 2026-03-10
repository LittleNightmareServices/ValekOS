#!/bin/bash
#===============================================================================
# ValekOS Post-Install VM Setup
# Installs VM detection and optimization support
#===============================================================================

set -e

INSTALL_DIR="/usr/share/valekos"
BIN_DIR="/usr/bin"
SYSTEMD_DIR="/etc/systemd/system"

echo "Installing ValekOS VM Detection Support..."

# Create directories
mkdir -p "$INSTALL_DIR/vm"
mkdir -p "$INSTALL_DIR/widgets"

# Copy VM detection script
cp /tmp/valekos/vm/vm-detect.sh "$BIN_DIR/valekos-vm-detect"
chmod +x "$BIN_DIR/valekos-vm-detect"

# Copy systemd service
cp /tmp/valekos/vm/valekos-vm-detect.service "$SYSTEMD_DIR/valekos-vm-detect.service"

# Enable the service
systemctl enable valekos-vm-detect.service

# Copy notification themes
cp -r /tmp/valekos/notifications/* "/usr/share/plasma/look-and-feel/com.valekos.valekos/contents/notifications/" 2>/dev/null || true

# Copy HyperIsland widget
cp -r /tmp/valekos/widgets/* "$INSTALL_DIR/widgets/" 2>/dev/null || true

# Create VM info directory
mkdir -p /run/valekos
mkdir -p /var/lib/valekos

echo "VM Detection Support installed successfully!"
