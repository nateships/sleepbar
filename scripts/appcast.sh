#!/bin/bash
# Sign the DMG with the Sparkle EdDSA key and write build/appcast/appcast.xml.
# The release workflow uploads that file as a release asset next to the DMG.
#
# Usage: scripts/appcast.sh
#
# Requires:
#   VERSION              semver of the DMG in build/
#   SPARKLE_PRIVATE_KEY  base64 EdDSA private key (CI). When unset, the key is
#                        read from the login keychain (local fallback).
#   A prior build so that Sparkle's tools exist in DerivedData.
#
# The previous appcast is fetched from the latest GitHub release so that
# generate_appcast keeps the last few items. sleepbar.app/appcast.xml
# redirects to that same asset (see site/_redirects).
#
# The enclosure URL points at the versioned asset on the GitHub release:
#   https://github.com/nateships/sleepbar/releases/download/v<VERSION>/SleepBar-<VERSION>.dmg

source "$(dirname "$0")/common.sh"
require_version

[ -f "$DMG_PATH" ] || { echo "DMG not found: $DMG_PATH. Run scripts/dmg.sh first." >&2; exit 1; }

SPARKLE_BIN="$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/bin"
[ -x "$SPARKLE_BIN/generate_appcast" ] || {
    echo "generate_appcast not found in $SPARKLE_BIN. Build the app first." >&2; exit 1; }

WORK="$BUILD_DIR/appcast"
rm -rf "$WORK"
mkdir -p "$WORK"
cp "$DMG_PATH" "$WORK/SleepBar-$VERSION.dmg"

PREVIOUS_APPCAST_URL="https://github.com/$RELEASES_REPO/releases/latest/download/appcast.xml"
if curl -fsSL -o "$WORK/appcast.xml" "$PREVIOUS_APPCAST_URL"; then
    echo "→ Seeded from $PREVIOUS_APPCAST_URL"
else
    echo "→ No previous appcast at $PREVIOUS_APPCAST_URL. Starting a new one."
    rm -f "$WORK/appcast.xml"
fi

KEY_ARGS=()
KEY_FILE=""
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    KEY_FILE="$WORK/.ed25519"
    (umask 077 && printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE")
    KEY_ARGS=(--ed-key-file "$KEY_FILE")
fi
cleanup() { [ -n "$KEY_FILE" ] && rm -Pf "$KEY_FILE"; return 0; }
trap cleanup EXIT

echo "→ Generating appcast"
"$SPARKLE_BIN/generate_appcast" "${KEY_ARGS[@]}" \
    --download-url-prefix "https://github.com/$RELEASES_REPO/releases/download/v$VERSION/" \
    --link "https://sleepbar.app" \
    --maximum-versions 3 \
    "$WORK"

echo "✓ Wrote: $WORK/appcast.xml"
grep -E "shortVersionString|enclosure" "$WORK/appcast.xml" | head -4
