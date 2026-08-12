#!/bin/bash
# Builds DeskArt.app and packages it as a distributable DMG.
#
# Usage: ./scripts/build-dmg.sh
# Output: dist/DeskArt.app and dist/DeskArt.dmg

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DIST="$ROOT/dist"
APP="$DIST/DeskArt.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> Building release binary"
swift build -c release

echo "==> Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/DeskArt" "$APP/Contents/MacOS/DeskArt"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# A bare executable does not need CFBundleExecutable, but a bundle does.
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string DeskArt" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable DeskArt" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true

echo "==> Generating icon"
ICONSET="$STAGE/DeskArt.iconset"
mkdir -p "$ICONSET" "$STAGE/png"
swift "Resources/Icon/make-icon.swift" "$STAGE/png" >/dev/null
cp "$STAGE/png/icon_16.png"   "$ICONSET/icon_16x16.png"
cp "$STAGE/png/icon_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$STAGE/png/icon_32.png"   "$ICONSET/icon_32x32.png"
cp "$STAGE/png/icon_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$STAGE/png/icon_128.png"  "$ICONSET/icon_128x128.png"
cp "$STAGE/png/icon_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$STAGE/png/icon_256.png"  "$ICONSET/icon_256x256.png"
cp "$STAGE/png/icon_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$STAGE/png/icon_512.png"  "$ICONSET/icon_512x512.png"
cp "$STAGE/png/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature. This does not satisfy Gatekeeper — that needs a paid
# Developer ID and notarisation — but it gives the app a stable code identity
# so macOS keeps its Automation permission across launches instead of
# re-prompting every time.
echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - --options runtime "$APP"
codesign -v "$APP" && echo "    signature valid"

echo "==> Building DMG"
DMGROOT="$STAGE/dmgroot"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
cp "$ROOT/scripts/dmg-readme.txt" "$DMGROOT/READ ME FIRST.txt"

rm -f "$DIST/DeskArt.dmg"
hdiutil create -volname "DeskArt" -srcfolder "$DMGROOT" -ov -format UDZO "$DIST/DeskArt.dmg"

echo
echo "Done:"
echo "  $APP"
echo "  $DIST/DeskArt.dmg  ($(du -h "$DIST/DeskArt.dmg" | cut -f1))"
