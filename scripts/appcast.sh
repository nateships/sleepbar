#!/bin/bash
# Sign the DMG with the Sparkle EdDSA key and update the appcast in the
# website checkout.
#
# Usage: scripts/appcast.sh <site-dir>
#
# Requires:
#   VERSION              semver of the DMG in build/
#   SPARKLE_PRIVATE_KEY  base64 EdDSA private key (CI). When unset, the key is
#                        read from the login keychain (local fallback).
#   A prior build so that Sparkle's tools exist in DerivedData.
#
# The enclosure URL points at the versioned asset on the GitHub release:
#   https://github.com/nateships/sleepbar/releases/download/v<VERSION>/SleepBar-<VERSION>.dmg

source "$(dirname "$0")/common.sh"
require_version

SITE_DIR="${1:?Usage: $0 <site-dir>}"
[ -d "$SITE_DIR" ] || { echo "Site dir not found: $SITE_DIR" >&2; exit 1; }
[ -f "$DMG_PATH" ] || { echo "DMG not found: $DMG_PATH. Run scripts/dmg.sh first." >&2; exit 1; }

SPARKLE_BIN="$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/bin"
[ -x "$SPARKLE_BIN/generate_appcast" ] || {
    echo "generate_appcast not found in $SPARKLE_BIN. Build the app first." >&2; exit 1; }

WORK="$BUILD_DIR/appcast"
rm -rf "$WORK"
mkdir -p "$WORK"
cp "$DMG_PATH" "$WORK/SleepBar-$VERSION.dmg"
[ -f "$SITE_DIR/appcast.xml" ] && cp "$SITE_DIR/appcast.xml" "$WORK/appcast.xml"

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

cp "$WORK/appcast.xml" "$SITE_DIR/appcast.xml"
echo "✓ Updated: $SITE_DIR/appcast.xml"
grep -E "shortVersionString|enclosure" "$SITE_DIR/appcast.xml" | head -4
