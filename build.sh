#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ClaudeNotifier"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
ICON_SOURCE="$SCRIPT_DIR/Media.xcassets/AppIcon.imageset/Claude-iOS-Default-1024x1024@1x.png"

echo "Building $APP_NAME..."

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile Swift
swiftc -O \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "$SCRIPT_DIR/Sources/main.swift"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Convert PNG to ICNS
if [ -f "$ICON_SOURCE" ]; then
    echo "Creating icon..."
    ICONSET="$SCRIPT_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET"

    # Generate all required sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1

    # Create icns
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"

    # To add notification attachment images for visual tagging, copy PNGs here:
    # cp "$SCRIPT_DIR/path/to/ErrorIcon.png" "$APP_BUNDLE/Contents/Resources/"
    # cp "$SCRIPT_DIR/path/to/SuccessIcon.png" "$APP_BUNDLE/Contents/Resources/"

    echo "Icon created."
else
    echo "Warning: Icon not found at $ICON_SOURCE"
fi

# Codesign the app bundle (required for notifications)
codesign --force --deep --sign - "$APP_BUNDLE"

# Create symlink in /usr/local/bin for easy access
INSTALL_PATH="/usr/local/bin/claude-notify"
if [ -L "$INSTALL_PATH" ] || [ -f "$INSTALL_PATH" ]; then
    rm "$INSTALL_PATH"
fi
ln -s "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$INSTALL_PATH"

# Create symlink for toggle command
TOGGLE_PATH="/usr/local/bin/claude-notifications"
if [ -L "$TOGGLE_PATH" ] || [ -f "$TOGGLE_PATH" ]; then
    rm "$TOGGLE_PATH"
fi
ln -s "$SCRIPT_DIR/claude-notifications.sh" "$TOGGLE_PATH"

# Create symlink for music toggle command
MUSIC_PATH="/usr/local/bin/claude-music"
if [ -L "$MUSIC_PATH" ] || [ -f "$MUSIC_PATH" ]; then
    rm "$MUSIC_PATH"
fi
ln -s "$SCRIPT_DIR/claude-music.sh" "$MUSIC_PATH"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo "CLI symlink: $INSTALL_PATH"
echo ""
echo "Usage: claude-notify -title 'Title' -message 'Message'"
echo ""
echo "First run will prompt for notification permissions."
