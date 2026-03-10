# ValekOS Build Makefile
# Simplified build commands for local development

.PHONY: all clean build bootstrap chroot iso help

# Default target
all: help

# Build everything
build: bootstrap chroot iso

# Bootstrap the base system
bootstrap:
	@echo "Bootstrapping ValekOS base system..."
	sudo ./build/scripts/bootstrap.sh \
		--distro linuxmint \
		--release victoria \
		--chroot /build/chroot \
		--version "1.0-dev"

# Configure system in chroot
chroot:
	@echo "Configuring ValekOS system..."
	sudo ./build/scripts/chroot.sh \
		--chroot /build/chroot \
		--config-dir ./build/configs \
		--theming-dir ./theming \
		--kernel-version "6.8" \
		--version "1.0-dev"

# Build the ISO
iso:
	@echo "Building ValekOS ISO..."
	sudo ./build/scripts/build-iso.sh \
		--chroot /build/chroot \
		--output /build/iso \
		--name "ValekOS" \
		--version "1.0-dev" \
		--grub-dir ./bootloaders/grub \
		--calamares-dir ./calamares

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	sudo rm -rf /build/chroot
	sudo rm -rf /build/iso
	sudo rm -rf /build/*.img

# Install dependencies (Debian/Ubuntu/Mint)
deps:
	sudo apt-get update
	sudo apt-get install -y \
		debootstrap \
		squashfs-tools \
		genisoimage \
		isolinux \
		syslinux-common \
		grub-pc-bin \
		grub-efi-amd64-bin \
		grub-efi-amd64-signed \
		mtools \
		dosfstools \
		xorriso \
		openssl \
		gpg \
		curl \
		wget \
		git

# Run in VM (requires QEMU)
test-iso:
	@echo "Testing ISO in QEMU..."
	qemu-system-x86_64 \
		-m 4G \
		-cdrom /build/iso/*.iso \
		-boot d \
		-enable-kvm \
		-cpu host \
		-smp 2

# Show help
help:
	@echo "ValekOS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Show this help"
	@echo "  build     - Build everything (bootstrap + chroot + iso)"
	@echo "  bootstrap - Bootstrap the base system"
	@echo "  chroot    - Configure system in chroot"
	@echo "  iso       - Build the ISO image"
	@echo "  clean     - Clean build artifacts"
	@echo "  deps      - Install build dependencies"
	@echo "  test-iso  - Test ISO in QEMU"
	@echo ""
	@echo "GitHub Actions Build:"
	@echo "  Push to main branch or run workflow manually"
	@echo ""
	@echo "Local Build:"
	@echo "  make deps && sudo make build"
