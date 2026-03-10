#!/bin/bash
#===============================================================================
# ValekOS Fallback Bootstrap Script
#
# Use this if the main bootstrap.sh fails.
# This uses simpler methods and more verbose error handling.
#
# Usage: ./fallback-bootstrap.sh --chroot /path/to/chroot
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[FALLBACK]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

CHROOT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --chroot) CHROOT_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$CHROOT_DIR" ]] && { err "Need --chroot"; exit 1; }

log "Starting fallback bootstrap..."

# Create directory
mkdir -p "$CHROOT_DIR"

# Step 1: Run debootstrap with minimal options
log "Running debootstrap (this takes time)..."

if debootstrap --arch=amd64 jammy "$CHROOT_DIR" http://archive.ubuntu.com/ubuntu; then
    ok "debootstrap succeeded"
else
    err "debootstrap failed!"
    err "Trying alternate mirror..."
    
    # Try alternate mirrors
    for mirror in "http://us.archive.ubuntu.com/ubuntu" "http://mirrors.edge.kernel.org/ubuntu"; do
        log "Trying mirror: $mirror"
        if debootstrap --arch=amd64 jammy "$CHROOT_DIR" "$mirror"; then
            ok "Success with $mirror"
            break
        fi
    done || { err "All mirrors failed!"; exit 1; }
fi

# Step 2: Mount filesystems
log "Mounting filesystems..."
for fs in dev proc sys; do
    mount --bind "/$fs" "$CHROOT_DIR/$fs" || warn "Could not mount $fs"
done

# Step 3: Configure sources
log "Configuring apt sources..."
cat > "$CHROOT_DIR/etc/apt/sources.list" << 'EOF'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

# Step 4: Update and install kernel
log "Updating package lists..."
chroot "$CHROOT_DIR" apt-get update || { err "apt-get update failed"; exit 1; }

log "Installing kernel (CRITICAL)..."
if chroot "$CHROOT_DIR" apt-get -y install linux-image-generic; then
    ok "Kernel installed"
else
    err "Kernel installation failed!"
    err "Trying alternative kernel..."
    chroot "$CHROOT_DIR" apt-get -y install linux-image-5.15.0-91-generic || {
        err "Could not install any kernel!"
        exit 1
    }
fi

# Step 5: Install basic packages
log "Installing basic packages..."
chroot "$CHROOT_DIR" apt-get -y install \
    sudo systemd locales curl wget ca-certificates || warn "Some packages failed"

# Step 6: Verify
log "Verifying installation..."
if ls "$CHROOT_DIR/boot/vmlinuz-"* 1>/dev/null 2>&1; then
    ok "Kernel found in /boot/"
    ls -la "$CHROOT_DIR/boot/vmlinuz-"*
else
    err "No kernel found! Something went wrong."
    exit 1
fi

ok "Fallback bootstrap complete!"
ok "Run chroot.sh next"
