#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_VERSION="0.4.0"
APP_BUILD="8"
if [[ $# -eq 0 ]]; then
  swift build -c release --scratch-path .build
  BIN_DIR="$(swift build -c release --scratch-path .build --show-bin-path)"
  BINARY="$BIN_DIR/Soundcheck"
else
  BINARY="$1"
fi
STAGING="$(mktemp -d /tmp/soundcheck-package.XXXXXX)"
APP="$STAGING/Soundcheck.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
RESOURCE_BUNDLE="$(dirname "$BINARY")/Soundcheck_Mixer.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing app resources: $RESOURCE_BUNDLE" >&2
  exit 1
fi
ditto --norsrc "$RESOURCE_BUNDLE" "$APP/Contents/Resources/Soundcheck_Mixer.bundle"
cp "$BINARY" "$APP/Contents/MacOS/Soundcheck"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Soundcheck</string>
<key>CFBundleIdentifier</key><string>local.sounddesk.mixer</string>
<key>CFBundleName</key><string>Soundcheck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$APP_BUILD</string>
<key>LSMinimumSystemVersion</key><string>14.2</string>
<key>LSUIElement</key><true/>
<key>NSAudioCaptureUsageDescription</key><string>Soundcheck processes app audio locally so you can change each app’s volume. Audio is never recorded or uploaded.</string>
</dict></plist>
PLIST
# Synced folders may attach Finder metadata, which invalidates code signing.
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
codesign --force --sign - "$APP/Contents/Resources/Soundcheck_Mixer.bundle"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p dist
ditto --norsrc "$APP" dist/Soundcheck.app
xattr -dr com.apple.FinderInfo dist/Soundcheck.app 2>/dev/null || true
ditto -c -k --norsrc --keepParent "$APP" dist/Soundcheck.zip
cp dist/Soundcheck.zip "dist/Soundcheck-$APP_VERSION.zip"
echo "Built dist/Soundcheck.app and dist/Soundcheck.zip"
