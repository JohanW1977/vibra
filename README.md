# Vibra++ Plasmoid — Installation Guide

A Shazam-like music recognition plasmoid for KDE Plasma 6.
---

Backend by Bayern Muller (C++ code), frontend Plasmoid generated with ChatGPT and Claude AI

## Screenshots
![Search tab](https://github.com/JohanW1977/vibra/contents/docs/01.png?raw=true "Search Tab")
![Settings tab]([/](https://github.com/JohanW1977/vibra/)contents/docs/02.png?raw=true "Settings Tab")
![Info Tab]([/](https://github.com/JohanW1977/vibra/)contents/docs/03.png?raw=true "Info Tab")


## Prerequisites

### Fedora / RHEL-based

```bash
sudo dnf install \
    cmake \
    extra-cmake-modules \
    gcc-c++ \
    qt6-qtbase-devel \
    qt6-qtdeclarative-devel \
    kf6-ki18n-devel \
    kf6-kpackage-devel \
    plasma-devel \
    pipewire-utils \
    pulseaudio-utils \
    kf6-knotifications-devel \
    git
```

### Arch / CachyOS / Manjaro

```bash
sudo pacman -S \
    cmake \
    extra-cmake-modules \
    gcc \
    qt6-base \
    qt6-declarative \
    ki18n \
    kpackage \
    libplasma \
    pipewire \
    pipewire-pulse \
    libpulse \
    git
```

### Ubuntu / Debian-based

```bash
sudo apt install \
    cmake \
    extra-cmake-modules \
    g++ \
    qt6-base-dev \
    qt6-declarative-dev \
    libkf6i18n-dev \
    libkf6package-dev \
    libplasma-dev \
    pipewire \
    libpipewire-0.3-dev \
    pulseaudio-utils \
    git
```

---

## Installation

### 1. Copy the plasmoid

Copy the `org.kde.plasma.vibra` folder to:

```bash
~/.local/share/plasma/plasmoids/
```

So the structure looks like:

```
~/.local/share/plasma/plasmoids/org.kde.plasma.vibra/
├── contents/
├── plugin/
├── vibra/
├── CMakeLists.txt
├── build.sh
└── metadata.json
```

### 2. Set permissions

```bash
cd ~/.local/share/plasma/plasmoids/org.kde.plasma.vibra
chmod +x build.sh
# Fix permissions if copy stripped execute bits
find . -name "*.sh" -exec chmod +x {} \;
chmod -R a+rX .
```

### 3. Build and install

```bash
rm -rf build && ./build.sh
```

The script will:
- Clone the vibra C++ backend from GitHub (if not already present)
- Build the Qt plugin
- Install to `~/.local/share/plasma/plasmoids/org.kde.plasma.vibra/`
- Install to the system Qt6 QML path (requires sudo/fingerprint)

### 4. Restart Plasma

```bash
kquitapp6 plasmashell && kstart plasmashell
```

### 5. Add the widget

Right-click the panel → **Add Widgets** → search **"Vibra"** → add it to your panel.

---

## First-time setup

Open the plasmoid and go to the **Settings tab**:

- **Source** — select the audio source to listen to:
  - *Monitor of [device]* — captures audio playing through that device
  - *[device] input* — captures ambient sound via microphone
- **Listen duration** — minimum 15 seconds, recommended 20-25 seconds
- **Show notifications** — shows a notification when a track is identified
- **Start listening at startup** — automatically starts listening when Plasma starts
- **Cover art quality** — High quality (800x800) or Standard (400x400)

---

## Troubleshooting

### "vibra binary not found"
The vibra backend wasn't built. Run `./build.sh` again from the plasmoid root.

### "module org.kde.plasma.vibra is not installed"
The plugin wasn't installed to the system Qt6 QML path. The build script does this automatically, but the path differs per distro:
- Fedora: `/usr/lib64/qt6/qml/`
- Arch/Ubuntu: `/usr/lib/qt6/qml/`

Manually install:
```bash
# Fedora
sudo mkdir -p /usr/lib64/qt6/qml/org/kde/plasma/vibra
sudo cp ~/.local/share/plasma/plasmoids/org.kde.plasma.vibra/contents/imports/org/kde/plasma/vibra/* \
        /usr/lib64/qt6/qml/org/kde/plasma/vibra/

# Arch/Ubuntu
sudo mkdir -p /usr/lib/qt6/qml/org/kde/plasma/vibra
sudo cp ~/.local/share/plasma/plasmoids/org.kde.plasma.vibra/contents/imports/org/kde/plasma/vibra/* \
        /usr/lib/qt6/qml/org/kde/plasma/vibra/
```

### "cmake: command not found"
```bash
# Fedora
sudo dnf install cmake

# Arch
sudo pacman -S cmake

# Ubuntu
sudo apt install cmake
```

### Recognition fails immediately
- Check that `pw-record` is available: `which pw-record`
- Check that `pactl` is available: `which pactl`
- Make sure PipeWire is running: `systemctl --user status pipewire`
- Try a longer listen duration (25-30 seconds)

### No devices in the source dropdown
Click the refresh button next to the source dropdown. If still empty, check that `pactl` is installed.

---

## Notes

- Settings and history are stored in KDE's config system and survive Plasma restarts
- History is limited to 50 entries
- The plasmoid continues listening/recognizing even when minimized
- Desktop notifications require the "Show notifications" setting to be enabled
- Notifications only appear when the plasmoid is minimized

