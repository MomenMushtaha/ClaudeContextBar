#!/bin/bash
set -e

APP_NAME="ClaudeContextBar"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_NAME="com.claude.contextbar.watcher"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "Building $APP_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"

# Create .app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macos13.0"
else
    TARGET="x86_64-apple-macos13.0"
fi

# Compile all Swift sources
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Combine \
    -sdk $(xcrun --show-sdk-path) \
    -target $TARGET \
    -O \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/StatusBarManager.swift \
    Sources/ClaudeDataProvider.swift \
    Sources/IconRenderer.swift \
    Sources/PopoverContentView.swift

# Copy Info.plist
cp Resources/Info.plist "$CONTENTS_DIR/"

echo "Built successfully."

# Install
echo "Installing to /Applications..."
pkill -f "ClaudeContextBar.app/Contents/MacOS/ClaudeContextBar" 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/$APP_NAME.app"
cp -r "$APP_BUNDLE" /Applications/

# Install and load LaunchAgent
echo "Setting up LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS_DIR"
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
cp "$PLIST_NAME.plist" "$LAUNCH_AGENTS_DIR/"
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist"

echo ""
echo "Done. ClaudeContextBar will now auto-launch when a Claude Code session starts"
echo "and auto-quit 60s after the last session ends."
echo ""
echo "To uninstall:"
echo "  launchctl bootout gui/$(id -u)/$PLIST_NAME"
echo "  rm ~/Library/LaunchAgents/$PLIST_NAME.plist"
echo "  rm -rf /Applications/$APP_NAME.app"
