#!/usr/bin/env bash
# build.sh — Build vibra + the Vibra plasmoid QML plugin, then install.
#
# Run from the plasmoid root:
#   cd ~/.local/share/plasma/plasmoids/org.kde.plasma.vibra
#   bash build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

# ── 1. Clone vibra if not present ───────────────────────────────────────────
if [ ! -d "${SCRIPT_DIR}/vibra/.git" ]; then
    echo "==> Cloning vibra..."
    git clone --depth=1 https://github.com/BayernMuller/vibra.git \
        "${SCRIPT_DIR}/vibra"
else
    echo "==> vibra already present, skipping clone."
fi

# ── 2. CMake configure + build ───────────────────────────────────────────────
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "==> Configuring..."
cmake "${SCRIPT_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${HOME}/.local"

echo "==> Building..."
make -j"$(nproc)"

# ── 3. Install into plasmoid package ─────────────────────────────────────────
echo "==> Installing plugin into plasmoid package..."
make install

# ── 4. Install into system Qt6 QML path ──────────────────────────────────────
# Detect system Qt6 QML path (differs between distros)
if [ -d "/usr/lib64/qt6/qml" ]; then
    QT6_QML_PATH="/usr/lib64/qt6/qml"
elif [ -d "/usr/lib/qt6/qml" ]; then
    QT6_QML_PATH="/usr/lib/qt6/qml"
else
    QT6_QML_PATH=$(qml6 -query QML2_IMPORT_PATH 2>/dev/null | head -1 || echo "")
fi

if [ -n "${QT6_QML_PATH}" ]; then
    DEST="${QT6_QML_PATH}/org/kde/plasma/vibra"
    echo "==> Installing plugin into system Qt6 QML path (requires sudo)..."
    sudo mkdir -p "${DEST}"
    sudo cp "${SCRIPT_DIR}/contents/imports/org/kde/plasma/vibra/"* "${DEST}/"
    echo "    Installed to: ${DEST}"
else
    echo "==> WARNING: Could not detect Qt6 QML path. Plugin may not be found by plasmashell."
fi

echo ""
echo "==> Done!"
echo ""
echo "    Restart Plasma to activate:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
echo ""
echo "    Or test with:"
echo "    QML2_IMPORT_PATH=${SCRIPT_DIR}/contents/imports plasmoidviewer -a org.kde.plasma.vibra"
