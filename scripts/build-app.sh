#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -eq 0 ]]; then
  swift build -c release --scratch-path .build
  BIN_DIR="$(swift build -c release --scratch-path .build --show-bin-path)"
  BINARY="$BIN_DIR/Soundcheck"
else
  BINARY="$1"
fi
APP="dist/Soundcheck.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BINARY" "$APP/Contents/MacOS/Soundcheck"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Soundcheck</string>
<key>CFBundleIdentifier</key><string>local.sounddesk.mixer</string>
<key>CFBundleName</key><string>Soundcheck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.2</string>
<key>LSUIElement</key><true/>
<key>NSAudioCaptureUsageDescription</key><string>Soundcheck processes app audio locally so you can change each app’s volume. Audio is never recorded or uploaded.</string>
</dict></plist>
PLIST
# Synced folders may attach Finder metadata, which invalidates code signing.
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
codesign --force --sign - "$APP"
echo "Built $APP"
