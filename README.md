# 🐧 ValekOS

<div align="center">

![ValekOS](https://img.shields.io/badge/ValekOS-Linux%20Distribution-blue?style=for-the-badge)
![Base](https://img.shields.io/badge/Base-Linux%20Mint%20Cinnamon-green?style=for-the-badge)
![Desktop](https://img.shields.io/badge/Desktop-KDE%20Plasma-purple?style=for-the-badge)
![License](https://img.shields.io/badge/License-GPL%20v3-orange?style=for-the-badge)

**A modern gaming-focused Linux distribution with HyperOS-inspired aesthetics**

[Features](#-features) • [Download](#-download) • [Build](#-build-from-source) • [Customization](#-customization) • [Contributing](#-contributing)

</div>

---

## 🎯 Overview

**ValekOS** is a custom Linux distribution designed for gamers and power users who want a beautiful, performant, and gaming-ready operating system out of the box. Built on the solid foundation of Linux Mint Cinnamon, it features:

- **KDE Plasma Desktop** with HyperOS3-inspired theming
- **Gaming-optimized kernel** with AMD driver support
- **Secure Boot** support for modern hardware
- **Curated software selection** for gaming and daily use

---

## ✨ Features

### 🎮 Gaming Focused
- Pre-installed gaming tools (Steam, Lutris, Heroic Games Launcher)
- Proton-GE and Wine-GE pre-configured
- GameMode and Gamemode-optimized kernel parameters
- AMD GPU drivers with Mesa latest
- Controller support (Xbox, PlayStation, Nintendo)

### 🖥️ Desktop Experience
- **KDE Plasma 6** desktop environment
- **HyperOS3-inspired theming** (glassmorphism, fluid animations)
- **Black & Blue color scheme** throughout the system
- Custom SDDM login theme
- Curated icon pack matching the aesthetic

### 🔒 Security & Performance
- **Secure Boot** compatible
- **Custom optimized kernel** (Liquorix-based for gaming)
- Pre-configured firewall and security settings
- Automatic updates enabled by default

### 📦 Pre-installed Software
| Category | Applications |
|----------|-------------|
| **Browser** | Brave Browser |
| **Store** | Discover Software Center |
| **Files** | Dolphin File Manager |
| **Settings** | KDE System Settings |
| **Terminal** | Konsole |
| **Gaming** | Steam, Lutris, Heroic, MangoHud |
| **Media** | VLC, Elisa Music Player |
| **Utilities** | Kate, Ark, Spectacle |

---

## 📥 Download

### System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| RAM | 4 GB | 8+ GB |
| Storage | 32 GB | 64+ GB SSD |
| CPU | Dual-core 64-bit | Quad-core+ |
| GPU | Any with OpenGL 3.3 | AMD Radeon RX / NVIDIA GTX |

### Download ISO

Download the latest release from our [Releases Page](../../releases).

---

## 🔨 Build from Source

### Prerequisites

- GitHub account
- Git
- (Optional) Local Linux machine for testing

### Building via GitHub Actions (Recommended)

1. **Fork this repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/ValekOS.git
   cd ValekOS
   ```

2. **Enable GitHub Actions**
   - Go to your fork → Actions tab
   - Click "I understand my workflows, go ahead and enable them"

3. **Trigger a Build**
   - Go to Actions → "Build ValekOS ISO"
   - Click "Run workflow"
   - Select options:
     - `release_type`: `nightly`, `beta`, or `stable`
     - `enable_testing`: `true` for additional tests

4. **Download Your ISO**
   - Wait 1-2 hours for the build
   - Download from the "Artifacts" section or Releases

### Local Building (Advanced)

```bash
# On a Debian/Ubuntu/Mint system
sudo apt install debootstrap squashfs-tools genisoimage

# Clone and build
git clone https://github.com/YOUR_USERNAME/ValekOS.git
cd ValekOS
sudo ./build/build.sh
```

---

## 🎨 Customization

### Changing the Theme

Edit `theming/plasma/theme.conf` to customize:
- Accent colors
- Transparency levels
- Blur effects
- Animation speeds

### Adding Software

Edit `build/configs/packages.list`:
```
# Add one package per line
your-package-name
another-package
```

### Kernel Configuration

Edit `kernel/kernel.config` to modify:
- Module inclusion
- Driver support
- Performance tuning

---

## 📁 Repository Structure

```
ValekOS/
├── .github/
│   └── workflows/
│       └── build-iso.yml          # GitHub Actions build workflow
├── build/
│   ├── scripts/
│   │   ├── bootstrap.sh           # Initial system bootstrap
│   │   ├── chroot.sh              # Chroot customization
│   │   ├── build-iso.sh           # ISO generation
│   │   └── cleanup.sh             # Cleanup utilities
│   └── configs/
│       ├── packages.list          # Software to install
│       ├── repositories.list      # APT repositories
│       └── locale.conf            # Locale settings
├── bootloaders/
│   ├── grub/
│   │   ├── grub.cfg               # GRUB configuration
│   │   └── theme/                 # GRUB theme files
│   └── systemd-boot/              # systemd-boot configs
├── calamares/
│   ├── branding/
│   │   └── valekos/               # Installer branding
│   └── modules/                   # Calamares module configs
├── theming/
│   ├── plasma/                    # KDE Plasma theme
│   ├── color-schemes/             # Color schemes
│   ├── icons/                     # Icon theme
│   ├── cursors/                   # Cursor theme
│   ├── wallpapers/                # Default wallpapers
│   └── sddm/                      # Login screen theme
├── kernel/
│   ├── kernel.config              # Custom kernel config
│   └── patches/                   # Kernel patches
├── secureboot/
│   └── shim-signing/              # Secure Boot files
└── README.md
```

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

ValekOS is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.

Individual components may have their own licenses:
- Linux Mint components: Various GPL licenses
- KDE Plasma: LGPL/GPL
- Included software: Respective licenses

---

## 🙏 Acknowledgments

- **Linux Mint Team** - For the excellent base distribution
- **KDE Community** - For the beautiful Plasma desktop
- **Xiaomi HyperOS** - Design inspiration
- **GitHub Actions** - For free CI/CD infrastructure

---

<div align="center">

**Made with ❤️ by the ValekOS Team**

[Website](#) • [Discord](#) • [Forum](#) • [Wiki](#)

</div>
