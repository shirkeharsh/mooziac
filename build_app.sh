#!/bin/bash
set -e

# ==============================================================================
# Mooziac Unified Build & Packaging Pipeline
# Compiles Universal binary, builds .app, packages .dmg & .zip, and installs locally.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_VERSION="1.0.0"
APP_BUILD="1"
APP_NAME="Mooziac.app"
APP_BUNDLE_ID="app.mooziac.mac"
APP_COPYRIGHT="Copyright © 2026 ThreeTen. All rights reserved."
APP_DESCRIPTION="Mooziac — modern music player for macOS with trackpad gestures and YouTube Music sync."
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
killall "YTMMenuBar" 2>/dev/null || true
pkill -9 -f "Mooziac" 2>/dev/null || true
pkill -9 -f "YTMMenuBar" 2>/dev/null || true
sleep 1

# Clean previous build artifacts
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
touch "$DIST_DIR/.metadata_never_index"
mkdir -p "$STAGING_DIR"
touch "$STAGING_DIR/.metadata_never_index"

# Ensure DMG background exists
if [ -f "scripts/generate_dmg_background.swift" ] && [ ! -f "Resources/dmg_background.png" ]; then
    echo "    Generating DMG background artwork..."
    swift scripts/generate_dmg_background.swift > /dev/null 2>&1 || true
fi

echo "[2/7] Compiling release binaries..."
# Attempt Universal 2 build (arm64 + x86_64)
UNIVERSAL_BIN="$DIST_DIR/Mooziac_universal"
ARM_BIN=".build/arm64-apple-macosx/release/Mooziac"
INTEL_BIN=".build/x86_64-apple-macosx/release/Mooziac"

if swift build --triple arm64-apple-macosx -c release 2>/dev/null && swift build --triple x86_64-apple-macosx -c release 2>/dev/null; then
    echo "    Merging arm64 and x86_64 into Universal 2 binary via lipo..."
    lipo -create -output "$UNIVERSAL_BIN" "$ARM_BIN" "$INTEL_BIN"
    BIN_PATH="$UNIVERSAL_BIN"
else
    echo "    Universal build not supported in current toolchain; building native release binary..."
    swift build -c release
    BIN_DIR=$(swift build -c release --show-bin-path)
    BIN_PATH="$BIN_DIR/Mooziac"
fi

echo "[3/7] Assembling $APP_NAME bundle..."
BUNDLE_DIR="$TARGET_APP/Contents"
MACOS_DIR="$BUNDLE_DIR/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/Mooziac"

# Copy runtime assets from Resources/
for asset in AppIcon.icns MOOZIAC_transparent.png launch_transparent.png MOOZIAC.png MenuBarIcon.png MenuBarIcon@2x.png trackpad.html macbook_panel.jpg; do
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
    if ! codesign --force --deep --options runtime $ENTITLEMENTS_FLAG --sign "$SIGN_IDENTITY" --identifier "$APP_BUNDLE_ID" "$TARGET_APP" 2>/dev/null; then
        echo "    Certificate signing unavailable. Falling back to ad-hoc signing..."
        codesign --force --deep --options runtime $ENTITLEMENTS_FLAG --sign - --identifier "$APP_BUNDLE_ID" "$TARGET_APP"
    else
        SIGN_STATUS="Valid signature ($SIGN_IDENTITY)"
    fi
else
    echo "    Ad-hoc signing with Hardened Runtime..."
    codesign --force --deep --options runtime $ENTITLEMENTS_FLAG --sign - --identifier "$APP_BUNDLE_ID" "$TARGET_APP"
fi

codesign --verify --deep --strict "$TARGET_APP" 2>/dev/null || true

echo "[5/7] Creating ZIP distribution..."
cd "$STAGING_DIR"
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

ln -s /Applications "$STAGING_DIR/Applications"

# Create temporary read-write DMG
hdiutil create -srcfolder "$STAGING_DIR" -volname "$VOLUME_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 150m "$TEMP_DMG" > /dev/null

hdiutil detach "/Volumes/$VOLUME_NAME" -force 2>/dev/null || true
hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" > /dev/null
sleep 1

# Apply AppleScript Finder layout & styling
osascript << EOF || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 150, 1040, 550}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 120
        if exists file ".background:dmg_background.png" then
            set background picture of theViewOptions to file ".background:dmg_background.png"
        end if
        
        set position of item "$APP_NAME" of container window to {160, 200}
        set position of item "Applications" of container window to {480, 200}
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Set volume icon and hidden attributes
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "/Volumes/$VOLUME_NAME/.VolumeIcon.icns"
    SetFile -c icnC "/Volumes/$VOLUME_NAME/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "/Volumes/$VOLUME_NAME" 2>/dev/null || true
    SetFile -a V "/Volumes/$VOLUME_NAME/.VolumeIcon.icns" 2>/dev/null || true
    swift -e "import AppKit; if let img = NSImage(byReferencingFile: \"Resources/AppIcon.icns\") { NSWorkspace.shared.setIcon(img, forFile: \"/Volumes/$VOLUME_NAME\", options: []) }" 2>/dev/null || true
fi

if [ -d "/Volumes/$VOLUME_NAME/.background" ]; then
    SetFile -a V "/Volumes/$VOLUME_NAME/.background" 2>/dev/null || true
fi

sync
hdiutil detach "/Volumes/$VOLUME_NAME" -force > /dev/null || true

# Convert to final compressed read-only DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" > /dev/null
rm -f "$TEMP_DMG"

# Apply DMG file icon & Spotlight metadata
if [ -f "Resources/AppIcon.icns" ]; then
    swift -e "import AppKit; if let img = NSImage(byReferencingFile: \"Resources/AppIcon.icns\") { NSWorkspace.shared.setIcon(img, forFile: \"$FINAL_DMG\", options: []) }" 2>/dev/null || true
fi

osascript -e "tell application \"Finder\" to set comment of (POSIX file \"$FINAL_DMG\" as alias) to \"$DMG_COMMENT\"" 2>/dev/null || true

swift - << SWIFTEOF 2>/dev/null || true
import Foundation

let dmgPath = "$FINAL_DMG"

func setXattr(key: String, value: Any) {
    if let data = try? PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0) {
        data.withUnsafeBytes { ptr in
            _ = setxattr(dmgPath, "com.apple.metadata:" + key, ptr.baseAddress, data.count, 0, 0)
        }
    }
}

setXattr(key: "kMDItemTitle", value: "Mooziac Installer")
setXattr(key: "kMDItemHeadline", value: "Mooziac $APP_VERSION — Modern Music Player for macOS")
setXattr(key: "kMDItemDescription", value: "$APP_DESCRIPTION")
setXattr(key: "kMDItemCopyright", value: "$APP_COPYRIGHT")
setXattr(key: "kMDItemVersion", value: "$APP_VERSION")
setXattr(key: "kMDItemAuthors", value: ["ThreeTen"])
setXattr(key: "kMDItemKeywords", value: ["Mooziac", "Music Player", "YouTube Music", "macOS", "Audio", "Installer"])
setXattr(key: "kMDItemFinderComment", value: """
$DMG_COMMENT
""")
SWIFTEOF

echo "[7/7] Installing to ~/Applications & Launching..."
mkdir -p "$HOME/Applications"
rm -rf "$LOCAL_APP_DEST"
cp -R "$TARGET_APP" "$LOCAL_APP_DEST"

# Unregister staging app and register destination app with LaunchServices
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$TARGET_APP" 2>/dev/null || true
    "$LSREGISTER" -f "$LOCAL_APP_DEST" 2>/dev/null || true
fi

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
echo "👉 To publish to GitHub, run: ./release.sh"
