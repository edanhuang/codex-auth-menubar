#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CodexAuthMenu.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

cd "$ROOT_DIR"
clang \
  -fobjc-arc \
  -framework AppKit \
  -framework UserNotifications \
  Sources/main.m \
  -o "$ROOT_DIR/CodexAuthMenu"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/CodexAuthMenu" "$MACOS_DIR/CodexAuthMenu"
chmod +x "$MACOS_DIR/CodexAuthMenu"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CodexAuthMenu</string>
    <key>CFBundleIdentifier</key>
    <string>local.huangjianlong.CodexAuthMenu</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CodexAuthMenu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Used to open Terminal and run codex-auth commands.</string>
</dict>
</plist>
PLIST

rm -f "$ROOT_DIR/CodexAuthMenu"
echo "Built app at: $APP_DIR"
