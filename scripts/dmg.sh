#!/bin/bash
# Build a DMG from the exported app and sign it with Developer ID.
#
# Input:  build/export/SleepBar.app
# Output: build/SleepBar.dmg

source "$(dirname "$0")/common.sh"

[ -d "$APP_PATH" ] || { echo "App not found: $APP_PATH. Run scripts/archive.sh first." >&2; exit 1; }

STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

echo "→ Staging DMG contents"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "→ Creating DMG"
hdiutil create -volname "SleepBar" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"

echo "→ Signing DMG"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

rm -rf "$STAGING"
echo "✓ Created: $DMG_PATH"
