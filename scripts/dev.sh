#!/bin/bash
# Build a signed Debug app and run it in the foreground. Ctrl-C quits it.
# The unsigned build from build.sh has no CloudKit entitlement and traps in
# CKContainer at launch, so this build signs with the development team.
# `open` does not launch a locally built app, so run the binary directly.

source "$(dirname "$0")/common.sh"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build | pretty

# Quit any running copy. The menu bar allows one instance per bundle id.
pkill -x SleepBar || true

exec "$DERIVED_DATA_PATH/Build/Products/Debug/SleepBar.app/Contents/MacOS/SleepBar"
