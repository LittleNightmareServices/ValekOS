#!/bin/bash
#===============================================================================
# ValekOS Chroot Configuration Script (Robust Version v3)
#
# This script configures the bootstrapped system and installs all packages.
# It includes comprehensive error handling and fallback mechanisms.
#
# CRITICAL FIXES:
# - Uses dpkg --force-confdef --force-confold to avoid conffile prompts
# - Fixes any broken dpkg state before installing packages
# - Creates custom lsb-release AFTER all packages are installed
#===============================================================================

set -euo pipefail

#======================================
# CONFIGURATION
#======================================
SCRIPT_VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
CHROOT_DIR=""
CONFIG_DIR=""
THEMING_DIR=""
KERNEL_VERSION=""
VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --chroot)       CHROOT_DIR="$2"; shift 2 ;;
        --config-dir)   CONFIG_DIR="$2"; shift 2 ;;
        --theming-dir)  THEMING_DIR="$2"; shift 2 ;;
        --kernel-version) KERNEL_VERSION="$2"; shift 2 ;;
        --version)      VERSION="$2"; shift 2 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$CHROOT_DIR" ]]; then
    log_error "Missing required argument: --chroot"
    exit 1
fi

VERSION="${VERSION:-1.0}"

#======================================
# FUNCTIONS
#======================================

# Run command in chroot with proper environment
run_chroot() {
    chroot "$CHROOT_DIR" /bin/bash -c "DEBIAN_FRONTEND=noninteractive $1"
}

# Install packages with fallback and retry logic
install_packages() {
    local description="$1"
    shift
    local packages=("$@")
    
    log_info "Installing: $description"
    
    local pkg_list=$(IFS=' '; echo "${packages[*]}")
    
    # First attempt
    if run_chroot "apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install $pkg_list"; then
        log_success "$description installed"
        return 0
    fi
    
    # Retry: fix broken state and try again
    log_warning "First attempt failed, fixing dpkg state..."
    run_chroot "dpkg --configure -a" || true
    run_chroot "apt-get -y -f install" || true
    
    # Second attempt
    if run_chroot "apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install $pkg_list"; then
        log_success "$description installed (after retry)"
        return 0
    fi
    
    log_warning "Some packages in '$description' may have failed, continuing..."
    return 1
}

# Install critical package with multiple retries
install_critical_package() {
    local package="$1"
    local max_retries=3
    local retry=0
    
    log_info "Installing critical package: $package"
    
    while [[ $retry -lt $max_retries ]]; do
        # Fix any broken state first
        run_chroot "dpkg --configure -a" 2>/dev/null || true
        
        if run_chroot "apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install $package"; then
            log_success "$package installed"
            return 0
        fi
        
        retry=$((retry + 1))
        log_warning "Retry $retry/$max_retries for $package..."
        
        # Try to fix dependencies
        run_chroot "apt-get -y -f install" 2>/dev/null || true
    done
    
    log_error "Failed to install critical package: $package after $max_retries attempts"
    return 1
}

# Verify critical package
verify_package() {
    local package="$1"
    if run_chroot "dpkg -l $package 2>/dev/null | grep -q ^ii"; then
        return 0
    else
        return 1
    fi
}

#======================================
# START
#======================================
log_info "=========================================="
log_info "ValekOS Chroot Configuration v${SCRIPT_VERSION}"
log_info "=========================================="
log_info "Chroot: $CHROOT_DIR"
log_info "Config: ${CONFIG_DIR:-none}"
log_info "Theming: ${THEMING_DIR:-none}"
log_info "Version: $VERSION"
log_info "=========================================="

#======================================
# PREPARE CHROOT
#======================================
log_step "Preparing chroot environment..."

# Mount filesystems (critical for chroot operations)
for fs in dev dev/pts proc sys run; do
    if ! mountpoint -q "$CHROOT_DIR/$fs" 2>/dev/null; then
        mount --bind "/$fs" "$CHROOT_DIR/$fs" 2>/dev/null || true
    fi
done

# Copy DNS
cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

log_success "Chroot environment ready"

#======================================
# CRITICAL: FIX DPKG STATE FIRST
# This is the key fix for the conffile prompt issue
#======================================
log_step "Fixing dpkg state..."

# Ensure dpkg config directory exists
mkdir -p "$CHROOT_DIR/etc/dpkg/dpkg.cfg.d"

# Create dpkg config to force non-interactive conffile handling
cat > "$CHROOT_DIR/etc/dpkg/dpkg.cfg.d/99force-noninteractive" << 'EOF'
force-confdef
force-confold
EOF

# Fix any pending dpkg configurations
run_chroot "dpkg --configure -a" || log_warning "Initial dpkg configure had issues"

log_success "dpkg state prepared"

#======================================
# UPDATE PACKAGE LISTS
#======================================
log_step "Updating package lists..."

if ! run_chroot "apt-get update"; then
    log_error "apt-get update failed!"
    log_info "Attempting to fix..."
    
    # Try with allow-releaseinfo-change
    run_chroot "apt-get update --allow-releaseinfo-change" || {
        log_error "Cannot update package lists. Check network connection."
        exit 1
    }
fi

log_success "Package lists updated"

#======================================
# UPGRADE BASE SYSTEM
# Using force-confdef/confold to avoid conffile prompts
#======================================
log_step "Upgrading base system..."

run_chroot "apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade" || {
    log_warning "dist-upgrade had issues, trying to fix..."
    run_chroot "dpkg --configure -a" || true
    run_chroot "apt-get -y -f install" || true
}

log_success "Base system upgraded"

#======================================
# INSTALL CRITICAL PACKAGES
# These MUST succeed for ISO to work
#======================================
log_step "Installing CRITICAL packages (kernel, bootloader)..."

# Install kernel first with retries
if ! install_critical_package "linux-image-generic"; then
    log_error "Cannot install kernel - ISO will not boot!"
    
    # Fallback: try specific kernel version
    log_warning "Trying specific kernel version..."
    run_chroot "apt-cache search linux-image | grep generic | head -5" || true
    install_critical_package "linux-image-5.15.0-91-generic" || {
        log_error "No kernel could be installed. Aborting."
        exit 1
    }
fi

# Install kernel headers
install_critical_package "linux-headers-generic" || log_warning "Kernel headers installation failed (non-critical)"

# Install initramfs tools
install_critical_package "initramfs-tools" || log_warning "initramfs-tools installation had issues"

# Install GRUB packages
install_critical_package "grub-pc" || log_warning "grub-pc installation had issues"
install_critical_package "grub-efi-amd64" || log_warning "grub-efi-amd64 installation had issues"
install_critical_package "grub-efi-amd64-signed" || log_warning "grub-efi-amd64-signed installation had issues"
install_critical_package "shim-signed" || log_warning "shim-signed installation had issues"

#======================================
# VERIFY KERNEL INSTALLATION
# CRITICAL CHECK - Exit if kernel missing
#======================================
log_step "Verifying kernel installation..."

if ls "$CHROOT_DIR/boot/vmlinuz-"* 1>/dev/null 2>&1; then
    KERNEL_VER=$(ls "$CHROOT_DIR/boot/vmlinuz-"* | head -1 | sed 's/.*vmlinuz-//')
    log_success "Kernel found: $KERNEL_VER"
else
    log_error "========================================="
    log_error "CRITICAL ERROR: No kernel installed!"
    log_error "========================================="
    
    # Debug info
    log_info "Boot directory contents:"
    ls -la "$CHROOT_DIR/boot/" 2>/dev/null || echo "  (empty or missing)"
    
    log_info "Installed linux packages:"
    run_chroot "dpkg -l | grep -i linux" || echo "  (none found)"
    
    log_error "Cannot continue without a kernel."
    log_error "Please check apt-get errors above."
    exit 1
fi

# Verify initrd
if ! ls "$CHROOT_DIR/boot/initrd.img-"* 1>/dev/null 2>&1; then
    log_warning "No initrd found, generating..."
    run_chroot "update-initramfs -c -k all" || log_warning "Initrd generation may have issues"
fi

#======================================
# INSTALL SYSTEM PACKAGES
#======================================
log_step "Installing system packages..."

install_packages "Essential system tools" \
    systemd sudo passwd adduser locales tzdata \
    keyboard-configuration console-setup \
    network-manager curl wget ca-certificates \
    gnupg lsb-release software-properties-common

install_packages "Filesystem tools" \
    fdisk gdisk parted e2fsprogs dosfstools ntfs-3g exfat-fuse

install_packages "Archive tools" \
    p7zip-full unzip zip bzip2 gzip xz-utils

#======================================
# INSTALL DISPLAY SERVER
#======================================
log_step "Installing display server..."

install_packages "X11/Wayland" \
    xorg xserver-xorg xserver-xorg-video-all \
    xserver-xorg-input-all x11-xserver-utils plasma-workspace-wayland

#======================================
# INSTALL KDE PLASMA
#======================================
log_step "Installing KDE Plasma desktop..."

install_packages "KDE Plasma core" \
    plasma-desktop plasma-workspace kde-plasma-desktop \
    sddm sddm-theme-breeze breeze breeze-gtk-theme

install_packages "KDE applications" \
    dolphin konsole kate okular ark gwenview \
    systemsettings kinfocenter kscreen powerdevil

# Spectacle is sometimes named kde-spectacle or unavailable in some base images
install_packages "Screenshot tool" spectacle || install_packages "Screenshot tool fallback" kde-spectacle || true

#======================================
# INSTALL FIRMWARE
#======================================
log_step "Installing firmware..."

install_packages "Firmware packages" \
    linux-firmware firmware-linux firmware-amd-graphics \
    firmware-iwlwifi firmware-realtek firmware-brcm80211 || \
    log_warning "Some firmware packages unavailable, continuing..."

#======================================
# INSTALL GRAPHICS DRIVERS
#======================================
log_step "Installing graphics drivers..."

install_packages "Mesa/Vulkan drivers" \
    mesa-vulkan-drivers mesa-va-drivers mesa-utils \
    vulkan-tools libgl1-mesa-dri libgl1-mesa-glx || \
    log_warning "Some graphics packages may have failed"

#======================================
# INSTALL GAMING TOOLS
#======================================
log_step "Installing gaming tools..."

install_packages "Gaming packages" \
    steam lutris wine wine64 winetricks \
    gamemode gamescope mangohud || \
    log_warning "Some gaming packages unavailable"

#======================================
# INSTALL MULTIMEDIA
#======================================
log_step "Installing multimedia support..."

install_packages "Multimedia codecs" \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav ffmpeg || \
    log_warning "Some multimedia packages unavailable"

install_packages "Audio system" \
    pipewire pipewire-pulse wireplumber pavucontrol-qt

#======================================
# INSTALL NETWORK
#======================================
log_step "Installing network tools..."

install_packages "Network tools" \
    network-manager plasma-nm wireless-tools \
    wpasupplicant bluez bluedevil

#======================================
# INSTALL FONTS
#======================================
log_step "Installing fonts..."

install_packages "Fonts" \
    fonts-noto fonts-noto-color-emoji fonts-dejavu \
    fonts-liberation fonts-ubuntu fonts-roboto || \
    log_warning "Some fonts unavailable"

#======================================
# INSTALL BRAVE BROWSER
#======================================
log_step "Installing Brave Browser..."

# More robust Brave installation
run_chroot "curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" || log_warning "Failed to download Brave GPG key"

if [ -f "$CHROOT_DIR/usr/share/keyrings/brave-browser-archive-keyring.gpg" ]; then
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > "$CHROOT_DIR/etc/apt/sources.list.d/brave-browser-release.list"
    
    run_chroot "apt-get update" || log_warning "Apt update failed after adding Brave repo"

    install_packages "Brave Browser" brave-browser || log_warning "Brave Browser installation failed"
else
    log_warning "Brave GPG key missing, skipping installation"
fi

#======================================
# INSTALL SOFTWARE CENTER
#======================================
log_step "Installing software center..."

install_packages "Software center" \
    discover plasma-discover flatpak || \
    log_warning "Software center packages may have failed"

run_chroot "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo" 2>/dev/null || true

#======================================
# INSTALL UTILITIES
#======================================
log_step "Installing utilities..."

install_packages "System utilities" \
    htop gparted timeshift bleachbit

#======================================
# INSTALL CALAMARES
#======================================
log_step "Installing Calamares installer..."

install_packages "Calamares" \
    calamares qml-module-qtquick2 qml-module-qtquick-controls2 || \
    log_warning "Calamares installation may have failed - installer may not work"

#======================================
# INSTALL VM TOOLS
#======================================
log_step "Installing VM guest tools..."

install_packages "VM tools" \
    open-vm-tools open-vm-tools-desktop \
    spice-vdagent qemu-guest-agent || \
    log_warning "VM tools may have failed - VM features may be limited"

#======================================
# CONFIGURE SYSTEM
#======================================
log_step "Configuring system..."

# Locales
run_chroot "
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
" || log_warning "Locale configuration had issues"

# Timezone
run_chroot "ln -sf /usr/share/zoneinfo/UTC /etc/localtime" || true

#======================================
# CREATE DEFAULT USER
#======================================
log_step "Creating default user..."

run_chroot '
if ! id valek &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,audio,video,bluetooth valek
    echo "valek:valek" | chpasswd
fi
echo "root:root" | chpasswd
'

# Configure sudo
run_chroot '
echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd
chmod 440 /etc/sudoers.d/nopasswd
'

log_success "Default user 'valek' created"

#======================================
# CONFIGURE SDDM
#======================================
log_step "Configuring display manager..."

mkdir -p "$CHROOT_DIR/etc/sddm.conf.d"
cat > "$CHROOT_DIR/etc/sddm.conf.d/autologin.conf" << 'EOF'
[Autologin]
User=valek
Session=plasma.desktop

[Theme]
Current=breeze

[Users]
MinimumUid=1000
EOF

#======================================
# CONFIGURE GRUB
#======================================
log_step "Configuring GRUB..."

cat > "$CHROOT_DIR/etc/default/grub" << 'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR="ValekOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_GFXMODE=1920x1080,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
EOF

#======================================
# APPLY THEMING
#======================================
if [[ -n "${THEMING_DIR:-}" && -d "$THEMING_DIR" ]]; then
    log_step "Applying theming..."
    
    mkdir -p "$CHROOT_DIR/usr/share/wallpapers/ValekOS"
    mkdir -p "$CHROOT_DIR/usr/share/color-schemes"
    mkdir -p "$CHROOT_DIR/usr/share/plasma/look-and-feel"
    mkdir -p "$CHROOT_DIR/usr/share/plasma/plasmoids"
    mkdir -p "$CHROOT_DIR/usr/local/bin"
    
    [[ -d "$THEMING_DIR/wallpapers" ]] && \
        cp -r "$THEMING_DIR/wallpapers"/* "$CHROOT_DIR/usr/share/wallpapers/ValekOS/" 2>/dev/null || true
    
    [[ -d "$THEMING_DIR/color-schemes" ]] && \
        cp -r "$THEMING_DIR/color-schemes"/* "$CHROOT_DIR/usr/share/color-schemes/" 2>/dev/null || true

    # Install Windows 10 Look and Feel
    [[ -d "$THEMING_DIR/plasma/look-and-feel/com.valekos.windows10" ]] && \
        cp -r "$THEMING_DIR/plasma/look-and-feel/com.valekos.windows10" "$CHROOT_DIR/usr/share/plasma/look-and-feel/" 2>/dev/null || true

    # Install Hyper Island widget
    [[ -d "$THEMING_DIR/widgets/com.valekos.hyperisland" ]] && \
        cp -r "$THEMING_DIR/widgets/com.valekos.hyperisland" "$CHROOT_DIR/usr/share/plasma/plasmoids/" 2>/dev/null || true

    # Install custom scripts
    [[ -f "$SCRIPT_DIR/custom/valekos-sounds.sh" ]] && \
        cp "$SCRIPT_DIR/custom/valekos-sounds.sh" "$CHROOT_DIR/usr/local/bin/valekos-sounds" && \
        chmod +x "$CHROOT_DIR/usr/local/bin/valekos-sounds"

    # Install welcome app
    mkdir -p "$CHROOT_DIR/usr/share/valekos/welcome"
    [[ -d "$SCRIPT_DIR/custom/welcome" ]] && \
        cp -r "$SCRIPT_DIR/custom/welcome"/* "$CHROOT_DIR/usr/share/valekos/welcome/" 2>/dev/null || true
    mv "$CHROOT_DIR/usr/share/valekos/welcome/valekos-welcome.sh" "$CHROOT_DIR/usr/local/bin/valekos-welcome"
    chmod +x "$CHROOT_DIR/usr/local/bin/valekos-welcome"

    # Install skel config for default theme
    [[ -d "$THEMING_DIR/plasma/skel" ]] && \
        cp -r "$THEMING_DIR/plasma/skel/." "$CHROOT_DIR/etc/skel/" 2>/dev/null || true

    log_success "Theming applied"
fi

#======================================
# INSTALL LIVE-BOOT PACKAGES
# CRITICAL for live ISO functionality
#======================================
log_step "Installing live-boot packages..."

install_packages "Live boot support" \
    casper live-boot live-boot-initramfs-tools || \
    log_warning "Live-boot packages may have failed - ISO may not boot properly"

# Regenerate initrd with live-boot support
log_info "Regenerating initramfs..."
run_chroot "update-initramfs -u -k all" 2>/dev/null || \
    log_warning "Initramfs regeneration may have issues"

#======================================
# CLEANUP
#======================================
log_step "Cleaning up..."

run_chroot '
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -f /var/log/*.log
rm -f /var/log/apt/*.log
'

log_success "Cleanup complete"

#======================================
# CREATE VALEKOS IDENTITY FILES
# Do this AFTER all packages are installed to avoid conffile conflicts
#======================================
log_step "Setting ValekOS identity (final)..."

# Create custom os-release
cat > "$CHROOT_DIR/etc/os-release" << EOF
NAME="ValekOS"
VERSION="$VERSION"
ID=valekos
ID_LIKE="ubuntu debian"
PRETTY_NAME="ValekOS $VERSION"
VERSION_ID="${VERSION%%-*}"
VERSION_CODENAME=horizon
HOME_URL="https://github.com/valekos/valekos"
SUPPORT_URL="https://github.com/valekos/valekos/issues"
BUG_REPORT_URL="https://github.com/valekos/valekos/issues"
EOF

# Create custom lsb-release
cat > "$CHROOT_DIR/etc/lsb-release" << EOF
DISTRIB_ID=ValekOS
DISTRIB_RELEASE=$VERSION
DISTRIB_CODENAME=horizon
DISTRIB_DESCRIPTION="ValekOS $VERSION"
EOF

log_success "ValekOS identity set"

#======================================
# FINAL VERIFICATION
#======================================
log_step "Final verification..."

echo ""
log_info "=== Installed Components ==="

# Check critical components
check_component() {
    local name="$1"
    local check="$2"
    local critical="${3:-true}"
    
    if eval "$check"; then
        echo "  ✅ $name"
    else
        echo "  ❌ $name (MISSING)"
        if [[ "$critical" == "true" ]]; then
            return 1
        fi
    fi
    return 0
}

check_component "Kernel" "ls $CHROOT_DIR/boot/vmlinuz-* 1>/dev/null 2>&1"
check_component "Initrd" "ls $CHROOT_DIR/boot/initrd.img-* 1>/dev/null 2>&1"
check_component "GRUB" "[ -f $CHROOT_DIR/usr/sbin/grub-install ]"
check_component "KDE Plasma" "[ -d $CHROOT_DIR/usr/share/plasma ]"
check_component "Network Manager" "[ -f $CHROOT_DIR/usr/sbin/NetworkManager ]"
check_component "SDDM" "[ -f $CHROOT_DIR/usr/bin/sddm ]"
check_component "Calamares" "[ -f $CHROOT_DIR/usr/bin/calamares ]" false
check_component "Brave Browser" "[ -f $CHROOT_DIR/usr/bin/brave-browser ]" false

echo ""

# Calculate size
SIZE=$(du -sh "$CHROOT_DIR" 2>/dev/null | cut -f1)

log_success "=========================================="
log_success "Chroot configuration complete!"
log_success "=========================================="
log_info "Size: $SIZE"
log_info ""
log_info "Next step: Run build-iso.sh to create the ISO"
