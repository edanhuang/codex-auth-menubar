#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CodexAuthMenu.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICON_SOURCE="$ROOT_DIR/icon.png"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICON_ICNS="$ROOT_DIR/.build/AppIcon.icns"

cd "$ROOT_DIR"
clang \
  -fobjc-arc \
  -framework AppKit \
  -framework CFNetwork \
  -framework Security \
  -framework UserNotifications \
  Sources/main.m \
  -o "$ROOT_DIR/CodexAuthMenu"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/CodexAuthMenu" "$MACOS_DIR/CodexAuthMenu"
chmod +x "$MACOS_DIR/CodexAuthMenu"

if [[ -f "$ICON_SOURCE" ]]; then
  rm -rf "$ICONSET_DIR" "$ICON_ICNS"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
  cp "$ICON_ICNS" "$RESOURCES_DIR/AppIcon.icns"
  cp "$ICON_SOURCE" "$RESOURCES_DIR/MenuBarIcon.png"
fi

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
