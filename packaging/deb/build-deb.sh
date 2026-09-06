#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VERSION="0.16.2"
PACKAGE_NAME="vocalinux-qwen"
ARCH="amd64"
BUILD_DIR="$REPO_ROOT/dist/deb-build"
DEB_ROOT="$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"
OUTPUT_DEB="$REPO_ROOT/dist/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

echo "=== Building Debian package for Vocalinux with Qwen / transcribe.cpp ==="
rm -rf "$BUILD_DIR"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/opt/vocalinux"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/scalable/apps"

echo "[1/5] Creating isolated virtualenv in /opt/vocalinux/venv..."
python3 -m venv --system-site-packages "$DEB_ROOT/opt/vocalinux/venv"

echo "[2/5] Copying application and dependencies into bundle..."
rsync -a --exclude '__pycache__' --exclude '*.pyc'     /home/toto/.local/share/vocalinux/venv/lib/     "$DEB_ROOT/opt/vocalinux/venv/lib/"

rsync -a --exclude '__pycache__' --exclude '*.pyc'     /home/toto/.local/share/vocalinux/venv/bin/     "$DEB_ROOT/opt/vocalinux/venv/bin/"

sed -i 's|/home/toto/.local/share/vocalinux/venv|/opt/vocalinux/venv|g' "$DEB_ROOT/opt/vocalinux/venv/bin/"* 2>/dev/null || true

echo "[3/5] Bundling transcribe-cli binary..."
TRANSCRIBE_BIN="/home/toto/Documents/temp/transcribe.cpp/build/bin/transcribe-cli"
if [ ! -f "$TRANSCRIBE_BIN" ]; then
    echo "ERROR: transcribe-cli binary not found at $TRANSCRIBE_BIN"
    exit 1
fi
cp "$TRANSCRIBE_BIN" "$DEB_ROOT/usr/bin/transcribe-cli"
chmod 755 "$DEB_ROOT/usr/bin/transcribe-cli"

cat << 'LAUNCHER' > "$DEB_ROOT/usr/bin/vocalinux"
#!/bin/bash
export PYTHONNOUSERSITE=1
export GI_TYPELIB_PATH=/usr/lib/x86_64-linux-gnu/girepository-1.0:${GI_TYPELIB_PATH:-}

VENV_PATH="/opt/vocalinux/venv"
EXEC_CMD="$VENV_PATH/bin/python3 $VENV_PATH/bin/vocalinux-gui $@"

if grep -q "^input:.*$(whoami)" /etc/group 2>/dev/null && ! groups | grep -q "input" && command -v sg &>/dev/null; then
    exec sg input -c "$EXEC_CMD"
else
    exec $EXEC_CMD
fi
LAUNCHER
chmod 755 "$DEB_ROOT/usr/bin/vocalinux"
ln -sf /usr/bin/vocalinux "$DEB_ROOT/usr/bin/vocalinux-gui"

echo "[4/5] Installing desktop file and icons..."
cp "$REPO_ROOT/vocalinux.desktop" "$DEB_ROOT/usr/share/applications/vocalinux.desktop"
sed -i 's|^Exec=.*|Exec=/usr/bin/vocalinux|' "$DEB_ROOT/usr/share/applications/vocalinux.desktop"

if [ -d "$REPO_ROOT/resources/icons/scalable" ]; then
    cp "$REPO_ROOT/resources/icons/scalable"/*.svg "$DEB_ROOT/usr/share/icons/hicolor/scalable/apps/" 2>/dev/null || true
    # Also render standard PNG icon resolutions for desktop environments (like KDE Plasma) that require raster icons
    python3 - << 'PY' "$REPO_ROOT" "$DEB_ROOT" 2>/dev/null || true
import sys, os
from gi.repository import GdkPixbuf
repo_root, deb_root = sys.argv[1], sys.argv[2]
svg_path = os.path.join(repo_root, "resources/icons/scalable/vocalinux.svg")
if os.path.isfile(svg_path):
    for size in [16, 24, 32, 48, 64, 128, 256, 512]:
        dest_dir = os.path.join(deb_root, f"usr/share/icons/hicolor/{size}x{size}/apps")
        os.makedirs(dest_dir, exist_ok=True)
        try:
            pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(svg_path, size, size, True)
            pb.savev(os.path.join(dest_dir, "vocalinux.png"), "png", [], [])
        except Exception:
            pass
PY
fi

mkdir -p "$DEB_ROOT/opt/vocalinux/resources"
if [ -d "$REPO_ROOT/resources" ]; then
    rsync -a "$REPO_ROOT/resources/" "$DEB_ROOT/opt/vocalinux/resources/"
fi

cat << EOF > "$DEB_ROOT/DEBIAN/control"
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: python3, python3-gi, python3-gi-cairo, gir1.2-gtk-3.0, gir1.2-ayatanaappindicator3-0.1 | gir1.2-appindicator3-0.1, libportaudio2, pulseaudio | pipewire-pulse
Maintainer: Toto Sugito <totosugito@users.noreply.github.com>
Description: Seamless voice dictation system for Linux with Qwen3-ASR and transcribe.cpp
 Vocalinux is an on-device, offline voice-to-text application for Linux.
 This customized edition includes built-in transcribe.cpp engine support
 and Qwen3-ASR model capability for ultra-fast, accurate offline dictation.
EOF

cat << 'POSTINST' > "$DEB_ROOT/DEBIAN/postinst"
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
fi
exit 0
POSTINST
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

cat << 'POSTRM' > "$DEB_ROOT/DEBIAN/postrm"
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
fi
exit 0
POSTRM
chmod 755 "$DEB_ROOT/DEBIAN/postrm"

echo "[5/5] Packaging .deb using dpkg-deb..."
mkdir -p "$REPO_ROOT/dist"
dpkg-deb --build --root-owner-group "$DEB_ROOT" "$OUTPUT_DEB"

echo "=== Successfully built: $OUTPUT_DEB ==="
ls -lh "$OUTPUT_DEB"
