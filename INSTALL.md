# Installation Guide

## Quick Install (For Users)

```bash
# Clone the repository
git clone https://github.com/arealicehole/vocoder.git
cd vocoder

# Run the installer
./install.sh
```

## Manual Install (For Developers)

### 1. Install System Dependencies
```bash
# Fedora/RHEL
sudo dnf install portaudio-devel python3-devel

# Ubuntu/Debian  
sudo apt install portaudio19-dev python3-dev

# For typing support
sudo dnf install ydotool  # Fedora
# OR
sudo apt install ydotool  # Ubuntu
```

### 2. Install Python Package
```bash
# Method A: With virtual environment (recommended)
./scripts/setup-venv.sh

# Method B: System-wide
pip install -r requirements.lock
```

### 3. Setup Service
```bash
# Copy service file
mkdir -p ~/.config/systemd/user
cp daemon/vocoder.service ~/.config/systemd/user/

# Enable and start
systemctl --user enable --now vocoder.service
```

### 4. Configure Hotkey
```bash
# GNOME (Super+Space)
./scripts/setup-keybinding.sh
```

## For Package Maintainers

### Build Python Package
```bash
# Build wheel
python -m build

# Install from wheel
pip install dist/vocoder-*.whl
```

### Create System Package
```bash
# RPM
rpmbuild -ba vocoder.spec

# DEB
dpkg-buildpackage -us -uc
```