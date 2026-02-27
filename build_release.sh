#!/bin/bash

set -e

APP_NAME="AppCloser"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
APP_CONTENTS="${APP_BUNDLE}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"

# Clean old build
echo "Cleaning..."
rm -rf "$APP_BUNDLE"

# Build release binary
echo "Building release..."
swift build -c release

# Create app bundle structure
echo "Creating .app bundle..."
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_MACOS/"

# Copy Info.plist
cp "Info.plist" "$APP_CONTENTS/"

# Copy icon (optional)
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_RESOURCES/"
fi

# Output path
echo "Done! App built at:"
echo "   $(pwd)/$APP_BUNDLE"

# Optionally copy to /Applications
read -p "Copy to /Applications? [y/N] " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    cp -R "$APP_BUNDLE" /Applications/
    echo "Installed to /Applications"
fi
