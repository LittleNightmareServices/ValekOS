# ValekOS Build Troubleshooting Guide

## Common Errors and Solutions

### Error: `dpkg: error processing package base-files (--configure): end of file on stdin at conffile prompt`

**Cause**: This is the most common error. When `/etc/lsb-release` or `/etc/os-release` files are created before package installation, and the `base-files` package is upgraded, dpkg prompts for conffile handling. In a non-interactive environment, this causes the installation to fail.

**Solutions**:
1. **The fix is already applied in v3 scripts** - The bootstrap.sh now creates ValekOS identity files AFTER all packages are installed.

2. **If you encounter this manually**, run:
   ```bash
   # Fix dpkg state
   chroot /build/chroot dpkg --configure -a
   
   # Use force-conf options
   chroot /build/chroot apt-get -y \
     -o Dpkg::Options::="--force-confdef" \
     -o Dpkg::Options::="--force-confold" \
     install base-files
   ```

3. **Prevent the issue**: Create dpkg config before any apt operations:
   ```bash
   cat > /build/chroot/etc/dpkg/dpkg.cfg.d/99force-noninteractive << 'EOF'
   force-confdef
   force-confold
   EOF
   ```

---

### Error: `debootstrap failed`

**Cause**: Network issues, invalid mirror, or missing packages.

**Solutions**:
1. Check internet connection
2. Try a different mirror:
   ```bash
   # Edit bootstrap.sh, change MIRROR to:
   MIRROR="http://us.archive.ubuntu.com/ubuntu"
   # or
   MIRROR="http://mirrors.edge.kernel.org/ubuntu"
   ```
3. Run with verbose output:
   ```bash
   DEBOOTSTRAP_DEBUG=5 ./build/scripts/bootstrap.sh ...
   ```

---

### Error: `No kernel found`

**Cause**: apt-get failed during chroot.sh, or package installation was interrupted.

**Solutions**:
1. Check apt logs in chroot:
   ```bash
   cat /build/chroot/var/log/apt/term.log
   ```
2. Manually install kernel:
   ```bash
   chroot /build/chroot apt-get update
   chroot /build/chroot apt-get -y \
     -o Dpkg::Options::="--force-confdef" \
     -o Dpkg::Options::="--force-confold" \
     install linux-image-generic
   ```
3. Use fallback script:
   ```bash
   ./build/scripts/fallback-bootstrap.sh --chroot /build/chroot
   ```

---

### Error: `GPG error: The following signatures couldn't be verified`

**Cause**: Missing GPG keys for a repository.

**Solutions**:
1. Remove problematic repository:
   ```bash
   rm /build/chroot/etc/apt/sources.list.d/*.list
   ```
2. Use Ubuntu repos only (recommended):
   ```bash
   cat > /build/chroot/etc/apt/sources.list << 'EOF'
   deb http://archive.ubuntu.com/ubuntu jammy main universe multiverse
   deb http://archive.ubuntu.com/ubuntu jammy-updates main universe multiverse
   deb http://archive.ubuntu.com/ubuntu jammy-security main universe multiverse
   EOF
   ```

---

### Error: `E: Unable to locate package`

**Cause**: Package name incorrect, repository not enabled, or package list not updated.

**Solutions**:
1. Update package lists:
   ```bash
   chroot /build/chroot apt-get update
   ```
2. Search for the correct package name:
   ```bash
   chroot /build/chroot apt-cache search <search-term>
   ```
3. Check if repository is enabled in `/etc/apt/sources.list`

---

### Error: `mksquashfs: command not found`

**Cause**: squashfs-tools not installed on build host.

**Solution**:
```bash
sudo apt-get install squashfs-tools
```

---

### Error: `xorriso: failed to create ISO`

**Cause**: Missing EFI files or grub modules.

**Solutions**:
1. Install required packages:
   ```bash
   sudo apt-get install grub-pc-bin grub-efi-amd64-bin \
       grub-efi-amd64-signed shim-signed xorriso isolinux
   ```
2. The script will fall back to UEFI-only ISO if hybrid fails.

---

### Error: `initrd not found`

**Cause**: initramfs-tools not properly configured.

**Solution**:
```bash
chroot /build/chroot update-initramfs -c -k all
```

---

### Error: GitHub Actions runs out of disk space

**Cause**: Build artifacts consuming all available space.

**Solutions**:
1. The workflow includes disk cleanup steps
2. Reduce package list to essential packages only
3. Consider using self-hosted runner with more storage

---

### Error: `chroot: failed to run command`

**Cause**: /bin/bash or required libraries not present in chroot.

**Solution**:
```bash
# Verify chroot structure
ls -la /build/chroot/bin/bash
ls -la /build/chroot/lib/x86_64-linux-gnu/

# If missing, re-run bootstrap
./build/scripts/bootstrap.sh --distro ubuntu --release jammy --chroot /build/chroot
```

---

### Error: `1 not fully installed or removed`

**Cause**: A package configuration was interrupted, leaving dpkg in a broken state.

**Solution**:
```bash
# Fix any pending configurations
chroot /build/chroot dpkg --configure -a

# Fix broken dependencies
chroot /build/chroot apt-get -f install
```

---

## Debug Mode

Run any script with debug output:
```bash
bash -x ./build/scripts/bootstrap.sh --chroot /build/chroot
```

## Manual Build Steps

If all scripts fail, you can build manually:

```bash
# 1. Bootstrap
sudo debootstrap --arch=amd64 jammy /build/chroot http://archive.ubuntu.com/ubuntu

# 2. Mount
sudo mount --bind /dev /build/chroot/dev
sudo mount --bind /proc /build/chroot/proc
sudo mount --bind /sys /build/chroot/sys

# 3. Configure dpkg for non-interactive
sudo mkdir -p /build/chroot/etc/dpkg/dpkg.cfg.d
cat << 'EOF' | sudo tee /build/chroot/etc/dpkg/dpkg.cfg.d/99force-noninteractive
force-confdef
force-confold
EOF

# 4. Chroot and install
sudo chroot /build/chroot /bin/bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  install linux-image-generic

# 5. Build ISO manually (see build-iso.sh for details)
```

## Version History

| Version | Changes |
|---------|---------|
| v3.0 | Fixed dpkg conffile prompt issue; added dpkg force-conf options; moved ValekOS identity creation to end of chroot.sh |
| v2.0 | Simplified scripts; added kernel verification; removed Linux Mint repo |
| v1.0 | Initial version |

## Getting Help

1. Check GitHub Actions logs for detailed error messages
2. Review `/var/log/` inside the chroot for package installation errors
3. Open an issue with full error output
