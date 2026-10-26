#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/PhoneBar.app"
ZIP="build/PhoneBar-for-mac.zip"
SIGN_IDENTITY="Developer ID Application: Dakota Hilchey (2FCUC227QF)"

echo "==> Building PhoneBar release binary..."
swift build -c release
BIN="$(swift build -c release --show-bin-path)/PhoneBar"

rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/PhoneBar"
cp Support/Info.plist "$APP/Contents/Info.plist"

if [ -f Support/AppIcon.icns ]; then
    cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Signing with Developer ID Application: Dakota Hilchey..."
codesign --force --options runtime --deep --sign "$SIGN_IDENTITY" --entitlements Support/PhoneBar.entitlements "$APP"

echo "==> Verifying signature..."
codesign -vvv --deep --strict "$APP"

echo "==> Creating Release ZIP..."
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Created $ZIP"
