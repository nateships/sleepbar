#!/bin/bash
# Notarize and staple either the exported app or the DMG.
#
# Usage: scripts/notarize.sh app|dmg
#
# Run "app" before scripts/dmg.sh so the DMG contains a stapled app. An app
# with its own ticket passes Gatekeeper offline, and Sparkle installs it
# without a network round trip to Apple. Then run "dmg" after scripts/dmg.sh.
#
# Credentials, one of:
#   NOTARY_APPLE_ID + NOTARY_PASSWORD   (app-specific password; used in CI)
#   a "notarytool" keychain profile     (local fallback)

source "$(dirname "$0")/common.sh"

TARGET="${1:?Usage: $0 app|dmg}"

if [ -n "${NOTARY_APPLE_ID:-}" ]; then
    AUTH=(--apple-id "$NOTARY_APPLE_ID" --team-id "$TEAM_ID" --password "$NOTARY_PASSWORD")
else
    AUTH=(--keychain-profile notarytool)
fi

case "$TARGET" in
    app)
        [ -d "$APP_PATH" ] || { echo "App not found: $APP_PATH. Run scripts/archive.sh first." >&2; exit 1; }
        # notarytool accepts zip, dmg, or pkg. ditto keeps the bundle intact.
        SUBMIT_PATH="$BUILD_DIR/SleepBar-notarize.zip"
        rm -f "$SUBMIT_PATH"
        ditto -c -k --keepParent "$APP_PATH" "$SUBMIT_PATH"
        STAPLE_PATH="$APP_PATH"
        ;;
    dmg)
        [ -f "$DMG_PATH" ] || { echo "DMG not found: $DMG_PATH. Run scripts/dmg.sh first." >&2; exit 1; }
        SUBMIT_PATH="$DMG_PATH"
        STAPLE_PATH="$DMG_PATH"
        ;;
    *)
        echo "Unknown target: $TARGET. Use app or dmg." >&2
        exit 2
        ;;
esac

echo "→ Submitting $TARGET to Apple notary service (usually 1-10 minutes)"
RESULT=$(xcrun notarytool submit "$SUBMIT_PATH" "${AUTH[@]}" --wait --output-format json)
SUBMISSION_ID=$(plutil -extract id raw -o - - <<< "$RESULT")
STATUS=$(plutil -extract status raw -o - - <<< "$RESULT")
echo "  submission: $SUBMISSION_ID"
echo "  status:     $STATUS"

if [ "$STATUS" != "Accepted" ]; then
    echo "→ Notarization log:"
    xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}"
    exit 1
fi

echo "→ Stapling ticket to $STAPLE_PATH"
xcrun stapler staple "$STAPLE_PATH"
xcrun stapler validate "$STAPLE_PATH"

echo "→ Gatekeeper check"
if [ "$TARGET" = "app" ]; then
    spctl --assess --type exec --verbose=2 "$STAPLE_PATH"
    rm -f "$SUBMIT_PATH"
else
    spctl --assess --type open --context context:primary-signature --verbose=2 "$STAPLE_PATH"
fi
echo "✓ Notarized $TARGET: $STAPLE_PATH"
