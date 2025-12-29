#!/bin/bash
set -e

APP_NAME="AudioPriorityBar"
BUNDLE_ID="com.audioproioritybar.app"
OUTPUT_DIR="$PWD/dist"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"

# Clean
rm -rf "$OUTPUT_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Compiling $APP_NAME..."

# Compile all Swift files
swiftc \
    AudioPriorityBar/AudioPriorityBarApp.swift \
    AudioPriorityBar/Models/AudioDevice.swift \
    AudioPriorityBar/Views/MenuBarView.swift \
    AudioPriorityBar/Views/DeviceListView.swift \
    AudioPriorityBar/Services/AudioDeviceService.swift \
    AudioPriorityBar/Services/PriorityManager.swift \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework AppKit \
    -framework SwiftUI \
    -framework CoreAudio \
    -framework AudioToolbox \
    -O \
    -whole-module-optimization

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AudioPriorityBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.audioproioritybar.app</string>
    <key>CFBundleName</key>
    <string>Audio Priority Bar</string>
    <key>CFBundleDisplayName</key>
    <string>Audio Priority Bar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Sign
codesign --force --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
