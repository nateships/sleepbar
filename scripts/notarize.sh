#!/bin/bash
# Notarize build/SleepBar.dmg with Apple and staple the ticket.
#
# Credentials, one of:
#   NOTARY_APPLE_ID + NOTARY_PASSWORD   (app-specific password; used in CI)
#   a "notarytool" keychain profile     (local fallback)

source "$(dirname "$0")/common.sh"

[ -f "$DMG_PATH" ] || { echo "DMG not found: $DMG_PATH. Run scripts/dmg.sh first." >&2; exit 1; }

if [ -n "${NOTARY_APPLE_ID:-}" ]; then
    AUTH=(--apple-id "$NOTARY_APPLE_ID" --team-id "$TEAM_ID" --password "$NOTARY_PASSWORD")
else
    AUTH=(--keychain-profile notarytool)
fi

echo "→ Submitting to Apple notary service (usually 1-10 minutes)"
RESULT=$(xcrun notarytool submit "$DMG_PATH" "${AUTH[@]}" --wait --output-format json)
SUBMISSION_ID=$(plutil -extract id raw -o - - <<< "$RESULT")
STATUS=$(plutil -extract status raw -o - - <<< "$RESULT")
echo "  submission: $SUBMISSION_ID"
echo "  status:     $STATUS"

if [ "$STATUS" != "Accepted" ]; then
    echo "→ Notarization log:"
    xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}"
    exit 1
fi

echo "→ Stapling ticket"
xcrun stapler staple "$DMG_PATH"

echo "→ Gatekeeper check"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
echo "✓ Notarized: $DMG_PATH"
