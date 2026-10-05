#!/bin/bash
# Builds ScrollToggle.app into ./build.
set -euo pipefail

APP_NAME="ScrollToggle"
BUNDLE_ID="com.jong.scrolltoggle"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/$APP_NAME.app"
# Build for whatever Mac runs this: arm64 or x86_64.
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>스크롤 방향 전환</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu-bar accessory: never shows in the Dock or app switcher. -->
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Pre-rendered; regenerate with: swift icon/make_icon.swift
cp "$ROOT/icon/AppIcon.icns" "$APP/Contents/Resources/"

swiftc -O \
    -target "$ARCH-apple-macos13.0" \
    -framework Cocoa -framework ServiceManagement -framework IOKit \
    -o "$APP/Contents/MacOS/$APP_NAME" \
    "$ROOT/src/ScrollDirection.swift" "$ROOT/src/MouseWatcher.swift" "$ROOT/src/main.swift"

# Ad-hoc signature; SMAppService refuses to register an unsigned bundle.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

echo "빌드 완료: $APP"
