#!/bin/bash
# Builds PhoneBar.app (sandboxed, ad-hoc signed) into ./build and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/PhoneBar.app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/PhoneBar"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PhoneBar"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [ -f Support/AppIcon.icns ]; then
    cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - --entitlements Support/PhoneBar.entitlements "$APP"

echo "Built $APP"
