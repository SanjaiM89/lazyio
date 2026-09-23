#!/usr/bin/env bash
#
# Build script for creating a self-contained Lazyio AppImage with bundled Qt 6
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-1.0.0}"
BUILD_DIR="$PROJECT_ROOT/build_appimage"
APPDIR="$PROJECT_ROOT/AppDir"
OUTPUT_DIR="$PROJECT_ROOT/dist"

echo "============================================================"
echo " Building Lazyio AppImage v${VERSION} (Bundled Qt 6)"
echo "============================================================"

# 1. Clean previous build dirs
rm -rf "$BUILD_DIR" "$APPDIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# 2. Configure & Build Desktop app with CMake
cd "$PROJECT_ROOT"
cmake -S Desktop -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLAZYIO_VERSION="$VERSION" \
    -DCMAKE_INSTALL_PREFIX=/usr

cmake --build "$BUILD_DIR"

# 3. Stage files into AppDir
DESTDIR="$APPDIR" cmake --install "$BUILD_DIR"

# 4. Icon setup for linuxdeploy
ICON_DIR="/tmp/lazyio-appimage-icon"
mkdir -p "$ICON_DIR"
cp "$PROJECT_ROOT/Desktop/resources/icons/png/lazyio-256.png" "$ICON_DIR/lazyio.png"

# 5. Download/setup linuxdeploy tools
TOOLS_DIR="$PROJECT_ROOT/tools_appimage"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

if [ ! -f "linuxdeploy" ]; then
    echo "Downloading linuxdeploy..."
    wget -q "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" -O linuxdeploy.AppImage
    chmod +x linuxdeploy.AppImage
    ./linuxdeploy.AppImage --appimage-extract >/dev/null && mv squashfs-root linuxdeploy
    rm -f linuxdeploy.AppImage
fi

if [ ! -f "linuxdeploy-plugin-qt" ]; then
    echo "Downloading linuxdeploy-plugin-qt..."
    wget -q "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" -O plugin-qt.AppImage
    chmod +x plugin-qt.AppImage
    ./plugin-qt.AppImage --appimage-extract >/dev/null && mv squashfs-root linuxdeploy-plugin-qt
    rm -f plugin-qt.AppImage
fi

if [ ! -f "appimagetool" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -O appimagetool.AppImage
    chmod +x appimagetool.AppImage
    ./appimagetool.AppImage --appimage-extract >/dev/null && mv squashfs-root appimagetool
    rm -f appimagetool.AppImage
fi

mkdir -p bin
ln -sf "$TOOLS_DIR/linuxdeploy-plugin-qt/AppRun" bin/linuxdeploy-plugin-qt
ln -sf "$TOOLS_DIR/appimagetool/AppRun" bin/appimagetool

export PATH="$TOOLS_DIR/bin:$PATH"

# 6. Environment setup for linuxdeploy-plugin-qt to bundle ALL QML & Qt 6 modules
QMAKE_BIN="$(which qmake6 2>/dev/null || which qmake 2>/dev/null || echo "")"
if [ -n "$QMAKE_BIN" ]; then
    export QMAKE="$QMAKE_BIN"
fi

export QML_SOURCES_PATHS="$PROJECT_ROOT/Desktop/qml"
export EXTRA_QT_PLUGINS="platforms;platformthemes;xcbglintegrations;multimedia;iconengines;imageformats;styles"
export VERSION="$VERSION"

echo "Running linuxdeploy to bundle Qt 6 and QML dependencies..."
cd "$PROJECT_ROOT"

"$TOOLS_DIR/linuxdeploy/AppRun" \
    --appdir "$APPDIR" \
    -e "$APPDIR/usr/bin/lazyio" \
    -d "$APPDIR/usr/share/applications/lazyio.desktop" \
    -i "$ICON_DIR/lazyio.png" \
    --plugin qt \
    --output appimage

APPIMAGE_FILE=$(ls Lazyio-*.AppImage 2>/dev/null | head -n 1 || echo "")
if [ -n "$APPIMAGE_FILE" ]; then
    TARGET_NAME="lazyio-${VERSION}-linux-x86_64.AppImage"
    mv "$APPIMAGE_FILE" "$OUTPUT_DIR/$TARGET_NAME"
    echo "============================================================"
    echo " SUCCESS: Built self-contained AppImage at:"
    echo " $OUTPUT_DIR/$TARGET_NAME"
    echo "============================================================"
else
    echo "Error: AppImage file was not generated."
    exit 1
fi
