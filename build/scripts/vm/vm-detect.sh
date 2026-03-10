#!/bin/bash
#===============================================================================
# ValekOS Virtual Machine Detection and Optimization Script
#
# This script detects if ValekOS is running in a virtual machine and applies
# appropriate optimizations for better performance in VM environments.
#
# Supported VMs:
#   - VMware (Workstation, Fusion, ESXi)
#   - VirtualBox
#   - QEMU/KVM
#   - Hyper-V
#   - Parallels
#   - Xen
#
# Usage: This script runs at boot time via systemd service
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[VM-DETECT]${NC} $1"; }
log_success() { echo -e "${GREEN}[VM-DETECT]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[VM-DETECT]${NC} $1"; }

# VM detection variables
VM_TYPE="none"
VM_VENDOR=""
IS_VM=false

# Detect virtual machine
detect_vm() {
    log_info "Detecting virtual machine environment..."

    # Check for VMware
    if [ -f /sys/class/dmi/id/product_name ] && grep -qi "vmware" /sys/class/dmi/id/product_name 2>/dev/null; then
        VM_TYPE="vmware"
        VM_VENDOR="VMware"
        IS_VM=true
        log_info "Detected: VMware environment"
    fi

    # Check for VirtualBox
    if [ -f /sys/class/dmi/id/product_name ] && grep -qi "virtualbox" /sys/class/dmi/id/product_name 2>/dev/null; then
        VM_TYPE="virtualbox"
        VM_VENDOR="Oracle VirtualBox"
        IS_VM=true
        log_info "Detected: VirtualBox environment"
    fi

    # Check for QEMU/KVM
    if [ -f /sys/class/dmi/id/product_name ] && grep -qi "qemu\|kvm\|bochs" /sys/class/dmi/id/product_name 2>/dev/null; then
        VM_TYPE="qemu"
        VM_VENDOR="QEMU/KVM"
        IS_VM=true
        log_info "Detected: QEMU/KVM environment"
    fi

    # Check for Hyper-V
    if [ -f /sys/class/dmi/id/product_name ] && grep -qi "hyper-v\|microsoft corporation" /sys/class/dmi/id/product_name 2>/dev/null; then
        VM_TYPE="hyperv"
        VM_VENDOR="Microsoft Hyper-V"
        IS_VM=true
        log_info "Detected: Hyper-V environment"
    fi

    # Check for Parallels
    if [ -f /sys/class/dmi/id/product_name ] && grep -qi "parallels" /sys/class/dmi/id/product_name 2>/dev/null; then
        VM_TYPE="parallels"
        VM_VENDOR="Parallels"
        IS_VM=true
        log_info "Detected: Parallels environment"
    fi

    # Check for Xen
    if [ -f /proc/xen/capabilities ] 2>/dev/null || [ -d /sys/hypervisor/xen ]; then
        VM_TYPE="xen"
        VM_VENDOR="Xen"
        IS_VM=true
        log_info "Detected: Xen environment"
    fi

    # Alternative detection via CPUID
    if command -v systemd-detect-virt &>/dev/null; then
        DETECTED_VM=$(systemd-detect-virt --vm 2>/dev/null || echo "none")
        if [ "$DETECTED_VM" != "none" ] && [ "$DETECTED_VM" != "" ]; then
            if [ "$VM_TYPE" = "none" ]; then
                VM_TYPE="$DETECTED_VM"
                VM_VENDOR="$DETECTED_VM"
                IS_VM=true
                log_info "Detected via systemd: $VM_VENDOR"
            fi
        fi
    fi

    # Create VM info file
    mkdir -p /run/valekos
    cat > /run/valekos/vm-info << EOF
VALEKOS_VM_DETECTED=$IS_VM
VALEKOS_VM_TYPE=$VM_TYPE
VALEKOS_VM_VENDOR=$VM_VENDOR
VALEKOS_VM_TIMESTAMP=$(date -Iseconds)
EOF

    if [ "$IS_VM" = true ]; then
        log_success "Running in virtual machine: $VM_VENDOR"
        return 0
    else
        log_success "Running on physical hardware"
        return 1
    fi
}

# Apply VMware optimizations
optimize_vmware() {
    log_info "Applying VMware optimizations..."

    # Enable VMware Tools services if available
    systemctl enable vmtoolsd 2>/dev/null || true
    systemctl start vmtoolsd 2>/dev/null || true

    # Enable VMware clipboard and drag-drop
    systemctl enable vgauth 2>/dev/null || true
    systemctl start vgauth 2>/dev/null || true

    # Set optimal resolution
    if command -v vmware-toolbox-cmd &>/dev/null; then
        vmware-toolbox-cmd -k stat sessionid 2>/dev/null || true
    fi

    # Configure kernel parameters for VMware
    echo "vm.swappiness=10" >> /etc/sysctl.d/99-valekos-vm.conf
    echo "vm.dirty_ratio=20" >> /etc/sysctl.d/99-valekos-vm.conf
    echo "vm.dirty_background_ratio=5" >> /etc/sysctl.d/99-valekos-vm.conf

    log_success "VMware optimizations applied"
}

# Apply VirtualBox optimizations
optimize_virtualbox() {
    log_info "Applying VirtualBox optimizations..."

    # Enable VirtualBox Guest Additions services
    systemctl enable vboxservice 2>/dev/null || true
    systemctl start vboxservice 2>/dev/null || true

    # Configure kernel parameters for VirtualBox
    echo "vm.swappiness=10" >> /etc/sysctl.d/99-valekos-vm.conf
    echo "vm.dirty_ratio=20" >> /etc/sysctl.d/99-valekos-vm.conf

    # Disable heavy compositor effects
    mkdir -p /home/*/.config
    for userhome in /home/*; do
        if [ -d "$userhome" ]; then
            username=$(basename "$userhome")
            if [ -d "$userhome/.config" ]; then
                # Reduce animations for better performance
                cat > "$userhome/.config/kdeglobals" << EOF
[KDE]
AnimationDurationFactor=0.5
EOF
                chown "$username:$username" "$userhome/.config/kdeglobals" 2>/dev/null || true
            fi
        fi
    done

    log_success "VirtualBox optimizations applied"
}

# Apply QEMU/KVM optimizations
optimize_qemu() {
    log_info "Applying QEMU/KVM optimizations..."

    # Install and configure spice-vdagent if available
    systemctl enable spice-vdagentd 2>/dev/null || true
    systemctl start spice-vdagentd 2>/dev/null || true

    # Enable qemu-guest-agent
    systemctl enable qemu-guest-agent 2>/dev/null || true
    systemctl start qemu-guest-agent 2>/dev/null || true

    # Optimize for virtio
    echo "vm.swappiness=10" >> /etc/sysctl.d/99-valekos-vm.conf

    # Set scheduler for virtio devices
    for dev in /sys/block/vd*/queue/scheduler; do
        if [ -f "$dev" ]; then
            echo "none" > "$dev" 2>/dev/null || true
        fi
    done

    log_success "QEMU/KVM optimizations applied"
}

# Apply Hyper-V optimizations
optimize_hyperv() {
    log_info "Applying Hyper-V optimizations..."

    # Enable Hyper-V daemons
    systemctl enable hv-fcopy-daemon 2>/dev/null || true
    systemctl start hv-fcopy-daemon 2>/dev/null || true
    systemctl enable hv-kvp-daemon 2>/dev/null || true
    systemctl start hv-kvp-daemon 2>/dev/null || true
    systemctl enable hv-vss-daemon 2>/dev/null || true
    systemctl start hv-vss-daemon 2>/dev/null || true

    # Hyper-V specific kernel parameters
    echo "vm.swappiness=10" >> /etc/sysctl.d/99-valekos-vm.conf

    log_success "Hyper-V optimizations applied"
}

# Apply Parallels optimizations
optimize_parallels() {
    log_info "Applying Parallels optimizations..."

    # Enable Parallels Tools
    systemctl enable prl-tools 2>/dev/null || true
    systemctl start prl-tools 2>/dev/null || true

    echo "vm.swappiness=10" >> /etc/sysctl.d/99-valekos-vm.conf

    log_success "Parallels optimizations applied"
}

# Apply generic VM optimizations
optimize_generic() {
    log_info "Applying generic VM optimizations..."

    # Reduce memory pressure
    sysctl -w vm.swappiness=10
    sysctl -w vm.dirty_ratio=20
    sysctl -w vm.dirty_background_ratio=5

    # Reduce GPU acceleration in VM
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/99-vm-graphics.conf << 'EOF'
Section "Device"
    Identifier "VM Graphics"
    Driver "modesetting"
    Option "AccelMethod" "none"
EndSection
EOF

    # Reduce desktop effects for better VM performance
    mkdir -p /etc/skel/.config
    cat > /etc/skel/.config/kdeglobals << EOF
[KDE]
AnimationDurationFactor=0.5

[Compositing]
OpenGLIsUnsafe=true
EOF

    log_success "Generic VM optimizations applied"
}

# Configure VM-specific services
configure_services() {
    log_info "Configuring VM-specific services..."

    # Create VM info notification
    if [ "$IS_VM" = true ]; then
        # Create a notification for the user
        mkdir -p /etc/profile.d
        cat > /etc/profile.d/vm-notify.sh << EOF
#!/bin/bash
# Notify user about VM mode
if [ -f /run/valekos/vm-info ]; then
    source /run/valekos/vm-info
    if [ "\$VALEKOS_VM_DETECTED" = "true" ]; then
        # Set environment variable for apps
        export VALEKOS_VM_MODE="\$VALEKOS_VM_TYPE"
        export VALEKOS_VM_VENDOR="\$VALEKOS_VM_VENDOR"
    fi
fi
EOF
        chmod +x /etc/profile.d/vm-notify.sh
    fi

    log_success "VM services configured"
}

# Main function
main() {
    log_info "ValekOS VM Detection and Optimization"
    log_info "======================================"

    # Detect VM
    detect_vm

    # Apply optimizations based on VM type
    if [ "$IS_VM" = true ]; then
        case "$VM_TYPE" in
            vmware)
                optimize_vmware
                ;;
            virtualbox)
                optimize_virtualbox
                ;;
            qemu)
                optimize_qemu
                ;;
            hyperv)
                optimize_hyperv
                ;;
            parallels)
                optimize_parallels
                ;;
            *)
                optimize_generic
                ;;
        esac

        configure_services

        # Create VM mode indicator file
        mkdir -p /var/lib/valekos
        echo "$VM_TYPE" > /var/lib/valekos/vm-mode
        echo "$VM_VENDOR" > /var/lib/valekos/vm-vendor

        log_success "VM optimizations complete!"
    else
        log_info "No VM detected, skipping optimizations"
    fi
}

# Run main function
main "$@"
