#!/bin/bash
#===============================================================================
# ValekOS Bootstrap Script (Robust Version v3)
# 
# Based on best practices from:
# - https://mvallim.github.io/live-custom-ubuntu-from-scratch
# - Ubuntu official documentation
# 
# This script bootstraps a minimal Ubuntu base system using debootstrap.
#
# CRITICAL: Do NOT create custom /etc/lsb-release here - this causes dpkg
# conffile prompts during package upgrades in chroot environment.
#===============================================================================

set -euo pipefail

#======================================
# CONFIGURATION
#======================================
SCRIPT_VERSION="3.0"
MIN_DISK_SPACE_GB=15

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()     { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success()  { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning()  { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()    { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()     { echo -e "\n${GREEN}[STEP]${NC} $1"; }

#======================================
# ARGUMENTS
#======================================
DISTRO=""
RELEASE=""
CHROOT_DIR=""
VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --distro)   DISTRO="$2"; shift 2 ;;
        --release)  RELEASE="$2"; shift 2 ;;
        --chroot)   CHROOT_DIR="$2"; shift 2 ;;
        --version)  VERSION="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 --distro <distro> --release <release> --chroot <dir> --version <ver>"
            echo ""
            echo "Supported distros: ubuntu, debian"
            echo "Example: $0 --distro ubuntu --release jammy --chroot /build/chroot --version 1.0"
            exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

#======================================
# VALIDATION
#======================================
if [[ -z "$DISTRO" || -z "$RELEASE" || -z "$CHROOT_DIR" ]]; then
    log_error "Missing required arguments!"
    echo "Use --help for usage information"
    exit 1
fi

log_info "=========================================="
log_info "ValekOS Bootstrap v${SCRIPT_VERSION}"
log_info "=========================================="
log_info "Distribution: $DISTRO"
log_info "Release: $RELEASE"
log_info "Target: $CHROOT_DIR"
log_info "Version: ${VERSION:-unspecified}"
log_info "=========================================="

#======================================
# PRE-CHECKS
#======================================
log_step "Running pre-flight checks..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root!"
    exit 1
fi

# Check required tools
REQUIRED_TOOLS=(debootstrap wget curl)
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        log_error "Required tool not found: $tool"
        log_info "Install with: apt-get install $tool"
        exit 1
    fi
done
log_success "All required tools available"

# Check disk space
AVAILABLE_SPACE=$(df -BG "$(dirname "$CHROOT_DIR")" | tail -1 | awk '{print $4}' | tr -d 'G')
if [[ "$AVAILABLE_SPACE" -lt "$MIN_DISK_SPACE_GB" ]]; then
    log_warning "Low disk space: ${AVAILABLE_SPACE}GB available, ${MIN_DISK_SPACE_GB}GB recommended"
fi

#======================================
# CONFIGURATION
#======================================
case "$DISTRO" in
    ubuntu|linuxmint)
        MIRROR="http://archive.ubuntu.com/ubuntu"
        SUITE="jammy"  # Ubuntu 22.04 LTS
        ;;
    debian)
        MIRROR="http://deb.debian.org/debian"
        SUITE="$RELEASE"
        ;;
    *)
        log_error "Unsupported distribution: $DISTRO"
        log_info "Supported: ubuntu, debian"
        exit 1
        ;;
esac

#======================================
# DEBOOTSTRAP
#======================================
log_step "Creating chroot directory..."
mkdir -p "$CHROOT_DIR"
log_success "Directory created: $CHROOT_DIR"

log_step "Running debootstrap (this takes several minutes)..."
log_info "Suite: $SUITE"
log_info "Mirror: $MIRROR"
log_info "Variant: minbase"

# Minimal debootstrap - only essential packages
# Note: apt-transport-https is built into apt since Ubuntu 18.04
# Note: gnupg instead of gnupg2 (gnupg2 may not be available in debootstrap)
DEBOOTSTRAP_PACKAGES="wget,ca-certificates,gnupg,curl"

if ! debootstrap --arch=amd64 --variant=minbase \
    --include="$DEBOOTSTRAP_PACKAGES" \
    "$SUITE" "$CHROOT_DIR" "$MIRROR"; then
    log_error "Debootstrap failed!"
    log_info "Common causes:"
    log_info "  1. Network connectivity issues"
    log_info "  2. Mirror is down - try a different mirror"
    log_info "  3. Invalid suite name"
    exit 1
fi

log_success "Debootstrap completed successfully!"

#======================================
# PREPARE CHROOT
#======================================
log_step "Preparing chroot environment..."

# Mount essential filesystems
# IMPORTANT: These must be mounted BEFORE any chroot operations
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"

# Copy DNS configuration
cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

log_success "Chroot environment prepared"

#======================================
# CONFIGURE APT
#======================================
log_step "Configuring APT repositories..."

# Use Ubuntu repos only (avoid Linux Mint GPG issues)
cat > "$CHROOT_DIR/etc/apt/sources.list" << 'EOF'
# Ubuntu 22.04 LTS (Jammy Jellyfish)
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse

# Source repositories (optional)
# deb-src http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
EOF

# Configure apt preferences for non-interactive operation
cat > "$CHROOT_DIR/etc/apt/apt.conf.d/99valekos" << 'EOF'
APT::Install-Recommends "true";
APT::Install-Suggests "false";
Acquire::AllowUnsizedPackages "true";
Acquire::Check-Valid-Until "false";
# Force non-interactive frontend
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
EOF

# Also set dpkg config for non-interactive operation
cat > "$CHROOT_DIR/etc/dpkg/dpkg.cfg.d/99non-interactive" << 'EOF'
force-confdef
force-confold
EOF

log_success "APT configured"

#======================================
# BASIC SYSTEM CONFIGURATION
#======================================
log_step "Configuring basic system settings..."

# Hostname
echo "valekos" > "$CHROOT_DIR/etc/hostname"

# Hosts file
cat > "$CHROOT_DIR/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   valekos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Environment
cat > "$CHROOT_DIR/etc/environment" << EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LANG="en_US.UTF-8"
LC_ALL="en_US.UTF-8"
DEBIAN_FRONTEND="noninteractive"
VALEKOS_VERSION="${VERSION:-1.0}"
EOF

#======================================
# VALEKOS IDENTITY (MINIMAL)
# Only create files that won't conflict with package updates
#======================================
log_step "Setting ValekOS identity (minimal)..."

mkdir -p "$CHROOT_DIR/etc/valekos"

cat > "$CHROOT_DIR/etc/valekos/release" << EOF
NAME="ValekOS"
VERSION="${VERSION:-1.0}"
ID=valekos
ID_LIKE="ubuntu debian"
PRETTY_NAME="ValekOS ${VERSION:-1.0}"
VERSION_CODENAME=horizon
HOME_URL="https://github.com/valekos/valekos"
EOF

# IMPORTANT: Do NOT create /etc/lsb-release or /etc/os-release here!
# These files are owned by the base-files package and will cause
# dpkg conffile prompts during package upgrades in chroot.
# They will be created in chroot.sh AFTER all packages are installed.

log_success "ValekOS identity configured (minimal)"

#======================================
# FINAL SUMMARY
#======================================
log_success "=========================================="
log_success "Bootstrap completed successfully!"
log_success "=========================================="
log_info "Chroot directory: $CHROOT_DIR"
log_info "Size: $(du -sh "$CHROOT_DIR" 2>/dev/null | cut -f1)"
log_info ""
log_info "Next step: Run chroot.sh to install packages"
