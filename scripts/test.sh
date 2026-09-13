#!/bin/bash
# Run unit tests. The test host needs a signed app, so Xcode must be signed in
# to the team. The provisioning flags let xcodebuild register this Mac and
# fetch or create the development certificate and profile.

source "$(dirname "$0")/common.sh"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    test | pretty
