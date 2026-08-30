#!/bin/bash
set -e

# ==============================================================================
# Mooziac Studio — Standalone Dev & Automation Command Center Build & Run
# Always terminates old instances, cleans old bundles, compiles, installs & runs.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="MooziacStudio.app"
APP_BUNDLE_ID="app.mooziac.studio"
APP_VERSION="1.0.0"
APP_BUILD="1"
APP_DESCRIPTION="Mooziac Studio — Native Full-Stack Automation & Command Center"

DIST_DIR="$SCRIPT_DIR/dist"
TARGET_APP="$DIST_DIR/$APP_NAME"
LOCAL_APP_DEST="$HOME/Applications/$APP_NAME"

LAUNCH_AFTER_BUILD=true

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-launch) LAUNCH_AFTER_BUILD=false; shift ;;
        --run) LAUNCH_AFTER_BUILD=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=========================================="
echo "  🎛️ Building Mooziac Studio               "
echo "=========================================="

echo "[1/4] Terminating old Studio processes..."
killall "MooziacStudio" 2>/dev/null || true
pkill -9 -f "MooziacStudio" 2>/dev/null || true
sleep 0.3

echo "[2/4] Compiling MooziacStudio binary..."
swift build -c release --product MooziacStudio

BIN_DIR=$(swift build -c release --show-bin-path)
BIN_PATH="$BIN_DIR/MooziacStudio"

if [ ! -f "$BIN_PATH" ]; then
    echo "❌ Error: MooziacStudio binary not found at $BIN_PATH"
    exit 1
fi

echo "[3/4] Assembling bundle in dist/ and installing to ~/Applications..."
BUNDLE_DIR="$TARGET_APP/Contents"
MACOS_DIR="$BUNDLE_DIR/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Resources"

# Clean old bundles
rm -rf "$TARGET_APP"
rm -rf "$LOCAL_APP_DEST"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/MooziacStudio"
chmod +x "$MACOS_DIR/MooziacStudio"

# Copy dedicated Studio icon
if [ -f "Resources/StudioAppIcon.icns" ]; then
    cp "Resources/StudioAppIcon.icns" "$RESOURCES_DIR/StudioAppIcon.icns"
    cp "Resources/StudioAppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat << EOF > "$BUNDLE_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MooziacStudio</string>
    <key>CFBundleIdentifier</key>
    <string>$APP_BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>MooziacStudio</string>
    <key>CFBundleDisplayName</key>
    <string>Mooziac Studio</string>
    <key>CFBundleIconFile</key>
    <string>StudioAppIcon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "[4/4] Code signing and installing..."
strip -x -S "$MACOS_DIR/MooziacStudio"
codesign --force --deep --options runtime --sign - --identifier "$APP_BUNDLE_ID" "$TARGET_APP"

mkdir -p "$HOME/Applications"
cp -R "$TARGET_APP" "$LOCAL_APP_DEST"

echo ""
echo "=========================================="
echo "  ✅ Mooziac Studio Installed & Ready!"
echo "=========================================="
echo "  • Local Bundle:   $TARGET_APP"
echo "  • Installed to:   $LOCAL_APP_DEST"
echo "=========================================="

if [ "$LAUNCH_AFTER_BUILD" = true ]; then
    echo "🚀 Launching new Mooziac Studio..."
    open "$LOCAL_APP_DEST"
fi
