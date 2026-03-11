#!/bin/bash
#===============================================================================
# ValekOS ISO Build Script (Robust Version v3)
#
# Creates a bootable hybrid ISO image (BIOS + UEFI)
# Based on best practices from Ubuntu live CD build process
#
# Includes multiple fallback mechanisms for robustness
#===============================================================================

set -euo pipefail

#======================================
# CONFIGURATION
#======================================
SCRIPT_VERSION="3.0"

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

LOG_DIR="/tmp/valekos_iso_logs"
mkdir -p "$LOG_DIR"

# Run a build step with detailed logging
run_step() {
    local step_name="$1"
    local command="$2"
    local log_file="$LOG_DIR/${step_name// /_}.log"

    log_step "Starting step: $step_name"

    if eval "$command" > "$log_file" 2>&1; then
        log_success "Completed: $step_name"
        return 0
    else
        log_error "FAILED: $step_name"
        echo -e "\n--- BEGIN ERROR LOG: $step_name ---"
        cat "$log_file"
        echo -e "--- END ERROR LOG: $step_name ---\n"
        return 1
    fi
}

#======================================
# ARGUMENTS
#======================================
CHROOT_DIR=""
OUTPUT_DIR=""
DIST_NAME="ValekOS"
VERSION=""
GRUB_DIR=""
CALAMARES_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --chroot)       CHROOT_DIR="$2"; shift 2 ;;
        --output)       OUTPUT_DIR="$2"; shift 2 ;;
        --name)         DIST_NAME="$2"; shift 2 ;;
        --version)      VERSION="$2"; shift 2 ;;
        --grub-dir)     GRUB_DIR="$2"; shift 2 ;;
        --calamares-dir) CALAMARES_DIR="$2"; shift 2 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$CHROOT_DIR" || -z "$OUTPUT_DIR" ]]; then
    log_error "Missing required arguments: --chroot and --output"
    exit 1
fi

VERSION="${VERSION:-1.0}"
ISO_NAME="${DIST_NAME,,}-${VERSION}-amd64"
ISO_FILE="${OUTPUT_DIR}/${ISO_NAME}.iso"

#======================================
# START
#======================================
log_info "=========================================="
log_info "ValekOS ISO Builder v${SCRIPT_VERSION}"
log_info "=========================================="
log_info "Chroot: $CHROOT_DIR"
log_info "Output: $OUTPUT_DIR"
log_info "Name: $DIST_NAME"
log_info "Version: $VERSION"
log_info "ISO: $ISO_FILE"
log_info "=========================================="

#======================================
# CRITICAL: VERIFY KERNEL
# Exit immediately if no kernel
#======================================
log_step "Verifying kernel installation..."

KERNEL_COUNT=$(ls "$CHROOT_DIR/boot/vmlinuz-"* 2>/dev/null | wc -l || echo "0")

if [[ "$KERNEL_COUNT" -eq 0 ]]; then
    log_error "============================================"
    log_error "CRITICAL ERROR: No kernel found!"
    log_error "============================================"
    log_error ""
    log_error "The chroot.sh script failed to install a kernel."
    log_error "Without a kernel, the ISO cannot boot."
    log_error ""
    log_error "Contents of $CHROOT_DIR/boot/:"
    ls -la "$CHROOT_DIR/boot/" 2>/dev/null || echo "  (directory not found)"
    log_error ""
    log_error "Please check the chroot.sh output above for errors."
    log_error "Common causes:"
    log_error "  1. apt-get update failed"
    log_error "  2. linux-image-generic package failed to install"
    log_error "  3. Network issues during package download"
    log_error "  4. dpkg conffile prompt blocked installation"
    log_error ""
    log_error "ISO build CANNOT continue."
    exit 1
fi

KERNEL_PATH=$(ls "$CHROOT_DIR/boot/vmlinuz-"* | head -1)
KERNEL_VER=$(basename "$KERNEL_PATH" | sed 's/vmlinuz-//')

log_success "Kernel found: $KERNEL_VER"

# Verify initrd
INITRD_COUNT=$(ls "$CHROOT_DIR/boot/initrd.img-"* 2>/dev/null | wc -l || echo "0")
if [[ "$INITRD_COUNT" -eq 0 ]]; then
    log_warning "No initrd found, generating..."
    
    # Mount proc for initramfs generation
    if ! mountpoint -q "$CHROOT_DIR/proc" 2>/dev/null; then
        mount --bind /proc "$CHROOT_DIR/proc" 2>/dev/null || true
    fi
    
    chroot "$CHROOT_DIR" update-initramfs -c -k "$KERNEL_VER" 2>/dev/null || {
        log_error "Failed to generate initrd!"
        exit 1
    }
fi

INITRD_PATH=$(ls "$CHROOT_DIR/boot/initrd.img-"* | head -1)
log_success "Initrd: $(basename "$INITRD_PATH")"

#======================================
# CREATE ISO STRUCTURE
#======================================
log_step "Creating ISO directory structure..."

ISO_ROOT="${OUTPUT_DIR}/iso_root"
mkdir -p "$ISO_ROOT"

# Clean up any previous build
rm -rf "${ISO_ROOT:?}"/*

# Create directories
mkdir -p "$ISO_ROOT"/{boot/grub/themes/valekos,boot/grub/x86_64-efi,EFI/BOOT,casper,.disk,install}
mkdir -p "$ISO_ROOT"/boot/grub/i386-pc

log_success "ISO structure created"

#======================================
# COPY KERNEL & INITRD
#======================================
log_step "Copying kernel and initrd to ISO..."

cp "$KERNEL_PATH" "$ISO_ROOT/boot/vmlinuz"
cp "$INITRD_PATH" "$ISO_ROOT/boot/initrd"

log_success "Kernel and initrd copied"

#======================================
# CREATE SQUASHFS
#======================================
log_step "Creating squashfs filesystem..."

# Prepare chroot for squashing
for dir in dev proc sys run tmp; do
    # Unmount if mounted
    umount "$CHROOT_DIR/$dir" 2>/dev/null || true
    umount "$CHROOT_DIR/$dir"/* 2>/dev/null || true
    # Clean and recreate
    rm -rf "$CHROOT_DIR/$dir"/* 2>/dev/null || true
    mkdir -p "$CHROOT_DIR/$dir"
done

# Create squashfs with good compression
log_info "Compressing filesystem (this takes several minutes)..."

SQUASHFS_SUCCESS=false

# Try zstd first (best compression)
if command -v mksquashfs &>/dev/null; then
    log_info "Attempting zstd compression..."
    if mksquashfs "$CHROOT_DIR" "$ISO_ROOT/casper/filesystem.squashfs" \
        -comp zstd -Xcompression-level 19 \
        -noappend -no-recovery \
        -wildcards \
        -e "var/cache/apt/archives/*" \
        -e "var/log/*" \
        -e "tmp/*" 2>/dev/null; then
        SQUASHFS_SUCCESS=true
        log_success "Squashfs created with zstd compression"
    fi
fi

# Fallback to gzip
if [[ "$SQUASHFS_SUCCESS" = false ]]; then
    log_warning "zstd failed, trying gzip..."
    if mksquashfs "$CHROOT_DIR" "$ISO_ROOT/casper/filesystem.squashfs" \
        -comp gzip \
        -noappend -no-recovery \
        -wildcards \
        -e "var/cache/apt/archives/*" \
        -e "var/log/*" \
        -e "tmp/*"; then
        SQUASHFS_SUCCESS=true
        log_success "Squashfs created with gzip compression"
    fi
fi

# Fallback to xz
if [[ "$SQUASHFS_SUCCESS" = false ]]; then
    log_warning "gzip failed, trying xz..."
    if mksquashfs "$CHROOT_DIR" "$ISO_ROOT/casper/filesystem.squashfs" \
        -comp xz \
        -noappend -no-recovery \
        -wildcards \
        -e "var/cache/apt/archives/*" \
        -e "var/log/*" \
        -e "tmp/*"; then
        SQUASHFS_SUCCESS=true
        log_success "Squashfs created with xz compression"
    fi
fi

# Final fallback - no compression
if [[ "$SQUASHFS_SUCCESS" = false ]]; then
    log_warning "All compression methods failed, trying uncompressed..."
    if mksquashfs "$CHROOT_DIR" "$ISO_ROOT/casper/filesystem.squashfs" \
        -noappend -no-recovery; then
        SQUASHFS_SUCCESS=true
        log_success "Squashfs created (uncompressed)"
    else
        log_error "Failed to create squashfs!"
        exit 1
    fi
fi

# Record filesystem size
FILESYSTEM_SIZE=$(du -s "$CHROOT_DIR" | cut -f1)
echo "$FILESYSTEM_SIZE" > "$ISO_ROOT/casper/filesystem.size"

log_success "Squashfs size: $(du -sh "$ISO_ROOT/casper/filesystem.squashfs" | cut -f1)"

#======================================
# CREATE FILESYSTEM MANIFEST
#======================================
log_step "Creating filesystem manifest..."

# Mount proc for chroot commands
if ! mountpoint -q "$CHROOT_DIR/proc" 2>/dev/null; then
    mount --bind /proc "$CHROOT_DIR/proc" 2>/dev/null || true
fi

chroot "$CHROOT_DIR" dpkg-query -W --showformat='${Package}\t${Version}\n' \
    > "$ISO_ROOT/casper/filesystem.manifest" 2>/dev/null || {
    log_warning "Could not create manifest"
    touch "$ISO_ROOT/casper/filesystem.manifest"
}

cp "$ISO_ROOT/casper/filesystem.manifest" "$ISO_ROOT/casper/filesystem.manifest-desktop"

#======================================
# CREATE DISK INFO
#======================================
log_step "Creating disk metadata..."

cat > "$ISO_ROOT/.disk/info" << EOF
${DIST_NAME} ${VERSION} - Live amd64 ($(date +%Y%m%d))
EOF

echo "full_cd/single" > "$ISO_ROOT/.disk/cd_type"

#======================================
# CONFIGURE GRUB
#======================================
log_step "Configuring GRUB bootloader..."

# Copy GRUB modules for UEFI
if [[ -d /usr/lib/grub/x86_64-efi ]]; then
    cp /usr/lib/grub/x86_64-efi/*.mod "$ISO_ROOT/boot/grub/x86_64-efi/" 2>/dev/null || true
    cp /usr/lib/grub/x86_64-efi/*.lst "$ISO_ROOT/boot/grub/x86_64-efi/" 2>/dev/null || true
fi

# Copy GRUB modules for BIOS
if [[ -d /usr/lib/grub/i386-pc ]]; then
    cp /usr/lib/grub/i386-pc/*.mod "$ISO_ROOT/boot/grub/i386-pc/" 2>/dev/null || true
    cp /usr/lib/grub/i386-pc/*.lst "$ISO_ROOT/boot/grub/i386-pc/" 2>/dev/null || true
fi

# Copy GRUB theme
if [[ -n "${GRUB_DIR:-}" && -d "${GRUB_DIR}/theme" ]]; then
    cp -r "${GRUB_DIR}/theme"/* "$ISO_ROOT/boot/grub/themes/valekos/" 2>/dev/null || true
fi

# Create GRUB config
cat > "$ISO_ROOT/boot/grub/grub.cfg" << EOF
# ValekOS GRUB Configuration
set default=0
set timeout=10
set gfxmode=1920x1080,auto
set gfxpayload=keep

insmod all_video
insmod gfxterm
insmod png
insmod part_gpt
insmod part_msdos
insmod ext2
terminal_output gfxterm

menuentry "Start ${DIST_NAME}" {
    linux /boot/vmlinuz boot=casper quiet splash ---
    initrd /boot/initrd
}

menuentry "Start ${DIST_NAME} (Safe Graphics)" {
    linux /boot/vmlinuz boot=casper quiet splash nomodeset ---
    initrd /boot/initrd
}

menuentry "Start ${DIST_NAME} (Debug Mode)" {
    linux /boot/vmlinuz boot=casper debug ---
    initrd /boot/initrd
}

menuentry "Install ${DIST_NAME}" {
    linux /boot/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /boot/initrd
}
EOF

# Loopback config
echo 'source /boot/grub/grub.cfg' > "$ISO_ROOT/boot/grub/loopback.cfg"

log_success "GRUB configured"

#======================================
# CREATE EFI BOOT
#======================================
run_step "Create EFI Image" '
    EFI_IMG="${OUTPUT_DIR}/efi.img"
    dd if=/dev/zero of="$EFI_IMG" bs=1M count=64
    mkfs.vfat -F 32 "$EFI_IMG"

    EFI_MNT="${OUTPUT_DIR}/efi_mnt"
    mkdir -p "$EFI_MNT"
    mount -o loop "$EFI_IMG" "$EFI_MNT"

    mkdir -p "$EFI_MNT/EFI/BOOT"
    mkdir -p "$EFI_MNT/boot/grub/x86_64-efi"

    if [[ -d /usr/lib/grub/x86_64-efi ]]; then
        cp /usr/lib/grub/x86_64-efi/*.mod "$EFI_MNT/boot/grub/x86_64-efi/" || true
        cp /usr/lib/grub/x86_64-efi/*.lst "$EFI_MNT/boot/grub/x86_64-efi/" || true
    fi

    cat > "$EFI_MNT/EFI/BOOT/grub.cfg" << EOF
set default=0
set timeout=10
insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "Start ${DIST_NAME}" {
    linux /boot/vmlinuz boot=casper quiet splash ---
    initrd /boot/initrd
}

menuentry "Install ${DIST_NAME}" {
    linux /boot/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /boot/initrd
}
EOF

    SHIM_SOURCES=(
        "$CHROOT_DIR/usr/lib/shim/shimx64.efi.signed"
        "$CHROOT_DIR/usr/lib/shim/shimx64.efi"
        "/usr/lib/shim/shimx64.efi.signed"
        "/usr/lib/shim/shimx64.efi"
        "/usr/share/shim/shimx64.efi.signed"
    )
    for src in "${SHIM_SOURCES[@]}"; do
        if [[ -f "$src" ]]; then
            cp "$src" "$EFI_MNT/EFI/BOOT/BOOTX64.EFI" && break
        fi
    done

    GRUB_SOURCES=(
        "$CHROOT_DIR/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"
        "$CHROOT_DIR/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi"
        "/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"
    )
    for src in "${GRUB_SOURCES[@]}"; do
        if [[ -f "$src" ]]; then
            cp "$src" "$EFI_MNT/EFI/BOOT/grubx64.efi" && break
        fi
    done

    MOK_SOURCES=(
        "$CHROOT_DIR/usr/lib/shim/mmx64.efi"
        "/usr/lib/shim/mmx64.efi"
    )
    for src in "${MOK_SOURCES[@]}"; do
        if [[ -f "$src" ]]; then
            cp "$src" "$EFI_MNT/EFI/BOOT/" && break
        fi
    done

    sync
    umount "$EFI_MNT"
    rmdir "$EFI_MNT"
' || exit 1

#======================================
# CREATE ISO
#======================================
log_step "Creating ISO image..."

# Check for required files
ISOLINUX_BIN=""
for path in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin /usr/share/syslinux/isohdpfx.bin; do
    if [[ -f "$path" ]]; then
        ISOLINUX_BIN="$path"
        break
    fi
done

ISO_SUCCESS=false

if [[ -n "$ISOLINUX_BIN" ]]; then
    # Hybrid ISO (BIOS + UEFI)
    log_info "Creating hybrid ISO (BIOS + UEFI)..."
    
    # First, create a BIOS boot image using GRUB
    CORE_IMG="${OUTPUT_DIR}/core.img"
    
    # Create BIOS bootable GRUB core image
    if command -v grub-mkimage &>/dev/null && [[ -d /usr/lib/grub/i386-pc ]]; then
        grub-mkimage -o "$CORE_IMG" -O i386-pc -p "(cd0)/boot/grub" \
            biosdisk part_msdos part_gpt ext2 iso9660 linux normal \
            2>/dev/null || true
        
        if [[ -f "$CORE_IMG" ]]; then
            # Create eltorito boot image
            cat /usr/lib/grub/i386-pc/cdboot.img "$CORE_IMG" > "$ISO_ROOT/boot/grub/i386-pc/eltorito.img" 2>/dev/null || true
        fi
    fi
    
    # Try hybrid ISO creation
    if xorriso -as mkisofs \
        -r -V "${DIST_NAME} ${VERSION}" \
        -o "$ISO_FILE" \
        -J -joliet-long \
        -cache-inodes \
        -isohybrid-mbr "$ISOLINUX_BIN" \
        -b boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot \
        -e --interval:appended_partition_2:all:: \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -append_partition 2 0xef "$EFI_IMG" \
        "$ISO_ROOT" 2>/dev/null; then
        ISO_SUCCESS=true
        log_success "Hybrid ISO created (BIOS + UEFI)"
    fi
fi

# Fallback: UEFI-only ISO
if [[ "$ISO_SUCCESS" = false ]]; then
    log_warning "Hybrid ISO failed, creating UEFI-only ISO..."
    
    if xorriso -as mkisofs \
        -r -V "${DIST_NAME} ${VERSION}" \
        -o "$ISO_FILE" \
        -J -joliet-long \
        -append_partition 2 0xef "$EFI_IMG" \
        -e --interval:appended_partition_2:all:: \
        -no-emul-boot \
        "$ISO_ROOT"; then
        ISO_SUCCESS=true
        log_success "UEFI-only ISO created"
    fi
fi

# Final fallback: Simple ISO
if [[ "$ISO_SUCCESS" = false ]]; then
    log_warning "xorriso options failed, trying simple ISO..."
    
    # Copy EFI image to ISO root
    cp "$EFI_IMG" "$ISO_ROOT/efi.img"
    
    if xorriso -as mkisofs \
        -r -V "${DIST_NAME} ${VERSION}" \
        -o "$ISO_FILE" \
        -J -joliet-long \
        "$ISO_ROOT"; then
        ISO_SUCCESS=true
        log_success "Simple ISO created"
    fi
fi

if [[ "$ISO_SUCCESS" = false ]]; then
    log_error "All ISO creation methods failed!"
    exit 1
fi

# Make hybrid bootable (BIOS support) - only if file exists
if command -v isohybrid &>/dev/null && [[ -n "$ISOLINUX_BIN" ]] && [[ -f "$ISO_FILE" ]]; then
    isohybrid "$ISO_FILE" 2>/dev/null || log_warning "isohybrid failed (UEFI-only ISO)"
fi

#======================================
# CLEANUP
#======================================
log_step "Cleaning up..."

rm -rf "${ISO_ROOT:?}"
rm -f "$EFI_IMG"
rm -f "${CORE_IMG:-}" 2>/dev/null || true

#======================================
# VERIFY & SUMMARIZE
#======================================
log_step "Verifying ISO..."

if [[ -f "$ISO_FILE" ]]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    
    # Generate checksums
    cd "$(dirname "$ISO_FILE")"
    sha256sum "$(basename "$ISO_FILE")" > SHA256SUMS
    md5sum "$(basename "$ISO_FILE")" > MD5SUMS
    
    log_success "=========================================="
    log_success "ISO created successfully!"
    log_success "=========================================="
    log_info "File: $ISO_FILE"
    log_info "Size: $ISO_SIZE"
    log_info ""
    log_info "SHA256:"
    head -1 SHA256SUMS
    log_info ""
    log_info "Boot modes:"
    echo "  ✅ UEFI boot"
    [[ -n "$ISOLINUX_BIN" ]] && echo "  ✅ BIOS boot" || echo "  ⚠️  BIOS boot (may not work)"
    echo ""
    log_info "To test: qemu-system-x86_64 -m 4G -cdrom $ISO_FILE -boot d"
else
    log_error "ISO creation failed!"
    exit 1
fi
