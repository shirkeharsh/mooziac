#!/bin/bash
set -e

# ==============================================================================
# Mooziac Unified Build & Packaging Pipeline
# Compiles Universal binary, builds .app, packages .dmg & .zip, and installs locally.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_VERSION="1.0.8"
APP_BUILD="8"
APP_NAME="Mooziac.app"
APP_BUNDLE_ID="app.mooziac.mac"
APP_COPYRIGHT="Copyright © 2026 ThreeTen. All rights reserved."
APP_DESCRIPTION="Mooziac — Modern Music Player for macOS with edge trackpad controls & YouTube Music WebKit sync."
VOLUME_NAME="Mooziac"
ZIP_NAME="Mooziac.zip"

LAUNCH_AFTER_BUILD=true

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-launch) LAUNCH_AFTER_BUILD=false; shift ;;
        --version) APP_VERSION="$2"; shift 2 ;;
        --build) APP_BUILD="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

DIST_DIR="$SCRIPT_DIR/dist"
STAGING_DIR="$DIST_DIR/staging"
TEMP_DMG="$DIST_DIR/temp.dmg"
FINAL_DMG="$DIST_DIR/Mooziac.dmg"
LOCAL_APP_DEST="$HOME/Applications/$APP_NAME"
TARGET_APP="$STAGING_DIR/$APP_NAME"

DMG_COMMENT="Mooziac — macOS Music Player Installer
Version $APP_VERSION (Build $APP_BUILD)
$APP_COPYRIGHT"

echo "=========================================="
echo "      🚀 Mooziac All-in-One Build         "
echo "      Version: $APP_VERSION ($APP_BUILD)  "
echo "=========================================="

echo "[1/7] Terminating old running processes..."
killall "Mooziac" 2>/dev/null || true
pkill -9 -f "Mooziac" 2>/dev/null || true
sleep 0.5

# Clean previous build artifacts
rm -rf "$STAGING_DIR" "$TEMP_DMG"
mkdir -p "$DIST_DIR"
mkdir -p "$STAGING_DIR"

# Ensure DMG background exists and is up to date
if [ -f "scripts/generate_dmg_background.swift" ]; then
    echo "    Generating DMG background artwork..."
    swift scripts/generate_dmg_background.swift > /dev/null 2>&1 || true
fi

echo "[2/7] Compiling release binaries..."
# Attempt Universal 2 build (arm64 + x86_64)
UNIVERSAL_BIN="$DIST_DIR/Mooziac_universal"
ARM_BIN=".build/arm64-apple-macosx/release/Mooziac"
INTEL_BIN=".build/x86_64-apple-macosx/release/Mooziac"

echo "    [1/2] Compiling Apple Silicon (arm64)..."
if swift build --triple arm64-apple-macosx -c release --product Mooziac && \
   echo "    [2/2] Compiling Intel (x86_64)..." && \
   swift build --triple x86_64-apple-macosx -c release --product Mooziac; then
    echo "    ✔ Merging arm64 and x86_64 into Universal 2 binary via lipo..."
    lipo -create -output "$UNIVERSAL_BIN" "$ARM_BIN" "$INTEL_BIN"
    BIN_PATH="$UNIVERSAL_BIN"
else
    echo "    ⚠️ Universal build failed. Compiling for native architecture..."
    swift build -c release --product Mooziac
    BIN_DIR=$(swift build -c release --show-bin-path)
    BIN_PATH="$BIN_DIR/Mooziac"
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "❌ Error: Mooziac binary not found at $BIN_PATH"
    exit 1
fi

echo "[3/7] Assembling $APP_NAME bundle..."
BUNDLE_DIR="$TARGET_APP/Contents"
MACOS_DIR="$BUNDLE_DIR/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/Mooziac"

# Copy runtime assets from Resources/
for asset in AppIcon.icns MOOZIAC_transparent.png launch_transparent.png MOOZIAC.png MenuBarIcon.png MenuBarIcon@2x.png trackpad.html macbook_panel.jpg dmg_background.png; do
    if [ -f "Resources/$asset" ]; then
        cp "Resources/$asset" "$RESOURCES_DIR/$asset"
    fi
done

# Create production Info.plist
cat << EOF > "$BUNDLE_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mooziac</string>
    <key>CFBundleIdentifier</key>
    <string>$APP_BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Mooziac</string>
    <key>CFBundleDisplayName</key>
    <string>Mooziac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>NSHumanReadableCopyright</key>
    <string>$APP_COPYRIGHT</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleGetInfoString</key>
    <string>Mooziac $APP_VERSION, $APP_COPYRIGHT</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>$APP_BUNDLE_ID</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mooziac</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

chmod +x "$MACOS_DIR/Mooziac"

echo "[4/7] Stripping symbols and code signing with Hardened Runtime..."
strip -x -S "$MACOS_DIR/Mooziac"

ENTITLEMENTS_FLAG=""
if [ -f "Mooziac.entitlements" ]; then
    ENTITLEMENTS_FLAG="--entitlements Mooziac.entitlements"
fi

SIGN_STATUS="Ad-hoc signed (Hardened Runtime)"
SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development|Developer ID Application/ {print $2}' | head -1)
if [ -n "$SIGN_IDENTITY" ]; then
    echo "    Signing with certificate: $SIGN_IDENTITY"
    codesign --force --deep --options runtime $ENTITLEMENTS_FLAG --sign "$SIGN_IDENTITY" --identifier "$APP_BUNDLE_ID" "$TARGET_APP"
    SIGN_STATUS="Valid signature ($SIGN_IDENTITY)"
else
    echo "    Ad-hoc signing with Hardened Runtime..."
    codesign --force --deep --options runtime $ENTITLEMENTS_FLAG --sign - --identifier "$APP_BUNDLE_ID" "$TARGET_APP"
fi

codesign --verify --deep --strict "$TARGET_APP" 2>/dev/null || true

echo "[5/7] Creating ZIP distribution..."
cd "$STAGING_DIR"
rm -f "$DIST_DIR/$ZIP_NAME"
zip -r -y -q "$DIST_DIR/$ZIP_NAME" "$APP_NAME"
cd "$SCRIPT_DIR"

echo "[6/7] Creating styled DMG installer..."
mkdir -p "$STAGING_DIR/.background"
if [ -f "Resources/dmg_background.png" ]; then
    cp "Resources/dmg_background.png" "$STAGING_DIR/.background/dmg_background.png"
fi

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
fi

rm -f "$STAGING_DIR/Applications"
ln -s /Applications "$STAGING_DIR/Applications"

# Create temporary read-write DMG
rm -f "$TEMP_DMG" "$FINAL_DMG"
echo "    Creating temporary disk image..."
hdiutil create -srcfolder "$STAGING_DIR" -volname "$VOLUME_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 150m "$TEMP_DMG" > /dev/null

hdiutil detach "/Volumes/$VOLUME_NAME" -force 2>/dev/null || true
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | egrep \/Volumes\/ | awk '{print $1}')
sleep 1

# Apply AppleScript Finder layout & styling
echo "    Applying Finder window layout & background styling..."
osascript << EOF || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 1
        set current view of container window to icon view
        try
            set toolbar visible of container window to false
        end try
        try
            set statusbar visible of container window to false
        end try
        try
            set pathbar visible of container window to false
        end try
        set the bounds of container window to {360, 140, 1040, 652}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 120
        set text size of theViewOptions to 12
        set label position of theViewOptions to bottom
        set background picture of theViewOptions to file ".background:dmg_background.png"
        
        set position of item "$APP_NAME" to {180, 135}
        set position of item "Applications" to {500, 135}
        
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Set volume icon and hidden attributes
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "/Volumes/$VOLUME_NAME/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -c icnC "/Volumes/$VOLUME_NAME/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "/Volumes/$VOLUME_NAME" 2>/dev/null || true
    SetFile -a V "/Volumes/$VOLUME_NAME/.VolumeIcon.icns" 2>/dev/null || true
fi

if [ -d "/Volumes/$VOLUME_NAME/.background" ]; then
    SetFile -a V "/Volumes/$VOLUME_NAME/.background" 2>/dev/null || true
fi

# Close window before unmounting so Finder writes .DS_Store cleanly
osascript -e "tell application \"Finder\" to close (every window whose name is \"$VOLUME_NAME\")" 2>/dev/null || true

sync
sleep 2
sync

hdiutil detach "$DEVICE" -force > /dev/null 2>&1 || hdiutil detach "/Volumes/$VOLUME_NAME" -force > /dev/null 2>&1 || true

# Convert to final compressed read-only DMG
echo "    Compressing final release DMG (UDZO level 9)..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" > /dev/null
rm -f "$TEMP_DMG"

# Apply DMG file cover icon
if [ -f "Resources/AppIcon.icns" ]; then
    swift -e "import AppKit; if let img = NSImage(byReferencingFile: \"Resources/AppIcon.icns\") { NSWorkspace.shared.setIcon(img, forFile: \"$FINAL_DMG\", options: []) }" 2>/dev/null || true
fi

echo "[7/7] Installing to ~/Applications & Launching..."
mkdir -p "$HOME/Applications"
rm -rf "$LOCAL_APP_DEST"
cp -R "$TARGET_APP" "$LOCAL_APP_DEST"

if [ "$LAUNCH_AFTER_BUILD" = true ]; then
    echo "    Launching $LOCAL_APP_DEST..."
    open "$LOCAL_APP_DEST"
fi

DMG_SIZE=$(du -h "$FINAL_DMG" | cut -f1 | tr -d ' ')
ZIP_SIZE=$(du -h "$DIST_DIR/$ZIP_NAME" | cut -f1 | tr -d ' ')

echo ""
echo "=========================================="
echo "  🎉 Mooziac Build Complete!"
echo "=========================================="
echo "  • Version:        $APP_VERSION (Build $APP_BUILD)"
echo "  • Bundle ID:      $APP_BUNDLE_ID"
echo "  • Code Signing:   $SIGN_STATUS"
echo "  • Local App:      $LOCAL_APP_DEST"
echo "  • DMG Installer:  $FINAL_DMG ($DMG_SIZE)"
echo "  • ZIP Archive:    $DIST_DIR/$ZIP_NAME ($ZIP_SIZE)"
echo "=========================================="
