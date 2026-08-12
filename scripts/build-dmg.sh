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
#
# The entitlements are NOT optional: --options runtime enables the hardened
# runtime, which forbids sending Apple Events unless the app carries
# com.apple.security.automation.apple-events. Without it Finder requests fail
# with -1743 and macOS never shows the consent prompt at all, so the user has
# no way to grant access. Ad-hoc signing honours entitlements here because TCC
# checks the entitlement, not the signing authority.
echo "==> Signing (ad-hoc, with Apple Events entitlement)"
codesign --force --deep --sign - --options runtime \
  --entitlements "Resources/DeskArt.entitlements" "$APP"
codesign -v "$APP" && echo "    signature valid"

# Fail loudly rather than shipping another DMG that cannot talk to Finder.
if ! codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "automation.apple-events"; then
  echo "ERROR: Apple Events entitlement missing from signature — aborting." >&2
  exit 1
fi
echo "    apple-events entitlement present"

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
