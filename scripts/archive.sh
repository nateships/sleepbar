#!/bin/bash
# Archive the app and export it signed with Developer ID.
#
# Requires:
#   VERSION                    semver, sets MARKETING_VERSION and the build number
#   PROVISIONING_PROFILE_NAME  Name of an installed Developer ID provisioning profile
#   "Developer ID Application" certificate in an unlocked keychain
#
# Output: build/export/SleepBar.app

source "$(dirname "$0")/common.sh"
require_version
: "${PROVISIONING_PROFILE_NAME:?Set PROVISIONING_PROFILE_NAME to the Developer ID profile name}"

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$BUILD_DIR"

# The project sets CODE_SIGN_IDENTITY[sdk=macosx*] = "Apple Development".
# A conditional setting cannot be overridden on the command line, so the
# release signing settings go through an xcconfig file.
XCCONFIG="$BUILD_DIR/release.xcconfig"
cat > "$XCCONFIG" <<EOF
MARKETING_VERSION = $VERSION
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = $TEAM_ID
CODE_SIGN_IDENTITY = $SIGNING_IDENTITY
CODE_SIGN_IDENTITY[sdk=macosx*] = $SIGNING_IDENTITY
PROVISIONING_PROFILE_SPECIFIER = $PROVISIONING_PROFILE_NAME
EOF

echo "→ Archiving $SCHEME $VERSION ($BUILD_NUMBER)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    -xcconfig "$XCCONFIG" \
    archive | pretty

EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$SIGNING_IDENTITY</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$PROVISIONING_PROFILE_NAME</string>
    </dict>
</dict>
</plist>
EOF

echo "→ Exporting Developer ID app"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" | pretty

echo "→ Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString
defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion
echo "✓ Exported: $APP_PATH"
