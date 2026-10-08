#!/usr/bin/env bash
# Builds Clipboard.app (Apple silicon) and packages it into a drag-to-install DMG.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Clipboard"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUT="build"
APP="$OUT/$APP_NAME.app"
DMG="$OUT/$APP_NAME-$VERSION.dmg"

echo "› Compiling release binary"
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

echo "› Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" scripts/Info.plist > "$APP/Contents/Info.plist"
printf "APPL????" > "$APP/Contents/PkgInfo"

echo "› Rendering app icon"
ICONSET="$OUT/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift scripts/make-icon.swift "$OUT/AppIcon-1024.png" >/dev/null
for size in 16 32 128 256 512; do
    sips -z $size $size "$OUT/AppIcon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$OUT/AppIcon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "› Signing"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

echo "› Creating $DMG"
STAGING="$OUT/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING" "$ICONSET"

echo "✓ Done"
echo "  App: $APP"
echo "  DMG: $DMG"
